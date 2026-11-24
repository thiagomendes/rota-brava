"""Estudos de direcao do porto/vila Farol 7 (RB-R1, Portao 1). Eevee, luz e paleta de docs/style-bible.md.
Monta as composicoes A (vila na encosta) e B (vila na orla) com os GLB do projeto (game/assets/models/environment),
renderiza na camera de jogo (3/4 alta, FOV vertical 55, alvo no cais, offset (0, 4.6, 6.2), olhar +1 m) e num plano aberto.
--map: renderiza o diagrama de cima do mapa completo (layout de game/episodes/ep01/world/LAYOUT_PROPOSTO.md).
Uso: blender --background --factory-startup --python study_village.py -- --comp A|B|MAP --out DIR [--size 1280x720] [--samples 32]
Coordenadas no espaco da Godot (x leste, y cima, z sul); convertidas por G(). ESTUDO PROVISORIO.
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "source_art", "scripts"))
import bpy
from mathutils import Vector
from rbart import arg_value, hex_to_linear

GLB = os.path.join(REPO, "game", "assets", "models", "environment")
sys.path.insert(0, os.path.join(REPO, "source_art", "environment"))
import village_layout as VL  # noqa: E402


def G(x, y, z):
    return Vector((x, -z, y))


# ------------------------------------------------------------------ cena
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


_kit = {}


WALLS = {"peach": "#FFC9A3", "mint": "#BDEBD3", "sky": "#BFE3FF", "lemon": "#FFF0A8", "rose": "#FFC6D3"}
ROOFS = {"terracotta": "#D8693F", "blue": "#3A7BD5"}


def kit(id_, wall=None, roof=None):
    key = id_ + (("_" + wall) if wall else "") + (("_" + roof) if roof else "")
    if key in _kit:
        return _kit[key]
    col = bpy.data.collections.new("K_" + key)
    bpy.context.scene.collection.children.link(col)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(GLB, id_ + ".glb"))
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        for c in o.users_collection:
            c.objects.unlink(o)
        col.objects.link(o)
        if o.type == "MESH":
            if wall and o.name.split(".")[0].endswith("_Wall"):
                o.data = o.data.copy()
                o.data.materials[0] = mat("w_" + wall, WALLS[wall], 0.85)
            if roof and o.name.split(".")[0].endswith(("_Roof", "_RoofTiles")):
                o.data = o.data.copy()
                o.data.materials[0] = mat("r_" + roof, ROOFS[roof], 0.7)
            _wire_vcol(o)
            if id_ in ("cloud", "seagull", "hills_far"):
                o.visible_shadow = False
    bpy.context.view_layer.layer_collection.children[col.name].exclude = True
    _kit[key] = col
    return col


def _wire_vcol(o):
    if not o.data.color_attributes:
        return
    name = o.data.color_attributes[0].name
    for m in o.data.materials:
        if m is None or m.get("_vc"):
            continue
        m["_vc"] = True
        nt = m.node_tree
        b = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if b is None:
            continue
        vc = nt.nodes.new("ShaderNodeVertexColor")
        vc.layer_name = name
        mul = nt.nodes.new("ShaderNodeMix")
        mul.data_type = "RGBA"
        mul.blend_type = "MULTIPLY"
        mul.inputs[0].default_value = 1.0
        inp = b.inputs["Base Color"]
        if inp.links:
            nt.links.new(inp.links[0].from_socket, mul.inputs[6])
        else:
            mul.inputs[6].default_value = inp.default_value
        nt.links.new(vc.outputs["Color"], mul.inputs[7])
        nt.links.new(mul.outputs[2], inp)


def inst(id_, x, y, z, ry=0.0, s=1.0, extra=None):
    e = bpy.data.objects.new(id_, None)
    e.instance_type = "COLLECTION"
    e.instance_collection = kit(id_, (extra or {}).get("wall"), (extra or {}).get("roof"))
    e.location = G(x, y, z)
    e.rotation_euler = (0, 0, math.radians(ry))
    e.scale = (s, s, s) if not isinstance(s, tuple) else (s[0], s[2], s[1])
    bpy.context.scene.collection.objects.link(e)
    return e


def mat(name, hx, rough=0.8, emit=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = hex_to_linear(hx) + (1,)
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = hex_to_linear(hx) + (1,)
        b.inputs["Emission Strength"].default_value = emit
    return m


def water():
    bpy.ops.mesh.primitive_plane_add(size=1, location=G(40, VL.WATER_Y, -20))
    o = bpy.context.object
    o.scale = (600, 400, 1)
    m = bpy.data.materials.new("water_study")
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs[0].default_value = 0.35
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = hex_to_linear("#3FC4BC") + (1,)
    ramp.color_ramp.elements[1].color = hex_to_linear("#1A7A8C") + (1,)
    nt.links.new(lw.outputs["Facing"], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.12
    b.inputs["Specular IOR Level"].default_value = 0.6
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.inputs["Scale"].default_value = 0.6
    wave.inputs["Distortion"].default_value = 6.0
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.08
    nt.links.new(wave.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    o.data.materials.append(m)


def blob(name, x, y, z, sx, sy, sz, hx, rough=0.9):
    """Massa de terra/rocha simples para o estudo (elipsoide)."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, location=G(x, y, z))
    o = bpy.context.object
    o.name = name
    o.scale = (sx, sz, sy)
    bpy.ops.object.shade_smooth()
    o.data.materials.append(mat(name, hx, rough))
    return o


def slab(name, x0, x1, z0, z1, y_top, depth, hx):
    bpy.ops.mesh.primitive_cube_add(size=1, location=G((x0 + x1) / 2, y_top - depth / 2, (z0 + z1) / 2))
    o = bpy.context.object
    o.name = name
    o.scale = (x1 - x0, z1 - z0, depth)
    bev = o.modifiers.new("b", "BEVEL")
    bev.width = 0.25
    bev.segments = 3
    o.data.materials.append(mat(name, hx, 0.95))
    return o


def kid(x, z, hx="#FF8A1F"):
    """Personagem-escala 1,10 m (silhueta simples, NAO e o heroi final)."""
    m = mat("kid_" + hx, hx, 0.6)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.2, depth=0.62, location=G(x, 0.42, z))
    bpy.context.object.data.materials.append(m)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.22, location=G(x, 0.88, z))
    bpy.ops.object.shade_smooth()
    bpy.context.object.data.materials.append(mat("kid_skin", "#C98A5E", 0.6))
    bpy.ops.mesh.primitive_cylinder_add(radius=0.34, depth=0.05, location=G(x, 1.02, z))
    bpy.context.object.data.materials.append(mat("kid_hat", "#E8D2A6", 0.7))
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.18, location=G(x, 1.06, z))
    bpy.context.object.scale = (1, 1, 0.6)
    bpy.context.object.data.materials.append(mat("kid_hat", "#E8D2A6", 0.7))
    for sx in (-0.09, 0.09):
        bpy.ops.mesh.primitive_cylinder_add(radius=0.07, depth=0.2, location=G(x + sx, 0.1, z))
        bpy.context.object.data.materials.append(mat("kid_boot", "#6A4A35", 0.7))


def world_light():
    sc = bpy.context.scene
    w = bpy.data.worlds.new("sky")
    sc.world = w
    w.use_nodes = True
    nt = w.node_tree
    bg = nt.nodes["Background"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = hex_to_linear("#FDE9C9") + (1,)
    ramp.color_ramp.elements[1].position = 0.3
    ramp.color_ramp.elements[1].color = hex_to_linear("#4FA6E8") + (1,)
    el = ramp.color_ramp.elements.new(0.035)
    el.color = hex_to_linear("#B9DDF5") + (1,)
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 0.8
    sun = bpy.data.lights.new("sun", "SUN")
    sun.color = hex_to_linear("#FFE6BE")
    sun.energy = 4.2
    sun.angle = math.radians(3.0)
    so = bpy.data.objects.new("sun", sun)
    sc.collection.objects.link(so)
    # ~45 graus de elevacao, vindo do sudeste (por tras-direita da camera): fachadas sul iluminadas
    so.rotation_euler = (math.radians(45), 0, math.radians(35))
    fill = bpy.data.lights.new("fill", "SUN")
    fill.color = hex_to_linear("#BFD8FF")
    fill.energy = 0.6
    fo = bpy.data.objects.new("fill", fill)
    sc.collection.objects.link(fo)
    fo.rotation_euler = (math.radians(60), 0, math.radians(200))
    ee = sc.eevee
    for k, v in (("taa_render_samples", int(arg_value("--samples", "32"))), ("use_shadows", True),
                 ("use_raytracing", True), ("shadow_ray_count", 2), ("fast_gi_method", "GLOBAL_ILLUMINATION"),
                 ("use_fast_gi", True)):
        if hasattr(ee, k):
            try:
                setattr(ee, k, v)
            except Exception:
                pass
    sc.view_settings.view_transform = "AgX"
    try:
        sc.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    sc.view_settings.exposure = 0.35
    # nevoa de distancia (volume leve no mundo)
    if not arg_value("--fog"):
        return
    vol = nt.nodes.new("ShaderNodeVolumePrincipled")
    vol.inputs["Density"].default_value = 0.0025
    vol.inputs["Color"].default_value = hex_to_linear("#DDEBF2") + (1,)
    nt.links.new(vol.outputs[0], nt.nodes["World Output"].inputs["Volume"])
    if hasattr(ee, "volumetric_end"):
        ee.volumetric_end = 400.0


def camera(name, eye, target, fov=55.0):
    c = bpy.data.cameras.new(name)
    c.sensor_fit = "VERTICAL"
    c.angle_y = math.radians(fov)
    c.clip_end = 1500
    o = bpy.data.objects.new(name, c)
    bpy.context.scene.collection.objects.link(o)
    o.location = G(*eye)
    o.rotation_euler = (G(*target) - o.location).to_track_quat("-Z", "Y").to_euler()
    return o


def render(cam, path, size):
    sc = bpy.context.scene
    sc.camera = cam
    w, h = [int(v) for v in size.split("x")]
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.resolution_percentage = 100
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("RENDER_OK", path)


def build(placements):
    for p in placements:
        inst(*p)


def main():
    comp = arg_value("--comp", "A")
    out = arg_value("--out")
    size = arg_value("--size", "1280x720")
    reset()
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
    world_light()
    water()
    if comp == "MAP":
        VL.map_terrain(slab, blob)
        build(VL.common())
        build(VL.comp_B())
        build(VL.map_extra())
        c = bpy.data.cameras.new("top")
        c.type = "ORTHO"
        c.ortho_scale = 300
        c.clip_end = 2000
        o = bpy.data.objects.new("top", c)
        sc.collection.objects.link(o)
        for txt, lx, lz in VL.MAP_LABELS:
            cu = bpy.data.curves.new(txt, "FONT")
            cu.body = txt
            cu.size = 6.0
            cu.align_x = "CENTER"
            to = bpy.data.objects.new(txt, cu)
            sc.collection.objects.link(to)
            to.location = G(lx, 40, lz)
            to.visible_glossy = False
            to.visible_shadow = False
            to.data.materials.append(mat("label", "#123A5E", 0.9, emit=0.0))
        c.ortho_scale = 272
        o.location = G(86, 400, -2)
        o.rotation_euler = (0, 0, 0)
        render(o, os.path.join(out, "mapa_topo_base.png"), "2400x1350")
        return
    VL.terrain(comp, slab, blob)
    build(VL.common())
    build(VL.comp_A() if comp == "A" else VL.comp_B())
    kid(*VL.KID[:2])
    kid(1.6, -1.0, "#3DBE5A")
    tgt = VL.CAM_TARGET
    eye = (tgt[0] + 0.0, tgt[1] + 4.6, tgt[2] + 6.2)
    render(camera("cais", eye, (tgt[0], tgt[1] + 1.0, tgt[2])), os.path.join(out, "vila_%s.png" % comp), size)
    oe, ot = VL.OPEN_CAM[comp]
    render(camera("aberto", oe, ot), os.path.join(out, "vila_%s_aberto.png" % comp), size)
    if arg_value("--save"):
        bpy.ops.wm.save_as_mainfile(filepath=arg_value("--save"))


main()
