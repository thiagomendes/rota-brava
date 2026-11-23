"""Renderiza (Workbench) as imagens de verificacao dos ativos a partir do .blend (PROVISORIO).

Uso: tools/blender.ps1 --background --factory-startup --python source_art/scripts/render_views.py -- --asset rastro|boat --out captures/rb-03/art
rastro: rastro_vistas.png (frontal, lateral, traseira + 3 expressoes) e rastro_malha.png
boat:   boat_malha.png
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import numpy as np
from mathutils import Vector
from rbart import (REPO, arg_value, empty, load_pixels, mat, ortho_camera, render_to, save_pixels,
                   setup_workbench, text_obj)

ASSET = arg_value("--asset", "rastro")
OUT = os.path.abspath(arg_value("--out", os.path.join(REPO, "captures", "rb-03", "art")))
BLENDS = {"rastro": "source_art/characters/rastro/rastro.blend", "boat": "source_art/vehicles/boat/boat.blend"}


def open_asset():
    bpy.ops.wm.open_mainfile(filepath=os.path.join(REPO, BLENDS[ASSET]))
    return bpy.context.scene


def dup(root, loc, rot_z=0.0):
    new_root = root.copy()
    bpy.context.scene.collection.objects.link(new_root)
    for c in root.children_recursive:
        c2 = c.copy()
        if c.type == "MESH":
            c2.data = c.data.copy()
        bpy.context.scene.collection.objects.link(c2)
        c2.parent = new_root if c.parent == root else None
    # reparent (nested parents keep structure por nome)
    new_root.hide_render = False
    for c2 in new_root.children_recursive:
        c2.hide_render = False
    new_root.location = loc
    new_root.rotation_euler = (0, 0, rot_z)
    return new_root


def hide_originals(root):
    root.hide_render = True
    for c in root.children_recursive:
        c.hide_render = True


def vistas():
    sc = open_asset()
    root = bpy.data.objects[ASSET.capitalize()]
    black = mat("mat_label", "#000000")
    hide_originals(root)
    # -- vistas: camera em +Y olhando para -Y (a frente do personagem aponta +Y)
    labels = ["FRONTAL", "LATERAL", "TRASEIRA"]
    for i, (rz, lab) in enumerate(zip((0, 90, 180), labels)):
        dup(root, (-i * 1.4, 0, 0), math.radians(rz))
        text_obj(sc, lab, (-i * 1.4, 0, -0.17), 0.1, rot=(math.pi / 2, 0, math.pi), color_mat=black)
    setup_workbench(sc, 1320, 620, color_type="MATERIAL", light="STUDIO")
    ortho_camera(sc, (-1.4, 8, 0.72), (-1.4, 0, 0.72), 4.5)
    p1 = os.path.join(OUT, "_v1.png")
    render_to(sc, p1)
    # -- expressoes (outra cena)
    sc = open_asset()
    root = bpy.data.objects["Rastro"]
    hide_originals(root)
    for i, ex in enumerate(("neutra", "atenta", "surpresa")):
        r2 = dup(root, (-i * 0.8, 0, 0))
        face = [c for c in r2.children_recursive if c.name.endswith("Face") or c.name.startswith("Rastro_Face")][0]
        for kb in face.data.shape_keys.key_blocks:
            kb.value = 1.0 if kb.name == ex else 0.0
        text_obj(sc, ex.upper(), (-i * 0.8, 0.5, 0.68), 0.05, rot=(math.pi / 2, 0, math.pi), color_mat=mat("mat_label", "#000000"))
    setup_workbench(sc, 1320, 420, color_type="MATERIAL", light="STUDIO")
    ortho_camera(sc, (-0.8, 8, 1.0), (-0.8, 0, 1.0), 2.4)
    # ortho_scale vale para a maior dimensao (largura); altura = scale*420/1320
    p2 = os.path.join(OUT, "_v2.png")
    render_to(sc, p2)
    a, b = load_pixels(p1), load_pixels(p2)
    save_pixels(np.vstack([b, a]), os.path.join(OUT, "rastro_vistas.png"))  # pixels: origem embaixo => b fica embaixo
    os.remove(p1); os.remove(p2)


def malha(thickness, cam_dir, scale, size, rot_z=0.0, center=(0, 0, 0.6), out_name=None):
    sc = open_asset()
    root = bpy.data.objects[ASSET.capitalize()]
    root.rotation_euler = (0, 0, math.radians(rot_z))
    objs = [c for c in root.children_recursive if c.type == "MESH"]
    for o in objs:
        o.color = (0.86, 0.88, 0.9, 1)
        if o.data.shape_keys:
            pass
        w = o.copy()
        w.data = o.data
        sc.collection.objects.link(w)
        w.parent = o.parent
        w.matrix_parent_inverse = o.matrix_parent_inverse
        w.color = (0.05, 0.1, 0.2, 1)
        md = w.modifiers.new("wire", "WIREFRAME")
        md.thickness = thickness
        md.use_even_offset = True
        md.use_replace = True
    setup_workbench(sc, size[0], size[1], color_type="OBJECT", light="FLAT")
    d = Vector(cam_dir).normalized() * 15
    ortho_camera(sc, Vector(center) + d, center, scale)
    render_to(sc, os.path.join(OUT, out_name))


os.makedirs(OUT, exist_ok=True)
if ASSET == "rastro":
    vistas()
    malha(0.0032, (0.5, 1.0, 0.25), 1.55, (1000, 1300), center=(0, 0, 0.65), out_name="rastro_malha.png")
else:
    malha(0.012, (0.9, 1.0, 0.7), 8.2, (1600, 900), center=(0, 0.5, 0.6), out_name="boat_malha.png")




