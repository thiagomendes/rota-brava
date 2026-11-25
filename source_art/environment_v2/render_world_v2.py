"""Rota Brava · Mundo v2 (RB-R1 W1) · imagens da malha (Workbench do Blender, cor de vertice + aramado).
Chamado por build_world_v2.py com --renders. Saida fora do Git: captures/mundo_v2/blender/. PROVISORIO.
"""
import math
import os

import bpy
from mathutils import Vector


def _wire_copy(ob, thick):
    me = ob.data.copy()
    ca = me.color_attributes.get("Color")
    if ca is not None:
        n = len(ca.data)
        ca.data.foreach_set("color", [0.02, 0.02, 0.025, 1.0] * n)
    w = bpy.data.objects.new(ob.name + "_wire", me)
    w.matrix_world = ob.matrix_world.copy()
    bpy.context.scene.collection.objects.link(w)
    mod = w.modifiers.new("wire", "WIREFRAME")
    mod.thickness = thick
    mod.use_replace = True
    mod.use_even_offset = False
    return w


def _setup(sc, w, h):
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x = w
    sc.render.resolution_y = h
    sc.render.resolution_percentage = 100
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "VERTEX"
    sc.display.shading.show_shadows = True
    sc.display.shading.show_cavity = True
    sc.display.shading.cavity_type = "WORLD"
    sc.display_settings.display_device = "sRGB"
    sc.view_settings.view_transform = "Standard"
    sc.world = sc.world or bpy.data.worlds.new("W")
    sc.render.film_transparent = False
    sc.display.shading.background_type = "VIEWPORT"
    sc.display.shading.background_color = (0.93, 0.94, 0.96)
    sc.render.image_settings.file_format = "PNG"


def _camera(sc, loc, target, lens=35.0, ortho=None):
    cam = bpy.data.cameras.new("cam")
    if ortho:
        cam.type = "ORTHO"
        cam.ortho_scale = ortho
    cam.lens = lens
    cam.clip_end = 2000
    ob = bpy.data.objects.new("cam", cam)
    sc.collection.objects.link(ob)
    ob.location = loc
    d = Vector(target) - Vector(loc)
    ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    sc.camera = ob
    return ob


def G(x, y, z):
    return (x, -z, y)


def render_all(statics, kit_objs, out_dir, boat_objs=()):
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    _setup(sc, 1800, 1000)
    hidden = [o for o in sc.objects if o.type == "MESH"]
    # 1) kit em grade com aramado
    for o in hidden:
        o.hide_render = True
    cols = 9
    for i, ob in enumerate(kit_objs):
        r, c = divmod(i, cols)
        span = 1.0 if ob.dimensions.x < 1.6 else 2.2
        ob.location = (c * 2.6, -r * 3.2, 0)
        sc_ = min(1.0, 2.2 / max(ob.dimensions.x, ob.dimensions.y, ob.dimensions.z, 0.01))
        ob.scale = (sc_, sc_, sc_)
        ob.hide_render = False
        bpy.context.view_layer.update()
        _wire_copy(ob, 0.004 / sc_).hide_render = False
    rows = (len(kit_objs) + cols - 1) // cols
    cx, cy = (cols - 1) * 2.6 / 2, -(rows - 1) * 3.2 / 2
    _camera(sc, (cx + 2, cy - 15, 10), (cx, cy - 0.5, 0.3), lens=36)
    sc.render.filepath = os.path.join(out_dir, "malha_kit.png")
    bpy.ops.render.render(write_still=True)
    for ob in kit_objs:
        ob.hide_render = True
        ob.scale = (1, 1, 1)
    for o in list(sc.objects):
        if o.name.endswith("_wire"):
            bpy.data.objects.remove(o)
    # 2) rua das casas + cais (estatico) com aramado
    for ob in statics:
        if ob.name in ("wv2_street", "wv2_dock", "wv2_quay"):
            ob.hide_render = False
            _wire_copy(ob, 0.004).hide_render = False
    _camera(sc, G(12.0, 9.0, 4.0), G(-2.0, 3.0, -17.0), lens=32)
    sc.render.filepath = os.path.join(out_dir, "malha_rua_cais.png")
    bpy.ops.render.render(write_still=True)
    _camera(sc, G(-6.5, 4.5, -11.5), G(-11.5, 4.0, -17.8), lens=40)
    sc.render.filepath = os.path.join(out_dir, "malha_fachada_close.png")
    bpy.ops.render.render(write_still=True)
    for o in list(sc.objects):
        if o.name.endswith("_wire"):
            bpy.data.objects.remove(o)
    # 3) vista aerea do recorte inteiro (sem aramado)
    for ob in statics:
        ob.hide_render = False
    _camera(sc, G(30.0, 55.0, 40.0), G(-4.0, 0.0, -6.0), lens=30)
    sc.render.filepath = os.path.join(out_dir, "recorte_aereo.png")
    bpy.ops.render.render(write_still=True)
    # 4) barco v2 com aramado (fora do mapa, na origem)
    for o in sc.objects:
        if o.type == "MESH":
            o.hide_render = True
    for ob in boat_objs:
        if ob.type != "MESH":
            continue
        if ob.parent is None:
            ob.location = (0.0, 0.0, 0.0)
            ob.rotation_euler = (0.0, 0.0, 0.0)
        ob.hide_render = False
    bpy.context.view_layer.update()
    for ob in boat_objs:
        if ob.type == "MESH":
            _wire_copy(ob, 0.003).hide_render = False
    _camera(sc, G(4.2, 3.0, 3.6), G(0.0, 0.6, -0.4), lens=35)
    sc.render.filepath = os.path.join(out_dir, "malha_barco.png")
    bpy.ops.render.render(write_still=True)
