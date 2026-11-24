"""Layout do mundo do Ep01 alem do porto (RB-R1, PROVISORIO): rio (x 30..182), ilha (x 190..212) e horizonte.
Fonte unica das posicoes -> game/episodes/ep01/world/{river,island,horizon}_layout.json, lidos por gen_world_scenes.gd.
Coordenadas do MUNDO (Godot: x leste, y cima, z sul; metros) conforme LAYOUT_PROPOSTO.md (adotado pelo lead).
Roda dentro do Blender (importa a geografia de build_world.py):
  blender --background --factory-startup --python world_layout.py -- --out game/episodes/ep01/world
"""
import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_world import (bank_top, flat_zone, island_top, land_h, sdf_island, sdf_north, sdf_south, smooth, zN, zS)

WATER_Y = -0.4
FOOTHOLDS = [(183.5, 0.3, 6.5), (186.0, 0.5, 5.0), (188.5, 0.3, 4.2)]
DECOYS = [(184.6, -0.3, 4.2), (185.0, -0.32, 7.4), (187.3, -0.3, 6.7), (187.2, -0.3, 3.0)]
PILOT = (195.0, 0.0, 3.0)
PIER = (190.5, 0.0, -2.0)
# vegetacao e rochas em MultiMesh (sem colisao propria; colisao por cilindros quando "col")
MM = ["tree_round", "tree_round_dark", "tree_tall", "bush_round", "bush_flower", "reeds", "rock_a", "rock_b", "rock_c",
      "grass_tuft", "flower_clump", "palm_tree", "boulder", "shell", "cloud", "hills_far", "hills_near"]


def h_bank(x, z, sdf, flat=None, beach=0.0, top=bank_top):
    return land_h(x, z, sdf, top, flat, beach)


def P(id_, x, y, z, ry=0.0, s=1.0, **kw):
    d = {"id": id_, "pos": [round(x, 3), round(y, 3), round(z, 3)], "ry": round(ry, 1),
         "s": list(s) if isinstance(s, (tuple, list)) else [s, s, s]}
    d.update(kw)
    return d


def river():
    rng = random.Random(11)
    L = [P("river_bank_north", 0, 0, 0), P("river_bank_south", 0, 0, 0), P("sandbar", 0, 0, 0),
         P("arch_bridge", 62.0, 0, 0)]
    for side, sdf, edge, flat in (("N", sdf_north, zN, None), ("S", sdf_south, zS, flat_zone)):
        sg = -1 if side == "N" else 1
        x = 36.0 if side == "N" else 12.0
        while x < 180.0:
            if side == "S" and 157.0 < x < 175.0:       # enseada: praia propria abaixo
                x += 2.0
                continue
            if 58.0 < x < 66.0:                          # cabeceiras da ponte livres
                x += 2.0
                continue
            ze = edge(x)
            # linha d'agua: juncos e pedras
            if rng.random() < 0.75:
                z = ze + sg * rng.uniform(-0.2, 0.9)
                L.append(P("reeds", x + rng.uniform(-0.6, 0.6), WATER_Y + 0.05, z, rng.uniform(0, 360), rng.uniform(0.9, 1.4)))
            if rng.random() < 0.35:
                z = ze + sg * rng.uniform(-0.4, 0.6)
                L.append(P(rng.choice(["rock_a", "rock_b", "rock_c"]), x + rng.uniform(-1, 1), WATER_Y - 0.1, z,
                           rng.uniform(0, 360), rng.uniform(0.9, 1.8)))
            # barranco: arbustos, flores e tufos
            for _ in range(2):
                z = ze + sg * rng.uniform(1.5, 5.0)
                xx = x + rng.uniform(-1, 1)
                y = h_bank(xx, z, sdf, flat) - 0.05
                L.append(P(rng.choice(["bush_round", "bush_flower", "grass_tuft", "flower_clump", "grass_tuft"]), xx, y, z,
                           rng.uniform(0, 360), rng.uniform(0.9, 1.5)))
            # arvores redondas no alto
            if rng.random() < 0.8:
                z = ze + sg * rng.uniform(5.5, 20.0)
                xx = x + rng.uniform(-1, 1)
                y = h_bank(xx, z, sdf, flat) - 0.1
                L.append(P(rng.choice(["tree_round", "tree_round_dark", "tree_round", "tree_tall"]), xx, y, z,
                           rng.uniform(0, 360), rng.uniform(0.9, 1.4)))
            x += 2.0
    # mata no alto das margens (sem plano vazio no aereo)
    for sdf, z0, z1 in ((sdf_north, -74.0, -22.0), (sdf_south, 22.0, 74.0)):
        n = 0
        while n < 150:
            x, z = rng.uniform(38.0, 180.0), rng.uniform(z0, z1)
            if sdf(x, z) < 8.0 or 57.0 < x < 67.0:
                continue
            y = h_bank(x, z, sdf) - 0.15
            L.append(P(rng.choice(["tree_round", "tree_round_dark", "tree_round_dark", "tree_tall", "bush_round"]), x, y, z,
                       rng.uniform(0, 360), rng.uniform(1.0, 1.6)))
            n += 1
    # cabana de pescador e pier de pesca (margem norte, x 100)
    zh = zN(100.0)
    L.append(P("boat_hut", 100.0, h_bank(100.0, zh - 7.0, sdf_north) - 0.05, zh - 7.0, 180.0))
    L.append(P("pier_small", 104.0, 0.25, zh - 1.5, 180.0, (1.0, 1.0, 0.7)))
    L.append(P("rowboat", 106.2, WATER_Y + 0.05, zh + 2.2, 80.0))
    L.append(P("fishing_net", 101.8, h_bank(101.8, zh - 5.0, sdf_north), zh - 5.0, 0.0))
    L.append(P("barrel", 98.3, h_bank(98.3, zh - 4.6, sdf_north), zh - 4.6, 0.0))
    # banco de areia: conchas e uma gaivota pousada
    for i in range(14):
        a = rng.uniform(0, math.tau)
        r = math.sqrt(rng.random())
        L.append(P("shell", 119 + 5.5 * r * math.cos(a), -0.2, 6 + 2.2 * r * math.sin(a), rng.uniform(0, 360), rng.uniform(1.0, 1.8)))
    L.append(P("gull_standing", 118.2, -0.19, 5.4, 120.0, 1.3))
    L.append(P("gull_standing", 121.0, -0.19, 6.6, 300.0, 1.2))
    # enseada (166, 21): praia, palmeiras, barquinho, rochedos
    for a_deg in range(20, 170, 22):
        a = math.radians(a_deg)
        x, z = 166 + 10.5 * math.cos(a), 21 + 10.5 * math.sin(a)
        L.append(P("palm_tree", x, h_bank(x, z, sdf_south) - 0.1, z, a_deg * 3, rng.uniform(0.9, 1.2)))
    for a_deg in (5, 95, 175):
        a = math.radians(a_deg)
        x, z = 166 + 8.4 * math.cos(a), 21 + 8.4 * math.sin(a)
        L.append(P("boulder", x, h_bank(x, z, sdf_south) - 0.4, z, a_deg, 0.9))
    L.append(P("rowboat", 163.5, h_bank(163.5, 27.5, sdf_south) + 0.25, 27.5, 30.0, 1.0))
    L.append(P("crate_peach", 168.0, h_bank(168.0, 28.2, sdf_south), 28.2, 10.0))
    # pouso de Pico (margem oeste do braco, topo y = 0)
    L += [P("dock_post", 181.5, 0.0, 3.8, 0.0), P("rope_coil", 180.6, 0.0, 6.0, 40.0), P("sign_board", 178.4, 0.0, 12.5, -60.0),
          P("crate_s", 177.2, 0.0, 14.2, 20.0)]
    boxes = [{"name": "PicoLanding", "size": [6.4, 1.0, 16.4], "pos": [178.75, -0.5, 9.8]}]
    return {"root": "RiverWorld", "pieces": L, "boxes": boxes}


def island():
    rng = random.Random(12)
    L = [P("island_ground", 0, 0, 0)]
    for i, (x, y, z) in enumerate(FOOTHOLDS):
        L.append(P("step_rock_safe", x, y, z, i * 70.0, 1.0, name="SafeRock%d" % i))
    for i, (x, y, z) in enumerate(DECOYS):
        L.append(P("step_rock_decoy", x, y, z, i * 50.0, rng.uniform(0.8, 1.1), name="DecoyRock%d" % i))
    # acampamento do piloto (piloto em (195, 0, 3) fica livre)
    L += [P("tent", 197.6, 0.0, 6.4, -90.0, name="CampTent"), P("campfire", 194.6, 0.0, 5.6, 0.0, name="CampFire"),
          P("crate_l", 198.0, 0.0, 1.6, 15.0, name="CampCrate"), P("flag_pole", 199.2, 0.0, 4.0, 0.0, name="CampFlag"),
          P("barrel", 197.2, 0.0, 0.6, 0.0), P("rope_coil", 196.3, 0.0, 8.6, 30.0), P("bucket", 193.6, 0.0, 6.8, 0.0)]
    L.append(P("pier_small", 191.8, 0.0, PIER[2], 90.0, name="IslandPier"))
    L.append(P("dock_post", 188.9, 0.0, -3.3, 0.0))
    # vegetacao: palmeiras e arvores redondas na borda, rochedos na costa leste/norte
    for k in range(18):
        a = k * math.tau / 18 + rng.uniform(-0.1, 0.1)
        rr = rng.uniform(0.72, 0.86)
        x, z = 201 + 11 * rr * math.cos(a), 1 + 15 * rr * math.sin(a)
        if (x < 193.5 and -5 < z < 9) or math.hypot(x - 196.5, z - 5.0) < 4.5:   # costa oeste e acampamento livres
            continue
        y = h_bank(x, z, sdf_island, lambda xx, zz: xx < 205.0, beach=1.0, top=island_top) - 0.1
        L.append(P(rng.choice(["palm_tree", "palm_tree", "tree_round", "tree_round_dark"]), x, y, z, rng.uniform(0, 360),
                   rng.uniform(0.9, 1.25), col=True))
    for k in range(9):
        a = 0.3 + k * 0.62
        x, z = 201 + 11.2 * math.cos(a - 1.3), 1 + 15.4 * math.sin(a - 1.3)
        L.append(P("boulder", x, -0.6, z, k * 40.0, rng.uniform(0.8, 1.4), col=True))
    for i in range(70):
        x, z = rng.uniform(192, 210), rng.uniform(-12, 14)
        if sdf_island(x, z) < 1.2 or math.hypot(x - PILOT[0], z - PILOT[2]) < 1.5 or (x < 194.5 and -4 < z < 9):
            continue
        y = h_bank(x, z, sdf_island, lambda xx, zz: xx < 205.0, beach=1.0, top=island_top) - 0.02
        L.append(P(rng.choice(["grass_tuft", "grass_tuft", "flower_clump", "bush_round", "bush_flower"]), x, y, z,
                   rng.uniform(0, 360), rng.uniform(0.9, 1.4)))
    boxes = [{"name": "IslandFloor", "size": [15.0, 1.0, 22.0], "pos": [199.0, -0.5, 1.0]}]
    return {"root": "IslandWorld", "pieces": L, "boxes": boxes}


def horizon():
    rng = random.Random(13)
    L = [P("far_water", 0, 0, 0)]
    c = (85.0, -10.0)
    for k in range(16):
        a = k * math.tau / 16
        x, z = c[0] + 330 * math.cos(a), c[1] + 260 * math.sin(a)
        ry = math.degrees(math.atan2(c[0] - x, c[1] - z))
        L.append(P("hills_far", x, -0.3, z, ry, (1.0, rng.uniform(0.8, 1.4), 1.0)))
    for k in range(12):
        a = k * math.tau / 12 + 0.2
        x, z = 55.0 + 265 * math.cos(a), 155 * math.sin(a)     # fora do retangulo do WaterSurface
        if -40 < x < 60 and z < -40:       # atras da vila ja ha morros do porto
            continue
        ry = math.degrees(math.atan2(c[0] - x, c[1] - z))
        L.append(P("hills_near", x, -0.3, z, ry, (rng.uniform(1.0, 1.6), rng.uniform(0.8, 1.3), 1.0)))
    for i in range(22):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(150, 300)
        L.append(P("cloud", c[0] + r * math.cos(a), rng.uniform(40, 70), c[1] + r * 0.8 * math.sin(a), rng.uniform(0, 360),
                   rng.uniform(1.8, 3.2)))
    return {"root": "Horizon", "pieces": L, "boxes": []}


def main():
    out = sys.argv[sys.argv.index("--out") + 1]
    for nm, fn in (("river", river), ("island", island), ("horizon", horizon)):
        d = fn()
        d.update({"provisional": True, "source": "source_art/environment/world_layout.py", "multimesh": MM})
        p = os.path.join(out, nm + "_layout.json")
        with open(p, "w", encoding="utf-8") as f:
            json.dump(d, f, indent=0)
        print("LAYOUT_JSON", p, len(d["pieces"]))


if "--out" in sys.argv:
    main()
