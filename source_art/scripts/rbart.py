"""Biblioteca do projeto Rota Brava para o Blender (PROVISORIO ate aprovacao de Thiago).

Toda geometria e gerada aqui do zero (bmesh + primitivas matematicas). Nada de modelo, malha,
textura ou personagem-base de terceiros. Convencao: Blender Z-up, a frente do personagem/barco
aponta para +Y; o exportador glTF (+Y up) converte isso para -Z na Godot.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))


def script_args():
    argv = sys.argv
    return argv[argv.index("--") + 1:] if "--" in argv else []


def arg_value(name, default=None):
    a = script_args()
    return a[a.index(name) + 1] if name in a else default


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    sc.unit_settings.scale_length = 1.0
    return sc


# ---------------------------------------------------------------- materiais
def _lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_to_linear(h):
    h = h.lstrip("#")
    return tuple(_lin(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


def mat(name, hexcol, rough=0.85, metal=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    lin = hex_to_linear(hexcol) + (1.0,)
    b.inputs["Base Color"].default_value = lin
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    m.diffuse_color = lin
    m["provisional"] = True
    return m


# ---------------------------------------------------------------- primitivas (bmesh)
def _T(v):
    return Matrix.Translation(Vector(v))


def sph(bm, c, r, u=20, v=12):
    rx, ry, rz = r if isinstance(r, (tuple, list)) else (r, r, r)
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0,
                              matrix=_T(c) @ Matrix.Diagonal((rx, ry, rz, 1.0)))


def cyl(bm, p0, p1, r0, r1=None, seg=16, caps=True):
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    q = d.to_track_quat("Z", "Y")
    bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=seg, radius1=r0,
                          radius2=r0 if r1 is None else r1, depth=d.length,
                          matrix=_T((p0 + p1) / 2) @ q.to_matrix().to_4x4())


def box(bm, c, size, rot=None, bevel=0.0):
    m = _T(c)
    if rot is not None:
        m = m @ rot
    n0 = len(bm.verts)
    bmesh.ops.create_cube(bm, size=1.0, matrix=m @ Matrix.Diagonal((size[0], size[1], size[2], 1.0)))
    if bevel > 0:
        new = [e for e in bm.edges if all(v.index >= n0 for v in e.verts)]
        bmesh.ops.bevel(bm, geom=new, offset=bevel, segments=2, affect="EDGES")


def torus(bm, c, R, r, rot=None, major=24, minor=8):
    m = _T(c) @ (rot if rot is not None else Matrix.Identity(4))
    base = len(bm.verts)
    vs = []
    for i in range(major):
        a = 2 * math.pi * i / major
        for j in range(minor):
            b = 2 * math.pi * j / minor
            x = (R + r * math.cos(b)) * math.cos(a)
            y = (R + r * math.cos(b)) * math.sin(a)
            z = r * math.sin(b)
            vs.append(bm.verts.new(m @ Vector((x, y, z))))
    for i in range(major):
        for j in range(minor):
            a = vs[i * minor + j]
            b = vs[((i + 1) % major) * minor + j]
            c2 = vs[((i + 1) % major) * minor + (j + 1) % minor]
            d = vs[i * minor + (j + 1) % minor]
            bm.faces.new((a, b, c2, d))


def rot_x(deg):
    return Matrix.Rotation(math.radians(deg), 4, "X")


def rot_y(deg):
    return Matrix.Rotation(math.radians(deg), 4, "Y")


def rot_z(deg):
    return Matrix.Rotation(math.radians(deg), 4, "Z")


def new_object(name, bm, material, smooth=True, parent=None, collection=None, recalc=True):
    me = bpy.data.meshes.new(name)
    if recalc:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    me.uv_layers.new(name="UVMap")   # Godot gera tangentes e exige UV (valores neutros: so cores)
    me.materials.append(material)
    ob = bpy.data.objects.new(name, me)
    (collection or bpy.context.scene.collection).objects.link(ob)
    if parent is not None:
        ob.parent = parent
    return ob


def empty(name, loc=(0, 0, 0), parent=None, kind="PLAIN_AXES", size=0.2, collection=None):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = kind
    e.empty_display_size = size
    e.location = loc
    (collection or bpy.context.scene.collection).objects.link(e)
    if parent is not None:
        e.parent = parent
    return e


def tri_count(objs):
    n = 0
    dg = bpy.context.evaluated_depsgraph_get()
    for o in objs:
        if o.type == "MESH":
            me = o.evaluated_get(dg).to_mesh()
            me.calc_loop_triangles()
            n += len(me.loop_triangles)
            o.evaluated_get(dg).to_mesh_clear()
    return n


def world_bbox(objs):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        if o.type != "MESH":
            continue
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


# ---------------------------------------------------------------- render (Workbench)
def setup_workbench(sc, w, h, color_type="MATERIAL", light="STUDIO", bg=(1, 1, 1)):
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = False
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGB"
    sc.view_settings.view_transform = "Standard"
    sc.display.shading.light = light
    sc.display.shading.color_type = color_type
    sc.display.shading.show_object_outline = False
    sc.display.shading.show_cavity = False
    sc.display.render_aa = "FXAA" if min(w, h) < 100 else "8"
    if sc.world is None:
        sc.world = bpy.data.worlds.new("w")
    sc.world.color = bg
    sc.display.shading.background_type = "WORLD"


def ortho_camera(sc, loc, target, scale, name="cam"):
    cam = bpy.data.cameras.new(name)
    cam.type = "ORTHO"
    cam.ortho_scale = scale
    co = bpy.data.objects.new(name, cam)
    sc.collection.objects.link(co)
    co.location = loc
    co.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.camera = co
    return co


def text_obj(sc, txt, loc, size, rot=(math.pi / 2, 0, 0), color_mat=None):
    cu = bpy.data.curves.new("t_" + txt, "FONT")
    cu.body = txt
    cu.size = size
    cu.align_x = "CENTER"
    ob = bpy.data.objects.new("t_" + txt, cu)
    sc.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = rot
    if color_mat:
        cu.materials.append(color_mat)
    return ob


def render_to(sc, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def load_pixels(path):
    import numpy as np
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    a = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    bpy.data.images.remove(img)
    return a.reshape(h, w, 4)


def save_pixels(arr, path):
    h, w, _ = arr.shape
    img = bpy.data.images.new("out", w, h, alpha=False)
    img.pixels.foreach_set(arr.reshape(-1).astype("float32"))
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


