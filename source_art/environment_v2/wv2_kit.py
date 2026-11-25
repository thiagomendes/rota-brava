"""Rota Brava · Mundo v2 (RB-R1 W1) · kit de aderecos e vegetacao (instanciados por MultiMesh na Godot).
PROVISORIO ate aprovacao de Thiago. Geometria 100% procedural (wv2lib); cada peca tem origem no chao (y = 0),
frente para +Z. Cores em sRGB (convertidas para linear na cor de vertice).
"""
import math
import random

from mathutils import Vector

from wv2lib import MB, R, T, hexc

WOOD = "wv2_wood"
PAINT = "wv2_paint"
METAL = "wv2_metal"
GLOSSY = "wv2_glossy"
ROPE = "wv2_rope"
NET = "wv2_net"
CANVAS = "wv2_canvas"
LEAF = "wv2_leaf"
BARK = "wv2_bark"
GRASS = "wv2_grass"
ROCK = "wv2_rock"
LAMP = "wv2_lamp"
PLASTER = "wv2_plaster"

IRON = hexc("#2F4A4C")
TERRA = hexc("#D27A4E")


def crate(name="crate", seed=1, size=0.6, color=(1, 1, 1), fill=None):
    m = MB(name)
    rng = random.Random(seed)
    s = size
    b = 0.06
    h = s
    # montantes e travessas (moldura com chanfro)
    for x in (-1, 1):
        for z in (-1, 1):
            m.box((x * (s / 2 - b / 2), h / 2, z * (s / 2 - b / 2)), (b, h, b), WOOD, color, 0.012, 1, grain="y", rng=rng)
    for y in (b / 2, h - b / 2):
        for z in (-1, 1):
            m.box((0, y, z * (s / 2 - b / 2)), (s - 2 * b, b, b), WOOD, color, 0.012, 1, rng=rng)
        for x in (-1, 1):
            m.box((x * (s / 2 - b / 2), y, 0), (b, b, s - 2 * b), WOOD, color, 0.012, 1, grain="z", rng=rng)
    # tabuas laterais (3 por face, com fresta)
    n = 3
    ph = (h - 2 * b) / n
    for k in range(n):
        y = b + ph * (k + 0.5)
        tone = tuple(c * rng.uniform(0.86, 1.05) for c in color)
        for z in (-1, 1):
            m.box((0, y, z * (s / 2 - 0.035)), (s - 2 * b, ph - 0.012, 0.022), WOOD, tone, 0.006, 1, rng=rng)
        for x in (-1, 1):
            m.box((x * (s / 2 - 0.035), y, 0), (0.022, ph - 0.012, s - 2 * b), WOOD, tone, 0.006, 1, grain="z", rng=rng)
    if fill == "lid":
        for k in range(4):
            m.box((0, h - 0.01, -s / 2 + b + (k + 0.5) * (s - 2 * b) / 4), (s - 2 * b, 0.022, (s - 2 * b) / 4 - 0.01), WOOD,
                  color, 0.006, 1, rng=rng)
    else:
        m.box((0, b + 0.01, 0), (s - 2 * b, 0.02, s - 2 * b), WOOD, color, 0.0, 1, rng=rng)
    if fill == "fish":
        for k in range(9):
            a = rng.uniform(0, 180)
            m.sphere((rng.uniform(-0.17, 0.17), h * 0.55 + rng.uniform(0, 0.08), rng.uniform(-0.17, 0.17)), 0.13, GLOSSY,
                     hexc("#9FB8C8") if k % 3 else hexc("#C9A15A"), subd=2, scale=(1, 0.32, 0.38), rot=R(ry=a, rz=rng.uniform(-15, 15)), rng=rng)
        m.box((0, h * 0.5, 0), (s - 2 * b, 0.02, s - 2 * b), WOOD, color, 0.0, 1, rng=rng)
    if fill == "fruit":
        cols = [hexc("#E8442E"), hexc("#F59A23"), hexc("#F4D03F"), hexc("#7DBA3A")]
        c = rng.choice(cols)
        for k in range(14):
            m.sphere((rng.uniform(-0.2, 0.2), h * 0.78 + rng.uniform(0, 0.12), rng.uniform(-0.2, 0.2)), rng.uniform(0.06, 0.075),
                     GLOSSY, tuple(x * rng.uniform(0.85, 1.05) for x in c), subd=1, rng=rng)
        m.box((0, h * 0.72, 0), (s - 2 * b, 0.02, s - 2 * b), WOOD, color, 0.0, 1, rng=rng)
    return m


def barrel(name="barrel", seed=2, lid=False):
    m = MB(name)
    rng = random.Random(seed)
    h = 0.9
    prof = [(0.27, 0.0)] + [(0.27 + 0.055 * math.sin(math.pi * k / 8), h * k / 8) for k in range(1, 8)] + [(0.27, h)]
    m.lathe((0, 0, 0), prof, WOOD, hexc("#C79A6A"), seg=20, uvrot=math.pi / 2, rng=rng)
    for y in (0.1, 0.32, h - 0.32, h - 0.1):
        r = 0.27 + 0.055 * math.sin(math.pi * y / h) + 0.008
        m.lathe((0, 0, 0), [(r, y - 0.03), (r + 0.004, y), (r, y + 0.03)], METAL, hexc("#3B3F44"), seg=20, rng=rng)
    if lid:
        m.cyl((0, h - 0.005, 0), 0.285, 0.05, WOOD, hexc("#B88A5C"), seg=20, bevel=0.015, rng=rng)
        m.box((0, h + 0.075, 0), (0.22, 0.045, 0.06), WOOD, hexc("#9C7552"), 0.012, 1, rng=rng)
        m.box((-0.09, h + 0.055, 0), (0.04, 0.05, 0.05), WOOD, hexc("#9C7552"), 0.01, 1, rng=rng)
        m.box((0.09, h + 0.055, 0), (0.04, 0.05, 0.05), WOOD, hexc("#9C7552"), 0.01, 1, rng=rng)
    else:
        m.cyl((0, h - 0.05, 0), 0.25, 0.04, WOOD, hexc("#A87D52"), seg=20, rng=rng)
    return m


def sack(name="sack", seed=3):
    m = MB(name)
    rng = random.Random(seed)
    m.sphere((0, 0.22, 0), 0.3, "wv2_net", hexc("#C9A876"), subd=3, scale=(1.0, 0.85, 0.8), seed=seed, amp=0.1,
             flat_bottom=-0.2, uv="box", rng=rng)
    m.lathe((0, 0.42, 0), [(0.16, 0.0), (0.07, 0.08), (0.06, 0.14), (0.11, 0.22), (0.0, 0.24)], "wv2_net", hexc("#C2A06E"), seg=12,
            rng=rng)
    m.lathe((0, 0.5, 0), [(0.065, -0.02), (0.08, 0.0), (0.065, 0.02)], ROPE, hexc("#8E6A48"), seg=10, rng=rng)
    return m


def rope_coil(name="rope_coil", seed=4):
    m = MB(name)
    pts = []
    turns = 4.2
    for i in range(int(turns * 24)):
        a = i / 24 * 2 * math.pi
        r = 0.12 + 0.045 * (i / 24)
        pts.append((math.sin(a) * r, 0.03 + 0.012 * math.sin(a * 0.5) + (0.03 if i / 24 > 3.2 else 0), math.cos(a) * r))
    m.tube(pts, 0.026, ROPE, hexc("#D9C38B"), seg=7)
    m.tube([(0.31, 0.03, 0.0), (0.42, 0.03, 0.12), (0.5, 0.025, 0.1)], 0.026, ROPE, hexc("#D9C38B"), seg=7)
    return m


def net_pile(name="net_pile", seed=5):
    m = MB(name)
    rng = random.Random(seed)
    m.sphere((0, 0.0, 0), 0.6, NET, hexc("#6E9F95"), subd=3, scale=(1.1, 0.42, 0.8), seed=seed, amp=0.16, freq=3.0,
             flat_bottom=0.0, uv="box", rng=rng)
    m.sphere((0.18, 0.12, 0.1), 0.38, NET, hexc("#5B8C86"), subd=2, scale=(1, 0.5, 0.9), seed=seed + 1, amp=0.2,
             freq=3.0, flat_bottom=-0.12, uv="box", rng=rng)
    for k in range(9):
        a = k / 9 * 6.28 + rng.uniform(-0.2, 0.2)
        m.sphere((math.cos(a) * 0.55, 0.08 + rng.uniform(0, 0.1), math.sin(a) * 0.42), 0.055, GLOSSY,
                 hexc("#F07A2E") if k % 2 else hexc("#F4D35E"), subd=1, scale=(1, 0.8, 1), rng=rng)
    return m


def life_ring(name="life_ring", seed=6):
    """Boia salva-vidas em pe (para pendurar), centro a 0,4 m."""
    m = MB(name)
    R0, r = 0.3, 0.075
    segs = 8
    for k in range(segs):
        a0 = k / segs * 2 * math.pi
        a1 = (k + 1) / segs * 2 * math.pi
        pts = [(math.cos(a0 + (a1 - a0) * t / 6) * R0, 0.4 + math.sin(a0 + (a1 - a0) * t / 6) * R0, 0) for t in range(7)]
        m.tube(pts, r, GLOSSY, hexc("#E8412F") if k % 2 == 0 else hexc("#FFF6EA"), seg=10, caps=False)
    pts = [(math.cos(a) * (R0 + r + 0.005), 0.4 + math.sin(a) * (R0 + r + 0.005), 0.0) for a in [i / 32 * 6.283 for i in range(33)]]
    m.tube(pts, 0.012, ROPE, hexc("#E9D9A8"), seg=5, caps=False)
    return m


def float_buoy(name="float_buoy", seed=7):
    m = MB(name)
    m.sphere((0, 0.2, 0), 0.2, GLOSSY, hexc("#FF7A21"), subd=2, rng=random.Random(seed))
    m.lathe((0, 0.2, 0), [(0.2, -0.03), (0.212, 0.0), (0.2, 0.03)], GLOSSY, hexc("#FFF4E0"), seg=16)
    m.cyl((0, 0.38, 0), 0.025, 0.08, METAL, hexc("#555A5E"), seg=8)
    return m


def lobster_trap(name="lobster_trap", seed=8):
    m = MB(name)
    rng = random.Random(seed)
    m.box((0, 0.03, 0), (0.8, 0.06, 0.5), WOOD, hexc("#B48A60"), 0.01, 1, rng=rng)
    for x in (-0.36, -0.12, 0.12, 0.36):
        pts = [(x, 0.06 + math.sin(t / 8 * math.pi) * 0.3, -0.24 * math.cos(t / 8 * math.pi)) for t in range(9)]
        m.tube(pts, 0.014, WOOD, hexc("#A07A52"), seg=5)
    # rede: casca cilindrica deitada ao longo de x (sem tampas)
    from wv2lib import _bm_cyl
    bm = _bm_cyl(0.235, 0.235, 0.74, 14, False)
    xf = T(-0.37, 0.06, 0) @ R(rz=-90)
    m.add_bm(bm, xf, NET, hexc("#6A9A8A"), "cyl", "y", rng=rng)
    return m


def bucket(name="bucket", seed=9):
    m = MB(name)
    m.lathe((0, 0, 0), [(0.0, 0.0), (0.13, 0.0), (0.135, 0.01), (0.17, 0.3), (0.165, 0.3), (0.128, 0.03), (0.0, 0.03)],
            METAL, hexc("#4F82A3"), seg=16)
    pts = [(math.cos(a) * 0.17, 0.3 + math.sin(a) * 0.14, 0) for a in [i / 10 * math.pi for i in range(11)]]
    m.tube(pts, 0.007, METAL, hexc("#3B3F44"), seg=5)
    return m


def pot(name="pot", seed=10, flower=("#FF5C8A", "#FFD23F"), size=1.0):
    m = MB(name)
    rng = random.Random(seed)
    s = size
    m.lathe((0, 0, 0), [(0.0, 0.0), (0.14 * s, 0.0), (0.2 * s, 0.32 * s), (0.225 * s, 0.33 * s), (0.225 * s, 0.38 * s),
                        (0.2 * s, 0.38 * s), (0.19 * s, 0.34 * s), (0.0, 0.34 * s)], GLOSSY, TERRA, seg=18, rng=rng)
    m.sphere((0, 0.42 * s, 0), 0.24 * s, LEAF, hexc("#5DAE40"), subd=2, scale=(1, 0.75, 1), seed=seed, amp=0.2, freq=3.2, rng=rng,
             shade=lambda p, w: 0.65 + 0.45 * max(0.0, min(1.0, (p.y / 0.18 + 1) * 0.5)))
    for k in range(10):
        a = rng.uniform(0, 6.28)
        rr = rng.uniform(0.05, 0.2) * s
        c = hexc(flower[k % len(flower)])
        m.sphere((math.cos(a) * rr, (0.5 + rng.uniform(0, 0.08) - rr * 0.6) * s, math.sin(a) * rr), 0.045 * s, GLOSSY, c, subd=1,
                 scale=(1, 0.6, 1), rng=rng)
    return m


def planter(name="planter", seed=11, flower=("#FF6F91", "#FFFFFF", "#FFC93C")):
    m = MB(name)
    rng = random.Random(seed)
    m.box((0, 0.2, 0), (1.3, 0.4, 0.45), PAINT, hexc("#3E8C8C"), 0.025, 2, rng=rng)
    m.box((0, 0.395, 0), (1.22, 0.02, 0.37), "wv2_terrain", hexc("#5A4532"), 0.0, 1, rng=rng)
    for k in range(4):
        m.sphere((-0.45 + k * 0.3, 0.48, rng.uniform(-0.04, 0.04)), 0.22, LEAF, hexc("#5FB044"), subd=2, scale=(1, 0.7, 0.9),
                 seed=seed + k, amp=0.2, freq=3.0, rng=rng,
                 shade=lambda p, w: 0.65 + 0.45 * max(0.0, min(1.0, (p.y / 0.15 + 1) * 0.5)))
    for k in range(18):
        m.sphere((rng.uniform(-0.58, 0.58), 0.58 + rng.uniform(0, 0.08), rng.uniform(-0.16, 0.16)), 0.04, GLOSSY,
                 hexc(flower[k % len(flower)]), subd=1, scale=(1, 0.6, 1), rng=rng)
    return m


def bench(name="bench", seed=12):
    m = MB(name)
    rng = random.Random(seed)
    for k in range(3):
        m.box((0, 0.45, -0.16 + k * 0.13), (1.6, 0.04, 0.11), WOOD, hexc("#C08A55"), 0.012, 2, rng=rng)
    for k in range(2):
        m.box((0, 0.68 + k * 0.16, -0.28 - k * 0.03), (1.6, 0.11, 0.035), WOOD, hexc("#C08A55"), 0.012, 2, rot=R(rx=-12), rng=rng)
    for x in (-0.68, 0.68):
        leg = [(-0.22, 0.0), (-0.16, 0.0), (-0.1, 0.43), (0.18, 0.43), (0.12, 0.0), (0.2, 0.0), (0.24, 0.47), (-0.32, 0.47),
               (-0.36, 0.95), (-0.3, 0.95), (-0.26, 0.47)]
        m.prism((x, 0, 0), [(z, y) for z, y in leg], 0.04, METAL, IRON, rot=R(ry=90), rng=rng)
    return m


def lamp_post(name="lamp_post", seed=13):
    m = MB(name)
    rng = random.Random(seed)
    m.lathe((0, 0, 0), [(0.2, 0.0), (0.2, 0.08), (0.15, 0.12), (0.12, 0.3), (0.085, 0.36), (0.0, 0.36)], METAL, IRON, seg=16, rng=rng)
    m.cyl((0, 0.34, 0), 0.06, 2.5, METAL, IRON, r1=0.045, seg=12, rng=rng)
    m.lathe((0, 2.8, 0), [(0.06, 0.0), (0.09, 0.05), (0.06, 0.1)], METAL, IRON, seg=12, rng=rng)
    # lanterna no topo (gaiola + vidro que brilha + chapeu)
    y0 = 2.92
    m.lathe((0, y0, 0), [(0.0, 0.0), (0.12, 0.0), (0.13, 0.04), (0.0, 0.04)], METAL, IRON, seg=8, rng=rng)
    m.lathe((0, y0 + 0.04, 0), [(0.1, 0.0), (0.135, 0.36), (0.0, 0.36)], LAMP, hexc("#FFE3A6"), seg=8, rng=rng)
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        m.box((math.sin(a) * 0.125, y0 + 0.22, math.cos(a) * 0.125), (0.022, 0.38, 0.022), METAL, IRON, 0.0, 1,
              rot=R(ry=math.degrees(a)), rng=rng)
    m.lathe((0, y0 + 0.4, 0), [(0.21, 0.0), (0.2, 0.03), (0.06, 0.15), (0.03, 0.2), (0.045, 0.24), (0.0, 0.27)], METAL, IRON,
            seg=12, rng=rng)
    return m


def bollard(name="bollard", seed=14):
    m = MB(name)
    m.lathe((0, 0, 0), [(0.0, 0.0), (0.17, 0.0), (0.15, 0.05), (0.12, 0.35), (0.16, 0.42), (0.17, 0.48), (0.12, 0.55), (0.0, 0.56)],
            METAL, hexc("#2B2F33"), seg=16)
    return m


def fender(name="fender", seed=15):
    """Defensa pendurada: origem no ponto de amarracao (topo); o corpo desce."""
    m = MB(name)
    m.lathe((0, -0.95, 0), [(0.0, 0.0), (0.09, 0.02), (0.13, 0.1), (0.14, 0.3), (0.14, 0.55), (0.13, 0.75), (0.09, 0.83),
                            (0.0, 0.85)], GLOSSY, hexc("#2E5C8A"), seg=14)
    m.tube([(0, -0.1, 0), (0, 0.0, 0.0), (0, 0.06, -0.04)], 0.014, ROPE, hexc("#E6D29C"), seg=6)
    return m


def cart(name="cart", seed=16):
    m = MB(name)
    rng = random.Random(seed)
    m.box((0, 0.62, 0), (1.3, 0.06, 0.8), WOOD, hexc("#B98B5C"), 0.012, 1, rng=rng)
    for z in (-0.38, 0.38):
        m.box((0, 0.78, z), (1.3, 0.26, 0.04), PAINT, hexc("#3D7DC4"), 0.01, 1, rng=rng)
    for x in (-0.63, 0.63):
        m.box((x, 0.78, 0), (0.04, 0.26, 0.8), PAINT, hexc("#3D7DC4"), 0.01, 1, grain="z", rng=rng)
    for z in (-0.3, 0.3):
        m.box((-1.05, 0.66, z), (0.9, 0.05, 0.05), WOOD, hexc("#A87D52"), 0.012, 1, rng=rng)
    m.cyl((0.2, 0.36, -0.45), 0.035, 0.9, METAL, hexc("#3B3F44"), seg=8, rot=R(rx=90))
    for z in (-0.47, 0.47):
        ring = [(0.2 + math.sin(a) * 0.34, 0.36 + math.cos(a) * 0.34, z) for a in [i / 24 * 6.2832 for i in range(25)]]
        m.tube(ring, 0.035, WOOD, hexc("#8E6A48"), seg=6, caps=False)
        for k in range(6):
            a = k / 6 * math.pi
            m.box((0.2, 0.36, z), (0.03, 0.66, 0.03), WOOD, hexc("#8E6A48"), 0.0, 1, rot=R(rz=math.degrees(a)), grain="y", rng=rng)
        m.cyl((0.2, 0.36, z - 0.05), 0.07, 0.1, METAL, hexc("#3B3F44"), seg=10, rot=R(rx=90))
    m.box((0.85, 0.3, 0), (0.05, 0.6, 0.05), WOOD, hexc("#A87D52"), 0.01, 1, grain="y", rng=rng)
    for k in range(5):
        m.sphere((rng.uniform(-0.4, 0.5), 0.75 + rng.uniform(0, 0.08), rng.uniform(-0.25, 0.25)), 0.075, GLOSSY,
                 hexc("#F59A23") if k % 2 else hexc("#E8442E"), subd=1, rng=rng)
    return m


def sign_aframe(name="sign_aframe", seed=17):
    m = MB(name)
    rng = random.Random(seed)
    for s in (-1, 1):
        m.box((0, 0.48, s * 0.17), (0.6, 0.95, 0.03), PAINT, hexc("#2F4F6F"), 0.012, 2, rot=R(rx=s * 12), rng=rng)
        m.box((0, 0.55, s * 0.19), (0.46, 0.6, 0.012), PAINT, hexc("#FFF3DA"), 0.004, 1, rot=R(rx=s * 12), rng=rng)
        m.sphere((0.0, 0.6, s * 0.205), 0.12, GLOSSY, hexc("#FF8A3D"), subd=2, scale=(1, 0.5, 0.15), rot=R(rx=s * 12), rng=rng)
        m.prism((0.14, 0.6, s * 0.205), [(0, 0), (0.09, 0.07), (0.09, -0.07)], 0.02, GLOSSY, hexc("#FF8A3D"), rot=R(rx=s * 12))
    return m


def cafe_set(name="cafe_set", seed=18):
    m = MB(name)
    rng = random.Random(seed)
    m.cyl((0, 0, 0), 0.22, 0.03, METAL, IRON, seg=14)
    m.cyl((0, 0.03, 0), 0.03, 0.68, METAL, IRON, seg=8)
    m.cyl((0, 0.71, 0), 0.35, 0.035, PAINT, hexc("#FFFFFF"), seg=20, bevel=0.01)
    m.cyl((0.1, 0.745, 0.05), 0.045, 0.08, GLOSSY, hexc("#FFFFFF"), seg=10)
    for a in (0, 180):
        cx, cz = math.sin(math.radians(a)) * 0.62, math.cos(math.radians(a)) * 0.62
        rot = R(ry=a)
        for dx in (-0.17, 0.17):
            for dz in (-0.17, 0.17):
                p = rot @ Vector((dx, 0, dz))
                m.cyl((cx + p.x, 0, cz + p.z), 0.018, 0.45, METAL, IRON, seg=6)
        m.box((cx, 0.46, cz), (0.42, 0.04, 0.42), PAINT, hexc("#E8553E"), 0.012, 2, rot=rot)
        p = rot @ Vector((0, 0.72, 0.2))
        m.box((cx + p.x, p.y, cz + p.z), (0.42, 0.42, 0.03), PAINT, hexc("#E8553E"), 0.012, 2, rot=rot @ R(rx=8))
    return m


def parasol(name="parasol", seed=19):
    m = MB(name)
    m.cyl((0, 0, 0), 0.2, 0.05, METAL, IRON, seg=12)
    m.cyl((0, 0, 0), 0.025, 2.35, WOOD, hexc("#C8A27A"), seg=8)
    n = 8
    for k in range(n):
        a0 = k / n * 2 * math.pi
        a1 = (k + 1) / n * 2 * math.pi
        poly = [(0, 0), (math.sin(a0) * 1.3, math.cos(a0) * 1.3), (math.sin(a1) * 1.3, math.cos(a1) * 1.3)]
        col = hexc("#FFFFFF") if k % 2 else hexc("#F2A541")
        # gomos: triangulo inclinado (topo em 2,4 m, borda em 2,0 m)
        from wv2lib import _bm_prism
        import bmesh as _b
        bm = _bm_prism([(0, 0), (1, 0), (0, 1)], 0.02)
        for v in bm.verts:
            x, y, z = v.co
            px = poly[0][0] * (1 - x - y) + poly[1][0] * x + poly[2][0] * y
            pz = poly[0][1] * (1 - x - y) + poly[1][1] * x + poly[2][1] * y
            d = math.hypot(px, pz)
            v.co = Vector((px, 2.42 - d * 0.32 + z, pz))
        m.add_bm(bm, T(), CANVAS, col, "box", "x")
    return m


def stall(name="stall", seed=20, awning="#E8442E", goods=("#E8442E", "#F59A23", "#F4D03F", "#7DBA3A")):
    """Barraca de mercado: mesa com caixotes de produtos, 4 postes, toldo de duas aguas listrado com babado."""
    m = MB(name)
    rng = random.Random(seed)
    W, D = 2.4, 1.3
    for x in (-W / 2 + 0.05, W / 2 - 0.05):
        for z in (-D / 2 + 0.05, D / 2 - 0.05):
            m.box((x, 1.15, z), (0.08, 2.3, 0.08), WOOD, hexc("#B48A60"), 0.015, 2, grain="y", rng=rng)
    m.box((0, 0.86, 0.05), (W - 0.1, 0.06, D - 0.15), WOOD, hexc("#C79A6A"), 0.015, 2, rng=rng)
    m.box((0, 0.45, D / 2 - 0.1), (W - 0.2, 0.75, 0.03), PAINT, hexc(awning), 0.01, 1, rng=rng)
    # caixotes de produtos inclinados para a frente
    for k in range(3):
        x = -0.75 + k * 0.75
        m.box((x, 0.95, 0.15), (0.62, 0.12, 0.5), WOOD, hexc("#B98B5C"), 0.012, 1, rot=R(rx=12), rng=rng)
        c = hexc(goods[k % len(goods)])
        for j in range(16):
            px = x + rng.uniform(-0.24, 0.24)
            pz = 0.15 + rng.uniform(-0.18, 0.2)
            py = 1.04 - (pz - 0.15) * 0.2 + rng.uniform(0, 0.04)
            m.sphere((px, py, pz), rng.uniform(0.05, 0.065), GLOSSY, tuple(x_ * rng.uniform(0.85, 1.05) for x_ in c), subd=1, rng=rng)
    # caixotes no chao e balanca
    m.box((W / 2 - 0.4, 0.2, -0.2), (0.5, 0.4, 0.5), WOOD, hexc("#B48A60"), 0.015, 1, rng=rng)
    m.cyl((-W / 2 + 0.4, 0.89, -0.25), 0.12, 0.03, METAL, hexc("#C9A13A"), seg=12)
    m.cyl((-W / 2 + 0.4, 0.89, -0.25), 0.02, 0.25, METAL, hexc("#C9A13A"), seg=6)
    # toldo de duas aguas (cumeeira ao longo de x)
    ridge_y, eave_y = 2.55, 2.15
    half = D / 2 + 0.25
    slope = math.degrees(math.atan2(ridge_y - eave_y, half))
    L = math.hypot(ridge_y - eave_y, half)
    for s in (-1, 1):
        m.box((0, (ridge_y + eave_y) / 2, s * half / 2), (W + 0.3, 0.025, L), CANVAS, hexc(awning), 0.0, 1,
              rot=R(rx=s * slope), uvrot=math.pi / 2, rng=rng)
        # babado recortado
        n = 9
        for k in range(n):
            x0 = -(W + 0.3) / 2 + (k + 0.5) * (W + 0.3) / n
            poly = [(-0.5, 0), (0.5, 0)] + [(math.cos(a) * 0.5, -0.4 * math.sin(a) - 0.0) for a in
                                             [math.pi * t / 6 for t in range(1, 6)]]
            poly = [(x0 + px * (W + 0.3) / n, eave_y + py * 0.45) for px, py in poly]
            m.prism((0, 0, s * (half + 0.0)), poly, 0.02, CANVAS, hexc(awning), uvoff=(k * 0.25, 0))
    return m


# ------------------------------------------------------------------ vegetacao
def _canopy_shade(center_y, radius):
    def f(p, w):
        t = max(0.0, min(1.0, (p.y - (center_y - radius)) / (2 * radius)))
        return 0.55 + 0.6 * t
    return f


def tree(name="tree_a", seed=30, height=4.2, crown=1.6, blobs=8, kind="round", leaf="#5DAE40"):
    m = MB(name)
    rng = random.Random(seed)
    top = height - crown * 0.9
    # tronco com leve curva e raizes
    pts = [(0, 0, 0)]
    for k in range(1, 7):
        t = k / 6
        pts.append((math.sin(t * 2.2 + seed) * 0.12 * t, top * t, math.cos(t * 1.7 + seed) * 0.08 * t))
    m.tube(pts, lambda t: 0.2 * (1 - t) + 0.09 * t + 0.08 * max(0, 0.15 - t) / 0.15, BARK, hexc("#8A6040"), seg=10, uv="box")
    for k in range(3):
        a = k * 2.1 + seed
        bp = Vector(pts[4])
        tip = bp + Vector((math.cos(a) * crown * 0.55, crown * 0.45, math.sin(a) * crown * 0.55))
        m.tube([bp, bp.lerp(tip, 0.5) + Vector((0, 0.1, 0)), tip], lambda t: 0.08 * (1 - t) + 0.03, BARK, hexc("#8A6040"), seg=6)
    for k in range(4):
        a = k * 1.57 + seed
        m.sphere((math.cos(a) * 0.18, 0.02, math.sin(a) * 0.18), 0.14, BARK, hexc("#7A5636"), subd=1, scale=(1.3, 0.5, 0.7),
                 rot=R(ry=-math.degrees(a)), rng=rng)
    cy = top + crown * 0.5
    if kind == "column":
        layout = [(0, cy - crown * 0.6 + i * crown * 0.42, 0, crown * (0.62 - abs(i - 2) * 0.08)) for i in range(5)]
    else:
        layout = [(0, cy + crown * 0.25, 0, crown * 0.72)]
        for k in range(blobs - 1):
            a = k / (blobs - 1) * 2 * math.pi + rng.uniform(-0.3, 0.3)
            rr = crown * rng.uniform(0.55, 0.75)
            layout.append((math.cos(a) * rr, cy + rng.uniform(-0.35, 0.3) * crown, math.sin(a) * rr, crown * rng.uniform(0.5, 0.66)))
    for i, (x, y, z, r) in enumerate(layout):
        c = tuple(x_ * rng.uniform(0.9, 1.08) for x_ in hexc(leaf))
        m.sphere((x, y, z), r, LEAF, c, subd=3 if r > 0.8 else 2, scale=(1, 0.86, 1), seed=seed * 31 + i, amp=0.3, freq=3.2,
                 shade=_canopy_shade(cy, crown * 1.25), rng=rng)
    # tufos de folhas na casca da copa: quebram a silhueta de bola (copa em grupos)
    nclump = 16 if kind == "column" else 26
    for i in range(nclump):
        bx, by, bz, br = layout[rng.randrange(len(layout))]
        d = Vector((rng.uniform(-1, 1), rng.uniform(-0.45, 1.0), rng.uniform(-1, 1))).normalized()
        r = br * rng.uniform(0.32, 0.46)
        p = Vector((bx, by, bz)) + Vector((d.x, d.y * 0.86, d.z)) * br * 0.92
        c = tuple(x_ * rng.uniform(0.95, 1.15) for x_ in hexc(leaf))
        m.sphere(tuple(p), r, LEAF, c, subd=2, scale=(1, 0.8, 1), seed=seed * 57 + i, amp=0.32, freq=3.5,
                 shade=_canopy_shade(cy, crown * 1.25), rng=rng)
    return m


def bush(name="bush", seed=40, size=0.7, flowers=None, leaf="#4FA83D"):
    m = MB(name)
    rng = random.Random(seed)
    for i in range(4):
        a = i * 1.7 + seed
        r = size * rng.uniform(0.5, 0.7)
        m.sphere((math.cos(a) * size * 0.35, r * 0.7, math.sin(a) * size * 0.3), r, LEAF,
                 tuple(x_ * rng.uniform(0.9, 1.1) for x_ in hexc(leaf)), subd=2, scale=(1, 0.85, 1), seed=seed * 7 + i, amp=0.24,
                 freq=3.0, flat_bottom=-r * 0.6, shade=lambda p, w: 0.55 + 0.6 * max(0.0, min(1.0, p.y / (size * 1.1))), rng=rng)
    for i in range(9):
        a = rng.uniform(0, 6.28)
        d = Vector((math.cos(a), rng.uniform(0.0, 0.9), math.sin(a))).normalized()
        r = size * rng.uniform(0.2, 0.3)
        m.sphere((d.x * size * 0.62, size * 0.45 + d.y * size * 0.5, d.z * size * 0.55), r, LEAF,
                 tuple(x_ * rng.uniform(0.95, 1.15) for x_ in hexc(leaf)), subd=2, scale=(1, 0.8, 1), seed=seed * 13 + i,
                 amp=0.3, freq=3.5, shade=lambda p, w: 0.55 + 0.6 * max(0.0, min(1.0, p.y / (size * 1.1))), rng=rng)
    if flowers:
        for k in range(26):
            a = rng.uniform(0, 6.28)
            el = rng.uniform(0.15, 1.2)
            rr = size * 0.72
            p = (math.cos(a) * rr * math.cos(el), size * 0.55 + math.sin(el) * size * 0.6, math.sin(a) * rr * math.cos(el) * 0.85)
            m.sphere(p, 0.05, GLOSSY, hexc(flowers[k % len(flowers)]), subd=1, scale=(1, 0.7, 1), rng=rng)
    return m


def grass_tuft(name="grass_tuft", seed=50, height=0.26, blades=24, color="#6DBA48", flowers=None):
    m = MB(name)
    rng = random.Random(seed)
    import bmesh as _b
    for k in range(blades):
        a = rng.uniform(0, 6.28)
        lean = rng.uniform(0.25, 0.75)
        h = height * rng.uniform(0.55, 1.15)
        w = 0.026 * rng.uniform(0.8, 1.25)
        bm = _b.new()
        vs = []
        n = 4
        for i in range(n + 1):
            t = i / n
            off = lean * t * t * h
            ww = w * (1 - t * 0.92)
            vs.append((bm.verts.new((-ww, t * h, off)), bm.verts.new((ww, t * h, off))))
        for i in range(n):
            bm.faces.new((vs[i][0], vs[i][1], vs[i + 1][1], vs[i + 1][0]))
        base = rng.uniform(0, 0.13)
        c = hexc(color, rng.uniform(0.85, 1.12))
        m.add_bm(bm, T(math.cos(a) * base, 0, math.sin(a) * base) @ R(ry=math.degrees(a)), GRASS, c, "none", "x",
                 shade=lambda p, w_: 0.45 + 0.75 * min(1.0, p.y / height))
    if flowers:
        for k in range(3):
            a = rng.uniform(0, 6.28)
            h = height * rng.uniform(1.0, 1.4)
            x, z = math.cos(a) * 0.05, math.sin(a) * 0.05
            m.tube([(x * 0.3, 0, z * 0.3), (x, h * 0.6, z), (x * 1.2, h, z * 1.2)], 0.006, GRASS, hexc("#4F8F3A"), seg=4)
            c = hexc(flowers[k % len(flowers)])
            for p in range(5):
                pa = p / 5 * 6.283
                m.sphere((x * 1.2 + math.cos(pa) * 0.022, h + 0.005, z * 1.2 + math.sin(pa) * 0.022), 0.02, GLOSSY, c, subd=1,
                         scale=(1, 0.35, 1), rng=rng)
            m.sphere((x * 1.2, h + 0.012, z * 1.2), 0.012, GLOSSY, hexc("#FFC21A"), subd=1, rng=rng)
    return m


def reeds(name="reeds", seed=60):
    m = grass_tuft(name, seed, height=1.25, blades=14, color="#7FAE4C")
    rng = random.Random(seed + 1)
    for k in range(4):
        a = rng.uniform(0, 6.28)
        r = rng.uniform(0.02, 0.1)
        h = rng.uniform(1.1, 1.45)
        x, z = math.cos(a) * r, math.sin(a) * r
        m.tube([(x, 0, z), (x * 1.5, h * 0.6, z * 1.5), (x * 2, h, z * 2)], 0.008, GRASS, hexc("#6E9443"), seg=4)
        m.cyl((x * 2, h - 0.05, z * 2), 0.028, 0.18, GLOSSY, hexc("#7A4E2E"), seg=8)
    return m


def rock(name="rock", seed=70, size=0.6, flat=0.6):
    m = MB(name)
    m.sphere((0, size * flat * 0.5, 0), size, ROCK, hexc("#FFFFFF"), subd=3, scale=(1, flat, 0.85), seed=seed, amp=0.22,
             freq=1.8, flat_bottom=-size * flat * 0.45, shade=lambda p, w: 0.6 + 0.45 * max(0.0, min(1.0, p.y / (size * flat) + 0.5)),
             rng=random.Random(seed))
    return m


def rowboat(name="rowboat", seed=80, hull="#3D7DC4", trim="#FFF4E0"):
    """Bote de remo (casco em secoes; proa em -Z), linha d'agua em y = 0."""
    import bmesh as _b
    m = MB(name)
    rng = random.Random(seed)
    L = 3.4
    ns, nr = 16, 7

    def section(t, inset=0.0):
        z = (t - 0.5) * L
        half = 0.66 * max(0.0, 1 - abs(2 * t - 1) ** 2.2) ** 0.55 + 0.02 - inset
        depth = 0.42 - inset
        sheer = 0.38 + 0.12 * (2 * t - 1) ** 2
        pts = []
        for j in range(nr + 1):
            a = j / nr * math.pi
            x = -math.cos(a) * half
            y = sheer - math.sin(a) * depth * (0.75 + 0.25 * (1 - abs(2 * t - 1)))
            pts.append(Vector((x, y - 0.12, z)))
        return pts

    for inset, mat, col in ((0.0, PAINT, hexc(hull)), (0.035, WOOD, hexc("#C9A57A"))):
        bm = _b.new()
        rows = []
        for i in range(ns + 1):
            rows.append([bm.verts.new(p) for p in section(i / ns, inset)])
        for i in range(ns):
            for j in range(nr):
                f = (rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1])
                bm.faces.new(f if inset == 0 else tuple(reversed(f)))
        _b.ops.remove_doubles(bm, verts=bm.verts, dist=0.004)
        m.add_bm(bm, T(), mat, col, "box", "z", rng=rng)
    for i in range(ns):
        a = section(i / ns)
        b = section((i + 1) / ns)
        for side in (0, nr):
            p0, p1 = a[side], b[side]
            m.tube([p0 + Vector((0, 0.015, 0)), p1 + Vector((0, 0.015, 0))], 0.03, PAINT, hexc(trim), seg=6)
    for t in (0.35, 0.62):
        s = section(t, 0.03)
        w = abs(s[0].x) * 2
        m.box((0, s[0].y - 0.12, s[0].z), (w, 0.04, 0.24), WOOD, hexc("#B98B5C"), 0.01, 1, rng=rng)
    m.tube([(0.2, 0.18, -0.4), (0.3, 0.2, 0.9)], 0.02, WOOD, hexc("#C8A27A"), seg=6)
    m.box((0.32, 0.2, 1.05), (0.12, 0.02, 0.4), WOOD, hexc("#C8A27A"), 0.008, 1, grain="z", rng=rng)
    return m


def build_all():
    k = {}
    k["crate"] = crate("crate", 1, color=hexc("#D8B489"))
    k["crate_dark"] = crate("crate_dark", 101, color=hexc("#B08A64"), fill="lid")
    k["crate_fish"] = crate("crate_fish", 102, size=0.6, color=hexc("#C9A37A"), fill="fish")
    k["crate_fruit"] = crate("crate_fruit", 103, size=0.6, color=hexc("#D2AE84"), fill="fruit")
    k["barrel"] = barrel("barrel", 2)
    k["barrel_lid"] = barrel("barrel_lid", 22, lid=True)
    k["sack"] = sack()
    k["rope_coil"] = rope_coil()
    k["net_pile"] = net_pile()
    k["life_ring"] = life_ring()
    k["float_buoy"] = float_buoy()
    k["lobster_trap"] = lobster_trap()
    k["bucket"] = bucket()
    k["pot_a"] = pot("pot_a", 10, ("#FF5C8A", "#FFD23F"))
    k["pot_b"] = pot("pot_b", 110, ("#FFFFFF", "#E8442E"), size=0.8)
    k["pot_c"] = pot("pot_c", 210, ("#B57CFF", "#FFFFFF"), size=1.15)
    k["planter"] = planter()
    k["bench"] = bench()
    k["lamp_post"] = lamp_post()
    k["bollard"] = bollard()
    k["fender"] = fender()
    k["cart"] = cart()
    k["sign_aframe"] = sign_aframe()
    k["cafe_set"] = cafe_set()
    k["parasol"] = parasol()
    k["stall_red"] = stall("stall_red", 20, "#E8442E", ("#F59A23", "#7DBA3A", "#F4D03F"))
    k["stall_blue"] = stall("stall_blue", 21, "#2F7FD8", ("#E8442E", "#9FB8C8", "#F4D03F"))
    k["stall_yellow"] = stall("stall_yellow", 23, "#F2B632", ("#7DBA3A", "#E8442E", "#B57CFF"))
    k["tree_a"] = tree("tree_a", 30, 4.6, 1.75, 8, "round", "#5DAE40")
    k["tree_b"] = tree("tree_b", 31, 6.0, 1.3, 5, "column", "#3F9244")
    k["tree_c"] = tree("tree_c", 32, 3.6, 1.4, 7, "round", "#7CC24A")
    k["bush_a"] = bush("bush_a", 40, 0.75, None, "#4FA83D")
    k["bush_b"] = bush("bush_b", 41, 0.6, ("#FF6F91", "#FFFFFF"), "#5DAE40")
    k["bush_c"] = bush("bush_c", 42, 0.55, ("#FFC93C", "#FF8A3D"), "#6DBA48")
    k["grass_tuft"] = grass_tuft("grass_tuft", 50)
    k["grass_tall"] = grass_tuft("grass_tall", 51, height=0.42, blades=26, color="#7DBE4E")
    k["flowers_a"] = grass_tuft("flowers_a", 52, 0.3, 8, "#64B044", ("#FFFFFF", "#FFE45C"))
    k["flowers_b"] = grass_tuft("flowers_b", 53, 0.3, 8, "#64B044", ("#FF6F91", "#B57CFF"))
    k["reeds"] = reeds()
    k["rock_a"] = rock("rock_a", 70, 0.6, 0.6)
    k["rock_b"] = rock("rock_b", 71, 1.1, 0.5)
    k["rowboat_a"] = rowboat("rowboat_a", 80, "#3D7DC4", "#FFF4E0")
    k["rowboat_b"] = rowboat("rowboat_b", 81, "#E8553E", "#FFF4E0")
    return k
