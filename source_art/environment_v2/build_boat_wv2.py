"""Rota Brava · Mundo v2 (RB-R1 W4) · barco do porto refeito no acabamento D11. PROVISORIO ate aprovacao de Thiago.

Mesmas medidas e pontos de encaixe do barco do jogo (source_art/environment/build_boat_v2.py, boat_v2.glb), para poder
substitui-lo depois sem mexer na jogabilidade:
  pivo (origem) no eixo longitudinal, 40% do comprimento a partir da popa; popa z = +2,0, proa z = -3,0, boca 2,2 m;
  convez em y = 0,40; borda em y ~0,55; banco com topo em y = 0,5 em z = 0,6 (Ep01Layout.BENCH_LOCAL);
  empties DeckPoint, BenchMark, WheelPoint (volante da Leme), HornPoint, PivotMark + pontos de corda RopeBow,
  RopeSternL, RopeSternR; marca da pata como objeto proprio "PawMark" (material wv2_paw).
O que muda: casco de tabuas pintadas com friso, verdugo e fundo vermelho; convez em tabuas chanfradas uma a uma;
cabine com JANELAS DE VERDADE (paredes com vaos, caixilho, vidro e interior com banco e luminaria); teto com corrimao,
holofote, antena, buzina e mastro com flamula; console com instrumentos e volante de madeira com punhos; motor de popa;
ancora, cunhos, corda enrolada, defensas, boia salva-vidas, caixote de peixe e balde.
Geometria 100% por script (wv2lib). Uso: chamado por build_world_v2.py (exporta wv2_boat.glb).
"""
import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

from wv2lib import MB, R, T, hexc, lin

BEAM = 2.2
Y_STERN, Y_BOW = -2.0, 3.0
KEEL, GUN, DECK = -0.30, 0.55, 0.40
Y_TURN = 0.4
NST, NPT = 34, 17
BENCH_Y, BENCH_Z = 0.5, 0.6

YELLOW = hexc("#F2BE2E")
RED = hexc("#C9443A")
TEAL = hexc("#1F8C8A")
CREAM = hexc("#FFF3DE")
NAVY = hexc("#2E4F7A")
WOOD_D = hexc("#9C7552")
WOOD_L = hexc("#C9A57A")
IRON = hexc("#3B3F44")
BRASS = hexc("#C9A13A")

EMPTIES = {
    "DeckPoint": (0.0, DECK + 0.01, -0.1),
    "BenchMark": (0.0, BENCH_Y + 0.012, BENCH_Z),
    "WheelPoint": (0.0, DECK + 0.72, -0.37),
    "HornPoint": (-0.5, DECK + 1.1, 0.96),
    "PivotMark": (0.0, 0.0, 0.0),
    "RopeBow": (0.0, DECK + 0.1, -2.05),
    "RopeSternL": (-0.82, GUN + 0.08, 1.85),
    "RopeSternR": (0.82, GUN + 0.08, 1.85),
}


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


def section(y, inset=0.0):
    hb, zk, zt = half_beam(y) - inset, keel_z(y) + inset, gun_z(y)
    pts = []
    for j in range(NPT):
        phi = math.pi * j / (NPT - 1)
        c, s = math.cos(phi), math.sin(phi)
        x = -hb * math.copysign(abs(c) ** 0.65, c)
        z = zt - (zt - zk) * abs(s) ** 0.75
        pts.append(Vector((x, z, -y)))   # Godot: (x, altura, -proa)
    return pts


def hull(m):
    for inset, outer in ((0.0, True), (0.05, False)):
        bm = bmesh.new()
        rows = []
        for i in range(NST):
            y = Y_STERN + (Y_BOW - Y_STERN) * i / (NST - 1)
            rows.append([bm.verts.new(p) for p in section(y, inset)])
        for i in range(NST - 1):
            for j in range(NPT - 1):
                f = (rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j])
                bm.faces.new(f if outer else tuple(reversed(f)))
        if outer:
            bm.faces.new(list(reversed(rows[0])))
        bm.normal_update()
        mid = min(bm.faces, key=lambda f: (f.calc_center_median() - Vector((0, KEEL, 0))).length)
        if (mid.normal.y > 0) == outer:
            bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
        n0 = len(m.faces)
        if outer:
            m.add_bm(bm, Matrix.Identity(4), "wv2_paint", YELLOW, "box", "z", uvrot=math.pi / 2, uvoff=(0.0, 0.0))
            # fundo vermelho abaixo da linha d'agua (y < 0,04) e faixa de bota branca logo acima
            for fi in range(n0, len(m.faces)):
                ys = [m.verts[v].y for v in m.faces[fi]]
                cy = sum(ys) / len(ys)
                if cy < 0.03:
                    m.ccol[fi] = [lin(RED) + (1.0,)] * len(ys)
        else:
            m.add_bm(bm, Matrix.Identity(4), "wv2_wood", WOOD_L, "box", "z")


def rail(side, inset=0.0, jfrac=0, dy=0.0, a=0, b=None):
    pts = []
    for i in range(NST):
        y = Y_STERN + (Y_BOW - Y_STERN) * i / (NST - 1)
        sec = section(y)
        j = 0 if side < 0 else NPT - 1
        j = j + jfrac * (1 if side < 0 else -1)
        p = sec[j].copy()
        p.x += side * inset
        p.y += dy
        pts.append(p)
    return pts[a:b]


def bm_box(sx, sy, sz):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Diagonal((sx, sy, sz, 1.0)))
    return bm


def wall_with_holes(m, x0, x1, y0, y1, zc, t, holes, mat, col):
    """Parede plana em z = zc (espessura t) com vaos retangulares (x, y)."""
    xs = sorted({x0, x1} | {h[0] for h in holes} | {h[1] for h in holes})
    for a, b in zip(xs[:-1], xs[1:]):
        mid = (a + b) / 2
        hs = sorted([(h[2], h[3]) for h in holes if h[0] < mid < h[1]])
        y = y0
        for h0, h1 in hs:
            if h0 > y:
                m.box(((a + b) / 2, (y + h0) / 2, zc), (b - a, h0 - y, t), mat, col, 0.0, 1, uv="world", uvoff=(0, 0))
            y = max(y, h1)
        if y1 > y:
            m.box(((a + b) / 2, (y + y1) / 2, zc), (b - a, y1 - y, t), mat, col, 0.0, 1, uv="world", uvoff=(0, 0))


def window(m, cx, cy, zc, w, h, axis, sgn):
    """Caixilho + vidro num vao. axis 'z' = vao numa parede normal a z; 'x' = parede normal a x."""
    rot = Matrix.Identity(4) if axis == "z" else R(ry=90)
    def place(lx, ly, lz):
        if axis == "z":
            return (cx + lx, cy + ly, zc + lz * sgn)
        return (zc + lz * sgn, cy + ly, cx + lx)
    fw = 0.045
    for (lx, ly, sx, sy) in ((0, h / 2 - fw / 2, w, fw), (0, -h / 2 + fw / 2, w, fw), (-w / 2 + fw / 2, 0, fw, h),
                             (w / 2 - fw / 2, 0, fw, h)):
        m.box(place(lx, ly, 0.0), (sx, sy, 0.07), "wv2_paint", TEAL, 0.008, 1, rot=rot)
    m.box(place(0, 0, 0.0), (w - 0.02, h - 0.02, 0.012), "wv2_glass", (1, 1, 1), 0.0, 1, rot=rot)
    # moldura externa arredondada
    m.box(place(0, h / 2 + 0.02, 0.03), (w + 0.08, 0.04, 0.03), "wv2_paint", TEAL, 0.01, 1, rot=rot)


def build(materials, collection):
    rng = random.Random(77)
    random.seed(77)
    m = MB("wv2_boat")
    hull(m)
    # verdugo (madeira), capa da borda e frisos
    for s in (-1, 1):
        m.tube(rail(s, 0.03, 0, -0.03)[:-1], 0.05, "wv2_wood", WOOD_D, seg=8)
        m.tube(rail(s, -0.005, 0, 0.015)[:-1], 0.035, "wv2_wood", WOOD_L, seg=8)
        m.tube(rail(s, 0.008, 3, 0.0)[1:-2], 0.022, "wv2_glossy", TEAL, seg=6)
        m.tube(rail(s, 0.004, 6, 0.0)[1:-3], 0.016, "wv2_glossy", CREAM, seg=6)
    # painel de popa
    sec = section(Y_STERN)
    poly = [(p.x, p.y) for p in sec]
    m.prism((0, 0, 2.0 + 0.02), poly, 0.05, "wv2_paint", TEAL, uv="box")
    # convez: tabuas ao longo do barco, cortadas pelo contorno do casco
    x = -1.0
    while x < 1.0:
        lim = None
        for i in range(200):
            y = Y_BOW - (Y_BOW - Y_STERN) * i / 199
            if half_beam(y) - 0.07 > abs(x) + 0.05:
                lim = y
                break
        if lim is not None and lim > Y_STERN + 0.3:
            z0, z1 = -min(lim, 2.55), 1.97
            m.box((x, DECK - 0.02, (z0 + z1) / 2), (0.105, 0.04, z1 - z0), "wv2_deck", (1, 1, 1), 0.006, 1, grain="z",
                  uvoff=(rng.uniform(0, 2), 0.1 + 0.2 * rng.randint(0, 9)), rng=rng)
        x += 0.115
    # cabine a POPA (z 0,98 .. 1,92), paredes com vaos de janela, interior com banco e luminaria
    cz0, cz1, cw, ch = 0.98, 1.92, 1.5, 0.94
    y0, y1 = DECK, DECK + ch
    t = 0.05
    wall_with_holes(m, -cw / 2, cw / 2, y0, y1, cz0 + t / 2, t, [(-0.5, 0.5, DECK + 0.4, DECK + 0.76)], "wv2_paint", CREAM)
    wall_with_holes(m, -cw / 2, cw / 2, y0, y1, cz1 - t / 2, t, [(-0.3, 0.3, DECK, DECK + 0.78)], "wv2_paint", CREAM)
    for s in (-1, 1):
        # paredes laterais: parede normal a x, montada no plano (z, y)
        holes = [(1.2, 1.7, DECK + 0.41, DECK + 0.75)]
        zs = sorted({cz0 + t, cz1 - t} | {h[0] for h in holes} | {h[1] for h in holes})
        for a, b in zip(zs[:-1], zs[1:]):
            mid = (a + b) / 2
            if 1.2 < mid < 1.7:
                m.box((s * (cw / 2 - t / 2), (y0 + DECK + 0.41) / 2, mid), (t, DECK + 0.41 - y0, b - a), "wv2_paint", CREAM, 0, 1,
                      uv="world", uvoff=(0, 0))
                m.box((s * (cw / 2 - t / 2), (DECK + 0.75 + y1) / 2, mid), (t, y1 - DECK - 0.75, b - a), "wv2_paint", CREAM, 0, 1,
                      uv="world", uvoff=(0, 0))
            else:
                m.box((s * (cw / 2 - t / 2), (y0 + y1) / 2, mid), (t, y1 - y0, b - a), "wv2_paint", CREAM, 0, 1, uv="world",
                      uvoff=(0, 0))
        window(m, 1.45, DECK + 0.58, s * (cw / 2), 0.5, 0.34, "x", s)
        # faixa teal na base da cabine
        m.box((s * (cw / 2 + 0.005), DECK + 0.08, (cz0 + cz1) / 2), (0.02, 0.16, cz1 - cz0), "wv2_paint", TEAL, 0.0, 1, grain="z")
    window(m, 0.0, DECK + 0.58, cz0, 1.0, 0.36, "z", -1)
    m.box((0, DECK + 0.08, cz0 - 0.005), (cw, 0.16, 0.02), "wv2_paint", TEAL, 0.0, 1)
    # porta de popa (de tabuas) entreaberta
    m.box((0.27, DECK + 0.39, cz1 + 0.12), (0.04, 0.76, 0.56), "wv2_paint", TEAL, 0.01, 1, rot=R(ry=-70), grain="y")
    # interior: banquinho, prateleira com caixa e luminaria acesa
    m.box((0, DECK + 0.2, 1.7), (1.3, 0.05, 0.36), "wv2_wood", WOOD_L, 0.01, 1)
    m.box((0, DECK + 0.1, 1.7), (1.3, 0.2, 0.05), "wv2_wood", WOOD_D, 0.01, 1)
    m.box((-0.45, DECK + 0.27, 1.65), (0.3, 0.12, 0.22), "wv2_paint", RED, 0.01, 1)
    m.sphere((0, y1 - 0.08, 1.45), 0.07, "wv2_lamp", hexc("#FFE0A0"), subd=2)
    m.box((0, y1 - 0.02, 1.45), (1.4, 0.02, 0.84), "wv2_wood", WOOD_L, 0.0, 1)
    # teto com aba, corrimao, holofote, antena, buzina e mastro com flamula
    m.box((0, y1 + 0.04, 1.45), (1.78, 0.08, 1.22), "wv2_paint", TEAL, 0.03, 2)
    for s in (-1, 1):
        pts = [(s * 0.78, y1 + 0.08, 0.95), (s * 0.78, y1 + 0.2, 1.0), (s * 0.78, y1 + 0.2, 1.9), (s * 0.78, y1 + 0.08, 1.95)]
        m.tube(pts, 0.016, "wv2_metal", IRON, seg=6)
    m.lathe((0.45, y1 + 0.08, 1.05), [(0.08, 0.0), (0.05, 0.12), (0.0, 0.12)], "wv2_metal", IRON, seg=10)
    m.cyl((0.45, y1 + 0.25, 0.95), 0.08, 0.18, "wv2_glossy", CREAM, seg=12, rot=R(rx=80), bevel=0.01)
    m.cyl((0.45, y1 + 0.25, 0.94), 0.06, 0.02, "wv2_lamp", hexc("#FFF2C8"), seg=12, rot=R(rx=80))
    m.cyl((-0.55, y1 + 0.08, 1.8), 0.012, 0.9, "wv2_metal", IRON, seg=6)
    m.sphere((-0.55, y1 + 0.99, 1.8), 0.025, "wv2_glossy", RED, subd=1)
    # buzina no HornPoint (-0,5; 1,5; 0,96)
    hp = EMPTIES["HornPoint"]
    m.cyl((hp[0], y1 + 0.08, hp[2] + 0.12), 0.05, 0.08, "wv2_metal", BRASS, seg=10)
    m.cyl((hp[0], hp[1] + 0.02, hp[2] + 0.12), 0.03, 0.2, "wv2_metal", BRASS, r1=0.08, seg=12, rot=R(rx=-90))
    # mastro e flamula
    m.cyl((0.55, y1 + 0.08, 1.75), 0.02, 1.0, "wv2_wood", WOOD_L, r1=0.013, seg=8)
    m.sphere((0.55, y1 + 1.1, 1.75), 0.03, "wv2_metal", BRASS, subd=1)
    bm = bmesh.new()
    pts = [(0.55, y1 + 1.02, 1.75), (0.55, y1 + 0.72, 1.75), (0.55, y1 + 0.87, 2.5)]
    vs = [bm.verts.new(p) for p in pts]
    bm.faces.new(vs)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=3, use_grid_fill=True)
    for v in bm.verts:
        tt = max(0.0, v.co.z - 1.75)
        v.co.x += 0.06 * math.sin(tt * 6.0)
    r = bmesh.ops.extrude_face_region(bm, geom=bm.faces[:])
    bmesh.ops.translate(bm, vec=(0.012, 0, 0), verts=[v for v in r["geom"] if isinstance(v, bmesh.types.BMVert)])
    m.add_bm(bm, Matrix.Identity(4), "wv2_canvas", RED, "box", "z", uvoff=(0.13, 0))
    # boia salva-vidas na parede lateral (bombordo, -x)
    R0, rr = 0.2, 0.05
    for k in range(8):
        a0 = k / 8 * 2 * math.pi
        a1 = (k + 1) / 8 * 2 * math.pi
        pts = [(-cw / 2 - 0.06, DECK + 0.5 + math.sin(a0 + (a1 - a0) * q / 5) * R0, 1.12 + math.cos(a0 + (a1 - a0) * q / 5) * R0)
               for q in range(6)]
        m.tube(pts, rr, "wv2_glossy", RED if k % 2 == 0 else CREAM, seg=8, caps=False)
    # banco no BENCH_LOCAL (topo y = 0,5; z = 0,6): ripas chanfradas e pes
    for k in range(4):
        m.box((0, BENCH_Y - 0.02, BENCH_Z - 0.18 + k * 0.12), (1.5, 0.04, 0.105), "wv2_wood", WOOD_L, 0.012, 2, rng=rng)
    for s in (-1, 1):
        m.box((s * 0.62, (BENCH_Y - 0.04 + DECK) / 2, BENCH_Z), (0.08, BENCH_Y - 0.04 - DECK, 0.44), "wv2_wood", WOOD_D, 0.01, 1,
              grain="y", rng=rng)
    # console + volante de madeira (centro em WheelPoint, inclinado 32 graus para a popa)
    m.box((0, DECK + 0.26, -0.45), (0.5, 0.52, 0.34), "wv2_paint", CREAM, 0.035, 2)
    m.box((0, DECK + 0.53, -0.47), (0.54, 0.05, 0.38), "wv2_wood", WOOD_D, 0.015, 2)
    for k, gx in enumerate((-0.14, 0.14)):
        m.cyl((gx, DECK + 0.42, -0.27), 0.05, 0.02, "wv2_metal", BRASS, seg=12, rot=R(rx=90))
        m.cyl((gx, DECK + 0.42, -0.255), 0.04, 0.01, "wv2_glossy", CREAM, seg=12, rot=R(rx=90))
    wc = Vector(EMPTIES["WheelPoint"])
    wxf = T(*wc) @ Matrix.Rotation(math.radians(-32), 4, "X")
    ring = [(math.cos(a) * 0.19, math.sin(a) * 0.19, 0.0) for a in [i / 28 * 2 * math.pi for i in range(29)]]
    m.tube([wxf @ Vector(p) for p in ring], 0.022, "wv2_wood", WOOD_D, seg=8, caps=False)
    for k in range(8):
        a = k / 8 * 2 * math.pi
        p0 = wxf @ Vector((0, 0, 0))
        p1 = wxf @ Vector((math.cos(a) * 0.19, math.sin(a) * 0.19, 0))
        p2 = wxf @ Vector((math.cos(a) * 0.28, math.sin(a) * 0.28, 0))
        m.tube([p0, p1], 0.011, "wv2_wood", WOOD_L, seg=5)
        m.tube([p1, p2], lambda q: 0.018 + 0.008 * math.sin(q * math.pi), "wv2_wood", WOOD_D, seg=6)
    m.cyl((0, 0, 0), 0.045, 0.05, "wv2_metal", BRASS, seg=12, rot=wxf @ R(rx=90) @ T(0, -0.025, 0))
    m.cyl((0, DECK + 0.5, -0.43), 0.035, 0.2, "wv2_metal", IRON, seg=8, rot=R(rx=-20))
    # marca da pata (objeto proprio, como no barco do jogo)
    paw = MB("PawMark")
    top_y = BENCH_Y + 0.004
    paw.sphere((-0.05, top_y, BENCH_Z), 1.0, "wv2_paw", (1, 1, 1), subd=2, scale=(0.12, 0.012, 0.15))
    for k in range(4):
        ang = math.radians(-54 + 36 * k)
        paw.sphere((0.065 + 0.065 * math.cos(ang), top_y, BENCH_Z + 0.215 * math.sin(ang)), 1.0, "wv2_paw", (1, 1, 1), subd=2,
                   scale=(0.042, 0.012, 0.052))
    # motor de popa
    m.box((0, 0.62, 2.1), (0.34, 0.12, 0.2), "wv2_metal", IRON, 0.02, 1)
    m.box((0, 0.5, 2.28), (0.32, 0.46, 0.32), "wv2_glossy", CREAM, 0.06, 2)
    m.box((0, 0.8, 2.28), (0.36, 0.16, 0.36), "wv2_glossy", TEAL, 0.07, 2)
    m.box((0, -0.1, 2.3), (0.1, 1.0, 0.16), "wv2_metal", IRON, 0.03, 2, grain="y")
    m.sphere((0, -0.58, 2.3), 1.0, "wv2_metal", IRON, subd=2, scale=(0.09, 0.07, 0.18))
    for k in range(3):
        ang = 120 * k + 20
        m.box((0.11 * math.cos(math.radians(ang)), -0.58 + 0.11 * math.sin(math.radians(ang)), 2.46), (0.045, 0.13, 0.02),
              "wv2_metal", BRASS, 0.01, 1, rot=R(rz=ang))
    m.tube([(0, 0.62, 2.4), (0, 0.62, 2.66)], 0.025, "wv2_metal", IRON, seg=8)
    m.box((0, 0.63, 2.68), (0.3, 0.05, 0.05), "wv2_glossy", RED, 0.015, 1)
    # proa: cunho, corda enrolada caindo para o cais, ancora, lampiao
    m.box((0.0, DECK + 0.05, -2.05), (0.36, 0.06, 0.08), "wv2_metal", IRON, 0.02, 2)
    for s in (-1, 1):
        m.box((s * 0.12, DECK + 0.02, -2.05), (0.05, 0.06, 0.06), "wv2_metal", IRON, 0.01, 1)
    pts = []
    for k in range(33):
        tt = k / 32
        ang = tt * 4 * math.pi
        pts.append(Vector((0.14 * math.cos(ang) * 0.9, DECK + 0.1 + 0.02 * math.sin(ang), -2.05 + 0.055 * math.sin(ang))))
    m.tube(pts, 0.022, "wv2_rope", hexc("#D9C38B"), seg=6)
    tail = [pts[-1], Vector((-0.32, DECK + 0.1, -2.0)), Vector((-0.75, DECK + 0.13, -1.85)), Vector((-1.08, GUN + 0.06, -1.7)),
            Vector((-1.2, DECK - 0.25, -1.55)), Vector((-1.18, DECK - 0.5, -1.45))]
    m.tube(tail, 0.022, "wv2_rope", hexc("#D9C38B"), seg=6)
    for s in (-1, 1):  # cunhos de popa
        p = EMPTIES["RopeSternR" if s > 0 else "RopeSternL"]
        m.box((p[0], p[1] - 0.04, p[2]), (0.08, 0.05, 0.26), "wv2_metal", IRON, 0.015, 2, grain="z")
    # ancora no convez de proa
    ax, az = 0.42, -1.55
    m.cyl((ax, DECK + 0.03, az), 0.025, 0.5, "wv2_metal", IRON, seg=8, rot=R(rx=90))
    arc = [(ax + math.sin(a) * 0.17, DECK + 0.03, az + 0.5 - math.cos(a) * 0.12) for a in [math.radians(d) for d in range(-80, 81, 20)]]
    m.tube(arc, 0.022, "wv2_metal", IRON, seg=6)
    m.lathe((ax, DECK + 0.03, az - 0.02), [(0.0, -0.05), (0.05, 0.0), (0.0, 0.05)], "wv2_metal", IRON, seg=10, rot=R(rx=90))
    m.cyl((0.0, DECK, -2.35), 0.025, 0.75, "wv2_metal", IRON, seg=8)
    m.box((0.0, DECK + 0.8, -2.35), (0.2, 0.025, 0.2), "wv2_metal", IRON, 0.008, 1)
    m.lathe((0.0, DECK + 1.04, -2.35), [(0.13, 0.0), (0.0, 0.1)], "wv2_metal", IRON, seg=8)
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.box((sx * 0.09, DECK + 0.925, -2.35 + sz * 0.09), (0.015, 0.25, 0.015), "wv2_metal", IRON, 0.0, 1)
    m.box((0.0, DECK + 0.925, -2.35), (0.15, 0.22, 0.15), "wv2_lamp", hexc("#FFE3A6"), 0.01, 1)
    # defensas penduradas e cabos
    for s in (-1, 1):
        for zc in (-1.0, 0.4, 1.6):
            hb = half_beam(-zc)
            m.lathe((s * (hb + 0.1), 0.06, zc), [(0.0, -0.16), (0.07, -0.14), (0.095, -0.06), (0.095, 0.06), (0.07, 0.14), (0.0, 0.16)],
                    "wv2_glossy", NAVY if zc > 0 else CREAM, seg=12)
            m.tube([(s * (hb + 0.1), 0.22, zc), (s * (hb + 0.07), 0.45, zc), (s * (hb - 0.02), GUN + 0.04, zc)], 0.012,
                   "wv2_rope", hexc("#E6D29C"), seg=5)
    # "nome" pintado em formas (sem texto), placa creme na proa
    for s in (-1, 1):
        for k, (w, kind) in enumerate([(0.2, "bar"), (0.14, "dot"), (0.26, "bar"), (0.12, "dot"), (0.2, "bar")]):
            cz = -1.2 + 0.55 - 0.28 * k
            sx = [p for p in section(-cz) if p.x * s > 0]
            p = min(sx, key=lambda q: abs(q.y - 0.3))
            if kind == "bar":
                m.box((p.x + s * 0.01, 0.3, cz), (0.02, 0.1, w * 0.9), "wv2_glossy", NAVY, 0.005, 1, grain="z")
            else:
                m.sphere((p.x + s * 0.01, 0.3, cz), 1.0, "wv2_glossy", RED, subd=1, scale=(0.012, 0.055, 0.055))
    # carga no convez de proa (longe do banco e do volante): caixote com peixe e balde
    m.box((-0.5, DECK + 0.13, -1.45), (0.42, 0.26, 0.34), "wv2_wood", WOOD_L, 0.015, 1, rot=R(ry=12))
    for k in range(5):
        m.sphere((-0.5 + rng.uniform(-0.12, 0.12), DECK + 0.28, -1.45 + rng.uniform(-0.1, 0.1)), 1.0, "wv2_glossy",
                 hexc("#9FB8C8"), subd=2, scale=(0.12, 0.035, 0.045), rot=R(ry=rng.uniform(0, 180)))
    m.lathe((0.6, DECK, -0.95), [(0.0, 0.0), (0.12, 0.0), (0.15, 0.26), (0.0, 0.26)], "wv2_metal", hexc("#4F82A3"), seg=14)

    ob = m.to_object(materials, collection)
    pob = paw.to_object(materials, collection)
    pob.parent = ob
    empties = []
    for name, (x, y, z) in EMPTIES.items():
        e = bpy.data.objects.new(name, None)
        e.empty_display_size = 0.2
        e.location = (x, -z, y)
        e.parent = ob
        collection.objects.link(e)
        empties.append(e)
    info = {"triangulos": m.tris() + paw.tris(), "materiais": sorted(set(m.mats) | set(paw.mats)),
            "empties": sorted(EMPTIES.keys())}
    return [ob, pob] + empties, info
