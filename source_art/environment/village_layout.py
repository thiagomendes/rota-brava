"""Layout do porto/vila Farol 7 (RB-R1, PROVISORIO). Fonte unica das posicoes usadas pelos estudos Blender
(source_art/studies/world/study_village.py) e pelo trecho da Godot (exportado em game/episodes/ep01/world/harbor_layout.json
por `python village_layout.py --json COMP`; o gerador game/episodes/ep01/world/gen_harbor_slice.gd le esse JSON).
Espaco Godot: x leste, y cima, z sul; metros. Colocacao = (id_glb, x, y, z, rot_y_graus, escala).
Geografia (compativel com game/episodes/ep01/ep01_layout.gd): cais x -8..8, z -3..3, topo y 0; barco em (0, 0, -5);
bacia do porto x -14..26, z -3..-13; cais de pedra norte z -13..-19; cais de pedra oeste x -20..-14; rio sai para +X.
"""
import json
import math
import random
import sys

WATER_Y = -0.4
CAM_TARGET = (0.0, 0.0, -2.4)        # Ep01Layout.BENCH_INTERACT_POS (Rastro junto ao banco do barco)
KID = (-0.6, -2.2)
OPEN_CAM = {"A": ((14.0, 21.0, 30.0), (2.0, 4.0, -16.0)), "B": ((14.0, 21.0, 30.0), (2.0, 4.0, -16.0))}
WALL_COLORS = ["peach", "mint", "sky", "lemon", "rose"]


def P(id_, x, y, z, ry=0.0, s=1.0, **kw):
    d = (id_, x, y, z, ry, s)
    return d if not kw else d + (kw,)


# ------------------------------------------------------------------ comum (cais, barco, adercos, ceu, fundo)
def dock():
    L = []
    for i in range(4):
        L.append(P("dock_deck_4m", -6 + 4 * i, 0, 0))
        L.append(P("dock_edge", -6 + 4 * i, 0, -3.0))
    for x in (-7.5, -4.5, -1.5, 1.5, 4.5, 7.5):
        L.append(P("dock_pile", x, 0, -2.85))
    L += [P("dock_post", -7.6, 0, -2.6, 20), P("dock_post", 7.6, 0, -2.6, -30), P("dock_post", -3.4, 0, -2.7, 70),
          P("dock_post", 2.9, 0, -2.7, 10), P("dock_cleat", -1.0, 0, -2.78, 3), P("dock_cleat", 1.2, 0, -2.78, -2)]
    for i in range(3):
        L.append(P("dock_fender", -1.6 + 1.7 * i, 0, -3.28))
    L += [P("dock_ladder", 4.8, 0, -3.1),
          P("crate_l", 6.4, 0, 1.7, 14), P("crate_s", 5.5, 0, 2.2, -8), P("crate_peach", 6.4, 0.8, 1.7, 14),
          P("crate_peach", 4.6, 0, 1.2, 30), P("barrel", 7.4, 0, 0.7), P("barrel", 7.0, 0, -0.2, 40, 0.9),
          P("rope_coil", -6.6, 0, -1.9, 30), P("lantern_post", -5.6, 0, -2.65), P("lantern_post", 5.0, 0, -2.65, 180),
          P("bucket", -6.1, 0, 1.0), P("cork_buoy", -6.9, 0, 2.3, 10), P("fishing_net", -7.2, 0.9, 2.6, 0),
          P("crate_peach", -6.8, 0, 0.2, -20), P("crate_s", -7.3, 0, 1.2, 10), P("barrel", -4.9, 0, 2.4),
          P("crate_peach", -4.5, 0, 0.3, 12), P("bucket", -3.7, 0, 0.6), P("barrel", 4.7, 0, 0.1),
          P("rope_coil", 3.9, 0, 0.6, 50), P("flower_clump", -4.6, 0.8, 0.3, 0, 0.9),
          P("boat_v2", 0, 0, -5.0, 90)]
    return L


def south_bank():
    """Margem sul (atras da camera do cais): mantida do RB-04 (Ep01Layout: x -10..10, z 3..16)."""
    L = [P("ground_tile_a", -6, 0, 9.5), P("ground_tile_path", 0, 0, 9.5), P("ground_tile_b", 6, 0, 9.5, 180),
         P("boat_hut", -7.0, 0, 13.5), P("tree_round", 9.5, 0, 7.6), P("tree_round_dark", -9.4, 0, 13.6),
         P("tree_tall", 9.2, 0, 13.0)]
    return L


def sky_and_far():
    L = [P("hills_far", 20, -0.2, -190, 0, 1.0)]   # o resto do perimetro fica em horizon.tscn
    rng = random.Random(7)
    for i in range(9):
        L.append(P("cloud", rng.uniform(-120, 160), rng.uniform(38, 60), rng.uniform(-260, -120), rng.uniform(0, 360),
                   rng.uniform(1.6, 3.0)))
    for i in range(7):
        L.append(P("seagull", rng.uniform(-10, 14), rng.uniform(4.5, 9.0), rng.uniform(-24, -6), rng.uniform(0, 360), 1.2))
    L += [P("seagull", -3.5, 3.4, -8.5, 40, 1.3), P("seagull", 5.5, 3.9, -10.0, 200, 1.3), P("seagull", 9.0, 3.1, -7.0, 120, 1.3)]
    for x, z, r in ((-9, -9, 20), (12, -10, -30), (18, -6, 60), (-4, -11, 85)):
        L.append(P("rowboat", x, WATER_Y + 0.05, z, r))
    return L


def common():
    return dock() + south_bank() + sky_and_far()


# ------------------------------------------------------------------ cais de pedra e praca (ambas as composicoes)
def quays():
    L = []
    for x in (-18, -10, -2, 6, 14, 22):
        L.append(P("quay_block", x, 0, -16, 180))
    for z in (-9, -1, 7):
        L.append(P("quay_block", -17, 0, z, -90))
    # praca do mercado a oeste
    for x in (-26, -34):
        for z in (-12, -4, 4):
            L.append(P("plaza_tile", x, 0, z))
    return L


def west_plaza():
    """Praca do mercado no cais oeste (lado esquerdo do quadro da camera do cais)."""
    L = [P("market_stall_red", -16.0, 0, -6.0, 90), P("market_stall_blue", -16.0, 0, -2.4, 90),
         P("market_stall_red", -16.0, 0, 1.2, 90), P("flower_bed", -24, 0, -4), P("park_bench", -21.5, 0, -4, 90),
         P("street_lamp", -14.6, 0, -9.0, 0), P("street_lamp", -14.6, 0, 4.5, 0), P("tree_round", -24, 0, 2.5),
         P("tree_round_dark", -24, 0, -11), P("crate_peach", -14.8, 0, -4.2, 10), P("barrel", -14.7, 0, -0.6),
         P("crate_peach", -15.0, 0, 3.0, -15)]
    # casas da praca (fachada para leste, +X)
    for i, z in enumerate((-12.5, -7.0, -1.8, 3.4)):
        hid = ("house_a", "house_d", "house_b", "house_a")[i]
        L.append(P(hid, -27.5, 0, z, 90, wall=WALL_COLORS[(i + 2) % 5], roof=("terracotta", "blue")[i % 2]))
    return L


def promenade(z_front, x0, x1, seed):
    """Calcada do cais norte entre a borda da agua (z=-13) e as fachadas: postes, bancos, flores, barris, redes."""
    rng = random.Random(seed)
    L = []
    x = x0
    k = 0
    while x <= x1:
        L.append(P("street_lamp", x, 0, -13.5, 0))
        if k % 2 == 0:
            L.append(P("flower_bed", x + 2.2, 0, z_front + 1.6, 0, 0.75))
        else:
            L.append(P("park_bench", x + 2.4, 0, z_front + 1.0, 0))
        L.append(P("bunting", x + 4.0, 3.2, -13.6, 0)) if x + 8 <= x1 + 0.1 else None
        x += 8
        k += 1
    L = [p for p in L if p]
    for i in range(10):
        L.append(P(rng.choice(["crate_peach", "barrel", "crate_s", "rope_coil", "bucket", "cork_buoy"]),
                   rng.uniform(x0, x1), 0, rng.uniform(-14.6, -13.8), rng.uniform(0, 360)))
    return L


# ------------------------------------------------------------------ composicao A: vila na encosta
def comp_A():
    L = quays() + west_plaza()
    rows = [  # (z_centro_da_casa, y_base, lista de (id, x, cor, telhado))
        (-18.6, 0.0, [("house_b", -13.5), ("house_a", -8.3), ("house_c", -2.6), ("house_d", 2.6), ("house_b", 7.8), ("house_a", 13.0)]),
        (-27.0, 2.6, [("house_a", -11.0), ("house_d", -5.5), ("house_a", 0.5), ("house_c", 6.4), ("house_d", 12.0)]),
        (-35.0, 5.2, [("house_d", -8.0), ("house_a", -2.5), ("house_b", 3.5), ("house_a", 9.0)]),
    ]
    k = 0
    for z, y, hs in rows:
        for hid, x in hs:
            L.append(P(hid, x, y, z, 0, wall=WALL_COLORS[k % 5], roof=("terracotta", "blue", "terracotta")[k % 3]))
            k += 1
    for x in (-16, -8, 0, 8, 16):
        L.append(P("terrace_wall", x, 2.6, -21.6))
        L.append(P("terrace_wall", x - 2, 5.2, -29.8))
    L += [P("stone_stairs", -16.5, 0, -22.9, 0, (1, 1.62, 1)), P("stone_stairs", 17.2, 2.6, -31.1, 0, (1, 1.62, 1))]
    for x, y, z in ((-15.5, 2.6, -24), (16.5, 2.6, -24.5), (-12, 5.2, -33), (14.5, 5.2, -33), (-4.5, 8.0, -40),
                    (6.5, 8.0, -41), (-14, 7.5, -39), (1, 7.5, -42)):
        L.append(P("tree_round" if x % 2 else "tree_round_dark", x, y, z, x * 7))
    for x in (-10.8, -5.4, 2.2, 7.4, 10.4):
        L.append(P("fence_2m", x, 2.6, -22.1))
    L += promenade(-16.0, -10, 14, 11)
    # promontorio e farol a direita
    L += [P("lighthouse", 27.0, 3.0, -21.0, 200), P("rock_a", 23.0, 0.4, -15.5, 20, 2.2), P("rock_b", 25.5, 0.0, -14.5, 70, 2.6),
          P("rock_c", 30.0, 0.5, -15.0, 140, 2.2), P("tree_tall", 22.5, 2.0, -24.0), P("flower_bed", 23.5, 3.0, -18.6, 0, 0.8)]
    L += [P("hills_near", 0, 0, -62, 0, 1.0)]
    return L


# ------------------------------------------------------------------ composicao B: vila na orla
def comp_B():
    L = quays() + west_plaza()
    xs = [-12.4, -7.6, -2.4, 2.8, 7.6, 12.6, 17.4]
    ids = ["house_a", "house_d", "house_c", "house_a", "house_b", "house_d", "house_a"]
    for i, (hid, x) in enumerate(zip(xs, ids)):
        pass
    for i, (x, hid) in enumerate(zip(xs, ids)):
        L.append(P(hid, x, 0, -18.7, 0, wall=WALL_COLORS[i % 5], roof=("terracotta", "blue")[i % 2]))
    # segunda fileira (atras, mais alta), aparece por cima dos telhados no plano aberto
    for i, x in enumerate((-10, -4.5, 1.5, 7.5, 13.5)):
        L.append(P(("house_c", "house_a", "house_b", "house_c", "house_a")[i], x, 1.2, -27.0, 0,
                   wall=WALL_COLORS[(i + 3) % 5], roof=("blue", "terracotta")[i % 2]))
    for x in (-14, -6, 2, 10, 18):
        L.append(P("terrace_wall", x, 1.2, -23.0))
    L += [P("market_stall_red", -9.9, 0, -14.6, 0), P("market_stall_blue", 5.2, 0, -14.6, 0),
          P("market_stall_red", 15.0, 0, -14.6, 0)]
    L += promenade(-16.0, -14, 18, 12)
    for x, z in ((-16, -26), (20, -26), (-1.5, -32), (10.5, -33), (-8, -34)):
        L.append(P("tree_round" if int(x) % 2 else "tree_round_dark", x, 1.2, z, x * 11))
    # farol no fim da baia (ponta leste, alem da praia de rochas)
    L += [P("headland", 0, 0, 0), P("lighthouse", 31.0, 2.4, -24.0, 200), P("tree_round", 26.4, 1.85, -27.5, 40, 0.9),
          P("tree_tall", 35.5, 1.85, -27.0, 0, 0.8), P("flower_bed", 33.6, 2.4, -21.2, 0, 0.6)]
    L += [P("hills_near", 0, 0, -58, 0, 1.0)]
    return L


# ------------------------------------------------------------------ terreno (so estudo; na Godot vira malha/colisao propria)
def terrain(comp, slab, blob):
    g = "#7CCB4A"
    slab("land_north", -60, 40, -70, -19, -0.02, 3.0, g)
    slab("land_west", -70, -20, -19, 30, -0.02, 3.0, g)
    slab("land_south", -20, 12, 3, 40, -0.02, 3.0, g)
    if comp == "A":
        slab("terrace1", -40, 22, -70, -21.6, 2.58, 3.0, g)
        slab("terrace2", -40, 22, -70, -29.8, 5.18, 3.0, g)
        blob("headland", 29, 0, -22, 9, 3.2, 9, "#A9A3B8")
        blob("headland_g", 29, 0.4, -24, 8, 3.0, 7, g)
    else:
        slab("terrace1", -40, 30, -70, -23.0, 1.18, 3.0, g)
        blob("headland", 32, 0, -22, 10, 2.6, 9, "#A9A3B8")
        blob("headland_g", 32, 0.2, -25, 9, 2.4, 8, g)


# ------------------------------------------------------------------ mapa completo (proposta)
MAP_LABELS = [("VILA FAROL 7", -30, -45), ("CAIS", -6, 8), ("FAROL", 22, -36), ("RIO (152 m)", 80, 6),
              ("PONTE", 56, -22), ("BOIA", 86, -9), ("BANCO DE AREIA", 104, 0), ("ENSEADA", 158, 34),
              ("BRACO", 176, -24), ("ILHA", 196, 24), ("ACAMPAMENTO", 186, -6), ("MERCADO", -40, -18)]


def map_terrain(slab, blob):
    g, s = "#7CCB4A", "#F2D9A6"
    terrain("B", slab, blob)
    # margens do rio (x 30..186), largura 28 m (z -14..14) com margens vegetadas
    slab("bank_north", 36, 182, -60, -14, -0.02, 2.0, g)
    slab("bank_south", 12, 158, 14, 60, -0.02, 2.0, g)
    slab("bank_south2", 174, 182, 14, 60, -0.02, 2.0, g)
    slab("enseada_back", 158, 174, 28, 60, -0.02, 2.0, g)
    slab("bridge", 60, 64, -16, 16, 3.6, 0.6, "#C9A57A")
    slab("camp", 194, 200, 0, 6, 0.3, 0.4, "#E2C493")

    # enseada (baia na margem sul) em x 160..176, z 14..30 fica como agua
    slab("sandbar", 112, 126, 3, 9, -0.25, 0.4, s)
    slab("island", 190, 212, -14, 16, -0.01, 2.0, g)
    slab("island_beach", 188.5, 191, -10, 12, -0.15, 0.4, s)


def map_extra():
    L = []
    rng = random.Random(3)
    for i in range(60):
        x = rng.uniform(32, 184)
        side = rng.choice((-1, 1))
        z = side * rng.uniform(16, 30)
        if 160 < x < 176 and side > 0:
            continue
        L.append(P(rng.choice(["tree_round", "tree_round_dark", "tree_tall", "bush_round"]), x, 0, z, rng.uniform(0, 360)))
    for i in range(14):
        L.append(P(rng.choice(["tree_round", "tree_tall"]), rng.uniform(194, 214), 0, rng.uniform(-12, 16), rng.uniform(0, 360)))
    L += [P("cork_buoy", 90, WATER_Y, -3, 0, 3.0), P("boat_hut", 205, 0, 6, 0)]
    for x, z in ((183.5, 6.5), (186.0, 5.0), (188.5, 4.2)):
        L.append(P("rock_b", x, -0.2, z, x * 13, 1.6))
    return L


# ------------------------------------------------------------------ exportacao para a Godot
def export_json(comp, path):
    pl = (comp_A() if comp == "A" else comp_B())
    out = {"comp": comp, "provisional": True, "source": "source_art/environment/village_layout.py",
           "pieces": []}
    for p in pl:
        d = {"id": p[0], "pos": [round(p[1], 3), round(p[2], 3), round(p[3], 3)], "ry": p[4],
             "s": list(p[5]) if isinstance(p[5], tuple) else [p[5]] * 3}
        if len(p) > 6:
            d.update(p[6])
        out["pieces"].append(d)
    for p in sky_and_far():
        if p[0] in ("hills_far", "cloud", "seagull", "rowboat"):
            out["pieces"].append({"id": p[0], "pos": [round(p[1], 3), round(p[2], 3), round(p[3], 3)], "ry": round(p[4], 2),
                                  "s": [p[5]] * 3})
    with open(path, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=1)
    print("LAYOUT_JSON", path, len(out["pieces"]))


if __name__ == "__main__" and "--json" in sys.argv:
    i = sys.argv.index("--json")
    export_json(sys.argv[i + 1], sys.argv[i + 2])
