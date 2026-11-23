"""Gera o barco amarelo PROVISORIO (casco #F5C518, convés, cabine, banco, volante) em metros.

Blender Z-up, proa em +Y (= -Z na Godot). PIVO (origem) no centro de giro: sobre o eixo longitudinal,
40% do comprimento a partir da popa. Popa em y=-2,0 e proa em y=+3,0 (5,0 m); boca de 2,2 m.
Empties: DeckPoint (onde ficam as pessoas) e BenchMark (marca da pata no banco).
Uso: tools/blender.ps1 --background --factory-startup --python source_art/scripts/build_boat.py -- --blend X --glb Y
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh
import bpy
from mathutils import Matrix, Vector
from rbart import (REPO, arg_value, box, cyl, empty, mat, new_object, reset_scene, rot_x, rot_y,
                   torus, tri_count, world_bbox)

LEN, BEAM = 5.0, 2.2
Y_STERN, Y_BOW = -2.0, 3.0          # pivo em y=0: 0.4 * 5.0 = 2.0 m da popa
KEEL, GUN, DECK = -0.30, 0.55, 0.40
Y_TURN = 0.4                        # onde o casco comeca a afinar para a proa
NST, NPT = 26, 15


def half_beam(y):
    if y <= Y_TURN:
        k = (y - Y_STERN) / (Y_TURN - Y_STERN)
        return BEAM / 2 * (0.93 + 0.07 * min(1.0, k * 4))       # popa levemente mais estreita
    t = (y - Y_TURN) / (Y_BOW - Y_TURN)
    return max(0.02, BEAM / 2 * (1 - t ** 1.7) ** 0.62)


def keel_z(y):
    t = max(0.0, (y - 0.6) / (Y_BOW - 0.6))
    return KEEL + 0.27 * t * t


def gun_z(y):
    t = max(0.0, (y - Y_TURN) / (Y_BOW - Y_TURN))
    return GUN + 0.16 * t * t


def section(y):
    hb, zk, zt = half_beam(y), keel_z(y), gun_z(y)
    pts = []
    for j in range(NPT):
        phi = math.pi * j / (NPT - 1)
        c, s = math.cos(phi), math.sin(phi)
        x = -hb * math.copysign(abs(c) ** 0.65, c)
        z = zt - (zt - zk) * abs(s) ** 0.75
        pts.append((x, y, z))
    return pts


def build_hull(hull_mat):
    bm = bmesh.new()
    rows = []
    for i in range(NST):
        y = Y_STERN + (Y_BOW - Y_STERN) * i / (NST - 1)
        rows.append([bm.verts.new(p) for p in section(y)])
    for i in range(NST - 1):
        for j in range(NPT - 1):
            bm.faces.new((rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]))
    bm.faces.new(list(reversed(rows[0])))        # painel de popa
    bm.faces.new(rows[-1])                       # ponta da proa
    bm.normal_update()
    # normais para fora: a face da quilha, a meio do casco, deve apontar para -Z
    mid = min((f for f in bm.faces if len(f.verts) == 4), key=lambda f: (f.calc_center_median() - Vector((0, 0, KEEL))).length)
    if mid.normal.z > 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    bm.normal_update()
    ob = new_object("Boat_Hull", bm, hull_mat, smooth=True, parent=None, recalc=False)
    return ob


def solidify(ob, thickness):
    md = ob.modifiers.new("solid", "SOLIDIFY")
    md.thickness = thickness
    md.offset = -1.0
    md.use_even_offset = True
    with bpy.context.temp_override(object=ob, active_object=ob, selected_objects=[ob]):
        bpy.ops.object.modifier_apply(modifier=md.name)


def outline(y0, y1, n, inset):
    ys = [y0 + (y1 - y0) * i / (n - 1) for i in range(n)]
    left = [(-(half_beam(y) - inset), y) for y in ys]
    return ys, left


def main():
    sc = reset_scene()
    root = empty("Boat", kind="PLAIN_AXES", size=0.5)
    root["provisional"] = True
    root["agent"] = "art3d"
    root["pivot_note"] = "origem = centro de giro: eixo longitudinal, 40% do comprimento a partir da popa"
    M = {
        "hull": mat("mat_boat_hull", "#F5C518", 0.55),
        "deck": mat("mat_boat_deck", "#C9A36A", 0.9),
        "planks": mat("mat_boat_planks", "#A98450", 0.9),
        "cabin": mat("mat_boat_cabin", "#FFF3C4", 0.8),
        "roof": mat("mat_boat_roof", "#D9552B", 0.7),
        "glass": mat("mat_boat_glass", "#5C9AAE", 0.2),
        "bench": mat("mat_boat_bench", "#A0714A", 0.9),
        "wheel": mat("mat_boat_wheel", "#7A4A28", 0.7),
        "brass": mat("mat_boat_trim", "#B8B0A0", 0.4, 0.5),
    }
    objs = []

    def add(name, bm, m, smooth=False):
        o = new_object("Boat_" + name, bm, M[m], smooth=smooth, parent=root)
        objs.append(o)
        return o

    hull = build_hull(M["hull"])
    solidify(hull, 0.07)
    hull.parent = root
    objs.append(hull)

    # convés: polígono acompanhando o casco (z=DECK), espessura 0,05
    ys, left = outline(Y_STERN + 0.05, 2.45, 22, 0.05)
    bm = bmesh.new()
    top = [bm.verts.new((x, y, DECK)) for (x, y) in left] + [bm.verts.new((-x, y, DECK)) for (x, y) in reversed(left)]
    bm.faces.new(top)
    r = bmesh.ops.extrude_face_region(bm, geom=bm.faces[:])
    bmesh.ops.translate(bm, vec=(0, 0, -0.05), verts=[v for v in r["geom"] if isinstance(v, bmesh.types.BMVert)])
    add("Deck", bm, "deck")
    # tábuas (listras transversais finas)
    bm = bmesh.new()
    for k in range(10):
        y = -1.55 + 0.38 * k
        hw = half_beam(y) - 0.07
        if hw > 0.12:
            box(bm, (0, y, DECK + 0.004), (2 * hw, 0.025, 0.012))
    add("DeckPlanks", bm, "planks")

    # cabine (à popa)
    bm = bmesh.new(); box(bm, (0, -1.2, 0.99), (1.62, 1.3, 1.18), bevel=0.05)
    add("Cabin", bm, "cabin")
    bm = bmesh.new(); box(bm, (0, -1.2, 1.62), (1.86, 1.56, 0.08), bevel=0.03)
    add("CabinRoof", bm, "roof")
    bm = bmesh.new()
    box(bm, (0, -0.545, 1.12), (1.14, 0.03, 0.36), bevel=0.01)
    for s in (-1, 1):
        box(bm, (s * 0.815, -1.2, 1.12), (0.03, 0.8, 0.36), bevel=0.01)
    add("Windows", bm, "glass")

    # volante (Helm; nao usar sufixo _wheel, a Godot o trata como VehicleWheel3D): coluna + aro com raios (plano XZ, inclinado), de frente para a popa
    bm = bmesh.new(); cyl(bm, (0, -0.30, DECK), (0, -0.30, 0.86), 0.05, 0.04, seg=12)
    add("HelmStand", bm, "brass", smooth=True)
    bm = bmesh.new()
    center = Vector((0, -0.30, 0.98))
    tilt = Matrix.Translation(center) @ rot_x(-25)
    torus(bm, (0, 0, 0), 0.19, 0.02, rot_x(90), 28, 8)
    for k in range(6):
        a = math.pi * k / 6
        cyl(bm, (math.cos(a) * 0.19, 0, math.sin(a) * 0.19), (-math.cos(a) * 0.19, 0, -math.sin(a) * 0.19), 0.013, seg=8)
    sph_bm = bm
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=0.04)
    bm.transform(tilt)
    add("Helm", bm, "wheel", smooth=True)

    # banco do cockpit + pernas
    bm = bmesh.new(); box(bm, (0, 0.95, 0.66), (1.5, 0.46, 0.09), bevel=0.02)
    add("Bench", bm, "bench")
    bm = bmesh.new()
    for s in (-1, 1):
        box(bm, (s * 0.62, 0.95, 0.52), (0.10, 0.40, 0.24))
    add("BenchLegs", bm, "planks")

    # proa: cunho e lanterna (volumes simples)
    bm = bmesh.new(); box(bm, (0, 2.45, DECK + 0.07), (0.34, 0.1, 0.1), bevel=0.02)
    add("BowCleat", bm, "brass")

    deck_pt = empty("DeckPoint", (0.0, 0.2, DECK + 0.01), parent=root, size=0.3)
    bench_mark = empty("BenchMark", (0.0, 0.95, 0.66 + 0.045 + 0.005), parent=root, kind="ARROWS", size=0.2)

    bpy.context.view_layer.update()
    lo, hi = world_bbox([hull])
    info = {"tris": tri_count(objs), "materials": sorted({m.name for o in objs for m in o.data.materials}),
            "hull_extent_m": [round(hi.x - lo.x, 3), round(hi.y - lo.y, 3), round(hi.z - lo.z, 3)],
            "hull_y_range": [round(lo.y, 3), round(hi.y, 3)],
            "pivot_from_stern_fraction": round((0 - lo.y) / (hi.y - lo.y), 3),
            "objects": sorted([o.name for o in objs] + ["DeckPoint", "BenchMark"])}
    print("BOAT_INFO", json.dumps(info))
    blend = arg_value("--blend", os.path.join(REPO, "source_art", "vehicles", "boat", "boat.blend"))
    os.makedirs(os.path.dirname(blend), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=blend)
    glb = arg_value("--glb")
    if glb:
        os.makedirs(os.path.dirname(glb), exist_ok=True)
        bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_selection=False, export_yup=True,
                                  export_apply=False, export_morph=True, export_materials="EXPORT",
                                  export_cameras=False, export_lights=False, export_extras=True)
    with open(os.path.splitext(blend)[0] + ".info.json", "w", encoding="utf-8") as f:
        json.dump(info, f, indent=2)


main()



