"""Rota Brava · pecas v3 · imagens da malha (Workbench do Blender: cor de vertice + aramado).
Chamado por build_props_v3.py com --renders, DEPOIS de exportar e salvar o .blend (move as pecas so para a foto).
Saida fora do Git: captures/props_v3/blender/.
"""
import os

import bpy
from mathutils import Vector


def _wire_copy(ob, thick):
    me = ob.data.copy()
    ca = me.color_attributes.get("Color")
    if ca is not None:
        ca.data.foreach_set("color", [0.02, 0.02, 0.025, 1.0] * len(ca.data))
    w = bpy.data.objects.new(ob.name + "_wire", me)
    w.matrix_world = ob.matrix_world.copy()
    bpy.context.scene.collection.objects.link(w)
    if ob.parent is not None and ob.parent.type == "ARMATURE":
        w.parent = ob.parent
        w.matrix_parent_inverse = ob.matrix_parent_inverse.copy()
        arm = w.modifiers.new("Armature", "ARMATURE")
        arm.object = ob.parent
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
    sc.display.shading.show_shadows = False
    sc.display.shading.show_cavity = True
    sc.display.shading.cavity_type = "WORLD"
    sc.display_settings.display_device = "sRGB"
    sc.view_settings.view_transform = "Standard"
    sc.world = sc.world or bpy.data.worlds.new("W")
    sc.render.film_transparent = False
    sc.display.shading.background_type = "VIEWPORT"
    sc.display.shading.background_color = (0.93, 0.94, 0.96)
    sc.render.image_settings.file_format = "PNG"


def _camera(sc, loc, target, lens=50.0, ortho=None):
    cam = bpy.data.cameras.new("cam")
    if ortho:
        cam.type = "ORTHO"
        cam.ortho_scale = ortho
    cam.lens = lens
    cam.clip_end = 200
    ob = bpy.data.objects.new("cam", cam)
    sc.collection.objects.link(ob)
    ob.location = loc
    d = Vector(target) - Vector(loc)
    ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    sc.camera = ob
    return ob


def render_all(mesh_objs, rig, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    _setup(sc, 2000, 1250)
    cols = 6
    cell = 0.95
    statics = [o for o in mesh_objs if o.parent is None]
    gull = [o for o in mesh_objs if o.parent is not None]
    # pecas agrupadas por colecao (a corda e o pulso tem 2 objetos)
    groups = {}
    for o in statics:
        groups.setdefault(o.users_collection[0].name, []).append(o)
    names = list(groups.keys())
    for i, nm in enumerate(names):
        r, c = divmod(i, cols)
        obs = groups[nm]
        size = max(max(o.dimensions) for o in obs)
        k = min(1.6, 0.8 / max(size, 0.01))
        for j, o in enumerate(obs):
            o.scale = (k, k, k)
            o.location = (c * cell + (0.0 if j == 0 else 0.35 * k), -r * cell * 1.1, 0.05 + (0.0 if j == 0 else 0.0))
            if nm.startswith(("cloth", "help")):
                o.location.z += 0.45
            if nm.startswith("emblem"):
                o.location.z += 0.25
        bpy.context.view_layer.update()
        for o in obs:
            _wire_copy(o, 0.0022 / k)
    for o in gull:
        o.hide_render = True
    rows = (len(names) + cols - 1) // cols
    cx, cy = (cols - 1) * cell / 2, -(rows - 1) * cell * 1.1 / 2
    _camera(sc, (cx, cy - 7.5, 2.6), (cx, cy, 0.35), lens=40)
    sc.render.filepath = os.path.join(out_dir, "malha_pecas.png")
    bpy.ops.render.render(write_still=True)
    # gaivota: pose de repouso (asas abertas) e pose de poleiro (quadro 0 da acao perch_idle), com aramado
    for o in sc.objects:
        if o.type == "MESH":
            o.hide_render = True
    for o in gull:
        o.hide_render = False
        _wire_copy(o, 0.0018).hide_render = False
    rig.location = (0, 0, 0)
    _setup(sc, 1600, 1000)
    _camera(sc, (1.25, -1.35, 1.05), (0.0, 0.0, 0.28), lens=50)
    sc.render.filepath = os.path.join(out_dir, "malha_gaivota_repouso.png")
    bpy.ops.render.render(write_still=True)
    act = bpy.data.actions.get("perch_idle")
    if act is not None:
        rig.animation_data.action = act
        sc.frame_set(0)
        _camera(sc, (0.9, -1.0, 0.7), (0.0, 0.0, 0.25), lens=50)
        sc.render.filepath = os.path.join(out_dir, "malha_gaivota_poleiro.png")
        bpy.ops.render.render(write_still=True)
        rig.animation_data.action = None
