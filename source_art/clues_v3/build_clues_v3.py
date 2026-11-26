"""Rota Brava · Ep01 v3 (RB-R1 F2, art3d) · pecas 3D das pistas: bota do capitao (M1), pena solta (M5) e o
pilar de luz do anel de alvo para grama alta (geral).

Toda geometria e gerada aqui do zero (bmesh do Blender e formulas proprias, via wv2lib do mundo v2 e as utilidades do
build_props_v3.py). Nenhum modelo, malha, textura, foto ou kit de terceiros. Mesmo acabamento do props v3: materiais
`wv2_*` da vila e `pv3_*` da Godot (game/assets/models/props_v3/props_v3_piece.gd).

CONVENCAO: coordenadas da GODOT (x leste, y cima, z sul; metros). Um GLB por peca em game/assets/models/props_v3/.

Uso:
  bash tools/blender.sh --background --factory-startup --python source_art/clues_v3/build_clues_v3.py
  bash tools/blender.sh --background --factory-startup --python source_art/clues_v3/build_clues_v3.py -- --renders
Depois: python3 source_art/clues_v3/gen_decals.py ; python3 source_art/clues_v3/gen_scenes_clues.py ; importacao da Godot.
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

import build_props_v3 as PV  # noqa: E402  (utilidades; o main dele nao roda no import)
from wv2lib import MB, R, S, T, hexc, lin  # noqa: E402

GLB_DIR = PV.GLB_DIR
BLEND = os.path.join(SCRIPT_DIR, "clues_v3.blend")
INFO = os.path.join(SCRIPT_DIR, "clues_v3.info.json")
RENDER_DIR = os.environ.get("RB_CLUES_V3_RENDERS", os.path.join(REPO, "captures", "f2_arte", "blender"))

# paleta do capitao (source_art/scripts/hero_lib.py: botas #3A2A22, uniforme #2B4C7E, creme #F7FBFF, ouro #FFC83D)
BOOT_LEATHER = "#55392A"   # um tom acima das botas do modelo: a forma le na sombra da camera baixa
BOOT_SOLE = "#F3E6CC"      # sola clara (bible: "botas grandes com sola clara")
CAP_NAVY = "#2B4C7E"
CAP_CREAM = "#F7FBFF"
# escala de leitura: a 0,5 m a bota virava um ponto de ~30 px a 8 m (captures/f2_arte); 1,45x da ~0,75 m (bota de desenho)
BOOT_SCALE = 1.45


def xform_mb(m, xf):
    """Aplica xf (Godot) a todos os vertices ja acumulados."""
    m.verts = [xf @ v for v in m.verts]


def ground_mb(m):
    """Desce a peca para que o ponto mais baixo fique em y = 0."""
    lo = min(v.y for v in m.verts)
    xform_mb(m, T(0, -lo, 0))


# ================================================================== M1: bota do capitao
def captain_boot():
    """Galocha de marinheiro do capitao, CAIDA DE LADO. Modelada em pe (bico para +Z, sola em y = 0), depois deitada
    sobre o lado de fora (rotacao no eixo do pe), mostrando o perfil em "L" e a sola clara. Medidas exageradas de
    desenho (pe ~0,75 m, cano ~0,6 m depois de BOOT_SCALE) para ler a 8 m na camera baixa. Pivo: centro do contato no chao."""
    m = MB("pv3_captain_boot")
    leather = hexc(BOOT_LEATHER)
    sh_z = -0.1     # eixo do cano (sobre o calcanhar)
    # sola clara (contorno visto de cima, um pouco maior que o pe) e salto
    sole = [(0.0, 0.275), (0.07, 0.262), (0.112, 0.225), (0.124, 0.16), (0.118, 0.07), (0.104, -0.01), (0.1, -0.09),
            (0.104, -0.16), (0.094, -0.205), (0.06, -0.228), (0.0, -0.232)]
    sole = sole + [(-x, z) for x, z in reversed(sole[1:-1])]
    sole = PV.densify(sole, 0.03)
    m.prism((0, 0.024, 0), sole, 0.048, "pv3_vinyl", hexc(BOOT_SOLE), rot=R(rx=90))
    # cravos da sola (barras rasas mais escuras: aparecem com a bota deitada)
    for k in range(5):
        z = 0.2 - k * 0.058
        m.box((0, -0.002, z), (0.17 - 0.012 * abs(k - 1), 0.006, 0.026), "pv3_vinyl", hexc("#B9A27E"), 0.0, 1)
    m.box((0, -0.002, -0.17), (0.15, 0.006, 0.07), "pv3_vinyl", hexc("#B9A27E"), 0.0, 1)
    # pe: um so volume redondo e largo (gaspea + calcanhar), achatado na sola
    m.sphere((0, 0.05, 0.025), 1.0, "pv3_vinyl", leather, subd=3, scale=(0.112, 0.125, 0.235), flat_bottom=-0.02,
             uv="none")
    # biqueira creme (meia casca na frente do pe)
    m.sphere((0, 0.05, 0.175), 1.0, "pv3_vinyl", hexc(BOOT_SOLE), subd=3, scale=(0.1, 0.085, 0.1), flat_bottom=-0.02)
    # cano (torno) com boca aberta, mais curto e gordo (desenho): alarga em cima
    prof = [(0.104, 0.03), (0.108, 0.12), (0.1, 0.22), (0.098, 0.3), (0.106, 0.37), (0.116, 0.4), (0.1, 0.405),
            (0.092, 0.37)]
    m.lathe((0, 0, sh_z), prof, "pv3_vinyl", leather, seg=28)
    m.cyl((0, 0.37, sh_z), 0.092, 0.004, "pv3_vinyl", hexc("#1E140E"), seg=28)   # fundo escuro da boca
    # dobra do cano: faixa creme grossa + listra azul do capitao (anel com sobra para esconder a emenda)
    def ring(r, y, n=28):
        return [(math.sin(a) * r, y, sh_z + math.cos(a) * r) for a in [i / n * 2 * math.pi for i in range(n + 3)]]
    m.tube(ring(0.114, 0.388), 0.03, "pv3_vinyl", hexc(CAP_CREAM), seg=10, caps=False)
    m.tube(ring(0.104, 0.335), 0.013, "pv3_vinyl", hexc(CAP_NAVY), seg=6, caps=False)
    # tira com fivela dourada no peito do pe
    strap = [(math.sin(a) * 0.118, 0.115 + 0.035 * math.cos(a), -0.02 + math.cos(a) * 0.1)
             for a in [i / 24 * 2 * math.pi for i in range(27)]]
    m.tube(strap, 0.017, "pv3_vinyl", hexc(CAP_NAVY), seg=6, caps=False)
    m.box((0.122, 0.118, -0.02), (0.018, 0.065, 0.075), "wv2_metal", hexc("#FFC83D"), 0.008, 1)
    m.box((0.131, 0.118, -0.02), (0.006, 0.036, 0.046), "wv2_metal", hexc("#7A5A1E"), 0.0, 1)
    # alca de puxar atras do cano
    loop = [(0.0, 0.36, sh_z - 0.1), (0.0, 0.42, sh_z - 0.125), (0.0, 0.45, sh_z - 0.1), (0.0, 0.42, sh_z - 0.075)]
    m.tube(loop, 0.012, "pv3_vinyl", hexc(CAP_NAVY), seg=6, caps=False)
    # deita: o cano vira para -Z, o bico para +Z; rola 78 graus sobre o eixo do pe (lado de fora para baixo) e
    # inclina o cano 8 graus para cima (a boca nao some no chao)
    xform_mb(m, S(BOOT_SCALE) @ R(rx=-8) @ R(rz=78))
    ground_mb(m)
    # centro do contato na origem (x, z)
    lo = [v for v in m.verts if v.y < 0.02]
    cx = sum(v.x for v in lo) / len(lo)
    cz = sum(v.z for v in lo) / len(lo)
    xform_mb(m, T(-cx, 0, -cz))
    return m


# ================================================================== M5: pena solta
def feather3d():
    """Pena grande de gaivota (0,5 m, exagerada como as pegadas), branca com ponta escura, deitada no chao com a ponta curvada para cima.
    Pivo: meio da raque, no chao. Ponta para -Z (igual ao decalque)."""
    m = MB("pv3_feather")
    L = 0.5
    vane_lo = -L / 2 + 0.16 * L
    rows, cols = 18, 8
    bm = bmesh.new()
    grid = []
    for i in range(rows + 1):
        t = i / rows
        y = vane_lo + t * (L / 2 - vane_lo)
        cx = 0.05 * L * math.sin(t * 2.4)
        w = 0.21 * L * (math.sin(max(t, 0.02) * math.pi) ** 0.55) * (0.62 + 0.38 * t)
        if i == rows:
            w = 0.004
        notch = 0.55 if 0.5 < t < 0.62 else 1.0     # corte em V no lado esquerdo (pena de verdade)
        row = []
        for j in range(cols + 1):
            u = j / cols * 2 - 1                    # -1 (esquerda) .. 1 (direita)
            ww = w * (notch if u < 0 else 1.0)
            x = cx + u * ww
            # barbas caem para os lados; comprimento arqueado (base e ponta levantam)
            z = 0.03 * (2 * t - 1) ** 2 + 0.06 * max(0.0, t - 0.75) - 0.012 * abs(u) ** 1.5
            row.append(bm.verts.new((x, y, z)))
        grid.append(row)
    for i in range(rows):
        for j in range(cols):
            bm.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]))
    PV._thicken(bm, 0.004)

    def shade(pl, pw):
        u = (pl.y - vane_lo) / (L / 2 - vane_lo)
        tip = max(0.0, min(1.0, (u - 0.74) / 0.1))
        band = 0.07 * (0.5 + 0.5 * math.sin(u * 40.0))    # barbas: faixas leves
        return (1.0 - band) * (1.0 - 0.95 * tip)   # cor de vertice e linear: 0,05 ~ #3A4454 sobre o branco
    # chapa no plano XY local -> deitada (XY -> XZ), ponta para -Z
    m.add_bm(bm, R(rx=-90), "pv3_cloth", hexc("#F7F9FC"), uv="box", shade=shade)
    # raque creme com canhao
    rach = []
    for i in range(13):
        u = i / 12
        y = -L / 2 + u * L * 0.97
        t = (y - vane_lo) / (L / 2 - vane_lo)
        cx = 0.05 * L * math.sin(max(-0.3, t) * 2.4)
        rach.append((cx, 0.006 + 0.03 * (2 * u - 1) ** 2, -y))
    m.tube(rach, lambda f: 0.0055 * (1.0 - 0.6 * f), "pv3_vinyl", hexc("#E9DCC0"), seg=6)
    ground_mb(m)
    return m


# ================================================================== geral: pilar de luz do anel de alvo
def target_beam():
    """Pilar de luz suave (1,9 m) que sai do anel de alvo: cilindro aberto com transparencia na cor de vertice
    (forte embaixo, some em cima). Material `pv3_beam` (aditivo, sem luz). Pivo: centro, no chao."""
    m = MB("pv3_beam")
    h = 1.9
    for k in range(6):   # 6 aneis empilhados: alpha por altura em degraus suaves
        y0, y1 = h * k / 6, h * (k + 1) / 6
        r0 = 0.46 - 0.1 * (k / 6)
        r1 = 0.46 - 0.1 * ((k + 1) / 6)
        m.cyl((0, y0, 0), r0, y1 - y0, "pv3_beam", hexc("#FFE680"), r1=r1, seg=32, caps=False, uv="none")
    # alpha por vertice: 0,55 no chao -> 0 no topo (curva suave)
    m.ccol = [[c[:3] + (0.55 * max(0.0, 1.0 - m.verts[i].y / h) ** 1.6,) for c, i in zip(cols, face)]
              for cols, face in zip(m.ccol, m.faces)]
    return m


# ================================================================== exportacao
PIECES = [
    ("captain_boot", captain_boot, "centro do contato no chao (bota deitada; bico para +Z, cano para -Z)", 3500),
    ("feather", feather3d, "meio da raque, no chao; ponta para -Z", 1600),
    ("target_beam", target_beam, "centro, no chao (sobe 1,9 m)", 600),
]


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    renders = "--renders" in argv
    PV.reset()
    PV.MAT_PREVIEW.setdefault("pv3_beam", "#FFE680")
    mats = PV.materials()
    info = {"pecas": {}, "data": "2026-11-25", "blender": bpy.app.version_string}
    sc = bpy.context.scene
    objs = []
    for i, (pid, fn, pivot, budget) in enumerate(PIECES):
        col = bpy.data.collections.new(pid)
        sc.collection.children.link(col)
        random.seed(5000 + i)
        mb = fn()
        ob = mb.to_object(mats, col)
        ob.name = "pv3_" + pid
        path = os.path.join(GLB_DIR, pid + ".glb")
        PV.export_glb([ob], path, False)
        lo = [min(ob.data.vertices[k].co[a] for k in range(len(ob.data.vertices))) for a in range(3)]
        hi = [max(ob.data.vertices[k].co[a] for k in range(len(ob.data.vertices))) for a in range(3)]
        size_godot = (round(hi[0] - lo[0], 3), round(hi[2] - lo[2], 3), round(hi[1] - lo[1], 3))   # x, y, z Godot
        info["pecas"][pid] = {"objetos": {ob.name: mb.tris()}, "triangulos": mb.tris(), "orcamento_tris": budget,
                              "materiais": sorted(set(mb.mats)), "pivo": pivot, "tamanho_m": list(size_godot),
                              "glb": "game/assets/models/props_v3/%s.glb" % pid, "glb_bytes": os.path.getsize(path)}
        objs.append(ob)
        print("CV3 %-14s tris=%5d orc=%5d tam=%s bytes=%d" % (pid, mb.tris(), budget, size_godot, os.path.getsize(path)))
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)
    with open(INFO, "w", encoding="utf-8", newline="\n") as f:
        json.dump(info, f, indent=1, ensure_ascii=False, sort_keys=True)
    if renders:
        render_mesh(objs, RENDER_DIR)


def render_mesh(objs, out_dir):
    """Imagem da malha (Workbench, cor de vertice + aramado): cada peca em 3/4 e de cima. Fora do Git."""
    import render_props_v3 as RP
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    for ob in objs:
        for o in sc.objects:
            if o.type == "MESH":
                o.hide_render = True
        ob.hide_render = False
        ob.location = (0, 0, 0)
        w = RP._wire_copy(ob, 0.0012)
        w.hide_render = False
        dim = max(ob.dimensions)
        c = ob.matrix_world @ (sum((Vector(b) for b in ob.bound_box), Vector()) / 8)
        RP._setup(sc, 1600, 1000)
        for tag, off in (("34", (1.1, -1.5, 0.85)), ("cima", (0.0, -0.05, 1.9))):
            RP._camera(sc, tuple(c + Vector(off) * dim), tuple(c), lens=50)
            sc.render.filepath = os.path.join(out_dir, "malha_%s_%s.png" % (ob.name[4:], tag))
            bpy.ops.render.render(write_still=True)
        w.hide_render = True


if __name__ == "__main__":
    main()
