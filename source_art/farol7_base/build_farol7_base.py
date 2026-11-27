"""Rota Brava · RB-R1 G21 · base Farol 7: a sala do radio (um plano da abertura), a cadeira giratoria, a luz giratoria
amarela da base, o exterior da casa-torre na ponta das pedras e o fundo visto pela escotilha (mar, a Vila Mare pequena e o
farol da vila ao longe). PROVISORIO.

Toda geometria e gerada aqui do zero (bmesh do Blender e formulas proprias, via wv2lib do mundo v2). Nenhum modelo,
malha, textura, foto ou kit de terceiros. Acabamento: os materiais `wv2_*` da vila v2.1 (texturas procedurais do projeto,
trocados na Godot por WV2Materials) e os materiais `f7_*` definidos em game/worlds/farol7_base/farol7_base.gd (mar, feixe,
lampada, vidro, LEDs e os retratos do trio nos pinos do mapa, que sao os PNG do HUD do proprio projeto).

CONVENCAO: modelado em coordenadas da GODOT (x leste, y cima, z sul; metros); wv2lib converte para o Blender. A sala tem o
chao em y = 0, o centro em x = z = 0 e a camera olha para o norte (-Z): parede do fundo (escotilha e mesa do radio) em
z = -2,1, mapa na parede da esquerda (oeste), emblema e cabide na da direita (leste), claraboia no teto.

Saida (game/assets/models/farol7_base/): farol7_room.glb, farol7_chair.glb (pivo no eixo do pe), farol7_beacon.glb (a
parte que gira se chama BeaconSpin, eixo em x = z = 0), farol7_tower.glb (exterior, chao da torre em y = 0) e
farol7_backdrop.glb (mar e vila ao longe).

Uso:
  bash tools/blender.sh --background --factory-startup --python source_art/farol7_base/build_farol7_base.py
"""
import json
import math
import os
import random
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
sys.path.insert(0, os.path.join(REPO, "source_art", "environment_v2"))
sys.path.insert(0, os.path.join(REPO, "source_art", "props_v3"))
sys.path.insert(0, SCRIPT_DIR)

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

from wv2lib import MB, R, T, _bm_lathe, hexc, lin  # noqa: E402
import build_props_v3 as PV3  # noqa: E402  (so leitura: contornos do emblema da marca, como nas moedas)

GLB_DIR = os.path.join(REPO, "game", "assets", "models", "farol7_base")
BLEND = os.path.join(SCRIPT_DIR, "farol7_base.blend")
INFO = os.path.join(SCRIPT_DIR, "farol7_base.info.json")

MAT_PREVIEW = dict(PV3.MAT_PREVIEW)
MAT_PREVIEW.update({"wv2_plaster": "#EDEDED", "wv2_deck": "#B08660", "wv2_slats": "#C8C8C8", "wv2_stone": "#BBBBBB",
                    "wv2_rock": "#9A9A9A", "wv2_roof": "#C8C8C8", "wv2_glass": "#CFE8FF", "wv2_interior_lit": "#FFD9A0",
                    "f7_sea": "#2F7FB8", "f7_beam": "#FFE680", "f7_lamp": "#FFD23A", "f7_glass": "#CFE8FF", "f7_led": "#FFFFFF",
                    "f7_pin_rastro": "#FF8A1F", "f7_pin_pico": "#3DBE5A", "f7_pin_leme": "#2F8CFF", "f7_screen": "#9FE3C8"})

# paleta: equipe (docs/proposals/g21_farol7.md) + assinaturas dos herois
NAVY, YELLOW, CORAL = "#0B2440", "#FFD23A", "#E2453A"
RASTRO, PICO, LEME = "#FF8A1F", "#3DBE5A", "#2F8CFF"
WALL, WALL_DK, BLUE = "#BCD6EC", "#16365E", "#2A5DA8"
CREAM, WOOD, BRASS = "#FFF4DE", "#B98A5E", "#E9B53A"

W, D, H = 4.6, 4.2, 2.8          # sala (x, z, y)
XW, ZB = W / 2, -D / 2           # parede oeste em -XW, leste em +XW; fundo em ZB
PORT = (0.55, 1.62, 1.18)        # escotilha: centro x, centro y, diametro do vidro
SKY = (0.0, -0.55, 0.92)         # claraboia: centro x, centro z, diametro
DESK = (-0.15, 0.76, 2.2, 0.72)  # mesa: centro x, altura, largura, profundidade
MAP = (-0.45, 1.55, 1.70, 1.10)  # mapa (parede oeste): centro z, centro y, largura, altura
EMB = (-0.35, 1.62)              # emblema (parede leste): centro z, centro y
CHAIR = (0.60, -1.00)            # pivo da cadeira (x, z)
BEACON_Y = H + 0.55              # luz giratoria acima da claraboia


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    sc.render.fps = 30
    return sc


def materials():
    mats = {}
    for name, h in MAT_PREVIEW.items():
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        c = lin(hexc(h)) + (1.0,)
        b.inputs["Base Color"].default_value = c
        b.inputs["Roughness"].default_value = 0.6
        m.diffuse_color = c
        mats[name] = m
    return mats


def c(h, mul=1.0):
    return hexc(h, mul)


# ================================================================== geometria auxiliar
def plate_with_hole(m, xf, half, r, t, mat, col, seg=32, frame=None):
    """Placa quadrada (lado 2*half, espessura t, plano XY local, normal +Z) com furo redondo de raio r no centro.
    As bordas externas ficam abertas (encostam em outras placas)."""
    bm = bmesh.new()
    inner = {}
    outer = {}
    for side, z in (("f", t / 2), ("b", -t / 2)):
        ii, oo = [], []
        for i in range(seg):
            a = 2 * math.pi * i / seg + math.pi / 4
            ca, sa = math.cos(a), math.sin(a)
            s = min(half / max(abs(ca), 1e-6), half / max(abs(sa), 1e-6))
            ii.append(bm.verts.new((ca * r, sa * r, z)))
            oo.append(bm.verts.new((ca * s, sa * s, z)))
        inner[side], outer[side] = ii, oo
    for i in range(seg):
        j = (i + 1) % seg
        bm.faces.new((inner["f"][i], outer["f"][i], outer["f"][j], inner["f"][j]))
        bm.faces.new((inner["b"][j], outer["b"][j], outer["b"][i], inner["b"][i]))
        bm.faces.new((inner["f"][i], inner["f"][j], inner["b"][j], inner["b"][i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    m.add_bm(bm, xf, mat, col, "world")


def ring_lathe(m, xf, profile, mat, col, seg=36):
    """Torno sem as tampas (aro com furo no meio): o lathe da wv2lib fecha base e topo quando o raio e > 0."""
    bm = _bm_lathe(profile, seg)
    caps = [f for f in bm.faces if len(f.verts) == seg]
    bmesh.ops.delete(bm, geom=caps, context="FACES_ONLY")
    m.add_bm(bm, xf, mat, col, "cyl")


def disc_uv(m, xf, r, t, mat, col=(1, 1, 1), seg=28):
    """Disco (plano XY local, face +Z) com UV em metros a partir do centro (o material da Godot converte em 0..1)."""
    bm = bmesh.new()
    top = [bm.verts.new((math.cos(2 * math.pi * i / seg) * r, math.sin(2 * math.pi * i / seg) * r, t / 2)) for i in range(seg)]
    bot = [bm.verts.new((v.co.x, v.co.y, -t / 2)) for v in top]
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    for i in range(seg):
        j = (i + 1) % seg
        bm.faces.new((bot[i], bot[j], top[j], top[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    m.add_bm(bm, xf, mat, col, "box", uvoff=(0.0, 0.0))


def star(n, ro, ri, rot=0.0):
    return [(math.cos(rot + math.pi / 2 + i * math.pi / n) * (ro if i % 2 == 0 else ri),
             math.sin(rot + math.pi / 2 + i * math.pi / n) * (ro if i % 2 == 0 else ri)) for i in range(2 * n)]


def circle(r, n=24, cx=0.0, cy=0.0, sx=1.0):
    return [(cx + math.cos(2 * math.pi * i / n) * r * sx, cy + math.sin(2 * math.pi * i / n) * r) for i in range(n)]


def blob2d(r, n, seed, amp=0.18, cx=0.0, cy=0.0, sx=1.0, sy=1.0):
    rnd = random.Random(seed)
    ph = [rnd.uniform(0, 6.28) for _ in range(3)]
    out = []
    for i in range(n):
        a = 2 * math.pi * i / n
        k = 1.0 + amp * (math.sin(2 * a + ph[0]) * 0.5 + math.sin(3 * a + ph[1]) * 0.3 + math.sin(5 * a + ph[2]) * 0.2)
        out.append((cx + math.cos(a) * r * k * sx, cy + math.sin(a) * r * k * sy))
    return out


# ================================================================== sala
def room():
    m = MB("Farol7_Room")
    # chao de tabuas e rodape
    m.box((0, -0.05, 0), (W + 0.4, 0.1, D + 0.4), "wv2_deck", c("#C49A6C"), 0.0, 1, uv="world")
    # tapete redondo azul com borda amarela sob a cadeira
    m.cyl((CHAIR[0], 0.0, CHAIR[1] + 0.15), 1.05, 0.012, "pv3_cloth", c(BLUE), seg=40)
    m.cyl((CHAIR[0], 0.0, CHAIR[1] + 0.15), 0.86, 0.016, "pv3_cloth", c(NAVY), seg=40)
    m.cyl((CHAIR[0], 0.0, CHAIR[1] + 0.15), 0.80, 0.018, "pv3_cloth", c(YELLOW), seg=40)
    m.cyl((CHAIR[0], 0.0, CHAIR[1] + 0.15), 0.74, 0.020, "pv3_cloth", c(BLUE), seg=40)
    # paredes: lambri azul-marinho ate 1,0 m, friso amarelo, reboco azul-claro em cima
    t = 0.14
    hx, hy, hr = PORT[0], PORT[1], PORT[2] / 2 + 0.12
    half = 0.80
    for (name, xf_wall, length) in (("W", T(-XW - t / 2, 0, 0) @ R(ry=90), D), ("E", T(XW + t / 2, 0, 0) @ R(ry=-90), D),
                                    ("N", T(0, 0, ZB - t / 2), W), ("S", T(0, 0, -ZB + t / 2) @ R(ry=180), W)):
        L = length + 2 * t
        m.box((0, 0.5, 0), (L, 1.0, t), "wv2_slats", c(WALL_DK), 0.0, 1, rot=xf_wall, uv="box")
        m.box((0, 1.02, 0.03), (L, 0.07, t + 0.05), "wv2_paint", c(YELLOW), 0.012, 1, rot=xf_wall)
        m.box((0, 0.06, 0.02), (L, 0.12, t + 0.03), "wv2_paint", c(NAVY), 0.01, 1, rot=xf_wall)
        if name != "N":
            m.box((0, 1.0 + (H - 1.0) / 2, 0), (L, H - 1.0, t), "wv2_plaster", c(WALL), 0.0, 1, rot=xf_wall, uv="box")
        else:
            # parede do fundo com o furo da escotilha: placa com furo + 4 pedacos em volta
            plate_with_hole(m, xf_wall @ T(hx, hy, 0), half, hr, t, "wv2_plaster", c(WALL))
            x0, x1 = -L / 2, L / 2
            y0, y1 = 1.0, H
            m.box(((x0 + hx - half) / 2, (y0 + y1) / 2, 0), (hx - half - x0, y1 - y0, t), "wv2_plaster", c(WALL), 0.0, 1, rot=xf_wall)
            m.box(((hx + half + x1) / 2, (y0 + y1) / 2, 0), (x1 - hx - half, y1 - y0, t), "wv2_plaster", c(WALL), 0.0, 1, rot=xf_wall)
            m.box((hx, (y0 + hy - half) / 2, 0), (2 * half, hy - half - y0, t), "wv2_plaster", c(WALL), 0.0, 1, rot=xf_wall)
            m.box((hx, (hy + half + y1) / 2, 0), (2 * half, y1 - hy - half, t), "wv2_plaster", c(WALL), 0.0, 1, rot=xf_wall)
    # porta coral na parede sul (atras da camera; aparece so no plano aberto vindo da escotilha)
    sf_ = T(0, 0, -ZB - 0.01) @ R(ry=180)
    m.box((1.2, 1.02, 0.0), (1.0, 2.04, 0.08), "wv2_paint", c(YELLOW), 0.02, 1, rot=sf_)
    m.box((1.2, 1.0, 0.03), (0.86, 1.96, 0.06), "wv2_paint", c(CORAL), 0.02, 2, rot=sf_)
    m.sphere((0, 0, 0), 0.04, "wv2_metal", c(BRASS), subd=1, rot=sf_ @ T(0.85, 1.0, 0.08))
    # vigas do teto aparente (navy) e forro com o furo da claraboia
    sx, sz, sr = SKY[0], SKY[1], SKY[2] / 2 + 0.10
    halfc = 0.75
    plate_with_hole(m, T(sx, H + 0.06, sz) @ R(rx=90), halfc, sr, 0.12, "wv2_slats", c("#2B4F7E"))
    for (cx, cz, wx, wz) in (((-XW - 0.2 + sx - halfc) / 2, sz, sx - halfc + XW + 0.2, 2 * halfc),
                             ((XW + 0.2 + sx + halfc) / 2, sz, XW + 0.2 - sx - halfc, 2 * halfc),
                             (0.0, (ZB - 0.2 + sz - halfc) / 2, W + 0.4, sz - halfc - ZB + 0.2),
                             (0.0, (sz + halfc + D / 2 + 0.2) / 2, W + 0.4, D / 2 + 0.2 - sz - halfc)):
        m.box((cx, H + 0.06, cz), (wx, 0.12, wz), "wv2_slats", c("#2B4F7E"), 0.0, 1, uv="world")
    for k in range(5):
        z = ZB + 0.45 + k * 0.85
        if abs(z - sz) < sr + 0.1:
            continue
        m.box((0, H - 0.07, z), (W, 0.16, 0.14), "wv2_wood", c("#1F3E66"), 0.02, 1, grain="x")
    # claraboia: aro amarelo e parafusos (sem vidro: o vidro transparente lia como chapa leitosa na captura)
    ring_lathe(m, T(sx, H - 0.02, sz), [(sr + 0.02, 0.0), (sr + 0.08, 0.02), (sr + 0.08, 0.10), (sr - 0.02, 0.14), (sr - 0.03, 0.0),
                                        (sr + 0.02, 0.0)], "wv2_paint", c(YELLOW), seg=36)
    for k in range(10):
        a = 2 * math.pi * k / 10
        m.sphere((sx + math.cos(a) * (sr + 0.05), H - 0.025, sz + math.sin(a) * (sr + 0.05)), 0.018, "wv2_metal", c(BRASS), subd=1)
    # escotilha: aro de latao grosso e parafusos (sem vidro, pelo mesmo motivo)
    pr = PORT[2] / 2
    pf = T(hx, hy, ZB + 0.01)
    ring_lathe(m, pf @ R(rx=90), [(pr - 0.02, -0.16), (pr + 0.10, -0.16), (pr + 0.13, -0.10), (pr + 0.13, 0.02), (pr + 0.09, 0.07),
                                  (pr - 0.01, 0.07), (pr - 0.04, 0.02), (pr - 0.04, -0.16), (pr - 0.02, -0.16)], "wv2_metal", c(BRASS), seg=40)
    for k in range(12):
        a = 2 * math.pi * k / 12 + 0.26
        m.sphere((hx + math.cos(a) * (pr + 0.075), hy + math.sin(a) * (pr + 0.075), ZB + 0.085), 0.024, "wv2_metal", c("#C9962E"), subd=1)
    # mesa do radio: tampo de madeira, corpo marinho com gavetas, pes
    dx, dh, dw, dd = DESK
    dz = ZB + dd / 2 + 0.02
    m.box((dx, dh - 0.03, dz), (dw, 0.06, dd), "wv2_wood", c(WOOD), 0.015, 2, grain="x")
    m.box((dx - dw / 2 + 0.28, (dh - 0.06) / 2, dz), (0.52, dh - 0.06, dd - 0.06), "wv2_paint", c(NAVY), 0.02, 2)
    m.box((dx + dw / 2 - 0.28, (dh - 0.06) / 2, dz), (0.52, dh - 0.06, dd - 0.06), "wv2_paint", c(NAVY), 0.02, 2)
    for sxk in (-1, 1):
        cxk = dx + sxk * (dw / 2 - 0.28)
        for k in range(3):
            y = 0.14 + k * 0.21
            m.box((cxk, y, dz + dd / 2 - 0.02), (0.44, 0.17, 0.03), "wv2_paint", c("#173A66"), 0.012, 1)
            m.box((cxk, y + 0.02, dz + dd / 2 + 0.005), (0.12, 0.025, 0.03), "wv2_metal", c(YELLOW), 0.008, 1)
    m.box((dx, dh - 0.12, dz - dd / 2 + 0.06), (dw - 1.1, 0.12, 0.04), "wv2_paint", c(NAVY), 0.01, 1)
    # console do radio: caixa inclinada azul, alto-falante, mostrador, 3 botoes grandes nas cores do trio
    cx0, cz0 = dx - 0.20, ZB + 0.28
    tilt = T(cx0, dh, cz0) @ R(rx=-18)
    m.box((0, 0, 0), (1.10, 0.34, 0.36), "wv2_glossy", c(BLUE), 0.04, 2, rot=tilt @ T(0, 0.17, 0))
    m.box((0, 0, 0), (1.14, 0.05, 0.40), "wv2_paint", c(YELLOW), 0.02, 2, rot=tilt @ T(0, 0.36, -0.02))
    face = tilt @ T(0, 0.17, 0.185)
    m.box((0, 0, 0), (1.02, 0.28, 0.01), "wv2_paint", c("#163C70"), 0.005, 1, rot=face)
    # mostrador de frequencia (tela verde-clara com ponteiro)
    m.box((0, 0, 0), (0.36, 0.09, 0.012), "f7_screen", c("#BFF2DA"), 0.004, 1, rot=face @ T(-0.26, 0.07, 0.008))
    m.box((0, 0, 0), (0.008, 0.07, 0.016), "wv2_paint", c(CORAL), 0.0, 1, rot=face @ T(-0.22, 0.07, 0.012))
    # grade do alto-falante
    for k in range(5):
        m.box((0, 0, 0), (0.20, 0.012, 0.012), "wv2_metal", c("#0E2747"), 0.0, 1, rot=face @ T(0.32, 0.03 + k * 0.025 - 0.02, 0.009))
    for k, col in enumerate((RASTRO, PICO, LEME)):
        bx = -0.24 + k * 0.17
        m.cyl((0, 0, 0), 0.062, 0.03, "wv2_glossy", c("#0E2747"), seg=24, rot=face @ T(bx, -0.07, 0.0) @ R(rx=90))
        m.lathe((0, 0, 0), [(0.052, 0.0), (0.052, 0.025), (0.046, 0.042), (0.025, 0.050), (0.0, 0.052)], "wv2_glossy", c(col),
                seg=24, rot=face @ T(bx, -0.07, 0.012) @ R(rx=90))
    # dois botoes giratorios e a luz "no ar" que pisca quando ele fala (f7_led)
    for k in range(2):
        m.cyl((0, 0, 0), 0.032, 0.035, "wv2_metal", c("#DDE3EA"), seg=16, rot=face @ T(0.22 + k * 0.11, -0.07, 0.0) @ R(rx=90))
    m.sphere((0, 0, 0), 0.026, "f7_led", c(CORAL), subd=2, scale=(1, 1, 0.7), rot=face @ T(0.40, 0.10, 0.012))
    # antena do radio saindo da parte de tras do console, com a bolinha coral (rima com a do fone do Lumi)
    m.cyl((cx0 - 0.50, dh + 0.30, cz0 - 0.10), 0.012, 0.75, "wv2_metal", c("#AEB7C2"), seg=8)
    m.sphere((cx0 - 0.50, dh + 1.07, cz0 - 0.10), 0.04, "wv2_glossy", c(CORAL), subd=2)
    # microfone de mesa: base, haste, cabeca com grade e anel coral
    mx, mz = dx + 0.77, ZB + 0.50
    m.lathe((mx, dh, mz), [(0.10, 0.0), (0.10, 0.018), (0.08, 0.03), (0.02, 0.04), (0.0, 0.04)], "wv2_glossy", c(NAVY), seg=24)
    m.tube([(mx, dh + 0.03, mz), (mx, dh + 0.18, mz + 0.02), (mx, dh + 0.27, mz + 0.08)], 0.011, "wv2_metal", c("#AEB7C2"), seg=8)
    m.lathe((0, 0, 0), [(0.0, -0.06), (0.032, -0.055), (0.040, -0.02), (0.040, 0.03), (0.032, 0.06), (0.0, 0.07)], "wv2_metal",
            c("#3A4452"), seg=20, rot=T(mx, dh + 0.31, mz + 0.10) @ R(rx=35))
    m.cyl((0, 0, 0), 0.043, 0.02, "wv2_glossy", c(CORAL), seg=20, rot=T(mx, dh + 0.31, mz + 0.10) @ R(rx=35) @ T(0, -0.035, 0))
    # caneca amarela com estrela navy
    gx, gz = dx + 1.03, ZB + 0.30
    m.lathe((gx, dh, gz), [(0.0, 0.0), (0.042, 0.0), (0.046, 0.01), (0.046, 0.105), (0.040, 0.105), (0.040, 0.015), (0.0, 0.015)],
            "wv2_glossy", c(YELLOW), seg=24)
    ring = [(gx + 0.046 + 0.022 * math.sin(a), dh + 0.055 + 0.03 * math.cos(a), gz) for a in [i / 12 * math.pi for i in range(13)]]
    m.tube(ring, 0.009, "wv2_glossy", c(YELLOW), seg=6)
    m.prism((0, 0, 0), star(5, 0.022, 0.009), 0.004, "wv2_paint", c(NAVY), rot=T(gx, dh + 0.06, gz + 0.046))
    # pilha de papeis e um lapis (vida na mesa)
    m.box((dx + 0.45, dh + 0.01, ZB + 0.55), (0.30, 0.02, 0.22), "wv2_paint", c(CREAM), 0.004, 1, rot=R(ry=8))
    m.cyl((0, 0, 0), 0.006, 0.17, "wv2_paint", c(YELLOW), seg=6, rot=T(dx + 0.50, dh + 0.03, ZB + 0.60) @ R(rz=90, ry=30))
    # lampada de mesa (braco articulado amarelo)
    lx, lz = dx - 0.98, ZB + 0.18
    m.cyl((lx, dh, lz), 0.07, 0.025, "wv2_glossy", c(YELLOW), seg=20)
    m.tube([(lx, dh + 0.02, lz), (lx + 0.04, dh + 0.30, lz + 0.06), (lx + 0.18, dh + 0.42, lz + 0.14)], 0.012, "wv2_glossy", c(YELLOW), seg=8)
    m.lathe((0, 0, 0), [(0.0, 0.10), (0.03, 0.10), (0.05, 0.05), (0.085, 0.0), (0.075, -0.005), (0.0, 0.04)], "wv2_glossy",
            c(YELLOW), seg=20, rot=T(lx + 0.20, dh + 0.38, lz + 0.15) @ R(rx=25, rz=-20))
    m.sphere((lx + 0.205, dh + 0.355, lz + 0.155), 0.03, "f7_lamp", c("#FFF6D0"), subd=2)
    # mapa da Vila Mare (parede oeste): moldura navy, mar, terra, cais, praca, galpao, farol, icones e os 3 pinos
    mz0, my0, mw, mh = MAP
    mf = T(-XW + 0.02, my0, mz0) @ R(ry=90)        # local: x ao longo da parede (para o sul = +x local), y para cima, +z sai da parede
    m.box((0, 0, 0), (mw + 0.10, mh + 0.10, 0.04), "wv2_paint", c(NAVY), 0.015, 2, rot=mf @ T(0, 0, 0.02))
    m.box((0, 0, 0), (mw, mh, 0.012), "wv2_paint", c("#7FC4E8"), 0.0, 1, rot=mf @ T(0, 0, 0.046))
    land = blob2d(0.52, 40, 7, 0.16, cx=-0.10, cy=0.02, sx=1.25, sy=0.85)
    m.prism((0, 0, 0), land, 0.008, "wv2_paint", c("#F2D9A6"), rot=mf @ T(0, 0, 0.054))
    m.prism((0, 0, 0), blob2d(0.40, 36, 8, 0.15, cx=-0.08, cy=0.06, sx=1.25, sy=0.8), 0.008, "wv2_paint", c("#8ED081"), rot=mf @ T(0, 0, 0.060))
    # cais (tabuas marrons saindo para o mar, a direita)
    m.box((0, 0, 0), (0.34, 0.07, 0.008), "wv2_paint", c("#A87449"), 0.0, 1, rot=mf @ T(0.50, -0.20, 0.066))
    for k in range(4):
        m.box((0, 0, 0), (0.012, 0.07, 0.009), "wv2_paint", c("#7E5434"), 0.0, 1, rot=mf @ T(0.38 + k * 0.08, -0.20, 0.068))
    # praca (circulo de pedras com chafariz azul)
    m.cyl((0, 0, 0), 0.10, 0.008, "wv2_paint", c("#D8CFC2"), seg=24, rot=mf @ T(-0.05, -0.02, 0.066) @ R(rx=90))
    m.cyl((0, 0, 0), 0.04, 0.010, "wv2_paint", c("#4BA3DD"), seg=16, rot=mf @ T(-0.05, -0.02, 0.070) @ R(rx=90))
    # galpao (casinha de telhado vermelho)
    m.box((0, 0, 0), (0.12, 0.08, 0.008), "wv2_paint", c("#F7EFE3"), 0.0, 1, rot=mf @ T(-0.38, 0.14, 0.068))
    m.prism((0, 0, 0), [(-0.08, 0.04), (0.08, 0.04), (0.0, 0.10)], 0.008, "wv2_paint", c("#D9473A"), rot=mf @ T(-0.38, 0.14, 0.070))
    # farol da vila (listras creme/vermelho, luz amarela)
    for k in range(4):
        y = 0.12 + k * 0.045
        wv = 0.05 - k * 0.006
        m.box((0, 0, 0), (wv, 0.045, 0.008), "wv2_paint", c("#FFF6EA" if k % 2 == 0 else "#D9473A"), 0.0, 1,
              rot=mf @ T(0.30, y, 0.068))
    m.prism((0, 0, 0), circle(0.025, 12), 0.008, "wv2_paint", c(YELLOW), rot=mf @ T(0.30, 0.32, 0.068))
    # icones das missoes (estrela, pata, flor), chapados
    m.prism((0, 0, 0), star(5, 0.045, 0.019), 0.008, "wv2_paint", c(YELLOW), rot=mf @ T(0.05, 0.30, 0.070))
    m.prism((0, 0, 0), circle(0.026, 14, sx=1.1), 0.008, "wv2_paint", c("#8A5426"), rot=mf @ T(-0.30, -0.22, 0.070))
    for (px_, py_) in ((-0.335, -0.18), (-0.30, -0.17), (-0.265, -0.18), (-0.345, -0.21)):
        m.prism((0, 0, 0), circle(0.010, 10), 0.008, "wv2_paint", c("#8A5426"), rot=mf @ T(px_ + 0.0, py_ + 0.0, 0.070))
    for k in range(6):
        a = 2 * math.pi * k / 6
        m.prism((0, 0, 0), circle(0.017, 10), 0.008, "wv2_paint", c("#FF7FB0"), rot=mf @ T(0.18 + math.cos(a) * 0.024, -0.30 + math.sin(a) * 0.024, 0.070))
    m.prism((0, 0, 0), circle(0.014, 10), 0.008, "wv2_paint", c(YELLOW), rot=mf @ T(0.18, -0.30, 0.073))
    # rosa dos ventos no canto do mapa
    m.prism((0, 0, 0), star(4, 0.07, 0.018), 0.008, "wv2_paint", c(NAVY), rot=mf @ T(-0.70, 0.38, 0.060))
    # pinos com os rostos do trio: aro na cor do heroi, disco com o retrato do HUD, alfinete
    for k, (hid, hcol, (px_, py_)) in enumerate((("rastro", RASTRO, (-0.20, 0.05)), ("pico", PICO, (0.08, 0.16)),
                                                ("leme", LEME, (0.42, -0.12)))):
        pf2 = mf @ T(px_, py_, 0.09)
        m.cyl((0, 0, 0), 0.105, 0.03, "wv2_glossy", c(hcol), seg=32, rot=pf2 @ R(rx=90) @ T(0, -0.015, 0))
        disc_uv(m, pf2 @ T(0, 0, 0.018), 0.09, 0.01, "f7_pin_" + hid)
        m.cyl((0, 0, 0), 0.006, 0.07, "wv2_metal", c("#AEB7C2"), seg=6, rot=pf2 @ R(rx=90) @ T(0, -0.07, 0))
    # emblema grande da Rota Brava na parede leste (escudo da marca em relevo, faixa dourada e rosa dos ventos)
    ez, ey = EMB
    K = 4.2
    ef = T(XW - 0.02, ey, ez) @ R(ry=-90)
    sp = [(x * K, y * K) for x, y in PV3.shield_poly()]
    rb = [(x * K, y * K) for x, y in PV3.ribbon_poly()]
    rs = [(x * K, y * K) for x, y in PV3.rose_poly()]
    m.prism((0, 0, 0), PV3._offset(sp, 0.05), 0.05, "wv2_glossy", c("#FFFFFF"), rot=ef @ T(0, 0, 0.025))
    m.prism((0, 0, 0), sp, 0.07, "wv2_glossy", c(NAVY), rot=ef @ T(0, 0, 0.040))
    m.prism((0, 0, 0), PV3._offset(rb, 0.022), 0.05, "wv2_glossy", c("#FFFFFF"), rot=ef @ T(0, 0, 0.060))
    m.prism((0, 0, 0), rb, 0.06, "wv2_metal", c(YELLOW), rot=ef @ T(0, 0, 0.075))
    m.prism((0, 0, 0), rs, 0.05, "wv2_metal", c(YELLOW), rot=ef @ T(0, -0.02 * K * 0.0 + 0.0, 0.085) @ T(0, 0.02, 0))
    m.cyl((0, 0, 0), 0.06, 0.05, "wv2_glossy", c(CORAL), seg=20, rot=ef @ T(0, 0.02 + 11 * PV3.EMB_K * K, 0.09) @ R(rx=90))
    # cabide (parede leste, perto da camera): tabua, 3 ganchos, colete de equipe e capacete amarelo
    kz = 1.25
    kf = T(XW - 0.02, 1.70, kz) @ R(ry=-90)
    m.box((0, 0, 0), (0.95, 0.12, 0.04), "wv2_wood", c(WOOD), 0.01, 2, rot=kf @ T(0, 0, 0.02))
    for k in range(3):
        m.tube([tuple(kf @ Vector((-0.32 + k * 0.32, 0.0, 0.04))), tuple(kf @ Vector((-0.32 + k * 0.32, 0.03, 0.14)))], 0.016,
               "wv2_metal", c(BRASS), seg=8)
    # colete (gancho do meio): corpo achatado azul com faixas refletivas amarelas e gola em V
    vf = kf @ T(0.0, -0.36, 0.12)
    vest = MB("tmp")
    bmv = bmesh.new()
    pts = [(-0.20, -0.30), (0.20, -0.30), (0.22, 0.10), (0.15, 0.26), (0.05, 0.10), (-0.05, 0.10), (-0.15, 0.26), (-0.22, 0.10)]
    vs0 = [bmv.verts.new((x, y, -0.04)) for x, y in pts]
    vs1 = [bmv.verts.new((x * 0.96, y, 0.04)) for x, y in pts]
    bmv.faces.new(list(reversed(vs0)))
    bmv.faces.new(vs1)
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        bmv.faces.new((vs0[i], vs0[j], vs1[j], vs1[i]))
    bmesh.ops.recalc_face_normals(bmv, faces=bmv.faces)
    bmesh.ops.bevel(bmv, geom=list(bmv.edges), offset=0.02, segments=2, affect="EDGES")
    m.add_bm(bmv, vf, "pv3_cloth", c("#1F4E8C"), "box")
    for yy in (-0.18, -0.06):
        m.box((0, 0, 0), (0.44, 0.04, 0.09), "pv3_vinyl", c(YELLOW), 0.01, 1, rot=vf @ T(0, yy, 0))
    m.prism((0, 0, 0), [(x * 0.35, y * 0.35) for x, y in PV3.shield_poly()], 0.012, "pv3_vinyl", c(CORAL), rot=vf @ T(0.09, 0.02, 0.045))
    # capacete amarelo no gancho da direita (casco, aba e lanterna)
    hf = kf @ T(0.32, -0.14, 0.14)
    m.lathe((0, 0, 0), [(0.0, 0.17), (0.08, 0.165), (0.14, 0.12), (0.16, 0.05), (0.165, 0.0), (0.18, -0.01), (0.18, -0.03),
                        (0.15, -0.02), (0.0, -0.02)], "pv3_vinyl", c(YELLOW), seg=28, rot=hf @ R(rx=-70))
    m.cyl((0, 0, 0), 0.035, 0.05, "pv3_vinyl", c(NAVY), seg=16, rot=hf @ R(rx=-70) @ T(0, 0.08, 0.15) @ R(rx=80))
    # boia na parede leste ao lado do emblema (coral e branca)
    bf = T(XW - 0.08, 1.15, -1.55) @ R(ry=-90)
    for k in range(8):
        a0, a1 = 2 * math.pi * k / 8, 2 * math.pi * (k + 1) / 8
        arc = [(math.cos(a0 + (a1 - a0) * i / 6) * 0.22, math.sin(a0 + (a1 - a0) * i / 6) * 0.22, 0.0) for i in range(7)]
        m.tube([tuple(bf @ Vector(p)) for p in arc], 0.07, "pv3_vinyl", c(CORAL if k % 2 == 0 else "#FFFFFF"), seg=10)
    # estante baixa na parede oeste sob o mapa: livros nas cores do trio e um radinho de reserva
    sf = T(-XW + 0.22, 0.0, 0.85)
    m.box((0, 0.45, 0), (0.40, 0.9, 1.0), "wv2_paint", c(NAVY), 0.02, 2, rot=sf)
    m.box((0.02, 0.45, 0), (0.36, 0.03, 0.94), "wv2_wood", c(WOOD), 0.006, 1, rot=sf)
    rnd = random.Random(21)
    zz = -0.42
    for k in range(9):
        wbk = rnd.uniform(0.05, 0.09)
        hbk = rnd.uniform(0.26, 0.36)
        m.box((0.0, 0.47 + hbk / 2, zz + wbk / 2), (0.24, hbk, wbk), "wv2_paint", c((RASTRO, PICO, LEME, YELLOW, CORAL)[k % 5]),
              0.008, 1, rot=sf)
        zz += wbk + 0.006
    m.box((0.0, 0.91, 0.20), (0.26, 0.16, 0.34), "wv2_glossy", c(CORAL), 0.02, 2, rot=sf)
    m.cyl((0, 0, 0), 0.05, 0.01, "wv2_metal", c("#DDE3EA"), seg=16, rot=sf @ T(0.13, 0.91, 0.26) @ R(rz=-90))
    return m


# ================================================================== cadeira giratoria
def chair():
    m = MB("Farol7_Chair")
    for k in range(5):
        a = 2 * math.pi * k / 5
        p = (math.sin(a) * 0.30, 0.07, math.cos(a) * 0.30)
        m.tube([(0, 0.11, 0), p], 0.025, "wv2_metal", c("#2B3440"), seg=8)
        m.sphere((p[0], 0.035, p[2]), 0.035, "wv2_glossy", c(NAVY), subd=2)
    m.cyl((0, 0.08, 0), 0.05, 0.06, "wv2_metal", c("#2B3440"), seg=16)
    # G21 r2: assento a 0,40 m (o Lumi sentado alcanca o chao com os pes)
    m.cyl((0, 0.12, 0), 0.028, 0.17, "wv2_metal", c("#AEB7C2"), seg=12)
    m.box((0, 0.35, 0.02), (0.50, 0.10, 0.48), "pv3_vinyl", c(CORAL), 0.045, 3)
    m.box((0, 0.29, 0.02), (0.44, 0.04, 0.42), "wv2_metal", c("#2B3440"), 0.01, 1)
    # encosto (o assento fica de frente para +Z; costas em -Z)
    m.tube([(0, 0.33, -0.18), (0, 0.44, -0.25), (0, 0.55, -0.25)], 0.02, "wv2_metal", c("#2B3440"), seg=8)
    m.box((0, 0.73, -0.25), (0.46, 0.40, 0.09), "pv3_vinyl", c(CORAL), 0.045, 3, rot=T(0, 0, 0) @ R(rx=-6))
    m.box((0, 0.73, -0.30), (0.30, 0.16, 0.02), "wv2_paint", c(YELLOW), 0.008, 1)
    m.prism((0, 0, 0), star(5, 0.06, 0.025), 0.01, "wv2_paint", c(NAVY), rot=T(0, 0.73, -0.31) @ R(ry=180))
    return m


# ================================================================== luz giratoria da base
def beacon():
    base = MB("BeaconBase")
    base.cyl((0, 0, 0), 0.20, 0.08, "wv2_metal", c(NAVY), seg=24, bevel=0.01)
    for k in range(4):
        a = 2 * math.pi * k / 4 + math.pi / 4
        base.cyl((math.cos(a) * 0.17, 0.08, math.sin(a) * 0.17), 0.012, 0.36, "wv2_metal", c(NAVY), seg=6)
    base.cyl((0, 0.08, 0), 0.17, 0.36, "f7_glass", c("#FFF2C0"), seg=24, caps=False)
    base.lathe((0, 0.44, 0), [(0.21, 0.0), (0.20, 0.04), (0.12, 0.12), (0.0, 0.15)], "wv2_glossy", c(CORAL), seg=24)
    spin = MB("BeaconSpin")
    spin.sphere((0, 0.26, 0), 0.08, "f7_lamp", c("#FFF1B0"), subd=2)
    spin.lathe((0, 0, 0), [(0.0, 0.0), (0.06, 0.0), (0.11, 0.06), (0.12, 0.10), (0.0, 0.10)], "wv2_metal", c("#DDE3EA"), seg=20,
               rot=T(0, 0.26, -0.03) @ R(rx=-90))
    # feixe curto (cone aberto para +Z), amarelo: alfa por cor de vertice (1 no foco, 0 na ponta)
    bm = bmesh.new()
    seg, L, r0, r1 = 20, 3.2, 0.09, 0.85
    ra = [bm.verts.new((math.cos(2 * math.pi * i / seg) * r0, 0.0, 0.0)) for i in range(seg)]
    rb = [bm.verts.new((math.cos(2 * math.pi * i / seg) * r1, math.sin(2 * math.pi * i / seg) * r1 * 0.5, L)) for i in range(seg)]
    for v, i in zip(ra, range(seg)):
        v.co.y = math.sin(2 * math.pi * i / seg) * r0
    for i in range(seg):
        j = (i + 1) % seg
        bm.faces.new((ra[i], ra[j], rb[j], rb[i]))
    spin.add_bm(bm, T(0, 0.26, 0.06), "f7_beam", c(YELLOW), "none", shade=lambda pl, pw: 1.0)
    # alfa ao longo do feixe: refaz as cores dos cantos (1 -> 0)
    nb = len(spin.faces) - seg
    for fi in range(nb, len(spin.faces)):
        cols = []
        for vi in spin.faces[fi]:
            z = spin.verts[vi].z - 0.06
            a = max(0.0, 1.0 - z / L) ** 1.6
            cols.append(lin(c(YELLOW)) + (a,))
        spin.ccol[fi] = cols
    return base, spin


# ================================================================== exterior da casa-torre
TOWER_R, TOWER_H = 2.6, 5.4


def tower():
    m = MB("Farol7_Tower")
    rnd = random.Random(77)
    # pedras da ponta (blocos organicos) do nivel do mar (y = -3) ate o pe da torre
    for k in range(22):
        a = rnd.uniform(0, 2 * math.pi)
        rr = rnd.uniform(2.6, 6.2)
        s = rnd.uniform(1.0, 2.3)
        y = -3.0 + rnd.uniform(0.2, 1.4) * (1.6 - rr / 6.2)
        m.sphere((math.cos(a) * rr, y, math.sin(a) * rr), s, "wv2_rock", c("#8E8A86"), subd=2, scale=(1.2, 0.75, 1.0),
                 seed=100 + k, amp=0.22)
    m.cyl((0, -3.2, 0), 3.6, 3.15, "wv2_rock", c("#9A958F"), r1=2.9, seg=24)
    m.cyl((0, -0.12, 0), 2.95, 0.16, "wv2_stone", c("#C8C2B8"), seg=36, bevel=0.03)
    # corpo da torre: reboco branco, faixa marinho, friso amarelo
    m.cyl((0, 0.0, 0), TOWER_R, TOWER_H, "wv2_plaster", c("#F5F2EC"), r1=TOWER_R * 0.93, seg=40, caps=False)
    m.cyl((0, 2.55, 0), TOWER_R * 0.985, 0.55, "wv2_paint", c(NAVY), r1=TOWER_R * 0.975, seg=40, caps=False)
    m.cyl((0, 3.10, 0), TOWER_R * 0.982, 0.10, "wv2_paint", c(YELLOW), seg=40, caps=False)
    # escotilhas acesas (amarelo quente) com aro de latao
    for k, (a, y) in enumerate(((1.75, 1.55), (3.75, 1.55), (0.2, 1.55), (2.25, 4.15), (3.25, 4.15), (0.9, 4.15))):
        rr = TOWER_R * (1.0 - 0.07 * y / TOWER_H) + 0.02
        f = T(math.sin(a) * rr, y, math.cos(a) * rr) @ R(ry=math.degrees(a))
        m.cyl((0, 0, 0), 0.34, 0.10, "wv2_metal", c(BRASS), seg=24, rot=f @ R(rx=90) @ T(0, -0.05, 0))
        m.cyl((0, 0, 0), 0.27, 0.11, "wv2_interior_lit", c("#FFD98A"), seg=24, rot=f @ R(rx=90) @ T(0, -0.05, 0))
    # porta coral com degraus e o emblema em cima
    a = 2.75      # porta virada para a camera do plano 9a (Base_CamExterior, ao norte-leste)
    rr = TOWER_R + 0.03
    df = T(math.sin(a) * rr, 0.0, math.cos(a) * rr) @ R(ry=math.degrees(a))
    m.box((0, 1.0, 0.0), (1.0, 2.0, 0.10), "wv2_paint", c(CORAL), 0.03, 2, rot=df)
    m.box((0, 0, 0), (1.16, 2.12, 0.08), "wv2_paint", c(YELLOW), 0.02, 1, rot=df @ T(0, 1.0, -0.02))
    m.sphere((0, 0, 0), 0.05, "wv2_metal", c(BRASS), subd=1, rot=df @ T(0.36, 1.0, 0.07))
    for k in range(3):
        m.box((0, 0, 0), (1.3, 0.22, 0.35), "wv2_stone", c("#C8C2B8"), 0.03, 1, rot=df @ T(0, -0.1 - k * 0.22, 0.35 + k * 0.30))
    sp = [(x * 2.2, y * 2.2) for x, y in PV3.shield_poly()]
    m.prism((0, 0, 0), PV3._offset(sp, 0.03), 0.03, "wv2_glossy", c("#FFFFFF"), rot=df @ T(0, 2.55, 0.02))
    m.prism((0, 0, 0), sp, 0.04, "wv2_glossy", c(NAVY), rot=df @ T(0, 2.55, 0.04))
    m.prism((0, 0, 0), [(x * 2.2, y * 2.2) for x, y in PV3.rose_poly()], 0.03, "wv2_metal", c(YELLOW), rot=df @ T(0, 2.57, 0.06))
    # beiral, telhado conico marinho com faixa coral e a casinha da luz no topo
    top = TOWER_H
    m.cyl((0, top, 0), TOWER_R * 1.0, 0.18, "wv2_paint", c(YELLOW), seg=40, bevel=0.03)
    m.lathe((0, top + 0.18, 0), [(TOWER_R * 1.12, 0.0), (TOWER_R * 1.10, 0.08), (TOWER_R * 0.55, 1.2), (0.55, 1.75), (0.0, 1.8)],
            "wv2_roof", c("#1F3E66"), seg=40)
    m.lathe((0, top + 0.18, 0), [(TOWER_R * 1.125, 0.02), (TOWER_R * 1.125, 0.10), (TOWER_R * 1.06, 0.18)], "wv2_paint", c(CORAL), seg=40)
    m.cyl((0, top + 1.80, 0), 0.32, 0.12, "wv2_metal", c(NAVY), seg=20)
    # mastro da antena com a bolinha coral (a mesma da sala e do fone do Lumi)
    m.cyl((1.2, top + 0.9, -0.6), 0.03, 2.0, "wv2_metal", c("#AEB7C2"), seg=8)
    m.sphere((1.2, top + 2.95, -0.6), 0.12, "wv2_glossy", c(CORAL), subd=2)
    for k in range(3):
        m.cyl((1.2, top + 1.5 + k * 0.4, -0.6), 0.16 - k * 0.04, 0.03, "wv2_metal", c("#AEB7C2"), seg=10)
    # bandeirinha da equipe
    m.cyl((-1.6, top + 0.5, 0.4), 0.025, 1.6, "wv2_metal", c("#DDE3EA"), seg=8)
    m.prism((0, 0, 0), [(0.0, 0.0), (0.75, -0.18), (0.0, -0.40)], 0.02, "pv3_cloth", c(YELLOW), rot=T(-1.6, top + 2.08, 0.4))
    return m


# ================================================================== fundo da escotilha: mar e a Vila Mare ao longe
def backdrop():
    m = MB("Farol7_Backdrop")
    m.cyl((0, -3.05, -40), 160.0, 0.05, "f7_sea", c("#2F86C4"), seg=48)
    # ilha da vila a ~60 m ao norte: areia, morro verde, casas coloridas, cais e o farol listrado (creme/vermelho)
    vz = -62.0
    m.sphere((-4.0, -3.4, vz), 1.0, "wv2_paint", c("#EBD3A0"), subd=3, scale=(30.0, 3.4, 9.0))
    m.sphere((-8.0, -2.2, vz - 2.0), 1.0, "wv2_leaf", c("#6FBF5A"), subd=3, scale=(17.0, 5.0, 6.0), seed=5, amp=0.08)
    m.sphere((10.0, -2.6, vz - 1.0), 1.0, "wv2_leaf", c("#5FB04E"), subd=3, scale=(10.0, 3.4, 5.0), seed=6, amp=0.10)
    rnd = random.Random(3)
    cols = ("#FF8A1F", "#FFD23A", "#7FC4E8", "#FF7FB0", "#F7EFE3", "#8ED081", "#E2453A")
    for k in range(14):
        x = -20.0 + k * 2.6 + rnd.uniform(-0.6, 0.6)
        z = vz + 4.5 + rnd.uniform(-1.5, 1.0)
        y = -0.6 + rnd.uniform(-0.3, 0.6) + (1.2 if -14 < x < 0 else 0.0)
        w, h = rnd.uniform(1.4, 2.2), rnd.uniform(1.2, 2.0)
        m.box((x, y + h / 2, z), (w, h, 1.6), "wv2_plaster", c(cols[k % len(cols)]), 0.0, 1)
        m.prism((0, 0, 0), [(-w / 2 - 0.15, 0.0), (w / 2 + 0.15, 0.0), (0.0, 0.8)], 1.7, "wv2_roof",
                c(("#D9473A", "#1F3E66", "#B05A3A")[k % 3]), rot=T(x, y + h, z))
    m.box((14.0, -2.4, vz + 7.0), (9.0, 0.3, 1.2), "wv2_deck", c("#A87449"), 0.0, 1)
    # farol da vila: torre listrada, sala da lanterna e cupula vermelha (alto, a esquerda da escotilha)
    lx, lz = -6.5, vz - 1.0
    base = 0.6
    for k in range(6):
        y0 = base + k * 1.45
        r0 = 1.15 - 0.06 * k
        m.cyl((lx, y0, lz), r0, 1.45, "wv2_plaster", c("#FFF6EA" if k % 2 == 0 else "#D9473A"), r1=r0 - 0.06, seg=20, caps=False)
    top = base + 6 * 1.45
    m.cyl((lx, top, lz), 1.0, 0.18, "wv2_stone", c("#D8D2C8"), seg=20)
    m.cyl((lx, top + 0.18, lz), 0.55, 0.9, "f7_lamp", c("#FFE9A0"), seg=16)
    m.lathe((lx, top + 1.08, lz), [(0.75, 0.0), (0.5, 0.35), (0.12, 0.65), (0.0, 0.7)], "wv2_glossy", c("#D9473A"), seg=16)
    # barquinhos e boias no mar entre a base e a vila
    for (bx, bz, bc) in ((6.0, -30.0, "#FFFFFF"), (-12.0, -40.0, "#FFD23A"), (16.0, -46.0, "#E2453A")):
        m.box((bx, -2.85, bz), (2.0, 0.35, 0.8), "wv2_paint", c(bc), 0.1, 2)
        m.cyl((bx, -2.7, bz), 0.04, 1.8, "wv2_wood", c("#A07A56"), seg=6)
        m.prism((0, 0, 0), [(0.0, 0.0), (0.9, 0.0), (0.0, 1.4)], 0.03, "pv3_cloth", c("#FFF6EA"), rot=T(bx + 0.05, -2.5, bz))
    return m


# ================================================================== exportacao
def export_glb(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=True,
                              export_materials="EXPORT", export_cameras=False, export_lights=False, export_extras=False,
                              export_vertex_color="ACTIVE", export_normals=True, export_tangents=False, export_texcoords=True,
                              export_image_format="NONE", export_animations=False, export_skins=False)


PIECES = [
    ("farol7_room", lambda: [room()], "chao da sala em y = 0, centro em x = z = 0; camera olha para -Z", 60000),
    ("farol7_chair", lambda: [chair()], "eixo do pe no chao; assento virado para +Z", 4000),
    ("farol7_beacon", lambda: list(beacon()), "eixo em x = z = 0, base em y = 0; BeaconSpin gira em Y", 2500),
    ("farol7_tower", lambda: [tower()], "eixo da torre, chao da torre em y = 0 (mar em y = -3)", 30000),
    ("farol7_backdrop", lambda: [backdrop()], "mesma origem da sala; mar em y = -3; vila a ~60 m ao norte", 12000),
]


def main():
    reset()
    mats = materials()
    info = {"pecas": {}, "data": "2026-11-27", "blender": bpy.app.version_string,
            "marcos": {"Base_Chair": [CHAIR[0], 0.0, CHAIR[1]], "Base_Porthole": [PORT[0], PORT[1], ZB],
                       "Base_Skylight": [SKY[0], H, SKY[1]], "Beacon_Y": BEACON_Y, "Desk": list(DESK),
                       "Mic": [DESK[0] + 0.77, DESK[1] + 0.31, ZB + 0.60]}}
    sc = bpy.context.scene
    for i, (pid, fn, pivot, budget) in enumerate(PIECES):
        col = bpy.data.collections.new(pid)
        sc.collection.children.link(col)
        random.seed(4000 + i)
        mbs = fn()
        obs = [mb.to_object(mats, col) for mb in mbs]
        path = os.path.join(GLB_DIR, pid + ".glb")
        export_glb(obs, path)
        tris = sum(mb.tris() for mb in mbs)
        info["pecas"][pid] = {"objetos": {mb.name: mb.tris() for mb in mbs}, "triangulos": tris, "orcamento_tris": budget,
                              "materiais": sorted({x for mb in mbs for x in mb.mats}), "pivo": pivot,
                              "glb": "game/assets/models/farol7_base/%s.glb" % pid, "glb_bytes": os.path.getsize(path)}
        print("F7 %-16s tris=%6d orc=%6d bytes=%d" % (pid, tris, budget, os.path.getsize(path)))
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)
    with open(INFO, "w", encoding="utf-8") as f:
        json.dump(info, f, indent=1, ensure_ascii=False, sort_keys=True)


if __name__ == "__main__":
    main()
