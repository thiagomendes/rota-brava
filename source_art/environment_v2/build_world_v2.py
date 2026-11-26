"""Rota Brava · Mundo v2 (RB-R1 W1) · vitrine "vila e cais v2". PROVISORIO ate aprovacao de Thiago.

Gera, do zero e de forma reproduzivel (sementes fixas), o recorte do porto Farol 7 refeito no acabamento D11:
  - texturas procedurais ladrilhaveis  -> game/assets/textures/environment_v2/*.jpg|png   (wv2_textures.py)
  - cenario fixo (cais, cais de pedra, ruas, casas, praca, margem, morros, farol), agrupado por material
                                       -> game/assets/models/environment_v2/wv2_static.glb
  - kit de aderecos e vegetacao        -> game/assets/models/environment_v2/wv2_kit.glb   (MultiMesh na Godot)
  - disposicao (instancias, luzes, vistas, percurso) -> game/lookdev/world_v2/world_v2_layout.json
  - info (triangulos, materiais, medidas)            -> source_art/environment_v2/world_v2.info.json
  - fonte .blend                                     -> source_art/environment_v2/world_v2.blend
Mapa: o mesmo referencial do Ep01 (harbor_layout.json / LAYOUT_PROPOSTO.md): cais de madeira x -8..8, z -3..3, topo
y = 0; agua em y = -0,4; cais de pedra norte em z -13; casas da orla com fachada em z ~ -17,8; cais oeste em x -14;
praca x -38..-22; margem sul z > 3; farol em (31, 2,4, -24).

Uso: bash tools/blender.sh --background --factory-startup --python source_art/environment_v2/build_world_v2.py -- [--no-tex] [--renders]
"""
import json
import math
import os
import random
import sys
import time

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
REPO = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import build_boat_wv2 as BOAT  # noqa: E402
import wv2_houses as HS  # noqa: E402
import wv2_kit as KIT  # noqa: E402
import wv2_textures as TX  # noqa: E402
import wv3_collision as COL  # noqa: E402
import wv3_glb  # noqa: E402
import wv3_world as W3  # noqa: E402
from wv2lib import MB, R, T, hexc, lin  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
TEX_DIR = os.path.join(REPO, "game", "assets", "textures", "environment_v2")
GLB_DIR = os.path.join(REPO, "game", "assets", "models", "environment_v2")
LAYOUT_JSON = os.path.join(REPO, "game", "lookdev", "world_v2", "world_v2_layout.json")
INFO_JSON = os.path.join(SCRIPT_DIR, "world_v2.info.json")
BLEND = os.path.join(SCRIPT_DIR, "world_v2.blend")

# Cor de referencia de cada material (so para o .blend e a imagem da malha; na Godot vem da textura).
MAT_PREVIEW = {
    "wv2_deck": "#C9A57A", "wv2_wood": "#B08660", "wv2_paint": "#EDEDED", "wv2_slats": "#E0E0E0", "wv2_plaster": "#F2F2F2",
    "wv2_stone": "#B4AEBF", "wv2_cobble": "#B5AEA6", "wv2_roof": "#E8E0D8", "wv2_canvas": "#FBF4E4", "wv2_metal": "#DDDDDD",
    "wv2_rope": "#D6BF85", "wv2_net": "#9C9C9C", "wv2_bark": "#7A5636", "wv2_leaf": "#5DB043", "wv2_grass": "#6DBA48",
    "wv2_rock": "#A9A3B8", "wv2_terrain": "#7CB850", "wv2_glass": "#355A78", "wv2_glass_lit": "#FFD9A0", "wv2_lamp": "#FFE3A6",
    "wv2_glossy": "#FFFFFF", "wv2_paw": "#5A3B2A", "wv2_burlap": "#C8A878", "wv2_interior": "#E8D8C0",
    "wv2_interior_lit": "#FFD9A0", "wv2_paper": "#FFD9A0", "wv2_beam": "#FFF2C0",
}

PAL = {
    "peach": hexc("#FFBE94"), "mint": hexc("#A9E5C6"), "sky": hexc("#AED8FF"), "lemon": hexc("#FFE38A"),
    "rose": hexc("#FFB8C8"), "cream": hexc("#FFF0D6"), "coral": hexc("#FF9E7E"), "lilac": hexc("#CDBDF2"),
    "terracotta": hexc("#E0703F"), "blue": hexc("#3F7FD8"), "teal": hexc("#2F9C95"), "navy": hexc("#2E4F7A"),
    "green": hexc("#3E9A57"), "red": hexc("#D9473A"), "yellow": hexc("#F2B632"),
}

# E3 (peso, D18): simplificacao por objeto (wv2lib.MB.lod). Medido nas 4 vistas baixas: sem diferenca visivel.
LOD = {"wv2_back": 2, "wv2_street": 1, "wv2_plaza": 1}

lights = []      # (tipo, (x, y, z))
bank_info = {}
houses = []      # (pos, ry, W, D, H) de cada casa: colisao do mundo jogavel (E3)


def build_house(m, pos, ry, p, seed, lights_):
    H = HS.build_house(m, pos, ry, p, seed, lights_)
    houses.append((tuple(pos), ry, p["W"], p["D"], H))
    return H
inst = {}        # kit -> lista de [x, y, z, ry, escala]


def put(kind, x, y, z, ry=0.0, s=1.0):
    inst.setdefault(kind, []).append([round(x, 3), round(y, 3), round(z, 3), round(ry, 2), round(s, 3)])


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    return sc


def materials():
    mats = {}
    for name, h in MAT_PREVIEW.items():
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        c = lin(hexc(h)) + (1.0,)
        b.inputs["Base Color"].default_value = c
        b.inputs["Roughness"].default_value = 0.8
        m.diffuse_color = c
        m["provisional"] = True
        mats[name] = m
    return mats


# ================================================================== cais de madeira
def build_dock():
    m = MB("wv2_dock")
    rng = random.Random(7)
    # tabuas ao longo de z, 0,2 m de passo, cada fiada partida em duas tabuas com emenda desencontrada
    x = -7.9
    k = 0
    while x < 7.95:
        cut = rng.uniform(-1.6, 1.6)
        tone = rng.uniform(0.9, 1.06)
        for z0, z1 in ((-3.0, cut - 0.005), (cut + 0.005, 3.0)):
            L = z1 - z0
            dy = rng.uniform(-0.004, 0.004)
            m.box((x, -0.025 + dy, (z0 + z1) / 2), (0.188, 0.05, L), "wv2_deck", (tone, tone, tone), 0.008, 1,
                  rot=R(rx=rng.uniform(-0.15, 0.15), rz=rng.uniform(-0.6, 0.6)), grain="z",
                  uvoff=(rng.uniform(0, 2), 0.1 + 0.2 * rng.randint(0, 9)), rng=rng)
        x += 0.2
        k += 1
    for z in (-2.7, -0.9, 0.9, 2.7):
        m.box((0, -0.16, z), (16.2, 0.2, 0.14), "wv2_wood", hexc("#9C7A55"), 0.015, 1, rng=rng)
    xs = [-7.8, -5.2, -2.6, 0.0, 2.6, 5.2, 7.8]
    for x in xs:
        m.box((x, -0.36, 0), (0.18, 0.2, 6.2), "wv2_wood", hexc("#8E6E4E"), 0.015, 1, grain="z", rng=rng)
        for z in (-2.95, 0.0, 2.95):
            m.cyl((x, -2.8, z), 0.15, 2.55, "wv2_wood", hexc("#8A6A4A"), seg=12, uvrot=math.pi / 2, rng=rng)
            # cracas/limo na linha d'agua
            m.lathe((x, -0.62, z), [(0.155, -0.1), (0.168, 0.0), (0.155, 0.12)], "wv2_rock", hexc("#5E7A58"), seg=12, rng=rng)
    # fascia
    m.box((0, -0.12, -3.03), (16.12, 0.28, 0.06), "wv2_wood", hexc("#A88560"), 0.012, 1, rng=rng)
    for s in (-1, 1):
        m.box((s * 8.03, -0.12, 0), (0.06, 0.28, 6.12), "wv2_wood", hexc("#A88560"), 0.012, 1, grain="z", rng=rng)
    # postes de amarracao altos no lado norte, com corda enrolada e chapeu
    posts = [-7.6, -3.9, 3.9, 7.6]
    for x in posts:
        z = -3.12
        m.cyl((x, -2.8, z), 0.17, 3.58, "wv2_wood", hexc("#A07A56"), seg=14, uvrot=math.pi / 2, rng=rng)
        m.lathe((x, 0.78, z), [(0.175, 0.0), (0.16, 0.06), (0.09, 0.12), (0.0, 0.14)], "wv2_wood", hexc("#8E6A48"), seg=14, rng=rng)
        for y in (0.42, 0.5, 0.58):
            ring = [(x + math.sin(a) * 0.185, y + 0.012 * math.sin(a * 3), z + math.cos(a) * 0.185) for a in
                    [i / 20 * 6.2832 for i in range(21)]]
            m.tube(ring, 0.022, "wv2_rope", hexc("#D9C38B"), seg=6, caps=False)
    # cabos entre postes (catenaria)
    for a, b in zip(posts[:-1], posts[1:]):
        if a < 0 < b:
            continue
        pts = []
        for i in range(17):
            t = i / 16
            pts.append((a + (b - a) * t, 0.55 - 0.22 * math.sin(math.pi * t), -3.12))
        m.tube(pts, 0.018, "wv2_rope", hexc("#D9C38B"), seg=6)
    # postes baixos de canto no lado sul (onde o cais encontra a margem)
    for x in (-7.85, 7.85):
        m.cyl((x, -1.2, 3.0), 0.15, 2.0, "wv2_wood", hexc("#A07A56"), seg=12, uvrot=math.pi / 2, rng=rng)
        m.lathe((x, 0.8, 3.0), [(0.155, 0.0), (0.14, 0.05), (0.07, 0.1), (0.0, 0.11)], "wv2_wood", hexc("#8E6A48"), seg=12, rng=rng)
    # escada oeste (para a agua, ~(-7, 0, 2)) e escada norte
    def ladder(x0, z0, along_z):
        for s in (-0.26, 0.26):
            px, pz = (x0, z0 + s) if along_z else (x0 + s, z0)
            m.box((px, -0.55, pz), (0.07, 2.7, 0.07), "wv2_wood", hexc("#9C7A55"), 0.012, 1, grain="y", rng=rng)
            m.tube([(px, 0.75, pz), (px + (0.12 if along_z else 0) * (-1 if x0 < 0 else 1), 0.86, pz + (0 if along_z else -0.12))],
                   0.035, "wv2_metal", hexc("#3B3F44"), seg=8)
        for k in range(8):
            y = 0.55 - k * 0.3
            if along_z:
                m.cyl((x0, y, z0 - 0.26), 0.022, 0.52, "wv2_metal", hexc("#5A6066"), rot=R(rx=90), seg=8)
            else:
                m.cyl((x0 - 0.26, y, z0), 0.022, 0.52, "wv2_metal", hexc("#5A6066"), rot=R(rz=-90), seg=8)
    ladder(-8.13, 2.0, True)
    ladder(4.6, -3.13, False)
    for x in (-6.0, -2.0, 2.0, 6.0):
        put("fender", x, -0.05, -3.12, 0.0)
    put("fender", 0.0, -0.05, -3.12, 0.0)
    put("life_ring", -3.9, 0.0, -2.88, 0.0)
    put("lamp_post", -7.55, 0.0, 2.6, 0.0)
    put("lamp_post", 7.55, 0.0, 2.6, 0.0)
    # aderecos no cais (area dos herois livre: x -4..1, z -1.5..2.5)
    for (x, z, ry) in ((-6.6, -1.9, 8), (-6.0, -1.95, -5), (-6.3, -1.3, 12)):
        put("crate", x, 0, z, ry)
    put("crate_dark", -6.35, 0.6, -1.85, 20, 0.9)
    put("net_pile", -6.4, 0.0, 0.3, 30)
    put("float_buoy", -5.6, 0.0, 0.9, 0)
    put("float_buoy", -5.9, 0.0, 1.25, 0)
    put("rope_coil", -4.6, 0.0, -2.45, 40)
    put("bucket", -5.0, 0.0, 2.35, 0)
    put("barrel", 5.7, 0.0, 1.9, 0)
    put("barrel_lid", 6.4, 0.0, 2.3, 30)
    put("barrel", 6.35, 0.0, 1.55, 70)
    put("lobster_trap", 6.1, 0.0, -1.5, 80)
    put("lobster_trap", 6.15, 0.36, -1.45, 95)
    put("lobster_trap", 6.9, 0.0, -0.6, 10)
    put("crate_fish", 2.6, 0.0, -2.3, 5)
    put("crate_fish", 3.3, 0.0, -2.35, -8, 0.95)
    put("rope_coil", 1.6, 0.0, 2.4, 160)
    put("sack", 5.2, 0.0, 0.5, 20)
    put("sack", 5.6, 0.0, 0.2, 70)
    put("bench", 3.0, 0.0, 2.6, 180)
    put("pot_a", -4.6, 0.0, 2.75, 0)
    put("pot_b", 1.9, 0.0, 2.75, 0)
    # cantos de baixo do quadro da camera do cais: aderecos que enchem o chao sem tapar os herois
    put("crate", -5.4, 0.0, 1.9, 15)
    put("crate_fruit", -5.3, 0.6, 1.95, 8, 0.85)
    put("crate", -6.05, 0.0, 2.3, -10)
    put("barrel", -4.85, 0.0, 1.0, 0)
    put("rope_coil", -4.2, 0.0, 1.9, 75)
    put("lobster_trap", 1.9, 0.0, 1.6, -70)
    put("crate_fish", 2.3, 0.0, 0.55, 12)
    put("bucket", 1.35, 0.0, 0.45, 0)
    put("net_pile", 1.2, 0.0, 3.0, 20, 0.85)
    put("crate", 2.1, 0.0, -0.5, -12)
    put("crate", 2.75, 0.0, -0.4, 6)
    put("crate_dark", 2.4, 0.6, -0.45, 30, 0.9)
    put("barrel", 1.3, 0.0, -1.7, 0)
    put("float_buoy", 0.9, 0.0, -1.3, 0)
    W3.dock_loose_rope(m)   # E3, M1: amarra vazia do bote do capitao
    return m


# ================================================================== cais de pedra, ruas, praca
def coping_run(m, a, b, fixed, along_x, rng, face_out):
    L = abs(b - a)
    n = int(L / 0.9)
    step = L / n
    for i in range(n):
        c = min(a, b) + (i + 0.5) * step
        w = step - 0.03
        h = 0.24
        tone = rng.uniform(0.92, 1.05)
        if along_x:
            m.box((c, -0.12, fixed - face_out * 0.22), (w, h, 0.56), "wv2_stone", (tone,) * 3, 0.035, 2, rng=rng)
        else:
            m.box((fixed - face_out * 0.22, -0.12, c), (0.56, h, w), "wv2_stone", (tone,) * 3, 0.035, 2, grain="z", rng=rng)


def build_quay():
    m = MB("wv2_quay")
    rng = random.Random(11)
    # paredes de pedra (face para a agua)
    m.box((6.0, -1.6, -13.5 - 0.0), (40.0, 2.4, 1.0), "wv2_stone", (1, 1, 1), 0.0, 1, uv="world", uvoff=(0, 0))
    m.box((-14.5, -1.6, -5.0), (1.0, 2.4, 16.0), "wv2_stone", (1, 1, 1), 0.0, 1, uv="world", uvoff=(0, 0))
    coping_run(m, -14.0, 26.0, -13.0, True, rng, 1)
    coping_run(m, -13.0, 3.0, -14.0, False, rng, 1)
    # fim leste do cais norte
    m.box((26.3, -1.3, -16.0), (0.6, 2.6, 6.5), "wv2_stone", (1, 1, 1), 0.0, 1, uv="world", uvoff=(0, 0))
    # calcamento (topo y = 0): rua norte, cais oeste, praca, sob as casas
    m.box((2.0, -0.2, -21.6), (48.0, 0.4, 17.0), "wv2_cobble", (1, 1, 1), 0.0, 1, uv="world", uvoff=(0, 0))
    m.box((-26.2, -0.2, -2.0), (24.4, 0.4, 22.0), "wv2_cobble", (1, 1, 1), 0.0, 1, uv="world", uvoff=(0.5, 0.3))
    m.box((-37.0, -0.2, -26.0), (14.0, 0.4, 26.0), "wv2_cobble", (1, 1, 1), 0.0, 1, uv="world", uvoff=(0.5, 0.3))
    # meio-fio de pedra separando a pista calcada da faixa junto as casas (rua com dois planos de leitura)
    for x0, x1 in ((-14.0, 26.0),):
        n = int((x1 - x0) / 0.8)
        for i in range(n):
            c = x0 + (i + 0.5) * (x1 - x0) / n
            m.box((c, 0.0, -16.6), ((x1 - x0) / n - 0.02, 0.06, 0.3), "wv2_stone", (rng.uniform(0.9, 1.05),) * 3, 0.02, 1, rng=rng)
    # muro de arrimo do terraco (z -23, topo 1,2) + calcamento do terraco
    m.box((2.0, 0.6, -23.4), (48.0, 1.2, 0.8), "wv2_stone", (1, 1, 1), 0.0, 1, uv="world", uvoff=(0.3, 0))
    m.box((2.0, 1.0, -30.0), (52.0, 0.4, 13.0), "wv2_cobble", (1, 1, 1), 0.0, 1, uv="world", uvoff=(0, 0))
    for i in range(52):
        c = -22.0 + (i + 0.5) * 48.0 / 52
        m.box((c, 1.25, -23.05), (48.0 / 52 - 0.03, 0.12, 0.42), "wv2_stone", (rng.uniform(0.9, 1.05),) * 3, 0.025, 1, rng=rng)
    # escadaria ao terraco (beco leste, x 22,4..25,6)
    for k in range(6):
        y = 0.2 * (k + 1)
        z = -18.6 - k * 0.72
        m.box((24.0, y / 2, z - 0.36), (3.2, y, 0.74), "wv2_stone", (rng.uniform(0.92, 1.04),) * 3, 0.03, 2, rng=rng)
    for s in (22.3, 25.7):
        m.box((s, 0.9, -21.0), (0.3, 1.8, 5.0), "wv2_stone", (1, 1, 1), 0.02, 1, grain="z", uv="world", uvoff=(0, 0))
    # escada de pedra para a agua no cais norte (x 12..13.4)
    for k in range(7):
        y = -0.25 - k * 0.3
        m.box((12.7, y, -12.75 + k * 0.32 + 0.16), (1.3, 0.3, 0.32 + 0.1), "wv2_stone", (rng.uniform(0.85, 1.0),) * 3, 0.025, 2,
              rng=rng)
    # argolas de amarracao na face do cais
    for x in (-8.0, -1.0, 6.0, 16.0, 21.0):
        m.lathe((x, -0.55, -12.98), [(0.0, -0.02), (0.05, -0.02), (0.05, 0.02), (0.0, 0.02)], "wv2_metal", hexc("#3B3F44"), seg=8,
                rot=R(rx=90))
        ring = [(x + math.sin(a) * 0.12, -0.7 + math.cos(a) * 0.12, -12.93) for a in [i / 16 * 6.2832 for i in range(17)]]
        m.tube(ring, 0.018, "wv2_metal", hexc("#3B3F44"), seg=6, caps=False)
    # limo escuro na linha d'agua das paredes
    m.box((6.0, -0.55, -12.98), (40.0, 0.35, 0.02), "wv2_rock", hexc("#4E6A4E"), 0.0, 1, uv="world")
    m.box((-13.98, -0.55, -5.0), (0.02, 0.35, 16.0), "wv2_rock", hexc("#4E6A4E"), 0.0, 1, uv="world")
    return m


# ================================================================== casas
ROW1 = [  # (largura, andares, telhado, parede, telha, extras)
    (5.2, 2, "eave", "peach", "terracotta", dict(ground="shop", icon="fish", awning=PAL["red"], door_color=PAL["navy"],
                                                 shutter=PAL["teal"], chimneys=1)),
    (4.6, 3, "gable", "mint", "blue", dict(balcony=1, door_color=PAL["red"], shutter=PAL["navy"], chimneys=1)),
    (6.0, 2, "eave", "lemon", "terracotta", dict(ground="shop", icon="bread", awning=PAL["blue"], door_color=PAL["teal"],
                                                 shutter=PAL["blue"], chimneys=2)),
    (5.0, 3, "eave", "sky", "terracotta", dict(balcony=1, door_color=PAL["yellow"], shutter=PAL["green"], chimneys=1)),
    (5.6, 2, "gable", "rose", "terracotta", dict(ground="shop", icon="flower", awning=PAL["green"], door_color=PAL["green"],
                                                 shutter=PAL["teal"], chimneys=1)),
    (4.8, 3, "eave", "coral", "blue", dict(door_color=PAL["navy"], shutter=PAL["navy"], chimneys=1, balcony=2)),
    (6.2, 2, "eave", "cream", "terracotta", dict(ground="shop", icon="cup", awning=PAL["yellow"], door_color=PAL["red"],
                                                 shutter=PAL["red"], chimneys=2)),
]


def house_params(w, floors, roof, wall, roofc, extra, detail=2):
    p = dict(W=w, D=5.0, floors=floors, roof=roof, wall=PAL[wall], roof_col=PAL[roofc], detail=detail)
    p.update(extra)
    return p


def build_street():
    m = MB("wv2_street")
    m.lod = LOD.get("wv2_street", 0)
    rng = random.Random(21)
    x = -15.5
    fronts = []
    for i, (w, fl, roof, wall, roofc, extra) in enumerate(ROW1):
        z = -17.8 + rng.uniform(-0.18, 0.18)
        p = house_params(w, fl, roof, wall, roofc, extra)
        build_house(m, (x, 0, z), 0, p, 100 + i, lights)
        fronts.append((x, w, z, fl, p))
        x += w
    # casa de esquina (fecha a praca ao norte)
    p0 = house_params(7.7, 3, "eave", "lilac", "terracotta", dict(door_color=PAL["teal"], shutter=PAL["navy"], chimneys=2,
                                                                  cols=4, balcony=1, balcony_col=2))
    build_house(m, (-29.5, 0, -17.8), 0, p0, 99, lights)
    # cata-vento com bussola na cumeeira da padaria (missoes v3, M5)
    hx, hw = fronts[2][0], fronts[2][1]
    weathervane(m, hx + hw * 0.62, 6.0 + 2.5 * math.tan(math.radians(34.0)) + 0.1, fronts[2][2] - 2.5)
    # galpao baixo de redes (subida do Pico: caixotes 0,6 -> toldo 1,6 -> laje 2,8 m, topo plano)
    build_shed(m, rng)
    # muro do quintal entre o galpao e a primeira casa, com portao
    for xx in (-17.45, -15.65):
        m.box((xx, 1.1, -17.65), (0.3, 2.2, 0.3), "wv2_stone", (1, 1, 1), 0.02, 1, grain="y", rng=rng)
        m.lathe((xx, 2.2, -17.65), [(0.2, 0.0), (0.2, 0.06), (0.1, 0.16), (0.0, 0.2)], "wv2_stone", (1, 1, 1), seg=8)
    m.box((-16.55, 0.95, -17.7), (1.5, 1.8, 0.05), "wv2_paint", PAL["teal"], 0.01, 1, grain="y", rng=rng)
    put("tree_c", -16.6, 0.0, -20.0, 40, 1.05)
    return m, fronts


def weathervane(m, x, y, z):
    iron, gold = hexc("#2B2F33"), hexc("#C9A13A")
    m.lathe((x, y, z), [(0.12, 0.0), (0.1, 0.06), (0.03, 0.1), (0.0, 0.1)], "wv2_metal", iron, seg=10)
    m.cyl((x, y, z), 0.018, 1.25, "wv2_metal", iron, seg=8)
    # rosa dos ventos: quatro bracos com ponta em seta e bola no centro
    for k in range(4):
        a = k * 90.0
        m.box((x, y + 0.7, z), (0.62, 0.018, 0.018), "wv2_metal", iron, 0.0, 1, rot=R(ry=a) @ T(0.31, 0, 0))
        m.prism((x, y + 0.7, z), [(0.6, 0.05), (0.72, 0.0), (0.6, -0.05)], 0.02, "wv2_metal", gold, rot=R(ry=a, rx=90))
    m.sphere((x, y + 0.7, z), 0.05, "wv2_metal", gold, subd=1)
    # seta com rabo (gira com o vento) e bola no topo
    m.box((x, y + 1.05, z), (0.8, 0.02, 0.02), "wv2_metal", iron, 0.0, 1, rot=R(ry=30))
    m.prism((x, y + 1.05, z), [(0.38, 0.07), (0.52, 0.0), (0.38, -0.07)], 0.02, "wv2_metal", gold, rot=R(ry=30))
    m.prism((x, y + 1.05, z), [(-0.42, 0.0), (-0.28, 0.13), (-0.2, 0.13), (-0.28, 0.0), (-0.2, -0.0)], 0.02, "wv2_metal", gold,
            rot=R(ry=30))
    m.sphere((x, y + 1.27, z), 0.04, "wv2_metal", gold, subd=1)


def build_shed(m, rng):
    x0, x1, z0, z1, h = -21.7, -17.6, -22.8, -14.8, 2.8
    # paredes de reboco sobre embasamento de pedra; laje com mureta baixa so atras (topo plano livre >= 1,5 m)
    m.box(((x0 + x1) / 2, 0.3, (z0 + z1) / 2), (x1 - x0 + 0.06, 0.6, z1 - z0 + 0.06), "wv2_stone", (1, 1, 1), 0.0, 1, uv="world")
    m.box(((x0 + x1) / 2, h / 2, (z0 + z1) / 2), (x1 - x0, h, z1 - z0), "wv2_plaster", PAL["sky"], 0.0, 1, uv="world")
    m.box(((x0 + x1) / 2, h + 0.06, (z0 + z1) / 2), (x1 - x0 + 0.24, 0.12, z1 - z0 + 0.24), "wv2_stone", (1, 1, 1), 0.03, 2,
          uv="world")
    m.box(((x0 + x1) / 2, h + 0.26, z0 + 0.15), (x1 - x0 + 0.24, 0.3, 0.3), "wv2_stone", (1, 1, 1), 0.03, 1, uv="world")
    # portao de tabuas na frente (sul), recuado
    cx = (x0 + x1) / 2
    m.box((cx, 1.15, z1 + 0.005), (2.2, 2.3, 0.04), "wv2_paint", PAL["blue"], 0.0, 1, grain="y")
    for k in range(2):
        m.box((cx - 0.55 + k * 1.1, 1.15, z1 + 0.04), (1.0, 2.2, 0.05), "wv2_paint", PAL["blue"], 0.01, 1, grain="y")
        m.box((cx - 0.55 + k * 1.1, 1.15, z1 + 0.07), (1.0, 0.1, 0.03), "wv2_paint", PAL["blue"], 0.01, 1, rot=R(rz=60))
    m.box((cx, 2.45, z1 + 0.06), (2.5, 0.18, 0.12), "wv2_wood", hexc("#9C7A55"), 0.015, 1)
    # placa "redes" com peixe
    m.box((cx, 2.62, z1 + 0.1), (1.3, 0.3, 0.05), "wv2_paint", hexc("#FFF0D0"), 0.012, 1)
    m.sphere((cx - 0.1, 2.62, z1 + 0.14), 0.13, "wv2_glossy", PAL["navy"], subd=2, scale=(1, 0.42, 0.2))
    m.prism((cx + 0.1, 2.62, z1 + 0.14), [(0, 0), (0.1, 0.08), (0.1, -0.08)], 0.02, "wv2_glossy", PAL["navy"])
    # janelinha lateral (leste) e boias penduradas
    m.box((x1 + 0.02, 1.6, -17.2), (0.05, 0.7, 0.8), "wv2_glass", (1, 1, 1), 0.0, 1)
    for k in range(3):
        put("float_buoy", x1 + 0.22, 0.85 + k * 0.42, -18.2 + k * 0.35, 0, 0.8)
    # toldo da barraca encostada (x -17,6..-15,7; topo 1,6 m), mesa com peixe
    ax0, ax1, az0, az1 = -17.6, -15.7, -17.4, -14.8
    for px in (ax1 - 0.05,):
        for pz in (az1 + 0.05, az0 + 0.6):
            m.box((px, 0.78, pz), (0.08, 1.56, 0.08), "wv2_wood", hexc("#B48A60"), 0.015, 1, grain="y", rng=rng)
    m.box(((ax0 + ax1) / 2, 1.58, (az0 + az1) / 2), (ax1 - ax0 + 0.1, 0.05, az1 - az0 + 0.1), "wv2_wood", hexc("#9C7A55"),
          0.01, 1, rot=R(rz=-4), rng=rng)
    m.box(((ax0 + ax1) / 2, 1.62, (az0 + az1) / 2), (ax1 - ax0 + 0.2, 0.03, az1 - az0 + 0.2), "wv2_canvas", PAL["red"], 0.0, 1,
          rot=R(rz=-4), uvrot=math.pi / 2)
    n = 8
    for k in range(n):
        zk = az1 + 0.1 - (k + 0.5) * (az1 - az0 + 0.2) / n
        poly = [(-0.5, 0), (0.5, 0)] + [(math.cos(a) * 0.5, -0.45 * math.sin(a)) for a in [math.pi * q / 6 for q in range(1, 6)]]
        poly = [(zk + px * (az1 - az0 + 0.2) / n, 1.55 + py * 0.36) for px, py in poly]
        m.prism((ax1 + 0.1, 0, 0), [(-a, b) for a, b in poly], 0.02, "wv2_canvas", PAL["red"], rot=R(ry=90), uvoff=(k * 0.125, 0))
    m.box(((ax0 + ax1) / 2 + 0.1, 0.82, (az0 + az1) / 2), (1.3, 0.06, 2.0), "wv2_wood", hexc("#C79A6A"), 0.015, 1, grain="z", rng=rng)
    for (dx, dz) in ((-0.5, -0.8), (0.6, -0.8), (-0.5, 0.8), (0.6, 0.8)):
        m.box(((ax0 + ax1) / 2 + 0.1 + dx, 0.4, (az0 + az1) / 2 + dz), (0.06, 0.8, 0.06), "wv2_wood", hexc("#A07A52"), 0.01, 1,
              grain="y", rng=rng)
    put("crate_fish", -16.55, 0.85, -16.6, 90, 0.85)
    put("crate_fish", -16.55, 0.85, -15.6, 95, 0.85)
    # caixotes de 0,6 m (primeiro degrau); E3b: recuados para liberar a passagem da praca para a rua (W3.PICO_CRATES)
    for (cx_, cz_, ry) in W3.PICO_CRATES:
        put("crate", cx_, 0.0, cz_, ry)
    put("barrel_lid", -18.0, 0.0, -14.4, 0)
    put("net_pile", -20.6, 0.0, -14.2, -10, 0.8)


def build_plaza():
    m = MB("wv2_plaza")
    m.lod = LOD.get("wv2_plaza", 0)
    rng = random.Random(31)
    specs = [  # (z da borda norte (local x = 0 fica no z maior), largura, andares, telhado, parede, telha, extras)
        (-10.5, 5.5, 3, "eave", "mint", "terracotta", dict(door_color=PAL["red"], shutter=PAL["navy"], balcony=1, chimneys=1)),
        (-4.3, 6.0, 2, "gable", "peach", "blue", dict(ground="shop", icon="bread", awning=PAL["green"], door_color=PAL["green"],
                                                     shutter=PAL["green"], chimneys=1)),
        (0.9, 5.0, 3, "eave", "lemon", "terracotta", dict(door_color=PAL["blue"], shutter=PAL["blue"], chimneys=1, balcony=2)),
        (7.6, 6.5, 2, "eave", "rose", "terracotta", dict(ground="shop", icon="flower", awning=PAL["blue"], door_color=PAL["navy"],
                                                         shutter=PAL["teal"], chimneys=2)),
    ]
    for i, (z, w, fl, roof, wall, roofc, extra) in enumerate(specs):
        x = -30.0 + rng.uniform(-0.15, 0.15)
        build_house(m, (x, 0, z), 90, house_params(w, fl, roof, wall, roofc, extra), 200 + i, lights)
    # chafariz com degraus 0,5/1,0/1,5, bacia superior, canaleta e grade (E3, M3) e placas de fruta nas barracas (M4)
    W3.fountain(m, random.Random(33))
    W3.stall_icons(m, random.Random(34))
    tx, tz = -24.0, -4.0
    put("tree_a", tx, 0.0, tz, 15, 1.2)
    m.lathe((tx, 0, tz), [(0.0, 0.0), (1.0, 0.0), (1.0, 0.3), (0.0, 0.3)], "wv2_stone", (1, 1, 1), seg=24)
    for k in range(10):
        a = k / 10 * 2 * math.pi
        r = 1.35
        m.box((tx + math.cos(a) * r, 0.45, tz + math.sin(a) * r), (0.75, 0.05, 0.4), "wv2_wood", hexc("#C08A55"), 0.012, 1,
              rot=R(ry=-math.degrees(a) + 90), rng=rng)
        m.box((tx + math.cos(a) * 1.32, 0.21, tz + math.sin(a) * 1.32), (0.08, 0.42, 0.3), "wv2_metal", hexc("#2F4A4C"), 0.0, 1,
              rot=R(ry=-math.degrees(a) + 90))
    # canteiros de flores com borda de pedra
    for (cx, cz, w, d) in ((-21.0, -11.6, 2.4, 0.9), (-27.2, 9.2, 0.9, 2.4)):
        m.box((cx, 0.15, cz), (w, 0.3, d), "wv2_stone", (1, 1, 1), 0.03, 2, rng=rng)
        m.box((cx, 0.31, cz), (w - 0.2, 0.02, d - 0.2), "wv2_terrain", (0.0, 0.0, 0.0), 0.0, 1)
        for k in range(int(w * d * 5)):
            put(random.Random(k).choice(["flowers_a", "flowers_b", "grass_tuft"]), cx + rng.uniform(-w / 2 + 0.2, w / 2 - 0.2), 0.3,
                cz + rng.uniform(-d / 2 + 0.2, d / 2 - 0.2), rng.uniform(0, 360), rng.uniform(0.9, 1.3))
    return m


def build_row2():
    m = MB("wv2_back")
    m.lod = LOD.get("wv2_back", 0)   # segunda fileira: so aparece ao fundo (>= 8 m da camera baixa)
    rng = random.Random(41)
    specs = [(6.0, 3, "eave", "cream", "blue"), (5.5, 2, "gable", "sky", "terracotta"), (6.5, 3, "eave", "peach", "terracotta"),
             (5.0, 2, "eave", "mint", "terracotta"), (6.0, 3, "gable", "lemon", "blue"), (5.5, 2, "eave", "rose", "terracotta"),
             (6.0, 3, "eave", "lilac", "terracotta")]
    x = -18.0
    for i, (w, fl, roof, wall, roofc) in enumerate(specs):
        p = house_params(w, fl, roof, wall, roofc, dict(chimneys=1, ground="door", shutter=PAL["navy"], flowers=0.3), detail=1)
        build_house(m, (x, 1.2, -24.6 + rng.uniform(-0.3, 0.3)), 0, p, 300 + i, lights)
        x += w + rng.uniform(0.0, 0.4)
    return m


# ================================================================== terreno
def noise2(x, z, seed=0):
    s = 0.0
    for k, (fx, fz, ph, a) in enumerate(((0.11, 0.07, 1.3, 0.5), (0.23, -0.19, 2.1, 0.25), (-0.47, 0.41, 0.7, 0.12),
                                         (0.93, 0.77, 4.1, 0.06))):
        s += math.sin(x * fx + z * fz + ph + seed) * math.cos(x * fz * 0.7 - z * fx * 1.3 + ph * 0.5) * a
    return s


PATH = [(0.0, 2.6), (-0.6, 4.6), (-2.6, 7.6), (-6.0, 10.0), (-9.5, 9.6), (-12.0, 8.6), (-14.6, 8.2)]
PATH2 = [(0.0, 2.6), (2.4, 5.4), (5.8, 7.8), (9.5, 8.6)]


def dist_poly(x, z, pts):
    best = 9e9
    for (ax, az), (bx, bz) in zip(pts[:-1], pts[1:]):
        dx, dz = bx - ax, bz - az
        t = max(0.0, min(1.0, ((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz)))
        best = min(best, math.hypot(x - (ax + dx * t), z - (az + dz * t)))
    return best


def bank_h(x, z):
    # paving region of the plaza / west quay: keep under the stones
    if x < -14.05 and z < 9.4:
        return -0.12
    base = 0.04 * noise2(x, z, 1.0)
    rise = max(0.0, z - 15.0) * 0.32 + max(0.0, z - 26.0) * 0.35
    rise += max(0.0, x - 20.0) * 0.25
    rise += max(0.0, -x - 30.0) * 0.35
    shore = max(0.0, min(1.0, (z - 1.2) / 2.2))
    shore = shore * shore * (3 - 2 * shore)
    if x < -14.0:
        shore = 1.0
    h = base + rise * (1.0 + 0.4 * noise2(x * 0.5, z * 0.5, 3.0))
    if dist_poly(x, z, PATH) < 1.4 or dist_poly(x, z, PATH2) < 1.1:
        h = min(h, 0.02) if z < 16 else h
    return h * shore + (-1.6) * (1 - shore)


def hill_h(x, z):
    d = max(0.0, -z - 31.0)
    h = 1.2 + d * 0.42 + max(0.0, d - 25) * 0.2 + 2.2 * noise2(x * 0.6, z * 0.6, 5.0) * min(1.0, d / 8)
    h += max(0.0, abs(x) - 45) * 0.3
    return h


def head_h(x, z):
    d = math.hypot((x - 31.5) / 1.25, (z + 23.0) / 1.0)
    h = 2.4 - max(0.0, d - 7.0) * 0.45 + 0.25 * noise2(x * 1.4, z * 1.4, 7.0)
    # E3b: o retalho do promontorio comeca em x = 20 sobre a rua (y 0); antes a borda ficava solta ate 0,55 m acima do
    # calcamento (chapa no ar atras do cafe e degrau que travava o heroi em (20; -16)). Agora nasce 2 cm abaixo da rua e
    # sobe no maximo 0,55 m por metro (29 graus, caminhavel). So em x >= 20 (onde ha retalho): pedras a oeste nao mudam.
    if x >= 20.0:
        h = min(h, (x - 20.0) * 0.55 - 0.02)
    return max(-1.8, h)


def west_h(x, z):
    d = max(0.0, -x - 38.5)
    return -0.1 + d * 0.5 + 1.5 * noise2(x * 0.7, z * 0.7, 9.0) * min(1.0, d / 6)


def terrain_patch(m, x0, x1, z0, z1, step, hf, mask, name_seed=0):
    nx = int(round((x1 - x0) / step))
    nz = int(round((z1 - z0) / step))
    bm = bmesh.new()
    vs = []
    for j in range(nz + 1):
        row = []
        for i in range(nx + 1):
            x = x0 + (x1 - x0) * i / nx
            z = z0 + (z1 - z0) * j / nz
            row.append(bm.verts.new((x, hf(x, z), z)))
        vs.append(row)
    for j in range(nz):
        for i in range(nx):
            bm.faces.new((vs[j][i], vs[j + 1][i], vs[j + 1][i + 1], vs[j][i + 1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        if f.normal.y < 0:
            f.normal_flip()
    m.add_bm(bm, Matrix.Identity(4), "wv2_terrain", (1, 1, 1), "none", "x",
             shade=lambda p, w: 1.0)
    # mascaras (R = terra do caminho, G = areia/lama molhada, B = pedra) direto na cor de vertice (sem gama)
    n = sum(1 for _ in range((nx) * (nz)))
    start = len(m.ccol) - n
    for fi in range(start, len(m.ccol)):
        cc = []
        for vi in m.faces[fi]:
            p = m.verts[vi]
            cc.append(mask(p.x, p.y, p.z) + (1.0,))
        m.ccol[fi] = cc


def bank_mask(x, y, z):
    d = min(dist_poly(x, z, PATH) / 1.15, dist_poly(x, z, PATH2) / 0.9)
    path = max(0.0, min(1.0, 1.3 - d)) if z < 16 else 0.0
    wet = max(0.0, min(1.0, (0.15 - y) / 0.5))
    rock = max(0.0, min(1.0, (-y - 0.9) * 1.5))
    return (path, wet, rock)


def hill_mask(x, y, z):
    return (0.0, 0.0, max(0.0, min(1.0, 0.5 * noise2(x * 2.0, z * 2.0, 11.0) - 0.15)))


def head_mask(x, y, z):
    return (0.0, max(0.0, min(1.0, (0.4 - y) / 0.8)), max(0.0, min(1.0, (1.6 - y) * 0.6 + 0.3 * noise2(x * 3, z * 3, 2.0))))


def build_terrain():
    m = MB("wv2_terrain")
    terrain_patch(m, -14.4, 34.0, 1.0, 46.0, 0.5, bank_h, bank_mask)
    terrain_patch(m, -42.0, -14.0, 9.0, 46.0, 1.0, bank_h, bank_mask)
    terrain_patch(m, -80.0, 80.0, -110.0, -31.0, 2.0, hill_h, hill_mask)
    terrain_patch(m, 20.0, 46.0, -36.0, -8.0, 0.75, head_h, head_mask)
    terrain_patch(m, -90.0, -38.0, -40.0, 46.0, 2.0, west_h, hill_mask)
    # fundo do porto
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in ((-60, -2.4, -40), (60, -2.4, -40), (60, -2.4, 6), (-60, -2.4, 6))]
    bm.faces.new((vs[0], vs[3], vs[2], vs[1]))
    m.add_bm(bm, Matrix.Identity(4), "wv2_terrain", (1, 1, 1), "none", "x")
    m.ccol[-1] = [(0.0, 1.0, 0.3, 1.0)] * 4
    return m


def clear_head_path(x, z, rad):
    """E3b: tira uma pedra de raio `rad` do corredor W3.HEAD_PATH (+ ramal da lente), empurrando-a para o lado mais
    proximo ate a borda do corredor. Devolve (None, None) se o novo lugar cair na rua, na casa do faroleiro, no
    embasamento do farol ou de novo no corredor."""
    need = W3.HEAD_PATH_HALF + rad
    moved = False
    for _ in range(3):
        best = None
        for path in (W3.HEAD_PATH, W3.HEAD_PATH_LENS):
            for (ax, az), (bx, bz) in zip(path[:-1], path[1:]):
                dx, dz = bx - ax, bz - az
                t = max(0.0, min(1.0, ((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz)))
                px, pz = ax + dx * t, az + dz * t
                d = math.hypot(x - px, z - pz)
                if d < need and (best is None or d < best[0]):
                    best = (d, px, pz, dx, dz)
        if best is None:
            break
        d, px, pz, dx, dz = best
        if d > 1e-3:
            ux, uz = (x - px) / d, (z - pz) / d
        else:   # em cima da linha: para a esquerda do segmento
            L = math.hypot(dx, dz)
            ux, uz = -dz / L, dx / L
        x, z = px + ux * (need + 0.05), pz + uz * (need + 0.05)
        moved = True
    else:
        return None, None
    if not moved:
        return x, z
    if head_h(x, z) < 0.5 or math.hypot(x - 31.0, z + 24.0) < 3.0 + rad or (27.0 - rad < x < 31.0 + rad and -19.0 - rad < z < -14.6 + rad):
        return None, None
    return x, z


def scatter_vegetation():
    rng = random.Random(55)
    # arvores da margem sul e encosta
    trees = [("tree_a", 5.2, 9.8, 1.0), ("tree_c", 10.5, 12.8, 1.1), ("tree_a", -3.2, 15.5, 1.15), ("tree_b", -12.5, 14.5, 1.0),
             ("tree_a", 15.5, 6.5, 0.95), ("tree_c", 19.0, 15.0, 1.2), ("tree_b", 1.5, 19.5, 1.1), ("tree_a", -8.0, 19.0, 1.25),
             ("tree_c", -17.5, 12.5, 1.0), ("tree_a", 24.0, 10.0, 1.3), ("tree_b", 13.0, 21.0, 1.2), ("tree_a", -22.0, 16.0, 1.2)]
    for k, x, z, s in trees:
        put(k, x, bank_h(x, z), z, rng.uniform(0, 360), s)
    for i in range(70):
        x = rng.uniform(-36, 34)
        z = rng.uniform(22, 44)
        put(rng.choice(["tree_a", "tree_b", "tree_c", "tree_a"]), x, bank_h(x, z) - 0.1, z, rng.uniform(0, 360), rng.uniform(1.0, 1.6))
    # morro norte (atras da segunda fileira)
    for i in range(190):
        x = rng.uniform(-75, 75)
        z = rng.uniform(-105, -33)
        if -33 > z > -38 and abs(x) < 26:
            continue
        put(rng.choice(["tree_a", "tree_b", "tree_a", "tree_c"]), x, hill_h(x, z) - 0.15, z, rng.uniform(0, 360), rng.uniform(1.1, 2.0))
    for i in range(45):
        x = rng.uniform(-85, -42)
        z = rng.uniform(-38, 44)
        put(rng.choice(["tree_a", "tree_b"]), x, west_h(x, z) - 0.1, z, rng.uniform(0, 360), rng.uniform(1.1, 1.8))
    # arbustos e flores ao longo do caminho e da praia
    for i in range(70):
        x = rng.uniform(-14, 30)
        z = rng.uniform(4.0, 22)
        if dist_poly(x, z, PATH) < 1.8 or dist_poly(x, z, PATH2) < 1.5 or (abs(x) < 8.5 and z < 4.2):
            continue
        if math.hypot(x + 10.6, z - 5.2) < 2.6:   # bote virado livre
            continue
        put(rng.choice(["bush_a", "bush_b", "bush_c", "bush_a"]), x, bank_h(x, z), z, rng.uniform(0, 360), rng.uniform(0.8, 1.3))
    for i in range(2600):
        if i < 1500:  # mais denso perto do caminho e do cais (onde a camera baixa olha)
            x = rng.uniform(-14, 14)
            z = rng.uniform(3.2, 15)
        else:
            x = rng.uniform(-14, 30)
            z = rng.uniform(3.2, 26)
        if dist_poly(x, z, PATH) < 1.05 or dist_poly(x, z, PATH2) < 0.8:
            continue
        if math.hypot(x + 10.6, z - 5.2) < 1.9:
            continue
        y = bank_h(x, z)
        if y < -0.15:
            continue
        k = rng.choices(["grass_tuft", "grass_tall", "flowers_a", "flowers_b"], [5, 3, 1, 1])[0]
        put(k, x, y - 0.02, z, rng.uniform(0, 360), rng.uniform(0.8, 1.4))
    # juncos e pedras na beira d'agua
    for i in range(60):
        x = rng.uniform(-14, 30)
        if -8.6 < x < 8.6:
            continue
        z = rng.uniform(1.8, 3.4)
        y = bank_h(x, z)
        if y < -0.65 or y > 0.1:
            continue
        put("reeds", x, y - 0.05, z, rng.uniform(0, 360), rng.uniform(0.8, 1.2))
    for i in range(34):
        x = rng.uniform(-14, 30)
        z = rng.uniform(1.4, 3.6)
        if -8.8 < x < 8.8:
            continue
        put(rng.choice(["rock_a", "rock_b"]), x, bank_h(x, z) - 0.15, z, rng.uniform(0, 360), rng.uniform(0.5, 1.0))
    # promontorio do farol (E3b: pedras empurradas para fora do caminho da rua ate a escada do farol; mesma ordem de
    # sorteio, entao o resto da dispersao nao muda)
    for i in range(40):
        a = rng.uniform(0, 6.28)
        r = rng.uniform(7.5, 11.0)
        x = 31.5 + math.cos(a) * r * 1.25
        z = -23.0 + math.sin(a) * r
        kind = rng.choice(["rock_a", "rock_b", "rock_b"])
        ry, s = rng.uniform(0, 360), rng.uniform(0.8, 1.8)
        x, z = clear_head_path(x, z, (0.62 if kind == "rock_a" else 1.15) * s)
        if x is None:
            continue
        put(kind, x, head_h(x, z) - 0.2, z, ry, s)
    for i in range(160):
        x = rng.uniform(22, 42)
        z = rng.uniform(-34, -12)
        y = head_h(x, z)
        if y < 0.5 or math.hypot(x - 31, z + 24) < 3.4 or (25.6 < x < 28.4 and -21.5 < z < -16.5):
            continue
        put(rng.choice(["grass_tuft", "grass_tall", "flowers_a", "grass_tuft"]), x, y - 0.03, z, rng.uniform(0, 360), rng.uniform(1, 1.5))
    for (x, z) in ((25.0, -28.0), (36.5, -18.0), (37.0, -28.5)):
        put("tree_b", x, head_h(x, z) - 0.1, z, 0, 1.1)
    for i in range(14):
        x = rng.uniform(24, 40)
        z = rng.uniform(-32, -14)
        if math.hypot(x - 31, z + 24) < 3.6:
            continue
        put(rng.choice(["bush_a", "bush_c"]), x, head_h(x, z) - 0.05, z, rng.uniform(0, 360), rng.uniform(0.9, 1.4))


# G6 (RB-R1): objetos que se atravessavam ou flutuavam, achados por tools/prop-overlap.sh (criterios em
# game/tests/prop_overlap.gd). Correcao DEPOIS de toda a dispersao, por (tipo, indice), para nao mudar a ordem dos sorteios
# nem os indices (a colisao e os testes usam o indice). y None = mesma regra de altura da origem do objeto.
G6_MOVES = {
    # covos empilhados: a rede (casca cilindrica) desce 0,18 m abaixo do fundo e atravessava o covo de baixo (9,8 e
    # 9,1 cm); o de cima vai para o chao ao lado
    ("lobster_trap", 1): (6.72, 0.0, -1.45),
    ("lobster_trap", 6): (23.45, 0.0, -16.05),
    ("sack", 1): (5.70, 0.0, 0.12),                # sacos 10,7 cm um dentro do outro
    ("crate", 0): (-6.65, 0.0, -1.9),              # caixotes encostados 2,9 cm um no outro
    ("crate", 8): (-15.05, 0.0, -16.2),            # 2,0 e 2,5 cm
    ("crate", 9): (-14.4, 0.0, -15.85),
    ("crate", 10): (8.55, "bank", 6.2),            # 2,2 cm no covo da margem
    # barris em cima do degrau da porta (x -10,33..-8,73; 0,16 m de altura): 14 cm enterrados nele; um de cada lado
    ("barrel_lid", 2): (-10.7, 0.0, -17.2),
    ("barrel", 5): (-8.38, 0.0, -17.05),
    # vaso 14 cm dentro do canteiro; canteiro e vasos em cima do degrau da porta (x 10,9..12,5): vaso de cada lado da
    # porta, canteiro depois do vaso da direita
    ("pot_c", 1): (10.6, 0.0, -17.3),
    ("pot_a", 3): (12.78, 0.0, -17.3),
    ("planter", 2): (13.72, 0.0, -17.3),
    # caixotes do cais norte com a frente 3 cm dentro da faixa de pedra do meio-fio (z > -16,75): recuam
    ("crate_fish", 5): (-12.4, 0.0, -17.1),
    ("crate_fish", 6): (-11.7, 0.0, -17.12),
    ("crate_fruit", 1): (1.2, 0.0, -17.1),
    ("crate_fruit", 2): (0.5, 0.0, -17.1),         # (em x 1,85 batia no degrau da porta)
    ("rock_b", 19): (20.94, "head", -19.69),       # pedra 25 cm dentro do barril
    ("rock_b", 27): (24.76, "head", -15.35),       # pedra 30 cm dentro do poste
    ("tree_b", 102): (25.0, "head_tree", -26.6),   # tronco 46 cm dentro de duas pedras
    ("tree_b", 103): (35.8, "head_tree", -18.6),   # tronco 38 cm dentro da pedra
    ("pot_b", 3): (-27.6, 0.0, -12.6),             # vaso sem chao embaixo (1,5 m no vazio)
    ("rock_b", 40): (20.0, "head", -25.55),        # pedra 76 cm para fora do barranco: 1 m para dentro
    ("parasol", 1): (19.95, 0.0, -15.5),           # lonas dos dois guarda-sois do cafe 8 cm uma na outra
    ("cafe_set", 1): (19.95, 0.0, -15.5),
    ("crate", 13): (-16.44, 0.0, -8.94),           # 2,7 cm no barril da praca
    ("rope_coil", 1): (1.66, 0.0, 2.34),           # 2,5 cm no monte de rede
}
# Pilha de caixote + caixote de fruta junto ao carrinho do M4: o canto do carrinho (x ~ -18,6) atravessava a pilha; ela
# sai 25 cm para oeste.
G6_STACK_NEAR_CART = ((-18.75, 1.55), (-19.0, 1.6))
# Moitas: base arredondada ficava 3-5 cm acima do chao plano; todas descem 5 cm.
G6_BUSH_SINK = 0.05


def g6_fixes():
    moved = 0
    for (kind, i), to in G6_MOVES.items():
        x, y, z = to
        if y == "bank":
            y = bank_h(x, z)
        elif y == "head":
            y = head_h(x, z) - 0.2
        elif y == "head_tree":
            y = head_h(x, z) - 0.1
        row = inst[kind][i]
        row[0], row[1], row[2] = round(x, 3), round(y, 3), round(z, 3)
        moved += 1
    (ox, oz), (nx, nz) = G6_STACK_NEAR_CART
    for kind in ("crate", "crate_fruit"):
        for row in inst[kind]:
            if abs(row[0] - ox) < 1e-6 and abs(row[2] - oz) < 1e-6:
                row[0], row[2] = nx, nz
                moved += 1
    for kind in ("bush_a", "bush_b", "bush_c"):
        for row in inst[kind]:
            row[1] = round(row[1] - G6_BUSH_SINK, 3)
    return moved


def build_bank():
    m = MB("wv2_bank")
    rng = random.Random(61)
    # galpao do pescador na margem sul (fundo do enquadramento da margem)
    p = house_params(4.2, 1, "gable", "sky", "terracotta", dict(chimneys=0, ground="door", shutter=PAL["red"], cols=2, door_col=1,
                                                                flowers=1.0), detail=2)
    p["D"] = 3.6
    p["gh"] = 2.7
    build_house(m, (9.5, bank_h(11.6, 10.6) - 0.05, 9.2), 200, p, 501, lights)
    # varal com roupas entre o galpao do pescador e a arvore (missoes v3, M2): mao-francesa na quina do galpao,
    # laco de corda no tronco da arvore (tree_a em (15,5; 6,5))
    a = Vector((9.75, 0.0, 9.0))
    b = Vector((15.32, 0.0, 6.62))
    ya0 = bank_h(a.x, a.z)
    m.box((a.x, ya0 + 2.0, a.z), (0.06, 0.06, 0.45), "wv2_wood", hexc("#A07A56"), 0.01, 1, rot=R(ry=-23), grain="z", rng=rng)
    m.box((a.x, ya0 + 1.85, a.z - 0.1), (0.05, 0.32, 0.05), "wv2_wood", hexc("#A07A56"), 0.01, 1, rot=R(rx=35), grain="y", rng=rng)
    ring = [(b.x + 0.04 + math.sin(t_) * 0.17, bank_h(b.x, b.z) + 2.0, b.z + math.cos(t_) * 0.17) for t_ in
            [i / 14 * 6.2832 for i in range(15)]]
    m.tube(ring, 0.012, "wv2_rope", hexc("#F2EAD8"), seg=5, caps=False)
    pts = []
    ya, yb = bank_h(a.x, a.z) + 2.0, bank_h(b.x, b.z) + 2.0
    for i in range(13):
        t = i / 12
        pts.append(Vector((a.x + (b.x - a.x) * t, ya + (yb - ya) * t - 0.25 * math.sin(math.pi * t), a.z + (b.z - a.z) * t)))
    m.tube(pts, 0.008, "wv2_rope", hexc("#F2EAD8"), seg=5)
    ang = math.degrees(math.atan2(-(b.z - a.z), b.x - a.x))
    cloth = [(0.18, 0.55, 0.42, PAL["red"]), (0.32, 0.6, 0.7, hexc("#FFFFFF")), (0.5, 0.45, 0.5, PAL["blue"]),
             (0.66, 0.5, 0.6, PAL["yellow"]), (0.82, 0.4, 0.45, PAL["green"])]
    for t, w, h, c in cloth:
        i = int(t * 12)
        p0 = pts[i].lerp(pts[min(12, i + 1)], t * 12 - i)
        m.box((p0.x, p0.y - h / 2, p0.z), (w, h, 0.012), "wv2_canvas", c, 0.0, 1, rot=R(ry=ang, rz=rng.uniform(-3, 3)),
              uvoff=(0.13, 0))
        m.box((p0.x - 0.15, p0.y + 0.02, p0.z), (0.03, 0.08, 0.02), "wv2_wood", hexc("#C8A27A"), 0.0, 1, rot=R(ry=ang))
    # cerca rustica ao longo do caminho (lado sul)
    fence = [(-4.0, 9.8), (-6.0, 11.8), (-9.5, 11.5), (-12.0, 10.6)]
    for (ax, az), (bx, bz) in zip(fence[:-1], fence[1:]):
        L = math.hypot(bx - ax, bz - az)
        n = max(2, int(L / 1.4))
        ang = math.degrees(math.atan2(-(bz - az), bx - ax))
        for k in range(n + 1):
            t = k / n
            x, z = ax + (bx - ax) * t, az + (bz - az) * t
            m.box((x, bank_h(x, z) + 0.5, z), (0.1, 1.05, 0.1), "wv2_wood", hexc("#A88560"), 0.02, 1, grain="y", rng=rng)
        for yy in (0.45, 0.85):
            mx, mz = (ax + bx) / 2, (az + bz) / 2
            m.box((mx, bank_h(mx, mz) + yy, mz), (L, 0.08, 0.05), "wv2_wood", hexc("#B8956C"), 0.015, 1, rot=R(ry=ang), rng=rng)
    # barco virado na margem
    put("rowboat_flip", -10.6, bank_h(-10.6, 5.2) - 0.02, 5.2, 70, 1.0)
    put("bench", -4.6, bank_h(-4.6, 5.0), 5.0, 160)
    put("lamp_post", -3.4, bank_h(-3.4, 6.6), 6.6, 0)
    put("lamp_post", -11.8, bank_h(-11.8, 7.0), 7.0, 0)
    put("sign_aframe", 1.6, 0.0, 4.3, -30)
    put("crate", 8.6, bank_h(8.6, 6.2), 6.2, 20)
    put("lobster_trap", 9.3, bank_h(9.3, 6.0), 6.0, -10)
    put("net_pile", 7.6, bank_h(7.6, 8.4), 8.4, 0, 0.8)
    put("barrel", 12.1, bank_h(12.1, 7.4), 7.4, 0)
    global bank_info
    bank_info = W3.bank_extras(m, bank_h, random.Random(35))   # E3, M2: anexo de topo plano + 2 degraus + galho baixo
    return m


def street_props():
    rng = random.Random(71)
    for x in (-10.0, -3.0, 4.0, 11.0, 18.0, 24.5):
        put("lamp_post", x, 0.0, -13.75, 0)
    for x in (-12.5, -6.5, 0.5, 7.5, 14.5, 20.5):
        put("bollard", x, 0.0, -13.45, rng.uniform(0, 90))
    for (x, z) in ((-21.2, -11.0), (-21.2, 6.5), (-16.0, -1.0), (-28.8, -12.8), (-28.8, 0.0)):
        put("lamp_post", x, 0.0, z, 0)
    put("bench", -6.8, 0.0, -14.0, 180)
    put("bench", 8.2, 0.0, -14.0, 180)
    put("planter", -1.5, 0.0, -13.9, 0)
    put("planter", 15.2, 0.0, -13.9, 0)
    put("rope_coil", 2.0, 0.0, -13.6, 20)
    put("rope_coil", 19.0, 0.0, -13.6, 200)
    put("net_pile", 22.4, 0.0, -14.4, 60, 0.9)
    put("lobster_trap", 23.5, 0.0, -15.2, 85)
    put("lobster_trap", 23.4, 0.36, -15.2, 100)
    put("life_ring", 12.7, 0.0, -13.45, 180)
    # frente das casas: vasos, barris, caixotes, carrinho, placas, cafe
    put("barrel_lid", -9.4, 0.0, -17.2, 0)
    put("barrel", -8.8, 0.0, -17.05, 40)
    put("crate_fish", -12.4, 0.0, -16.7, 5)
    put("crate_fish", -11.7, 0.0, -16.75, -3)
    put("crate", -14.3, 0.0, -17.0, 10)
    put("sign_aframe", -10.6, 0.0, -15.8, 10)
    put("pot_a", -5.7, 0.0, -17.3, 0)
    put("pot_c", -4.2, 0.0, -17.35, 0)
    put("cart", -1.8, 0.0, -15.9, 200)
    put("crate_fruit", 1.2, 0.0, -16.9, 0)
    put("crate_fruit", 1.85, 0.0, -16.95, 8)
    put("sack", 2.6, 0.0, -17.1, 30)
    put("sign_aframe", 0.4, 0.0, -15.6, -10)
    put("pot_b", 4.8, 0.0, -17.3, 0)
    put("pot_a", 6.4, 0.0, -17.4, 0)
    put("bench", 9.0, 0.0, -17.25, 0)
    put("pot_c", 10.8, 0.0, -17.3, 0)
    put("pot_a", 12.6, 0.0, -17.3, 0)
    put("planter", 13.0, 0.0, -17.3, 0)
    put("stall_yellow", 10.5, 0.0, -15.2, 0, 0.95)
    put("pot_b", 15.3, 0.0, -17.3, 0)
    put("cafe_set", 17.3, 0.0, -15.6, 10)
    put("cafe_set", 19.6, 0.0, -15.5, -15)
    put("parasol", 17.3, 0.0, -15.6, 0)
    put("parasol", 19.6, 0.0, -15.5, 20)
    put("pot_c", 21.6, 0.0, -17.2, 0)
    put("barrel", 22.0, 0.0, -18.4, 0)
    put("tree_c", 24.3, 1.2, -25.5, 0, 1.1)
    # praca / mercado
    put("stall_red", -26.0, 0.0, -9.6, 90)
    put("stall_yellow", -26.0, 0.0, -1.2, 90)
    put("stall_blue", -19.2, 0.0, -6.4, -90)
    put("cart", -18.6, 0.0, 0.8, 120)
    for (x, z, k) in ((-25.2, -11.4, "crate_fruit"), (-25.4, -7.8, "crate"), (-24.8, -7.6, "sack"), (-27.0, 1.5, "barrel"),
                      (-20.3, -8.2, "crate_fruit"), (-20.2, -4.6, "sack"), (-27.6, 5.0, "pot_a"), (-27.6, -3.2, "pot_c"),
                      (-27.6, -13.4, "pot_b"), (-20.0, 7.0, "bench"), (-17.0, -9.5, "barrel_lid"), (-16.5, -9.0, "crate")):
        put(k, x, 0.0, z, rng.uniform(-20, 20) if k != "bench" else 200)
    put("tree_c", -15.8, 0.0, 6.8, 120, 1.0)
    # primeiro plano da praca (vista baixa da praca): mercadoria, canteiro e banco
    for (x, z, k, ry) in ((-18.1, 1.7, "crate_fruit", 10), (-18.9, 2.3, "crate_fruit", -15), (-18.75, 1.55, "crate", 4),
                          (-19.9, 2.9, "sack", 40), (-20.2, 2.25, "sack", 100), (-17.6, 0.4, "barrel_lid", 0),
                          (-21.2, 1.0, "pot_c", 0), (-17.4, -2.6, "planter", 90)):
        put(k, x, 0.0, z, ry)
    put("crate_fruit", -18.75, 0.6, 1.55, 5, 0.85)
    # barquinhos no porto
    put("rowboat_a", -10.6, -0.42, -8.6, 18)
    put("rowboat_a", 13.4, -0.42, -11.4, 82)
    put("rowboat_b", 18.6, -0.42, -7.2, 65)
    for (x, z) in ((-4.5, -9.0), (9.5, -6.5), (20.0, -10.0)):
        put("float_buoy", x, -0.52, z, 0, 1.2)


def bunting(m):
    """Bandeirolas: das fachadas aos postes do cais e atravessando a praca."""
    rng = random.Random(81)
    cols = [PAL["red"], PAL["yellow"], PAL["blue"], hexc("#FFFFFF"), PAL["green"], hexc("#FF8FB1")]
    lines = [((-11.0, 5.6, -17.6), (-10.0, 3.3, -13.75)), ((-5.0, 5.6, -17.6), (-3.0, 3.3, -13.75)),
             ((3.0, 5.6, -17.6), (4.0, 3.3, -13.75)), ((9.5, 5.6, -17.6), (11.0, 3.3, -13.75)),
             ((16.0, 5.6, -17.6), (18.0, 3.3, -13.75)), ((-29.6, 5.0, -8.0), (-21.2, 3.3, -11.0)),
             ((-29.6, 5.0, 2.0), (-21.2, 3.3, 6.5)), ((-21.2, 3.3, -11.0), (-16.0, 3.3, -1.0))]
    for a, b in lines:
        a, b = Vector(a), Vector(b)
        n = 18
        pts = []
        for i in range(n + 1):
            t = i / n
            p = a.lerp(b, t)
            p.y -= 0.45 * math.sin(math.pi * t)
            pts.append(p)
        m.tube(pts, 0.008, "wv2_rope", hexc("#F2EAD8"), seg=4)
        L = (b - a).length
        nf = int(L / 0.42)
        d = (b - a).normalized()
        ang = math.degrees(math.atan2(-d.z, d.x))
        for k in range(nf):
            t = (k + 0.5) / nf
            p = a.lerp(b, t)
            p.y -= 0.45 * math.sin(math.pi * t)
            c = cols[k % len(cols)]
            m.prism((p.x, p.y, p.z), [(-0.13, 0.0), (0.13, 0.0), (0.0, -0.3)], 0.008, "wv2_canvas", c,
                    rot=R(ry=ang, rx=rng.uniform(-8, 8)), uvoff=(0.13, 0))


# ================================================================== vistas e percurso
VIEWS = {
    # camera baixa do jogo: ~1,95 m, 12 graus para baixo, FOV 50 (igual a vitrine lookdev)
    "dock": {"pos": [-0.95, 1.95, 4.85], "look": [-2.0, 1.95, 1.0], "hero": [-2.0, 0.0, 1.0]},
    "street": {"pos": [16.2, 1.95, -13.95], "look": [6.0, 1.95, -16.9]},
    "plaza": {"pos": [-15.6, 1.95, 4.2], "look": [-24.0, 1.95, -3.0]},
    "bank": {"pos": [-9.0, 1.95, 13.6], "look": [-3.0, 1.95, 7.0]},
    # vistas de detalhe para aprovacao (nao sao a camera do jogo)
    "boat": {"pos": [3.4, 1.95, -1.7], "look": [-0.4, 1.95, -5.0], "pitch": 16.0, "fov": 50.0},
    "windows": {"pos": [-7.2, 2.4, -14.0], "look": [-9.2, 2.4, -17.8], "pitch": -12.0, "fov": 46.0},
}
TRIO = [
    {"id": "rastro", "pos": [-2.0, 0.0, 1.0], "ry": 160.0, "phase": 0.0},
    {"id": "pico", "pos": [-3.55, 0.0, -0.35], "ry": 195.0, "phase": 0.37},
    {"id": "leme", "pos": [-0.55, 0.0, -0.7], "ry": 140.0, "phase": 0.71},
]
PATH_CAM = [  # [t (s), posicao, alvo do olhar]
    [0.0, [-11.0, 1.9, 13.2], [-5.0, 1.3, 7.5]],
    [3.5, [-6.4, 1.9, 10.6], [-1.0, 1.2, 4.0]],
    [7.0, [-1.6, 1.85, 5.6], [-2.0, 1.0, 0.0]],
    [10.0, [0.9, 1.85, 1.6], [-2.6, 1.0, -0.8]],
    [12.5, [3.2, 1.95, -1.4], [6.0, 3.0, -16.0]],
    [15.5, [8.6, 2.1, -9.0], [2.0, 2.4, -17.0]],
    [18.5, [6.0, 1.9, -14.6], [-6.0, 2.2, -16.4]],
    [21.5, [-5.0, 1.9, -14.9], [-16.0, 2.0, -14.2]],
    [24.5, [-15.2, 1.9, -11.6], [-25.0, 1.6, -5.0]],
    [27.0, [-18.4, 1.9, -3.0], [-27.0, 1.6, 2.0]],
    [29.5, [-16.6, 1.9, 4.6], [-6.0, 1.3, 9.0]],
]


# ================================================================== saida
def write_textures():
    if "--no-tex" in ARGS and os.path.exists(INFO_JSON):
        info = json.load(open(INFO_JSON)).get("texturas", {})
    else:
        info = TX.build(TEX_DIR)
    TX.write_imports(TEX_DIR, os.path.join(REPO, "game"))
    return info


def export_glb(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=True,
                              export_materials="EXPORT", export_cameras=False, export_lights=False, export_extras=False,
                              export_vertex_color="ACTIVE", export_normals=True, export_tangents=False,
                              export_texcoords=True, export_image_format="NONE")


MANIFEST = os.path.join(REPO, "source_art", "manifest.json")
SOURCES = ["source_art/environment_v2/build_world_v2.py", "source_art/environment_v2/build_boat_wv2.py", "source_art/environment_v2/wv2lib.py",
           "source_art/environment_v2/wv3_world.py", "source_art/environment_v2/wv3_collision.py", "source_art/environment_v2/wv3_glb.py",
           "source_art/environment_v2/wv2_houses.py", "source_art/environment_v2/wv2_kit.py",
           "source_art/environment_v2/wv2_textures.py", "source_art/environment_v2/render_world_v2.py",
           "source_art/environment_v2/world_v2.blend", "source_art/environment_v2/PROVENANCE.md"]


def _sha(path):
    import hashlib
    h = hashlib.sha256()
    with open(path, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def update_manifest(info):
    """Entradas do mundo v2 no source_art/manifest.json (mesmo padrao dos ativos do RB-R1: sha256, triangulos, origem)."""
    with open(MANIFEST, encoding="utf-8") as f:
        man = json.load(f)
    common = {
        "agente": "art3d", "status": "provisorio", "aprovacao": "direcao aprovada (D14); E3 pendente (Thiago)", "data": "2026-11-25",
        "proposta": "RB-R1 W1: vitrine vila e cais v2; NAO substitui o porto do jogo (so game/lookdev/world_v2/)",
        "originalidade": "geometria e texturas 100% procedurais por script (bmesh, formulas e numpy); nenhum modelo, malha, "
                         "textura, foto, HDRI ou kit de terceiros",
        "origem": SOURCES,
    }
    proc = {"script": "source_art/environment_v2/build_world_v2.py",
            "ferramenta": "Blender 4.5.16 (tools/blender.sh, headless, numpy embutido)",
            "exportador": "glTF 2.0 binario (GLB), +Y up, metros, cor de vertice (COLOR_0 linear), UV em metros, "
                          "normais ponderadas por area (WeightedNormal), sem texturas embutidas"}
    st = info["estatico"]
    kit = info["kit"]
    entries = [
        dict(id="world_v2_static", nome="Mundo v2: cenario fixo do recorte do porto", processo=proc,
             saida_glb="game/assets/models/environment_v2/wv2_static.glb",
             glb_sha256=_sha(os.path.join(GLB_DIR, "wv2_static.glb")), glb_bytes=os.path.getsize(os.path.join(GLB_DIR, "wv2_static.glb")),
             triangulos=info["triangulos_estatico"],
             materiais=sorted({m for v in st.values() for m in v["materiais"]}),
             objetos=sorted(st.keys()),
             nota="cais de madeira, cais de pedra, ruas e praca calcadas, 20 casas (vaos recuados, venezianas, floreiras, "
                  "sacadas, toldos, telhas modeladas), galpao, chafariz, farol, margem, morros e fundo do porto. E3: farol em "
                  "objeto proprio com 3 patamares + galeria, chafariz em 3 degraus com canaleta e grade, anexo do galpao da "
                  "margem com 2 degraus, galho baixo, placas de fruta nas barracas; peso: LOD por objeto (wv2_back 2, rua e "
                  "praca 1), micro-simplificacao e cor de vertice em 8 bits (wv3_glb.py); antes 13.902.076 bytes / 273.880 tris"),
        dict(id="world_v2_kit", nome="Mundo v2: kit de aderecos e vegetacao (MultiMesh)", processo=proc,
             saida_glb="game/assets/models/environment_v2/wv2_kit.glb",
             glb_sha256=_sha(os.path.join(GLB_DIR, "wv2_kit.glb")), glb_bytes=os.path.getsize(os.path.join(GLB_DIR, "wv2_kit.glb")),
             triangulos=sum(v["triangulos"] for v in kit.values()),
             materiais=sorted({m for v in kit.values() for m in v["materiais"]}),
             objetos=sorted("kit_" + k for k in kit.keys()),
             nota="%d pecas, %d instancias no layout (game/lookdev/world_v2/world_v2_layout.json)" % (len(kit), info["instancias"])),
        dict(id="world_v2_boat", nome="Mundo v2: barco do porto (proposta para substituir boat_v2)", processo=proc,
             saida_glb="game/assets/models/environment_v2/wv2_boat.glb",
             glb_sha256=_sha(os.path.join(GLB_DIR, "wv2_boat.glb")), glb_bytes=os.path.getsize(os.path.join(GLB_DIR, "wv2_boat.glb")),
             triangulos=info["barco"]["triangulos"], materiais=info["barco"]["materiais"],
             empties=info["barco"]["empties"],
             nota="mesmas medidas e pontos de encaixe do boat_v2 (pivo, popa z 2, proa z -3, boca 2,2, convez 0,40, banco 0,5 "
                  "em z 0,6, WheelPoint, HornPoint, DeckPoint, BenchMark, PawMark) + pontos de corda RopeBow/RopeSternL/R"),
        dict(id="world_v2_textures", nome="Mundo v2: texturas procedurais ladrilhaveis",
             processo={"script": "source_art/environment_v2/wv2_textures.py",
                       "ferramenta": "Blender 4.5.16 (numpy embutido); JPEG pelo Blender, PNG escrito pelo script",
                       "exportador": "cor em JPEG (sRGB); dados em PNG RGBA (normal OpenGL, mascara de tinta, rugosidade)"},
             saida="game/assets/textures/environment_v2",
             arquivos_sha256={f: _sha(os.path.join(TEX_DIR, f)) for f in sorted(os.listdir(TEX_DIR)) if f.endswith((".jpg", ".png"))},
             arquivos_bytes={f: os.path.getsize(os.path.join(TEX_DIR, f)) for f in sorted(os.listdir(TEX_DIR))
                             if f.endswith((".jpg", ".png"))},
             bytes_total=sum(os.path.getsize(os.path.join(TEX_DIR, f)) for f in os.listdir(TEX_DIR) if f.endswith((".jpg", ".png"))),
             nota="ruido de valor, Voronoi e formas analiticas; mipmaps e sem compressao com perda no .import. E3 (peso): PNG de "
                  "dados com filtro adaptativo por linha (sem perda) e dados de plaster/stone/grass/dirt/leaf em meia resolucao; "
                  "decal_* = decalques RGBA (pegadinha seca/molhada, pena, escamas) de wv3_world.decals()"),
        dict(id="world_v3_props", nome="Ep01 v3: pecas soltas das missoes (lanterna do farol, bote do capitao, boias, barquinhos "
                                       "da festa, lanternas de papel, lente)", processo=proc,
             saida_glb="game/assets/models/environment_v2/wv3_props.glb",
             glb_sha256=_sha(os.path.join(GLB_DIR, "wv3_props.glb")), glb_bytes=os.path.getsize(os.path.join(GLB_DIR, "wv3_props.glb")),
             triangulos=info["props"]["triangulos"], materiais=info["props"]["materiais"], objetos=info["props"]["objetos"],
             nota="RB-R1 E3; um no por peca com origem no pivo; wv3_lantern gira em Y (filho wv3_lantern_beam = feixe)"),
        dict(id="world_v3_village_scenes", nome="Ep01 v3: colisao, limites e marcadores M0-M8 da vila (cenas geradas)",
             processo={"script": "source_art/environment_v2/wv3_collision.py", "ferramenta": "Blender 4.5.16 (Python)",
                       "exportador": "texto .tscn da Godot 4 (BoxShape3D, CylinderShape3D, HeightMapShape3D, Marker3D)"},
             saida="game/worlds/village_v3",
             arquivos_sha256={f: _sha(os.path.join(REPO, "game", "worlds", "village_v3", f))
                              for f in ("village_collision.tscn", "village_world.tscn")},
             arquivos_bytes={f: os.path.getsize(os.path.join(REPO, "game", "worlds", "village_v3", f))
                             for f in ("village_collision.tscn", "village_world.tscn")},
             colisao=info.get("colisao", {}),
             nota="formas simples; camada 1, mascara 0; beira d'agua por contorno do nivel -0,3 m"),
    ]
    ids = {e["id"] for e in entries}
    man["ativos"] = [a for a in man["ativos"] if a.get("id") not in ids]
    for e in entries:
        full = {"id": e.pop("id"), "nome": e.pop("nome")}
        full.update(common)
        full.update(e)
        man["ativos"].append(full)
    with open(MANIFEST, "w", encoding="utf-8") as f:
        f.write(json.dumps(man, indent=2, ensure_ascii=False) + "\n")


FESTA_LINES = [  # cordoes de lanternas da festa (E3, M8): rua da frente, praca e cais
    ((-12.0, 4.6, -17.4), (-12.0, 3.0, -13.75), 4), ((1.0, 4.6, -17.4), (0.5, 3.0, -13.75), 4),
    ((14.0, 4.6, -17.4), (14.5, 3.0, -13.75), 4), ((-10.0, 3.0, -13.75), (4.0, 3.0, -13.75), 12),
    ((4.0, 3.0, -13.75), (18.0, 3.0, -13.75), 12), ((-29.6, 4.4, -3.0), (-21.2, 3.0, -11.0), 9),
    ((-29.6, 4.4, 5.0), (-21.2, 3.0, 6.5), 8), ((-21.2, 3.0, 6.5), (-16.0, 3.0, -1.0), 7),
    ((-7.55, 3.0, 2.6), (7.55, 3.0, 2.6), 12), ((-3.4, 3.0, 6.6), (-11.8, 3.0, 7.0), 7),
]


def build_props(mats, kit):
    """Pecas soltas do Ep01 v3 (E3) em wv3_props.glb, cada uma com origem no proprio pivo (a Godot move/gira/acende)."""
    col = bpy.data.collections.new("WV3_Props")
    bpy.context.scene.collection.children.link(col)
    objs = []
    pos = {}

    def add(mb, x, y, z, ry=0.0, rx=0.0, rz=0.0, parent=None):
        ob = mb.to_object(mats, col)
        ob.location = (x, -z, y)
        W3._to_godot_rot(ob, rx, ry, rz)
        if parent is not None:
            ob.parent = parent
        else:
            pos[mb.name] = [round(x, 3), round(y, 3), round(z, 3), round(ry, 2), round(rx, 2), round(rz, 2)]
        objs.append(ob)
        return ob

    lan, beam = W3.lantern_parts()
    lob = add(lan, W3.LH[0], W3.LANTERN_Y, W3.LH[2], 0.0)
    add(beam, 0.0, 0.0, 0.0, parent=lob)
    dx, dz, dry = W3.DINGHY
    add(W3.dinghy(), dx, max(head_h(dx, dz), -0.4) + 0.02, dz, dry, rx=-7.0, rz=9.0)
    for name, x, z, c in W3.BUOYS:
        add(W3.buoy(name, c), x, -0.4, z)
    boat_lanterns = []
    for i, (x, z, ry, hull, icon) in enumerate(W3.FESTA_BOATS):
        mb, lp = W3.festa_boat(i + 1, hull, icon)
        add(mb, x, -0.42, z, ry)
        a = math.radians(ry)
        boat_lanterns.append([round(x + lp[0] * math.cos(a) + lp[2] * math.sin(a), 3), round(-0.42 + lp[1], 3),
                              round(z - lp[0] * math.sin(a) + lp[2] * math.cos(a), 3)])
    fl, fpts = W3.festa_lanterns(FESTA_LINES)
    add(fl, 0.0, 0.0, 0.0)
    lx, lz = W3.LENS
    add(W3.lens(), lx, head_h(lx, lz) - 0.02, lz, 30.0, rx=-6.0)
    info = {"pos": pos, "festa_lanternas": [[round(c, 3) for c in p_] for p_ in fpts], "festa_barcos_lanternas": boat_lanterns,
            "objetos": sorted(pos.keys()) + ["wv3_lantern_beam"],
            "materiais": sorted({mt.name for o in objs for mt in o.data.materials}),
            "triangulos": sum(len(o.data.polygons) for o in objs)}
    tris = 0
    for o in objs:
        tris += sum(len(pp.vertices) - 2 for pp in o.data.polygons)
    info["triangulos"] = tris
    return objs, info


def main():
    t0 = time.time()
    random.seed(20261125)  # deslocamentos de UV sem rng explicito: reprodutivel
    reset()
    tex_info = write_textures()
    mats = materials()
    col_static = bpy.data.collections.new("WV2_Static")
    col_kit = bpy.data.collections.new("WV2_Kit")
    bpy.context.scene.collection.children.link(col_static)
    bpy.context.scene.collection.children.link(col_kit)

    statics = []
    dock = build_dock()
    quay = build_quay()
    street, fronts = build_street()
    bunting(street)
    plaza = build_plaza()
    back = build_row2()
    lighthouse = MB("wv2_lighthouse")   # E3: farol em objeto proprio (detalhe cheio), com patamares e galeria
    W3.lighthouse(lighthouse, build_house, house_params, lights)
    bank = build_bank()
    terrain = build_terrain()
    scatter_vegetation()
    street_props()
    g6_fixes()
    info = {"gerado_por": "source_art/environment_v2/build_world_v2.py", "provisorio": True, "texturas": tex_info,
            "estatico": {}, "kit": {}}
    for mb in (dock, quay, street, plaza, back, lighthouse, bank, terrain):
        ob = mb.to_object(mats, col_static)
        statics.append(ob)
        info["estatico"][mb.name] = {"triangulos": mb.tris(), "materiais": mb.mats}
    kit = KIT.build_all()
    kit_objs = []
    xcur = 0.0
    for name, mb in kit.items():
        mb.name = "kit_" + name
        ob = mb.to_object(mats, col_kit)
        kit_objs.append(ob)
        xs = [v.x for v in mb.verts]
        ys = [v.y for v in mb.verts]
        zs = [v.z for v in mb.verts]
        info["kit"][name] = {"triangulos": mb.tris(), "materiais": mb.mats, "instancias": len(inst.get(name, [])),
                             "tamanho_m": [round(max(xs) - min(xs), 3), round(max(ys) - min(ys), 3), round(max(zs) - min(zs), 3)]}
    missing = [k for k in inst if k not in kit]
    if missing:
        raise RuntimeError("kit sem malha: %s" % missing)
    col_boat = bpy.data.collections.new("WV2_Boat")
    bpy.context.scene.collection.children.link(col_boat)
    boat_objs, boat_info = BOAT.build(mats, col_boat)
    info["barco"] = boat_info
    export_glb(boat_objs, os.path.join(GLB_DIR, "wv2_boat.glb"))
    for ob in boat_objs:
        if ob.parent is None:
            ob.location = (0.0, -5.0, 0.0)   # vitrine do .blend: barco atracado (Ep01Layout.BOAT_DOCKED_POS); GLB ja exportado
            ob.rotation_euler = (0.0, 0.0, math.pi / 2)
    export_glb(statics, os.path.join(GLB_DIR, "wv2_static.glb"))
    export_glb(kit_objs, os.path.join(GLB_DIR, "wv2_kit.glb"))
    props_objs, props_info = build_props(mats, kit)
    export_glb(props_objs, os.path.join(GLB_DIR, "wv3_props.glb"))
    info["props"] = props_info
    for g in ("wv2_static.glb", "wv2_kit.glb", "wv2_boat.glb", "wv3_props.glb"):
        b0, b1 = wv3_glb.compact(os.path.join(GLB_DIR, g))
        print("WV3 GLB %s %d -> %d bytes" % (g, b0, b1))
    info["decalques"] = W3.decals(TEX_DIR)
    TX.write_imports(TEX_DIR, os.path.join(REPO, "game"))
    # vitrine do .blend: kit em fila ao lado do mapa (nao afeta os GLB, ja exportados)
    for ob in kit_objs:
        ob.location.x = 50.0 + xcur
        ob.location.y = 60.0
        xcur += max(1.5, ob.dimensions.x + 0.8)
    info["triangulos_estatico"] = sum(v["triangulos"] for v in info["estatico"].values())
    info["triangulos_instancias"] = sum(v["triangulos"] * v["instancias"] for v in info["kit"].values())
    info["instancias"] = sum(len(v) for v in inst.values())
    info["luzes"] = len(lights)
    layout = {"provisorio": True, "fonte": "source_art/environment_v2/build_world_v2.py", "kit": inst,
              "luzes": [{"tipo": k, "pos": [round(c, 3) for c in p]} for k, p in lights], "vistas": VIEWS, "trio": TRIO,
              "percurso": PATH_CAM,
              "texturas": {k: v["metros"] for k, v in tex_info.items()},
              "props": props_info["pos"], "festa_lanternas": props_info["festa_lanternas"],
              "festa_barcos_lanternas": props_info["festa_barcos_lanternas"]}
    os.makedirs(os.path.dirname(LAYOUT_JSON), exist_ok=True)
    with open(LAYOUT_JSON, "w") as f:
        json.dump(layout, f, indent=1, sort_keys=True)
    with open(INFO_JSON, "w") as f:
        json.dump(info, f, indent=1, sort_keys=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)
    if os.path.exists(BLEND + "1"):
        os.remove(BLEND + "1")
    col_info = COL.write_scenes(REPO, inst, houses, lights, props_info, bank_info,
                                dict(bank_h=bank_h, head_h=head_h, hill_h=hill_h, west_h=west_h))
    info["colisao"] = col_info
    with open(INFO_JSON, "w") as f:
        json.dump(info, f, indent=1, sort_keys=True)
    update_manifest(info)
    if "--renders" in ARGS:
        import render_world_v2
        render_world_v2.render_all(statics, kit_objs, os.path.join(REPO, "captures", "mundo_v2", "blender"), boat_objs)
    print("WV2 OK estatico=%d tris kit_inst=%d tris instancias=%d luzes=%d tempo=%.1fs" % (
        info["triangulos_estatico"], info["triangulos_instancias"], info["instancias"], len(lights), time.time() - t0))


if __name__ == "__main__":
    main()
