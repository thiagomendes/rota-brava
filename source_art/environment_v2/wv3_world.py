"""Rota Brava · Ep01 v3 (RB-R1 E3) · geometria que faltava na vila v2.1 para as missoes M0-M8. PROVISORIO.

Tudo do zero (wv2lib: caixas, tornos, prismas, tubos, esferas; numpy para os decalques). Coordenadas da Godot
(x leste, y cima, z sul; metros), mesmo referencial do Ep01Layout. Chamado por build_world_v2.py.

Estatico (vai para wv2_static.glb, dentro dos objetos existentes ou no novo wv2_lighthouse):
  - farol com 3 patamares externos + galeria (subida do Pico, ~4,8 m), sala da lanterna com vidro (a lanterna e peca solta)
  - chafariz com 3 degraus (0,5 / 1,0 / 1,5 m), bacia superior, canaleta e grade (M3)
  - galpao da margem com anexo de topo plano a 1,6 m + 2 degraus (0,5 / 1,0) e galho baixo na arvore do varal (M2)
  - placas com icone de fruta (sem texto) nas 3 barracas da praca (M4)
  - ponta de corda solta na estaca do cais (amarra vazia do bote, M1)
Pecas soltas (wv3_props.glb, um no por peca, origem no pivo):
  wv3_lantern (gira em Y; filho wv3_lantern_beam = cone do feixe), wv3_dinghy (bote do capitao encalhado),
  wv3_buoy_a / wv3_buoy_b (boias de rota), wv3_festa_boat_1..4 (barquinhos com lanterna), wv3_festa_lanterns
  (lanternas penduradas da festa), wv3_lens (lente caida do farol)
Decalques (texturas RGBA): decal_paw, decal_paw_wet, decal_feather, decal_scale.
"""
import math
import os
import random

import bpy
from mathutils import Vector

import wv2_kit as KIT
import wv2_textures as TX
from wv2lib import MB, R, T, hexc

LH = (31.0, 2.4, -24.0)          # farol (base do embasamento em y 2,0; topo do embasamento 3,0)
LH_BASE_Y = 3.0
LH_H = 13.0
LH_TOP = LH_BASE_Y + LH_H        # 16,0: topo da torre
LANTERN_Y = LH_TOP + 0.75        # piso da sala da lanterna (pivo da lanterna)
# patamares (angulo em graus no plano xz: 0 = +x leste, 90 = +z sul) e altura do piso
LANDINGS = [(95.0, 4.2), (55.0, 5.4), (15.0, 6.6)]   # lado sul/sudeste: visivel da bacia e fora da casa do faroleiro
STAIR_STEP_ANG = 112.0
GALLERY_DOOR_ANG = 330.0
GALLERY_Y = 7.8
GALLERY_W = 0.8
FOUNTAIN = (-22.8, 3.6)
# degraus do chafariz: lado leste (de frente para a vista baixa da praca)
FOUNTAIN_STEP_ANG = 20.0
CHANNEL = ((-24.28, 2.12), (-25.75, 0.65))   # canaleta da borda do chafariz ate a grade, junto a barraca amarela
GRATE = (-25.95, 0.45)
STALLS = [  # (kit, x, z, ry, fruta)  mesmas posicoes de street_props()
    ("stall_red", -26.0, -9.6, 90.0, "apple"),
    ("stall_yellow", -26.0, -1.2, 90.0, "lemon"),
    ("stall_blue", -19.2, -6.4, -90.0, "grapes"),
]
SHED_M2 = (9.5, 9.2, 200.0)      # galpao da margem (origem da casa, ry)
TREE_M2 = (15.5, 6.5)            # arvore do varal
DINGHY = (26.4, -9.9, 205.0)     # bote do capitao, proa encalhada no promontorio
BUOYS = [("wv3_buoy_a", 5.0, -9.2, "red"), ("wv3_buoy_b", 11.5, -6.6, "green")]
FESTA_BOATS = [  # (x, z, ry, cor do casco, icone)  4 direcoes vistas do farol
    (9.0, -9.0, 30.0, "#3D7DC4", "star"),
    (21.5, -4.0, 80.0, "#E8553E", "moon"),
    (40.0, -2.5, 140.0, "#3E9A57", "fish"),
    (52.0, -15.0, 190.0, "#F2B632", "flower"),
]
LENS = (25.8, -21.8)
PAPER_COLS = ["#FF5A4E", "#FFC93C", "#FF8A3D", "#FF8FB1", "#7FD07A", "#FFFFFF"]

lantern_points = []   # posicoes das lanternas de festa (para as luzes da noite na Godot)


def lh_radius(y):
    return 2.1 - 0.6 * (y - LH_BASE_Y) / LH_H


def polar(a_deg, r, y):
    a = math.radians(a_deg)
    return (LH[0] + math.cos(a) * r, y, LH[2] + math.sin(a) * r)


# ================================================================== farol
def lighthouse(m, house_fn, house_params, lights):
    """Farol completo em `m` (substitui build_lighthouse): torre listrada, janelas, sala da lanterna com vidro e
    caixilhos (sem a lanterna, que e peca solta), cupula, casa do faroleiro, 3 patamares e galeria externa."""
    bx, by, bz = LH
    pal_red, cream = hexc("#D9473A"), hexc("#FFF6EA")
    iron, wood = hexc("#2B2F33"), hexc("#A07A56")
    m.lathe((bx, by - 0.4, bz), [(3.0, 0.0), (3.0, 0.9), (2.7, 1.0), (0.0, 1.0)], "wv2_stone", (1, 1, 1), seg=32)
    y = LH_BASE_Y
    bands = 6
    for k in range(bands):
        y0 = y + LH_H * k / bands
        y1 = y + LH_H * (k + 1) / bands
        m.lathe((bx, 0, bz), [(lh_radius(y0), y0), (lh_radius(y1), y1)], "wv2_plaster", pal_red if k % 2 else cream, seg=32)
    for k in range(4):
        a = k * 1.9
        yy = y + 2.5 + k * 2.8
        r = lh_radius(yy) + 0.02
        m.box((bx + math.sin(a) * r, yy, bz + math.cos(a) * r), (0.5, 0.8, 0.12), "wv2_glass", (1, 1, 1), 0.0, 1,
              rot=R(ry=math.degrees(a)))
        m.box((bx + math.sin(a) * (r + 0.04), yy - 0.45, bz + math.cos(a) * (r + 0.04)), (0.7, 0.1, 0.16), "wv2_stone", (1, 1, 1),
              0.02, 1, rot=R(ry=math.degrees(a)))
    top = LH_TOP
    m.cyl((bx, top, bz), 2.1, 0.25, "wv2_stone", (1, 1, 1), seg=32, bevel=0.04)
    for k in range(28):
        a = k / 28 * 2 * math.pi
        m.cyl((bx + math.cos(a) * 1.95, top + 0.25, bz + math.sin(a) * 1.95), 0.025, 0.9, "wv2_metal", iron, seg=6)
    ring = [(bx + math.cos(a) * 1.95, top + 1.15, bz + math.sin(a) * 1.95) for a in [i / 40 * 6.2832 for i in range(41)]]
    m.tube(ring, 0.04, "wv2_metal", iron, seg=6, caps=False)
    m.cyl((bx, top + 0.25, bz), 1.1, 0.5, "wv2_plaster", cream, seg=24)
    # sala da lanterna: vidro (transparente) e 8 caixilhos; a lanterna giratoria fica dentro (wv3_props.glb)
    m.cyl((bx, top + 0.75, bz), 0.95, 1.6, "wv2_glass", (1, 1, 1), seg=24, caps=False)
    for k in range(8):
        a = k / 8 * 2 * math.pi
        m.box((bx + math.cos(a) * 0.97, top + 1.55, bz + math.sin(a) * 0.97), (0.06, 1.6, 0.06), "wv2_metal", iron, 0.0, 1)
    m.lathe((bx, top + 2.35, bz), [(1.25, 0.0), (1.2, 0.1), (0.9, 0.5), (0.4, 0.9), (0.12, 1.1), (0.0, 1.15)], "wv2_glossy",
            pal_red, seg=24)
    m.lathe((bx, top + 3.45, bz), [(0.0, 0.0), (0.1, 0.0), (0.14, 0.15), (0.0, 0.32)], "wv2_metal", hexc("#C9A13A"), seg=10)
    lights.append(("lighthouse", (bx, top + 1.5, bz)))
    p = house_params(4.4, 1, "gable", "cream", "red", dict(chimneys=1, ground="door", shutter=pal_red, cols=2, door_col=0),
                     detail=1)
    p["D"] = 4.0
    house_fn(m, (27.0, 2.4, -19.0), -90, p, 400, lights)
    rng = random.Random(91)
    # --- patamares externos (subida do Pico: piso a 4,2 / 5,4 / 6,6; o embasamento fica a 3,0)
    for ang, fy in LANDINGS:
        rt = lh_radius(fy)
        rc = rt + 0.42
        cx, _, cz = polar(ang, rc, fy)
        ry = 90.0 - ang          # eixo local z aponta para fora (radial)
        m.box((cx, fy - 0.05, cz), (1.15, 0.1, 0.84), "wv2_deck", (1, 1, 1), 0.012, 1, rot=R(ry=ry), grain="x", rng=rng)
        # tabuas de borda e mao-francesa de ferro presa na torre
        for s in (-0.5, 0.5):
            px, _, pz = polar(ang + math.degrees(s * 1.0 / rc), rt + 0.05, fy)
            ox, _, oz = polar(ang + math.degrees(s * 1.0 / rc), rt + 0.8, fy)
            m.tube([(px, fy - 0.75, pz), (ox, fy - 0.1, oz)], 0.03, "wv2_metal", iron, seg=6)
            m.tube([(px, fy - 0.11, pz), (ox, fy - 0.11, oz)], 0.028, "wv2_metal", iron, seg=6)
        # guarda-corpo na borda de fora (deixa os lados abertos: o Pico pula de um patamar ao outro)
        posts = []
        for k in range(4):
            t = -0.5 + k / 3
            px, _, pz = polar(ang + math.degrees(t * 1.05 / (rt + 0.82)), rt + 0.82, fy)
            m.cyl((px, fy, pz), 0.022, 0.85, "wv2_metal", iron, seg=6)
            posts.append((px, fy + 0.85, pz))
        m.tube(posts, 0.028, "wv2_metal", iron, seg=6, caps=True)
        m.tube([(p_[0], p_[1] - 0.45, p_[2]) for p_ in posts], 0.016, "wv2_metal", iron, seg=5, caps=True)
        # vaso de flor no patamar mais baixo (leitura de "lugar onde se pisa")
        if fy < 4.5:
            px, _, pz = polar(ang + 14.0, rt + 0.35, fy)
            m.lathe((px, fy, pz), [(0.0, 0.0), (0.1, 0.0), (0.13, 0.22), (0.0, 0.22)], "wv2_glossy", hexc("#D27A4E"), seg=10)
            m.sphere((px, fy + 0.3, pz), 0.14, "wv2_leaf", hexc("#58A83F"), subd=1, seed=7, amp=0.25)
    # --- galeria (anel) com mísulas de pedra, piso de tabuas e guarda-corpo
    rt = lh_radius(GALLERY_Y)
    ro = rt + GALLERY_W
    m.lathe((bx, 0, bz), [(rt + 0.02, GALLERY_Y - 0.14), (ro, GALLERY_Y - 0.14), (ro, GALLERY_Y), (rt + 0.02, GALLERY_Y)],
            "wv2_deck", (1, 1, 1), seg=36)
    m.lathe((bx, 0, bz), [(ro + 0.04, GALLERY_Y - 0.2), (ro + 0.04, GALLERY_Y - 0.12), (ro - 0.06, GALLERY_Y - 0.12),
                          (ro - 0.06, GALLERY_Y - 0.2)], "wv2_stone", (1, 1, 1), seg=36)
    # cornija conica de pedra sob a galeria (le como misula continua) + friso
    m.lathe((bx, 0, bz), [(lh_radius(GALLERY_Y - 0.75) + 0.01, GALLERY_Y - 0.75), (rt + 0.25, GALLERY_Y - 0.45),
                          (ro - 0.12, GALLERY_Y - 0.2), (ro - 0.12, GALLERY_Y - 0.14)], "wv2_stone", (1, 1, 1), seg=36)
    m.lathe((bx, 0, bz), [(lh_radius(GALLERY_Y - 0.9) + 0.02, GALLERY_Y - 0.9), (lh_radius(GALLERY_Y - 0.9) + 0.06, GALLERY_Y - 0.86),
                          (lh_radius(GALLERY_Y - 0.75) + 0.06, GALLERY_Y - 0.79), (lh_radius(GALLERY_Y - 0.75) + 0.02, GALLERY_Y - 0.75)],
            "wv2_stone", (1, 1, 1), seg=36)
    posts = []
    for k in range(24):
        a = k / 24 * 360.0
        px, _, pz = polar(a, ro - 0.04, GALLERY_Y)
        m.cyl((px, GALLERY_Y, pz), 0.02, 0.9, "wv2_metal", iron, seg=6)
    for hh in (0.9, 0.45):
        ring = [polar(i / 48 * 360.0, ro - 0.04, GALLERY_Y + hh) for i in range(49)]
        m.tube(ring, 0.03 if hh > 0.5 else 0.016, "wv2_metal", iron, seg=6, caps=False)
    # porta da galeria (sul) e lampiao
    da = GALLERY_DOOR_ANG
    dx, _, dz = polar(da, rt + 0.03, GALLERY_Y)
    m.box((dx, GALLERY_Y + 0.85, dz), (0.8, 1.7, 0.08), "wv2_paint", hexc("#2E4F7A"), 0.01, 1, rot=R(ry=90.0 - da))
    lx, _, lz = polar(da + 22.0, rt + 0.12, GALLERY_Y + 1.6)
    m.sphere((lx, GALLERY_Y + 1.6, lz), 0.08, "wv2_lamp", hexc("#FFE0A0"), subd=1)
    lights.append(("wall_lamp", (lx, GALLERY_Y + 1.6, lz)))
    # placas de piso no embasamento (degrau de chegada da escada) e caixote de apoio no chao (0,6 m)
    cx, _, cz = polar(STAIR_STEP_ANG, 3.35, 2.4)
    m.box((cx, 2.55, cz), (0.9, 0.3, 0.7), "wv2_stone", (1, 1, 1), 0.03, 1, rot=R(ry=90.0 - STAIR_STEP_ANG), rng=rng)


# ================================================================== chafariz
def fountain(m, rng):
    """Chafariz da praca (M3): degrau largo, bacia baixa com borda a 0,5 m, pedestal a 1,0 m, patamar a 1,5 m junto a
    bacia superior (borda 1,55), coluna com bica, canaleta de pedra seca ate a grade de ferro perto da barraca amarela."""
    fx, fz = FOUNTAIN
    blue, foam = hexc("#3FA7C9"), hexc("#BFE9F5")
    m.lathe((fx, 0, fz), [(0.0, 0.0), (2.05, 0.0), (2.08, 0.04), (2.08, 0.22), (2.02, 0.26), (0.0, 0.26)], "wv2_stone",
            (0.95, 0.95, 0.97), seg=32)
    m.lathe((fx, 0, fz), [(0.0, 0.0), (1.55, 0.0), (1.6, 0.1), (1.6, 0.46), (1.5, 0.5), (1.38, 0.46), (1.38, 0.25), (0.0, 0.25)],
            "wv2_stone", (1, 1, 1), seg=28)
    m.cyl((fx, 0.36, fz), 1.38, 0.02, "wv2_glossy", blue, seg=28)
    # 3 degraus concentricos (bolo de noiva): borda baixa 0,5 -> tambor 1,0 (anel de 0,4 m) -> borda da bacia de cima 1,5
    m.lathe((fx, 0, fz), [(1.1, 0.25), (1.1, 0.86), (1.15, 0.9), (1.15, 1.0), (0.0, 1.0)], "wv2_stone", (0.97, 0.96, 0.98), seg=28)
    m.lathe((fx, 0, fz), [(1.105, 0.5), (1.13, 0.52), (1.13, 0.6), (1.105, 0.62)], "wv2_stone", (0.9, 0.88, 0.9), seg=28)
    m.lathe((fx, 0, fz), [(0.6, 1.0), (0.7, 1.06), (0.72, 1.38), (0.76, 1.43), (0.76, 1.5), (0.58, 1.5), (0.56, 1.36),
                          (0.0, 1.36)], "wv2_stone", (1, 1, 1), seg=24)
    m.cyl((fx, 1.42, fz), 0.57, 0.02, "wv2_glossy", blue, seg=20)
    # folhas entupindo a bacia de cima (o Pico puxa com o gancho)
    for k in range(8):
        a = math.radians(200 + k * 14)
        r = 0.22 + rng.uniform(0.0, 0.28)
        m.prism((fx + math.cos(a) * r, 1.45, fz + math.sin(a) * r), [(0, -0.07), (0.05, 0), (0, 0.08), (-0.05, 0)], 0.01,
                "wv2_leaf", hexc(rng.choice(["#C98A2E", "#B5652A", "#8A9A3A"])), rot=R(rx=90, rz=rng.uniform(0, 180)))
    # bica central (sem jorro: o chafariz esta parado no M3; a agua volta na Godot)
    m.lathe((fx, 1.36, fz), [(0.12, 0.0), (0.09, 0.5), (0.17, 0.58), (0.19, 0.66), (0.0, 0.74)], "wv2_stone", (1, 1, 1), seg=16)
    # bica de saida na borda baixa, virada para a canaleta
    ca = math.atan2(CHANNEL[0][1] - fz, CHANNEL[0][0] - fx)
    m.box((fx + math.cos(ca) * 1.7, 0.42, fz + math.sin(ca) * 1.7), (0.5, 0.08, 0.16), "wv2_stone", (0.95, 0.95, 0.97), 0.02, 1,
          rot=R(ry=-math.degrees(ca)))
    # boca de saida na borda baixa (lado da canaleta) e canaleta de pedra com fundo seco
    (ax, az), (bx, bz) = CHANNEL
    L = math.hypot(bx - ax, bz - az)
    cang = math.degrees(math.atan2(-(bz - az), bx - ax))
    mx, mz = (ax + bx) / 2, (az + bz) / 2
    for s in (-1, 1):
        ox, oz = -math.sin(math.radians(-cang)) * 0.0, 0.0
        nx, nz = (bz - az) / L * 0.16 * s, -(bx - ax) / L * 0.16 * s
        m.box((mx + nx, 0.06, mz + nz), (L, 0.12, 0.1), "wv2_stone", (0.95, 0.95, 0.97), 0.02, 1, rot=R(ry=cang), rng=rng)
    m.box((mx, 0.012, mz), (L, 0.02, 0.24), "wv2_stone", (0.8, 0.78, 0.76), 0.0, 1, rot=R(ry=cang), rng=rng)
    # grade: caixa de pedra com barras de ferro (a bola fica presa dentro)
    gx, gz = GRATE
    m.box((gx, 0.05, gz), (0.7, 0.1, 0.7), "wv2_stone", (0.95, 0.95, 0.97), 0.025, 1, rot=R(ry=cang), rng=rng)
    m.box((gx, 0.0, gz), (0.5, 0.02, 0.5), "wv2_rock", hexc("#2A2F2A"), 0.0, 1, rot=R(ry=cang))
    for k in range(6):
        off = -0.21 + k * 0.084
        m.box((gx + math.cos(math.radians(-cang)) * off, 0.1, gz + math.sin(math.radians(-cang)) * off), (0.03, 0.03, 0.52),
              "wv2_metal", hexc("#2B2F33"), 0.0, 1, rot=R(ry=cang))


# ================================================================== barracas
def stall_icons(m, rng):
    """Placa redonda sem texto no alto de cada barraca da praca, com o icone da fruta dos dois lados (M4)."""
    for kind, x, z, ry, fruit in STALLS:
        xf = T(x, 0, z) @ R(ry=ry)
        rim = {"stall_red": hexc("#E8442E"), "stall_yellow": hexc("#F2B632"), "stall_blue": hexc("#2F7FD8")}[kind]
        m.cyl((0, 0, 0), 0.035, 0.55, "wv2_wood", hexc("#B48A60"), seg=8, rot=xf @ T(0, 2.5, 0))
        m.cyl((0, 0, 0), 0.36, 0.06, "wv2_paint", rim, seg=24, rot=xf @ T(0, 3.12, -0.03) @ R(rx=90), bevel=0.012)
        m.cyl((0, 0, 0), 0.3, 0.075, "wv2_paint", hexc("#FFF4E0"), seg=24, rot=xf @ T(0, 3.12, -0.0375) @ R(rx=90))
        for side in (1, -1):
            f = xf @ T(0, 3.12, side * 0.045) @ R(ry=0 if side > 0 else 180)
            if fruit == "apple":
                m.sphere((0, 0, 0), 0.17, "wv2_glossy", hexc("#E8442E"), subd=2, scale=(1.0, 0.92, 0.32), rot=f @ T(0, -0.02, 0))
                m.cyl((0, 0, 0), 0.015, 0.1, "wv2_wood", hexc("#6B4A2E"), seg=6, rot=f @ T(0, 0.12, 0.01) @ R(rz=-15))
                m.prism((0, 0, 0), [(0, 0), (0.06, 0.04), (0.13, 0.0), (0.06, -0.035)], 0.012, "wv2_glossy", hexc("#4FA83D"),
                        rot=f @ T(0.02, 0.17, 0.02) @ R(rz=20))
            elif fruit == "lemon":
                m.sphere((0, 0, 0), 0.15, "wv2_glossy", hexc("#F7D531"), subd=2, scale=(1.3, 0.88, 0.32), rot=f @ R(rz=-18))
                for s in (-1, 1):
                    m.sphere((0, 0, 0), 0.035, "wv2_glossy", hexc("#F7D531"), subd=1, rot=f @ R(rz=-18) @ T(s * 0.2, 0, 0.0))
                m.prism((0, 0, 0), [(0, 0), (0.06, 0.04), (0.13, 0.0), (0.06, -0.035)], 0.012, "wv2_glossy", hexc("#4FA83D"),
                        rot=f @ T(0.05, 0.12, 0.02) @ R(rz=35))
            else:
                for gx, gy in ((-0.08, 0.08), (0.0, 0.09), (0.08, 0.08), (-0.04, 0.0), (0.04, 0.0), (0.0, -0.08),
                               (-0.08, -0.0), (0.08, 0.0)):
                    m.sphere((0, 0, 0), 0.055, "wv2_glossy", hexc("#6B4FC8"), subd=1, scale=(1, 1, 0.6), rot=f @ T(gx, gy - 0.02, 0.01))
                m.sphere((0, 0, 0), 0.05, "wv2_glossy", hexc("#6B4FC8"), subd=1, scale=(1, 1, 0.6), rot=f @ T(0.0, -0.15, 0.01))
                m.cyl((0, 0, 0), 0.014, 0.09, "wv2_wood", hexc("#6B4A2E"), seg=6, rot=f @ T(0, 0.12, 0.01))
                m.prism((0, 0, 0), [(0, 0), (0.06, 0.04), (0.13, 0.0), (0.06, -0.035)], 0.012, "wv2_glossy", hexc("#4FA83D"),
                        rot=f @ T(0.02, 0.17, 0.02) @ R(rz=10))


# ================================================================== margem: anexo do galpao e galho
def shed_local(lx, lz):
    x0, z0, ry = SHED_M2
    a = math.radians(ry)
    return (x0 + lx * math.cos(a) + lz * math.sin(a), z0 - lx * math.sin(a) + lz * math.cos(a))


ANNEX = (-1.9, 0.0, -3.2, -0.6, 1.6)          # x0, x1, z0, z1 (locais do galpao), topo acima do chao
STEPS_M2 = [(-1.9, -1.1, -0.6, 0.0, 1.0), (-1.9, -1.2, 0.0, 0.6, 0.5)]


def bank_extras(m, ground, rng):
    """Anexo de tabuas com topo plano (1,6 m) no lado leste do galpao da margem + 2 degraus (caixotes 0,5 e 1,0 m) +
    galho baixo e grosso na arvore do varal (topo ~1,6 m). `ground(x, z)` = altura do terreno."""
    x0, z0, ry = SHED_M2
    wood, dark = hexc("#A88560"), hexc("#8E6E4E")

    def lbox(lx0, lx1, lz0, lz1, y0, y1, mat, col, bev=0.015, base=None):
        cx, cz = shed_local((lx0 + lx1) / 2, (lz0 + lz1) / 2)
        gy = ground(cx, cz) - 0.05 if base is None else base
        m.box((cx, gy + (y0 + y1) / 2, cz), (lx1 - lx0, y1 - y0, lz1 - lz0), mat, col, bev, 1, rot=R(ry=ry), rng=rng)
        return gy

    ax0, ax1, az0, az1, top = ANNEX
    cx, cz = shed_local((ax0 + ax1) / 2, (az0 + az1) / 2)
    gy = ground(cx, cz) - 0.05
    # paredes de tabuas verticais (3 lados), laje de tabuas com beiral e testeira
    lbox(ax0, ax1, az0, az1, -0.3, top - 0.12, "wv2_wood", dark, 0.0, base=gy)
    n = 9
    for k in range(n):
        t = (k + 0.5) / n
        lbox(ax0 - 0.02, ax0 + 0.02, az0 + (az1 - az0) * t - 0.13, az0 + (az1 - az0) * t + 0.13, -0.3, top - 0.12, "wv2_wood",
             tuple(c * rng.uniform(0.92, 1.05) for c in wood), 0.008, base=gy)
    lbox(ax0 - 0.08, ax1 + 0.02, az0 - 0.08, az1 + 0.08, top - 0.12, top, "wv2_deck", (1, 1, 1), 0.012, base=gy)
    lbox(ax0 - 0.1, ax0 - 0.04, az0 - 0.08, az1 + 0.08, top - 0.2, top - 0.04, "wv2_paint", hexc("#3F7FD8"), 0.006, base=gy)
    # porta de tabuas e redes penduradas na frente
    lbox(ax0 + 0.35, ax1 - 0.35, az1, az1 + 0.04, 0.0, 1.3, "wv2_paint", hexc("#2F9C95"), 0.008, base=gy)
    # degraus (caixotes empilhados: 0,5 e 1,0 m)
    for k, (sx0, sx1, sz0, sz1, h) in enumerate(STEPS_M2):
        c2x, c2z = shed_local((sx0 + sx1) / 2, (sz0 + sz1) / 2)
        g2 = ground(c2x, c2z) - 0.04
        nlay = int(round(h / 0.5))
        for j in range(nlay):
            lbox(sx0 + 0.02 * j, sx1 - 0.02 * j, sz0 + 0.02 * j, sz1 - 0.02 * j, j * 0.5 - (0.2 if j == 0 else 0), (j + 1) * 0.5,
                 "wv2_wood", hexc("#D8B489") if (j + k) % 2 == 0 else hexc("#C9A37A"), 0.02, base=g2)
            # ripas do caixote
            lbox(sx0 + 0.02 * j - 0.01, sx1 - 0.02 * j + 0.01, sz1 - 0.02 * j - 0.01, sz1 - 0.02 * j + 0.012,
                 j * 0.5 + 0.2, j * 0.5 + 0.3, "wv2_wood", hexc("#B48A60"), 0.0, base=g2)
    # galho baixo na arvore do varal: sai do tronco a ~1,3 m e sobe ate ~1,6 m na direcao do galpao
    tx, tz = TREE_M2
    gy = ground(tx, tz)
    dirx, dirz = -0.86, 0.5
    pts = []
    for i in range(7):
        t = i / 6
        pts.append((tx + dirx * (0.15 + 1.7 * t), gy + 1.3 + 0.32 * math.sin(t * 1.4), tz + dirz * (0.15 + 1.7 * t)))
    m.tube(pts, lambda t: 0.16 - 0.08 * t, "wv2_bark", hexc("#7A5636"), seg=8)
    ex, ey, ez = pts[-1]
    m.sphere((ex + dirx * 0.2, ey + 0.35, ez + dirz * 0.2), 0.5, "wv2_leaf", hexc("#5DAE40"), subd=2, scale=(1.2, 0.75, 1.0),
             seed=17, amp=0.22)
    m.sphere((ex - dirx * 0.4, ey + 0.45, ez - dirz * 0.3), 0.38, "wv2_leaf", hexc("#58A83F"), subd=1, scale=(1.1, 0.7, 1.0),
             seed=18, amp=0.25)
    return {"branch": pts}


def dock_loose_rope(m):
    """Amarra vazia (M1): na estaca de canto oeste-norte do cais, a corda do bote do capitao ficou solta e cai na agua."""
    x, z = -7.6, -3.12
    pts = [(x + 0.18, 0.5, z), (x + 0.35, 0.32, z - 0.12), (x + 0.42, 0.05, z - 0.25), (x + 0.48, -0.3, z - 0.42),
           (x + 0.7, -0.4, z - 0.7), (x + 1.0, -0.41, z - 0.82)]
    m.tube(pts, 0.022, "wv2_rope", hexc("#D9C38B"), seg=6)


# ================================================================== pecas soltas
def _place(ob, x, y, z, ry=0.0, rx=0.0, rz=0.0):
    ob.location = (x, -z, y)
    ob.rotation_mode = "YXZ"
    ob.rotation_euler = (math.radians(rx), -math.radians(rz), math.radians(ry))


def _to_godot_rot(ob, rx, ry, rz):
    """Rotacao Godot (graus, ordem Ry @ Rx @ Rz) -> Blender (x, -z, y)."""
    from mathutils import Matrix
    Mg = R(rx=rx, ry=ry, rz=rz)
    C = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    Mb = C @ Mg @ C.inverted()
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = Mb.to_quaternion()


def lantern_parts():
    """Lanterna giratoria (origem = pivo no piso da sala; frente = -Z local): nucleo aceso, refletor em concha atras,
    lente de Fresnel na frente, seta dourada no topo (le a direcao), base giratoria. E o cone do feixe."""
    m = MB("wv3_lantern")
    gold, iron = hexc("#C9A13A"), hexc("#2B2F33")
    m.cyl((0, 0, 0), 0.5, 0.12, "wv2_metal", gold, seg=20, bevel=0.02)
    m.cyl((0, 0.12, 0), 0.08, 0.15, "wv2_metal", iron, seg=10)
    m.cyl((0, 0.27, 0), 0.26, 0.75, "wv2_lamp", hexc("#FFE8B8"), seg=16)
    # refletor (meia concha atras do nucleo)
    for k in range(9):
        a = math.radians(-80 + k * 20)
        m.box((math.sin(a) * 0.48, 0.65, math.cos(a) * 0.48), (0.17, 0.95, 0.04), "wv2_metal", hexc("#D9DDE2"), 0.0, 1,
              rot=R(ry=math.degrees(a)))
    # lente de Fresnel (aneis concentricos) na frente
    for k, (r0, r1) in enumerate(((0.0, 0.14), (0.16, 0.26), (0.28, 0.38), (0.4, 0.48))):
        prof = [(r1, 0.0), (r1, 0.03 + 0.02 * k), (r0, 0.06 + 0.01 * k)] + ([(r0, 0.0)] if r0 > 0 else [(0.0, 0.07)])
        m.lathe((0, 0.65, -0.5), prof, "wv2_glossy", hexc("#FFF0C0"), seg=20, rot=R(rx=-90))
    m.lathe((0, 0.65, -0.5), [(0.5, -0.02), (0.53, 0.0), (0.53, 0.05), (0.5, 0.06)], "wv2_metal", gold, seg=20, rot=R(rx=-90))
    m.cyl((0, 1.12, 0), 0.5, 0.06, "wv2_metal", iron, seg=20)
    m.prism((0, 1.2, 0), [(-0.08, 0.25), (0.08, 0.25), (0.08, -0.1), (0.18, -0.1), (0.0, -0.4), (-0.18, -0.1), (-0.08, -0.1)],
            0.03, "wv2_metal", gold, rot=R(rx=90))
    beam = MB("wv3_lantern_beam")
    beam.cyl((0, 0, 0), 0.45, 16.0, "wv2_beam", hexc("#FFF2C0"), r1=3.2, seg=20, caps=False, rot=T(0, 0.65, -0.5) @ R(rx=-97))   # 7 graus para baixo (mar)
    return m, beam


def dinghy():
    """Bote do capitao (casco do kit, cor propria), remo caido, corda de amarra solta, bone do capitao no banco."""
    m = MB("wv3_dinghy")
    m.merge(KIT.rowboat("dinghy_hull", 84, "#2F9C95", "#FFF4E0"))
    rng = random.Random(84)
    m.box((-0.2, 0.0, 0.3), (0.06, 0.03, 1.6), "wv2_wood", hexc("#C8A27A"), 0.008, 1, rot=R(ry=12), grain="z", rng=rng)
    m.box((-0.33, 0.0, 1.05), (0.13, 0.015, 0.36), "wv2_wood", hexc("#C8A27A"), 0.006, 1, rot=R(ry=12), grain="z", rng=rng)
    m.tube([(0.0, 0.3, -1.6), (0.1, 0.25, -1.9), (0.3, -0.1, -2.1), (0.7, -0.25, -2.3), (1.1, -0.27, -2.2)], 0.02, "wv2_rope",
           hexc("#D9C38B"), seg=6)
    # bone de capitao (azul-marinho com aba e emblema dourado)
    m.lathe((0.15, 0.1, 0.35), [(0.13, 0.0), (0.14, 0.05), (0.12, 0.1), (0.0, 0.12)], "wv2_canvas", hexc("#2E4F7A"), seg=14)
    m.box((0.15, 0.1, 0.22), (0.2, 0.015, 0.12), "wv2_glossy", hexc("#1E2C40"), 0.004, 1)
    m.sphere((0.15, 0.17, 0.25), 0.025, "wv2_metal", hexc("#C9A13A"), subd=1)
    return m


def buoy(name, color):
    """Boia de rota (bombordo vermelha / boreste verde) com faixa branca, mastro, marca de topo e luz. Origem na agua."""
    m = MB(name)
    c = hexc("#D9473A") if color == "red" else hexc("#3E9A57")
    m.lathe((0, -0.55, 0), [(0.0, 0.0), (0.3, 0.05), (0.42, 0.3), (0.42, 0.62), (0.3, 0.8), (0.0, 0.82)], "wv2_glossy", c, seg=18)
    m.lathe((0, 0.0, 0), [(0.425, 0.0), (0.425, 0.12), (0.0, 0.12)], "wv2_glossy", hexc("#FFFFFF"), seg=18)
    m.cyl((0, 0.27, 0), 0.05, 1.1, "wv2_metal", hexc("#2B2F33"), seg=8)
    if color == "red":
        m.cyl((0, 1.3, 0), 0.2, 0.2, "wv2_glossy", c, seg=12)
    else:
        m.cyl((0, 1.3, 0), 0.22, 0.3, "wv2_glossy", c, r1=0.0, seg=12)
    m.sphere((0, 1.16, 0), 0.06, "wv2_lamp", hexc("#FFE0A0"), subd=1)
    m.lathe((0, 0.02, 0), [(0.43, 0.0), (0.55, 0.0)], "wv2_rope", hexc("#D9C38B"), seg=18)
    return m


ICONS = {"star": "#FFD23F", "moon": "#AED8FF", "fish": "#FF8A3D", "flower": "#FF8FB1"}


def _icon(m, xf, kind, mat="wv2_glossy"):
    col = hexc(ICONS[kind])
    if kind == "star":
        pts = []
        for i in range(10):
            a = math.pi / 2 + i * math.pi / 5
            r = 0.2 if i % 2 == 0 else 0.085
            pts.append((math.cos(a) * r, math.sin(a) * r))
        m.prism((0, 0, 0), pts, 0.03, mat, col, rot=xf)
    elif kind == "moon":
        pts = [(math.cos(a) * 0.19, math.sin(a) * 0.19) for a in [math.radians(60 + i * 12) for i in range(21)]]
        pts += [(math.cos(a) * 0.14 + 0.07, math.sin(a) * 0.14) for a in [math.radians(300 - i * 12) for i in range(21)]][1:-1]
        m.prism((0, 0, 0), pts, 0.03, mat, col, rot=xf)
    elif kind == "fish":
        m.sphere((0, 0, 0), 1.0, mat, col, subd=2, scale=(0.15, 0.09, 0.025), rot=xf @ T(0.04, 0, 0))
        m.prism((0, 0, 0), [(-0.1, 0.0), (-0.2, 0.09), (-0.2, -0.09)], 0.03, mat, col, rot=xf)
    else:
        for i in range(5):
            a = math.radians(90 + i * 72)
            m.sphere((0, 0, 0), 1.0, mat, col, subd=1, scale=(0.075, 0.075, 0.02), rot=xf @ T(math.cos(a) * 0.1, math.sin(a) * 0.1, 0))
        m.sphere((0, 0, 0), 0.06, mat, hexc("#FFD23F"), subd=1, scale=(1, 1, 0.4), rot=xf @ T(0, 0, 0.012))


def festa_boat(i, hull, icon):
    """Barquinho da festa ancorado: casco do kit, mastro curto com lanterna de papel e bandeira com icone (4 direcoes)."""
    m = MB("wv3_festa_boat_%d" % i)
    m.merge(KIT.rowboat("festa_hull_%d" % i, 90 + i, hull, "#FFF4E0"), T(0, 0, 0))
    m.cyl((0, -0.1, -0.6), 0.035, 2.2, "wv2_wood", hexc("#B48A60"), seg=8)
    m.cyl((0, 1.6, -0.6), 0.025, 0.4, "wv2_wood", hexc("#B48A60"), seg=6, rot=T() @ R(rz=0))
    m.box((0.0, 1.85, -0.6), (0.6, 0.02, 0.02), "wv2_wood", hexc("#B48A60"), 0.0, 1)
    paper = lantern_mesh(m, (0.28, 1.84, -0.6), hexc("#FFC93C"), hang=0.08)
    # bandeira-placa com icone (dos dois lados)
    m.box((0.0, 1.45, -0.6), (0.02, 0.5, 0.62), "wv2_canvas", hexc("#FFF4E0"), 0.006, 1)
    for s in (1, -1):
        _icon(m, T(s * 0.02, 1.45, -0.6) @ R(ry=90 * s), icon)
    m.lathe((0, -0.1, 1.2), [(0.0, 0.0), (0.12, 0.0), (0.12, 0.08), (0.0, 0.08)], "wv2_metal", hexc("#2B2F33"), seg=8)
    return m, paper


def lantern_mesh(m, pos, col, hang=0.12, r=0.13, h=0.28):
    """Lanterna de papel com gomos (torno), tampa e fio. Devolve o centro (para a luz da noite)."""
    x, y, z = pos
    m.cyl((x, y - hang, z), 0.006, hang, "wv2_rope", hexc("#2B2F33"), seg=4)
    yc = y - hang - h / 2
    prof = []
    for i in range(5):
        t = i / 4
        rr = r * (0.55 + 0.45 * math.sin(math.pi * t))
        prof.append((rr, -h / 2 + h * t))
    m.lathe((x, yc, z), prof, "wv2_paper", col, seg=10)
    m.cyl((x, yc + h / 2 - 0.01, z), r * 0.6, 0.04, "wv2_metal", hexc("#2B2F33"), seg=8)
    m.cyl((x, yc - h / 2 - 0.03, z), r * 0.6, 0.04, "wv2_metal", hexc("#2B2F33"), seg=8)
    return (x, yc, z)


def festa_lanterns(lines):
    """Lanternas penduradas da festa ao longo de cordoes (catenaria). Acesas so na noite de festa (Godot)."""
    m = MB("wv3_festa_lanterns")
    rng = random.Random(97)
    pts_out = []
    for a, b, n in lines:
        a, b = Vector(a), Vector(b)
        cord = []
        for i in range(17):
            t = i / 16
            p = a.lerp(b, t)
            p.y -= 0.5 * math.sin(math.pi * t)
            cord.append(p)
        m.tube(cord, 0.007, "wv2_rope", hexc("#3B3F44"), seg=4)
        for k in range(n):
            t = (k + 0.5) / n
            p = a.lerp(b, t)
            p.y -= 0.5 * math.sin(math.pi * t)
            c = hexc(PAPER_COLS[(k + len(pts_out)) % len(PAPER_COLS)])
            pts_out.append(lantern_mesh(m, (p.x, p.y, p.z), c, hang=0.08 + rng.uniform(0, 0.08), r=0.12 + rng.uniform(0, 0.03)))
    return m, pts_out


def lens():
    """Lente caida do farol (M7): aro de latao com vidro grosso e alca."""
    m = MB("wv3_lens")
    ring = [(math.cos(a) * 0.2, 0.06, math.sin(a) * 0.2) for a in [i / 24 * 6.2832 for i in range(25)]]
    m.tube(ring, 0.035, "wv2_metal", hexc("#C9A13A"), seg=8, caps=False)
    m.lathe((0, 0.03, 0), [(0.2, 0.0), (0.2, 0.04), (0.1, 0.07), (0.0, 0.075)], "wv2_glossy", hexc("#E8F4FF"), seg=24)
    m.tube([(0.2, 0.06, 0.0), (0.32, 0.08, 0.0), (0.4, 0.07, 0.05)], 0.02, "wv2_metal", hexc("#C9A13A"), seg=6)
    return m


# ================================================================== decalques (numpy)
def _sd_ellipse(X, Y, cx, cy, rx, ry, ang=0.0):
    import numpy as np
    c, s = math.cos(ang), math.sin(ang)
    dx, dy = X - cx, Y - cy
    u = (dx * c + dy * s) / rx
    v = (-dx * s + dy * c) / ry
    return (np.sqrt(u * u + v * v) - 1.0) * min(rx, ry)


def decals(out_dir):
    """Pegadinha do filhote (seca e molhada), pena de gaivota e escamas de peixe: RGBA 256 px, fundo transparente."""
    import numpy as np
    n = 256
    ys, xs = np.mgrid[0:n, 0:n]
    X = (xs + 0.5) / n * 2 - 1
    Y = (ys + 0.5) / n * 2 - 1
    out = {}

    def paw(col, gloss):
        d = _sd_ellipse(X, Y, 0.0, -0.25, 0.42, 0.34)
        for cx, cy, rx, ry, a in ((-0.5, 0.22, 0.17, 0.22, 0.35), (-0.18, 0.46, 0.17, 0.23, 0.1), (0.18, 0.46, 0.17, 0.23, -0.1),
                                  (0.5, 0.22, 0.17, 0.22, -0.35)):
            d = np.minimum(d, _sd_ellipse(X, Y, cx, cy, rx, ry, a))
        a = np.clip(0.5 - d * n / 2.5, 0, 1)
        noise = np.sin(X * 37 + Y * 11) * np.sin(Y * 29 - X * 7) * 0.08
        a = np.clip(a * (0.85 + noise), 0, 1)
        rgb = np.ones((n, n, 3)) * np.array(col)[None, None, :]
        rgb *= (1.0 + gloss * np.clip(-d * 8, 0, 1)[..., None] * 0.25)
        return np.concatenate([np.clip(rgb, 0, 1), a[..., None]], axis=-1)

    out["decal_paw"] = paw((0.36, 0.24, 0.16), 0.0)
    out["decal_paw_wet"] = paw((0.16, 0.2, 0.26), 1.0)
    # pena: raque curva + barbas em V, ponta arredondada
    t = (Y + 0.85) / 1.7
    cx = 0.08 * np.sin(t * 2.5)
    w = 0.34 * np.sin(np.clip(t, 0, 1) * math.pi) ** 0.7 * (0.6 + 0.4 * t)
    dx = X - cx
    inside = (np.abs(dx) < w) & (t > 0.0) & (t < 1.0)
    barbs = 0.75 + 0.25 * np.sin((Y - np.abs(dx) * 0.9) * 90)
    rachis = np.clip(1 - np.abs(dx) / 0.025, 0, 1) * ((t > -0.1) & (t < 1.0))
    a = np.clip(inside * barbs * np.clip((w - np.abs(dx)) * 30, 0, 1) + rachis, 0, 1)
    col = np.stack([0.94 - 0.25 * (1 - t), 0.95 - 0.22 * (1 - t), 0.97 - 0.15 * (1 - t)], axis=-1)
    col = col * (1 - 0.3 * rachis[..., None])
    out["decal_feather"] = np.concatenate([np.clip(col, 0, 1), a[..., None]], axis=-1)
    # escamas: semicirculos prateados em fileiras, num borrao irregular
    rng = np.random.default_rng(42)
    acc = np.zeros((n, n))
    shade = np.zeros((n, n))
    for _ in range(26):
        cx, cy = rng.uniform(-0.55, 0.55), rng.uniform(-0.55, 0.55)
        r = rng.uniform(0.07, 0.12)
        d = np.sqrt((X - cx) ** 2 + (Y - cy) ** 2)
        m_ = np.clip((r - d) * n / 3, 0, 1) * (Y > cy - r * 0.2)
        acc = np.maximum(acc, m_)
        shade = np.where(m_ > 0.5, np.clip(1 - d / r, 0, 1), shade)
    iri = 0.5 + 0.5 * np.sin(X * 9 + Y * 5)
    col = np.stack([0.72 + 0.2 * shade, 0.8 + 0.12 * shade + 0.05 * iri, 0.86 + 0.1 * shade + 0.04 * (1 - iri)], axis=-1)
    out["decal_scale"] = np.concatenate([np.clip(col, 0, 1), (acc * 0.92)[..., None]], axis=-1)
    for name, img in out.items():
        TX.write_png_rgba(os.path.join(out_dir, name + ".png"), img[::-1])
    return sorted(out.keys())
