"""Provas de um secundario v2 a partir do .blend: frente e tres-quartos com luz de cena (mesma do trio, rv2_render), close
do rosto e malha (wireframe) com contagem de triangulos. Saida fora do Git. PROVISORIO.

Uso: bash tools/blender.sh --background source_art/characters/secondary_v2/<id>.blend \
        --python source_art/characters/secondary_v2/render_sv2.py -- <saida> <prefixo> <altura_alvo_m> [--fast] [--sem-malha]
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
for p in (HERE, os.path.abspath(os.path.join(HERE, "..", "rastro_v2")), os.path.abspath(os.path.join(HERE, "..", "..", "scripts"))):
    if p not in sys.path:
        sys.path.insert(0, p)

import bpy
from mathutils import Vector

import rv2_render as RR
from rbart import tri_count

args = sys.argv[sys.argv.index("--") + 1:]
OUT, PFX, TOP = os.path.abspath(args[0]), args[1], float(args[2])
S = 0.5 if "--fast" in args else 1.0
os.makedirs(OUT, exist_ok=True)
sc = bpy.context.scene
rig = next(o for o in sc.objects if o.type == "ARMATURE")
meshes = [o for o in sc.objects if o.type == "MESH"]
face = next(o for o in meshes if o.name.endswith("_Face"))
for ad in (rig.animation_data, face.data.shape_keys.animation_data):
    for tr in ad.nla_tracks:
        tr.mute = True
rig.animation_data.action = bpy.data.actions["idle"]
face.data.shape_keys.animation_data.action = bpy.data.actions["idle_key"]
sc.frame_set(0)
RR.scene_lights(sc)
mid = (0, 0, TOP * 0.5)
cam = RR.camera(sc, mid, TOP * 3.3, 8, 0, 85)
RR.cycles(sc, int(720 * S), int(1000 * S), int(96 * S))
paths = []
for label, az in (("frente", 0), ("tres_quartos", -38), ("lado", -90)):
    RR.place(cam, mid, TOP * 3.3, 8.0, az)
    paths.append(RR.render(sc, os.path.join(OUT, "%s_%s.png" % (PFX, label))))
RR.compose([paths], os.path.join(OUT, PFX + "_turnaround.png"))
RR.cycles(sc, int(900 * S), int(900 * S), int(96 * S))
bb = [face.matrix_world @ Vector(c) for c in face.bound_box]
hc = tuple(sum((p for p in bb), Vector()) / 8.0)
RR.place(cam, hc, max(TOP * 0.75, 0.85), 4.0, -22)
RR.render(sc, os.path.join(OUT, PFX + "_close.png"))
if "--sem-malha" not in args:
    tris = tri_count(meshes)
    wm = RR.wire_material()
    for o in meshes:
        for i in range(len(o.data.materials)):
            o.data.materials[i] = wm
    RR.cycles(sc, int(800 * S), int(1000 * S), int(24 * S))
    wp = []
    for label, az in (("frente", 0), ("lado", -90)):
        RR.place(cam, mid, TOP * 3.1, 4.0, az)
        wp.append(RR.render(sc, os.path.join(OUT, "%s_malha_%s.png" % (PFX, label))))
    RR.compose([wp], os.path.join(OUT, PFX + "_malha.png"))
    print("MALHA tris=%d" % tris)
print("PROVAS OK")
