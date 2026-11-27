"""Provas do G21 (RB-R1): Lumi lado a lado com o trio v2, o capitao v2 e a Dona Amora v2, a partir dos .blend versionados.
Fila de frente, de costas e de perfil (todos no quadro 0 do `idle`), close dos rostos e close das maos direitas. Luz de
cena das provas v2 (rv2_render). Saida fora do Git (captures/). PROVISORIO.

Uso: bash tools/blender.sh --background --factory-startup --python source_art/characters/secondary_v2/render_lineup_g21.py -- \
        <saida> [--fast] [--lumi <lumi_v2.blend>]
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
FAST = "--fast" in args
Q = 0.5 if FAST else 1.0
CH = "source_art/characters/"
SRC = [("rastro", CH + "rastro_v2/rastro_v2.blend"), ("pico", CH + "pico_v2/pico_v2.blend"), ("leme", CH + "leme_v2/leme_v2.blend"),
       ("captain", CH + "secondary_v2/captain_v2.blend"), ("amora", CH + "secondary_v2/amora_v2.blend"),
       ("lumi", args[args.index("--lumi") + 1] if "--lumi" in args else CH + "secondary_v2/lumi_v2.blend")]
SPACING = 0.82


def load(cid, path, x):
    path = path if os.path.isabs(path) else os.path.join(REPO, path)
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = [n for n in src.objects]
        dst.actions = [n for n in src.actions]
    sc = bpy.context.scene
    rig, face = None, None
    obs = []
    for o in dst.objects:
        if o is None or o.type not in ("ARMATURE", "MESH"):
            continue
        if o.name.startswith(("Chao", "Acc_")):
            continue
        sc.collection.objects.link(o)
        obs.append(o)
        if o.type == "ARMATURE":
            rig = o
        elif o.name.endswith("_Face"):
            face = o
    acts = {a.name.rsplit(".", 1)[0] if a.name[-4:-3] == "." else a.name: a for a in dst.actions if a is not None}
    for ad in (rig.animation_data, face.data.shape_keys.animation_data if face.data.shape_keys else None):
        if ad is not None:
            for tr in ad.nla_tracks:
                tr.mute = True
    rig.animation_data.action = acts.get("idle")
    if face.data.shape_keys and face.data.shape_keys.animation_data:
        face.data.shape_keys.animation_data.action = acts.get("idle_key")
    for o in obs:     # acessorios por shape key (Leme): pose do idle
        sk = o.data.shape_keys if o.type == "MESH" else None
        if o is not face and sk is not None and sk.animation_data is not None:
            for tr in sk.animation_data.nla_tracks:
                tr.mute = True
            sk.animation_data.action = acts.get("idle_gear")
    rig.location.x += x
    for o in obs:
        if o.type == "MESH" and o.parent is None:
            o.location.x += x
    return rig, face


def main():
    os.makedirs(OUT, exist_ok=True)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    sc = bpy.context.scene
    sc.render.fps = 30
    n = len(SRC)
    figs = {}
    for i, (cid, path) in enumerate(SRC):
        x = -(i - (n - 1) * 0.5) * SPACING     # de frente, o Rastro fica a esquerda da imagem e o Lumi a direita
        figs[cid] = (x,) + load(cid, path, x)
    sc.frame_set(0)
    bpy.context.view_layer.update()
    RR.scene_lights(sc)
    chao = bpy.data.objects.get("Chao_prova")
    if chao is not None:
        chao.scale = (2.0, 1.0, 1.0)
    mid = Vector((0, 0, 0.88))
    cam = RR.camera(sc, mid, 11.0, 5.0, 0.0, 50.0)
    RR.cycles(sc, int(1800 * Q), int(760 * Q), int(64 * Q))
    out = []
    for label, az in (("frente", 0.0), ("costas", 180.0), ("perfil", -90.0)):
        if label == "perfil":
            # de perfil a fila se esconderia atras de si mesma: cada um gira 90 graus no lugar (camera de frente)
            for cid, (x, rig, face) in figs.items():
                rig.rotation_euler.z = math.radians(90)
            RR.place(cam, mid, 11.0, 5.0, 0.0)
        else:
            RR.place(cam, mid, 11.0, 5.0, az)
        p = os.path.join(OUT, "g21_fila_%s.png" % label)
        RR.render(sc, p)
        out.append(p)
    for cid, (x, rig, face) in figs.items():
        rig.rotation_euler.z = 0.0
    bpy.context.view_layer.update()
    # rostos e maos: um quadro por personagem, mesma distancia relativa a cabeca
    RR.cycles(sc, int(520 * Q), int(560 * Q), int(64 * Q))
    rows = [[], []]
    for cid, (x, rig, face) in figs.items():
        hb = rig.pose.bones["head"]
        hc = rig.matrix_world @ ((hb.head + hb.tail) * 0.5)
        hh = (hb.tail - hb.head).length
        RR.place(cam, hc, hh * 4.2, 4.0, -18.0)
        cam.data.lens = 85.0
        rows[0].append(RR.render(sc, os.path.join(OUT, "g21_rosto_%s.png" % cid)))
        hn = rig.pose.bones["hand.R"]
        hp = rig.matrix_world @ ((hn.head + hn.tail) * 0.5)
        RR.place(cam, hp + Vector((0.0, 0.0, 0.02)), 0.95, 8.0, 40.0)
        rows[1].append(RR.render(sc, os.path.join(OUT, "g21_mao_%s.png" % cid)))
    RR.compose([rows[0]], os.path.join(OUT, "g21_rostos.png"))
    RR.compose([rows[1]], os.path.join(OUT, "g21_maos.png"))
    print("LINEUP OK", out)


main()
