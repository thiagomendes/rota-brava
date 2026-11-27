"""Provas do G23 (RB-R1): perna e sapato dos adultos v2 ao lado do trio v2. PROVISORIO.

Fila de frente, de lado e de 3/4 (cada personagem gira no lugar), e close dos pes do capitao, da Dona Amora e do Lumi de
frente, de lado e de 3/4, cada um num quadro de um clipe escolhido. Luz de cena das provas v2 (rv2_render). Saida fora do
Git (captures/).

Uso: bash tools/blender.sh --background --factory-startup --python source_art/characters/secondary_v2/render_feet_g23.py -- \
        <saida> <rotulo> [--feet] [--src <pasta com captain_v2/amora_v2/lumi_v2.blend>] [--pose captain=walk:21 ...] [--fast] [--wire]
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
for p in (HERE, os.path.join(REPO, "source_art", "characters", "rastro_v2"), os.path.join(REPO, "source_art", "scripts")):
    if p not in sys.path:
        sys.path.insert(0, p)

import bpy
from mathutils import Vector

import rv2_render as RR

args = sys.argv[sys.argv.index("--") + 1:]
OUT = os.path.abspath(args[0])
LABEL = args[1]
FAST = "--fast" in args
WIRE = "--wire" in args
FEET_ONLY = "--feet" in args
Q = 0.5 if FAST else 1.0
SRC_DIR = args[args.index("--src") + 1] if "--src" in args else os.path.join(REPO, "source_art", "characters", "secondary_v2")
POSES = {}
for i, a in enumerate(args):
    if a == "--pose":
        cid, spec = args[i + 1].split("=")
        clip, fr = spec.split(":")
        POSES[cid] = (clip, int(fr))
CH = os.path.join(REPO, "source_art", "characters")
SRC = [("rastro", os.path.join(CH, "rastro_v2", "rastro_v2.blend")), ("pico", os.path.join(CH, "pico_v2", "pico_v2.blend")),
       ("leme", os.path.join(CH, "leme_v2", "leme_v2.blend")), ("captain", os.path.join(SRC_DIR, "captain_v2.blend")),
       ("amora", os.path.join(SRC_DIR, "amora_v2.blend")), ("lumi", os.path.join(SRC_DIR, "lumi_v2.blend"))]
ADULTS = ("captain", "amora", "lumi")
SPACING = 0.82


def load(cid, path, x):
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = [n for n in src.objects]
        dst.actions = [n for n in src.actions]
    sc = bpy.context.scene
    rig, face, obs = None, None, []
    for o in dst.objects:
        if o is None or o.type not in ("ARMATURE", "MESH") or o.name.startswith(("Chao", "Acc_")):
            continue
        sc.collection.objects.link(o)
        obs.append(o)
        if o.type == "ARMATURE":
            rig = o
        elif o.name.endswith("_Face"):
            face = o
    acts = {a.name.rsplit(".", 1)[0] if a.name[-4:-3] == "." else a.name: a for a in dst.actions if a is not None}
    for o in obs:
        ad = o.animation_data if o.type == "ARMATURE" else (o.data.shape_keys.animation_data if o.data.shape_keys else None)
        if ad is not None:
            for tr in ad.nla_tracks:
                tr.mute = True
    clip, fr = POSES.get(cid, ("idle", 0))
    if clip not in acts:
        clip, fr = "idle", 0
    # o quadro pedido cai no quadro 0 da cena: faixa de NLA deslocada
    rig.animation_data.action = None
    tr = rig.animation_data.nla_tracks.new()
    st = tr.strips.new(clip, 0, acts[clip])
    st.frame_start = -fr
    st.frame_end = -fr + (acts[clip].frame_range[1] - acts[clip].frame_range[0])
    if face.data.shape_keys and face.data.shape_keys.animation_data:
        face.data.shape_keys.animation_data.action = acts.get("idle_key")
    for o in obs:
        sk = o.data.shape_keys if o.type == "MESH" else None
        if o is not face and sk is not None and sk.animation_data is not None:
            sk.animation_data.action = acts.get("idle_gear")
    rig.location.x += x
    for o in obs:
        if o.type == "MESH" and o.parent is None:
            o.location.x += x
    return rig, face, obs, clip, fr


def main():
    os.makedirs(OUT, exist_ok=True)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    sc = bpy.context.scene
    sc.render.fps = 30
    n = len(SRC)
    figs = {}
    for i, (cid, path) in enumerate(SRC):
        x = -(i - (n - 1) * 0.5) * SPACING
        figs[cid] = (x,) + load(cid, path, x)
    sc.frame_set(0)
    bpy.context.view_layer.update()
    RR.scene_lights(sc)
    chao = bpy.data.objects.get("Chao_prova")
    if chao is not None:
        chao.scale = (2.0, 1.0, 1.0)
    if WIRE:
        wm = RR.wire_material()
        for cid in ADULTS:
            for o in figs[cid][3]:
                if o.type == "MESH":
                    o.data.materials.clear()
                    o.data.materials.append(wm)
                    for pl in o.data.polygons:
                        pl.material_index = 0
    mid = Vector((0, 0, 0.88))
    cam = RR.camera(sc, mid, 11.0, 5.0, 0.0, 50.0)
    out = []
    if not WIRE and not FEET_ONLY:
        RR.cycles(sc, int(1800 * Q), int(760 * Q), int(48 * Q))
        for label, rot in (("frente", 0.0), ("perfil", 90.0), ("tres_quartos", 40.0)):
            for cid, f in figs.items():
                f[1].rotation_euler.z = math.radians(rot)
            RR.place(cam, mid, 11.0, 5.0, 0.0)
            out.append(RR.render(sc, os.path.join(OUT, "g23_%s_fila_%s.png" % (LABEL, label))))
    # close dos pes: um quadro por adulto e por vista
    RR.cycles(sc, int(440 * Q), int(400 * Q), int(48 * Q))
    rows = []
    for cid in ADULTS:
        x, rig, face, obs, clip, fr = figs[cid]
        row = []
        for label, rot, elev in (("frente", 0.0, 6.0), ("perfil", 90.0, 6.0), ("tres_quartos", 40.0, 6.0), ("baixo", 25.0, 1.0)):
            rig.rotation_euler.z = math.radians(rot)
            bpy.context.view_layer.update()
            RR.place(cam, Vector((x, 0.0, 0.17)), 1.05, elev, 0.0)
            cam.data.lens = 60.0
            row.append(RR.render(sc, os.path.join(OUT, "g23_%s_pes_%s_%s.png" % (LABEL, cid, label))))
        rig.rotation_euler.z = 0.0
        rows.append(row)
        print("POSE", cid, clip, fr)
    RR.compose(rows, os.path.join(OUT, "g23_%s_pes%s.png" % (LABEL, "_malha" if WIRE else "")))
    print("FEET OK", out)


main()
