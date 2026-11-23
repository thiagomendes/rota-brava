"""Barco v2 (PROVISORIO), evolucao de source_art/vehicles/boat (RB-03): casco amarelo com friso, defensas, nome pintado
em formas (sem texto), cabine pequena na POPA (banco e marca da pata livres para a camera), console com volante,
motor de popa, bandeirola, lampiao de proa, corda amarrada. Metros, espaco Godot, proa em -Z.
PIVO (origem) sobre o eixo longitudinal, 40% do comprimento a partir da popa: popa z = +2,0, proa z = -3,0, boca 2,2 m.
Banco no ponto BENCH_LOCAL do Ep01Layout (0, 0.5, 0.6): topo do banco em y = 0,5.
Empties: DeckPoint, BenchMark, WheelPoint, HornPoint. Objeto proprio da marca: PawMark (mat_env_paw).
Uso: blender --background --factory-startup --python build_boat_v2.py -- --blend X --glb-dir Y
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh
from mathutils import Vector
from envlib import (REPO, Asset, arg_value, gbox, gcyl, gsph, lathe, materials, reset_scene, save_all, sweep)
from rbart import torus

BEAM = 2.2
Y_STERN, Y_BOW = -2.0, 3.0         # eixo "proa positiva" do RB-03; em Godot z = -y
KEEL, GUN, DECK = -0.30, 0.55, 0.40
Y_TURN = 0.4
NST, NPT = 30, 15
BENCH_Y, BENCH_Z = 0.5, 0.6


def half_beam(y):
    if y <= Y_TURN:
        k = (y - Y_STERN) / (Y_TURN - Y_STERN)
        return BEAM / 2 * (0.93 + 0.07 * min(1.0, k * 4))
    t = (y - Y_TURN) / (Y_BOW - Y_TURN)
    return max(0.02, BEAM / 2 * (1 - t ** 1.7) ** 0.62)


def keel_z(y):
    t = max(0.0, (y - 0.6) / (Y_BOW - 0.6))
    return KEEL + 0.27 * t * t


def gun_z(y):
    t = max(0.0, (y - Y_TURN) / (Y_BOW - Y_TURN))
    s = max(0.0, (Y_STERN + 0.8 - y) / 0.8)
    return GUN + 0.2 * t * t + 0.03 * s


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


def P(x, y, z):
    return (x, z, -y)           # (x, y_proa, z_altura) -> Godot


def build_hull(a):
    bm = bmesh.new()
    rows = []
    for i in range(NST):
        y = Y_STERN + (Y_BOW - Y_STERN) * i / (NST - 1)
        rows.append([bm.verts.new(P(*p)) for p in section(y)])
    for i in range(NST - 1):
        for j in range(NPT - 1):
            bm.faces.new((rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]))
    bm.faces.new(list(reversed(rows[0])))
    bm.faces.new(rows[-1])
    bm.normal_update()
    # normais para fora: a face da quilha deve apontar para -Y
    mid = min((f for f in bm.faces if len(f.verts) == 4), key=lambda f: (f.calc_center_median() - Vector((0, KEEL, 0))).length)
    if mid.normal.y > 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    # gradiente de cor: escurece perto da quilha / linha d'agua
    a.part("Boat_Hull", bm, "mat_env_boat_hull", keep_name=True, jit=0.04, ao=0.38, ao_h=0.78, recalc=False, solid=0.07)
    return rows


def rail_points(side, inset=0.0, jfrac=0):
    pts = []
    for i in range(NST):
        y = Y_STERN + (Y_BOW - Y_STERN) * i / (NST - 1)
        sec = section(y)
        j = 0 if side < 0 else NPT - 1
        j = j + jfrac * (1 if side < 0 else -1)
        x, yy, z = sec[j]
        pts.append(Vector(P(x + side * inset, yy, z)))
    return pts


def main():
    reset_scene()
    M = materials()
    info = {}
    glb = arg_value("--glb-dir", os.path.join(REPO, "game", "assets", "models", "environment"))
    a = Asset("Boat_V2", M, 7)
    _part = a.part
    a.part = lambda *args, **kw: _part(*args, **{"keep_name": True, **kw})   # nos estaveis: Boat_Hull, Boat_Cabin, ...
    a.root["pivot_note"] = "origem = centro de giro: eixo longitudinal, 40% do comprimento a partir da popa; proa em -Z"
    build_hull(a)

    # friso/defensa de convez (teal) e faixa pintada (laranja) em ambos os bordos
    bm = bmesh.new()
    for s in (-1, 1):
        sweep(bm, rail_points(s, 0.012)[:-1], 0.04, seg=8, caps=True)
    a.part("Boat_Rail", bm, "mat_env_boat_trim", jit=0.05, ao=0.2, ao_h=0.1)
    bm = bmesh.new()
    for s in (-1, 1):
        sweep(bm, rail_points(s, 0.004, 3)[1:-2], 0.022, seg=6, caps=True)
    a.part("Boat_Stripe", bm, "mat_env_boat_stripe", jit=0.04, ao=0.0)

    # convez: poligono acompanhando o casco
    bm = bmesh.new()
    ys = [Y_STERN + 0.06 + (2.5 - (Y_STERN + 0.06)) * i / 24 for i in range(25)]
    left = [(-(half_beam(y) - 0.05), y) for y in ys]
    top = [bm.verts.new(P(x, y, DECK)) for (x, y) in left] + [bm.verts.new(P(-x, y, DECK)) for (x, y) in reversed(left)]
    f = bm.faces.new(top)
    r = bmesh.ops.extrude_face_region(bm, geom=[f])
    bmesh.ops.translate(bm, vec=(0, -0.05, 0), verts=[v for v in r["geom"] if isinstance(v, bmesh.types.BMVert)])
    a.part("Boat_Deck", bm, "mat_env_boat_deck", bevel=0.01, bseg=1, jit=0.1, ao=0.0)
    bm = bmesh.new()
    for k in range(11):
        y = -1.75 + 0.4 * k
        hw = half_beam(y) - 0.08
        if hw > 0.12:
            before = set(bm.verts)
            gbox(bm, (0, DECK + 0.005, -y), (2 * hw, 0.012, 0.035 + 0.004 * (k % 3)))
            a.paint_new(bm, before, jit=0.25, ao=0.0)
    a.part("Boat_DeckPlanks", bm, "mat_env_wood_dark", bevel=0.003, bseg=1, paint=False)

    # nome pintado em formas (sem texto): quatro "glifos" abstratos de cada lado, a vante
    bm = bmesh.new()
    zc = -1.2
    for s in (-1, 1):
        sec = section(-zc)
        cand = [p for p in sec if (p[0] * s) > 0]
        xs, _, zs = min(cand, key=lambda p: abs(p[2] - 0.27))
        zz = 0.0
        for k, (w, kind) in enumerate([(0.2, "bar"), (0.14, "dot"), (0.26, "bar"), (0.12, "dot"), (0.2, "bar")]):
            cz = zc + 0.55 - 0.28 * k
            hx = half_beam(-cz)
            sx = [p for p in section(-cz) if p[0] * s > 0]
            px, _, pz = min(sx, key=lambda p: abs(p[2] - 0.27))
            if kind == "bar":
                gbox(bm, (px + s * 0.008, 0.27, cz), (0.02, 0.1, w * 0.9))
            else:
                gsph(bm, (px + s * 0.008, 0.27, cz), (0.012, 0.055, 0.055), 8, 6)
    a.part("Boat_Name", bm, "mat_env_boat_name", jit=0.04, ao=0.0)

    # cabine pequena a POPA (z 0,98 .. 1,92), console e volante a vante do banco
    bm = bmesh.new()
    gbox(bm, (0, DECK + 0.47, 1.45), (1.5, 0.94, 0.94), cuts=(1, 1, 1))
    a.part("Boat_Cabin", bm, "mat_env_boat_cabin", sub=2, crease=0.82, jit=0.04, ao=0.3, ao_h=0.9)
    bm = bmesh.new()
    gbox(bm, (0, DECK + 1.0, 1.45), (1.78, 0.07, 1.22), cuts=(1, 0, 1))
    for v in bm.verts:
        v.co.y += 0.05 * (1 - (abs(v.co.x) / 0.89) ** 2) * 0.0 - 0.0
    a.part("Boat_CabinRoof", bm, "mat_env_boat_roof", sub=2, crease=0.8, jit=0.05, ao=0.0)
    bm = bmesh.new()
    gbox(bm, (0, DECK + 0.58, 0.975), (1.0, 0.36, 0.03))                    # janela de vante
    for s in (-1, 1):
        gbox(bm, (s * 0.755, DECK + 0.58, 1.45), (0.03, 0.34, 0.5))      # janelas laterais
    a.part("Boat_Windows", bm, "mat_env_boat_glass", bevel=0.01, bseg=2, jit=0.0, ao=0.0)
    bm = bmesh.new()
    gbox(bm, (0, DECK + 0.58, 0.97), (1.12, 0.46, 0.02))
    gbox(bm, (0, DECK + 0.58, 0.96), (0.04, 0.46, 0.04))
    a.part("Boat_WindowFrames", bm, "mat_env_boat_trim", bevel=0.006, bseg=1, jit=0.05, ao=0.0)

    # banco no BENCH_LOCAL (topo em y = 0,5) com pernas
    bm = bmesh.new()
    gbox(bm, (0, BENCH_Y - 0.035, BENCH_Z), (1.5, 0.07, 0.5), cuts=(3, 0, 1))
    a.part("Boat_Bench", bm, "mat_env_boat_bench", bevel=0.015, bseg=2, jit=0.04, ao=0.25, ao_h=0.07)
    bm = bmesh.new()
    for s in (-1, 1):
        gbox(bm, (s * 0.62, (BENCH_Y - 0.07 + DECK) / 2, BENCH_Z), (0.1, BENCH_Y - 0.07 - DECK, 0.42))
    a.part("Boat_BenchLegs", bm, "mat_env_wood_dark", bevel=0.01, bseg=1, jit=0.1, ao=0.5)

    # marca da pata: almofada + 4 dedos, relevo raso sobre o banco, dedos para +X (sobe na tela, camera a bombordo)
    bm = bmesh.new()
    top_y = BENCH_Y + 0.004
    gsph(bm, (-0.05, top_y, BENCH_Z), (0.12, 0.012, 0.15), 18, 8)               # almofada (maior no eixo z)
    for k in range(4):
        ang = math.radians(-54 + 36 * k)
        gsph(bm, (0.065 + 0.065 * math.cos(ang), top_y,
                  BENCH_Z + 0.215 * math.sin(ang)), (0.042, 0.012, 0.052), 12, 6)
    a.part("PawMark", bm, "mat_env_paw", keep_name=True, jit=0.0, ao=0.0)

    # console + volante (a vante do banco, volante virado para a popa) e hastes
    bm = bmesh.new()
    gbox(bm, (0, DECK + 0.26, -0.45), (0.5, 0.52, 0.34), cuts=(1, 1, 1))
    a.part("Boat_HelmStand", bm, "mat_env_boat_cabin", sub=2, crease=0.78, jit=0.05, ao=0.35, ao_h=0.5)
    bm = bmesh.new()
    wc = Vector((0.0, DECK + 0.72, -0.37))
    torus(bm, (0, 0, 0), 0.19, 0.022, None, 28, 8)
    for k in range(6):
        ang = math.pi * k / 6
        gcyl(bm, (math.cos(ang) * 0.19, math.sin(ang) * 0.19, 0), (-math.cos(ang) * 0.19, -math.sin(ang) * 0.19, 0), 0.013, seg=8)
    gsph(bm, (0, 0, 0), 0.045, 10, 6)
    # inclina 30 graus para a popa e posiciona
    from mathutils import Matrix
    bm.transform(Matrix.Translation(wc) @ Matrix.Rotation(math.radians(-32), 4, "X"))
    a.part("Boat_Helm", bm, "mat_env_boat_wheel", jit=0.1, ao=0.2, ao_h=0.4)
    bm = bmesh.new()
    gcyl(bm, (0, DECK + 0.5, -0.43), (0, DECK + 0.68, -0.38), 0.04, 0.03, seg=8)
    a.part("Boat_HelmColumn", bm, "mat_env_metal", jit=0.1, ao=0.0)

    # motor de popa no painel de popa (z = 2,0)
    bm = bmesh.new()
    gbox(bm, (0, 0.62, 2.1), (0.34, 0.12, 0.2))                                # suporte no painel
    gbox(bm, (0, 0.5, 2.28), (0.3, 0.46, 0.3), cuts=(1, 1, 1))
    a.part("Boat_Motor", bm, "mat_env_boat_motor", sub=2, crease=0.7, jit=0.05, ao=0.4, ao_h=0.5)
    bm = bmesh.new()
    gbox(bm, (0, 0.78, 2.28), (0.34, 0.14, 0.34), cuts=(1, 0, 1))
    a.part("Boat_MotorCowl", bm, "mat_env_boat_stripe", sub=2, crease=0.7, jit=0.04, ao=0.2)
    bm = bmesh.new()
    gbox(bm, (0, -0.1, 2.3), (0.1, 1.0, 0.16), cuts=(0, 2, 0))
    gsph(bm, (0, -0.58, 2.3), (0.09, 0.07, 0.18), 10, 6)
    for k in range(3):
        ang = math.radians(120 * k + 20)
        gbox(bm, (0.0 + 0.11 * math.cos(ang), -0.58 + 0.11 * math.sin(ang), 2.46), (0.04, 0.12, 0.02), rz=math.degrees(ang))
    a.part("Boat_MotorLeg", bm, "mat_env_boat_motor", bevel=0.01, bseg=2, jit=0.05, ao=0.5, ao_h=1.0)
    bm = bmesh.new()
    gcyl(bm, (0, 0.62, 2.4), (0.0, 0.62, 2.62), 0.025, seg=8)
    gbox(bm, (0, 0.64, 2.62), (0.34, 0.03, 0.03))
    a.part("Boat_MotorTiller", bm, "mat_env_boat_motor", bevel=0.005, bseg=1, jit=0.05, ao=0.0)

    # bandeirola (mastro no teto da cabine; flamula para a popa) e buzina
    bm = bmesh.new()
    gcyl(bm, (0.55, DECK + 1.03, 1.75), (0.55, DECK + 2.0, 1.75), 0.018, 0.012, seg=8)
    gsph(bm, (0.55, DECK + 2.02, 1.75), 0.03, 8, 6)
    a.part("Boat_FlagPole", bm, "mat_env_wood_light", jit=0.1, ao=0.0)
    bm = bmesh.new()
    # flamula: prisma triangular fino; ondula um pouco
    pts = [(0.55, DECK + 1.93, 1.75), (0.55, DECK + 1.62, 1.75), (0.55, DECK + 1.78, 2.55)]
    vs = [bm.verts.new(p) for p in pts]
    f = bm.faces.new(vs)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=3, use_grid_fill=True)
    for v in bm.verts:
        t = max(0.0, v.co.z - 1.75)
        v.co.x += 0.07 * math.sin(t * 6.0)
    r = bmesh.ops.extrude_face_region(bm, geom=bm.faces[:])
    bmesh.ops.translate(bm, vec=(0.012, 0, 0), verts=[v for v in r["geom"] if isinstance(v, bmesh.types.BMVert)])
    a.part("Boat_Flag", bm, "mat_env_boat_flag", jit=0.05, ao=0.0)
    bm = bmesh.new()
    gcyl(bm, (-0.5, DECK + 1.04, 1.1), (-0.5, DECK + 1.1, 1.1), 0.05, seg=10)
    gcyl(bm, (-0.5, DECK + 1.1, 1.1), (-0.5, DECK + 1.1, 0.96), 0.03, 0.075, seg=10)
    a.part("Boat_Horn", bm, "mat_env_metal", jit=0.1, ao=0.0)

    # lampiao de proa em haste, com vidro emissivo
    bm = bmesh.new()
    gcyl(bm, (0.0, DECK, -2.3), (0.0, DECK + 0.75, -2.3), 0.025, seg=8)
    gbox(bm, (0.0, DECK + 0.8, -2.3), (0.2, 0.025, 0.2))
    gbox(bm, (0.0, DECK + 1.05, -2.3), (0.2, 0.025, 0.2))
    for sx in (-1, 1):
        for sz in (-1, 1):
            gbox(bm, (sx * 0.09, DECK + 0.925, -2.3 + sz * 0.09), (0.015, 0.25, 0.015))
    a.part("Boat_Lantern", bm, "mat_env_metal", bevel=0.004, bseg=1, jit=0.1, ao=0.0)
    bm = bmesh.new()
    gbox(bm, (0.0, DECK + 0.925, -2.3), (0.15, 0.22, 0.15))
    a.part("Boat_LanternGlass", bm, "mat_env_boat_lamp", bevel=0.01, bseg=2, jit=0.0, ao=0.0)

    # cunho de proa + corda amarrada (voltas + ponta caindo para o cais, lado -X) + defensas penduradas
    bm = bmesh.new()
    gbox(bm, (0.0, DECK + 0.05, -2.05), (0.36, 0.1, 0.1))
    a.part("Boat_Cleat", bm, "mat_env_metal", bevel=0.015, bseg=2, jit=0.1, ao=0.2)
    bm = bmesh.new()
    pts = []
    for k in range(33):
        t = k / 32
        ang = t * 4 * math.pi
        pts.append(Vector((0.14 * math.cos(ang) * 0.9, DECK + 0.1 + 0.02 * math.sin(ang), -2.05 + 0.055 * math.sin(ang * 1.0))))
    tail = [pts[-1], Vector((-0.32, DECK + 0.1, -2.0)), Vector((-0.75, DECK + 0.12, -1.85)), Vector((-1.1, DECK + 0.05, -1.7)),
            Vector((-1.22, DECK - 0.25, -1.55)), Vector((-1.18, DECK - 0.5, -1.45))]
    sweep(bm, pts, 0.022, seg=6)
    sweep(bm, tail, 0.022, seg=6)
    a.part("Boat_Rope", bm, "mat_env_rope", jit=0.15, ao=0.0)
    bm = bmesh.new()
    for s in (-1, 1):
        for zc in (-1.0, 0.4):
            hb = half_beam(-zc)
            before = set(bm.verts)
            lathe(bm, [(0.0, -0.14), (0.07, -0.12), (0.095, -0.05), (0.095, 0.05), (0.07, 0.12), (0.0, 0.14)], seg=12,
                  c=(s * (hb + 0.1), 0.2, zc))
            a.paint_new(bm, before, jit=0.1, ao=0.35, ao_h=0.28)
            sweep(bm, [Vector((s * (hb + 0.07), 0.55, zc)), Vector((s * (hb + 0.1), 0.38, zc))], 0.012, seg=5)
    a.part("Boat_Fenders", bm, "mat_env_white", jit=0.0, ao=0.0, paint=False)

    # empties
    a.point("DeckPoint", (0.0, DECK + 0.01, -0.1), size=0.3)
    a.point("BenchMark", (0.0, BENCH_Y + 0.012, BENCH_Z), size=0.2)
    a.point("WheelPoint", (0.0, DECK + 0.72, -0.37), size=0.2)
    a.point("HornPoint", (-0.5, DECK + 1.1, 0.96), size=0.15)
    a.point("PivotMark", (0, 0, 0), kind="PLAIN_AXES", size=0.3)

    a.finish(glb, info)
    blend = arg_value("--blend", os.path.join(REPO, "source_art", "environment", "boat_v2.blend"))
    save_all(blend, info, os.path.splitext(blend)[0] + ".info.json")


main()
