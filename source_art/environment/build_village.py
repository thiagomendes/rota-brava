"""Kit da vila Farol 7 (RB-R1, PROVISORIO ate aprovacao de Thiago). Paleta e formas de docs/style-bible.md (secoes 2 e 5).
Casas modulares parametricas (4 tipos), barraca de mercado, poste, banco, canteiro, cerca, escada, muro, cais de pedra,
gramado, muro de arrimo, FAROL, morros, nuvem, gaivota, arvores redondas, barquinho, bandeirolas, tufo de flores.
Tudo do zero (bmesh + Bevel/Solidify). Espaco Godot (x leste, y cima, z sul; metros); frente das pecas = +Z.
Uso: blender --background --factory-startup --python build_village.py -- --blend X --glb-dir Y
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh
from mathutils import Matrix, Vector
from envlib import (REPO, Asset, arg_value, gbox, gcyl, gsph, grid_patch, lathe, materials, reset_scene, save_all,
                    sweep)
from rbart import hex_to_linear, mat as _mat, torus

VILLAGE = {
    "mat_env_wall_peach": ("#FFC9A3", 0.85), "mat_env_wall_mint": ("#BDEBD3", 0.85),
    "mat_env_wall_sky": ("#BFE3FF", 0.85), "mat_env_wall_lemon": ("#FFF0A8", 0.85),
    "mat_env_wall_rose": ("#FFC6D3", 0.85),
    "mat_env_roof_terracotta": ("#D8693F", 0.7), "mat_env_roof_blue": ("#3A7BD5", 0.6),
    "mat_env_trim": ("#FFFDF6", 0.6), "mat_env_glass": ("#35648A", 0.12),
    "mat_env_door": ("#2F9C95", 0.6), "mat_env_shutter": ("#4C9BE0", 0.6),
    "mat_env_stone": ("#EADFC8", 0.9), "mat_env_masonry": ("#CFC3B4", 0.95), "mat_env_cobble": ("#E3D3B6", 0.95),
    "mat_env_grass": ("#7CCB4A", 0.95), "mat_env_earth": ("#B98A5E", 0.95),
    "mat_env_awning_red": ("#E8664A", 0.8), "mat_env_awning_cream": ("#FFF1D6", 0.8),
    "mat_env_awning_blue": ("#3A7BD5", 0.8),
    "mat_env_iron": ("#2E5E6E", 0.5), "mat_env_tint": ("#FFFFFF", 0.7),
    "mat_env_lh_red": ("#E2473B", 0.55), "mat_env_lh_white": ("#FFFBF2", 0.6), "mat_env_lh_dark": ("#2E4756", 0.5),
    "mat_env_hill": ("#FFFFFF", 1.0), "mat_env_cloud": ("#FFFFFF", 1.0),
    "mat_env_gull": ("#FFFFFF", 0.8), "mat_env_gull_gray": ("#9AA3B5", 0.8), "mat_env_beak": ("#FFB23F", 0.6),
}
VILLAGE_EMISSIVE = {"mat_env_lh_glass": ("#FFE9A8", "#FFD88A", 4.0), "mat_env_lamp_light": ("#FFE9A8", "#FFD88A", 2.5)}

WALLS = ["peach", "mint", "sky", "lemon", "rose"]
FLOWER_TINTS = [(1.0, 0.45, 0.62), (1.0, 0.85, 0.3), (1.0, 1.0, 1.0), (0.72, 0.55, 0.95), (1.0, 0.55, 0.35)]


def village_materials():
    M = materials()
    for n, (hx, ro) in VILLAGE.items():
        M[n] = _mat(n, hx, ro, 0.0)
    for n, (hx, ex, st) in VILLAGE_EMISSIVE.items():
        M[n] = _mat(n, hx, 0.3, 0.0)
        b = M[n].node_tree.nodes["Principled BSDF"]
        b.inputs["Emission Color"].default_value = hex_to_linear(ex) + (1.0,)
        b.inputs["Emission Strength"].default_value = st
    return M


def ROT_FLAT():
    return Matrix.Rotation(math.radians(90), 4, "X")


# ------------------------------------------------------------------ casas
def _roof(bm, w, d, y, rh, o, kind):
    """Superficie do telhado (aberta; espessura vem do Solidify). kind: gable (cumeeira em x) ou hip."""
    x0, x1, z0, z1 = -w / 2 - o, w / 2 + o, -d / 2 - o, d / 2 + o
    e = [bm.verts.new(p) for p in ((x0, y, z1), (x1, y, z1), (x1, y, z0), (x0, y, z0))]
    if kind == "gable":
        r = [bm.verts.new((x0, y + rh, 0)), bm.verts.new((x1, y + rh, 0))]
        bm.faces.new((e[0], e[1], r[1], r[0]))
        bm.faces.new((e[2], e[3], r[0], r[1]))
    else:
        rx = max(0.05, (w - d) / 2)
        r = [bm.verts.new((-rx, y + rh, 0)), bm.verts.new((rx, y + rh, 0))]
        bm.faces.new((e[0], e[1], r[1], r[0]))
        bm.faces.new((e[2], e[3], r[0], r[1]))
        bm.faces.new((e[1], e[2], r[1]))
        bm.faces.new((e[3], e[0], r[0]))


def _window(a, bt, bg, bs, bf, x, y, z, ww, wh, face="front", shutters=True, flowers=False):
    """Janela com moldura branca, cruzeta, peitoril, venezianas e floreira. face: front (+z) ou side (+x)."""
    def B(bm, c, s):
        if face == "front":
            gbox(bm, (x + c[0], y + c[1], z + c[2]), s)
        else:
            gbox(bm, (z + c[2], y + c[1], -(x + c[0])), (s[2], s[1], s[0]))
    t = 0.1
    B(bt, (0, wh / 2 + t / 2, 0.04), (ww + 2 * t, t, 0.12))
    B(bt, (0, -wh / 2 - t / 2, 0.06), (ww + 2 * t + 0.14, t * 1.2, 0.2))
    B(bt, (-ww / 2 - t / 2, 0, 0.04), (t, wh, 0.12))
    B(bt, (ww / 2 + t / 2, 0, 0.04), (t, wh, 0.12))
    B(bt, (0, 0, 0.0), (0.05, wh, 0.06))
    B(bt, (0, wh * 0.1, 0.0), (ww, 0.05, 0.06))
    B(bg, (0, 0, -0.03), (ww, wh, 0.04))
    if shutters:
        B(bs, (-ww / 2 - t - ww * 0.27, 0, 0.05), (ww * 0.5, wh + 0.05, 0.06))
        B(bs, (ww / 2 + t + ww * 0.27, 0, 0.05), (ww * 0.5, wh + 0.05, 0.06))
    if flowers:
        B(bt, (0, -wh / 2 - 0.28, 0.16), (ww + 0.1, 0.26, 0.22))
        for k in range(5):
            px = (k - 2) * (ww + 0.05) / 4.2
            before = set(bf.verts)
            r = a.rng.uniform(0.09, 0.13)
            c = (x + px, y - wh / 2 - 0.12, z + 0.17) if face == "front" else (z + 0.17, y - wh / 2 - 0.12, -(x + px))
            gsph(bf, c, r, 8, 6)
            a.paint_new(bf, before, jit=0.05, ao=0.2, tint=FLOWER_TINTS[a.rng.randrange(len(FLOWER_TINTS))])


def house(M, info, glb, name, w, d, floors, wall, roof, kind, seed, door_x=0.0, balcony=False, awning=None,
          chimney=True, side_windows=True):
    a = Asset(name, M, seed)
    fh = 2.75
    H = 0.45 + floors * fh
    # embasamento de pedra (mais largo: "gordinho embaixo")
    bm = bmesh.new()
    gbox(bm, (0, 0.225, 0), (w + 0.24, 0.45, d + 0.24))
    a.part("Plinth", bm, "mat_env_stone", bevel=0.07, bseg=2, jit=0.08, ao=0.35)
    # paredes com leve afunilamento
    bm = bmesh.new()
    gbox(bm, (0, 0.45 + (H - 0.45) / 2, 0), (w, H - 0.45, d), cuts=(0, 2, 0))
    for v in bm.verts:
        k = 1.0 - 0.035 * (v.co.y - 0.45) / (H - 0.45)
        v.co.x *= k
        v.co.z *= k
    # empena (triangulo) nas casas de duas aguas
    rh = d * 0.42 if kind == "gable" else d * 0.36
    top_w, top_d = w * (1 - 0.035), d * (1 - 0.035)
    if kind == "gable":
        for sx in (-1, 1):
            xx = sx * top_w / 2
            vs = [bm.verts.new((xx, H, -top_d / 2)), bm.verts.new((xx, H, top_d / 2)), bm.verts.new((xx, H + rh * 0.97, 0))]
            ws = [bm.verts.new((xx - sx * 0.3, H, -top_d / 2 + 0.05)), bm.verts.new((xx - sx * 0.3, H, top_d / 2 - 0.05)),
                  bm.verts.new((xx - sx * 0.3, H + rh * 0.9, 0))]
            bm.faces.new(vs if sx > 0 else vs[::-1])
            bm.faces.new(ws[::-1] if sx > 0 else ws)
            for i in range(3):
                j = (i + 1) % 3
                bm.faces.new((vs[i], ws[i], ws[j], vs[j]) if sx < 0 else (vs[j], ws[j], ws[i], vs[i]))
    a.part("Wall", bm, "mat_env_wall_" + wall, bevel=0.14, bseg=3, jit=0.05, ao=0.22)
    # telhado com espessura + fiadas de telha
    bm = bmesh.new()
    _roof(bm, top_w, top_d, H + 0.02, rh, 0.38, kind)
    a.part("Roof", bm, "mat_env_roof_" + roof, solid=0.2, bevel=0.06, bseg=2, jit=0.06, ao=0.15, smooth=False)
    bm = bmesh.new()
    L = math.hypot(top_d / 2 + 0.38, rh)
    for side in (-1, 1):
        for k in range(1, 4):
            f = k / 4.0
            zz = side * (top_d / 2 + 0.38) * (1 - f)
            yy = H + 0.07 + rh * f
            half = top_w / 2 + 0.36 if kind == "gable" else (top_w / 2 + 0.38) - ((top_w / 2 + 0.38) - max(0.05, (top_w - top_d) / 2)) * f - 0.1
            gcyl(bm, (-half, yy, zz), (half, yy, zz), 0.055, seg=6)
    gcyl(bm, (-(top_w / 2 + 0.36) if kind == "gable" else -max(0.08, (top_w - top_d) / 2), H + rh + 0.06, 0),
         ((top_w / 2 + 0.36) if kind == "gable" else max(0.08, (top_w - top_d) / 2), H + rh + 0.06, 0), 0.13, seg=8)
    a.part("RoofTiles", bm, "mat_env_roof_" + roof, jit=0.1, ao=0.1, tint=(0.9, 0.9, 0.9))
    # frisos (cornija e faixa entre andares)
    bm = bmesh.new()
    gbox(bm, (0, H - 0.05, 0), (top_w + 0.16, 0.18, top_d + 0.16))
    for f in range(1, floors):
        yy = 0.45 + f * fh
        k = 1.0 - 0.035 * (yy - 0.45) / (H - 0.45)
        gbox(bm, (0, yy, 0), (w * k + 0.08, 0.1, d * k + 0.08))
    for sx in (-1, 1):
        for sz in (-1, 1):
            gbox(bm, (sx * (w / 2 - 0.02), 0.45 + (H - 0.45) / 2, sz * (d / 2 - 0.02)), (0.16, H - 0.45, 0.16))
    a.part("Trim", bm, "mat_env_trim", bevel=0.04, bseg=2, jit=0.03, ao=0.15)
    # janelas, porta
    bt, bg, bs, bf = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    fz = d / 2
    ncol = max(1, int((w + 0.4) / 1.7))
    xs = [(-w / 2 + w * (i + 0.5) / ncol) for i in range(ncol)]
    for f in range(floors):
        yy = 0.45 + f * fh + 1.45
        k = 1.0 - 0.035 * (yy - 0.45) / (H - 0.45)
        for x in xs:
            if f == 0 and abs(x - door_x) < 0.9:
                continue
            _window(a, bt, bg, bs, bf, x * k, yy, fz * k, 0.72, 1.0, shutters=(w / ncol) > 1.5,
                    flowers=(f > 0 or a.rng.random() < 0.5))
        if side_windows:
            _window(a, bt, bg, bs, bf, 0.0, yy, (w / 2) * k, 0.62, 0.9, face="side", shutters=False,
                    flowers=a.rng.random() < 0.5)
    a.part("WindowTrim", bt, "mat_env_trim", bevel=0.02, bseg=1, jit=0.03, ao=0.1)
    a.part("Glass", bg, "mat_env_glass", jit=0.05, ao=0.0)
    a.part("Shutters", bs, "mat_env_shutter", bevel=0.015, bseg=1, jit=0.08, ao=0.1)
    a.part("Flowers", bf, "mat_env_tint", paint=False)
    # porta arqueada (2,0 m) com moldura
    bm = bmesh.new()
    gbox(bm, (door_x, 0.45 + 0.75, fz + 0.03), (1.0, 1.5, 0.08))
    gcyl(bm, (door_x, 1.95, fz - 0.01), (door_x, 1.95, fz + 0.07), 0.5, seg=14)
    a.part("Door", bm, "mat_env_door", bevel=0.02, bseg=1, jit=0.06, ao=0.25, smooth=False)
    bm = bmesh.new()
    gbox(bm, (door_x, 0.45 + 0.78, fz + 0.0), (1.26, 1.56, 0.1))
    gcyl(bm, (door_x, 1.98, fz - 0.03), (door_x, 1.98, fz + 0.05), 0.63, seg=14)
    gbox(bm, (door_x, 0.1, fz + 0.3), (1.5, 0.2, 0.5))
    gsph(bm, (door_x + 0.32, 1.2, fz + 0.1), 0.05, 6, 4)
    a.part("DoorFrame", bm, "mat_env_trim", bevel=0.03, bseg=1, jit=0.03, ao=0.1, smooth=False)
    # chamine
    if chimney:
        bm = bmesh.new()
        cx = w * 0.28
        gbox(bm, (cx, H + rh * 0.55 + 0.45, -d * 0.12), (0.6, rh * 0.9 + 0.9, 0.6))
        gbox(bm, (cx, H + rh + 0.95, -d * 0.12), (0.78, 0.18, 0.78))
        a.part("Chimney", bm, "mat_env_masonry", bevel=0.05, bseg=2, jit=0.1, ao=0.3)
    if balcony and floors > 1:
        bm = bmesh.new()
        yy = 0.45 + fh
        gbox(bm, (0, yy, fz + 0.45), (w * 0.62, 0.14, 0.9))
        n = 9
        for i in range(n):
            x = -w * 0.3 + w * 0.6 * i / (n - 1)
            gcyl(bm, (x, yy, fz + 0.86), (x, yy + 0.9, fz + 0.86), 0.035, seg=6)
        for sx in (-1, 1):
            gcyl(bm, (sx * w * 0.3, yy, fz + 0.86), (sx * w * 0.3, yy, fz + 0.05), 0.04, seg=6)
        sweep(bm, [(-w * 0.31, yy + 0.92, fz), (-w * 0.31, yy + 0.92, fz + 0.86), (w * 0.31, yy + 0.92, fz + 0.86),
                   (w * 0.31, yy + 0.92, fz)], 0.05, seg=6)
        a.part("Balcony", bm, "mat_env_trim", bevel=0.0, jit=0.05, ao=0.15)
    if awning:
        _awning(a, (door_x, 2.85, fz), w * 0.86, 1.3, awning)
    info_ = a.finish(glb, info)
    return info_


def _awning(a, base, width, depth, colors, drop=0.55, nstripe=None):
    """Toldo listrado inclinado com babado de meia-lua. base = (x, y, z) da borda na parede."""
    x0, y0, z0 = base
    n = nstripe or max(4, int(width / 0.36))
    sw = width / n
    ang = math.degrees(math.atan2(drop, depth))
    L = math.hypot(drop, depth)
    bms = [bmesh.new(), bmesh.new()]
    for i in range(n):
        bm = bms[i % 2]
        x = x0 - width / 2 + sw * (i + 0.5)
        # tira curva (tres segmentos)
        pts = []
        for k in range(4):
            t = k / 3.0
            pts.append((x, y0 - drop * t - 0.12 * math.sin(math.pi * t), z0 + depth * t))
        for k in range(3):
            p, q = Vector(pts[k]), Vector(pts[k + 1])
            c = (p + q) / 2
            seg = q - p
            rx = -math.degrees(math.atan2(-seg.y, seg.z))
            gbox(bm, c, (sw + 0.004, 0.05, seg.length + 0.02), rx=-rx)
        gcyl(bm, (x, pts[-1][1] - 0.02, z0 + depth + 0.01), (x, pts[-1][1] - 0.02, z0 + depth - 0.03), sw / 2, seg=10)
    a.part("Awning_A", bms[0], colors[0], bevel=0.015, bseg=1, jit=0.04, ao=0.1)
    a.part("Awning_B", bms[1], colors[1], bevel=0.015, bseg=1, jit=0.04, ao=0.1)
    bm = bmesh.new()
    for sx in (-1, 1):
        gcyl(bm, (x0 + sx * width / 2, y0 + 0.02, z0), (x0 + sx * width / 2, y0 - drop, z0 + depth), 0.03, seg=6)
    a.part("AwningRod", bm, "mat_env_iron", jit=0.05, ao=0.0)


# ------------------------------------------------------------------ mobiliario urbano
def market_stall(M, info, glb, name, colors, seed):
    a = Asset(name, M, seed)
    w, d = 2.6, 1.4
    bm = bmesh.new()
    for sx in (-1, 1):
        for sz in (-1, 1):
            gcyl(bm, (sx * w / 2, 0, sz * d / 2), (sx * w / 2, 2.3 if sz < 0 else 2.0, sz * d / 2), 0.06, seg=8)
    gbox(bm, (0, 0.85, d / 2 - 0.1), (w + 0.1, 0.12, 0.6))
    gbox(bm, (0, 0.45, d / 2 - 0.1), (w - 0.1, 0.8, 0.5))
    gbox(bm, (0, 0.15, 0), (w - 0.1, 0.06, d - 0.1))
    a.part("Frame", bm, "mat_env_wood_light", bevel=0.025, bseg=2, jit=0.15, ao=0.35)
    # caixas de frutas no balcao (pessego, limao, maca) - cor por vertice
    bm = bmesh.new()
    bf = bmesh.new()
    tints = [(1.0, 0.55, 0.32), (1.0, 0.86, 0.25), (0.95, 0.3, 0.3), (0.55, 0.85, 0.35)]
    for i in range(4):
        cx = -w / 2 + 0.38 + i * 0.62
        gbox(bm, (cx, 0.98, d / 2 - 0.1), (0.54, 0.16, 0.48), ry=a.rng.uniform(-6, 6))
        for j in range(6):
            before = set(bf.verts)
            gsph(bf, (cx + (j % 3 - 1) * 0.15, 1.1, d / 2 - 0.22 + (j // 3) * 0.22), 0.085, 8, 6)
            a.paint_new(bf, before, jit=0.08, ao=0.25, tint=tints[i])
    a.part("Crates", bm, "mat_env_wood_deck", bevel=0.015, bseg=1, jit=0.15, ao=0.3)
    a.part("Fruit", bf, "mat_env_tint", paint=False)
    _awning(a, (0, 2.42, -d / 2 - 0.05), w + 0.4, d + 0.55, colors, drop=0.6)
    a.finish(glb, info)


def street_lamp(M, info, glb):
    a = Asset("Street_Lamp", M, 31)
    bm = bmesh.new()
    lathe(bm, [(0.22, 0), (0.22, 0.12), (0.15, 0.22), (0.09, 0.4), (0.07, 2.6), (0.1, 2.7), (0.1, 2.78)], seg=10)
    sweep(bm, [(0, 2.74, 0), (0.18, 2.95, 0), (0.42, 3.0, 0)], 0.035, seg=6)
    lathe(bm, [(0.0, 3.55), (0.12, 3.5), (0.24, 3.42), (0.26, 3.36), (0.0, 3.36)], seg=10, c=(0.42, 0, 0))
    a.part("Post", bm, "mat_env_iron", bevel=0.0, jit=0.05, ao=0.3)
    bm = bmesh.new()
    lathe(bm, [(0.0, 2.92), (0.12, 2.95), (0.17, 3.15), (0.17, 3.3), (0.0, 3.36)], seg=10, c=(0.42, 0, 0))
    a.part("Light", bm, "mat_env_lamp_light", jit=0.0, ao=0.0)
    a.point("Lamp_Light", (0.42, 3.15, 0))
    a.finish(glb, info)


def park_bench(M, info, glb):
    a = Asset("Park_Bench", M, 32)
    bm = bmesh.new()
    for k in range(3):
        gbox(bm, (0, 0.45, -0.18 + k * 0.15), (1.7, 0.05, 0.12))
    for k in range(2):
        gbox(bm, (0, 0.68 + k * 0.17, -0.3), (1.7, 0.12, 0.05), rx=-12)
    a.part("Slats", bm, "mat_env_wood_light", bevel=0.015, bseg=2, jit=0.15, ao=0.15)
    bm = bmesh.new()
    for sx in (-0.7, 0.7):
        sweep(bm, [(sx, 0, 0.2), (sx, 0.42, 0.12), (sx, 0.42, -0.25), (sx, 0, -0.25)], 0.035, seg=6)
        sweep(bm, [(sx, 0.42, -0.25), (sx, 0.95, -0.34)], 0.03, seg=6)
        sweep(bm, [(sx, 0.62, 0.15), (sx, 0.62, -0.2)], 0.03, seg=6)
    a.part("Legs", bm, "mat_env_iron", jit=0.05, ao=0.2)
    a.finish(glb, info)


def flower_bed(M, info, glb):
    a = Asset("Flower_Bed", M, 33)
    bm = bmesh.new()
    lathe(bm, [(0.0, 0.0), (1.0, 0.0), (1.05, 0.2), (1.0, 0.42), (0.88, 0.44), (0.86, 0.3), (0.0, 0.3)], seg=16)
    a.part("Planter", bm, "mat_env_stone", jit=0.08, ao=0.35)
    bm = bmesh.new()
    gsph(bm, (0, 0.3, 0), (0.88, 0.3, 0.88), 14, 6)
    a.part("Soil", bm, "mat_env_grass", jit=0.1, ao=0.3)
    bf = bmesh.new()
    for i in range(22):
        ang = a.rng.uniform(0, math.tau)
        rr = 0.72 * math.sqrt(a.rng.random())
        y = 0.3 + 0.3 * math.sqrt(max(0, 1 - (rr / 0.88) ** 2)) + 0.04
        before = set(bf.verts)
        gsph(bf, (rr * math.cos(ang), y, rr * math.sin(ang)), a.rng.uniform(0.09, 0.13), 8, 5)
        a.paint_new(bf, before, jit=0.05, ao=0.15, tint=FLOWER_TINTS[i % len(FLOWER_TINTS)])
    a.part("Flowers", bf, "mat_env_tint", paint=False)
    a.finish(glb, info)


def flower_clump(M, info, glb):
    """Tufo de flores para MultiMesh (malha unica com cor por vertice)."""
    a = Asset("Flower_Clump", M, 34)
    bm = bmesh.new()
    gsph(bm, (0, 0.08, 0), (0.32, 0.18, 0.32), 10, 5)
    a.paint_new(bm, set(), jit=0.08, ao=0.45, tint=(0.49, 0.8, 0.29))
    for i in range(7):
        ang = i * 2.4
        rr = 0.08 + 0.18 * (i % 3) / 2
        before = set(bm.verts)
        gsph(bm, (rr * math.cos(ang), 0.24 + 0.05 * (i % 2), rr * math.sin(ang)), 0.075, 6, 4)
        a.paint_new(bm, before, jit=0.04, ao=0.1, tint=FLOWER_TINTS[(i * 3) % len(FLOWER_TINTS)])
    a.part("Clump", bm, "mat_env_tint", paint=False)
    a.finish(glb, info)


def fence(M, info, glb):
    a = Asset("Fence_2m", M, 35)
    bm = bmesh.new()
    for i in range(7):
        x = -0.9 + i * 0.3
        h = 0.95 + (0.05 if i % 2 else 0)
        gbox(bm, (x, h / 2, 0), (0.12, h, 0.05))
        gsph(bm, (x, h, 0), (0.06, 0.07, 0.026), 8, 4)
    for y in (0.3, 0.72):
        gbox(bm, (0, y, -0.05), (2.0, 0.09, 0.04))
    a.part("Pickets", bm, "mat_env_trim", bevel=0.012, bseg=1, jit=0.08, ao=0.3)
    a.finish(glb, info)


def stone_stairs(M, info, glb):
    """Escada de pedra: sobe 1,6 m em +Z->-Z (base em z=+1.4, topo em z=-1.4, topo y=1.6). Largura 2 m."""
    a = Asset("Stone_Stairs", M, 36)
    bm = bmesh.new()
    n = 6
    for i in range(n):
        h = 1.6 * (i + 1) / n
        z = 1.4 - (i + 0.5) * 2.8 / n
        gbox(bm, (0, h / 2, z), (2.0 - 0.04 * a.rng.random(), h, 2.8 / n + 0.02))
    a.part("Steps", bm, "mat_env_stone", bevel=0.05, bseg=2, jit=0.12, ao=0.3)
    bm = bmesh.new()
    for sx in (-1, 1):
        for i in range(n):
            h = 1.6 * (i + 1) / n
            z = 1.4 - (i + 0.5) * 2.8 / n
            gbox(bm, (sx * 1.15, h / 2 + 0.2, z), (0.32, h + 0.4, 2.8 / n + 0.02))
    a.part("Cheeks", bm, "mat_env_masonry", bevel=0.06, bseg=2, jit=0.12, ao=0.35)
    a.finish(glb, info)


def low_wall(M, info, glb):
    a = Asset("Low_Wall", M, 37)
    bm = bmesh.new()
    gbox(bm, (0, 0.3, 0), (4.0, 0.6, 0.45))
    a.part("Body", bm, "mat_env_masonry", bevel=0.05, bseg=2, jit=0.1, ao=0.4)
    bm = bmesh.new()
    x = -2.0
    while x < 1.95:
        sw = a.rng.uniform(0.35, 0.6)
        sw = min(sw, 2.0 - x)
        before = set(bm.verts)
        gbox(bm, (x + sw / 2, 0.66, 0), (sw - 0.03, 0.16, 0.55))
        a.paint_new(bm, before, jit=0.15, ao=0.1)
        x += sw
    a.part("Cap", bm, "mat_env_stone", bevel=0.04, bseg=2, paint=False)
    a.finish(glb, info)


# ------------------------------------------------------------------ chao: cais de pedra, praca, gramado, arrimo
def _cobble_top(a, bm, sx, sz, cell=0.5):
    nx, nz = int(sx / cell), int(sz / cell)
    lay = a._layer(bm)
    g = 0.035
    base = [bm.verts.new(p) for p in ((-sx / 2, -g, sz / 2), (sx / 2, -g, sz / 2), (sx / 2, -g, -sz / 2), (-sx / 2, -g, -sz / 2))]
    bm.faces.new(base)
    for v in base:
        v[lay] = (0.66, 0.62, 0.6, 1.0)
    cx, cz = sx / nx, sz / nz
    for i in range(nx):
        for j in range(nz):
            off = (cx * 0.5) if j % 2 else 0.0
            x0 = -sx / 2 + i * cx + off
            x1 = min(sx / 2, x0 + cx)
            z0 = -sz / 2 + j * cz
            m = 0.025
            q = [bm.verts.new(p) for p in ((x0 + m, 0, z0 + cz - m), (x1 - m, 0, z0 + cz - m), (x1 - m, 0, z0 + m), (x0 + m, 0, z0 + m))]
            bm.faces.new(q)
            k = 1.0 - a.rng.uniform(0.0, 0.16)
            for v in q:
                v[lay] = (k, k * 0.99, k * 0.96, 1.0)
            if off and i == 0:
                q = [bm.verts.new(p) for p in ((-sx / 2 + m, 0, z0 + cz - m), (x0 - m, 0, z0 + cz - m), (x0 - m, 0, z0 + m), (-sx / 2 + m, 0, z0 + m))]
                bm.faces.new(q)
                for v in q:
                    v[lay] = (k, k, k, 1.0)


def quay_block(M, info, glb):
    """Cais de pedra 8 x 6 m: topo de paralelepipedo em y=0, face de pedra ate y=-1.6, capeamento redondo na borda -Z."""
    a = Asset("Quay_Block", M, 38)
    bm = bmesh.new()
    _cobble_top(a, bm, 8.0, 6.0)
    a.part("Top", bm, "mat_env_cobble", paint=False, smooth=False)
    bm = bmesh.new()
    gbox(bm, (0, -0.85, 0), (8.0, 1.6, 6.0))
    for f in bm.faces:
        if abs(f.normal.z) > 0.9 or abs(f.normal.x) > 0.9:
            pass
    a.part("Body", bm, "mat_env_masonry", jit=0.06, ao=0.55)
    bm = bmesh.new()
    x = -4.0
    while x < 3.95:
        sw = min(a.rng.uniform(0.7, 1.1), 4.0 - x)
        before = set(bm.verts)
        gbox(bm, (x + sw / 2, 0.06, -2.82), (sw - 0.04, 0.24, 0.42))
        a.paint_new(bm, before, jit=0.12, ao=0.15)
        x += sw
    for i in range(8):
        before = set(bm.verts)
        gbox(bm, (-3.5 + i, -0.55 - 0.45 * (i % 2), -3.02), (0.96, 0.42, 0.08))
        a.paint_new(bm, before, jit=0.18, ao=0.4)
    a.part("Coping", bm, "mat_env_stone", bevel=0.06, bseg=2, paint=False)
    a.finish(glb, info)


def plaza_tile(M, info, glb):
    a = Asset("Plaza_Tile", M, 39)
    bm = bmesh.new()
    _cobble_top(a, bm, 8.0, 8.0, cell=0.66)
    a.part("Top", bm, "mat_env_cobble", paint=False, smooth=False)
    bm = bmesh.new()
    gbox(bm, (0, -0.4, 0), (8.0, 0.7, 8.0))
    a.part("Body", bm, "mat_env_masonry", jit=0.05, ao=0.4)
    a.finish(glb, info)


def lawn_block(M, info, glb):
    """Gramado 8 x 6 m (topo y=0 com ondulacao <= 6 cm), lateral de terra ate -1,6."""
    a = Asset("Lawn_Block", M, 40)
    bm = bmesh.new()
    a._layer(bm)
    vs, faces = grid_patch(bm, -4, 4, -3, 3, 16, 12, lambda x, z: 0.04 * math.sin(x * 1.3) * math.cos(z * 1.1) + 0.02)
    lay = a._layer(bm)
    for row in vs:
        for v in row:
            k = 0.88 + 0.12 * (0.5 + 0.5 * math.sin(v.co.x * 0.9 + v.co.z * 1.7))
            v[lay] = (k, k, k * 0.95, 1.0)
    a.part("Top", bm, "mat_env_grass", paint=False)
    bm = bmesh.new()
    gbox(bm, (0, -0.82, 0), (7.96, 1.6, 5.96))
    a.part("Body", bm, "mat_env_earth", jit=0.05, ao=0.5)
    a.finish(glb, info)


def terrace_wall(M, info, glb):
    """Muro de arrimo 8 m, topo em y=0, desce ate -2,6 (para terracos). Pedras em relevo na face +Z."""
    a = Asset("Terrace_Wall", M, 41)
    bm = bmesh.new()
    gbox(bm, (0, -1.3, -0.2), (8.0, 2.6, 0.8))
    a.part("Core", bm, "mat_env_masonry", jit=0.05, ao=0.5)
    bm = bmesh.new()
    rows = 5
    for r in range(rows):
        y = -2.6 + (r + 0.5) * 2.4 / rows
        x = -4.0 + (0.3 if r % 2 else 0.0)
        while x < 3.95:
            sw = min(a.rng.uniform(0.7, 1.2), 4.0 - x)
            if sw > 0.15:
                before = set(bm.verts)
                gbox(bm, (x + sw / 2, y, 0.25), (sw - 0.07, 2.4 / rows - 0.07, 0.12))
                a.paint_new(bm, before, jit=0.2, ao=0.25, ao_h=2.6)
            x += sw
    gbox(bm, (0, 0.0, 0.05), (8.0, 0.22, 0.5))
    a.part("Stones", bm, "mat_env_stone", bevel=0.05, bseg=2, paint=False)
    a.finish(glb, info)


# ------------------------------------------------------------------ farol
def lighthouse(M, info, glb):
    """Farol 7: torre listrada vermelho/branco 15 m, galeria, lanterna com emissao, cupula. Total ~19,8 m."""
    a = Asset("Lighthouse", M, 50)
    bm = bmesh.new()
    lathe(bm, [(0.0, 0.0), (3.2, 0.0), (3.3, 0.5), (3.1, 1.0), (0.0, 1.0)], seg=10)
    a.part("Base", bm, "mat_env_masonry", bevel=0.08, bseg=2, jit=0.1, ao=0.4, smooth=False)

    def r_at(y):
        return 2.25 - 0.75 * (y - 1.0) / 14.0
    bands = [(1.0, 3.6), (3.6, 6.4), (6.4, 9.2), (9.2, 12.0), (12.0, 15.0)]
    br, bw = bmesh.new(), bmesh.new()
    for i, (y0, y1) in enumerate(bands):
        prof = [(r_at(y0 + (y1 - y0) * k / 3), y0 + (y1 - y0) * k / 3) for k in range(4)]
        lathe(br if i % 2 == 0 else bw, prof, seg=24)
    a.part("Bands_Red", br, "mat_env_lh_red", jit=0.03, ao=0.25, ao_h=15)
    a.part("Bands_White", bw, "mat_env_lh_white", jit=0.03, ao=0.2, ao_h=15)
    # porta e janelinhas
    bm = bmesh.new()
    gbox(bm, (0, 1.95, 2.17), (1.1, 1.9, 0.2))
    gcyl(bm, (0, 2.9, 2.08), (0, 2.9, 2.27), 0.55, seg=12)
    for y, ang in ((6.0, 0.0), (9.8, 0.0), (8.0, 90.0)):
        rr = r_at(y)
        c, s = math.sin(math.radians(ang)), math.cos(math.radians(ang))
        gcyl(bm, (c * (rr - 0.1), y, s * (rr - 0.1)), (c * (rr + 0.06), y, s * (rr + 0.06)), 0.36, seg=12)
    a.part("Openings", bm, "mat_env_lh_dark", bevel=0.02, bseg=1, jit=0.05, ao=0.1)
    bm = bmesh.new()
    gcyl(bm, (0, 2.9, 2.04), (0, 2.9, 2.2), 0.7, seg=12)
    gbox(bm, (0, 1.9, 2.12), (1.4, 2.0, 0.14))
    gbox(bm, (0, 1.1, 2.7), (1.8, 0.2, 1.1))
    a.part("DoorFrame", bm, "mat_env_trim", bevel=0.03, bseg=1, jit=0.03, ao=0.15)
    # galeria
    bm = bmesh.new()
    lathe(bm, [(0.0, 14.9), (1.6, 14.9), (2.4, 15.2), (2.4, 15.45), (0.0, 15.45)], seg=24)
    n = 20
    for i in range(n):
        an = math.tau * i / n
        gcyl(bm, (2.25 * math.cos(an), 15.45, 2.25 * math.sin(an)), (2.25 * math.cos(an), 16.4, 2.25 * math.sin(an)),
             0.04, seg=5)
    torus(bm, (0, 16.4, 0), 2.25, 0.07, rot=ROT_FLAT(), major=32, minor=6)
    a.part("Gallery", bm, "mat_env_lh_dark", jit=0.05, ao=0.2)
    # lanterna
    bm = bmesh.new()
    lathe(bm, [(1.15, 15.45), (1.15, 17.3)], seg=16)
    a.part("Lantern", bm, "mat_env_lh_glass", jit=0.0, ao=0.0)
    a.point("Beacon", (0, 16.4, 0))
    bm = bmesh.new()
    for i in range(8):
        an = math.tau * i / 8
        gcyl(bm, (1.2 * math.cos(an), 15.45, 1.2 * math.sin(an)), (1.2 * math.cos(an), 17.35, 1.2 * math.sin(an)),
             0.06, seg=5)
    lathe(bm, [(1.2, 15.4), (1.35, 15.5), (1.35, 15.65), (1.2, 15.65)], seg=16)
    a.part("Mullions", bm, "mat_env_lh_dark", jit=0.05, ao=0.1)
    bm = bmesh.new()
    prof = [(1.5, 17.3), (1.55, 17.45)] + [(1.45 * math.cos(t * math.pi / 2 / 6), 17.45 + 1.3 * math.sin(t * math.pi / 2 / 6))
                                          for t in range(1, 7)]
    prof[-1] = (0.0, prof[-1][1])
    lathe(bm, prof, seg=24)
    gsph(bm, (0, 18.95, 0), 0.28, 12, 8)
    gcyl(bm, (0, 19.15, 0), (0, 19.8, 0), 0.06, 0.02, seg=6)
    a.part("Dome", bm, "mat_env_lh_red", jit=0.03, ao=0.05)
    a.finish(glb, info)


# ------------------------------------------------------------------ fundo e ceu
def hills(M, info, glb, name, w, depth, hmax, tint_near, tint_far, seed, nx=36, nz=8):
    """Morros de fundo em malha baixa: base y=-0.5, frente em z=+depth/2. Cor por vertice (verde -> azulado com a altura)."""
    a = Asset(name, M, seed)
    rnd = a.rng
    bumps = [(rnd.uniform(-w / 2, w / 2), rnd.uniform(0.25, 1.0) * hmax, rnd.uniform(w * 0.08, w * 0.2)) for _ in range(7)]

    def hgt(x, z):
        t = (depth / 2 - z) / depth
        prof = math.sin(min(1.0, t * 1.4) * math.pi / 2)
        h = max(b[1] * math.exp(-((x - b[0]) / b[2]) ** 2) for b in bumps)
        return -0.5 + prof * h
    bm = bmesh.new()
    a._layer(bm)
    vs, faces = grid_patch(bm, -w / 2, w / 2, -depth / 2, depth / 2, nx, nz, hgt)
    lay = a._layer(bm)
    for row in vs:
        for v in row:
            t = clamp01((v.co.y + 0.5) / hmax)
            c = [tint_near[i] * (1 - t) + tint_far[i] * t for i in range(3)]
            v[lay] = (c[0], c[1], c[2], 1.0)
    a.part("Mass", bm, "mat_env_hill", paint=False, smooth=True)
    a.finish(glb, info)


def clamp01(v):
    return max(0.0, min(1.0, v))


def cloud(M, info, glb):
    a = Asset("Cloud", M, 60)
    bm = bmesh.new()
    lumps = [(0, 0, 0, 2.2), (2.2, -0.3, 0.3, 1.6), (-2.1, -0.4, -0.2, 1.5), (0.9, 1.0, 0, 1.5), (-0.8, 0.8, 0.4, 1.3),
             (3.6, -0.7, 0, 1.0), (-3.4, -0.8, 0.2, 0.9)]
    for x, y, z, r in lumps:
        gsph(bm, (x, y, z), (r, r * 0.85, r * 0.9), 14, 8)
    lay = a._layer(bm)
    for v in bm.verts:
        t = clamp01((v.co.y + 1.6) / 3.2)
        v[lay] = (0.82 + 0.18 * t, 0.8 + 0.2 * t, 0.93 + 0.07 * t, 1.0)
    for v in bm.verts:
        if v.co.y < -1.2:
            v.co.y = -1.2 + (v.co.y + 1.2) * 0.25
    a.part("Puff", bm, "mat_env_cloud", paint=False)
    a.finish(glb, info)


def seagull(M, info, glb):
    a = Asset("Seagull", M, 61)
    bm = bmesh.new()
    gsph(bm, (0, 0, 0), (0.09, 0.09, 0.22), 10, 6)
    gsph(bm, (0, 0.05, -0.2), 0.075, 8, 6)
    a.part("Body", bm, "mat_env_gull", jit=0.03, ao=0.15)
    bm = bmesh.new()
    for sx in (-1, 1):
        sweep(bm, [(0, 0.03, -0.02), (sx * 0.3, 0.12, 0.0), (sx * 0.62, 0.02, 0.06)], lambda t: 0.06 * (1 - 0.7 * t), seg=6)
    a.part("Wings", bm, "mat_env_gull_gray", jit=0.03, ao=0.1)
    bm = bmesh.new()
    gcyl(bm, (0, 0.04, -0.26), (0, 0.03, -0.36), 0.03, 0.01, seg=6)
    a.part("Beak", bm, "mat_env_beak", jit=0.0, ao=0.0)
    a.finish(glb, info)


def tree_round(M, info, glb, name, h, seed, lumps=3, leaf="mat_env_foliage_a"):
    a = Asset(name, M, seed)
    bm = bmesh.new()
    sweep(bm, [(0, 0, 0), (0.05, h * 0.3, 0.02), (-0.03, h * 0.55, 0)], lambda t: 0.2 * (1 - 0.45 * t), seg=8)
    a.part("Trunk", bm, "mat_env_trunk", jit=0.1, ao=0.3)
    bm = bmesh.new()
    cr = h * 0.3
    gsph(bm, (0, h * 0.62, 0), cr, 16, 10)
    for i in range(lumps):
        an = math.tau * i / lumps + a.rng.uniform(-0.4, 0.4)
        gsph(bm, (cr * 0.62 * math.cos(an), h * 0.62 + a.rng.uniform(-0.15, 0.35) * cr, cr * 0.62 * math.sin(an)),
             cr * a.rng.uniform(0.62, 0.78), 14, 9)
    lay = a._layer(bm)
    y0, y1 = h * 0.3, h
    for v in bm.verts:
        t = clamp01((v.co.y - y0) / (y1 - y0))
        k = 0.62 + 0.38 * t
        v[lay] = (k * (0.95 + 0.1 * t), k, k * (1.05 - 0.15 * t), 1.0)
    a.part("Canopy", bm, leaf, paint=False)
    a.finish(glb, info)


def tree_cone(M, info, glb):
    """Arvore alta arredondada (gota)."""
    a = Asset("Tree_Tall", M, 63)
    bm = bmesh.new()
    gcyl(bm, (0, 0, 0), (0, 1.2, 0), 0.16, 0.12, seg=8)
    a.part("Trunk", bm, "mat_env_trunk", jit=0.1, ao=0.3)
    bm = bmesh.new()
    prof = [(0.0, 0.9)] + [(1.25 * math.sin(math.pi * t / 8) ** 0.8 * (1.0 - 0.45 * t / 8), 0.9 + 5.2 * t / 8)
                           for t in range(1, 8)] + [(0.0, 6.2)]
    lathe(bm, prof, seg=14)
    lay = a._layer(bm)
    for v in bm.verts:
        t = clamp01((v.co.y - 0.9) / 5.3)
        k = 0.6 + 0.4 * t
        v[lay] = (k, k, k, 1.0)
    a.part("Canopy", bm, "mat_env_foliage_b", paint=False)
    a.finish(glb, info)


def rowboat(M, info, glb):
    a = Asset("Rowboat", M, 64)
    bm = bmesh.new()
    lathe(bm, [(0.0, -0.25), (0.35, -0.22), (0.55, 0.0), (0.62, 0.25), (0.6, 0.32), (0.52, 0.3), (0.42, 0.05), (0.0, 0.0)],
          seg=16, sx=1.0, sz=2.6)
    for v in bm.verts:
        if v.co.z < 0:
            v.co.x *= 1.0 - 0.6 * min(1.0, -v.co.z / 1.6)
    a.paint_new(bm, set(), jit=0.03, ao=0.3, tint=(1.0, 1.0, 1.0))
    lay = a._layer(bm)
    for v in bm.verts:
        c = v[lay]
        if v.co.y > 0.2 or (v.co.y > -0.05 and abs(v.co.x) < 0.5 and abs(v.co.z) < 1.25):
            v[lay] = (c[0], c[1] * 0.97, c[2] * 0.92, 1.0)
        else:
            v[lay] = (c[0] * 0.91, c[1] * 0.4, c[2] * 0.29, 1.0)
    a.part("Hull", bm, "mat_env_tint", paint=False)
    bm = bmesh.new()
    for z in (-0.5, 0.4):
        gbox(bm, (0, 0.18, z), (1.0, 0.06, 0.28))
    a.part("Seats", bm, "mat_env_wood_light", bevel=0.01, bseg=1, jit=0.1, ao=0.2)
    a.finish(glb, info)


def bunting(M, info, glb):
    """Bandeirolas: cordao de 8 m em catenaria (pontas em x=+-4, y=0), 14 bandeirinhas coloridas."""
    a = Asset("Bunting", M, 65)
    bm = bmesh.new()

    def py(x):
        return -0.8 * (1 - (x / 4.0) ** 2)
    sweep(bm, [(-4 + 8 * i / 16, py(-4 + 8 * i / 16), 0) for i in range(17)], 0.015, seg=4)
    a.part("Cord", bm, "mat_env_trim", jit=0.0, ao=0.0)
    bf = bmesh.new()
    lay = a._layer(bf)
    cols = [(0.91, 0.4, 0.29), (1.0, 0.82, 0.25), (0.23, 0.48, 0.84), (0.49, 0.8, 0.29), (1.0, 0.98, 0.95)]
    for i in range(14):
        x = -3.7 + 7.4 * i / 13
        y = py(x)
        v1 = bf.verts.new((x - 0.17, y, 0))
        v2 = bf.verts.new((x + 0.17, y, 0))
        v3 = bf.verts.new((x, y - 0.38, 0.02))
        bf.faces.new((v1, v2, v3))
        for v in (v1, v2, v3):
            c = cols[i % len(cols)]
            v[lay] = (c[0], c[1], c[2], 1.0)
    a.part("Flags", bf, "mat_env_tint", paint=False, smooth=False, solid=0.015)
    a.finish(glb, info)


HOUSES = [
    # nome, w, d, andares, parede, telhado, tipo, extras
    ("House_A", 4.2, 5.0, 2, "peach", "terracotta", "gable", dict(seed=101)),
    ("House_B", 5.0, 5.0, 2, "mint", "blue", "hip", dict(seed=102, awning=("mat_env_awning_red", "mat_env_awning_cream"))),
    ("House_C", 5.2, 5.6, 3, "sky", "terracotta", "gable", dict(seed=103, balcony=True, door_x=-1.2)),
    ("House_D", 4.0, 4.4, 1, "lemon", "blue", "gable", dict(seed=104, chimney=True)),
]


def main():
    reset_scene()
    M = village_materials()
    glb = arg_value("--glb-dir", os.path.join(REPO, "game", "assets", "models", "environment"))
    info = {}
    for nm, w, d, fl, wall, roof, kind, kw in HOUSES:
        house(M, info, glb, nm, w, d, fl, wall, roof, kind, **kw)
    market_stall(M, info, glb, "Market_Stall_Red", ("mat_env_awning_red", "mat_env_awning_cream"), 201)
    market_stall(M, info, glb, "Market_Stall_Blue", ("mat_env_awning_blue", "mat_env_awning_cream"), 202)
    street_lamp(M, info, glb)
    park_bench(M, info, glb)
    flower_bed(M, info, glb)
    flower_clump(M, info, glb)
    fence(M, info, glb)
    stone_stairs(M, info, glb)
    low_wall(M, info, glb)
    quay_block(M, info, glb)
    plaza_tile(M, info, glb)
    lawn_block(M, info, glb)
    terrace_wall(M, info, glb)
    lighthouse(M, info, glb)
    hills(M, info, glb, "Hills_Near", 120.0, 30.0, 16.0, (0.42, 0.72, 0.3), (0.32, 0.62, 0.42), 70)
    hills(M, info, glb, "Hills_Far", 260.0, 30.0, 34.0, (0.55, 0.7, 0.72), (0.7, 0.8, 0.9), 71, nx=48, nz=6)
    cloud(M, info, glb)
    seagull(M, info, glb)
    tree_round(M, info, glb, "Tree_Round", 4.6, 62)
    tree_round(M, info, glb, "Tree_Round_Dark", 3.8, 66, lumps=4, leaf="mat_env_foliage_b")
    tree_cone(M, info, glb)
    rowboat(M, info, glb)
    bunting(M, info, glb)
    blend = arg_value("--blend", os.path.join(REPO, "source_art", "environment", "village_kit.blend"))
    save_all(blend, info, os.path.splitext(blend)[0] + ".info.json")


main()
