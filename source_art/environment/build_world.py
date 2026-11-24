"""Mundo do Ep01 alem do porto (RB-R1, PROVISORIO ate aprovacao de Thiago): terrenos (margens do rio, ilha, banco de
areia, promontorio do farol, agua distante) e pecas (ponte em arco, cerca rustica, palmeira, barraca, fogueira, bandeira,
rochas da travessia seguras/iscas, rochedo, concha, pier pequeno, gaivota pousada). Paleta: docs/style-bible.md.
Terrenos sao modelados em coordenadas do MUNDO (origem 0, metros, espaco Godot) conforme
game/episodes/ep01/world/LAYOUT_PROPOSTO.md; pecas tem origem na base (rocha segura: origem no TOPO).
Uso: blender --background --factory-startup --python build_world.py -- --blend X --glb-dir Y
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh
from mathutils import Vector
from envlib import (REPO, Asset, arg_value, clamp, gbox, gcyl, gsph, grid_patch, lathe, reset_scene, save_all, sweep)
from rbart import hex_to_linear, mat as _mat
from build_village import village_materials

WATER_Y = -0.4
EXTRA = {"mat_env_tent": ("#FFB347", 0.85), "mat_env_tent_dark": ("#E07A2E", 0.85), "mat_env_flag": ("#FFC83D", 0.7),
         "mat_env_flag_navy": ("#123A5E", 0.7), "mat_env_rock_safe": ("#EFE3CC", 0.95), "mat_env_rock_wet": ("#4A5866", 0.18),
         "mat_env_far_water": ("#1F8A98", 0.3), "mat_env_ash": ("#5B5560", 0.95), "mat_env_palm": ("#B88A5A", 0.9)}


def M_all():
    M = village_materials()
    for n, (hx, ro) in EXTRA.items():
        M[n] = _mat(n, hx, ro, 0.0)
    return M


def noise(x, z, s):
    return (math.sin(x * 1.3 + s) * math.cos(z * 0.9 - s * 1.7) + 0.5 * math.sin(x * 2.9 + z * 2.3 + s * 3.1)
            + 0.25 * math.sin(x * 5.7 - z * 4.9 + s)) / 1.75


def smooth(e0, e1, x):
    t = clamp((x - e0) / (e1 - e0))
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    return [a[i] * (1 - t) + b[i] * t for i in range(3)]


SAND = hex_to_linear("#F2D9A6")
WETSAND = hex_to_linear("#C9A878")
GRASS = hex_to_linear("#7CCB4A")
GRASS_L = hex_to_linear("#A6DB62")
GRASS_D = hex_to_linear("#4FA83D")
ROCK = hex_to_linear("#A9A3B8")
EARTH = hex_to_linear("#B98A5E")


# ------------------------------------------------------------------ geografia (mundo)
def zN(x):
    return -14.6 - 1.4 * (0.5 + 0.5 * math.sin(x / 9.0)) - 1.1 * (0.5 + 0.5 * math.sin(x / 23.0 + 1.0))


def zS(x):
    return 14.6 + 1.4 * (0.5 + 0.5 * math.sin(x / 11.0 + 2.0)) + 1.0 * (0.5 + 0.5 * math.sin(x / 19.0))


def sdf_north(x, z):
    wob = 4.0 * math.sin(x / 13.0) + 2.5 * math.sin(x / 5.3 + 1.0)
    wz = 3.0 * math.sin(z / 9.0) + 1.5 * math.sin(z / 4.1)
    return min(zN(x) - z, x - 36.0 - wz, 184.0 - x + wz, z + 70.0 + wob)


def sdf_south(x, z):
    wob = 4.0 * math.sin(x / 11.0 + 2.0) + 2.5 * math.sin(x / 4.7)
    s = min(z - zS(x), x - 10.0, 182.0 - x, 70.0 - z + wob)
    tongue = min(z - 1.5, 182.0 - x, x - 175.0)            # margem oeste do braco (pouso de Pico)
    s = max(s, tongue)
    s = min(s, math.hypot(x - 166.0, z - 21.0) - 8.0)      # enseada
    return s


def sdf_island(x, z):
    a = math.atan2(z - 1.0, x - 201.0)
    rx, rz = 11.0, 15.0
    r = math.hypot((x - 201.0) / rx, (z - 1.0) / rz)
    return (1.0 - r) * min(rx, rz) * (1.0 + 0.06 * math.sin(3 * a + 1.0))


def flat_zone(x, z):
    """Areas onde se anda: topo exato y = 0."""
    if 175.5 <= x <= 182.0 and 1.5 <= z <= 18.0:
        return True
    return False


def land_h(x, z, sdf, top_fn, flat=None, beach=0.0):
    """Altura do terreno: fundo em y = -4 (fora do alcance da cor rasa da agua), praia, barranco e topo; zonas
    planas (onde se anda) em y = 0 exato."""
    d = sdf(x, z)
    top = top_fn(x, z, d)
    h = -4.0 + (4.0 + top) * smooth(-7.0, 3.5 + beach, d)
    if flat and d > 0.8 and flat(x, z):
        h = 0.0
    return h


def terrain(M, info, glb, name, x0, x1, z0, z1, cell, sdf, top_fn, flat=None, seed=1, beach=0.0):
    a = Asset(name, M, seed)
    nx, nz = int((x1 - x0) / cell), int((z1 - z0) / cell)

    def H(x, z):
        return land_h(x, z, sdf, top_fn, flat, beach)
    bm = bmesh.new()
    lay = bm.verts.layers.float_color.new("Col")
    vs, faces = grid_patch(bm, x0, x1, z0, z1, nx, nz, H)
    for row in vs:
        for v in row:
            x, z, y = v.co.x, v.co.z, v.co.y
            n1 = 0.5 + 0.5 * noise(x * 0.35, z * 0.35, seed)
            n2 = 0.5 + 0.5 * noise(x * 1.1 + 4, z * 1.0, seed + 3)
            g = mix(mix(GRASS, GRASS_L, n1), GRASS_D, smooth(0.6, 0.9, n2))
            sand_t = max(1.0 - smooth(-0.15, 0.12, y), 1.0 - smooth(0.6 + beach, 1.6 + beach * 2.0, sdf(x, z)))
            c = mix(g, SAND, sand_t)
            c = mix(c, WETSAND, 1.0 - smooth(-0.9, -0.35, y))
            k = 0.88 + 0.12 * n2
            v[lay] = tuple(clamp(c[i] * k) for i in range(3)) + (1.0,)
    kill = [f for f in faces if all(v.co.y < -3.9 for v in f.verts)]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    a.part("Ground", bm, "mat_env_ground", paint=False)
    a.finish(glb, info)


def bank_top(x, z, d):
    roll = 0.5 + 0.5 * math.sin(x * 0.045 + 1.0) * math.cos(z * 0.06)
    return 0.5 + 0.8 * clamp(0.5 + 0.5 * noise(x * 0.08, z * 0.1, 2.0)) + min(1.0, max(0.0, d - 8.0) / 25.0) * (1.5 + 4.5 * roll)


def island_top(x, z, d):
    return 0.0 + 1.6 * smooth(205.0, 211.0, x) * smooth(2.0, 6.0, d)


def headland(M, info, glb):
    """Promontorio do farol (31, -24): morro arredondado com plato y = 2,4 (raio 3,6) para a base do farol,
    saia de rocha cinza-lilas na agua e grama no topo."""
    a = Asset("Headland", M, 80)
    cx, cz = 31.0, -24.0

    def H(x, z):
        r = math.hypot(x - cx, z - cz)
        ang = math.atan2(z - cz, x - cx)
        R = 10.0 * (1 + 0.08 * math.sin(3 * ang) + 0.05 * math.sin(7 * ang + 1))
        if r <= 3.6:
            return 2.4
        t = clamp((r - 3.6) / (R - 3.6))
        return -1.2 + 3.6 * (1 - t * t) ** 1.3 + 0.12 * noise(x, z, 4) * t * (1 - t) * 4
    bm = bmesh.new()
    lay = bm.verts.layers.float_color.new("Col")
    vs, faces = grid_patch(bm, cx - 12, cx + 12, cz - 12, cz + 12, 48, 48, H)
    for row in vs:
        for v in row:
            y = v.co.y
            n = 0.5 + 0.5 * noise(v.co.x * 0.9, v.co.z * 0.9, 1)
            rock_t = 1.0 - smooth(0.5, 1.3 + 0.4 * n, y)
            c = mix(mix(GRASS, GRASS_L, n), ROCK, rock_t)
            k = 0.85 + 0.15 * n
            v[lay] = tuple(clamp(c[i] * k) for i in range(3)) + (1.0,)
    kill = [f for f in faces if all(v.co.y < -1.15 for v in f.verts)]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    a.part("Ground", bm, "mat_env_ground", paint=False)
    # rochas arredondadas na base
    bm = bmesh.new()
    for i in range(14):
        ang = i * 2.399
        r = 8.6 + 1.2 * math.sin(i * 1.7)
        rr = 0.7 + 0.5 * (0.5 + 0.5 * math.sin(i * 2.3))
        before = set(bm.verts)
        gsph(bm, (cx + r * math.cos(ang), -0.5 + rr * 0.3, cz + r * math.sin(ang)), (rr, rr * 0.7, rr * 0.9), 12, 7)
        a.paint_new(bm, before, jit=0.12, ao=0.35)
    a.part("Rocks", bm, "mat_env_rock", paint=False)
    a.finish(glb, info)


def far_water(M, info, glb):
    """Mar distante: moldura em y = -0,4 AO REDOR do WaterSurface do jogo (x -115..225, z -80..80), sem sobrepor
    (a agua do jogo e translucida e faz espuma por profundidade: uma placa por baixo vira espuma)."""
    a = Asset("Far_Water", M, 81)
    bm = bmesh.new()
    X0, X1, Z0, Z1 = -115.0, 225.0, -80.0, 80.0
    O = 1100.0
    for (x0, x1, z0, z1) in ((55 - O, 55 + O, -O, Z0), (55 - O, 55 + O, Z1, O), (55 - O, X0, Z0, Z1), (X1, 55 + O, Z0, Z1)):
        v = [bm.verts.new(p) for p in ((x0, WATER_Y, z1), (x1, WATER_Y, z1), (x1, WATER_Y, z0), (x0, WATER_Y, z0))]
        bm.faces.new(v)
    a.part("Plane", bm, "mat_env_far_water", jit=0.0, ao=0.0, smooth=False)
    a.finish(glb, info)

# ------------------------------------------------------------------ pecas
def arch_bridge(M, info, glb):
    """Ponte de pedestre em arco, ao longo de z (z -19..19), largura 2,6 m. Vao livre: a face inferior do tabuleiro
    fica em y >= 3,0 (3,4 m sobre a agua) para |z| <= 12 e y = 3,6 (4,0 m) no centro."""
    a = Asset("Arch_Bridge", M, 90)

    def under(z):
        az = abs(z)
        if az <= 12.0:
            return 3.6 - 0.4 * (az / 10.0) ** 2
        return 3.024 - (3.024 - 0.55) * smooth(12.0, 19.0, az)
    zs = [-19.0 + 0.5 * i for i in range(77)]
    bm = bmesh.new()
    for i in range(len(zs) - 1):
        z0, z1 = zs[i], zs[i + 1]
        y0, y1 = under(z0), under(z1)
        c = Vector((0, (y0 + y1) / 2 + 0.17, (z0 + z1) / 2))
        ang = math.degrees(math.atan2(y1 - y0, z1 - z0))
        before = set(bm.verts)
        gbox(bm, c, (2.6 + 0.04 * ((i * 7) % 3), 0.12, 0.47), rx=ang)
        a.paint_new(bm, before, jit=0.18, ao=0.05)
    a.part("Deck", bm, "mat_env_wood_deck", bevel=0.015, bseg=1, paint=False)
    bm = bmesh.new()
    for sx in (-1, 1):
        pts = [(sx * 1.25, under(z) + 0.05, z) for z in zs[::2]]
        sweep(bm, pts, 0.16, seg=8)
    a.part("Stringers", bm, "mat_env_wood_dark", jit=0.1, ao=0.2)
    bm = bmesh.new()
    for sx in (-1, 1):
        for z in zs[::3]:
            y = under(z) + 0.25
            gcyl(bm, (sx * 1.28, y, z), (sx * 1.28, y + 0.95, z), 0.055, seg=6)
            gsph(bm, (sx * 1.28, y + 1.0, z), 0.08, 8, 5)
        sweep(bm, [(sx * 1.28, under(z) + 1.2, z) for z in zs[::2]], 0.06, seg=6)
    a.part("Rails", bm, "mat_env_trim", jit=0.04, ao=0.1)
    bm = bmesh.new()
    for sz in (-1, 1):
        gbox(bm, (0, -0.6, sz * 18.0), (3.4, 2.4, 3.2))
        for sx in (-1, 1):
            gcyl(bm, (sx * 1.55, -1.5, sz * 16.6), (sx * 1.55, 1.6, sz * 16.6), 0.28, seg=10)
    a.part("Abutments", bm, "mat_env_masonry", bevel=0.12, bseg=2, jit=0.12, ao=0.4)
    a.point("Underside_Center", (0, under(0), 0))
    a.finish(glb, info)


def fence_rustic(M, info, glb):
    a = Asset("Fence_Rustic", M, 91)
    bm = bmesh.new()
    for i, x in enumerate((-0.95, 0.0, 0.95)):
        h = 0.82 + 0.06 * (i % 2)
        gcyl(bm, (x, 0, 0), (x, h, 0), 0.07, seg=8)
        gsph(bm, (x, h, 0), 0.075, 8, 5)
    a.part("Stakes", bm, "mat_env_wood_light", jit=0.15, ao=0.35)
    bm = bmesh.new()
    for y, tilt in ((0.32, 1.5), (0.62, -1.2)):
        sweep(bm, [(-1.0, y, 0.06), (0.0, y + 0.02 * tilt, 0.07), (1.0, y - 0.01 * tilt, 0.06)], 0.045, seg=6)
    a.part("Rails", bm, "mat_env_wood_deck", jit=0.15, ao=0.2)
    a.finish(glb, info)


def palm_tree(M, info, glb):
    a = Asset("Palm_Tree", M, 92)
    pts = [(0.35 * math.sin(t * 1.4) * t, 5.2 * t, 0.12 * t) for t in [k / 10 for k in range(11)]]
    bm = bmesh.new()
    lay = a._layer(bm)
    sweep(bm, pts, lambda t: 0.24 - 0.09 * t, seg=10)
    for v in bm.verts:
        k = 0.82 + 0.18 * (0.5 + 0.5 * math.sin(v.co.y * 9.0))
        v[lay] = (k, k, k, 1.0)
    a.part("Trunk", bm, "mat_env_palm", paint=False)
    top = Vector(pts[-1])
    bm = bmesh.new()
    for i in range(8):
        ang = i * math.tau / 8 + 0.2
        d = Vector((math.cos(ang), 0, math.sin(ang)))
        leaf = [top + d * (2.3 * t) + Vector((0, 0.5 * math.sin(t * 2.2) - 1.3 * t * t, 0)) for t in [k / 6 for k in range(7)]]
        before = set(bm.verts)
        sweep(bm, leaf, lambda t: 0.36 * math.sin(math.pi * (0.15 + 0.85 * t)) + 0.04, seg=6)
        for v in bm.verts:
            if v not in before:
                rel = v.co - top
                side = rel.dot(Vector((0, 1, 0)))
                v.co.y = top.y + (v.co.y - top.y) * 1.0
        a.paint_new(bm, before, jit=0.1, ao=0.25)
    for v in bm.verts:
        pass
    a.part("Fronds", bm, "mat_env_foliage_a", paint=False)
    bm = bmesh.new()
    for i in range(3):
        ang = i * 2.1
        gsph(bm, (top.x + 0.22 * math.cos(ang), top.y - 0.25, top.z + 0.22 * math.sin(ang)), 0.15, 8, 6)
    a.part("Coconuts", bm, "mat_env_trunk", jit=0.1, ao=0.2)
    a.finish(glb, info)


def tent(M, info, glb):
    """Barraca do piloto: A-frame 2,4 x 2,2 x 1,6 m, entrada em +Z."""
    a = Asset("Tent", M, 93)
    L, W, Hh = 2.4, 2.2, 1.6
    bm = bmesh.new()
    for side in (-1, 1):
        v = [bm.verts.new(p) for p in ((side * W / 2, 0.02, -L / 2), (side * W / 2, 0.02, L / 2), (0, Hh, L / 2), (0, Hh, -L / 2))]
        bm.faces.new(v if side < 0 else v[::-1])
    a.part("Canvas", bm, "mat_env_tent", solid=0.04, bevel=0.02, bseg=1, jit=0.05, ao=0.35, smooth=False)
    bm = bmesh.new()
    v = [bm.verts.new(p) for p in ((-W / 2, 0.02, -L / 2), (0, Hh, -L / 2), (W / 2, 0.02, -L / 2))]
    bm.faces.new(v)
    v = [bm.verts.new(p) for p in ((-W / 2 + 0.05, 0.02, L / 2 - 0.02), (-0.05, Hh - 0.1, L / 2 + 0.25), (-0.05, 0.02, L / 2 + 0.35))]
    bm.faces.new(v)
    a.part("Flaps", bm, "mat_env_tent_dark", solid=0.03, jit=0.05, ao=0.3, smooth=False)
    bm = bmesh.new()
    gcyl(bm, (0, Hh + 0.05, -L / 2 - 0.15), (0, Hh + 0.05, L / 2 + 0.15), 0.04, seg=6)
    for sz in (-1, 1):
        gcyl(bm, (0, 0, sz * (L / 2 + 0.1)), (0, Hh + 0.1, sz * (L / 2 + 0.1)), 0.04, seg=6)
        for sx in (-1, 1):
            sweep(bm, [(0, Hh, sz * (L / 2 + 0.1)), (sx * 1.6, 0.05, sz * (L / 2 + 0.8))], 0.012, seg=4)
    a.part("Poles", bm, "mat_env_wood_dark", jit=0.05, ao=0.1)
    a.finish(glb, info)


def campfire(M, info, glb):
    a = Asset("Campfire", M, 94)
    bm = bmesh.new()
    for i in range(9):
        ang = i * math.tau / 9
        before = set(bm.verts)
        gsph(bm, (0.55 * math.cos(ang), 0.1, 0.55 * math.sin(ang)), (0.17, 0.13, 0.15), 10, 6)
        a.paint_new(bm, before, jit=0.15, ao=0.3)
    a.part("Stones", bm, "mat_env_rock", paint=False)
    bm = bmesh.new()
    for i in range(3):
        ang = i * math.tau / 3
        d = Vector((math.cos(ang), 0, math.sin(ang)))
        p0 = d * 0.45 + Vector((0, 0.06, 0))
        p1 = -d * 0.15 + Vector((0, 0.3, 0))
        gcyl(bm, tuple(p0), tuple(p1), 0.07, seg=8)
    a.part("Logs", bm, "mat_env_trunk", jit=0.15, ao=0.3)
    bm = bmesh.new()
    lathe(bm, [(0.0, 0.03), (0.42, 0.01), (0.0, 0.05)], seg=14)
    a.part("Ash", bm, "mat_env_ash", jit=0.1, ao=0.0)
    a.finish(glb, info)


def flag_pole(M, info, glb):
    a = Asset("Flag_Pole", M, 95)
    bm = bmesh.new()
    gcyl(bm, (0, 0, 0), (0, 3.0, 0), 0.05, 0.04, seg=8)
    gsph(bm, (0, 3.05, 0), 0.08, 8, 5)
    a.part("Pole", bm, "mat_env_wood_dark", jit=0.08, ao=0.2)
    bm = bmesh.new()
    v = [bm.verts.new(p) for p in ((0.04, 2.95, 0), (0.04, 2.25, 0), (1.15, 2.62, 0.08))]
    bm.faces.new(v)
    a.part("Flag", bm, "mat_env_flag", solid=0.02, jit=0.03, ao=0.1, smooth=False)
    bm = bmesh.new()
    v = [bm.verts.new(p) for p in ((0.06, 2.72, 0.012), (0.06, 2.5, 0.012), (0.75, 2.62, 0.06))]
    bm.faces.new(v)
    a.part("Stripe", bm, "mat_env_flag_navy", solid=0.03, jit=0.0, ao=0.0, smooth=False)
    a.finish(glb, info)


def step_rock_safe(M, info, glb):
    """Apoio SEGURO da travessia: rocha clara de topo plano (raio 0,75). ORIGEM NO TOPO (y = 0); corpo ate y = -1,8."""
    a = Asset("Step_Rock_Safe", M, 96)
    bm = bmesh.new()
    prof = [(0.0, 0.0), (0.62, 0.0), (0.74, -0.06), (0.8, -0.2), (0.86, -0.7), (0.95, -1.4), (1.0, -1.8), (0.0, -1.8)]
    lathe(bm, prof, seg=14)
    for v in bm.verts:
        ang = math.atan2(v.co.z, v.co.x)
        if v.co.y < -0.01:
            k = 1 + 0.08 * math.sin(3 * ang + 0.5) + 0.05 * math.sin(5 * ang)
            v.co.x *= k
            v.co.z *= k
    a.part("Body", bm, "mat_env_rock_safe", jit=0.06, ao=0.45, ao_h=1.8)
    bm = bmesh.new()
    for i in range(5):
        ang = i * 1.3
        gsph(bm, (0.3 * math.cos(ang), 0.0, 0.3 * math.sin(ang)), (0.05, 0.012, 0.05), 6, 3)
    a.part("Marks", bm, "mat_env_flag", jit=0.0, ao=0.0)
    a.finish(glb, info)


def step_rock_decoy(M, info, glb):
    """Isca: rocha escura e molhada (brilhante), topo abaulado. Origem na base (y = -1,2); topo em y ~ +0,15."""
    a = Asset("Step_Rock_Decoy", M, 97)
    bm = bmesh.new()
    gsph(bm, (0, -0.55, 0), (0.6, 0.7, 0.5), 14, 9)
    for v in bm.verts:
        v.co *= 1 + 0.07 * noise(v.co.x * 4, v.co.z * 4 + v.co.y * 3, 2)
    a.part("Body", bm, "mat_env_rock_wet", jit=0.05, ao=0.35)
    a.finish(glb, info)


def boulder(M, info, glb):
    a = Asset("Boulder", M, 98)
    bm = bmesh.new()
    gsph(bm, (0, 0.55, 0), (1.5, 1.1, 1.3), 18, 11)
    gsph(bm, (0.9, 0.35, 0.6), (0.8, 0.6, 0.7), 12, 8)
    for v in bm.verts:
        v.co += v.co.normalized() * 0.08 * noise(v.co.x * 2, v.co.z * 2 + v.co.y, 5)
    a.part("Body", bm, "mat_env_rock", jit=0.08, ao=0.45)
    a.finish(glb, info)


def shell(M, info, glb):
    a = Asset("Shell", M, 99)
    bm = bmesh.new()
    lay = a._layer(bm)
    lathe(bm, [(0.0, 0.0), (0.09, 0.0), (0.06, 0.03), (0.0, 0.035)], seg=10, sz=1.25)
    for v in bm.verts:
        v[lay] = (1.0, 0.8, 0.78, 1.0)
    a.part("Body", bm, "mat_env_tint", paint=False)
    a.finish(glb, info)


def pier_small(M, info, glb):
    """Pier de madeira 2,4 x 6 m: topo em y = 0, do ponto de origem (terra) ate z = -6 (agua)."""
    a = Asset("Pier_Small", M, 100)
    bm = bmesh.new()
    for i in range(20):
        z = -0.15 - i * 0.3
        before = set(bm.verts)
        gbox(bm, (0.02 * math.sin(i), -0.05, z), (2.4 + 0.06 * math.sin(i * 3), 0.1, 0.27), ry=0.6 * math.sin(i * 1.7))
        a.paint_new(bm, before, jit=0.2, ao=0.05)
    a.part("Deck", bm, "mat_env_wood_deck", bevel=0.012, bseg=1, paint=False)
    bm = bmesh.new()
    for z in (-0.4, -3.0, -5.7):
        for sx in (-1.1, 1.1):
            gcyl(bm, (sx, -1.6, z), (sx, 0.25 if z < -5 else -0.1, z), 0.13, seg=8)
    for sx in (-1.1, 1.1):
        gbox(bm, (sx, -0.22, -3.0), (0.14, 0.16, 6.0))
    a.part("Piles", bm, "mat_env_wood_dark", jit=0.15, ao=0.4)
    a.finish(glb, info)


def gull_standing(M, info, glb):
    a = Asset("Gull_Standing", M, 101)
    bm = bmesh.new()
    gsph(bm, (0, 0.22, 0), (0.1, 0.1, 0.2), 10, 6)
    gsph(bm, (0, 0.34, -0.15), 0.075, 8, 6)
    a.part("Body", bm, "mat_env_gull", jit=0.03, ao=0.2)
    bm = bmesh.new()
    for sx in (-1, 1):
        gsph(bm, (sx * 0.08, 0.25, 0.04), (0.04, 0.07, 0.2), 8, 5)
    a.part("Wings", bm, "mat_env_gull_gray", jit=0.03, ao=0.1)
    bm = bmesh.new()
    gcyl(bm, (0, 0.33, -0.21), (0, 0.32, -0.31), 0.028, 0.01, seg=6)
    for sx in (-0.04, 0.04):
        gcyl(bm, (sx, 0.0, 0), (sx, 0.14, 0), 0.012, seg=4)
    a.part("Beak", bm, "mat_env_beak", jit=0.0, ao=0.0)
    a.finish(glb, info)


def main():
    reset_scene()
    M = M_all()
    glb = arg_value("--glb-dir", os.path.join(REPO, "game", "assets", "models", "environment"))
    info = {}
    terrain(M, info, glb, "River_Bank_North", 24.0, 196.0, -92.0, -10.0, 1.5, sdf_north, bank_top, seed=3)
    terrain(M, info, glb, "River_Bank_South", 0.0, 194.0, -1.0, 92.0, 1.5, sdf_south, bank_top, flat=flat_zone, seed=4)
    terrain(M, info, glb, "Island_Ground", 178.0, 224.0, -26.0, 28.0, 0.75, sdf_island, island_top,
            flat=lambda x, z: x < 205.0, seed=5, beach=1.0)
    terrain(M, info, glb, "Sandbar", 100.0, 138.0, -7.0, 19.0, 0.75,
            lambda x, z: (1.0 - math.hypot((x - 119.0) / 7.0, (z - 6.0) / 3.0)) * (3.0 if math.hypot((x - 119.0) / 7.0, (z - 6.0) / 3.0) < 1 else 7.0),
            lambda x, z, d: 0.15, seed=6, beach=2.0)
    headland(M, info, glb)
    far_water(M, info, glb)
    arch_bridge(M, info, glb)
    fence_rustic(M, info, glb)
    palm_tree(M, info, glb)
    tent(M, info, glb)
    campfire(M, info, glb)
    flag_pole(M, info, glb)
    step_rock_safe(M, info, glb)
    step_rock_decoy(M, info, glb)
    boulder(M, info, glb)
    shell(M, info, glb)
    pier_small(M, info, glb)
    gull_standing(M, info, glb)
    blend = arg_value("--blend", os.path.join(REPO, "source_art", "environment", "world_kit.blend"))
    save_all(blend, info, os.path.splitext(blend)[0] + ".info.json")


if __name__ == "__main__":
    main()
