"""Provas da arte das cenas (RB-R1): turnaround, quadros-chave de clipes e malha de um personagem a partir do .blend.
Luz e render do Pico v2 (pv2_render, Cycles). Saida fora do Git (captures/). PROVISORIO.

Uso: bash tools/blender.sh --background <personagem>.blend --python source_art/scripts/render_arte_cenas.py -- \
        <out_dir> <prefixo> --target 0,0,0.55 --dist 3.6 [--turn] [--wire] [--poses walk:0,walk:6 --az 90 --elev 4] [--fast]
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
for p in (HERE, os.path.join(HERE, "..", "characters", "pico_v2")):
    p = os.path.abspath(p)
    if p not in sys.path:
        sys.path.insert(0, p)

import bpy
from mathutils import Vector

import pv2_render as RR
from rbart import tri_count

args = sys.argv[sys.argv.index("--") + 1:]
OUT = os.path.abspath(args[0])
PREFIX = args[1]


def opt(name, default=None):
    return args[args.index(name) + 1] if name in args else default


TARGET = tuple(float(x) for x in opt("--target", "0,0,0.55").split(","))
DIST = float(opt("--dist", "3.6"))
AZ = float(opt("--az", "-30"))
ELEV = float(opt("--elev", "6"))
LENS = float(opt("--lens", "85"))
FAST = "--fast" in args
S = 0.5 if FAST else 1.0
W, H = int(float(opt("--w", "720")) * S), int(float(opt("--h", "1000")) * S)
os.makedirs(OUT, exist_ok=True)
sc = bpy.context.scene
rig = next(o for o in sc.objects if o.type == "ARMATURE")
meshes = [o for o in sc.objects if o.type == "MESH"]
face = next(o for o in meshes if o.name.endswith("_Face"))
keyed = [o for o in meshes if o.data.shape_keys is not None and o.data.shape_keys.animation_data is not None]


def mute_all():
    for ad in [rig.animation_data] + [o.data.shape_keys.animation_data for o in keyed]:
        for tr in ad.nla_tracks:
            tr.mute = True


def rest_pose():
    mute_all()
    rig.animation_data.action = None
    for o in keyed:
        o.data.shape_keys.animation_data.action = None
        for kb in o.data.shape_keys.key_blocks:
            kb.value = 0.0
    for pb in rig.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    sc.frame_set(0)


def set_clip(name, frame):
    mute_all()
    rig.animation_data.action = bpy.data.actions[name]
    for o in keyed:
        suffix = "_gear" if o.name.endswith("_Gear") else "_key"
        o.data.shape_keys.animation_data.action = bpy.data.actions.get(name + suffix)
    sc.frame_set(frame)


rest_pose()
RR.scene_lights(sc)
cam = RR.camera(sc, TARGET, DIST, ELEV, 0, LENS)
if "--turn" in args:
    if opt("--turn-clip"):
        c, f = opt("--turn-clip").split(":")
        set_clip(c, int(f))
    RR.turnaround(sc, OUT, PREFIX, target=TARGET, dist=DIST, w=W, h=H, samples=int(96 * S),
                  views=(("frente", 0), ("tres_quartos", -38), ("costas", 180)))
    rest_pose()
if opt("--poses"):
    spec = [p.split(":") for p in opt("--poses").split(",")]
    per_row = int(opt("--per-row", "6"))
    RR.cycles(sc, W, H, int(48 * S))
    paths = []
    for name, fr in spec:
        set_clip(name, int(fr))
        RR.place(cam, TARGET, DIST, ELEV, AZ)
        paths.append(RR.render(sc, os.path.join(OUT, "%s_%s_%s.png" % (PREFIX, name, fr))))
    rows = [paths[i:i + per_row] for i in range(0, len(paths), per_row)]
    RR.compose(rows, os.path.join(OUT, PREFIX + "_poses.png"))
    rest_pose()
if "--wire" in args:
    tris = tri_count(meshes)
    wm = RR.wire_material()
    for o in meshes:
        for i in range(len(o.data.materials)):
            o.data.materials[i] = wm
    for o in list(sc.objects):
        if o.name == "Chao_prova":
            o.hide_render = True
    RR.cycles(sc, W, H, int(24 * S))
    wp = []
    for label, az in (("frente", 0), ("lado", 90)):
        RR.place(cam, TARGET, DIST, 4.0, az)
        wp.append(RR.render(sc, os.path.join(OUT, "%s_malha_%s.png" % (PREFIX, label))))
    RR.compose([wp], os.path.join(OUT, PREFIX + "_malha.png"))
    print("PROVAS tris=%d" % tris)
print("PROVAS OK", PREFIX)
