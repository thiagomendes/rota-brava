"""Retratos do HUD dos herois v2 (RB-R1 E3b): mesmo enquadramento, tamanho (512x512), formato (PNG RGBA, fundo
transparente) e caminho dos retratos antigos (game/ui/portraits/<id>_<expr>.png), agora renderizados a partir das fontes
v2 (source_art/characters/<id>_v2/<id>_v2.blend), com a luz de cena dos renders de prova v2 (Cycles). PROVISORIO.

Enquadramento dos antigos (hero_portraits.py): busto, elevacao 6 graus, giro -20 graus, lente 85 mm, camera a 1,70 m do
centro da cabeca. Aqui o centro vem do osso `head` do rig v2 (meio do osso) e a distancia/altura foram calibradas lado a
lado com os antigos (1,60 m; 7 cm abaixo) para a cabeca ocupar a mesma area. Expressao pelas shape keys do rosto
(`neutra`, `alegre`, `surpresa`), corpo na pose do clipe `idle` (quadro 0), acessorios `Acc_*` ocultos (no jogo o colete
da Leme so aparece quando a missao pede).

Uso (um heroi por chamada, abrindo o .blend dele):
  bash tools/blender.sh --background source_art/characters/pico_v2/pico_v2.blend \
       --python source_art/scripts/hero_portraits_v2.py -- pico [--out game/ui/portraits] [--samples 96]
  capitao/filhote/Lumi: source_art/characters/secondary_v2/{captain,pup,lumi}_v2.blend -- captain | pup | lumi
"""
import json
import os
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
HID = args[0]
HERE = os.path.dirname(bpy.data.filepath)
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(REPO, args[args.index("--out") + 1] if "--out" in args else os.path.join("game", "ui", "portraits"))
SAMPLES = int(args[args.index("--samples") + 1]) if "--samples" in args else 96
for p in (HERE, os.path.join(REPO, "source_art", "scripts"), os.path.join(REPO, "source_art", "characters", "rastro_v2")):
    if p not in sys.path:
        sys.path.insert(0, p)

# RB-R1 E7 (ux): capitao e filhote usam a mesma luz e render do Rastro v2 (rv2_render), para a legenda nao misturar estilos
# com os herois v2. RB-R1 G4 r2 (art3d): fontes passam a ser os v2 (source_art/characters/secondary_v2/<id>_v2.blend).
RR = __import__({"rastro": "rv2_render", "pico": "pv2_render", "leme": "lv2_render",
                 "captain": "rv2_render", "pup": "rv2_render", "lumi": "rv2_render"}[HID])
EXPRS = ("neutra", "alegre", "surpresa")
# 1,60 m e 7 cm abaixo do meio do osso: calibrado para a cabeca v2 ocupar a mesma area do quadro que a dos antigos
DIST, ELEV, AZIM, LENS, DROP = 1.60, 6.0, -20.0, 85.0, 0.07
# Capitao (adulto) e filhote: calibrados lado a lado com os retratos v2 dos herois (cabeca na mesma area do quadro).
# Capitao: mais longe e alvo 2 cm acima para caber o quepe; filhote: perto (cabeca pequena), alvo 2 cm abaixo.
# G4 r2: capitao v2 tem cabeca adulta menor (0,37 m) que a da primeira geracao (0,46 m): camera mais perto.
# RB-R1 G21: Lumi (adulto, cabeca 0,36 m, sem chapeu; o arco do fone e a antena precisam caber): perto do capitao.
DIST, AZIM, DROP = {"captain": (1.62, AZIM, -0.03), "pup": (0.95, AZIM, 0.02), "lumi": (1.58, AZIM, -0.01)}.get(HID, (DIST, AZIM, DROP))


def _opt(flag, default):
    return float(args[args.index(flag) + 1]) if flag in args else default


DIST, AZIM, DROP = _opt("--dist", DIST), _opt("--azim", AZIM), _opt("--drop", DROP)


def main():
    sc = bpy.context.scene
    rig = next(o for o in sc.objects if o.type == "ARMATURE")
    face = next(o for o in sc.objects if o.type == "MESH" and o.name.endswith("_Face"))
    keys = face.data.shape_keys
    # corpo na pose do idle (quadro 0); rosto controlado a mao (sem acao nas shape keys)
    for ad in (rig.animation_data, keys.animation_data):
        if ad is not None:
            for tr in ad.nla_tracks:
                tr.mute = True
    if "idle" in bpy.data.actions:
        rig.animation_data.action = bpy.data.actions["idle"]
    for o in sc.objects:   # punho/acessorios por shape key: idle tambem
        sk = o.data.shape_keys if o.type == "MESH" else None
        if o is not face and sk is not None and sk.animation_data is not None:
            for tr in sk.animation_data.nla_tracks:
                tr.mute = True
            sk.animation_data.action = bpy.data.actions.get("idle_gear")
    if keys.animation_data is not None:
        keys.animation_data.action = None
    sc.frame_set(0)
    for o in sc.objects:
        if o.name.startswith("Acc_"):
            o.hide_render = True
    # cena: luz das provas v2, fundo transparente, sem o chao de prova
    RR.scene_lights(sc)
    chao = bpy.data.objects.get("Chao_prova")
    if chao is not None:
        bpy.data.objects.remove(chao, do_unlink=True)
    RR.cycles(sc, 512, 512, SAMPLES)
    sc.render.film_transparent = True
    sc.render.image_settings.color_mode = "RGBA"
    hb = rig.pose.bones["head"]
    hc = rig.matrix_world @ ((hb.head + hb.tail) * 0.5)
    target = Vector((hc.x, hc.y, hc.z - DROP))
    RR.camera(sc, target, DIST, ELEV, AZIM, LENS)
    os.makedirs(OUT, exist_ok=True)
    written = []
    for e in EXPRS:
        for kb in keys.key_blocks[1:]:
            kb.value = 0.0
        if e in keys.key_blocks:
            keys.key_blocks[e].value = 1.0
        p = os.path.join(OUT, "%s_%s.png" % (HID, e))
        RR.render(sc, p)
        written.append(os.path.relpath(p, REPO).replace("\\", "/"))
    print("PORTRAITS_V2", HID, json.dumps({"arquivos": written, "centro_cabeca": [round(v, 3) for v in hc],
                                           "camera": {"dist": DIST, "elev": ELEV, "azim": AZIM, "lente": LENS}}))


main()
