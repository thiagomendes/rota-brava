"""Imagens de revisao do Rastro final (RB-R1): malha (wireframe), poses extremas para pesos e quadros-chave dos clipes.
Saida em captures/rb-r1/herois (fora do Git). PROVISORIO.

Uso: tools/blender.ps1 --background --factory-startup --python source_art/scripts/hero_review.py -- [--out captures/rb-r1/herois]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector

import char_lib as cl
import hero_anim
import hero_build
import hero_render as hr
from char_anim import put_foot, reach, torso
from rbart import REPO, arg_value

OUT = os.path.join(REPO, arg_value("--out", os.path.join("captures", "rb-r1", "herois")))
TMP = os.path.join(OUT, "_tmp")


def mute_nla(rig, face):
    for ad in (rig.animation_data, face.data.shape_keys.animation_data):
        if ad:
            ad.action = None
            for tr in ad.nla_tracks:
                tr.mute = True


def solo_clip(rig, face, name):
    for ad in (rig.animation_data, face.data.shape_keys.animation_data):
        for tr in ad.nla_tracks:
            tr.mute = tr.name != name


def mesh_image(b, sc):
    """Wireframe sobre a malha solida (Workbench), frente e costas em repouso."""
    eng = sc.render.engine
    ground = bpy.data.objects.get("Chao")
    if ground:
        ground.hide_render = True
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "MATERIAL"
    sc.display.shading.background_type = "VIEWPORT"
    sc.display.shading.background_color = (1, 1, 1)
    wire = bpy.data.materials.new("wire")
    wire.diffuse_color = (0.08, 0.08, 0.12, 1)
    dups = []
    for o in b.objs:
        d = o.copy()
        d.data = o.data.copy()
        sc.collection.objects.link(d)
        d.data.materials.clear()
        d.data.materials.append(wire)
        if d.data.shape_keys:
            d.shape_key_clear()
        for m in list(d.modifiers):
            if m.type != "ARMATURE":
                d.modifiers.remove(m)
        w = d.modifiers.new("wire", "WIREFRAME")
        w.thickness = 0.0012
        w.use_replace = True
        w.use_even_offset = False
        dups.append(d)
    cam = hr.camera(sc, (0, 0, 0.56), 3.2, 4.0, 0.0, 85.0)
    sc.render.resolution_x, sc.render.resolution_y = 700, 900
    hr.render(sc, os.path.join(TMP, "malha_frente.png"))
    hr.place_view(cam, (0, 0, 0.56), 3.2, 4.0, 180.0)
    hr.render(sc, os.path.join(TMP, "malha_costas.png"))
    hr.place_view(cam, (0, 0, 0.80), 1.5, 4.0, -30.0)
    hr.render(sc, os.path.join(TMP, "malha_rosto.png"))
    hr.compose([[os.path.join(TMP, "malha_frente.png"), os.path.join(TMP, "malha_costas.png"), os.path.join(TMP, "malha_rosto.png")]],
               os.path.join(OUT, "rastro_malha.png"))
    for d in dups:
        bpy.data.objects.remove(d)
    bpy.data.objects.remove(cam)
    sc.render.engine = eng
    if ground:
        ground.hide_render = False


def extreme(R, F, kind):
    R.reset()
    if kind == "ombro":            # braco direito acima da cabeca, esquerdo aberto na horizontal
        reach(R, "R", Vector((F.sh.x + 0.05, 0.02, F.sh.z + 0.36)), (0.1, 0.0, 1.0), pole=(1.0, -0.5, 0.0))
        reach(R, "L", Vector((-F.sh.x - 0.36, 0.0, F.sh.z + 0.02)), (-1.0, 0.0, 0.0), pole=(0.0, -1.0, 0.0))
    elif kind == "cotovelo":       # cotovelos dobrados ao maximo, maos no ombro
        for s, sx in (("R", 1), ("L", -1)):
            reach(R, s, Vector((sx * (F.sh.x + 0.03), 0.06, F.sh.z + 0.02)), (0.0, 0.3, 1.0), pole=(sx * 0.3, -0.2, -1.0))
    elif kind == "joelho":         # perna direita erguida (joelho a 90+ graus)
        put_foot(R, "L", R.rest_head["heel.L"].y, 0.0, "heel")
        put_foot(R, "R", 0, 0.0, "heel", ankle=Vector((F.hip_x, 0.12, F.hz * 0.55)), pole=(0.0, 1.0, 0.0))
    elif kind == "pescoco":        # cabeca virada e inclinada
        torso(R, head_yaw=50.0, head_pitch=-20.0, head_roll=15.0)
        for s in ("R", "L"):
            put_foot(R, s, R.rest_head["heel." + s].y, 0.0, "heel")
    else:                          # agachada funda
        hero_anim.crouch_pose(R, F, 1.0, lean_max=40.0)
    R.apply(0, {})


def main():
    b = hero_build.build("rastro", hero_build.FINAL_VARIANT)
    sc = bpy.context.scene
    hr.eevee_scene(500, 640)
    mute_nla(b.rig, b.face_ob)
    sc.frame_set(0)
    mesh_image(b, sc)
    # poses extremas (toon)
    sc.render.resolution_x, sc.render.resolution_y = 500, 640
    hr.toonify(b.objs)
    cam = hr.camera(sc, (0, 0, 0.58), 3.6, 6.0, -25.0, 85.0)
    R = cl.Rigger(b.rig)
    paths = []
    for kind in ("ombro", "cotovelo", "joelho", "pescoco", "agachada"):
        b.rig.animation_data.action = bpy.data.actions.new("pose_" + kind)
        extreme(R, b.F, kind)
        sc.frame_set(0)
        paths.append(hr.render(sc, os.path.join(TMP, "extremo_%s.png" % kind)))
    hr.compose([paths], os.path.join(OUT, "rastro_poses_extremas.png"))
    # quadros-chave dos clipes
    b.rig.animation_data.action = None
    rows, row = [], []
    picks = [("idle", 75), ("walk", 8), ("run", 5), ("stop", 6), ("inspect_touch", 40), ("point", 18), ("wave", 22),
             ("celebrate", 14), ("team_pose", 30), ("react_surprise", 6), ("look_to_leme", 36), ("crouch", 30)]
    for name, fr in picks:
        solo_clip(b.rig, b.face_ob, name)
        sc.frame_set(fr)
        row.append(hr.render(sc, os.path.join(TMP, "clipe_%s.png" % name)))
        if len(row) == 6:
            rows.append(row)
            row = []
    hr.compose(rows, os.path.join(OUT, "rastro_clipes.png"))


main()
