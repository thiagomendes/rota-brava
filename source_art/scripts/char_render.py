"""Renders de verificacao dos personagens (RB-04-chars). Imagens ficam em captures/rb-04/chars (fora do Git).

Uso: tools/blender.ps1 --background --factory-startup --python source_art/scripts/char_render.py -- --id rastro --out DIR
        --mode views|expr|poses|walk|touch|mesh|anim:<clip>:<frames,..>
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector

from rbart import REPO, arg_value, ortho_camera, render_to, setup_workbench

CID = arg_value("--id", "rastro")
OUT = os.path.abspath(arg_value("--out", os.path.join(REPO, "captures", "rb-04", "chars")))
MODE = arg_value("--mode", "views")
ENGINE = arg_value("--engine", "EEVEE")


def open_char():
    bpy.ops.wm.open_mainfile(filepath=arg_value("--blend", os.path.join(REPO, "source_art", "characters", "rb04", CID, CID + ".blend")))
    sc = bpy.context.scene
    rig = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    if "--rest" in sys.argv:
        rig.animation_data.use_nla = False
        for pb in rig.pose.bones:
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = (1, 0, 0, 0)
            pb.location = (0, 0, 0)
        for ob in bpy.data.objects:
            if ob.type == "MESH" and ob.data.shape_keys and ob.data.shape_keys.animation_data:
                ob.data.shape_keys.animation_data.use_nla = False
        bpy.context.view_layer.update()
    elif "idle" in bpy.data.actions:
        set_pose(rig, "idle", 0)
    return sc, rig


def setup(sc, w, h):
    if ENGINE == "EEVEE":
        sc.render.engine = "BLENDER_EEVEE_NEXT"
        sc.render.resolution_x, sc.render.resolution_y = w, h
        sc.render.resolution_percentage = 100
        sc.render.image_settings.file_format = "PNG"
        sc.view_settings.view_transform = "Standard"
        sc.eevee.taa_render_samples = 24
        if sc.world is None:
            sc.world = bpy.data.worlds.new("w")
        sc.world.use_nodes = True
        bg = sc.world.node_tree.nodes["Background"]
        bg.inputs[0].default_value = (0.78, 0.86, 0.92, 1)
        bg.inputs[1].default_value = 0.6
        for name, loc, rot, en in (("key", (2.5, 3, 4), (math.radians(50), 0, math.radians(145)), 1.8),
                                   ("fill", (-3, -2, 2), (math.radians(70), 0, math.radians(-30)), 0.6)):
            ld = bpy.data.lights.new(name, "SUN")
            ld.energy = en
            ld.color = (1.0, 0.92, 0.8) if name == "key" else (0.7, 0.8, 1.0)
            lo = bpy.data.objects.new(name, ld)
            sc.collection.objects.link(lo)
            lo.rotation_euler = rot
    else:
        setup_workbench(sc, w, h, color_type="MATERIAL", light="STUDIO", bg=(0.85, 0.9, 0.95))


def cam(sc, loc, target, scale=None, persp_lens=None):
    c = bpy.data.cameras.new("cam")
    if persp_lens:
        c.lens = persp_lens
    else:
        c.type = "ORTHO"
        c.ortho_scale = scale
    co = bpy.data.objects.new("cam", c)
    sc.collection.objects.link(co)
    co.location = loc
    co.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.camera = co
    return co


def set_pose(rig, clip, frame):
    rig.animation_data.use_nla = False
    rig.animation_data.action = bpy.data.actions[clip]
    for ob in bpy.data.objects:
        if ob.type == "MESH" and ob.data.shape_keys and ob.data.shape_keys.animation_data:
            ob.data.shape_keys.animation_data.use_nla = False
            ob.data.shape_keys.animation_data.action = bpy.data.actions.get(clip + "_key")
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()

def set_expr(name):
    for ob in bpy.data.objects:
        if ob.type == "MESH" and ob.data.shape_keys:
            if ob.data.shape_keys.animation_data:
                ob.data.shape_keys.animation_data.action = None
            for kb in ob.data.shape_keys.key_blocks:
                if kb.name != "Basis":
                    kb.value = 1.0 if kb.name == name and name != "neutra" else 0.0


def clones(rig, offsets):
    """Nao clona: usa um unico personagem; esta funcao existe so para marcar a intencao."""
    return rig


def shot(sc, path, w, h):
    setup(sc, w, h)
    render_to(sc, path)


def mode_views():
    sc, rig = open_char()
    set_expr("neutra")
    base = os.path.join(OUT, CID)
    for nm, loc in (("frente", (0, 5, 0.65)), ("lado", (5, 0, 0.65)), ("costas", (0, -5, 0.65))):
        c = cam(sc, loc, (0, 0, 0.65), scale=1.6)
        shot(sc, base + "_" + nm + ".png", 480, 640)
        bpy.data.objects.remove(c)
    c = cam(sc, (1.8, 2.2, 1.1), (0, 0, 0.62), persp_lens=50)
    shot(sc, base + "_persp.png", 640, 640)


def mode_expr():
    sc, rig = open_char()
    if "--nohat" in sys.argv:
        for ob in bpy.data.objects:
            if "Hat" in ob.name:
                ob.hide_render = True
    base = os.path.join(OUT, CID)
    c = cam(sc, (0, 2.2, 1.06), (0, 0, 1.06), scale=0.55)
    for ex in ("neutra", "atenta", "surpresa", "alegre", "blink"):
        set_expr(ex)
        shot(sc, base + "_expr_" + ex + ".png", 400, 400)


def mode_clip():
    # --mode clip --clip walk --frames 0,5,10 --view lado
    sc, rig = open_char()
    clip = arg_value("--clip")
    frames = [int(x) for x in arg_value("--frames").split(",")]
    view = arg_value("--view", "lado")
    scale = float(arg_value("--scale", "1.8"))
    base = os.path.join(OUT, "%s%s_%s_%s" % (CID, arg_value("--tag", ""), clip, view))
    locs = {"lado": (5, 0, 0.65), "frente": (0, 5, 0.65), "costas": (0, -5, 0.65), "tres": (3.5, 3.5, 0.9)}
    for fr in frames:
        set_pose(rig, clip, fr)
        c = cam(sc, locs[view], (0, 0, float(arg_value("--zc", "0.65"))), scale=scale)
        shot(sc, base + "_f%03d.png" % fr, 360, 480)
        bpy.data.objects.remove(c)


def mode_face():
    sc, rig = open_char()
    set_expr("neutra")
    c = cam(sc, (0.5, 1.4, 1.15), (0, 0, 1.04), persp_lens=85)
    shot(sc, os.path.join(OUT, CID + "_rosto_persp.png"), 600, 600)


def mode_extremes():
    """Poses extremas por FK (ombro erguido, cotovelo dobrado, joelho dobrado, quadril, pescoco, agachada) para checar deformacao."""
    import char_lib as cl
    from char_lib import eul
    sc, rig = open_char()
    rig.animation_data.use_nla = False
    rig.animation_data.action = None
    for ob in bpy.data.objects:
        if ob.type == "MESH" and ob.data.shape_keys and ob.data.shape_keys.animation_data:
            ob.data.shape_keys.animation_data.action = None
    R = cl.Rigger(rig)
    cases = {
        "ombro": lambda: (R.rel("upper_arm.R", eul(y=-150)), R.rel("upper_arm.L", eul(x=100, y=-20))),
        "cotovelo": lambda: (R.rel("upper_arm.R", eul(x=60)), R.rel("forearm.R", eul(x=130)), R.rel("upper_arm.L", eul(x=60)), R.rel("forearm.L", eul(x=130))),
        "joelho": lambda: (R.rel("thigh.R", eul(x=95)), R.rel("shin.R", eul(x=-125)), R.rel("foot.R", eul(x=30))),
        "quadril": lambda: (R.rel("thigh.R", eul(x=85, y=-25)), R.rel("thigh.L", eul(x=-30, y=20)), R.rel("spine", eul(x=-35)), R.rel("chest", eul(x=-25))),
        "pescoco": lambda: (R.rel("neck", eul(x=-20, z=35, y=15)), R.rel("head", eul(x=-15, z=40, y=15))),
        "tronco": lambda: (R.rel("spine", eul(x=-40, z=25)), R.rel("chest", eul(x=-30, z=25, y=10))),
    }
    base = os.path.join(OUT, CID + "_extremo_")
    views = (("frente", (0, 5, 0.65)), ("lado", (5, 0, 0.65)))
    for name, fn in cases.items():
        R.reset()
        fn()
        R.apply(1)
        bpy.context.scene.frame_set(1)
        bpy.context.view_layer.update()
        for vn, loc in views:
            c = cam(sc, loc, (0, 0, 0.65), scale=1.7)
            shot(sc, base + name + "_" + vn + ".png", 360, 460)
            bpy.data.objects.remove(c)

def mode_mesh():
    """Imagem da malha: modificador Wireframe + material unico; frente e rosto/cabeca."""
    sc, rig = open_char()
    set_expr("neutra")
    dark = bpy.data.materials.new("wire")
    dark.diffuse_color = (0.05, 0.08, 0.15, 1)
    dark.use_nodes = True
    dark.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.05, 0.08, 0.15, 1)
    dark.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1.0
    sc.view_layers[0].material_override = dark
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            w = ob.modifiers.new("wf", "WIREFRAME")
            w.thickness = 0.0016
            w.use_replace = True
    c = cam(sc, (0, 5, 0.65), (0, 0, 0.65), scale=1.5)
    shot(sc, os.path.join(OUT, CID + "_malha.png"), 900, 1100)
    bpy.data.objects.remove(c)
    c = cam(sc, (0.6, 1.6, 1.12), (0, 0, 1.05), persp_lens=85)
    shot(sc, os.path.join(OUT, CID + "_malha_rosto.png"), 900, 900)

{"views": mode_views, "expr": mode_expr, "clip": mode_clip, "mesh": mode_mesh, "face": mode_face, "extremes": mode_extremes}[MODE]()









