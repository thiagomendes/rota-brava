"""Rota Brava · Ep01 v3 (RB-R1 E3) · colisao, limites e marcadores do mundo jogavel da vila v2.1. PROVISORIO.

Gera, a partir dos MESMOS numeros do build (funcoes de terreno, caixas do calcamento, casas registradas, instancias do kit):
  game/worlds/village_v3/village_collision.tscn  (gerado; nao editar a mao)
    Ground      chao: calcamento, cais, terraco, rampa da escadaria + 4 HeightMapShape3D (margem, promontorio, morro, oeste)
    Structures  casas (caixa da planta), galpoes, chafariz em degraus, farol (torre, patamares, galeria), muros, cercas
    Props       aderecos grandes do kit (caixotes, barris, barracas, bancos, postes, carrinho, arvores, rochas...)
    WaterLimits paredes invisiveis na beira d'agua (contorno do nivel -0,3 m, marching squares + simplificacao)
    MapBounds   paredes do limite do mapa
    AccessRamps rampas invisiveis sobre degraus de missao (camada 5 = valor 16, fora da mascara do heroi): o gameplay liga
                com VillageWorld.set_access_ramps(true) ou pondo a camada 5 na mascara do heroi (E3b)
  game/worlds/village_v3/village_world.tscn       (raiz com village_world.gd + colisao + Markers M0-M8)
Formas simples (caixa, cilindro, mapa de altura). Camada 1 (mundo), mascara 0, como as cenas do Ep01.
"""
import math
import os

from mathutils import Matrix, Vector

import wv3_world as W3

GRID = 0.5
WATER_LEVEL = -0.3
BOUNDS = (-40.5, 44.0, -34.5, 24.0)   # x0, x1, z0, z1

# kit -> formas locais: ("box", (sx, sy, sz), (cx, cy, cz)) | ("cyl", r, h, base_y)
KIT_SHAPES = {
    "crate": [("box", (0.6, 0.6, 0.6), (0, 0.3, 0))], "crate_dark": [("box", (0.6, 0.6, 0.6), (0, 0.3, 0))],
    "crate_fish": [("box", (0.6, 0.6, 0.6), (0, 0.3, 0))], "crate_fruit": [("box", (0.6, 0.62, 0.6), (0, 0.31, 0))],
    "barrel": [("cyl", 0.32, 0.9, 0.0)], "barrel_lid": [("cyl", 0.32, 0.98, 0.0)],
    "sack": [("box", (0.6, 0.6, 0.5), (0, 0.3, 0))], "lobster_trap": [("box", (0.78, 0.52, 0.5), (0, 0.26, 0))],
    "bench": [("box", (1.55, 0.48, 0.62), (0, 0.24, 0))], "lamp_post": [("cyl", 0.13, 3.4, 0.0)],
    "bollard": [("cyl", 0.17, 0.56, 0.0)], "cart": [("box", (2.3, 0.9, 1.0), (0, 0.45, 0))],
    "planter": [("box", (1.3, 0.66, 0.45), (0, 0.33, 0))], "sign_aframe": [("box", (0.58, 0.9, 0.5), (0, 0.45, 0))],
    "cafe_set": [("box", (0.7, 0.75, 1.65), (0, 0.375, 0))],
    "stall_red": [("box", (2.4, 0.95, 1.3), (0, 0.475, 0)), ("box", (2.75, 0.4, 1.85), (0, 2.35, 0))],
    "stall_blue": [("box", (2.4, 0.95, 1.3), (0, 0.475, 0)), ("box", (2.75, 0.4, 1.85), (0, 2.35, 0))],
    "stall_yellow": [("box", (2.4, 0.95, 1.3), (0, 0.475, 0)), ("box", (2.75, 0.4, 1.85), (0, 2.35, 0))],
    "tree_a": [("cyl", 0.28, 3.2, 0.0)], "tree_b": [("cyl", 0.22, 3.6, 0.0)], "tree_c": [("cyl", 0.25, 2.6, 0.0)],
    "rock_a": [("box", (0.9, 0.45, 0.8), (0, 0.2, 0))], "rock_b": [("box", (1.7, 0.6, 1.5), (0, 0.25, 0))],
    "rowboat_flip": [("box", (1.3, 0.55, 3.3), (0, 0.27, 0))],
    "pot_c": [("cyl", 0.25, 0.6, 0.0)], "net_pile": [("box", (1.2, 0.28, 0.85), (0, 0.14, 0))],
}
# calcamento e pisos (x0, x1, z0, z1, topo): mesmos numeros de build_quay()/build_dock()
PAVING = [
    ("Dock", -8.03, 8.03, -3.03, 3.0, 0.0),
    ("Street", -22.0, 26.0, -30.1, -12.94, 0.0),
    ("QuayWest", -38.4, -13.94, -13.0, 9.0, 0.0),
    ("CoveWestCoping", -14.5, -13.94, -13.5, 3.0, 0.0),
    ("Plaza", -44.0, -30.0, -39.0, -13.0, 0.0),
    ("QuayEastEnd", 26.0, 26.6, -19.25, -12.75, 0.0),
    ("Terrace", -24.0, 28.0, -36.5, -23.0, 1.2),
]
TERRAIN = [  # nome, funcao, x0, x1, z0, z1 (regioes de build_terrain(), recortadas ao mapa jogavel)
    ("bank", "bank_h", -42.0, 34.0, 1.0, 25.0),
    ("headland", "head_h", 20.0, 46.0, -36.0, -8.0),   # E3b: head_h nasce abaixo da rua em x = 20 (sem degrau na borda)
    ("hill", "hill_h", -42.0, 46.0, -40.0, -31.0),
    ("west", "west_h", -44.0, -38.0, -40.0, 25.0),
]
TERRAIN_FULL = [("bank_h", -14.4, 34.0, 1.0, 46.0), ("bank_h", -42.0, -14.0, 9.0, 46.0), ("hill_h", -80.0, 80.0, -110.0, -31.0),
                ("head_h", 20.0, 46.0, -36.0, -8.0), ("west_h", -90.0, -38.0, -40.0, 46.0)]


def rot_y(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Y")


ACCESS_RAMPS_LAYER = 16   # camada 5 da fisica


class Shapes:
    def __init__(self):
        self.res = []     # sub_resources: (id, type, props)
        self.nodes = []   # (body, name, res_id, basis(3x3), origin)
        self.meta = {}    # (body, name) -> {chave: valor} (metadata do CollisionShape3D)
        self._cache = {}

    def _res(self, kind, props):
        key = (kind, tuple(sorted((k, str(v)) for k, v in props.items())))
        if key in self._cache:
            return self._cache[key]
        rid = "%s_%d" % (kind, len(self.res) + 1)
        self.res.append((rid, kind, props))
        self._cache[key] = rid
        return rid

    def box(self, body, name, size, center, ry=0.0, basis=None):
        rid = self._res("BoxShape3D", {"size": "Vector3(%.3f, %.3f, %.3f)" % tuple(size)})
        self.nodes.append((body, name, rid, basis if basis is not None else rot_y(ry), tuple(center)))

    def ramp(self, body, name, low, high, width, meta, thick=0.3):
        """Caixa inclinada cujo topo vai de `low` a `high` (pontos (x, y, z) no eixo central do topo)."""
        a, b = Vector(low), Vector(high)
        f = (b - a).normalized()
        r = f.cross(Vector((0.0, 1.0, 0.0))).normalized()
        u = r.cross(f).normalized()
        if u.y < 0:
            r, u = -r, -u
        basis = Matrix((r, u, f)).transposed()
        c = (a + b) / 2 - u * (thick / 2)
        self.box(body, name, (width, thick, (b - a).length), c, basis=basis)
        self.meta[(body, name)] = meta

    def cyl(self, body, name, r, h, base):
        rid = self._res("CylinderShape3D", {"radius": "%.3f" % r, "height": "%.3f" % h})
        self.nodes.append((body, name, rid, Matrix.Identity(3), (base[0], base[1] + h / 2, base[2])))

    def heightmap(self, body, name, fn, x0, x1, z0, z1):
        w = int(round(x1 - x0)) + 1
        d = int(round(z1 - z0)) + 1
        data = []
        for j in range(d):
            for i in range(w):
                data.append(round(fn(x0 + i, z0 + j), 3))
        rid = self._res("HeightMapShape3D", {"map_width": str(w), "map_depth": str(d),
                                             "map_data": "PackedFloat32Array(%s)" % ", ".join("%g" % v for v in data)})
        self.nodes.append((body, name, rid, Matrix.Identity(3), ((x0 + x1) / 2, 0.0, (z0 + z1) / 2)))


def _xf(basis, origin):
    r = basis
    return "Transform3D(%s)" % ", ".join("%.5g" % v for v in (r[0][0], r[0][1], r[0][2], r[1][0], r[1][1], r[1][2], r[2][0],
                                                             r[2][1], r[2][2], origin[0], origin[1], origin[2]))


# ------------------------------------------------------------------ altura do chao (para limites e marcadores)
def make_ground(terr):
    def ground(x, z):
        best = -9.0
        for fn, x0, x1, z0, z1 in TERRAIN_FULL:
            if x0 <= x <= x1 and z0 <= z <= z1:
                best = max(best, terr[fn](x, z))
        for _, x0, x1, z0, z1, top in PAVING:
            if x0 <= x <= x1 and z0 <= z <= z1:
                best = max(best, top)
        return best
    return ground


def water_contours(ground):
    """Segmentos (marching squares) do nivel WATER_LEVEL na grade de GRID m dentro do mapa, encadeados e simplificados."""
    x0, x1, z0, z1 = BOUNDS
    nx = int((x1 - x0) / GRID)
    nz = int((z1 - z0) / GRID)
    v = [[ground(x0 + i * GRID, z0 + j * GRID) - WATER_LEVEL for i in range(nx + 1)] for j in range(nz + 1)]

    def lerp(pa, pb, va, vb):
        t = va / (va - vb)
        return (pa[0] + (pb[0] - pa[0]) * t, pa[1] + (pb[1] - pa[1]) * t)

    segs = []
    for j in range(nz):
        for i in range(nx):
            c = [(x0 + i * GRID, z0 + j * GRID), (x0 + (i + 1) * GRID, z0 + j * GRID), (x0 + (i + 1) * GRID, z0 + (j + 1) * GRID),
                 (x0 + i * GRID, z0 + (j + 1) * GRID)]
            vv = [v[j][i], v[j][i + 1], v[j + 1][i + 1], v[j + 1][i]]
            pts = []
            for k in range(4):
                a, b = k, (k + 1) % 4
                if (vv[a] >= 0) != (vv[b] >= 0):
                    pts.append(lerp(c[a], c[b], vv[a], vv[b]))
            if len(pts) == 2:
                segs.append((pts[0], pts[1]))
            elif len(pts) == 4:
                segs.append((pts[0], pts[1]))
                segs.append((pts[2], pts[3]))
    # encadeia
    key = lambda p: (round(p[0], 4), round(p[1], 4))  # noqa: E731
    adj = {}
    for a, b in segs:
        adj.setdefault(key(a), []).append(key(b))
        adj.setdefault(key(b), []).append(key(a))
    seen = set()
    chains = []
    for start in list(adj.keys()):
        if start in seen:
            continue
        # comeca de uma ponta se houver
        cur = start
        chain = [cur]
        seen.add(cur)
        while True:
            nxt = [p for p in adj[cur] if p not in seen]
            if not nxt:
                break
            cur = nxt[0]
            seen.add(cur)
            chain.append(cur)
        chains.append(chain)
    return [_rdp(c, 0.12) for c in chains if len(c) >= 2]


def _rdp(pts, eps):
    if len(pts) < 3:
        return pts
    a, b = Vector((pts[0][0], pts[0][1])), Vector((pts[-1][0], pts[-1][1]))
    ab = b - a
    L = ab.length
    best, bi = 0.0, 0
    for i in range(1, len(pts) - 1):
        p = Vector((pts[i][0], pts[i][1]))
        d = (p - a).length if L < 1e-6 else abs(ab.x * (a.y - p.y) - ab.y * (a.x - p.x)) / L
        if d > best:
            best, bi = d, i
    if best > eps:
        return _rdp(pts[:bi + 1], eps)[:-1] + _rdp(pts[bi:], eps)
    return [pts[0], pts[-1]]


# ------------------------------------------------------------------ marcadores das missoes (proposta v3, secao 5)
def markers(ground, props, bank_info):
    """(nome, missao, (x, y, z), agua?) — y = superficie onde se pisa (agua: y = -0,4)."""
    g = ground
    out = []

    def add(name, mis, x, z, y=None, water=False):
        out.append((name, mis, (round(x, 3), round(-0.4 if water else (g(x, z) if y is None else y), 3), round(z, 3)), water))

    add("M0_RastroStart", "M0", -3.0, 1.5)
    add("M0_BoatDocked", "M0", 0.0, -5.0, water=True)
    add("M0_BoatArrival", "M0", 34.0, -5.0, water=True)
    add("M1_BenchClue", "M1", 0.0, -2.4)
    add("M1_EmptyMooring", "M1", -7.3, -2.7)
    add("M1_BootPrint", "M1", -6.0, 10.0)
    for i, (x, z) in enumerate(((1.0, 3.9), (2.9, 5.9), (5.2, 7.4), (7.6, 8.3))):
        add("M1_PawTrail_%d" % (i + 1), "M1", x, z)
    # M2: degraus e topo do anexo do galpao da margem, galho, varal, juncos
    for k, (sx0, sx1, sz0, sz1, h) in enumerate(W3.STEPS_M2):
        cx, cz = W3.shed_local((sx0 + sx1) / 2, (sz0 + sz1) / 2)
        add("M2_ShedStep_%d" % (len(W3.STEPS_M2) - k), "M2", cx, cz, y=g(cx, cz) - 0.04 + h)
    ax0, ax1, az0, az1, top = W3.ANNEX
    cx, cz = W3.shed_local((ax0 + ax1) / 2, (az0 + az1) / 2)
    add("M2_ShedTop", "M2", cx, cz, y=g(cx, cz) - 0.05 + top)
    bp = bank_info["branch"][4]
    add("M2_TreeBranch", "M2", bp[0], bp[2], y=bp[1] + 0.12)
    add("M2_Clothesline", "M2", 12.5, 7.85)
    add("M2_ReedsPiece", "M2", 12.4, 3.6)
    # M3: chafariz
    fx, fz = W3.FOUNTAIN
    ang = math.radians(W3.FOUNTAIN_STEP_ANG)
    for k, (r, y) in enumerate(((1.5, 0.5), (0.95, 1.0), (0.67, 1.5))):
        add("M3_FountainStep_%d" % (k + 1), "M3", fx + math.cos(ang) * r, fz + math.sin(ang) * r, y=y)
    add("M3_UpperBasin", "M3", fx + math.cos(ang) * 0.4, fz + math.sin(ang) * 0.4, y=1.5)
    (ax, az), (bx, bz) = W3.CHANNEL
    add("M3_ChannelStart", "M3", ax, az)
    add("M3_Grate", "M3", W3.GRATE[0], W3.GRATE[1])
    add("M3_BallStop", "M3", -24.6, -0.4)
    # M4: carrinho e frente de cada barraca (lado do cliente, +z local)
    add("M4_Cart", "M4", -19.5, 1.2)   # ao lado do carrinho (-18,6; 0,8), onde a Leme pega
    for kind, x, z, ry, fruit in W3.STALLS:
        a = math.radians(ry)
        add("M4_Stall_%s" % fruit.capitalize(), "M4", x + math.sin(a) * 1.4, z + math.cos(a) * 1.4)
    # M5: trilha de penas/escamas na rua, cata-vento, subida do Pico ao telhado do galpao de redes
    for i, (x, z) in enumerate(((-6.0, -15.0), (-9.5, -15.3), (-12.6, -15.0), (-14.0, -13.9))):
        add("M5_FeatherTrail_%d" % (i + 1), "M5", x, z)
    add("M5_Weathervane", "M5", -4.6, -15.6)
    (c1x, c1z, _), (c2x, c2z, _) = W3.PICO_CRATES[0], W3.PICO_CRATES[1]
    add("M5_Crates", "M5", (c1x + c2x) / 2, (c1z + c2z) / 2, y=0.6)
    add("M5_Awning", "M5", -16.6, -16.1, y=1.6)
    add("M5_ShedRoof", "M5", -19.6, -18.6, y=2.92)
    # M6: barco na bacia
    add("M6_BoatStart", "M6", 0.0, -5.0, water=True)
    for name, x, z, c in W3.BUOYS:
        add("M6_Buoy%s" % name[-1].upper(), "M6", x, z, water=True)
    add("M6_Dinghy", "M6", W3.DINGHY[0], W3.DINGHY[1], water=True)
    add("M6_DinghyApproach", "M6", 22.5, -8.5, water=True)
    # M7: farol
    lx, lz = W3.LENS
    add("M7_Lens", "M7", lx, lz)
    sx, _, sz = W3.polar(W3.STAIR_STEP_ANG, 3.35, 0)
    add("M7_StairStep", "M7", sx, sz, y=2.7)
    bx, _, bz = W3.polar(W3.STAIR_STEP_ANG, 2.45, 0)
    add("M7_StairBase", "M7", bx, bz, y=3.0)
    for i, (ang_, fy) in enumerate(W3.LANDINGS):
        px, _, pz = W3.polar(ang_, W3.lh_radius(fy) + 0.42, fy)
        add("M7_Landing_%d" % (i + 1), "M7", px, pz, y=fy)
    gx, _, gz = W3.polar(0.0, W3.lh_radius(W3.GALLERY_Y) + 0.4, 0)
    add("M7_Gallery", "M7", gx, gz, y=W3.GALLERY_Y)
    out.append(("M7_LanternPivot", "M7", (W3.LH[0], W3.LANTERN_Y, W3.LH[2]), False))
    for i, (x, z, ry, hull, icon) in enumerate(W3.FESTA_BOATS):
        add("M7_FestaBoat_%d_%s" % (i + 1, icon), "M7", x, z, water=True)
    # M8
    add("M8_FestaPlaza", "M8", -19.5, 3.4)
    add("M8_CaptainDock", "M8", -1.5, 0.5)
    # RB-R1 arte das cenas: Dona Amora atras da barraca azul; marcadores de camera dos planos amplos (sem chao embaixo:
    # metadata camera = true; look_at = marcador olhado). Escritos a mao tambem no .tscn (ver EXTRA abaixo).
    return out


EXTRA_MARKERS = [  # (nome, missao, posicao, girar Y em graus, metadados extras)
    ("M4_Vendor", "M4", (-18.1, 0.0, -6.4), 90.0, {"note": "Dona Amora atras da barraca azul (uvas), virada para o cliente (-X)"}),
    ("Cut_VillageWide", "cut", (38.0, 20.0, 8.0), 0.0, {"camera": True, "look_at": "M8_FestaPlaza"}),
    ("Cut_LighthouseView", "cut", (18.0, 2.5, -2.0), 0.0, {"camera": True, "look_at": "M7_LanternPivot"}),
]


# ------------------------------------------------------------------ montagem
def build(inst, houses, terr, bank_info):
    S = Shapes()
    ground = make_ground(terr)
    # --- chao
    for name, x0, x1, z0, z1, top in PAVING:
        S.box("Ground", name, (x1 - x0, 1.0, z1 - z0), ((x0 + x1) / 2, top - 0.5, (z0 + z1) / 2))
    for name, fn, x0, x1, z0, z1 in TERRAIN:
        S.heightmap("Ground", "Terrain_" + name, terr[fn], x0, x1, z0, z1)
    # rampa sobre a escadaria do terraco (degraus de 0,2 m: a rampa evita travar no degrau) e muretas laterais
    run = 4.32
    ang = math.atan2(1.2, run)
    L = math.hypot(1.2, run)
    basis = Matrix.Rotation(ang, 3, "X")    # sobe para -z
    S.box("Ground", "StairsRamp", (3.2, 0.3, L), (24.0, 0.6 - 0.15 * math.cos(ang), -18.6 - run / 2), basis=basis)
    for s in (22.3, 25.7):
        S.box("Structures", "StairsWall_%g" % s, (0.3, 1.8, 5.0), (s, 0.9, -21.0))
    # --- casas
    for k, (pos, ry, W, D, H) in enumerate(houses):
        b = rot_y(ry)
        c = Vector(pos) + b @ Vector((W / 2, (H + 1.4) / 2, -D / 2))
        S.box("Structures", "House_%02d" % k, (W, H + 1.4, D), c, basis=b)
    # galpao de redes (M5): corpo, mureta da laje, toldo a 1,6, mesa de peixe, muro do quintal e portao
    S.box("Structures", "NetShed", (4.1, 2.92, 8.0), (-19.65, 1.46, -18.8))
    S.box("Structures", "NetShedParapet", (4.34, 0.34, 0.3), (-19.65, 3.09, -22.65))
    S.box("Structures", "NetShedAwning", (2.0, 0.1, 2.7), (-16.65, 1.55, -16.1))
    S.box("Structures", "NetShedFishTable", (1.3, 0.85, 2.0), (-16.55, 0.425, -16.1))
    for xx in (-17.45, -15.65):
        S.box("Structures", "YardPost_%g" % xx, (0.3, 2.2, 0.3), (xx, 1.1, -17.65))
    S.box("Structures", "YardGate", (1.5, 1.8, 0.12), (-16.55, 0.9, -17.7))
    # praca: chafariz em degraus, banco redondo da arvore, canteiros
    fx, fz = W3.FOUNTAIN
    S.cyl("Structures", "FountainStep", 2.08, 0.26, (fx, 0.0, fz))
    S.cyl("Structures", "FountainBasin", 1.6, 0.5, (fx, 0.0, fz))
    S.cyl("Structures", "FountainDrum", 1.15, 1.0, (fx, 0.0, fz))
    S.cyl("Structures", "FountainUpperBasin", 0.76, 1.5, (fx, 0.0, fz))
    S.cyl("Structures", "FountainSpout", 0.19, 0.75, (fx, 1.36, fz))
    S.cyl("Structures", "TreeBench", 1.6, 0.48, (-24.0, 0.0, -4.0))
    S.box("Structures", "FlowerBedN", (2.4, 0.32, 0.9), (-21.0, 0.16, -11.6))
    S.box("Structures", "FlowerBedS", (0.9, 0.32, 2.4), (-27.2, 0.16, 9.2))
    # cais: estacas altas (norte) e de canto (sul)
    for x in (-7.6, -3.9, 3.9, 7.6):
        S.cyl("Structures", "DockPost_%g" % x, 0.18, 1.45, (x, -0.5, -3.12))
    for x in (-7.85, 7.85):
        S.cyl("Structures", "DockCornerPost_%g" % x, 0.16, 1.4, (x, -0.5, 3.0))
    # farol: embasamento, torre, patamares, galeria, degrau de chegada
    bx, by, bz = W3.LH
    S.cyl("Structures", "LighthousePlinth", 3.0, 1.0, (bx, 2.0, bz))
    S.cyl("Structures", "LighthouseTowerLow", 2.05, 6.5, (bx, 3.0, bz))
    S.cyl("Structures", "LighthouseTowerHigh", 1.8, 6.75, (bx, 9.5, bz))
    S.cyl("Structures", "LighthouseTop", 2.1, 2.0, (bx, W3.LH_TOP, bz))
    for i, (ang_, fy) in enumerate(W3.LANDINGS):
        rt = W3.lh_radius(fy)
        cx, _, cz = W3.polar(ang_, rt + 0.42, fy)
        S.box("Structures", "LighthouseLanding_%d" % (i + 1), (1.15, 0.12, 0.84), (cx, fy - 0.06, cz), ry=90.0 - ang_)
        ox, _, oz = W3.polar(ang_, rt + 0.82, fy)
        S.box("Structures", "LighthouseLandingRail_%d" % (i + 1), (1.1, 0.9, 0.06), (ox, fy + 0.45, oz), ry=90.0 - ang_)
    rt = W3.lh_radius(W3.GALLERY_Y)
    ro = rt + W3.GALLERY_W
    S.cyl("Structures", "LighthouseGallery", ro, 0.16, (bx, W3.GALLERY_Y - 0.16, bz))
    for k in range(16):
        a_ = k / 16 * 360.0
        px, _, pz = W3.polar(a_, ro - 0.04, 0)
        S.box("Structures", "LighthouseGalleryRail_%02d" % k, (2 * math.pi * ro / 16 + 0.05, 0.95, 0.06), (px, W3.GALLERY_Y + 0.47, pz),
              ry=90.0 - a_)
    sx, _, sz = W3.polar(W3.STAIR_STEP_ANG, 3.35, 0)
    S.box("Structures", "LighthouseStep", (0.9, 0.5, 0.7), (sx, 2.45, sz), ry=90.0 - W3.STAIR_STEP_ANG)
    # margem (M2): anexo do galpao, degraus de caixote, galho baixo, cerca
    x0, z0, sry = W3.SHED_M2
    ax0, ax1, az0, az1, top = W3.ANNEX
    cx, cz = W3.shed_local((ax0 + ax1) / 2, (az0 + az1) / 2)
    gy = ground(cx, cz) - 0.05
    S.box("Structures", "BankShedAnnex", (ax1 - ax0 + 0.1, top + 0.3, az1 - az0 + 0.16), (cx, gy + (top - 0.3) / 2, cz), ry=sry)
    for k, (sx0, sx1, sz0, sz1, h) in enumerate(W3.STEPS_M2):
        c2x, c2z = W3.shed_local((sx0 + sx1) / 2, (sz0 + sz1) / 2)
        g2 = ground(c2x, c2z) - 0.04
        S.box("Structures", "BankShedStep_%d" % (len(W3.STEPS_M2) - k), (sx1 - sx0, h + 0.2, sz1 - sz0),
              (c2x, g2 + (h - 0.2) / 2, c2z), ry=sry)
    br = bank_info["branch"]
    p0, p1 = Vector(br[1]), Vector(br[-1])
    d = p1 - p0
    yaw = math.degrees(math.atan2(d.x, d.z))
    pitch = -math.degrees(math.atan2(d.y, math.hypot(d.x, d.z)))
    bas = rot_y(yaw) @ Matrix.Rotation(math.radians(pitch), 3, "X")
    mid = (p0 + p1) / 2
    S.box("Structures", "TreeBranch", (0.34, 0.22, d.length), (mid.x, mid.y + 0.02, mid.z), basis=bas)
    fence = [(-4.0, 9.8), (-6.0, 11.8), (-9.5, 11.5), (-12.0, 10.6)]
    for k, ((fx0, fz0), (fx1, fz1)) in enumerate(zip(fence[:-1], fence[1:])):
        L = math.hypot(fx1 - fx0, fz1 - fz0)
        mx, mz = (fx0 + fx1) / 2, (fz0 + fz1) / 2
        S.box("Structures", "Fence_%d" % k, (L, 1.0, 0.12), (mx, ground(mx, mz) + 0.5, mz),
              ry=math.degrees(math.atan2(-(fz1 - fz0), fx1 - fx0)))
    # --- aderecos do kit
    n_props = 0
    for kind, rows in sorted(inst.items()):
        for i, r in enumerate(rows):
            for j, sh in enumerate(KIT_SHAPES.get(kind, [])):
                x, y, z, ry, s = r
                b = rot_y(ry)
                if sh[0] == "box":
                    size = tuple(v * s for v in sh[1])
                    c = Vector((x, y, z)) + b @ (Vector(sh[2]) * s)
                    S.box("Props", "%s_%d_%d" % (kind, i, j), size, c, basis=b)
                else:
                    S.cyl("Props", "%s_%d_%d" % (kind, i, j), sh[1] * s, sh[2] * s, (x, y + sh[3], z))
                n_props += 1
    # --- rampas de acesso (E3b): so para heroi sem step-up; camada propria, desligadas por padrao
    def polar_pt(ang, rr, y):
        px, _, pz = W3.polar(ang, rr, 0)
        return (px, y, pz)
    lo = W3.polar(W3.STAIR_STEP_ANG, 5.0, 0)
    S.ramp("AccessRamps", "Ramp_LighthouseStep", (lo[0], terr["head_h"](lo[0], lo[2]) - 0.02, lo[2]),
           polar_pt(W3.STAIR_STEP_ANG, 3.05, 3.0), 1.2,
           {"mission": "M7", "covers": "degrau 0,37 m (terreno -> LighthouseStep 2,70) + 0,30 m (-> embasamento 3,00)",
            "to_marker": "M7_StairBase"})
    fx, fz = W3.FOUNTAIN
    fa = math.radians(W3.FOUNTAIN_STEP_ANG)
    S.ramp("AccessRamps", "Ramp_FountainEast", (fx + math.cos(fa) * 3.3, -0.005, fz + math.sin(fa) * 3.3),
           (fx + math.cos(fa) * 1.45, 0.52, fz + math.sin(fa) * 1.45), 1.0,
           {"mission": "M3", "covers": "degraus 0,26 m (FountainStep) + 0,24 m (borda da bacia 0,50)",
            "to_marker": "M3_FountainStep_1"})
    # borda sul do cais (margem -0,12 -> cais 0,00): a capsula sobe sem rampa (medido no teste), entao sem rampa aqui
    # --- beira d'agua
    chains = water_contours(ground)
    n_w = 0
    for chain in chains:
        for (ax, az), (bx_, bz_) in zip(chain[:-1], chain[1:]):
            L = math.hypot(bx_ - ax, bz_ - az)
            if L < 0.05:
                continue
            S.box("WaterLimits", "Edge_%03d" % n_w, (L + 0.25, 4.0, 0.3), ((ax + bx_) / 2, 1.0, (az + bz_) / 2),
                  ry=math.degrees(math.atan2(-(bz_ - az), bx_ - ax)))
            n_w += 1
    # --- limites do mapa
    X0, X1, Z0, Z1 = BOUNDS
    S.box("MapBounds", "West", (0.5, 30.0, Z1 - Z0 + 1), (X0 - 0.25, 10.0, (Z0 + Z1) / 2))
    S.box("MapBounds", "East", (0.5, 30.0, Z1 - Z0 + 1), (X1 + 0.25, 10.0, (Z0 + Z1) / 2))
    S.box("MapBounds", "North", (X1 - X0 + 1, 30.0, 0.5), ((X0 + X1) / 2, 10.0, Z0 - 0.25))
    S.box("MapBounds", "South", (X1 - X0 + 1, 30.0, 0.5), ((X0 + X1) / 2, 10.0, Z1 + 0.25))
    return S, ground, n_props, n_w, len(chains)


def write_scenes(repo, inst, houses, lights, props_info, bank_info, terr):
    S, ground, n_props, n_w, n_chains = build(inst, houses, terr, bank_info)
    out_dir = os.path.join(repo, "game", "worlds", "village_v3")
    os.makedirs(out_dir, exist_ok=True)
    bodies = ["Ground", "Structures", "Props", "WaterLimits", "MapBounds", "AccessRamps"]
    lines = ["[gd_scene format=3]", ""]
    for rid, kind, props in S.res:
        lines.append('[sub_resource type="%s" id="%s"]' % (kind, rid))
        for k, v in props.items():
            lines.append("%s = %s" % (k, v))
        lines.append("")
    lines += ['[node name="VillageCollision" type="Node3D"]', "metadata/provisional = true",
              'metadata/generated_by = "source_art/environment_v2/wv3_collision.py"', ""]
    for b in bodies:
        lines += ['[node name="%s" type="StaticBody3D" parent="."]' % b]
        if b == "AccessRamps":
            lines += ["collision_layer = %d" % ACCESS_RAMPS_LAYER, "metadata/access_ramps = true"]
        lines += ["collision_mask = 0", ""]
    used = set()
    for body, name, rid, basis, origin in S.nodes:
        nm = name
        k = 2
        while (body, nm) in used:
            nm = "%s_%d" % (name, k)
            k += 1
        used.add((body, nm))
        lines += ['[node name="%s" type="CollisionShape3D" parent="%s"]' % (nm, body), "transform = " + _xf(basis, origin),
                  'shape = SubResource("%s")' % rid]
        for k, v in S.meta.get((body, name), {}).items():
            lines.append('metadata/%s = "%s"' % (k, v))
        lines.append("")
    with open(os.path.join(out_dir, "village_collision.tscn"), "w") as f:
        f.write("\n".join(lines))
    mk = markers(ground, props_info["pos"], bank_info)
    lines = ["[gd_scene format=3]", "",
             '[ext_resource type="Script" path="res://worlds/village_v3/village_world.gd" id="1_world"]',
             '[ext_resource type="PackedScene" path="res://worlds/village_v3/village_collision.tscn" id="2_col"]', "",
             '[node name="VillageWorld" type="Node3D"]', 'script = ExtResource("1_world")', "metadata/provisional = true",
             'metadata/generated_by = "source_art/environment_v2/wv3_collision.py"', "",
             '[node name="Collision" parent="." instance=ExtResource("2_col")]', "",
             '[node name="Markers" type="Node3D" parent="."]', ""]
    for name, mis, p, water in mk:
        lines += ['[node name="%s" type="Marker3D" parent="Markers"]' % name,
                  "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %g, %g, %g)" % p, 'metadata/mission = "%s"' % mis]
        if water:
            lines.append("metadata/water = true")
        lines.append("")
    for name, mis, p, ry, meta in EXTRA_MARKERS:
        c, s_ = math.cos(math.radians(ry)), math.sin(math.radians(ry))
        lines += ['[node name="%s" type="Marker3D" parent="Markers"]' % name,
                  "transform = Transform3D(%g, 0, %g, 0, 1, 0, %g, 0, %g, %g, %g, %g)" % ((c, s_, -s_, c) + p), 'metadata/mission = "%s"' % mis]
        for k, v in meta.items():
            lines.append("metadata/%s = %s" % (k, "true" if v is True else '"%s"' % v))
        lines.append("")
    with open(os.path.join(out_dir, "village_world.tscn"), "w") as f:
        f.write("\n".join(lines))
    counts = {}
    for body, *_ in S.nodes:
        counts[body] = counts.get(body, 0) + 1
    return {"formas_por_corpo": counts, "aderecos_com_colisao": n_props, "paredes_beira_agua": n_w, "contornos_agua": n_chains,
            "marcadores": len(mk), "limites_mapa": list(BOUNDS)}
