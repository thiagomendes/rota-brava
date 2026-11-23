"""Terreno e vegetacao estilizados (PROVISORIO): ladrilhos de chao 4 x 13 m (topo plano em y = 0 onde se anda),
3 arvores, 2 arbustos, tufo de grama, juncos e 3 rochas. Metros, espaco Godot, origem na base.
Uso: blender --background --factory-startup --python build_nature.py -- --blend X --glb-dir Y
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh
from mathutils import Vector
from envlib import (REPO, Asset, arg_value, clamp, gsph, grid_patch, materials, reset_scene, save_all, sweep)
from rbart import hex_to_linear

TD = 13.0   # ladrilhos: largura 4 (caminho) ou 8 m, 13 m em z (z -6.5..6.5)


def noise(x, z, s):
    return (math.sin(x * 1.3 + s) * math.cos(z * 0.9 - s * 1.7) + 0.5 * math.sin(x * 2.9 + z * 2.3 + s * 3.1)
            + 0.25 * math.sin(x * 5.7 - z * 4.9 + s)) / 1.75


def smooth(e0, e1, x):
    t = clamp((x - e0) / (e1 - e0))
    return t * t * (3 - 2 * t)


def ground_tile(M, info, glb, name, seed, width=4.0, path=False):
    """Chao em grade de 0,25 m: topo em y = 0 (so afunda ate 1,8 cm longe das bordas), cor de grama/terra por vertice
    (material unico branco), borda com saia para nao vazar a agua nas juncoes."""
    a = Asset(name, M, seed)
    s = seed * 1.37
    bm = bmesh.new()
    W = width
    NX, NZ = int(W * 4), 52
    grass = hex_to_linear("#6F9A4F")
    dirt = hex_to_linear("#9C7B56")

    def edge_fade(x, z):
        d = min(W / 2 - abs(x), TD / 2 - abs(z))
        return smooth(0.0, 0.7, d)

    def height(x, z):
        return -0.018 * clamp(0.5 + 0.5 * noise(x, z, s)) ** 2 * edge_fade(x, z)

    layer = bm.verts.layers.float_color.new("Col")
    vs, faces = grid_patch(bm, -W / 2, W / 2, -TD / 2, TD / 2, NX, NZ, height)
    for row in vs:
        for v in row:
            x, z = v.co.x, v.co.z
            f = edge_fade(x, z)
            w = smooth(0.30, 0.80, 0.5 + 0.5 * noise(x * 0.8 + 3, z * 0.8, s + 9)) * 0.75
            if path:
                w = max(w, 1.0 - smooth(0.45, 1.25, abs(x + 0.3 * math.sin(z * 0.7)) + 0.2 * math.sin(z * 1.3)))
            w = 0.1 + (w - 0.1) * f
            k = (0.86 + 0.14 * (0.5 + 0.5 * noise(x * 1.1, z * 1.1, s + 4))) * (1 - 0.05 * f * a.rng.random())
            k = 1 - (1 - k) * f
            v[layer] = tuple(clamp((grass[i] * (1 - w) + dirt[i] * w) * k, 0, 1) for i in range(3)) + (1.0,)
    # saia: desce 0,35 m nas quatro bordas (cor de terra escura)
    skirt = hex_to_linear("#6B5439")
    for edge in ([vs[i][0] for i in range(NX + 1)], [vs[i][NZ] for i in range(NX, -1, -1)],
                 [vs[0][j] for j in range(NZ, -1, -1)], [vs[NX][j] for j in range(NZ + 1)]):
        low = []
        for v in edge:
            nv = bm.verts.new((v.co.x, -0.35, v.co.z))
            nv[layer] = tuple(skirt) + (1.0,)
            low.append(nv)
        for i in range(len(edge) - 1):
            bm.faces.new((edge[i], low[i], low[i + 1], edge[i + 1]))
    a.part("Surface", bm, "mat_env_ground", jit=0.0, ao=0.0, paint=False)
    a.point("TileOrigin", (0, 0, 0))
    a.finish(glb, info, offset=W + 1.0)


def blob_crown(bm, a, centers, base_r, noise_amp=0.12, ao_h=None):
    for (cx, cy, cz, r) in centers:
        before = set(bm.verts)
        gsph(bm, (cx, cy, cz), (r * 1.05, r * 0.9, r * 1.05), 14, 9)
        new = [v for v in bm.verts if v not in before]
        for v in new:
            dv = v.co - Vector((cx, cy, cz))
            k = 1.0 + noise_amp * noise(dv.x * 3, dv.y * 3 + dv.z * 2, cx + cz)
            v.co = Vector((cx, cy, cz)) + dv * k
        a.paint_new(bm, before, jit=0.12, ao=0.42, ao_h=ao_h or (2 * r))


def trunk(bm, base, tip, r0, r1, bend, seg=9):
    pts = []
    for k in range(9):
        t = k / 8
        pts.append(Vector((base[0] + (tip[0] - base[0]) * t + bend[0] * math.sin(math.pi * t),
                           base[1] + (tip[1] - base[1]) * t,
                           base[2] + (tip[2] - base[2]) * t + bend[1] * math.sin(math.pi * t))))
    sweep(bm, pts, lambda t: r0 + (r1 - r0) * t + 0.05 * (1 - t) ** 6, seg=seg, caps=True)
    return pts


def tree(M, info, glb, name, seed, kind):
    a = Asset(name, M, seed)
    rng = a.rng
    bm = bmesh.new()
    if kind == "a":      # copa redonda ampla
        pts = trunk(bm, (0, 0, 0), (0.25, 2.3, 0.1), 0.26, 0.13, (0.25, 0.1))
        trunk(bm, (0.2, 1.7, 0.1), (-0.7, 2.9, 0.4), 0.09, 0.04, (0.0, 0.1))
        crown = [(0.1, 3.5, 0.0, 1.35), (-0.9, 3.1, 0.4, 1.0), (1.1, 3.0, -0.3, 1.0), (0.2, 4.3, 0.3, 0.95), (-0.3, 3.4, -0.9, 0.9),
                 (0.5, 3.2, 1.0, 0.95)]
        mat = "mat_env_foliage_a"
    elif kind == "b":    # alta e estreita (massas empilhadas)
        pts = trunk(bm, (0, 0, 0), (-0.1, 3.2, 0.0), 0.21, 0.09, (-0.2, 0.0))
        crown = [(-0.1, 3.2, 0.0, 0.95), (0.1, 4.3, 0.1, 0.85), (-0.15, 5.2, 0.0, 0.7), (0.1, 5.95, 0.0, 0.5), (0.5, 3.6, 0.4, 0.6),
                 (-0.6, 4.0, -0.3, 0.6)]
        mat = "mat_env_foliage_c"
    else:                # guarda-chuva inclinada
        pts = trunk(bm, (0, 0, 0), (0.9, 2.7, 0.3), 0.24, 0.12, (-0.5, 0.2))
        trunk(bm, (0.5, 1.6, 0.2), (1.9, 2.5, 0.0), 0.08, 0.04, (0.0, 0.0))
        crown = [(0.9, 3.2, 0.3, 1.25), (-0.1, 3.0, 0.6, 0.85), (1.9, 3.0, -0.1, 0.9), (1.2, 3.6, -0.6, 0.85), (0.4, 3.5, 0.9, 0.8)]
        mat = "mat_env_foliage_b"
    a.part("Trunk", bm, "mat_env_trunk", bevel=0.01, bseg=1, jit=0.15, ao=0.5, ao_h=2.5)
    bm = bmesh.new()
    blob_crown(bm, a, crown, 1.0)
    a.part("Crown", bm, mat, sub=1, jit=0.1, ao=0.0, paint=False)
    a.finish(glb, info)


def bush(M, info, glb, name, seed, flower):
    a = Asset(name, M, seed)
    bm = bmesh.new()
    cs = [(0, 0.38, 0, 0.5), (-0.45, 0.3, 0.1, 0.38), (0.42, 0.3, -0.05, 0.4), (0.05, 0.35, 0.42, 0.36), (-0.1, 0.55, -0.25, 0.34)]
    if flower:
        cs = [(0, 0.3, 0, 0.42), (-0.4, 0.25, 0.1, 0.3), (0.38, 0.25, 0.0, 0.32)]
    blob_crown(bm, a, cs, 0.5, ao_h=0.8)
    a.part("Leaves", bm, "mat_env_bush", sub=1, jit=0.0, ao=0.0, paint=False)
    if flower:
        bm = bmesh.new()
        for k in range(14):
            ang = a.rng.uniform(0, 2 * math.pi)
            rr = a.rng.uniform(0.1, 0.42)
            h = 0.52 + 0.25 * (1 - rr / 0.5)
            gsph(bm, (math.cos(ang) * rr * 0.9, h + a.rng.uniform(0, 0.08), math.sin(ang) * rr * 0.9), 0.045, 8, 5)
        a.part("Flowers", bm, "mat_env_bush_flower", jit=0.1, ao=0.0)
    a.finish(glb, info)


def blades(a, bm, n, hmin, hmax, spread, rw, bend):
    for k in range(n):
        ang = a.rng.uniform(0, 2 * math.pi)
        rr = a.rng.uniform(0, spread)
        x0, z0 = math.cos(ang) * rr, math.sin(ang) * rr
        h = a.rng.uniform(hmin, hmax)
        dx, dz = math.cos(ang) * a.rng.uniform(0.05, bend), math.sin(ang) * a.rng.uniform(0.05, bend)
        pts = [Vector((x0 + dx * (t ** 2), h * t, z0 + dz * (t ** 2))) for t in (0, 0.3, 0.65, 1.0)]
        before = set(bm.verts)
        sweep(bm, pts, lambda t: rw * (1 - t) + 0.002, seg=3)
        a.paint_new(bm, before, jit=0.25, ao=0.5, ao_h=h)


def grass_tuft(M, info, glb):
    a = Asset("Grass_Tuft", M, 61)
    bm = bmesh.new()
    blades(a, bm, 12, 0.22, 0.42, 0.07, 0.016, 0.16)
    a.part("Blades", bm, "mat_env_reed", jit=0.0, ao=0.0, paint=False)
    a.finish(glb, info)


def reeds(M, info, glb):
    a = Asset("Reeds", M, 62)
    bm = bmesh.new()
    blades(a, bm, 10, 0.9, 1.5, 0.22, 0.02, 0.35)
    a.part("Stalks", bm, "mat_env_reed", jit=0.0, ao=0.0, paint=False)
    bm = bmesh.new()
    for k in range(3):
        ang = k * 2.1
        x, z = math.cos(ang) * 0.12, math.sin(ang) * 0.12
        h = 1.25 + 0.15 * k
        sweep(bm, [Vector((x + 0.05 * k, h - 0.1, z)), Vector((x + 0.06 * k, h + 0.1, z))], 0.028, seg=6)
    a.part("Heads", bm, "mat_env_trunk", jit=0.1, ao=0.0)
    a.finish(glb, info)


def rock(M, info, glb, name, seed, size, mat):
    a = Asset(name, M, seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    sx, sy, sz = size
    s = seed * 0.77
    for v in bm.verts:
        p = v.co.copy()
        k = 1.0 + 0.22 * noise(p.x * 2.1, p.y * 1.7 + p.z * 1.9, s) + 0.07 * noise(p.x * 6, p.z * 6, s + 2)
        q = Vector((p.x * sx * k, p.y * sy * k, p.z * sz * k))
        if q.y < 0.0:
            q.y = q.y * 0.18
        v.co = q
    ymin = min(v.co.y for v in bm.verts)
    for v in bm.verts:
        v.co.y -= ymin * 0.9
        v.co.y = max(v.co.y, 0.0) if v.co.y < 0.01 else v.co.y
    a.part("Stone", bm, mat, sub=1, jit=0.15, ao=0.5, ao_h=size[1] * 1.6)
    a.finish(glb, info)


def main():
    reset_scene()
    M = materials()
    info = {}
    glb = arg_value("--glb-dir", os.path.join(REPO, "game", "assets", "models", "environment"))
    ground_tile(M, info, glb, "Ground_Tile_A", 71, 8.0)
    ground_tile(M, info, glb, "Ground_Tile_B", 72, 8.0)
    ground_tile(M, info, glb, "Ground_Tile_Path", 73, 4.0, path=True)
    tree(M, info, glb, "Tree_A", 81, "a")
    tree(M, info, glb, "Tree_B", 82, "b")
    tree(M, info, glb, "Tree_C", 83, "c")
    bush(M, info, glb, "Bush_Round", 91, False)
    bush(M, info, glb, "Bush_Flower", 92, True)
    grass_tuft(M, info, glb)
    reeds(M, info, glb)
    rock(M, info, glb, "Rock_A", 101, (0.55, 0.38, 0.5), "mat_env_rock")
    rock(M, info, glb, "Rock_B", 102, (0.3, 0.22, 0.34), "mat_env_rock_warm")
    rock(M, info, glb, "Rock_C", 103, (0.85, 0.55, 0.7), "mat_env_rock")
    blend = arg_value("--blend", os.path.join(REPO, "source_art", "environment", "nature.blend"))
    save_all(blend, info, os.path.splitext(blend)[0] + ".info.json")


main()
