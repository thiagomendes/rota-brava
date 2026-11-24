"""Provas da Leme v2 a partir do .blend: turnaround com luz de cena (frente, tres-quartos, costas), close do rosto,
camera baixa de heroi, prancha de poses dos clipes (com vista FRONTAL do walk/run mostrando o vao entre os pes) e malha
(wireframe) com contagem de triangulos. Saida em captures/ (fora do Git). PROVISORIO.

Uso: bash tools/blender.sh --background source_art/characters/leme_v2/leme_v2.blend \
        --python source_art/characters/leme_v2/render_leme_v2.py -- $PWD/captures/leme_v2 [--fast]
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.abspath(os.path.join(HERE, "..", "..", "scripts"))
for p in (HERE, SCRIPTS):
    if p not in sys.path:
        sys.path.insert(0, p)

import bpy
from mathutils import Vector

import lv2_render as RR
from rbart import tri_count

args = sys.argv[sys.argv.index("--") + 1:]
OUT = os.path.abspath(args[0])
FAST = "--fast" in args
S = 0.5 if FAST else 1.0
os.makedirs(OUT, exist_ok=True)
sc = bpy.context.scene
rig = next(o for o in sc.objects if o.type == "ARMATURE")
meshes = [o for o in sc.objects if o.type == "MESH"]
face = next(o for o in meshes if o.name.endswith("_Face"))


def rest_pose():
    for ad in (rig.animation_data, face.data.shape_keys.animation_data):
        for tr in ad.nla_tracks:
            tr.mute = True
        ad.action = None
    for pb in rig.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    for kb in face.data.shape_keys.key_blocks:
        kb.value = 0.0
    sc.frame_set(0)


def set_clip(name, frame):
    for ad in (rig.animation_data, face.data.shape_keys.animation_data):
        for tr in ad.nla_tracks:
            tr.mute = True
    rig.animation_data.action = bpy.data.actions[name]
    face.data.shape_keys.animation_data.action = bpy.data.actions[name + "_key"]
    sc.frame_set(frame)


rest_pose()
RR.scene_lights(sc)
cam = RR.camera(sc, (0, 0, 0.57), 3.7, 8, 0, 85)
# 1) turnaround com luz de cena
RR.turnaround(sc, OUT, "leme_v2", target=(0, 0, 0.57), dist=3.7, w=int(720 * S), h=int(1040 * S), samples=int(128 * S))
# 2) close do rosto (sorriso leve) e camera baixa de heroi
set_clip("idle", 120)
RR.cycles(sc, int(900 * S), int(900 * S), int(128 * S))
RR.place(cam, (0.0, 0.0, 0.82), 1.35, 3.0, -18)
RR.render(sc, os.path.join(OUT, "leme_v2_close.png"))
rest_pose()
RR.cycles(sc, int(900 * S), int(1100 * S), int(128 * S))
RR.place(cam, (0.0, 0.0, 0.56), 2.6, -6.0, 30)
RR.render(sc, os.path.join(OUT, "leme_v2_heroi_baixo.png"))
# 3) prancha de poses: linha 1 em 3/4 (personalidade), linha 2 de FRENTE (vao entre os pes no walk/run)
row1 = [("idle", 55), ("idle", 120), ("team_pose", 26), ("wave", 20), ("celebrate", 18), ("idle_wheel", 10)]
row2 = [("walk", 0), ("walk", 8), ("walk", 15), ("run", 4), ("run", 13), ("stop", 8)]
RR.cycles(sc, int(420 * S), int(600 * S), int(48 * S))
p1, p2 = [], []
for name, fr in row1:
    set_clip(name, fr)
    RR.place(cam, (0, 0, 0.57), 4.0, 8.0, -30)
    p1.append(RR.render(sc, os.path.join(OUT, "pose_%s_%d.png" % (name, fr))))
for name, fr in row2:
    set_clip(name, fr)
    RR.place(cam, (0, 0, 0.50), 4.0, 3.0, 0)
    p2.append(RR.render(sc, os.path.join(OUT, "pose_frente_%s_%d.png" % (name, fr))))
RR.compose([p1, p2], os.path.join(OUT, "leme_v2_poses.png"))
rest_pose()
# 4) malha: material de wireframe em tudo, luz neutra
tris = tri_count(meshes)
wm = RR.wire_material()
for o in meshes:
    for i in range(len(o.data.materials)):
        o.data.materials[i] = wm
for o in list(sc.objects):
    if o.name == "Chao_prova":
        o.hide_render = True
cu = bpy.data.curves.new("t_tris", "FONT")
cu.body = "Leme v2 - %d triangulos" % tris
cu.size = 0.06
cu.align_x = "CENTER"
tob = bpy.data.objects.new("t_tris", cu)
sc.collection.objects.link(tob)
tm = bpy.data.materials.new("t_mat")
tm.use_nodes = True
tm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.02, 0.05, 0.12, 1)
cu.materials.append(tm)
wp = []
RR.cycles(sc, int(800 * S), int(1100 * S), int(24 * S))
for label, az in (("frente", 0), ("lado", 90)):
    RR.place(cam, (0, 0, 0.57), 3.5, 4.0, az)
    tob.rotation_euler = (math.radians(90), 0, math.radians(180 - az))
    d = (cam.location - Vector((0, 0, 0.57))).normalized()
    tob.location = d * 0.3
    tob.location.z = -0.03
    wp.append(RR.render(sc, os.path.join(OUT, "leme_v2_malha_%s.png" % label)))
RR.compose([wp], os.path.join(OUT, "leme_v2_malha.png"))
print("PROVAS OK tris=%d" % tris)
