"""Biblioteca do ambiente de Rota Brava (RB-04-env, PROVISORIO ate aprovacao de Thiago).

Toda geometria e gerada aqui do zero (bmesh + modificadores Bevel/Subdivision do Blender). Nada baixado.
CONVENCAO: as pecas sao modeladas em coordenadas da GODOT (x leste, y CIMA, z sul; metros) e convertidas
no fim para o Blender (x, -z, y); o exportador glTF (+Y up) devolve exatamente as mesmas medidas.
Frente de objetos direcionais (barco) = -Z na Godot.
"""
import json
import math
import os
import random
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(SCRIPT_DIR, "..", "scripts"))
import bmesh
import bpy
from mathutils import Matrix, Vector

from rbart import REPO, arg_value, empty, hex_to_linear, mat as _mat, reset_scene, tri_count

CONV = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def G(x, y, z):
    """Godot (x, y_cima, z) -> Blender."""
    return Vector((x, -z, y))


def clamp(v, a=0.0, b=1.0):
    return max(a, min(b, v))


# ---------------------------------------------------------------- materiais
PALETTE = {
    "mat_env_wood_deck": ("#8A7254", 0.92, 0.0),
    "mat_env_wood_dark": ("#6A5240", 0.95, 0.0),
    "mat_env_wood_light": ("#BE9F76", 0.9, 0.0),
    "mat_env_nail": ("#4B4A47", 0.55, 0.6),
    "mat_env_rope": ("#CDB67E", 0.95, 0.0),
    "mat_env_metal": ("#5E676C", 0.5, 0.6),
    "mat_env_rubber": ("#2D2D30", 0.8, 0.0),
    "mat_env_ground": ("#FFFFFF", 1.0, 0.0),
    "mat_env_peach": ("#F08E5C", 0.6, 0.0),
    "mat_env_leaf": ("#5F9A45", 0.8, 0.0),
    "mat_env_barrel": ("#7C5B3E", 0.9, 0.0),
    "mat_env_lamp_glass": ("#FFE2A0", 0.3, 0.0),
    "mat_env_net": ("#8E9170", 0.95, 0.0),
    "mat_env_cork": ("#C79A5E", 0.9, 0.0),
    "mat_env_buoy_red": ("#D8573C", 0.6, 0.0),
    "mat_env_white": ("#EFE8D6", 0.7, 0.0),
    "mat_env_bucket": ("#4F82A3", 0.5, 0.2),
    "mat_env_hut_wall": ("#D8C7A0", 0.95, 0.0),
    "mat_env_hut_roof": ("#A8503C", 0.85, 0.0),
    "mat_env_hut_door": ("#4F8A8C", 0.8, 0.0),
    "mat_env_hut_glass": ("#3D5D66", 0.2, 0.0),
    "mat_env_trunk": ("#6A4C36", 0.95, 0.0),
    "mat_env_foliage_a": ("#5C9A4A", 0.9, 0.0),
    "mat_env_foliage_b": ("#7AA84F", 0.9, 0.0),
    "mat_env_foliage_c": ("#4C8A58", 0.9, 0.0),
    "mat_env_bush": ("#6AA253", 0.9, 0.0),
    "mat_env_bush_flower": ("#E3B84C", 0.8, 0.0),
    "mat_env_reed": ("#8DAA58", 0.9, 0.0),
    "mat_env_rock": ("#8F918A", 0.95, 0.0),
    "mat_env_rock_warm": ("#A29A8A", 0.95, 0.0),
    "mat_env_bootprint": ("#3A2A22", 1.0, 0.0),
    # barco v2
    "mat_env_boat_hull": ("#F5C518", 0.5, 0.0),
    "mat_env_boat_trim": ("#2F7F86", 0.6, 0.0),
    "mat_env_boat_stripe": ("#D9552B", 0.6, 0.0),
    "mat_env_boat_deck": ("#B08A58", 0.9, 0.0),
    "mat_env_boat_cabin": ("#F2E6C4", 0.8, 0.0),
    "mat_env_boat_roof": ("#2F7F86", 0.7, 0.0),
    "mat_env_boat_glass": ("#5C9AAE", 0.2, 0.0),
    "mat_env_boat_bench": ("#CDAA78", 0.85, 0.0),
    "mat_env_boat_wheel": ("#7A4A28", 0.7, 0.0),
    "mat_env_boat_motor": ("#3D4448", 0.5, 0.4),
    "mat_env_boat_flag": ("#D9552B", 0.8, 0.0),
    "mat_env_boat_name": ("#F2E6C4", 0.7, 0.0),
    "mat_env_paw": ("#2B1B14", 0.9, 0.0),
}
EMISSIVE = {"mat_env_lamp_glass": ("#FFD88A", 3.0), "mat_env_boat_lamp": ("#FFD88A", 3.0)}


def materials():
    out = {}
    for name, (hx, ro, me) in PALETTE.items():
        out[name] = _mat(name, hx, ro, me)
    out["mat_env_boat_lamp"] = _mat("mat_env_boat_lamp", "#FFE2A0", 0.3, 0.0)
    for name, (hx, st) in EMISSIVE.items():
        b = out[name].node_tree.nodes["Principled BSDF"]
        b.inputs["Emission Color"].default_value = hex_to_linear(hx) + (1.0,)
        b.inputs["Emission Strength"].default_value = st
    return out


# ---------------------------------------------------------------- primitivas (espaco Godot)
def rotm(rx=0, ry=0, rz=0):
    return (Matrix.Rotation(math.radians(ry), 4, "Y") @ Matrix.Rotation(math.radians(rx), 4, "X")
            @ Matrix.Rotation(math.radians(rz), 4, "Z"))


def gbox(bm, c, s, rx=0, ry=0, rz=0, cuts=(0, 0, 0)):
    """Caixa centrada em c, tamanho s (x,y,z) em espaco Godot; cuts = subdivisoes por eixo local."""
    m = Matrix.Translation(Vector(c)) @ rotm(rx, ry, rz) @ Matrix.Diagonal((s[0], s[1], s[2], 1.0))
    before = set(bm.verts)
    res = bmesh.ops.create_cube(bm, size=1.0, matrix=m)
    if any(cuts):
        inv = (rotm(rx, ry, rz)).inverted()
        for ax in range(3):
            if cuts[ax] <= 0:
                continue
            mine = set(v for v in bm.verts if v not in before)
            edges = set()
            for v in mine:
                for e in v.link_edges:
                    d = inv @ (e.verts[0].co - e.verts[1].co)
                    if abs(d[ax]) > 0.6 * d.length and e.verts[0] in mine and e.verts[1] in mine:
                        edges.add(e)
            bmesh.ops.subdivide_edges(bm, edges=list(edges), cuts=cuts[ax], use_grid_fill=True)
    return [v for v in bm.verts if v not in before]


def gcyl(bm, p0, p1, r0, r1=None, seg=12, caps=True):
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=seg, radius1=r0,
                          radius2=r0 if r1 is None else r1, depth=d.length,
                          matrix=Matrix.Translation((p0 + p1) / 2) @ q.to_matrix().to_4x4())


def gsph(bm, c, r, u=14, v=9):
    rx, ry, rz = r if isinstance(r, (tuple, list)) else (r, r, r)
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0,
                              matrix=Matrix.Translation(Vector(c)) @ Matrix.Diagonal((rx, ry, rz, 1.0)))


def sweep(bm, pts, r, seg=8, caps=True, closed=False):
    """Tubo ao longo de uma polilinha (espaco Godot). r escalar ou f(t)."""
    pts = [Vector(p) for p in pts]
    n = len(pts)
    rings = []
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        a = Vector((0, 1, 0)) if abs(t.dot(Vector((0, 1, 0)))) < 0.9 else Vector((1, 0, 0))
        nr = t.cross(a).normalized()
        bn = t.cross(nr).normalized()
        rr = r(i / max(1, n - 1)) if callable(r) else r
        rings.append([bm.verts.new(p + (nr * math.cos(2 * math.pi * k / seg) + bn * math.sin(2 * math.pi * k / seg)) * rr)
                      for k in range(seg)])
    for i in range(n - 1):
        for k in range(seg):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % seg], rings[i + 1][(k + 1) % seg], rings[i + 1][k]))
    if caps:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])


def lathe(bm, profile, seg=16, c=(0, 0, 0), sx=1.0, sz=1.0):
    """Revolucao em torno do eixo y: profile = [(raio, y), ...] de baixo para cima (raio 0 fecha a ponta)."""
    rings = []
    for r, y in profile:
        if r <= 1e-6:
            rings.append([bm.verts.new((c[0], c[1] + y, c[2]))])
        else:
            rings.append([bm.verts.new((c[0] + r * sx * math.cos(2 * math.pi * k / seg), c[1] + y,
                                        c[2] + r * sz * math.sin(2 * math.pi * k / seg))) for k in range(seg)])
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        if len(a) == 1:
            for k in range(seg):
                bm.faces.new((a[0], b[(k + 1) % seg], b[k]))
        elif len(b) == 1:
            for k in range(seg):
                bm.faces.new((a[k], a[(k + 1) % seg], b[0]))
        else:
            for k in range(seg):
                bm.faces.new((a[k], a[(k + 1) % seg], b[(k + 1) % seg], b[k]))
    for ring in (rings[0], rings[-1]):
        if len(ring) > 2:
            bm.faces.new(ring)


def grid_patch(bm, x0, x1, z0, z1, nx, nz, height):
    """Malha em grade (plano XZ) com altura height(x,z); retorna matriz de verts e faces."""
    vs = [[bm.verts.new((x0 + (x1 - x0) * i / nx, height(x0 + (x1 - x0) * i / nx, z0 + (z1 - z0) * j / nz),
                         z0 + (z1 - z0) * j / nz)) for j in range(nz + 1)] for i in range(nx + 1)]
    faces = []
    for i in range(nx):
        for j in range(nz):
            faces.append(bm.faces.new((vs[i][j], vs[i][j + 1], vs[i + 1][j + 1], vs[i + 1][j])))
    return vs, faces


# ---------------------------------------------------------------- objetos
class Asset:
    """Um ativo exportavel: raiz (empty) + partes (malhas com modificadores) + empties."""
    X_CURSOR = 0.0

    def __init__(self, name, mats, seed=1, spacing=None):
        self.name = name
        self.M = mats
        self.rng = random.Random(seed)
        self.root = empty(name, (0, 0, 0), kind="PLAIN_AXES", size=0.3)
        self.root["provisional"] = True
        self.root["agent"] = "art3d"
        self.objs = []
        self.empties = []

    # cor por vertice: variacao por objeto + AO por altura (multiplica a cor do material)
    @staticmethod
    def _layer(bm):
        lay = bm.verts.layers.float_color.get("Col")
        if lay is None:
            lay = bm.verts.layers.float_color.new("Col")
            for v in bm.verts:
                v[lay] = (1.0, 1.0, 1.0, 1.0)
        return lay

    def paint_new(self, bm, before, jit=0.1, ao=0.25, tint=(1, 1, 1), ao_h=None):
        """Pinta so os vertices criados depois de `before` (set de verts)."""
        self._layer(bm)
        self._paint(bm, jit, ao, tint, ao_h, only=[v for v in bm.verts if v not in before])

    def _paint(self, bm, jit, ao, tint, ao_h, only=None):
        lay = self._layer(bm)
        verts = only if only is not None else list(bm.verts)
        ys = [v.co.y for v in verts]
        if not ys:
            return
        y0, y1 = min(ys), max(ys)
        span = max(ao_h if ao_h else (y1 - y0), 1e-4)
        base = 1.0 - self.rng.uniform(0.0, jit)
        for v in verts:
            h = clamp((v.co.y - y0) / span)
            a = 1.0 - ao * (1.0 - h) ** 1.6
            n = 1.0 - self.rng.uniform(0.0, 0.025)
            k = base * a * n
            v[lay] = (clamp(k * tint[0]), clamp(k * tint[1]), clamp(k * tint[2]), 1.0)

    def part(self, pname, bm, matname, bevel=0.0, bseg=2, sub=0, crease=0.0, jit=0.1, ao=0.25, tint=(1, 1, 1),
             ao_h=None, smooth=True, parent=None, keep_name=False, paint=True, recalc=True, solid=0.0):
        if crease:
            lay = bm.edges.layers.float.get("crease_edge") or bm.edges.layers.float.new("crease_edge")
            for e in bm.edges:
                e[lay] = crease
        if paint:
            self._paint(bm, jit, ao, tint, ao_h)
        else:
            self._layer(bm)
        bm.transform(CONV)
        if recalc:
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        nm = pname if keep_name else f"{self.name}_{pname}"
        me = bpy.data.meshes.new(nm)
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = smooth
        me.uv_layers.new(name="UVMap")
        if "Col" in me.color_attributes:
            me.color_attributes.active_color = me.color_attributes["Col"]
            me.color_attributes.render_color_index = me.color_attributes.find("Col")
        me.materials.append(self.M[matname])
        ob = bpy.data.objects.new(nm, me)
        bpy.context.scene.collection.objects.link(ob)
        ob.parent = parent or self.root
        if solid:
            md = ob.modifiers.new("Solidify", "SOLIDIFY")
            md.thickness = solid
            md.offset = -1.0
            md.use_even_offset = True
        if bevel:
            md = ob.modifiers.new("Bevel", "BEVEL")
            md.width = bevel
            md.segments = bseg
            md.limit_method = "ANGLE"
            md.angle_limit = math.radians(32)
        if sub:
            md = ob.modifiers.new("Subdivision", "SUBSURF")
            md.levels = sub
            md.render_levels = sub
        self.objs.append(ob)
        return ob

    def point(self, pname, loc, kind="ARROWS", size=0.15):
        e = empty(pname, G(*loc), parent=self.root, kind=kind, size=size)
        self.empties.append(e)
        return e

    def bounds_godot(self):
        bpy.context.view_layer.update()
        lo = Vector((1e9,) * 3)
        hi = Vector((-1e9,) * 3)
        deps = bpy.context.evaluated_depsgraph_get()
        for o in self.objs:
            ev = o.evaluated_get(deps)
            for c in ev.bound_box:
                w = ev.matrix_world @ Vector(c)
                g = Vector((w.x, w.z, -w.y))
                lo = Vector(map(min, lo, g))
                hi = Vector(map(max, hi, g))
        return lo, hi

    def finish(self, glb_dir, info, offset=None):
        """Exporta GLB (so este ativo) e desloca o ativo para a vitrine do .blend."""
        bpy.context.view_layer.update()
        lo, hi = self.bounds_godot()
        tris = tri_count(self.objs)
        mats = sorted({m.name for o in self.objs for m in o.data.materials})
        glb = os.path.join(glb_dir, self.name.lower() + ".glb")
        os.makedirs(glb_dir, exist_ok=True)
        bpy.ops.object.select_all(action="DESELECT")
        for o in [self.root] + self.objs + self.empties:
            o.select_set(True)
        bpy.context.view_layer.objects.active = self.root
        kw = dict(filepath=glb, export_format="GLB", use_selection=True, export_yup=True, export_apply=True,
                  export_materials="EXPORT", export_cameras=False, export_lights=False, export_extras=False,
                  export_vertex_color="ACTIVE", export_normals=True)
        bpy.ops.export_scene.gltf(**kw)
        info[self.name.lower()] = {
            "glb": os.path.relpath(glb, REPO).replace("\\", "/"),
            "tris": tris, "materials": mats,
            "bbox_min": [round(c, 3) for c in lo], "bbox_max": [round(c, 3) for c in hi],
            "size": [round(hi[i] - lo[i], 3) for i in range(3)],
            "objects": sorted(o.name for o in self.objs), "empties": sorted(e.name for e in self.empties),
        }
        w = (hi.x - lo.x)
        step = offset if offset is not None else max(w, 1.0) + 1.5
        self.root.location = (Asset.X_CURSOR + w * 0.5, 0, 0)   # vitrine do .blend (nao afeta o GLB)
        Asset.X_CURSOR += step
        return info[self.name.lower()]


def save_all(blend, info, info_path):
    os.makedirs(os.path.dirname(blend), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=blend)
    with open(info_path, "w", encoding="utf-8") as f:
        json.dump(info, f, indent=2)
    tot = sum(v["tris"] for v in info.values())
    print("ENV_INFO", os.path.basename(blend), "ativos=%d" % len(info), "tris=%d" % tot)
