"""Rota Brava · Mundo v2 (RB-R1 W1) · texturas procedurais ladrilhaveis. PROVISORIO ate aprovacao de Thiago.

Tudo gerado aqui do zero com numpy (ruido de valor, celulas de Voronoi e formas analiticas); nenhuma foto,
textura, scan ou biblioteca de terceiros. Cada textura sai em dois arquivos:
  <nome>_albedo.jpg  cor (sRGB)
  <nome>_data.png    R,G = normal em espaco tangente (OpenGL, +Y = v crescente), B = mascara de tingimento
                     (1 = a cor de vertice tinge; 0 = cor propria da textura), A = rugosidade
Convencao de linhas: linha 0 do array = v = 0 (base da imagem), igual ao buffer de pixels do Blender.
Uso: importado por build_world_v2.py (roda dentro do Blender 4.5, numpy embutido).
"""
import math
import os
import struct
import zlib

import numpy as np

# E3 (peso, D18): dados destas texturas saem com METADE da resolucao da cor (relevo largo/difuso; a cor segue cheia).
# Cais e calcamento (chao em primeiro plano da camera baixa) mantem os dados na resolucao cheia.
DATA_HALF = {"plaster", "stone", "grass", "dirt", "leaf"}

# Tamanho de cada textura em metros (o shader usa uv_scale = 1 / tamanho) e resolucao.
SPECS = {
    "deck": (2.0, 1024),
    "wood": (1.0, 512),
    "paint": (1.0, 512),
    "slats": (0.5, 512),
    "plaster": (2.0, 1024),
    "stone": (2.0, 1024),
    "cobble": (1.5, 1024),
    "roof": (1.0, 512),
    "canvas": (1.0, 512),
    "metal": (0.5, 256),
    "grass": (4.0, 1024),
    "dirt": (3.0, 1024),
    "leaf": (1.0, 1024),
    "bark": (1.0, 512),
    "rope": (0.25, 256),
    "net": (0.5, 256),
    "rock": (2.0, 512),
    "burlap": (0.5, 512),
}


def srgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


# ------------------------------------------------------------------ ruido ladrilhavel
def vnoise(res, cu, cv, rng):
    g = rng.random((cv, cu))
    x = np.arange(res) * cu / res
    y = np.arange(res) * cv / res
    xi = np.floor(x).astype(int)
    yi = np.floor(y).astype(int)
    fx = x - xi
    fy = y - yi
    sx = fx * fx * (3 - 2 * fx)
    sy = fy * fy * (3 - 2 * fy)
    a = g[np.ix_(yi % cv, xi % cu)]
    b = g[np.ix_(yi % cv, (xi + 1) % cu)]
    c = g[np.ix_((yi + 1) % cv, xi % cu)]
    d = g[np.ix_((yi + 1) % cv, (xi + 1) % cu)]
    top = a + (b - a) * sx[None, :]
    bot = c + (d - c) * sx[None, :]
    return top + (bot - top) * sy[:, None]


def fbm(res, cu, cv, rng, octaves=4, gain=0.5):
    s = np.zeros((res, res))
    amp = 1.0
    tot = 0.0
    for o in range(octaves):
        f = 2 ** o
        s += vnoise(res, min(cu * f, res), min(cv * f, res), rng) * amp
        tot += amp
        amp *= gain
    return s / tot


def grid(res):
    c = (np.arange(res) + 0.5) / res
    return np.meshgrid(c, c)  # u (colunas), v (linhas)


def cells(res, pts, sx=1.0, sy=1.0):
    """Voronoi toroidal. pts (n,2) em [0,1). Devolve F1, F2, id (em unidades da textura)."""
    u, v = grid(res)
    f1 = np.full((res, res), 9.0)
    f2 = np.full((res, res), 9.0)
    idx = np.zeros((res, res), dtype=int)
    for i, (px, py) in enumerate(pts):
        dx = np.abs(u - px)
        dx = np.minimum(dx, 1 - dx) * sx
        dy = np.abs(v - py)
        dy = np.minimum(dy, 1 - dy) * sy
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < f1
        f2 = np.where(closer, f1, np.minimum(f2, d))
        idx = np.where(closer, i, idx)
        f1 = np.where(closer, d, f1)
    return f1, f2, idx


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def normal_from_height(h, meters, res, depth_m):
    """h em 0..1; depth_m = profundidade em metros de h=0 a h=1. Normal OpenGL codificada 0..1."""
    px = meters / res
    hz = h * depth_m
    dx = (np.roll(hz, -1, axis=1) - np.roll(hz, 1, axis=1)) / (2 * px)
    dy = (np.roll(hz, -1, axis=0) - np.roll(hz, 1, axis=0)) / (2 * px)
    n = np.stack([-dx, -dy, np.ones_like(dx)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


# ------------------------------------------------------------------ texturas
def tex_deck(res, m, rng):
    u, v = grid(res)
    planks = 10
    pv = v * planks
    pid = np.floor(pv).astype(int)
    pt = pv - pid
    tone = rng.uniform(0.82, 1.12, planks)
    bleach = rng.uniform(0.0, 0.35, planks)
    # emendas de topo: 2 por tabua, posicoes aleatorias
    joints = np.sort(rng.random((planks, 2)), axis=1)
    jd = np.full((res, res), 1.0)
    seg = np.zeros((res, res), dtype=int)
    for j in range(planks):
        rows = pid == j
        for k in range(2):
            d = np.abs(u - joints[j, k])
            d = np.minimum(d, 1 - d)
            jd = np.where(rows, np.minimum(jd, d), jd)
        seg = np.where(rows, ((u > joints[j, 0]) & (u < joints[j, 1])).astype(int) + j * 2, seg)
    segtone = rng.uniform(0.9, 1.08, planks * 2)[seg]
    edge = np.minimum(pt, 1 - pt) / planks  # distancia a borda da tabua (unid. textura)
    gap = smooth(0.0, 0.006, edge) * smooth(0.0, 0.004, jd)
    grain = fbm(res, 6, 160, rng, 4)
    fine = vnoise(res, 64, 512, rng)
    knots = np.zeros((res, res))
    for _ in range(14):
        cx, cy = rng.random(2)
        dx = np.minimum(np.abs(u - cx), 1 - np.abs(u - cx)) * 2.2
        dy = np.minimum(np.abs(v - cy), 1 - np.abs(v - cy)) * 6.0
        knots = np.maximum(knots, 1 - smooth(0.0, 0.035, np.sqrt(dx * dx + dy * dy)))
    # pregos nas pontas das emendas
    nails = np.zeros((res, res))
    for j in range(planks):
        for k in range(2):
            for side in (-1, 1):
                cx = (joints[j, k] + side * 0.012) % 1.0
                for off in (0.3, 0.7):
                    cy = (j + off) / planks
                    dx = np.minimum(np.abs(u - cx), 1 - np.abs(u - cx))
                    dy = np.minimum(np.abs(v - cy), 1 - np.abs(v - cy))
                    nails = np.maximum(nails, 1 - smooth(0.0028, 0.0042, np.sqrt(dx * dx + dy * dy)))
    base = srgb("#C9A57A")
    grey = srgb("#B9AFA2")
    t = tone[pid] * segtone
    col = base[None, None, :] * t[..., None]
    col = col * (1 - bleach[pid][..., None]) + grey[None, None, :] * bleach[pid][..., None] * t[..., None]
    g = (grain - 0.5) * 2
    col *= (1 + 0.16 * g[..., None] - 0.08 * fine[..., None])
    col *= (1 - 0.35 * knots[..., None])
    col *= (0.30 + 0.70 * gap[..., None])
    col = col * (1 - nails[..., None]) + srgb("#4B4743")[None, None, :] * nails[..., None]
    h = 0.55 + 0.45 * gap - 0.35 * (1 - gap) + 0.06 * g + 0.03 * fine - 0.05 * knots
    h += 0.04 * np.sin(np.clip(pt, 0, 1) * math.pi)  # tabua levemente abaulada
    rough = 0.78 + 0.1 * fine - 0.25 * nails
    return col, h, 0.006, np.zeros_like(h), rough


def tex_wood(res, m, rng):
    u, v = grid(res)
    warp = fbm(res, 3, 12, rng, 3)
    rings = np.sin((v * 22 + warp * 3.0) * math.pi * 2) * 0.5 + 0.5
    grain = fbm(res, 4, 96, rng, 4)
    fine = vnoise(res, 48, 384, rng)
    base = srgb("#B08660")
    col = base[None, None, :] * (0.86 + 0.18 * grain[..., None] + 0.06 * fine[..., None])
    col *= (1 - 0.16 * smooth(0.55, 1.0, rings)[..., None])
    h = 0.5 + 0.25 * grain + 0.15 * fine - 0.2 * smooth(0.6, 1.0, rings)
    return col, h, 0.002, np.full_like(h, 0.6), 0.8 + 0.08 * fine


def tex_paint(res, m, rng):
    """Tabuas verticais pintadas (portas, venezianas, placas, barracas). Lascas mostram a madeira."""
    u, v = grid(res)
    boards = 8
    bu = u * boards
    bt = bu - np.floor(bu)
    edge = np.minimum(bt, 1 - bt) / boards
    groove = smooth(0.0, 0.006, edge)
    grain = fbm(res, 40, 3, rng, 3)
    chips_n = fbm(res, 14, 14, rng, 5)
    chips = smooth(0.76, 0.785, chips_n) * smooth(0.45, 0.7, fbm(res, 3, 3, rng, 2))
    paint = np.ones(3) * 0.93
    wood = srgb("#9C7552")
    col = paint[None, None, :] * (0.94 + 0.08 * grain[..., None])
    col = col * (1 - chips[..., None]) + wood[None, None, :] * chips[..., None] * (0.8 + 0.3 * grain[..., None])
    col *= (0.45 + 0.55 * groove[..., None])
    h = 0.6 + 0.3 * groove - 0.25 * (1 - groove) + 0.04 * grain - 0.12 * chips
    mask = 1 - chips
    return col, h, 0.003, mask, 0.55 + 0.3 * chips


def tex_slats(res, m, rng):
    u, v = grid(res)
    n = 9
    sv = v * n
    st = sv - np.floor(sv)
    shade = 0.62 + 0.45 * st  # cada ripa inclinada: escura embaixo, clara em cima
    edge = smooth(0.0, 0.08, st) * smooth(0.0, 0.03, 1 - st)
    grain = fbm(res, 3, 30, rng, 3)
    chips = smooth(0.77, 0.795, fbm(res, 12, 12, rng, 5)) * smooth(0.45, 0.7, fbm(res, 3, 3, rng, 2))
    col = np.ones(3)[None, None, :] * 0.92 * (shade * (0.35 + 0.65 * edge))[..., None]
    col *= (0.95 + 0.07 * grain[..., None])
    col = col * (1 - chips[..., None]) + srgb("#9C7552")[None, None, :] * chips[..., None] * 0.8
    h = st * 0.8 * edge
    return col, h, 0.004, 1 - chips, 0.6 + 0.2 * chips


def tex_plaster(res, m, rng):
    u, v = grid(res)
    mott = fbm(res, 6, 6, rng, 5)
    trowel = fbm(res, 3, 14, rng, 3)
    fine = vnoise(res, 256, 256, rng)
    pits = smooth(0.80, 0.86, vnoise(res, 180, 180, rng))
    pts = rng.random((26, 2))
    f1, f2, _ = cells(res, pts)
    crack_mask = smooth(0.62, 0.72, fbm(res, 4, 4, rng, 3))
    cracks = (1 - smooth(0.0, 0.0025, f2 - f1)) * crack_mask
    col = np.ones(3)[None, None, :] * (0.90 + 0.09 * mott[..., None] + 0.03 * trowel[..., None] + 0.02 * fine[..., None])
    col *= (1 - 0.06 * pits[..., None] - 0.25 * cracks[..., None])
    h = 0.5 + 0.25 * mott + 0.25 * trowel + 0.12 * fine - 0.3 * pits - 0.4 * cracks
    return col, h, 0.0025, np.ones_like(h), 0.86 + 0.06 * fine


def tex_stone(res, m, rng):
    u, v = grid(res)
    heights = np.array([0.30, 0.26, 0.36, 0.28, 0.34, 0.24, 0.22])
    heights = heights / heights.sum()
    y_edges = np.concatenate([[0], np.cumsum(heights)])
    pal = [srgb("#B4AEBF"), srgb("#C7B89F"), srgb("#A39FAB"), srgb("#BDB2A6"), srgb("#9C98A3")]
    col = np.zeros((res, res, 3))
    h = np.zeros((res, res))
    surf = fbm(res, 16, 16, rng, 5)
    fine = vnoise(res, 200, 200, rng)
    for r in range(len(heights)):
        y0, y1 = y_edges[r], y_edges[r + 1]
        rows = (v >= y0) & (v < y1)
        n = rng.integers(3, 5)
        lens = rng.uniform(0.7, 1.3, n)
        edges = np.sort((np.cumsum(lens / lens.sum()) + rng.random()) % 1.0)
        uu = u[rows]
        k = np.searchsorted(edges, uu, side="right") - 1
        left = (uu - edges[k % n]) % 1.0
        right = (edges[(k + 1) % n] - uu) % 1.0
        vv = v[rows]
        dy = np.minimum(vv - y0, y1 - vv)
        d = np.minimum(np.minimum(left, right) * 1.0, dy)
        bev = smooth(0.004, 0.022, d)
        bid = (k % n) + r * 7
        tones = np.array([rng.uniform(0.85, 1.1) for _ in range(len(heights) * 7 + 8)])
        pidx = np.array([rng.integers(0, len(pal)) for _ in range(len(heights) * 7 + 8)])
        palarr = np.array(pal)
        c = palarr[pidx[bid]] * tones[bid][:, None]
        col[rows] = c
        h[rows] = bev
    mortar = srgb("#8B8378")
    m_amt = 1 - smooth(0.0, 0.5, h)
    col = col * (0.88 + 0.2 * surf[..., None] + 0.05 * fine[..., None])
    col = col * (1 - m_amt[..., None]) + mortar[None, None, :] * m_amt[..., None] * (0.7 + 0.3 * surf[..., None])
    col *= (0.55 + 0.45 * smooth(0.0, 0.6, h))[..., None]
    hh = h * (0.75 + 0.25 * surf) + 0.04 * fine
    return col, hh, 0.025, np.zeros_like(h), 0.85 + 0.08 * fine


def tex_cobble(res, m, rng):
    u, v = grid(res)
    pts = []
    nx, ny = 11, 12
    for j in range(ny):
        for i in range(nx):
            pts.append(((i + 0.5 * (j % 2) + rng.uniform(-0.28, 0.28)) / nx % 1.0, (j + rng.uniform(-0.25, 0.25)) / ny % 1.0))
    pts = np.array(pts)
    f1, f2, idx = cells(res, pts)
    edge = (f2 - f1) * 0.5
    dome = smooth(0.003, 0.022, edge)
    tones = rng.uniform(0.9, 1.07, len(pts))
    pal = np.array([srgb("#B8B0A6"), srgb("#AFAAB2"), srgb("#BEB29E"), srgb("#AAA6AA"), srgb("#B5A893")])
    pc = pal[rng.integers(0, len(pal), len(pts))]
    surf = fbm(res, 20, 20, rng, 4)
    fine = vnoise(res, 220, 220, rng)
    col = pc[idx] * tones[idx][:, :, None] * (0.85 + 0.25 * surf[..., None])
    gapc = srgb("#A49A86")
    moss = srgb("#6F8F45")
    mossy = smooth(0.55, 0.75, fbm(res, 5, 5, rng, 3))
    gcol = gapc * (1 - mossy[..., None] * 0.4) + moss * mossy[..., None] * 0.4
    g = 1 - dome
    col = col * (1 - g[..., None]) + gcol * g[..., None] * (0.8 + 0.3 * fine[..., None])
    col *= (0.82 + 0.18 * dome)[..., None]
    h = dome * (0.85 + 0.15 * surf) * (1 - 0.6 * f1 * ny) + 0.03 * fine
    h = np.clip(h, 0, 1)
    return col, h, 0.03, np.zeros_like(h), 0.8 + 0.1 * fine - 0.1 * dome


def tex_roof(res, m, rng):
    u, v = grid(res)
    cols_n, rows_n = 5, 4
    rv = v * rows_n
    row = np.floor(rv).astype(int)
    t = rv - row  # 0 = beira de baixo da fiada (sombra), 1 = topo (sob a fiada de cima)
    cu = u * cols_n + 0.5 * (row % 2)
    col_i = np.floor(cu).astype(int) % cols_n
    ct = cu - np.floor(cu)
    profile = np.sin(ct * math.pi) ** 0.8
    tile_id = row * cols_n + col_i
    tones = rng.uniform(0.80, 1.10, rows_n * cols_n)
    lich = smooth(0.66, 0.8, fbm(res, 6, 6, rng, 4))
    surf = fbm(res, 12, 12, rng, 4)
    fine = vnoise(res, 128, 128, rng)
    lip = smooth(0.0, 0.10, t)  # beira escura onde a telha de cima sobrepoe
    # telha capa (meia cana): luz no dorso, sombra nos canais entre colunas
    shade = (0.40 + 0.60 * lip) * (0.42 + 0.58 * profile) * (0.9 + 0.1 * t)
    col = np.ones(3)[None, None, :] * (tones[tile_id] * (0.88 + 0.16 * surf) * shade)[..., None]
    col = col * (1 - 0.35 * lich[..., None]) + srgb("#C9C38E")[None, None, :] * 0.35 * lich[..., None] * shade[..., None]
    h = profile * 0.6 + t * 0.4 * lip + 0.04 * fine
    mask = 1 - 0.6 * lich
    return col, h, 0.035, mask, 0.62 + 0.15 * fine + 0.15 * lich


def tex_canvas(res, m, rng):
    u, v = grid(res)
    stripes = 4  # 4 faixas coloridas por metro (largura 12,5 cm)
    s = (u * stripes) % 1.0
    mask = smooth(0.0, 0.01, s) * smooth(0.0, 0.01, 0.5 - s) * (s < 0.5)
    threads = 0.5 + 0.25 * np.sin(u * res * math.pi / 2) * np.sin(v * res * math.pi / 2)
    folds = fbm(res, 2, 6, rng, 3)
    dirt = fbm(res, 6, 6, rng, 4)
    base = srgb("#FBF4E4")
    col = base[None, None, :] * (0.93 + 0.05 * threads[..., None] + 0.03 * folds[..., None])
    col *= (1 - 0.05 * smooth(0.6, 0.85, dirt))[..., None]
    h = 0.5 + 0.2 * threads + 0.3 * folds
    return col, h, 0.0015, mask, 0.9 + 0.05 * threads


def tex_metal(res, m, rng):
    u, v = grid(res)
    n = fbm(res, 8, 8, rng, 5)
    rust = smooth(0.7, 0.8, fbm(res, 6, 6, rng, 5))
    col = np.ones(3)[None, None, :] * (0.88 + 0.1 * n[..., None])
    col = col * (1 - rust[..., None]) + srgb("#8A5A3A")[None, None, :] * rust[..., None]
    h = 0.5 + 0.3 * n - 0.2 * rust
    return col, h, 0.0006, 1 - rust, 0.42 + 0.2 * n + 0.3 * rust


def tex_grass(res, m, rng):
    u, v = grid(res)
    big = fbm(res, 3, 3, rng, 3)
    mid = fbm(res, 12, 12, rng, 4)
    blades = vnoise(res, 512, 160, rng) * 0.5 + vnoise(res, 160, 512, rng) * 0.5
    c1, c2, c3 = srgb("#86C94E"), srgb("#5DAE40"), srgb("#3E8A4C")
    a = smooth(0.35, 0.65, big)
    col = c1[None, None, :] * a[..., None] + c2[None, None, :] * (1 - a[..., None])
    col = col * (1 - 0.35 * smooth(0.5, 0.8, mid)[..., None]) + c3[None, None, :] * 0.35 * smooth(0.5, 0.8, mid)[..., None]
    col *= (0.72 + 0.45 * blades[..., None])
    # trevos claros e florzinhas esparsas
    specks = smooth(0.93, 0.95, vnoise(res, 300, 300, rng)) * smooth(0.6, 0.7, fbm(res, 6, 6, rng, 2))
    flower = np.where(vnoise(res, 40, 40, rng)[..., None] > 0.5, srgb("#FFF6D8")[None, None, :], srgb("#FFD84A")[None, None, :])
    col = col * (1 - specks[..., None]) + flower * specks[..., None]
    h = 0.4 * blades + 0.3 * mid + 0.3 * specks
    return col, h, 0.012, np.zeros_like(h), 0.9 - 0.1 * blades


def tex_dirt(res, m, rng):
    u, v = grid(res)
    big = fbm(res, 4, 4, rng, 4)
    fine = vnoise(res, 300, 300, rng)
    pts = rng.random((160, 2))
    f1, f2, idx = cells(res, pts)
    pebble = 1 - smooth(0.004, 0.009, f1)
    ptone = rng.uniform(0.75, 1.15, len(pts))[idx]
    c = srgb("#B9915F")
    col = c[None, None, :] * (0.82 + 0.3 * big[..., None] + 0.08 * fine[..., None])
    col *= (1 - 0.12 * smooth(0.6, 0.8, fbm(res, 10, 10, rng, 3)))[..., None]
    pc = srgb("#CBC2B4")[None, None, :] * ptone[..., None]
    col = col * (1 - pebble[..., None]) + pc * pebble[..., None]
    h = 0.3 * big + 0.15 * fine + 0.6 * pebble * (1 - f1 / 0.009).clip(0, 1)
    return col, h, 0.012, np.zeros_like(h), 0.92 - 0.2 * pebble


def tex_leaf(res, m, rng):
    u, v = grid(res)
    col = np.zeros((res, res, 3)) + srgb("#244F2E")[None, None, :] * 0.7
    h = np.zeros((res, res))
    greens = [srgb("#7CCB4A"), srgb("#5DB043"), srgb("#4FA83D"), srgb("#3F9244"), srgb("#8BD15A")]
    n = 1500
    for i in range(n):
        cx, cy = rng.random(2)
        ang = rng.uniform(0, math.pi * 2)
        L = rng.uniform(0.035, 0.06)
        W = L * rng.uniform(0.42, 0.55)
        ca, sa = math.cos(ang), math.sin(ang)
        r = int(L * res) + 2
        x0 = int(cx * res)
        y0 = int(cy * res)
        xs = (np.arange(x0 - r, x0 + r)) % res
        ys = (np.arange(y0 - r, y0 + r)) % res
        lx = (np.arange(x0 - r, x0 + r) + 0.5) / res - cx
        ly = (np.arange(y0 - r, y0 + r) + 0.5) / res - cy
        LX, LY = np.meshgrid(lx, ly)
        a = (LX * ca + LY * sa) / L
        b = (-LX * sa + LY * ca) / W
        # folha em gota: mais larga perto da base
        wprof = np.sqrt(np.clip(1 - a * a, 0, 1)) * (1 - 0.35 * a)
        inside = np.abs(b) < wprof
        dome = np.clip(1 - (b / np.maximum(wprof, 1e-3)) ** 2, 0, 1) * np.clip(1 - a * a, 0, 1)
        rib = 1 - smooth(0.0, 0.08, np.abs(b))
        hh = 0.3 + 0.6 * dome - 0.08 * rib + i / n * 0.4
        sub = h[np.ix_(ys, xs)]
        put = inside & (hh > sub)
        g = greens[rng.integers(0, len(greens))] * rng.uniform(0.85, 1.12)
        shade = (0.72 + 0.4 * dome - 0.12 * rib)[..., None] * (0.75 + 0.25 * (a[..., None] + 1) * 0.5)
        ccur = col[np.ix_(ys, xs)]
        ccur[put] = (g[None, None, :] * shade)[put]
        col[np.ix_(ys, xs)] = ccur
        sub[put] = hh[put]
        h[np.ix_(ys, xs)] = sub
    return col, h, 0.012, np.ones_like(h), 0.62 + 0.0 * h


def tex_bark(res, m, rng):
    u, v = grid(res)
    fiss = fbm(res, 14, 1, rng, 3) * 0.75 + fbm(res, 40, 4, rng, 2) * 0.25
    plates = smooth(0.38, 0.5, fiss)
    fine = vnoise(res, 128, 32, rng)
    c = srgb("#7A5636")
    col = c[None, None, :] * (0.55 + 0.55 * plates[..., None]) * (0.9 + 0.15 * fine[..., None])
    moss = smooth(0.6, 0.75, fbm(res, 4, 4, rng, 3)) * (1 - plates)
    col = col * (1 - 0.5 * moss[..., None]) + srgb("#6E8A3C")[None, None, :] * 0.5 * moss[..., None]
    h = plates * 0.8 + 0.2 * fine
    return col, h, 0.012, np.zeros_like(h), 0.92 + 0.0 * h


def tex_rope(res, m, rng):
    u, v = grid(res)
    strands = 3
    s = ((u + v * 0.9) * strands * 4) % 1.0
    prof = np.sin(s * math.pi) ** 0.6
    fibers = vnoise(res, 128, 16, rng)
    c = srgb("#D6BF85")
    col = c[None, None, :] * (0.55 + 0.5 * prof[..., None]) * (0.9 + 0.15 * fibers[..., None])
    h = prof * 0.85 + 0.15 * fibers
    return col, h, 0.004, np.full_like(h, 0.3), 0.95 + 0.0 * h


def tex_net(res, m, rng):
    u, v = grid(res)
    k = 10
    a = ((u + v) * k) % 1.0
    b = ((u - v) * k) % 1.0
    la = 1 - smooth(0.03, 0.09, np.minimum(a, 1 - a))
    lb = 1 - smooth(0.03, 0.09, np.minimum(b, 1 - b))
    th = np.maximum(la, lb)
    knot = la * lb
    col = np.ones(3)[None, None, :] * (0.18 + 0.75 * th[..., None] + 0.1 * knot[..., None])
    h = th * 0.8 + knot * 0.2
    return col, h, 0.004, np.ones_like(h), 0.95 + 0.0 * h


def tex_rock(res, m, rng):
    u, v = grid(res)
    big = fbm(res, 4, 4, rng, 6)
    pts = rng.random((40, 2))
    f1, f2, idx = cells(res, pts)
    crev = 1 - smooth(0.0, 0.012, f2 - f1)
    tones = rng.uniform(0.85, 1.1, len(pts))[idx]
    c = srgb("#A9A3B8")
    col = c[None, None, :] * tones[..., None] * (0.8 + 0.3 * big[..., None])
    col *= (1 - 0.45 * crev[..., None])
    moss = smooth(0.62, 0.75, fbm(res, 5, 5, rng, 4))
    col = col * (1 - 0.6 * moss[..., None]) + srgb("#6F9A45")[None, None, :] * 0.6 * moss[..., None]
    h = 0.6 * big + 0.4 * (1 - crev)
    return col, h, 0.05, np.zeros_like(h), 0.85 + 0.0 * h


def tex_burlap(res, m, rng):
    """Juta/lona de saco: trama grossa (fios por cima e por baixo), fibras e manchas."""
    u, v = grid(res)
    k = 36
    a = np.sin(u * k * 2 * math.pi)
    b = np.sin(v * k * 2 * math.pi)
    over = (np.floor(u * k * 2) + np.floor(v * k * 2)) % 2
    warp = np.abs(np.sin(u * k * math.pi)) ** 0.7
    weft = np.abs(np.sin(v * k * math.pi)) ** 0.7
    th = np.where(over > 0, warp, weft)
    fib = vnoise(res, 256, 32, rng) * 0.5 + vnoise(res, 32, 256, rng) * 0.5
    blot = fbm(res, 4, 4, rng, 4)
    c = srgb("#CDAE7E")
    col = c[None, None, :] * (0.62 + 0.42 * th[..., None]) * (0.9 + 0.15 * fib[..., None]) * (0.92 + 0.12 * blot[..., None])
    h = th * 0.8 + 0.2 * fib
    return col, h, 0.004, np.full_like(h, 0.75), 0.95 + 0.0 * h + 0.0 * a * b


FUNCS = {
    "deck": tex_deck, "wood": tex_wood, "paint": tex_paint, "slats": tex_slats, "plaster": tex_plaster,
    "stone": tex_stone, "cobble": tex_cobble, "roof": tex_roof, "canvas": tex_canvas, "metal": tex_metal,
    "grass": tex_grass, "dirt": tex_dirt, "leaf": tex_leaf, "bark": tex_bark, "rope": tex_rope, "net": tex_net,
    "rock": tex_rock, "burlap": tex_burlap,
}


# ------------------------------------------------------------------ saida
def _png_filter_rows(a):
    """Filtros PNG por linha (0 nenhum, 1 Sub, 2 Up, 3 Average, 4 Paeth), escolhendo o de menor soma |residuo| (heuristica
    do libpng). Sem perda: o arquivo decodifica nos mesmos bytes; so comprime melhor (E3, peso do repositorio)."""
    h, w, c = a.shape
    x = a.reshape(h, w * c).astype(np.int16)
    left = np.zeros_like(x)
    left[:, c:] = x[:, :-c]
    up = np.zeros_like(x)
    up[1:] = x[:-1]
    ul = np.zeros_like(x)
    ul[1:, c:] = x[:-1, :-c]
    p = left + up - ul
    pa, pb, pc = np.abs(p - left), np.abs(p - up), np.abs(p - ul)
    paeth = np.where((pa <= pb) & (pa <= pc), left, np.where(pb <= pc, up, ul))
    cands = [x, x - left, x - up, x - (left + up) // 2, x - paeth]
    res = [(cd & 0xFF).astype(np.uint8) for cd in cands]
    cost = np.stack([np.abs(r.astype(np.int8).astype(np.int16)).sum(axis=1) for r in res])
    best = cost.argmin(axis=0)
    out = bytearray()
    for y in range(h):
        out += bytes((int(best[y]),)) + res[best[y]][y].tobytes()
    return bytes(out)


def write_png_rgba(path, arr):
    """arr (h,w,4) 0..1, linha 0 = base da imagem. PNG RGBA 8 bits com filtro adaptativo por linha."""
    a = (np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8)[::-1]
    h, w, _ = a.shape
    raw = _png_filter_rows(np.ascontiguousarray(a))
    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def half(arr):
    """Reduz pela metade (media 2x2). Usado nos dados (normal, mascara, rugosidade) que nao precisam da resolucao da cor."""
    h, w, c = arr.shape
    return arr.reshape(h // 2, 2, w // 2, 2, c).mean(axis=(1, 3))


def write_jpg(path, arr, name):
    import bpy
    h, w, _ = arr.shape
    img = bpy.data.images.new("tmp_" + name, w, h, alpha=False)
    rgba = np.concatenate([np.clip(arr, 0, 1), np.ones((h, w, 1))], axis=-1)
    img.pixels.foreach_set(rgba.astype(np.float32).ravel())
    sc = bpy.context.scene
    sc.render.image_settings.file_format = "JPEG"
    sc.render.image_settings.quality = 92
    sc.render.image_settings.color_management = "OVERRIDE"
    sc.render.image_settings.view_settings.view_transform = "Standard"
    img.save_render(path, scene=sc)
    bpy.data.images.remove(img)


def build(out_dir, only=None, log=print):
    os.makedirs(out_dir, exist_ok=True)
    info = {}
    for i, (name, (meters, res)) in enumerate(SPECS.items()):
        if only and name not in only:
            continue
        rng = np.random.default_rng(1000 + i * 17)
        col, h, depth, mask, rough = FUNCS[name](res, meters, rng)
        h = np.clip(h, 0, 1.5)
        nrm = normal_from_height(h, meters, res, depth)
        data = np.concatenate([nrm[..., :2], np.clip(mask, 0, 1)[..., None], np.clip(rough, 0, 1)[..., None]], axis=-1)
        write_jpg(os.path.join(out_dir, name + "_albedo.jpg"), col, name)
        if name in DATA_HALF:
            data = half(data)
        write_png_rgba(os.path.join(out_dir, name + "_data.png"), data)
        info[name] = {"metros": meters, "resolucao": res, "resolucao_dados": data.shape[0]}
        log("textura %s %dpx %.2fm" % (name, res, meters))
    return info


IMPORT_TMPL = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://%s"

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=2
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=false
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""


def write_imports(out_dir, game_dir):
    """.import da Godot com mipmaps (sem cintilar a distancia) e sem compressao com perda (normal e mascaras exatas).
    So cria se nao existir: a Godot completa o arquivo (uid, caminho importado) na primeira importacao."""
    for f in sorted(os.listdir(out_dir)):
        if f.endswith((".jpg", ".png")):
            p = os.path.join(out_dir, f + ".import")
            if os.path.exists(p):
                continue
            rel = os.path.relpath(os.path.join(out_dir, f), game_dir).replace(os.sep, "/")
            with open(p, "w") as fh:
                fh.write(IMPORT_TMPL % rel)
