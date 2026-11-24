"""Estudos de direcao dos herois (RB-R1, Portao 1). Gera pranchas em captures/rb-r1/herois (fora do Git). PROVISORIO.

Uso: tools/blender.ps1 --background --factory-startup --python source_art/scripts/hero_studies.py -- --stage abc|trio
        [--variant C] [--out captures/rb-r1/herois] [--blend source_art/studies/heroes/X.blend]
abc : Rastro nas variacoes A, B e C (frente, 3/4, costas e a 48 px) -> estudo_rastro_ABC.png
trio: Rastro, Pico e Leme na variacao escolhida -> trio_pose_equipe.png, trio_lineup.png, trio_48px.png
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector

import char_lib as cl
import hero_lib
import hero_render as hr
from char_anim import reach
from rbart import REPO, arg_value, reset_scene

OUT = os.path.join(REPO, arg_value("--out", os.path.join("captures", "rb-r1", "herois")))
TMP = os.path.join(OUT, "_tmp")


def parent_all(objs, rig, name):
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    for o in ([rig] if rig else []) + [o for o in objs if o.parent is None]:
        o.parent = e
    return e


def set_face(b, key, w=1.0):
    kb = b.face_ob.data.shape_keys.key_blocks
    for k in kb[1:]:
        k.value = 0.0
    if key in kb:
        kb[key].value = w


def views_of(sc, root, tag, center_z, dist, size=(420, 560)):
    cam = hr.camera(sc, (0, 0, center_z), dist, 4.0, 0.0, 85.0)
    paths = []
    for vname, yaw in (("frente", 0.0), ("tres_quartos", -38.0), ("costas", 180.0)):
        root.rotation_euler = (0, 0, math.radians(yaw))
        sc.render.resolution_x, sc.render.resolution_y = size
        paths.append(hr.render(sc, os.path.join(TMP, "%s_%s.png" % (tag, vname))))
    # a 48 px: personagem com ~48 px de altura, ampliado sem filtro para a prancha
    root.rotation_euler = (0, 0, math.radians(-30.0))
    sc.render.resolution_x, sc.render.resolution_y = 56, 56
    p48 = hr.render(sc, os.path.join(TMP, "%s_48.png" % tag))
    hr.upscale_nearest(p48, os.path.join(TMP, "%s_48x.png" % tag), 10)
    paths.append(os.path.join(TMP, "%s_48x.png" % tag))
    return paths


def stage_abc():
    rows = []
    for var in ("A", "B", "C"):
        reset_scene()
        sc = hr.eevee_scene(420, 560)
        b = hero_lib.build_hero("rastro", var, with_rig=False)
        set_face(b, "alegre", 0.35)
        hr.toonify(b.objs)
        root = parent_all(b.objs, None, "Raiz")
        lo = min((o.matrix_world @ Vector(c)).z for o in b.objs for c in o.bound_box)
        hi = max((o.matrix_world @ Vector(c)).z for o in b.objs for c in o.bound_box)
        head = b.head_ob
        hz = [(head.matrix_world @ Vector(c)).z for c in head.bound_box]
        print("STUDY_INFO variante=%s altura=%.3f cabeca=%.3f razao=%.3f olho=%.3f" % (
            var, hi - lo, max(hz) - min(hz), (max(hz) - min(hz)) / (hi - lo), b.eye_info["R"]["ez"] * 2 / (max(hz) - min(hz))))
        rows.append(views_of(sc, root, "rastro_" + var, 0.57, 3.5))
        if arg_value("--blend"):
            p = arg_value("--blend").replace("{v}", var)
            os.makedirs(os.path.dirname(os.path.join(REPO, p)), exist_ok=True)
            bpy.ops.wm.save_as_mainfile(filepath=os.path.join(REPO, p))
    hr.compose(rows, os.path.join(OUT, "estudo_rastro_ABC.png"))


def pose(b, kind):
    R = cl.Rigger(b.rig)
    R.reset()
    F = b.F
    K = b.cfg["K"]
    sh = F.sh
    if kind == "rastro":   # punho erguido "vamos!", mao na cintura
        R.hips_off = Vector((0.0, 0.0, -0.01))
        R.rel("spine", cl.eul(x=-4, y=-3))
        R.rel("head", cl.eul(x=6, y=6, z=-8))
        reach(R, "R", Vector((sh.x + 0.25, 0.08, sh.z + 0.21)) * K, (0.3, 0.1, 1.0), pole=(1.0, -0.4, -0.4))
        reach(R, "L", Vector((-F.v["belly"] - 0.03, 0.03, F.hz + 0.03)) * K, (0.6, 0.2, -0.5), pole=(-1.0, -0.6, 0.0))
    elif kind == "pico":   # salto de alegria: punho para cima, outro punho cerrado a frente
        R.hips_off = Vector((0.0, 0.0, -0.015))
        R.rel("spine", cl.eul(x=-3, y=4))
        R.rel("head", cl.eul(x=8, y=-6, z=6))
        reach(R, "L", Vector((-sh.x - 0.10, 0.04, sh.z + 0.30)) * K, (-0.3, 0.1, 1.0), pole=(-1.0, -0.4, -0.4))
        reach(R, "R", Vector((sh.x + 0.03, 0.20, sh.z - 0.06)) * K, (0.0, 1.0, 0.3), pole=(1.0, -0.2, -1.0))
    else:                  # Leme: aceno aberto
        R.hips_off = Vector((0.0, 0.0, -0.01))
        R.rel("spine", cl.eul(x=-2, y=-4))
        R.rel("head", cl.eul(x=5, y=7, z=-6))
        reach(R, "R", Vector((sh.x + 0.20, 0.05, sh.z + 0.25)) * K, (0.35, 0.15, 1.0), pole=(1.0, -0.6, -0.5))
        R.rel("upper_arm.L", cl.eul(x=10, y=-6))
        R.rel("forearm.L", cl.eul(x=25))
    for s in ("R", "L"):
        R.rel("thigh." + s, cl.eul())
    R.apply(0, {})
    set_face(b, "alegre", 1.0)


def stage_trio(var):
    reset_scene()
    sc = hr.eevee_scene(1200, 760)
    heroes = {}
    for cid, x in (("pico", -0.62), ("rastro", 0.0), ("leme", 0.62)):
        b = hero_lib.build_hero(cid, var, with_rig=True)
        for o in b.objs:
            o.name = o.name   # nomes ja prefixados por personagem
        hr.toonify(b.objs)
        root = parent_all(b.objs, b.rig, "Raiz_" + cid)
        root.location.x = x
        heroes[cid] = (b, root)
    cam = hr.camera(sc, (0, 0, 0.56), 6.2, 4.0, 0.0, 70.0)
    # lineup frente e costas (pose neutra)
    for cid, (b, root) in heroes.items():
        set_face(b, "alegre", 0.3)
    hr.render(sc, os.path.join(TMP, "lineup_frente.png"))
    for cid, (b, root) in heroes.items():
        root.rotation_euler = (0, 0, math.pi)
    hr.render(sc, os.path.join(TMP, "lineup_costas.png"))
    hr.compose([[os.path.join(TMP, "lineup_frente.png")], [os.path.join(TMP, "lineup_costas.png")]], os.path.join(OUT, "trio_lineup.png"))
    # 48 px
    for cid, (b, root) in heroes.items():
        root.rotation_euler = (0, 0, math.radians(-25))
    sc.render.resolution_x, sc.render.resolution_y = 131, 83
    p = hr.render(sc, os.path.join(TMP, "trio_48.png"))
    hr.upscale_nearest(p, os.path.join(OUT, "trio_48px.png"), 8)
    # pose de equipe: camera mais baixa, levemente em 3/4
    sc.render.resolution_x, sc.render.resolution_y = 1200, 820
    for cid, (b, root) in heroes.items():
        pose(b, cid)
    heroes["pico"][1].location = (-0.60, 0.12, 0.0)
    heroes["leme"][1].location = (0.60, 0.10, 0.0)
    heroes["rastro"][1].location = (0.0, 0.25, 0.0)
    heroes["pico"][1].rotation_euler = (0, 0, math.radians(18))
    heroes["leme"][1].rotation_euler = (0, 0, math.radians(-18))
    heroes["rastro"][1].rotation_euler = (0, 0, 0)
    hr.place_view(cam, (0, 0.1, 0.60), 5.6, -2.0, -12.0)
    hr.render(sc, os.path.join(OUT, "trio_pose_equipe.png"))
    if arg_value("--blend"):
        p = os.path.join(REPO, arg_value("--blend"))
        os.makedirs(os.path.dirname(p), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=p)


def stage_face(var):
    reset_scene()
    sc = hr.eevee_scene(900, 450, ground=False)
    b = hero_lib.build_hero("rastro", var, with_rig=False)
    hr.toonify(b.objs)
    hc = b.F.hc
    cam = hr.camera(sc, (0, 0, hc.z), 1.25, 2.0, 0.0, 85.0)
    paths = []
    for key in ("neutra", "alegre", "surpresa", "triste", "brava_leve", "blink", "mouth_A", "mouth_E", "mouth_O", "mouth_M", "look_left", "look_up"):
        set_face(b, key, 1.0)
        sc.render.resolution_x, sc.render.resolution_y = 300, 300
        paths.append(hr.render(sc, os.path.join(TMP, "face_%s.png" % key)))
    hr.compose([paths[0:6], paths[6:12]], os.path.join(OUT, "rastro_rosto_%s.png" % var))


def stage_lineup(ids, name, spacing=0.75, center_z=0.85, dist=7.5):
    reset_scene()
    sc = hr.eevee_scene(1400, 800)
    n = len(ids)
    roots = []
    for i, cid in enumerate(ids):
        if cid == "pup":
            import pup_build
            b = pup_build.build_pup(with_rig=False)
        else:
            b = hero_lib.build_hero(cid, "A", with_rig=False)
        set_face(b, "alegre", 0.0)
        hr.toonify(b.objs)
        root = parent_all(b.objs, None, "Raiz_" + cid)
        root.location.x = (i - (n - 1) / 2) * spacing
        roots.append(root)
    hr.camera(sc, (0, 0, center_z), dist, 4.0, 0.0, 70.0)
    hr.render(sc, os.path.join(TMP, name + "_f.png"))
    for r in roots:
        r.rotation_euler = (0, 0, math.pi)
    hr.render(sc, os.path.join(TMP, name + "_c.png"))
    hr.compose([[os.path.join(TMP, name + "_f.png")], [os.path.join(TMP, name + "_c.png")]], os.path.join(OUT, name + ".png"))


stage = arg_value("--stage", "abc")
if stage == "lineup":
    stage_lineup(arg_value("--ids").split(","), arg_value("--name"), float(arg_value("--spacing", "0.75")),
                 float(arg_value("--cz", "0.85")), float(arg_value("--dist", "7.5")))
elif stage == "face":
    stage_face(arg_value("--variant", "C"))
elif stage == "abc":
    stage_abc()
else:
    stage_trio(arg_value("--variant", "C"))




