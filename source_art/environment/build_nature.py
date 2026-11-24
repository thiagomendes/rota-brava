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


BANK_Z = 9.5   # centro dos ladrilhos em z (margem sul z 3..16)
# caminho de terra batida (coords do MUNDO): cais (0, 3) -> pegada (-6, 10) -> praca oeste (-10, 8)
PATH = [(0.4, 3.1), (0.0, 4.2), (-1.4, 6.0), (-3.4, 7.8), (-5.2, 9.4), (-6.4, 10.1), (-8.0, 9.6), (-9.2, 8.6), (-10.6, 7.9)]
MUD = (-6.0, 10.0, 1.35)


def path_dist(x, z):
    best, bt = 1e9, 0.0
    for i in range(len(PATH) - 1):
        ax, az = PATH[i]
        bx, bz = PATH[i + 1]
        dx, dz = bx - ax, bz - az
        L2 = dx * dx + dz * dz
        t = clamp(((x - ax) * dx + (z - az) * dz) / L2)
        d = math.hypot(x - ax - dx * t, z - az - dz * t)
        if d < best:
            best, bt = d, (i + t) / (len(PATH) - 1)
    return best, bt


def path_half_width(x, z, t):
    return 0.95 + 0.22 * noise(x * 1.7, z * 1.7, 5.0) + 0.25 * math.sin(t * 9.0)


def bank_height(x, z):
    """Altura da margem (mundo). Caminho e lama: y = 0 exato. Grama: morrinhos de ate ~22 cm longe do caminho,
    zerando nas bordas da margem (cais, agua, cerca) e sob a cabana."""
    d, t = path_dist(x, z)
    w = path_half_width(x, z, t)
    if d <= w + 0.45 or math.hypot(x - MUD[0], z - MUD[1]) <= MUD[2] + 0.3:
        return 0.0
    edge = min(10.0 - abs(x), (z - 3.0) * 2.5, 16.0 - z)
    hut = max(abs(x + 7.0) - 2.3, abs(z - 13.5) - 2.0)
    f = smooth(0.0, 1.6, edge) * smooth(0.0, 0.8, hut) * smooth(w + 0.3, w + 2.2, d)
    return 0.22 * f * clamp(0.45 + 0.55 * noise(x * 0.55, z * 0.6, 2.0))


def ground_tile(M, info, glb, name, seed, width=4.0, path=False, ox=0.0):
    """Ladrilho da margem sul (RB-R1): amostra a margem do MUNDO em x = ox +- width/2, z 3..16. Partes:
    Surface (grama com variacao por vertice e morrinhos), Path (terra batida e lama em y = 0 exato) e Pebbles."""
    a = Asset(name, M, seed)
    W = width
    NX, NZ = int(W * 4), 52
    grass = hex_to_linear("#5DB43E")
    grass_l = hex_to_linear("#86C94C")
    grass_d = hex_to_linear("#4FA83D")
    dirt = hex_to_linear("#DDBF8E")
    dirt_e = hex_to_linear("#B98A5E")
    mud = hex_to_linear("#8E6A46")

    def H(x, z):
        return bank_height(x + ox, z + BANK_Z)

    for part in ("Surface",):
        bm = bmesh.new()
        layer = bm.verts.layers.float_color.new("Col")
        vs, faces = grid_patch(bm, -W / 2, W / 2, -TD / 2, TD / 2, NX, NZ, H)
        kill = []
        for f in faces:
            c = f.calc_center_median()
            xw, zw = c.x + ox, c.z + BANK_Z
            d, t = path_dist(xw, zw)
            on = d <= path_half_width(xw, zw, t) - 0.05 or math.hypot(xw - MUD[0], zw - MUD[1]) <= MUD[2] - 0.05
            if False and on:
                kill.append(f)
        for row in vs:
            for v in row:
                xw, zw = v.co.x + ox, v.co.z + BANK_Z
                d, t = path_dist(xw, zw)
                w = path_half_width(xw, zw, t)
                if part == "Path":
                    e = smooth(w * 0.3, w, d)
                    c = [dirt[i] * (1 - e) + dirt_e[i] * e for i in range(3)]
                    m = 1.0 - smooth(MUD[2] * 0.55, MUD[2], math.hypot(xw - MUD[0], zw - MUD[1]))
                    c = [c[i] * (1 - m) + mud[i] * m for i in range(3)]
                    k = 0.92 + 0.08 * noise(xw * 3.1, zw * 3.1, 7.0)
                else:
                    n1 = 0.5 + 0.5 * noise(xw * 0.7, zw * 0.7, 3.0)
                    n2 = 0.5 + 0.5 * noise(xw * 2.3 + 4, zw * 2.1, 9.0)
                    c = [grass[i] * (1 - n1) + grass_l[i] * n1 for i in range(3)]
                    dk = smooth(0.55, 0.9, n2)
                    c = [c[i] * (1 - dk) + grass_d[i] * dk for i in range(3)]
                    near = 1.0 - smooth(-0.1, 0.6, d - w)
                    mud_n = 1.0 - smooth(MUD[2] - 0.1, MUD[2] + 0.4, math.hypot(xw - MUD[0], zw - MUD[1]))
                    near = max(near, mud_n)
                    c = [c[i] * (1 - 0.85 * near) + dirt_e[i] * 0.85 * near for i in range(3)]
                    k = 0.9 + 0.1 * (v.co.y / 0.22)
                v[layer] = tuple(clamp(c[i] * k, 0, 1) for i in range(3)) + (1.0,)
        bmesh.ops.delete(bm, geom=kill, context="FACES")
        if part == "Surface":
            # saia: desce 0,35 m nas bordas do ladrilho (nao vaza agua nas juncoes)
            skirt = hex_to_linear("#A07A55")
            for edge in ([vs[i][0] for i in range(NX + 1)], [vs[i][NZ] for i in range(NX, -1, -1)],
                         [vs[0][j] for j in range(NZ, -1, -1)], [vs[NX][j] for j in range(NZ + 1)]):
                edge = [v for v in edge if v.is_valid]
                low = []
                for v in edge:
                    nv = bm.verts.new((v.co.x, -0.35, v.co.z))
                    nv[layer] = tuple(skirt) + (1.0,)
                    low.append(nv)
                for i in range(len(edge) - 1):
                    if (edge[i].co - edge[i + 1].co).length < 0.3:
                        bm.faces.new((edge[i], low[i], low[i + 1], edge[i + 1]))
        if not bm.faces:
            bm.free()
            continue
        a.part(part, bm, "mat_env_ground", jit=0.0, ao=0.0, paint=False, smooth=(part == "Surface"))
    # pedrinhas na borda do caminho
    bm = bmesh.new()
    lay = a._layer(bm)
    rng = a.rng
    for i in range(int(W * 18)):
        x = rng.uniform(-W / 2 + 0.1, W / 2 - 0.1)
        z = rng.uniform(-TD / 2 + 0.3, TD / 2 - 0.3)
        xw, zw = x + ox, z + BANK_Z
        d, t = path_dist(xw, zw)
        w = path_half_width(xw, zw, t)
        if abs(d - w) > 0.35 or math.hypot(xw - MUD[0], zw - MUD[1]) < MUD[2] + 0.2:
            continue
        r = rng.uniform(0.05, 0.12)
        before = set(bm.verts)
        gsph(bm, (x, H(x, z) + r * 0.25, z), (r, r * 0.55, r * rng.uniform(0.8, 1.2)), 8, 5)
        g = rng.uniform(0.85, 1.1)
        for v in bm.verts:
            if v not in before:
                v[lay] = (clamp(0.92 * g), clamp(0.9 * g), clamp(0.97 * g), 1.0)
    if bm.verts:
        a.part("Pebbles", bm, "mat_env_rock", paint=False)
    else:
        bm.free()
    a.point("TileOrigin", (0, 0, 0))
    a.finish(glb, info, offset=W + 1.0)


def bank_path(M, info, glb):
    """Caminho de terra batida da margem sul em coordenadas do MUNDO (origem 0): fita com bordas irregulares em
    y = 0,002 e poca de lama em volta da pegada (y = 0,004). Partes: Dirt, Mud."""
    a = Asset("Bank_Path", M, 74)
    dirt = hex_to_linear("#DDBF8E")
    dirt_e = hex_to_linear("#B98A5E")
    mud = hex_to_linear("#8E6A46")
    pts = []
    for i in range(len(PATH) - 1):
        ax, az = PATH[i]
        bx, bz = PATH[i + 1]
        n = max(2, int(math.hypot(bx - ax, bz - az) / 0.2))
        for k in range(n):
            pts.append((ax + (bx - ax) * k / n, az + (bz - az) * k / n))
    pts.append(PATH[-1])
    # suaviza o polilinha (cantos arredondados)
    for _ in range(6):
        pts = [pts[0]] + [((pts[i - 1][0] + 2 * pts[i][0] + pts[i + 1][0]) / 4, (pts[i - 1][1] + 2 * pts[i][1] + pts[i + 1][1]) / 4)
                          for i in range(1, len(pts) - 1)] + [pts[-1]]
    bm = bmesh.new()
    lay = bm.verts.layers.float_color.new("Col")
    rows = []
    N = len(pts)
    for i, (x, z) in enumerate(pts):
        p0 = pts[max(0, i - 1)]
        p1 = pts[min(N - 1, i + 1)]
        tx, tz = p1[0] - p0[0], p1[1] - p0[1]
        L = math.hypot(tx, tz) or 1.0
        nx, nz = -tz / L, tx / L
        t = i / (N - 1)
        w = path_half_width(x, z, t)
        row = []
        for s, col in ((-1.0, dirt_e), (-0.55, dirt), (0.0, dirt), (0.55, dirt), (1.0, dirt_e)):
            jit = 0.08 * noise(x * 5.0 + s * 3, z * 5.0, 2.0) if abs(s) == 1.0 else 0.0
            v = bm.verts.new((x + nx * (w + jit) * s, 0.002, z + nz * (w + jit) * s))
            k = 0.93 + 0.07 * noise(x * 3.3 + s, z * 3.1, 7.0)
            v[lay] = tuple(clamp(col[c] * k) for c in range(3)) + (1.0,)
            row.append(v)
        rows.append(row)
    for i in range(N - 1):
        for j in range(4):
            bm.faces.new((rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]))
    a.part("Dirt", bm, "mat_env_ground", paint=False, recalc=False)
    bm = bmesh.new()
    lay = bm.verts.layers.float_color.new("Col")
    c = bm.verts.new((MUD[0], 0.004, MUD[1]))
    c[lay] = tuple(mud) + (1.0,)
    ring = []
    for k in range(28):
        ang = math.tau * k / 28
        r = MUD[2] * (1.0 + 0.12 * math.sin(3 * ang + 1.0) + 0.06 * math.sin(7 * ang))
        v = bm.verts.new((MUD[0] + r * math.cos(ang), 0.004, MUD[1] + r * math.sin(ang)))
        v[lay] = tuple(clamp(mud[i] * 1.12 + 0.03) for i in range(3)) + (1.0,)
        ring.append(v)
    for k in range(28):
        bm.faces.new((c, ring[(k + 1) % 28], ring[k]))
    a.part("Mud", bm, "mat_env_ground", paint=False, recalc=False, smooth=False)
    a.finish(glb, info)


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
    ground_tile(M, info, glb, "Ground_Tile_A", 71, 8.0, ox=-6.0)
    ground_tile(M, info, glb, "Ground_Tile_B", 72, 8.0, ox=6.0)
    ground_tile(M, info, glb, "Ground_Tile_Path", 73, 4.0, path=True, ox=0.0)
    bank_path(M, info, glb)
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
