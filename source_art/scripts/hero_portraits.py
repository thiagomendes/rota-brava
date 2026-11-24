"""Retratos do HUD (RB-R1): busto 512x512, fundo transparente, luz da biblia (Eevee toon), contorno fino.
Saida: game/ui/portraits/<id>_<expr>.png para rastro, pico, leme, captain e pup em neutra, alegre e surpresa. PROVISORIO.

Uso: tools/blender.ps1 --background --factory-startup --python source_art/scripts/hero_portraits.py -- [--out game/ui/portraits]
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector

import hero_lib
import hero_render as hr
import pup_build
from rbart import REPO, arg_value, reset_scene

OUT = os.path.join(REPO, arg_value("--out", os.path.join("game", "ui", "portraits")))
IDS = ("rastro", "pico", "leme", "captain", "pup")
EXPRS = ("neutra", "alegre", "surpresa")


def set_face(face, key):
    kb = face.data.shape_keys.key_blocks
    for k in kb[1:]:
        k.value = 0.0
    if key in kb and key != "neutra":
        kb[key].value = 1.0


def main():
    os.makedirs(OUT, exist_ok=True)
    written = []
    for cid in IDS:
        reset_scene()
        sc = hr.eevee_scene(512, 512, ground=False)
        sc.render.film_transparent = True
        sc.render.image_settings.color_mode = "RGBA"
        if cid == "pup":
            b = pup_build.build_pup(with_rig=False)
            target, dist, elev, azim = Vector((0, 0.17, 0.37)), 0.95, 8.0, -22.0
        else:
            b = hero_lib.build_hero(cid, "A", with_rig=False)
            hc = b.F.hc
            target, dist, elev, azim = Vector((0, 0, hc.z - 0.03 * b.F.k)), 1.70 * b.F.k, 6.0, -20.0
        hr.toonify(b.objs, outline=0.004)
        hr.camera(sc, target, dist, elev, azim, 85.0)
        for e in EXPRS:
            set_face(b.face_ob, e)
            p = os.path.join(OUT, "%s_%s.png" % (cid, e))
            hr.render(sc, p)
            written.append(os.path.relpath(p, REPO).replace("\\", "/"))
    print("PORTRAITS", json.dumps(written))


main()
