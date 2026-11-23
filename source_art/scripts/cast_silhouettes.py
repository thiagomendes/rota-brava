"""Gera as 9 silhuetas candidatas do elenco (3 por integrante) e as pranchas (PROVISORIO).

Uso: tools/blender.ps1 --background --factory-startup --python source_art/scripts/cast_silhouettes.py -- --out captures/rb-03/art
Saidas: prancha_silhuetas.png, prancha_silhuetas_48px.png (nativa) e _x4.png (ampliada sem suavizar),
prancha_silhuetas_costas.png (e 48 px de costas).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import numpy as np
from rbart import (REPO, arg_value, empty, load_pixels, mat, ortho_camera, render_to, reset_scene,
                   save_pixels, setup_workbench, text_obj, world_bbox)
import rbchars

OUT = os.path.abspath(arg_value("--out", os.path.join(REPO, "captures", "rb-03", "art")))
ORDER = ["tracker", "climber", "pilot"]
VARS = ["A", "B", "C"]


def build_sheet(view, labels, ppm, cell_w, cell_h, margin_top=0.0):
    sc = reset_scene()
    black = mat("mat_sil_black", "#000000")
    sign = -1 if view == "front" else 1          # camera em +Y ve +X para a esquerda
    heights = {}
    for r, m in enumerate(ORDER):
        for c, v in enumerate(VARS):
            root = empty("%s_%s_root" % (m, v), (sign * (c - 1) * cell_w, 0, -r * cell_h))
            ch = rbchars.build(m, v, prefix="%s_%s" % (m, v), root=root)
            bpy.context.view_layer.update()
            lo, hi = world_bbox(ch.objs)
            heights["%s_%s" % (m, v)] = round(hi.z - lo.z, 3)
            if labels:
                lab = "%s %s" % (rbchars.MEMBERS[m].upper(), v)
                text_obj(sc, lab, (sign * (c - 1) * cell_w, 0, -r * cell_h - 0.2), 0.16,
                         rot=(math.pi / 2, 0, 0 if view == "back" else math.pi), color_mat=black)
    w_m, h_m = cell_w * 3, cell_h * 3 + margin_top
    resx, resy = int(round(w_m * ppm)), int(round(h_m * ppm))
    setup_workbench(sc, resx, resy, color_type="SINGLE", light="FLAT")
    sc.display.shading.single_color = (0, 0, 0)
    cy = 6.0 if view == "front" else -6.0
    center_z = (1.7 + (-2 * cell_h - 0.3)) / 2
    ortho_camera(sc, (0, cy, center_z), (0, 0, center_z), resy / ppm)
    return sc, heights


def build_and_render(view, labels, ppm, cell_w, cell_h, path):
    sc, heights = build_sheet(view, labels, ppm, cell_w, cell_h)
    render_to(sc, path)
    return heights


def upscale(path_in, path_out, k):
    a = load_pixels(path_in)
    a = np.repeat(np.repeat(a, k, axis=0), k, axis=1)
    save_pixels(a, path_out)


def main():
    os.makedirs(OUT, exist_ok=True)
    h = build_and_render("front", True, 260, 1.55, 1.95, os.path.join(OUT, "prancha_silhuetas.png"))
    build_and_render("back", True, 200, 1.55, 1.95, os.path.join(OUT, "prancha_silhuetas_costas.png"))
    # miniatura: 32 px/m => 1,5 m ~ 48 px de altura (sem rotulos)
    mini = os.path.join(OUT, "prancha_silhuetas_48px.png")
    build_and_render("front", False, 32, 1.6, 1.75, mini)
    upscale(mini, os.path.join(OUT, "prancha_silhuetas_48px_x4.png"), 4)
    mini_b = os.path.join(OUT, "prancha_silhuetas_costas_48px.png")
    build_and_render("back", False, 32, 1.6, 1.75, mini_b)
    upscale(mini_b, os.path.join(OUT, "prancha_silhuetas_costas_48px_x4.png"), 4)
    print("ALTURAS_M", h)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(REPO, "source_art", "characters", "cast", "cast_silhouettes.blend"))


main()

