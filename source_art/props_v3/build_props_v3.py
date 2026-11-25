"""Rota Brava · Ep01 v3 (RB-R1) · pecas das missoes M2-M7 e pecas gerais (emblema, seta de ajuda, pulso do alvo).

Toda geometria e gerada aqui do zero (bmesh do Blender e formulas proprias, via wv2lib do mundo v2). Nenhum modelo,
malha, textura, foto ou kit de terceiros. Acabamento: os mesmos materiais `wv2_*` da vila v2.1 (texturas procedurais do
projeto) mais 5 materiais `pv3_*` definidos na Godot (game/assets/models/props_v3/props_v3_piece.gd).

CONVENCAO: modelado em coordenadas da GODOT (x leste, y cima, z sul; metros); wv2lib converte para o Blender. Cada peca
vira UM GLB em game/assets/models/props_v3/<id>.glb com a origem no pivo descrito em PIECES.

Uso:
  bash tools/blender.sh --background --factory-startup --python source_art/props_v3/build_props_v3.py
  bash tools/blender.sh --background --factory-startup --python source_art/props_v3/build_props_v3.py -- --renders
Depois: python3 source_art/props_v3/gen_scenes.py (cenas .tscn + manifesto) e a importacao da Godot.
"""
import json
import math
import os
import random
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
sys.path.insert(0, os.path.join(REPO, "source_art", "environment_v2"))
sys.path.insert(0, SCRIPT_DIR)

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Quaternion, Vector  # noqa: E402

from wv2lib import MB, R, S, T, hexc, lin  # noqa: E402

GLB_DIR = os.path.join(REPO, "game", "assets", "models", "props_v3")
BLEND = os.path.join(SCRIPT_DIR, "props_v3.blend")
INFO = os.path.join(SCRIPT_DIR, "props_v3.info.json")
RENDER_DIR = os.environ.get("RB_PROPS_V3_RENDERS", os.path.join(REPO, "captures", "props_v3", "blender"))

# cor de previa no Blender (a Godot troca pelo material da biblioteca pelo NOME)
MAT_PREVIEW = {
    "wv2_wood": "#B08660", "wv2_paint": "#EDEDED", "wv2_metal": "#DDDDDD", "wv2_rope": "#D6BF85", "wv2_leaf": "#5DB043",
    "wv2_bark": "#7A5636", "wv2_glossy": "#FFFFFF", "wv2_burlap": "#C8A878",
    "pv3_cloth": "#FFFFFF", "pv3_vinyl": "#FFFFFF", "pv3_glow": "#FFD23F", "pv3_glow_rim": "#FFFFFF", "pv3_ring": "#FFE680",
}

# paleta (docs/style-bible.md): assinatura dos herois e marca
RASTRO, PICO, LEME = "#FF8A1F", "#3DBE5A", "#2F8CFF"
NAVY, GOLD, CREAM = "#123A5E", "#FFC83D", "#FFF1D6"
STALL_COLORS = {"apple": "#E0412B", "lemon": "#F2C81D", "grapes": "#4A6FD8"}   # = Ep01V3Land.STALL_COLORS
PUP_FUR = "#B9753F"


# ================================================================== utilidades
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


def G(x, y, z):
    """Ponto/vetor Godot -> Blender."""
    return Vector((x, -z, y))


def densify(poly, step=0.025):
    out = []
    n = len(poly)
    for i in range(n):
        a, b = Vector(poly[i]), Vector(poly[(i + 1) % n])
        k = max(1, int(math.ceil((b - a).length / step)))
        for j in range(k):
            out.append(tuple(a.lerp(b, j / k)))
    return out


def bez_q(p0, p1, p2, n=10):
    return [tuple((1 - t) ** 2 * p0[i] + 2 * (1 - t) * t * p1[i] + t * t * p2[i] for i in (0, 1))
            for t in [k / n for k in range(1, n + 1)]]


def bez_c(p0, p1, p2, p3, n=14):
    return [tuple((1 - t) ** 3 * p0[i] + 3 * (1 - t) ** 2 * t * p1[i] + 3 * (1 - t) * t * t * p2[i] + t ** 3 * p3[i]
                  for i in (0, 1)) for t in [k / n for k in range(1, n + 1)]]


def sheet_bm(poly, cuts=2, thick=0.012, disp=None, step=0.03):
    """Tecido: contorno (plano XY local) triangulado, subdividido, deslocado em Z por disp(x, y) e com espessura."""
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, 0.0)) for x, y in densify(poly, step)]
    f = bm.faces.new(vs)
    bmesh.ops.triangulate(bm, faces=[f], quad_method="BEAUTY", ngon_method="BEAUTY")
    # (sem beautify_fill: o resultado variava entre execucoes)
    if cuts:
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
    if disp is not None:
        for v in bm.verts:
            v.co.z = disp(v.co.x, v.co.y)
    _thicken(bm, thick)
    return bm


def _thicken(bm, thick):
    """Espessura de chapa quase plana: copia deslocada em -Z, faces de tras invertidas e costura na borda.
    (bmesh.ops.solidify dava ordem diferente a cada execucao e quebrava o GLB reproduzivel.)"""
    bm.normal_update()
    bm.verts.index_update()
    bm.verts.ensure_lookup_table()
    front = list(bm.verts)
    back = [bm.verts.new((v.co.x, v.co.y, v.co.z - thick)) for v in front]
    faces = list(bm.faces)
    border = [e for e in bm.edges if len(e.link_faces) == 1]
    for f in faces:
        if f.normal.z < 0:
            f.normal_flip()
    for f in faces:
        bm.faces.new([back[v.index] for v in reversed(f.verts)])
    for e in border:
        f = e.link_faces[0]
        vs = list(f.verts)
        a, b = e.verts
        ia, ib = vs.index(a), vs.index(b)
        if (ia + 1) % len(vs) != ib:   # mesma direcao da face da frente
            a, b = b, a
        bm.faces.new((b, a, back[a.index], back[b.index]))
    bm.normal_update()


def flat_ring_bm(r0, r1, seg=48):
    """Anel plano (coroa circular) no plano XZ, face para +Y (Godot)."""
    bm = bmesh.new()
    inner, outer = [], []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        inner.append(bm.verts.new((math.sin(a) * r0, 0.0, math.cos(a) * r0)))
        outer.append(bm.verts.new((math.sin(a) * r1, 0.0, math.cos(a) * r1)))
    for i in range(seg):
        j = (i + 1) % seg
        bm.faces.new((inner[i], inner[j], outer[j], outer[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        if f.normal.y < 0:
            f.normal_flip()
    return bm


def clothespin(m, x, y=0.0, z=0.0):
    """Prendedor de madeira (2 pernas + mola de arame) com a boca no varal (y = 0)."""
    wood = hexc("#E2C597")
    for s in (-1, 1):
        m.box((x, y + 0.004, z + s * 0.0065), (0.014, 0.075, 0.011), "wv2_wood", wood, 0.003, 1, grain="y")
    m.cyl((x - 0.009, y + 0.012, z), 0.0045, 0.018, "wv2_metal", hexc("#B9BEC4"), seg=6, rot=R(rz=90))


# ================================================================== M2: roupas do varal e cesto
def tshirt():
    """Camiseta rosa com estrela no peito, presa pelos ombros (2 prendedores). Pivo: meio da gola no varal."""
    m = MB("pv3_cloth_tshirt")
    neck = [(-0.075, 0.0)] + [(math.cos(a) * 0.075, -math.sin(a) * 0.05) for a in
                              [math.pi - k * math.pi / 8 for k in range(1, 8)]] + [(0.075, 0.0)]
    poly = [(-0.075, 0.0), (-0.175, -0.008), (-0.285, -0.065), (-0.245, -0.165), (-0.165, -0.13), (-0.168, -0.415),
            (-0.06, -0.425), (0.06, -0.425), (0.168, -0.415), (0.165, -0.13), (0.245, -0.165), (0.285, -0.065),
            (0.175, -0.008)] + list(reversed(neck[1:-1]))

    def disp(x, y):
        return 0.014 * math.sin(x * 24.0 + 0.6) * min(1.0, -y * 4.0) + 0.02 * math.sin(math.pi * min(1.0, -y / 0.42)) * \
            math.cos(x * 6.0)
    m.add_bm(sheet_bm(poly, 2, 0.012, disp), T(0, 0, 0), "pv3_cloth", hexc("#E85D75"), uv="box", grain="x")
    # barra e punhos (debrum em tom mais escuro)
    for x0, x1, y in ((-0.168, 0.168, -0.415),):
        m.box(((x0 + x1) / 2, y + 0.006, 0.0), (x1 - x0, 0.016, 0.026), "pv3_cloth", hexc("#C9435C"), 0.006, 1)
    # estrela amarela no peito (frente +Z e costas -Z)
    star = [(math.cos(math.pi / 2 + i * math.pi / 5) * (0.07 if i % 2 == 0 else 0.03),
             math.sin(math.pi / 2 + i * math.pi / 5) * (0.07 if i % 2 == 0 else 0.03)) for i in range(10)]
    for s in (1, -1):
        z = disp(0.0, -0.2) + s * 0.016
        m.prism((0, -0.2, z), star, 0.006, "pv3_vinyl", hexc("#FFD23F"), rot=R(ry=0 if s > 0 else 180))
    for x in (-0.15, 0.15):
        clothespin(m, x)
    return m


def scarf():
    """Lenco azul de bolinhas brancas dobrado em triangulo sobre o varal. Pivo: meio da dobra no varal."""
    m = MB("pv3_cloth_scarf")
    poly = [(-0.22, 0.0), (0.22, 0.0), (0.03, -0.31), (0.0, -0.325), (-0.03, -0.31)]

    def disp(x, y):
        return 0.012 * math.sin(x * 20.0) * min(1.0, -y * 5.0) + 0.008 * math.sin(y * 30.0 + x * 8.0)
    m.add_bm(sheet_bm(poly, 2, 0.01, disp), T(0, 0, 0), "pv3_cloth", hexc("#3F8FDA"), uv="box")
    # dobra sobre o varal (rolinho)
    m.tube([(-0.22, 0.004, 0.0), (0.0, 0.006, 0.0), (0.22, 0.004, 0.0)], 0.011, "pv3_cloth", hexc("#3584CE"), seg=8)
    rng = random.Random(31)
    dots = [(-0.14, -0.04), (-0.06, -0.06), (0.03, -0.045), (0.12, -0.05), (-0.09, -0.13), (0.0, -0.13), (0.08, -0.12),
            (-0.03, -0.21), (0.04, -0.2), (0.0, -0.27)]
    for x, y in dots:
        r = rng.uniform(0.014, 0.019)
        for s in (1, -1):
            m.cyl((0, 0, 0), r, 0.004, "pv3_cloth", hexc("#FFFFFF"), seg=10,
                  rot=T(x, y, disp(x, y) + s * 0.012) @ R(rx=90 * s))
    # franjas na ponta
    for k in range(5):
        x = -0.02 + k * 0.01
        m.box((x, -0.335, 0.0), (0.005, 0.03, 0.005), "pv3_cloth", hexc("#FFFFFF"), 0.0, 1)
    for x in (-0.17, 0.17):
        clothespin(m, x)
    return m


def sock():
    """Meia amarela listrada com tufos de pelo do filhote (a pista do M2). Pivo: meio do punho no varal."""
    m = MB("pv3_cloth_sock")
    toe = [(0.155 + math.cos(a) * 0.05, -0.255 + math.sin(a) * 0.05) for a in [math.radians(90 - k * 30) for k in range(7)]]
    heel = [(math.cos(a) * 0.05, -0.255 + math.sin(a) * 0.05) for a in [math.radians(270 - k * 30) for k in range(1, 4)]]
    poly = [(-0.05, 0.0), (0.05, 0.0), (0.05, -0.19), (0.155, -0.205)] + toe + [(0.05, -0.305)] + heel + [(-0.05, -0.19)]

    def disp(x, y):
        return 0.01 * math.sin(y * 22.0) + 0.006 * math.cos(x * 30.0)
    yellow = hexc("#F2C81D")
    m.add_bm(sheet_bm(poly, 2, 0.022, disp), T(0, 0, 0), "pv3_cloth", yellow, uv="box",
             shade=lambda pl, pw: 0.72 if (int((-pl.y + 0.02) / 0.035) % 2 == 1 and pl.y > -0.17) else 1.0)
    # punho canelado (branco) e calcanhar/ponta laranja
    m.box((0.0, -0.022, 0.0), (0.11, 0.044, 0.03), "pv3_cloth", hexc("#FFF6E8"), 0.008, 1)
    for s in (1, -1):
        m.sphere((0.175, -0.255, s * 0.006), 0.045, "pv3_cloth", hexc("#FF8A3D"), subd=2, scale=(1.0, 0.95, 0.3))
        m.sphere((0.0, -0.262, s * 0.006), 0.04, "pv3_cloth", hexc("#FF8A3D"), subd=2, scale=(1.0, 0.95, 0.3))
    # tufos de pelo do filhote (a pista): cones fofos castanhos grudados nos dois lados
    rng = random.Random(77)
    for k in range(9):
        x, y = rng.uniform(-0.035, 0.16), rng.uniform(-0.28, -0.07)
        if x > 0.05 and y > -0.2:
            x = rng.uniform(-0.035, 0.04)
        s = 1 if k % 3 else -1
        for j in range(3):
            m.cyl((0, 0, 0), 0.007, 0.03 + rng.uniform(0, 0.015), "pv3_vinyl", hexc(PUP_FUR, rng.uniform(0.85, 1.1)), r1=0.0,
                  seg=5, rot=T(x + j * 0.006, y, s * 0.018) @ R(rx=s * rng.uniform(45, 80), rz=rng.uniform(-60, 60)))
    clothespin(m, 0.0)
    return m


def basket():
    """Cesto de vime oval com alcas. Pivo: centro do fundo, no chao."""
    m = MB("pv3_basket")
    rng = random.Random(41)
    wick = hexc("#D2A46A")
    prof = [(0.0, 0.0), (0.2, 0.0), (0.215, 0.015), (0.245, 0.24), (0.262, 0.262), (0.25, 0.275), (0.232, 0.26),
            (0.2, 0.03), (0.0, 0.03)]
    m.lathe((0, 0, 0), prof, "wv2_burlap", wick, seg=24, rot=S(1.3, 1.0, 0.95))
    # fiadas do trancado (aneis alternados) e varetas verticais
    for k in range(7):
        y = 0.03 + k * 0.032
        rr = 0.205 + (0.245 - 0.205) * (y / 0.24) + 0.006
        pts = [(math.sin(a) * rr * 1.3, y, math.cos(a) * rr * 0.95) for a in [i / 32 * 2 * math.pi for i in range(33)]]
        m.tube(pts, 0.0075, "wv2_wood", hexc("#C9935A" if k % 2 else "#DDB07A"), seg=4, caps=False, rng=rng)
    for i in range(18):
        a = i / 18 * 2 * math.pi
        p0 = (math.sin(a) * 0.212 * 1.3, 0.02, math.cos(a) * 0.212 * 0.95)
        p1 = (math.sin(a) * 0.25 * 1.3, 0.245, math.cos(a) * 0.25 * 0.95)
        m.tube([p0, p1], 0.005, "wv2_wood", hexc("#B98450"), seg=4, caps=False, rng=rng)
    # borda torcida e alcas
    rim = [(math.sin(a) * 0.257 * 1.3, 0.268, math.cos(a) * 0.257 * 0.95) for a in [i / 48 * 2 * math.pi for i in range(49)]]
    m.tube(rim, 0.014, "wv2_rope", hexc("#C99A5E"), seg=6, caps=False)
    for s in (1, -1):
        arc = [(s * (0.335 + 0.05 * math.sin(math.pi * t)), 0.24 + 0.07 * math.sin(math.pi * t), -0.09 + 0.18 * t)
               for t in [k / 10 for k in range(11)]]
        m.tube(arc, 0.013, "wv2_rope", hexc("#B98450"), seg=6)
    # toalha dobrada dentro (cor da casa do varal), so para o cesto nao parecer vazio de longe
    m.box((0.05, 0.2, 0.0), (0.3, 0.05, 0.24), "pv3_cloth", hexc("#BDEBD3"), 0.02, 2, rot=R(ry=8, rz=-6))
    return m


# ================================================================== M3: folhas do chafariz e bola
LEAF = [(0.0, -0.06), (0.03, -0.035), (0.04, 0.0), (0.028, 0.04), (0.0, 0.07), (-0.028, 0.04), (-0.04, 0.0), (-0.03, -0.035)]


def leaves():
    """Tufo de folhas molhadas e gravetos que entope a bacia de cima (raio da bacia 0,57). Pivo: centro da base."""
    m = MB("pv3_fountain_leaves")
    rng = random.Random(53)
    m.sphere((0, 0.0, 0), 0.22, "wv2_leaf", hexc("#5B6A2A"), subd=2, scale=(1.15, 0.42, 1.0), seed=5, amp=0.18,
             flat_bottom=0.0)
    m.sphere((0.1, 0.0, -0.08), 0.13, "wv2_leaf", hexc("#6E7A30"), subd=1, scale=(1.0, 0.5, 1.0), seed=6, amp=0.2,
             flat_bottom=0.0)
    cols = ["#C98A2E", "#B5652A", "#8A9A3A", "#6E9A35", "#D9A23A", "#9C5A28"]
    for k in range(30):
        a = rng.uniform(0, 2 * math.pi)
        rr = math.sqrt(rng.uniform(0.0, 1.0)) * 0.24
        x, z = math.cos(a) * rr * 1.1, math.sin(a) * rr
        y = 0.085 * max(0.0, 1 - (rr / 0.27) ** 2) + 0.01 + rng.uniform(0, 0.02)
        sc = rng.uniform(0.9, 1.5)
        m.prism((0, 0, 0), [(px * sc, py * sc) for px, py in LEAF], 0.006, "wv2_leaf", hexc(rng.choice(cols)),
                rot=T(x, y, z) @ R(ry=rng.uniform(0, 360), rx=90 + rng.uniform(-35, 35), rz=rng.uniform(-25, 25)))
    for k in range(4):
        a = rng.uniform(0, 2 * math.pi)
        p0 = Vector((math.cos(a) * 0.05, 0.06, math.sin(a) * 0.05))
        d = Vector((math.cos(a), rng.uniform(0.1, 0.4), math.sin(a))).normalized()
        pts = [p0 + d * (0.08 * i) + Vector((0, -0.01 * i * i, 0)) for i in range(5)]
        m.tube([tuple(p) for p in pts], 0.007, "wv2_bark", hexc("#6B4A2E"), seg=5)
        m.tube([tuple(pts[2]), tuple(pts[2] + Vector((d.z, 0.6, -d.x)).normalized() * 0.07)], 0.004, "wv2_bark", hexc("#6B4A2E"), seg=4)
    return m


def _sphere_patch(m, r, lon0, lon1, lat0, lat1, nlon, nlat, mat, col, center=(0, 0, 0)):
    bm = bmesh.new()
    rows = []
    for j in range(nlat + 1):
        la = lat0 + (lat1 - lat0) * j / nlat
        row = []
        for i in range(nlon + 1):
            lo = lon0 + (lon1 - lon0) * i / nlon
            row.append(bm.verts.new((math.cos(la) * math.sin(lo) * r, math.sin(la) * r, math.cos(la) * math.cos(lo) * r)))
        rows.append(row)
    for j in range(nlat):
        for i in range(nlon):
            a, b, c, d = rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]
            if len({a, b, c, d}) == 4 and (a.co - d.co).length > 1e-6 and (b.co - c.co).length > 1e-6:
                bm.faces.new((a, b, c, d))
            else:
                vv = [v for v in (a, b, c, d)]
                uniq = []
                for v in vv:
                    if all((v.co - u.co).length > 1e-6 for u in uniq):
                        uniq.append(v)
                if len(uniq) == 3:
                    bm.faces.new(uniq)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    for f in bm.faces:   # retalho aberto: normal para fora pelo centro da esfera
        if f.normal.dot(f.calc_center_median()) < 0:
            f.normal_flip()
    m.add_bm(bm, T(*center), mat, col, uv="none")


def ball():
    """Bola do filhote: 6 gomos (vermelho, branco, amarelo...) e tampas brancas, vinil brilhante. Raio 0,16.
    Pivo: ponto de contato no chao; a malha fica no filho Spin (centro a 0,16 m) para rolar."""
    m = MB("pv3_ball")
    r = 0.16
    cols = ["#E8452C", "#FFFFFF", "#FFD23F", "#E8452C", "#FFFFFF", "#2F8CFF"]
    lat_cap = math.radians(72)
    for g in range(6):
        _sphere_patch(m, r, g * math.pi / 3, (g + 1) * math.pi / 3, -lat_cap, lat_cap, 4, 12, "wv2_glossy", hexc(cols[g]))
    for s in (1, -1):
        _sphere_patch(m, r, 0, 2 * math.pi, s * lat_cap, s * math.pi / 2, 24, 3, "wv2_glossy", hexc("#FFFFFF"))
        m.cyl((0, 0, 0), 0.03, 0.006, "wv2_glossy", hexc("#E8452C"), seg=14, rot=R(rx=0 if s > 0 else 180) @ T(0, r - 0.002, 0))
    return m


# ================================================================== M4: caixotes de entrega
def fruit_icon(m, f, fruit):
    """Icone de fruta IGUAL ao das placas das barracas (wv3_world.stall_icons), no referencial f (face +Z)."""
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


def fruit_ball(m, p, fruit, rng, s=1.0):
    x, y, z = p
    if fruit == "apple":
        m.sphere((x, y, z), 0.042 * s, "wv2_glossy", hexc("#E8442E", rng.uniform(0.9, 1.05)), subd=2, scale=(1, 0.9, 1))
        m.cyl((x, y + 0.03 * s, z), 0.004, 0.02, "wv2_wood", hexc("#6B4A2E"), seg=5)
    elif fruit == "lemon":
        m.sphere((x, y, z), 0.036 * s, "wv2_glossy", hexc("#F7D531", rng.uniform(0.92, 1.05)), subd=2, scale=(1.35, 0.95, 1.0),
                 rot=R(ry=rng.uniform(0, 180)))
    else:
        for k in range(7):
            a = k * 2.4
            m.sphere((x + math.cos(a) * 0.022 * (k > 0), y - 0.012 * (k // 3), z + math.sin(a) * 0.022 * (k > 0)), 0.018 * s,
                     "wv2_glossy", hexc("#6B4FC8", rng.uniform(0.9, 1.08)), subd=1)


def crate(fruit):
    """Caixote de entrega pintado na cor da barraca, placa creme com o icone da fruta nos dois lados longos e frutas por
    cima. 0,42 x 0,28 x 0,32 m (= caixa provisoria da E4). Pivo: centro do fundo."""
    m = MB("pv3_crate_" + fruit)
    rng = random.Random({"apple": 61, "lemon": 62, "grapes": 63}[fruit])
    col = hexc(STALL_COLORS[fruit])
    dark = tuple(c * 0.78 for c in col)
    W, H, D, b = 0.42, 0.28, 0.32, 0.028
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.box((sx * (W / 2 - b / 2), H / 2, sz * (D / 2 - b / 2)), (b, H, b), "wv2_paint", dark, 0.006, 1, grain="y", rng=rng)
    m.box((0, 0.01, 0), (W - 0.01, 0.02, D - 0.01), "wv2_wood", hexc("#B48A60"), 0.004, 1, rng=rng)
    for k, (y0, y1) in enumerate(((0.02, 0.12), (0.135, 0.26))):
        yc, h = (y0 + y1) / 2, y1 - y0
        tone = tuple(c * rng.uniform(0.93, 1.03) for c in col)
        for sz in (-1, 1):
            m.box((0, yc, sz * (D / 2 - 0.012)), (W - 2 * b + 0.004, h, 0.02), "wv2_paint", tone, 0.005, 1, rng=rng)
        for sx in (-1, 1):
            if k == 1:   # pega vazada nas cabeceiras
                for zz in (-1, 1):
                    m.box((sx * (W / 2 - 0.012), yc, zz * 0.085), (0.02, h, D - 2 * b - 0.17 + 0.004), "wv2_paint", tone, 0.005, 1,
                          grain="z", rng=rng)
                m.box((sx * (W / 2 - 0.012), y0 + 0.025, 0), (0.02, 0.05, 0.1), "wv2_paint", tone, 0.005, 1, grain="z", rng=rng)
                m.box((sx * (W / 2 - 0.016), yc + 0.02, 0), (0.012, 0.07, 0.1), "wv2_wood", hexc("#3B2A1E"), 0.0, 1)
            else:
                m.box((sx * (W / 2 - 0.012), yc, 0), (0.02, h, D - 2 * b + 0.004), "wv2_paint", tone, 0.005, 1, grain="z", rng=rng)
    for sz in (-1, 1):
        m.box((0, H - 0.009, sz * (D / 2 - b / 2)), (W - 2 * b, 0.018, b), "wv2_paint", dark, 0.005, 1, rng=rng)
    for sx in (-1, 1):
        m.box((sx * (W / 2 - b / 2), H - 0.009, 0), (b, 0.018, D - 2 * b), "wv2_paint", dark, 0.005, 1, grain="z", rng=rng)
    # placa creme com aro da cor e icone (escala da placa da barraca: raio 0,3 -> 0,085)
    for sz in (1, -1):
        f = T(0, 0.14, sz * (D / 2 + 0.002)) @ R(ry=0 if sz > 0 else 180)
        m.cyl((0, 0, 0), 0.098, 0.012, "wv2_paint", tuple(c * 0.7 for c in col), seg=22, rot=f @ R(rx=90), bevel=0.003)
        m.cyl((0, 0, 0), 0.086, 0.016, "wv2_paint", hexc("#FFF4E0"), seg=22, rot=f @ R(rx=90))
        fruit_icon(m, f @ T(0, 0, 0.012) @ S(0.27), fruit)
    # frutas por cima (monte)
    pts = []
    for k in range(9):
        x, z = rng.uniform(-0.15, 0.15), rng.uniform(-0.1, 0.1)
        if all(math.hypot(x - a, z - c) > 0.07 for a, _, c in pts):
            pts.append((x, H - 0.03 + rng.uniform(0, 0.02), z))
    for p in pts:
        fruit_ball(m, p, fruit, rng)
    return m


# ================================================================== M5: peixe e gaivota
def fish():
    """Peixe prateado-azul (o roubado pela gaivota), olho de desenho. 0,34 m. Frente (cabeca) = +X.
    Pivo: meio do corpo (onde o bico da gaivota segura)."""
    m = MB("pv3_fish")
    prof = [(0.0, -0.165), (0.016, -0.15), (0.032, -0.11), (0.052, -0.05), (0.062, 0.0), (0.06, 0.05), (0.05, 0.1),
            (0.034, 0.135), (0.014, 0.155), (0.0, 0.162)]

    def shade(pl, pw):
        t = max(0.0, min(1.0, (pw.y + 0.02) / 0.08))
        return 1.0 - 0.45 * t * t
    m.lathe((0, 0, 0), prof, "wv2_glossy", hexc("#C9DDEB"), seg=16, rot=S(1, 1, 0.55) @ R(rz=-90), shade=shade)
    blue = hexc("#4F86B8")
    m.prism((0, 0, 0), [(-0.15, 0.0), (-0.215, 0.07), (-0.2, 0.0), (-0.215, -0.07)], 0.01, "wv2_glossy", blue)
    m.prism((0, 0, 0), [(-0.06, 0.05), (0.03, 0.06), (-0.01, 0.1), (-0.08, 0.085)], 0.008, "wv2_glossy", blue)
    m.prism((0, 0, 0), [(-0.07, -0.04), (-0.02, -0.05), (-0.06, -0.075)], 0.006, "wv2_glossy", blue)
    for s in (1, -1):
        m.prism((0, 0, 0), [(0.03, -0.01), (0.07, -0.0), (0.02, -0.04)], 0.004, "wv2_glossy", blue,
                rot=T(0, 0, s * 0.03) @ R(ry=s * 20))
        m.sphere((0.1, 0.012, s * 0.026), 0.019, "wv2_glossy", hexc("#FFFFFF"), subd=2, scale=(1, 1, 0.5))
        m.sphere((0.106, 0.014, s * 0.033), 0.011, "wv2_glossy", hexc("#1B1F24"), subd=1, scale=(1, 1, 0.5))
        m.sphere((0.11, 0.019, s * 0.037), 0.0035, "wv2_glossy", hexc("#FFFFFF"), subd=1)
        # escamas: duas fileiras de "v" mais escuros
        for i in range(4):
            m.prism((0, 0, 0), [(0.0, 0.0), (0.012, 0.012), (0.0, 0.024), (0.006, 0.012)], 0.002, "wv2_glossy",
                    hexc("#8FB3CF"), rot=T(-0.06 + i * 0.03, -0.01, s * (0.033 - abs(i - 1.5) * 0.002)) @ R(ry=0 if s > 0 else 180))
    m.box((0.158, -0.008, 0), (0.012, 0.006, 0.022), "wv2_glossy", hexc("#2E3540"), 0.0, 1)
    return m


GULL_BONES = [  # nome, cabeca (Godot), cauda (Godot), pai
    ("root", (0, 0, 0), (0, 0.1, 0), None),
    ("body", (0, 0.24, -0.04), (0, 0.24, 0.1), "root"),
    ("head", (0, 0.33, 0.12), (0, 0.43, 0.19), "body"),
    ("tail", (0, 0.25, -0.17), (0, 0.24, -0.3), "body"),
    ("wing_in_R", (0.1, 0.31, 0.04), (0.33, 0.31, 0.04), "body"),
    ("wing_out_R", (0.33, 0.31, 0.04), (0.64, 0.31, 0.04), "wing_in_R"),
    ("wing_in_L", (-0.1, 0.31, 0.04), (-0.33, 0.31, 0.04), "body"),
    ("wing_out_L", (-0.33, 0.31, 0.04), (-0.64, 0.31, 0.04), "wing_in_L"),
    ("leg_R", (0.05, 0.17, 0.0), (0.05, 0.02, 0.02), "body"),
    ("leg_L", (-0.05, 0.17, 0.0), (-0.05, 0.02, 0.02), "body"),
]


def gull_parts():
    """Gaivota de brinquedo: corpo branco, manto e asas cinza com pontas pretas e pintas brancas, bico amarelo com mancha
    vermelha, pes laranja, olhos de desenho. Envergadura 1,28 m, 0,5 m de bico a cauda, 0,48 m de altura em pe.
    Frente = +Z (como os herois). Devolve {osso: MB} (pele rigida: cada parte segue 1 osso)."""
    white, grey, black = hexc("#F7F9FB"), hexc("#9FAEC0"), hexc("#2A2E35")
    yellow, orange = hexc("#FFCB2E"), hexc("#FF9A3A")
    under = hexc("#D5DDE6")   # face de baixo da asa (fica para fora com a asa recolhida)
    parts = {}
    b = MB("gull_body")
    b.sphere((0, 0.25, 0.0), 1.0, "pv3_vinyl", white, subd=4, scale=(0.125, 0.12, 0.215))
    b.sphere((0, 0.29, -0.03), 1.0, "pv3_vinyl", grey, subd=2, scale=(0.112, 0.07, 0.17))   # manto (costas)
    b.sphere((0, 0.31, 0.1), 1.0, "pv3_vinyl", white, subd=2, scale=(0.085, 0.085, 0.09))    # pescoco
    parts["body"] = b
    h = MB("gull_head")
    h.sphere((0, 0.41, 0.17), 0.095, "pv3_vinyl", white, subd=4)
    h.cyl((0, 0, 0), 0.032, 0.13, "wv2_glossy", yellow, r1=0.012, seg=12, rot=T(0, 0.395, 0.245) @ R(rx=95))
    h.sphere((0, 0.383, 0.37), 0.016, "wv2_glossy", yellow, subd=1, scale=(1.0, 1.3, 1.0))      # gancho
    h.sphere((0, 0.38, 0.33), 0.012, "wv2_glossy", hexc("#E8442E"), subd=1, scale=(1.2, 1.0, 1.4))   # mancha vermelha
    for s in (1, -1):
        h.sphere((s * 0.055, 0.43, 0.225), 0.034, "wv2_glossy", hexc("#FFFFFF"), subd=2, scale=(0.75, 1.0, 1.0))
        h.sphere((s * 0.068, 0.432, 0.245), 0.02, "wv2_glossy", hexc("#1B1F24"), subd=2, scale=(0.7, 1.0, 1.0))
        h.sphere((s * 0.075, 0.44, 0.255), 0.0065, "wv2_glossy", hexc("#FFFFFF"), subd=1)
        h.box((s * 0.05, 0.47, 0.215), (0.045, 0.012, 0.02), "pv3_vinyl", hexc("#6E7B8C"), 0.004, 1, rot=R(rz=s * -18))
    parts["head"] = h
    t = MB("gull_tail")
    t.prism((0, 0, 0), [(-0.06, 0.0), (0.06, 0.0), (0.085, -0.15), (0.0, -0.135), (-0.085, -0.15)], 0.03, "pv3_vinyl",
            white, rot=T(0, 0.255, -0.17) @ R(rx=98))
    parts["tail"] = t
    for side, s in (("R", 1), ("L", -1)):
        wi = MB("gull_wing_in_" + side)
        inner = [(0.0, 0.075), (0.12, 0.085), (0.25, 0.075), (0.25, -0.12), (0.12, -0.15), (0.0, -0.12)]
        wi.prism((0, 0, 0), [(s * x, z) for x, z in inner], 0.026, "pv3_vinyl", grey, rot=T(0.1 * s, 0.31, 0.04) @ R(rx=90))
        wi.prism((0, 0, 0), [(s * x * 0.98, z * 0.92) for x, z in inner], 0.01, "pv3_vinyl", under,
                 rot=T(0.1 * s, 0.296, 0.035) @ R(rx=90))
        wi.tube([(s * 0.1, 0.31, 0.115), (s * 0.22, 0.312, 0.125), (s * 0.35, 0.31, 0.115)], 0.016, "pv3_vinyl", grey, seg=8)
        parts["wing_in_" + side] = wi
        wo = MB("gull_wing_out_" + side)
        outer = [(0.0, 0.082), (0.14, 0.07), (0.27, 0.035), (0.31, 0.0), (0.27, -0.03), (0.24, -0.07), (0.2, -0.05),
                 (0.17, -0.1), (0.13, -0.075), (0.09, -0.125), (0.05, -0.1), (0.0, -0.13)]
        wo.prism((0, 0, 0), [(s * x, z) for x, z in outer], 0.022, "pv3_vinyl", grey, rot=T(0.33 * s, 0.31, 0.04) @ R(rx=90))
        tip = [(0.15, 0.072), (0.27, 0.035), (0.31, 0.0), (0.27, -0.03), (0.24, -0.07), (0.2, -0.05), (0.17, -0.1), (0.15, -0.09)]
        wo.prism((0, 0, 0), [(s * x, z) for x, z in tip], 0.026, "pv3_vinyl", black, rot=T(0.33 * s, 0.31, 0.04) @ R(rx=90))
        wo.prism((0, 0, 0), [(s * x, z * 0.9) for x, z in ((0.0, 0.082), (0.15, 0.07), (0.15, -0.08), (0.13, -0.075), (0.09, -0.125),
                                                    (0.05, -0.1), (0.0, -0.13))], 0.01, "pv3_vinyl", under,
                 rot=T(0.33 * s, 0.298, 0.035) @ R(rx=90))
        for px, pz in ((0.235, 0.005), (0.18, -0.03)):
            wo.cyl((0, 0, 0), 0.016, 0.004, "pv3_vinyl", hexc("#FFFFFF"), seg=10, rot=T(0.33 * s + s * px, 0.324, 0.04 + pz))
        parts["wing_out_" + side] = wo
        lg = MB("gull_leg_" + side)
        lg.cyl((0, 0, 0), 0.013, 0.16, "wv2_glossy", orange, seg=8, rot=T(s * 0.05, 0.02, 0.02) @ R(rx=-7))
        lg.prism((0, 0, 0), [(0.0, -0.015), (-0.05, 0.06), (-0.018, 0.05), (0.0, 0.075), (0.018, 0.05), (0.05, 0.06)], 0.012,
                 "wv2_glossy", orange, rot=T(s * 0.05, 0.006, 0.02) @ R(rx=90))
        parts["leg_" + side] = lg
    return parts


def build_gull(mats, col):
    parts = gull_parts()
    objs = []
    for bone, mb in parts.items():
        ob = mb.to_object(mats, col)
        vg = ob.vertex_groups.new(name=bone)
        vg.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
        objs.append(ob)
    tris = sum(mb.tris() for mb in parts.values())
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    body = [o for o in objs if o.name.startswith("gull_body")][0]
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    body.name = "pv3_gull"
    body.data.name = "pv3_gull"
    # esqueleto
    arm = bpy.data.armatures.new("gull_rig")
    rig = bpy.data.objects.new("gull_rig", arm)
    col.objects.link(rig)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    ebs = {}
    for name, hd, tl, parent in GULL_BONES:
        eb = arm.edit_bones.new(name)
        eb.head = G(*hd)
        eb.tail = G(*tl)
        eb.roll = 0.0
        if parent:
            eb.parent = ebs[parent]
        eb.use_deform = name != "root"
        ebs[name] = eb
    bpy.ops.object.mode_set(mode="OBJECT")
    body.parent = rig
    for md in list(body.modifiers):
        body.modifiers.remove(md)
    mod = body.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    wn = body.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
    wn.keep_sharp = True
    wn.weight = 50
    wn.mode = "FACE_AREA"
    anims = animate_gull(rig)
    return rig, body, tris, anims


# ------------------------------------------------------------------ animacao da gaivota
GODOT_AX = {"x": (1, 0, 0), "y": (0, 1, 0), "z": (0, 0, 1)}


def _q(pb, rots):
    B = pb.bone.matrix_local.to_3x3()
    Bi = B.inverted()
    q = Quaternion()
    for ax, deg in rots:
        a = Bi @ G(*GODOT_AX[ax])
        q = Quaternion(a.normalized(), math.radians(deg)) @ q
    return q


def _pose_key(rig, frame, pose):
    """pose: {osso: {"r": [(eixo, graus)...], "t": (x, y, z) Godot}} (eixos no repouso, relativos ao pai)."""
    for pb in rig.pose.bones:
        p = pose.get(pb.name, {})
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = _q(pb, p.get("r", []))
        B = pb.bone.matrix_local.to_3x3()
        pb.location = B.inverted() @ G(*p.get("t", (0, 0, 0)))
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        pb.keyframe_insert("location", frame=frame)


def _wings(spread_up, out_up, sweep=0.0, out_sweep=0.0, droop=0.0, out=0.0):
    """Asas: spread_up = graus de subida da asa interna (+ = pontas para cima), out_up = da externa em relacao a interna,
    sweep = recolhe para tras (graus, em torno de Y), droop = inclina o bordo."""
    p = {}
    for side, s in (("R", 1), ("L", -1)):
        p["wing_in_" + side] = {"r": [("x", droop), ("z", s * spread_up), ("y", s * sweep)], "t": (s * out, 0.0, 0.0)}
        p["wing_out_" + side] = {"r": [("z", s * out_up), ("y", s * out_sweep)]}
    return p


# asa recolhida: gira no proprio eixo (plano vertical, bordo de ataque em cima), varre para tras e encosta no flanco
FOLDED = dict(spread_up=-8.0, out_up=0.0, sweep=86.0, out_sweep=6.0, droop=-62.0, out=0.035)


def _merge(*ds):
    out = {}
    for d in ds:
        for k, v in d.items():
            out.setdefault(k, {})
            for kk, vv in v.items():
                if kk == "r":
                    out[k]["r"] = out[k].get("r", []) + list(vv)
                else:
                    out[k][kk] = vv
    return out


LEGS_TUCKED = {"leg_R": {"r": [("x", 75)]}, "leg_L": {"r": [("x", 75)]}}
LEGS_DOWN = {"leg_R": {"r": [("x", 0)]}, "leg_L": {"r": [("x", 0)]}}


def _flap(ph, amp=38.0, center=8.0):
    """Ciclo de batida: ph 0..1. Asa externa atrasa 1/8 de ciclo (dobra no fim da descida)."""
    a = center + amp * math.cos(2 * math.pi * ph)
    b = 0.45 * amp * math.cos(2 * math.pi * (ph - 0.125))
    return a, b


def animate_gull(rig):
    """Acoes (30 qps): fly (loop 0,8 s), glide (loop 2 s), perch_idle (loop 2 s), land (1,2 s), flee (1,0 s).
    land/flee trazem o deslocamento vertical no osso root (land desce de 0,9 m ate o chao; flee sobe 1,1 m e avanca 0,8 m
    para +Z); o movimento no mapa e do jogo."""
    ad = rig.animation_data_create()
    made = {}

    def action(name, loop, frames, fn):
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        ad.action = act
        for f in frames:
            _pose_key(rig, f, fn(f))
        act["loop"] = loop
        ad.action = None
        tr = ad.nla_tracks.new()
        tr.name = name
        st = tr.strips.new(name, int(frames[0]), act)
        st.name = name
        made[name] = {"loop": loop, "frames": [int(frames[0]), int(frames[-1])], "seconds": round((frames[-1] - frames[0]) / 30.0, 3)}

    def fly(f):
        ph = (f % 24) / 24.0
        a, b = _flap(ph)
        bob = -0.025 * math.cos(2 * math.pi * ph)
        return _merge(_wings(a, b), LEGS_TUCKED, {"root": {"t": (0, bob, 0)}, "body": {"r": [("x", -4)]},
                                                  "tail": {"r": [("x", 3 * math.sin(2 * math.pi * ph))]}})
    action("fly", True, list(range(0, 25, 2)), fly)

    def glide(f):
        ph = (f % 60) / 60.0
        bank = 6 * math.sin(2 * math.pi * ph)
        return _merge(_wings(10 + 3 * math.sin(2 * math.pi * ph), 4), LEGS_TUCKED,
                      {"root": {"t": (0, 0.03 * math.sin(2 * math.pi * ph), 0)}, "body": {"r": [("z", bank), ("x", -2)]}})
    action("glide", True, list(range(0, 61, 5)), glide)

    def perch(f):
        ph = (f % 60) / 60.0
        look = 0.0
        if 0.15 < ph < 0.45:
            look = 28 * math.sin(math.pi * (ph - 0.15) / 0.3)
        elif 0.55 < ph < 0.85:
            look = -22 * math.sin(math.pi * (ph - 0.55) / 0.3)
        breath = 0.006 * math.sin(2 * math.pi * ph * 2)
        return _merge(_wings(**FOLDED), LEGS_DOWN, {"root": {"t": (0, breath, 0)}, "head": {"r": [("y", look), ("x", -4 * math.sin(2 * math.pi * ph))]},
                                                   "tail": {"r": [("y", 6 * math.sin(4 * math.pi * ph))]}})
    action("perch_idle", True, list(range(0, 61, 3)), perch)

    def land(f):
        t = f / 36.0
        e = 1 - (1 - t) ** 2
        y = 0.9 * (1 - e)
        z = -0.7 * (1 - e)
        if t < 0.7:
            k = t / 0.7
            a, b = _flap((f % 12) / 12.0, amp=42 * (1 - 0.5 * k), center=20.0)
            w = _wings(a, b, droop=-10 * k)
            legs = {"leg_R": {"r": [("x", 75 * (1 - k) - 25 * k)]}, "leg_L": {"r": [("x", 75 * (1 - k) - 25 * k)]}}
            body = {"body": {"r": [("x", -4 - 18 * k)]}}
        else:
            k = (t - 0.7) / 0.3
            w = _wings(20 * (1 - k) + FOLDED["spread_up"] * k, 6 * (1 - k) + FOLDED["out_up"] * k, FOLDED["sweep"] * k,
                       FOLDED["out_sweep"] * k, -10 * (1 - k) + FOLDED["droop"] * k, FOLDED["out"] * k)
            legs = {"leg_R": {"r": [("x", -25 * (1 - k))]}, "leg_L": {"r": [("x", -25 * (1 - k))]}}
            body = {"body": {"r": [("x", -22 * (1 - k))]}}
        return _merge(w, legs, body, {"root": {"t": (0, y, z)}})
    action("land", False, list(range(0, 37, 2)), land)

    def flee(f):
        t = f / 30.0
        if t < 0.2:
            k = t / 0.2
            crouch = -0.05 * math.sin(math.pi * k * 0.5)
            w = _wings(FOLDED["spread_up"] * (1 - k) + 30 * k, FOLDED["out_up"] * (1 - k), FOLDED["sweep"] * (1 - k),
                       FOLDED["out_sweep"] * (1 - k), FOLDED["droop"] * (1 - k), FOLDED["out"] * (1 - k))
            return _merge(w, LEGS_DOWN, {"root": {"t": (0, crouch, 0)}, "body": {"r": [("x", 12 * k)]},
                                         "head": {"r": [("x", -10 * k)]}})
        k = (t - 0.2) / 0.8
        e = k * k * (3 - 2 * k)
        a, b = _flap(((f - 6) % 10) / 10.0, amp=48, center=12)
        legs = {"leg_R": {"r": [("x", 75 * min(1.0, k * 2))]}, "leg_L": {"r": [("x", 75 * min(1.0, k * 2))]}}
        return _merge(_wings(a, b), legs, {"root": {"t": (0, -0.05 * (1 - e) + 1.1 * e, 0.8 * e)},
                                           "body": {"r": [("x", 12 * (1 - e) - 4 * e)]}})
    action("flee", False, list(range(0, 31, 1)), flee)
    # pose de repouso com as asas abertas fica so no esqueleto; o jogo comeca em perch_idle
    for pb in rig.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
    return made


# ================================================================== M6: corda de reboque
def tow_rope():
    """Corda de reboque: trecho de 1 m ao longo de +Z (o jogo escala Z = comprimento), alca de cada ponta em objeto
    proprio (a do fim e movida para z = comprimento, sem esticar) e rolo para o Pico carregar/jogar."""
    span = MB("pv3_rope_span")
    pts = [(0.0, -0.05 * math.sin(math.pi * t), t) for t in [k / 24 for k in range(25)]]
    span.tube(pts, 0.02, "wv2_rope", hexc("#E3C98F"), seg=8)
    coil = MB("pv3_rope_coil")
    hel = []
    for i in range(97):
        a = i / 96 * 4 * 2 * math.pi
        rr = 0.13 + 0.012 * math.sin(i * 0.9)
        hel.append((math.cos(a) * rr, 0.02 + i / 96 * 0.1, math.sin(a) * rr * 0.9))
    coil.tube(hel, 0.02, "wv2_rope", hexc("#E3C98F"), seg=6)
    tail = [hel[-1], (0.16, 0.08, 0.05), (0.2, 0.03, 0.12), (0.22, 0.01, 0.2)]
    coil.tube(tail, 0.02, "wv2_rope", hexc("#E3C98F"), seg=8)
    eye = [(0.22 + math.cos(a) * 0.05, 0.01, 0.25 + math.sin(a) * 0.05) for a in [k / 16 * 2 * math.pi for k in range(17)]]
    coil.tube(eye, 0.018, "wv2_rope", hexc("#D6B676"), seg=6, caps=False)
    eyes = []
    for nm, sg in (("pv3_rope_eye_start", -1), ("pv3_rope_eye_end", 1)):
        e = MB(nm)
        e.tube([(math.cos(a) * 0.045, 0.0, sg * (0.045 + math.sin(a) * 0.045)) for a in [k / 14 * 2 * math.pi for k in range(15)]],
               0.016, "wv2_rope", hexc("#D6B676"), seg=6, caps=False)
        eyes.append(e)
    return span, coil, eyes[0], eyes[1]


# ================================================================== gerais: emblema, seta, pulso
EMB_K = 0.00172


def _svg(pts):
    return [((x - 100.0) * EMB_K, (123.0 - y) * EMB_K) for x, y in pts]


def shield_poly():
    p = [(22, 46)] + bez_q((22, 46), (61, 22), (100, 42)) + bez_q((100, 42), (139, 62), (178, 38))
    p += bez_c((178, 38), (182, 118), (150, 168), (100, 208)) + bez_c((100, 208), (50, 168), (18, 118), (22, 46))[:-1]
    return _svg(p)


def ribbon_poly():
    p = [(30, 150)] + bez_q((30, 150), (100, 182), (170, 150)) + [(178, 176)] + bez_q((178, 176), (100, 210), (22, 176))[:-1]
    return _svg(p)


def rose_poly():
    return _svg([(100, 54), (114, 100), (156, 112), (114, 124), (100, 170), (86, 124), (44, 112), (86, 100)])


def _offset(poly, d):
    """Contorno aproximado para fora (pela media das normais nos vertices) - basta para poligonos suaves."""
    n = len(poly)
    out = []
    area = sum(poly[i][0] * poly[(i + 1) % n][1] - poly[(i + 1) % n][0] * poly[i][1] for i in range(n))
    sg = 1.0 if area > 0 else -1.0
    for i in range(n):
        a, b, c = Vector(poly[i - 1]), Vector(poly[i]), Vector(poly[(i + 1) % n])
        e1, e2 = (b - a).normalized(), (c - b).normalized()
        n1, n2 = Vector((e1.y, -e1.x)) * sg, Vector((e2.y, -e2.x)) * sg
        nn = (n1 + n2)
        nn = nn.normalized() if nn.length > 1e-6 else n1
        out.append(tuple(b + nn * d))
    return out


EMBLEMS = {  # id: (cor do escudo, cor do icone, icone, heroi)
    "paw": (RASTRO, CREAM, "paw", "tracker"),
    "carabiner": (PICO, CREAM, "carabiner", "climber"),
    "helm": (LEME, CREAM, "helm", "pilot"),
    "compass": (NAVY, GOLD, "compass", ""),
    "star": (NAVY, GOLD, "star", ""),
}


def _emb_icon(m, f, icon, col):
    c = hexc(col)
    if icon == "paw":
        m.sphere((0, 0, 0), 1.0, "wv2_glossy", c, subd=2, scale=(0.05, 0.042, 0.012), rot=f @ T(0, -0.03, 0))
        for x, y, r in ((-0.06, 0.025, 0.021), (-0.022, 0.06, 0.022), (0.022, 0.06, 0.022), (0.06, 0.025, 0.021)):
            m.sphere((0, 0, 0), 1.0, "wv2_glossy", c, subd=2, scale=(r * 0.9, r * 1.1, 0.011), rot=f @ T(x, y, 0))
    elif icon == "carabiner":
        pts = []
        for k in range(29):
            a = k / 28 * 2 * math.pi
            x, y = math.cos(a) * 0.045, math.sin(a) * 0.075
            x = x * (1.0 + 0.25 * (y / 0.075))   # mais largo em cima (forma de D)
            pts.append(f @ R(rz=-20) @ Vector((x, y, 0.0)))
        m.tube([tuple(p) for p in pts], 0.011, "wv2_glossy", c, seg=8, caps=False)
        m.box((0, 0, 0), (0.012, 0.075, 0.014), "wv2_glossy", hexc(GOLD), 0.003, 1, rot=f @ R(rz=-20) @ T(0.048, 0.0, 0.004))
    elif icon == "helm":
        ring = [tuple(f @ Vector((math.cos(a) * 0.06, math.sin(a) * 0.06, 0.0))) for a in [k / 16 * 2 * math.pi for k in range(17)]]
        m.tube(ring, 0.011, "wv2_glossy", c, seg=6, caps=False)
        m.cyl((0, 0, 0), 0.02, 0.016, "wv2_glossy", c, seg=14, rot=f @ R(rx=90) @ T(0, -0.008, 0))
        for k in range(8):
            a = k * 45
            m.box((0, 0, 0), (0.0095, 0.088, 0.009), "wv2_glossy", c, 0.0, 1, rot=f @ R(rz=a) @ T(0, 0.044, 0))
            m.sphere((0, 0, 0), 0.012, "wv2_glossy", c, subd=1, rot=f @ R(rz=a) @ T(0, 0.092, 0))
    elif icon == "compass":
        # rosa dos ventos da marca, no mesmo lugar do SVG (centro em y = 11 unidades acima do centro do escudo)
        m.prism((0, 0, 0), rose_poly(), 0.012, "wv2_metal", c, rot=f @ T(0, -0.02, 0))
        m.cyl((0, 0, 0), 0.014, 0.016, "wv2_glossy", hexc(NAVY), seg=12, rot=f @ T(0, -0.02 + 11 * EMB_K, 0) @ R(rx=90))
    else:
        star = [(math.cos(math.pi / 2 + i * math.pi / 5) * (0.085 if i % 2 == 0 else 0.036),
                 math.sin(math.pi / 2 + i * math.pi / 5) * (0.085 if i % 2 == 0 else 0.036)) for i in range(10)]
        m.prism((0, 0, 0), star, 0.012, "wv2_metal", c, rot=f @ T(0, 0.015, 0))


def emblem(key):
    """Moeda-brasao de missao: aro dourado, escudo da marca (game/ui/brand/emblem_*.svg) na cor do heroi, faixa dourada e
    icone em relevo, igual nas duas faces. Raio 0,26, espessura 0,06. Malha centrada (o no Coin fica a 0,75 m do chao)."""
    shield_col, icon_col, icon, _hero = EMBLEMS[key]
    m = MB("pv3_emblem_" + key)
    gold = hexc("#E9B53A")
    prof = [(0.0, -0.021), (0.205, -0.021), (0.212, -0.028), (0.238, -0.031), (0.258, -0.02), (0.262, 0.0), (0.258, 0.02),
            (0.238, 0.031), (0.212, 0.028), (0.205, 0.021), (0.0, 0.021)]
    m.lathe((0, 0, 0), prof, "wv2_metal", gold, seg=28, rot=R(rx=90))
    # serrilha da borda
    for k in range(24):
        a = k / 24 * 360
        m.box((0, 0, 0), (0.012, 0.012, 0.03), "wv2_metal", tuple(x * 0.92 for x in gold), 0.0, 1,
              rot=R(rz=a + 5.6) @ T(0, 0.262, 0))
    sp, rb = shield_poly(), ribbon_poly()
    for s in (1, -1):
        f = R(ry=0 if s > 0 else 180)
        m.prism((0, 0, 0), _offset(sp, 0.013), 0.006, "wv2_glossy", hexc("#FFFFFF"), rot=f @ T(0, 0, 0.024))
        m.prism((0, 0, 0), sp, 0.008, "wv2_glossy", hexc(shield_col), rot=f @ T(0, 0, 0.028))
        m.prism((0, 0, 0), _offset(rb, 0.006), 0.006, "wv2_glossy", hexc("#FFFFFF"), rot=f @ T(0, 0, 0.031))
        m.prism((0, 0, 0), rb, 0.007, "wv2_metal", hexc(GOLD), rot=f @ T(0, 0, 0.034))
        _emb_icon(m, f @ T(0, 0.02, 0.036), icon, icon_col)
    return m


def help_arrow():
    """Seta de ajuda (degrau 3): seta grossa apontando para baixo, ouro com borda branca, frente e verso iguais.
    Pivo: a PONTA (o jogo poe a ponta acima do alvo). Altura 0,66 m."""
    m = MB("pv3_help_arrow")
    head = [(-0.24, 0.27), (0.24, 0.27), (0.0, 0.0)]
    m.prism((0, 0, 0), head, 0.13, "pv3_glow", hexc("#FFD23F"))
    m.box((0, 0.44, 0), (0.18, 0.36, 0.13), "pv3_glow", hexc("#FFD23F"), 0.03, 2)
    m.prism((0, 0, 0), [(-0.29, 0.3), (0.29, 0.3), (0.0, -0.055)], 0.085, "pv3_glow_rim", hexc("#FFFFFF"))
    m.box((0, 0.46, 0), (0.24, 0.42, 0.085), "pv3_glow_rim", hexc("#FFFFFF"), 0.04, 2)
    return m


def target_ring():
    """Pulso de destaque do alvo: 2 aneis planos concentricos (o jogo anima escala e transparencia). Pivo: centro, no chao."""
    a = MB("pv3_ring_outer")
    a.add_bm(flat_ring_bm(0.44, 0.5, 48), T(0, 0.0, 0), "pv3_ring", hexc("#FFE680"), uv="none")
    b = MB("pv3_ring_inner")
    b.add_bm(flat_ring_bm(0.3, 0.33, 40), T(0, 0.0, 0), "pv3_ring", hexc("#FFFFFF"), uv="none")
    return a, b


# ================================================================== exportacao
def export_glb(objs, path, anim=False):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    kw = dict(filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=True,
              export_materials="EXPORT", export_cameras=False, export_lights=False, export_extras=False,
              export_vertex_color="ACTIVE", export_normals=True, export_tangents=False, export_texcoords=True,
              export_image_format="NONE")
    if anim:
        kw.update(export_skins=True, export_animations=True, export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                  export_frame_range=False, export_optimize_animation_size=False, export_def_bones=False)
    else:
        kw.update(export_animations=False, export_skins=False)
    bpy.ops.export_scene.gltf(**kw)


def mesh_tris(ob):
    me = ob.data
    me.calc_loop_triangles()
    return len(me.loop_triangles)


# id: (funcao, pivo, orcamento de tris)
PIECES = [
    ("cloth_tshirt", tshirt, "meio da gola, na linha do varal", 2500),
    ("cloth_scarf", scarf, "meio da dobra, na linha do varal", 2500),
    ("cloth_sock", sock, "meio do punho, na linha do varal", 2500),
    ("basket", basket, "centro do fundo, no chao", 4000),
    ("fountain_leaves", leaves, "centro da base (assenta na agua da bacia de cima)", 3000),
    ("ball", ball, "centro da bola (a cena poe o centro a 0,16 m do chao)", 1500),
    ("crate_apple", lambda: crate("apple"), "centro do fundo", 4500),
    ("crate_lemon", lambda: crate("lemon"), "centro do fundo", 4500),
    ("crate_grapes", lambda: crate("grapes"), "centro do fundo", 4500),
    ("fish", fish, "meio do corpo (pega do bico)", 1500),
    ("help_arrow", help_arrow, "ponta da seta", 600),
] + [("emblem_" + k, (lambda kk: (lambda: emblem(kk)))(k), "centro da moeda", 3000) for k in EMBLEMS]


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    renders = "--renders" in argv
    reset()
    mats = materials()
    info = {"pecas": {}, "data": "2026-11-25", "blender": bpy.app.version_string}
    sc = bpy.context.scene
    export_sets = []
    for i, (pid, fn, pivot, budget) in enumerate(PIECES):
        col = bpy.data.collections.new(pid)
        sc.collection.children.link(col)
        random.seed(1000 + i)   # wv2lib sorteia o deslocamento de UV com o random global: semente fixa por peca
        mb = fn()
        ob = mb.to_object(mats, col)
        ob.name = "pv3_" + pid
        export_sets.append((pid, [ob], False))
        info["pecas"][pid] = {"objetos": {ob.name: mb.tris()}, "triangulos": mb.tris(), "orcamento_tris": budget,
                              "materiais": sorted(set(mb.mats)), "pivo": pivot}
    # corda (2 objetos) e pulso (2 aneis)
    random.seed(2000)
    for pid, objs_mb, pivot, budget in (("tow_rope", tow_rope(), "inicio da corda (o Span vai de z 0 a z 1)", 2500),
                                        ("target_ring", target_ring(), "centro, no chao", 400)):
        col = bpy.data.collections.new(pid)
        sc.collection.children.link(col)
        obs = []
        for mb in objs_mb:
            obs.append(mb.to_object(mats, col))
        export_sets.append((pid, obs, False))
        info["pecas"][pid] = {"objetos": {o.name: mesh_tris(o) for o in obs}, "triangulos": sum(mb.tris() for mb in objs_mb),
                              "orcamento_tris": budget, "materiais": sorted({x for mb in objs_mb for x in mb.mats}),
                              "pivo": pivot}
    # gaivota (esqueleto + acoes)
    col = bpy.data.collections.new("gull")
    sc.collection.children.link(col)
    random.seed(3000)
    rig, body, tris, anims = build_gull(mats, col)
    export_sets.append(("gull", [rig, body], True))
    info["pecas"]["gull"] = {"objetos": {"pv3_gull": tris}, "triangulos": tris, "orcamento_tris": 6000,
                             "materiais": sorted({m.name for m in body.data.materials}),
                             "pivo": "entre os pes, no chao; frente = +Z", "ossos": [b[0] for b in GULL_BONES],
                             "animacoes": anims}
    for pid, objs, anim in export_sets:
        path = os.path.join(GLB_DIR, pid + ".glb")
        export_glb(objs, path, anim)
        info["pecas"][pid]["glb"] = "game/assets/models/props_v3/%s.glb" % pid
        info["pecas"][pid]["glb_bytes"] = os.path.getsize(path)
        print("PV3 %-18s tris=%5d orc=%5d bytes=%d" % (pid, info["pecas"][pid]["triangulos"], info["pecas"][pid]["orcamento_tris"],
                                                   os.path.getsize(path)))
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)
    with open(INFO, "w", encoding="utf-8") as f:
        json.dump(info, f, indent=1, ensure_ascii=False, sort_keys=True)
    if renders:
        import render_props_v3 as RP
        RP.render_all([o for pid, objs, _ in export_sets for o in objs if o.type == "MESH"], rig, RENDER_DIR)


if __name__ == "__main__":
    main()
