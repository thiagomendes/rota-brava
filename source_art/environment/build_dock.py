"""Kit modular do cais (PROVISORIO): deck de tabuas em 2 larguras, poste de ancoragem com anel de corda, cabeco,
defensa de pneu, escada, borda e estaca. Metros, espaco Godot (topo do deck em y = 0, origem funcional descrita abaixo).
Uso: tools/blender.ps1 --background --factory-startup --python source_art/environment/build_dock.py -- --blend X --glb-dir Y
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh
from mathutils import Vector
from envlib import (REPO, Asset, arg_value, gbox, gcyl, gsph, materials, reset_scene, save_all, sweep)
from rbart import torus

DEPTH = 6.0   # z do cais


def deck(M, info, glb_dir, width, seed):
    """Modulo de deck: origem no centro do topo (y = 0). Tabuas ao longo de z; longarinas por baixo; pregos."""
    a = Asset(f"Dock_Deck_{width}m", M, seed)
    n = int(round(width / 0.2))
    pitch = width / n
    bm = bmesh.new()
    nails = bmesh.new()
    for i in range(n):
        before = set(bm.verts)
        x = -width / 2 + pitch * (i + 0.5)
        w = pitch - 0.016
        drop = 0.0 if i == 0 else -a.rng.uniform(0.0, 0.005)     # nunca acima de y = 0
        sag = a.rng.uniform(0.0, 0.004)
        twist = a.rng.uniform(-0.5, 0.5)
        sk = a.rng.uniform(-0.005, 0.005)                          # tabua levemente torta em planta
        gbox(bm, (x, -0.04, 0), (w, 0.08, DEPTH - a.rng.uniform(0.0, 0.05)), rz=twist, cuts=(0, 0, 14))
        for v in [v for v in bm.verts if v not in before]:
            t = v.co.z / (DEPTH / 2)
            v.co.y += drop - sag * (1 - t * t)
            v.co.x += sk * math.sin(math.pi * (t + 1) / 2)
            if v.co.y > 0:
                v.co.y = 0.0
        a.paint_new(bm, before, jit=0.42, ao=0.0, tint=a.rng.choice([(1.0, 0.92, 0.80), (0.86, 0.9, 0.93), (0.96, 0.95, 0.9), (1.0, 0.97, 0.88)]))
        for sz in (-2.55, 0.0, 2.55):
            for sx in (-1, 1):
                zz = sz + a.rng.uniform(-0.02, 0.02)
                gcyl(nails, (x + sx * w * 0.28, -0.012, zz), (x + sx * w * 0.28, 0.002, zz), 0.011, 0.014, seg=6)
    a.part("Planks", bm, "mat_env_wood_deck", bevel=0.006, bseg=1, paint=False)
    ub = bmesh.new()
    gbox(ub, (0, -0.088, 0), (width - 0.004, 0.012, DEPTH - 0.08))
    a.part("Underlay", ub, "mat_env_wood_dark", jit=0.1, ao=0.0)
    a.part("Nails", nails, "mat_env_nail", jit=0.05, ao=0.0)
    bm = bmesh.new()
    for sz in (-2.55, 0.0, 2.55):
        gbox(bm, (0, -0.15, sz), (width - 0.02, 0.14, 0.15), cuts=(max(1, width), 0, 0))
    a.part("Stringers", bm, "mat_env_wood_dark", bevel=0.012, bseg=2, ao=0.55, jit=0.15, ao_h=0.14)
    a.point("DeckTop", (0, 0, 0))
    a.finish(glb_dir, info)
    return a


def post(M, info, glb_dir):
    """Poste de ancoragem: origem na face superior do deck (y = 0); do fundo (-1.6) ate 0,95 m."""
    a = Asset("Dock_Post", M, 11)
    bm = bmesh.new()
    pts = []
    for k in range(11):
        t = k / 10
        y = -1.6 + 2.55 * t
        pts.append(Vector((0.02 * math.sin(t * 5), y, 0.015 * math.cos(t * 4))))
    sweep(bm, pts, lambda t: 0.135 - 0.012 * t + (0.012 if 0.55 < t < 0.62 else 0.0), seg=14, caps=True)
    a.part("Pile", bm, "mat_env_wood_dark", bevel=0.02, bseg=2, sub=1, crease=0.6, jit=0.12, ao=0.5, ao_h=2.5)
    bm = bmesh.new()
    gsph(bm, (0.0, 0.96, 0.0), (0.14, 0.07, 0.14), 14, 8)
    a.part("Cap", bm, "mat_env_wood_deck", jit=0.1, ao=0.1)
    bm = bmesh.new()   # anel de corda: 3 voltas + laco pendente
    pts = []
    for k in range(37):
        t = k / 36
        ang = t * 3 * 2 * math.pi
        pts.append(Vector((math.cos(ang) * 0.158, 0.60 + 0.15 * t, math.sin(ang) * 0.158)))
    sweep(bm, pts, 0.026, seg=6)
    loop = []
    for k in range(25):
        ang = k / 24 * 2 * math.pi
        loop.append(Vector((0.19 + 0.0 * k, 0.60 + 0.22 * math.cos(ang) - 0.22, 0.04 * math.sin(ang * 2) + 0.0)))
    loop = [Vector((0.17 + 0.17 * math.sin(ang), 0.45 - 0.17 * (1 - math.cos(ang)), 0.0)) for ang in
            [k / 24 * 2 * math.pi for k in range(25)]]
    sweep(bm, loop, 0.024, seg=6)
    a.part("RopeRing", bm, "mat_env_rope", jit=0.15, ao=0.2)
    a.point("RopePoint", (0.34, 0.28, 0))
    a.finish(glb_dir, info)


def cleat(M, info, glb_dir):
    """Cabeco de ferro: origem na base (y = 0 do deck)."""
    a = Asset("Dock_Cleat", M, 12)
    bm = bmesh.new()
    gbox(bm, (0, 0.025, 0), (0.46, 0.05, 0.16))
    a.part("Base", bm, "mat_env_metal", bevel=0.012, bseg=2, jit=0.1, ao=0.2)
    bm = bmesh.new()
    gbox(bm, (0, 0.10, 0), (0.07, 0.10, 0.09))
    gbox(bm, (0, 0.17, 0), (0.42, 0.06, 0.09), cuts=(4, 0, 0))
    for v in bm.verts:
        if v.co.y > 0.14:
            v.co.y -= 0.025 * (abs(v.co.x) / 0.21) ** 2 - 0.0
            v.co.z *= 1.0 - 0.28 * (abs(v.co.x) / 0.21)
    a.part("Horn", bm, "mat_env_metal", bevel=0.01, bseg=2, sub=1, crease=0.4, jit=0.1, ao=0.35, ao_h=0.2)
    a.finish(glb_dir, info)


def fender(M, info, glb_dir):
    """Defensa de pneu: pendurada na borda; origem no ponto de amarracao (y = 0), pneu 0,6 m abaixo."""
    a = Asset("Dock_Fender", M, 13)
    bm = bmesh.new()
    torus(bm, (0, -0.62, 0.0), 0.2, 0.09, None, 24, 10)
    a.part("Tire", bm, "mat_env_rubber", jit=0.12, ao=0.0, ao_h=0.5)
    bm = bmesh.new()
    for sx in (-0.07, 0.07):
        sweep(bm, [Vector((sx, 0.0, 0.0)), Vector((sx * 1.4, -0.3, 0.0)), Vector((sx * 1.9, -0.52, 0.0))], 0.015, seg=5)
    a.part("Rope", bm, "mat_env_rope", jit=0.1, ao=0.0)
    a.finish(glb_dir, info)


def ladder(M, info, glb_dir):
    """Escada de madeira: origem na borda do deck (y = 0, z = 0); desce para -z/agua (-1,2 m)."""
    a = Asset("Dock_Ladder", M, 14)
    bm = bmesh.new()
    for sx in (-0.23, 0.23):
        gbox(bm, (sx, -0.42, -0.03), (0.07, 1.64, 0.06), cuts=(0, 4, 0))
        gbox(bm, (sx, 0.18, 0.06), (0.07, 0.07, 0.24), cuts=(0, 0, 1))
    a.part("Rails", bm, "mat_env_wood_dark", bevel=0.012, bseg=2, jit=0.14, ao=0.3, ao_h=1.0)
    bm = bmesh.new()
    for k in range(6):
        y = 0.1 - 0.23 * k
        gcyl(bm, (-0.23, y, -0.03), (0.23, y + a.rng.uniform(-0.008, 0.008), -0.03), 0.026, seg=8)
    a.part("Rungs", bm, "mat_env_wood_light", jit=0.18, ao=0.1)
    a.finish(glb_dir, info)


def edge(M, info, glb_dir):
    """Viga de borda com parafusos, 4 m ao longo de x; origem no eixo da borda (z = 0), fica para o lado de -z."""
    a = Asset("Dock_Edge", M, 15)
    bm = bmesh.new()
    gbox(bm, (0, 0.0, -0.08), (4.0, 0.2, 0.16), cuts=(8, 0, 0))
    for v in bm.verts:
        v.co.y += 0.012 * math.sin(v.co.x * 1.7) - 0.0
        v.co.z += 0.006 * math.sin(v.co.x * 2.9 + 1.0)
    a.part("Beam", bm, "mat_env_wood_dark", bevel=0.018, bseg=2, jit=0.14, ao=0.3, ao_h=0.2)
    bm = bmesh.new()
    for x in (-1.7, -0.6, 0.6, 1.7):
        gcyl(bm, (x, 0.04, -0.158), (x, 0.04, -0.172), 0.025, seg=8)
    a.part("Bolts", bm, "mat_env_nail", jit=0.05, ao=0.0)
    a.finish(glb_dir, info)


def pile(M, info, glb_dir):
    a = Asset("Dock_Pile", M, 16)
    bm = bmesh.new()
    pts = [Vector((0.03 * math.sin(k * 0.9), -2.0 + 1.8 * k / 8, 0.02 * math.cos(k * 1.3))) for k in range(9)]
    sweep(bm, pts, 0.12, seg=10)
    a.part("Pile", bm, "mat_env_wood_dark", bevel=0.015, bseg=2, sub=1, crease=0.6, jit=0.12, ao=0.55, ao_h=1.8)
    a.finish(glb_dir, info)


def main():
    reset_scene()
    M = materials()
    info = {}
    glb_dir = arg_value("--glb-dir", os.path.join(REPO, "game", "assets", "models", "environment"))
    deck(M, info, glb_dir, 2, 101)
    deck(M, info, glb_dir, 4, 202)
    post(M, info, glb_dir)
    cleat(M, info, glb_dir)
    fender(M, info, glb_dir)
    ladder(M, info, glb_dir)
    edge(M, info, glb_dir)
    pile(M, info, glb_dir)
    blend = arg_value("--blend", os.path.join(REPO, "source_art", "environment", "dock_kit.blend"))
    save_all(blend, info, os.path.splitext(blend)[0] + ".info.json")


main()
