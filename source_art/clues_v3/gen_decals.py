"""Rota Brava · Ep01 v3 (RB-R1 F2, art3d) · decalques GRANDES das pistas (pegadas e pena). Python 3 + numpy.

Tudo desenhado aqui por formulas proprias (campos de distancia de elipses e poligonos). Nenhuma imagem de terceiros.
Problema que resolvem (docs/proposals/ep01_v3_roteiro_intuitivo.md, P1): os decalques da E3 tinham 0,24 m e eram marrom
sobre terra marrom. Estes tem >= 0,45 m e CONTORNO EM DUAS CAMADAS em volta do desenho:
  miolo (cor da pista) -> halo claro (creme) -> aro escuro fino.
O halo claro separa o miolo da terra, da grama escura e da madeira na sombra; o aro escuro separa o halo da pedra
clara e da madeira clara. Assim a mesma pegada le em qualquer piso. Uma textura de EMISSAO (so halo/realces) deixa a
pista legivel a noite sem brilhar demais de dia (a energia fica na cena .tscn).

Saida (PNG RGBA, 8 bits): game/worlds/village_v3/decals/tex/<id>_albedo.png e <id>_emission.png
Orientacao: topo da imagem = -Z do Decal (frente da cena na Godot): dedos, ponta da pena e bico da bota para -Z.
Uso: python3 source_art/clues_v3/gen_decals.py
"""
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(REPO, "source_art", "environment_v2"))
import wv2_textures as TX  # noqa: E402  (so write_png_rgba: PNG proprio, sem bpy)

OUT = os.path.join(REPO, "game", "worlds", "village_v3", "decals", "tex")
INFO = os.path.join(HERE, "decals_v3.info.json")


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


CREAM = hexc("#FFF1D6")    # creme da marca (style bible)
RIM_DARK = hexc("#22170F")   # aro escuro quente
NAVY_RIM = hexc("#16263D")


def grid(w, h, sx, sy):
    """Grade de pixels em METROS: x em [-sx/2, sx/2] (direita), y em [-sy/2, sy/2] (y+ = topo da imagem)."""
    ys, xs = np.mgrid[0:h, 0:w]
    X = ((xs + 0.5) / w - 0.5) * sx
    Y = (0.5 - (ys + 0.5) / h) * sy
    return X, Y


def sd_ellipse(X, Y, cx, cy, rx, ry, ang=0.0):
    c, s = math.cos(ang), math.sin(ang)
    dx, dy = X - cx, Y - cy
    u = (dx * c + dy * s) / rx
    v = (-dx * s + dy * c) / ry
    return (np.sqrt(u * u + v * v) - 1.0) * min(rx, ry)


def sd_poly(X, Y, pts):
    """Distancia com sinal a um poligono fechado (negativa dentro). Vetorizado por aresta."""
    P = [tuple(pts[0])]
    for q in pts[1:]:
        if math.hypot(q[0] - P[-1][0], q[1] - P[-1][1]) > 1e-9:
            P.append(tuple(q))
    if math.hypot(P[0][0] - P[-1][0], P[0][1] - P[-1][1]) <= 1e-9:
        P.pop()
    P = np.asarray(P, dtype=float)
    d2 = np.full(X.shape, np.inf)
    inside = np.zeros(X.shape, dtype=bool)
    n = len(P)
    for i in range(n):
        ax, ay = P[i]
        bx, by = P[(i + 1) % n]
        ex, ey = bx - ax, by - ay
        wx, wy = X - ax, Y - ay
        t = np.clip((wx * ex + wy * ey) / (ex * ex + ey * ey), 0.0, 1.0)
        qx, qy = wx - ex * t, wy - ey * t
        d2 = np.minimum(d2, qx * qx + qy * qy)
        cond = ((ay <= Y) & (by > Y)) | ((by <= Y) & (ay > Y))
        xint = ax + (Y - ay) * ex / np.where(ey == 0, 1e-9, ey)
        inside ^= cond & (X < xint)
    d = np.sqrt(d2)
    return np.where(inside, -d, d)


def smin(a, b, k):
    """Uniao suave (polinomial): funde o halo de formas proximas num so contorno."""
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1 - h) + a * h - k * h * (1 - h)


def cover(d, px):
    """Cobertura antisserrilhada de d < 0 (px = tamanho do pixel em metros)."""
    return np.clip(0.5 - d / px, 0.0, 1.0)


def layered(d_core, d_halo, px, core_rgb, halo_rgb, rim_rgb, halo_w, rim_w, core_a=0.96, halo_a=0.92, rim_a=0.8):
    """Compoe miolo + halo claro + aro escuro. d_core: forma; d_halo: forma de base do halo (pode ser mais lisa).
    Devolve (rgb, alpha, mascara do halo)."""
    c_core = cover(d_core, px)
    c_halo = cover(d_halo - halo_w, px)
    c_rim = cover(d_halo - halo_w - rim_w, px * 1.6)
    # fora para dentro: aro escuro, depois halo, depois miolo
    rgb = np.ones(d_core.shape + (3,)) * rim_rgb
    a = c_rim * rim_a
    rgb = rgb * (1 - c_halo[..., None]) + halo_rgb * c_halo[..., None]
    a = a * (1 - c_halo) + halo_a * c_halo
    rgb = rgb * (1 - c_core[..., None]) + core_rgb * c_core[..., None]
    a = a * (1 - c_core) + core_a * c_core
    halo_only = np.clip(c_halo - c_core, 0, 1)
    return rgb, a, halo_only, c_core


def soft_noise(X, Y, k):
    return (np.sin(X * 37 * k + Y * 11 * k) * np.sin(Y * 29 * k - X * 7 * k) + 0.5 * np.sin(X * 83 * k + 1.7) *
            np.sin(Y * 71 * k + 0.4))


# ---------------------------------------------------------------- pegadas de pata
PAW_TOES = ((-0.5, 0.22, 0.17, 0.22, 0.35), (-0.18, 0.46, 0.17, 0.23, 0.1), (0.18, 0.46, 0.17, 0.23, -0.1),
            (0.5, 0.22, 0.17, 0.22, -0.35))


def paw_shape(X, Y, s):
    """Pata do filhote (almofada + 4 dedos), mesma forma da E3 ampliada. s = metros por unidade."""
    d = sd_ellipse(X, Y, 0.0, -0.25 * s, 0.42 * s, 0.34 * s)
    toes = None
    for cx, cy, rx, ry, a in PAW_TOES:
        t = sd_ellipse(X, Y, cx * s, cy * s, rx * s, ry * s, a)
        toes = t if toes is None else np.minimum(toes, t)
    core = np.minimum(d, toes)
    halo = smin(d, toes, 0.12 * s)
    return core, halo


def paw(size, kind):
    n = 512
    X, Y = grid(n, n, size, size)
    px = size / n
    s = size * 0.43            # pata com halo ocupa ~0,85 do quadro
    X = X
    Y = Y + 0.03 * size        # centraliza (os dedos sobem mais que a almofada desce)
    core, halo = paw_shape(X, Y, s)
    if kind == "dry":
        # lama marrom-escura com centro mais fundo (pegada prensada)
        depth = np.clip(-core / (0.06 * s), 0, 1)[..., None]
        col = hexc("#5A3A24") * (1 - 0.35 * depth) + 0.025 * soft_noise(X, Y, 0.8)[..., None]
        rgb, a, halo_m, core_m = layered(core, halo, px, col, CREAM, RIM_DARK, 0.035, 0.014)
        emis = halo_m[..., None] * CREAM * 0.9
    elif kind == "wet":
        # agua: miolo azul com brilho claro, halo azul-gelo e gotinhas em volta
        depth = np.clip(-core / (0.07 * s), 0, 1)[..., None]
        col = hexc("#2F7FC8") * (1 - 0.3 * depth)
        hl = np.clip(1 - np.abs(sd_ellipse(X, Y, -0.12 * s, -0.1 * s, 0.16 * s, 0.07 * s, 0.5)) / (0.03 * s), 0, 1) * \
            (sd_ellipse(X, Y, -0.12 * s, -0.1 * s, 0.16 * s, 0.07 * s, 0.5) < 0)
        col = col * (1 - hl[..., None]) + hexc("#D9F2FF") * hl[..., None]
        drops = None
        for cx, cy, r in ((-0.78, -0.5, 0.06), (0.72, -0.62, 0.05), (0.86, 0.6, 0.045), (-0.86, 0.66, 0.04), (0.0, -0.86, 0.05)):
            e = sd_ellipse(X, Y, cx * s, cy * s, r * s, r * s)
            drops = e if drops is None else np.minimum(drops, e)
        core = np.minimum(core, drops)
        halo = np.minimum(halo, drops)
        rgb, a, halo_m, core_m = layered(core, halo, px, col, hexc("#EAF8FF"), hexc("#0E2B47"), 0.035, 0.014)
        emis = halo_m[..., None] * hexc("#CFEFFF") * 0.9 + (hl * core_m)[..., None] * hexc("#FFFFFF") * 0.5
    elif kind == "mud":
        # pata de lama na tabua do cais: miolo escuro, respingos e um escorrido; halo creme
        depth = np.clip(-core / (0.06 * s), 0, 1)[..., None]
        col = hexc("#4A2C18") * (1 - 0.3 * depth) + 0.03 * soft_noise(X, Y, 0.7)[..., None]
        rng = np.random.default_rng(7)
        spl = None
        for _ in range(9):
            ang = rng.uniform(0, 2 * math.pi)
            rr = rng.uniform(0.78, 0.98)
            r = rng.uniform(0.03, 0.065)
            e = sd_ellipse(X, Y, math.cos(ang) * rr * s, math.sin(ang) * rr * s - 0.08 * s, r * s, r * s * rng.uniform(0.7, 1.2), ang)
            spl = e if spl is None else np.minimum(spl, e)
        core = np.minimum(core, spl)
        halo = smin(halo, spl, 0.08 * s)
        rgb, a, halo_m, core_m = layered(core, halo, px, col, CREAM, RIM_DARK, 0.035, 0.014)
        emis = halo_m[..., None] * CREAM * 0.9
    return rgb, a, emis


# ---------------------------------------------------------------- pena
def feather(size):
    n = 512
    X, Y = grid(n, n, size, size)
    px = size / n
    L = size * 0.84          # comprimento total (raque incluida)
    y0, y1 = -L / 2, L / 2
    # contorno: raque curva, largura em gota, ponta arredondada, um corte em V num lado (pena de verdade)
    ts = np.linspace(0, 1, 60)
    vane_lo = y0 + 0.16 * L
    yy = vane_lo + ts * (y1 - vane_lo)
    cx = 0.05 * L * np.sin(ts * 2.4)
    w = 0.26 * L * np.sin(np.clip(ts, 0, 1) * math.pi) ** 0.55 * (0.62 + 0.38 * ts)
    right = [(cx[i] + w[i], yy[i]) for i in range(len(ts))]
    left = [(cx[i] - w[i] * (0.82 if 0.55 < ts[i] < 0.62 else 1.0), yy[i]) for i in range(len(ts))]
    # corte em V no lado esquerdo
    left = [(x + (0.06 * L if 0.56 < (y - vane_lo) / (y1 - vane_lo) < 0.62 else 0.0), y) for x, y in left]
    poly = right + left[::-1]
    d_vane = sd_poly(X, Y, poly)
    t_all = (Y - vane_lo) / (y1 - vane_lo)
    cxx = 0.05 * L * np.sin(np.clip(t_all, -0.3, 1) * 2.4)
    d_rach = np.where((Y > y0) & (Y < y1 - 0.04 * L), np.abs(X - cxx) - 0.012 * L, 1.0)
    d_rach = np.minimum(d_rach, np.sqrt((X - cxx) ** 2 + (Y - y0) ** 2) - 0.012 * L)
    core = np.minimum(d_vane, d_rach)
    # cor: branca, barbas em V cinza-azuladas, ponta escura (ultimo quarto), raque creme
    dx = X - cxx
    barbs = 0.5 + 0.5 * np.sin((Y - np.abs(dx) * 0.9) * (2 * math.pi / (0.018 * L / 0.45 * 2.2)))
    t = np.clip(t_all, 0, 1)
    tip = np.clip((t - 0.72) / 0.12, 0, 1)
    white = hexc("#F7F9FC")
    col = white[None, None, :] * (1 - 0.1 * barbs[..., None])
    col = col * (1 - tip[..., None]) + hexc("#3A4454")[None, None, :] * (1 - 0.15 * barbs[..., None]) * tip[..., None]
    on_rach = np.clip(1 - (np.abs(dx) - 0.009 * L) / px, 0, 1) * (d_rach < 0.002)
    col = col * (1 - on_rach[..., None]) + hexc("#E9DCC0") * on_rach[..., None]
    halo = smin(d_vane, d_rach, 0.02 * L)
    # pena branca: o contorno de dentro e ESCURO (le na pedra clara); fora dele, halo claro suave (le na terra escura)
    c_core = cover(core, px)
    c_rim = cover(halo - 0.016, px)
    c_out = cover(halo - 0.016 - 0.02, px * 1.5)
    rgb = np.ones(core.shape + (3,)) * CREAM
    a = c_out * 0.7
    rgb = rgb * (1 - c_rim[..., None]) + NAVY_RIM * c_rim[..., None]
    a = a * (1 - c_rim) + 0.9 * c_rim
    rgb = rgb * (1 - c_core[..., None]) + col * c_core[..., None]
    a = a * (1 - c_core) + 0.97 * c_core
    emis = (c_core * (1 - tip))[..., None] * white * 0.85 + np.clip(c_out - c_rim, 0, 1)[..., None] * CREAM * 0.5
    return rgb, a, emis


# ---------------------------------------------------------------- pegada de bota (capitao)
def boot_print(w_m, h_m, side):
    """Sola de bota de marinheiro: bico + planta e salto separados (o arco nao marca), cravos em barras."""
    wpx, hpx = 256, 512
    X, Y = grid(wpx, hpx, w_m, h_m)
    px = h_m / hpx
    sgn = 1.0 if side == "r" else -1.0
    Xs = X * sgn
    L = h_m * 0.82
    fore = sd_ellipse(Xs, Y, 0.012, 0.12 * L, 0.205 * L, 0.33 * L, 0.06)
    toe = sd_ellipse(Xs, Y, 0.02, 0.33 * L, 0.17 * L, 0.16 * L, 0.1)
    fore = smin(fore, toe, 0.03)
    heel = sd_poly(Xs, Y, [(-0.135 * L, -0.5 * L + 0.04 * L), (0.135 * L, -0.5 * L + 0.04 * L), (0.15 * L, -0.27 * L),
                           (-0.145 * L, -0.27 * L)])
    heel = np.maximum(heel, sd_ellipse(Xs, Y, 0.0, -0.33 * L, 0.18 * L, 0.2 * L))
    core = np.minimum(fore, heel)
    halo = smin(fore, heel, 0.07)
    # cravos: barras inclinadas na planta, barras retas no salto (claras, "terra prensada")
    bars_f = (np.sin((Y + Xs * 0.25) * 2 * math.pi / 0.034) > 0.35) & (fore < -0.012)
    bars_h = (np.sin(Y * 2 * math.pi / 0.03) > 0.35) & (heel < -0.012)
    ring = (np.abs(core + 0.014) < 0.004)
    col = np.ones(core.shape + (3,)) * hexc("#33241A")
    tread = (bars_f | bars_h | ring).astype(float)
    col = col * (1 - tread[..., None]) + hexc("#7A5A3F") * tread[..., None]
    rgb, a, halo_m, core_m = layered(core, halo, px, col, CREAM, RIM_DARK, 0.032, 0.013)
    emis = halo_m[..., None] * CREAM * 0.9
    return rgb, a, emis


def finish(rgb, a):
    """Pixels transparentes com a cor vizinha (aro): evita franja clara/escura nos mipmaps."""
    rgb = np.clip(rgb, 0, 1)
    a = np.clip(a, 0, 1)
    return np.concatenate([rgb, a[..., None]], axis=-1)


# id: (descricao, tamanho do Decal em metros (x, z), funcao)
DECALS = {
    "decal_paw_big": ("pata do filhote, lama seca (M1/P4)", (0.6, 0.6), lambda: paw(0.6, "dry")),
    "decal_paw_wet_big": ("pata molhada do filhote (M2/P4)", (0.6, 0.6), lambda: paw(0.6, "wet")),
    "decal_paw_dock": ("pata de lama na tabua do cais (M1.bench)", (0.66, 0.66), lambda: paw(0.66, "mud")),
    "decal_feather_big": ("pena de gaivota (M5)", (0.6, 0.6), lambda: feather(0.6)),
    "decal_boot_print_l": ("pegada da bota do capitao, pe esquerdo (M1.boot)", (0.28, 0.56), lambda: boot_print(0.28, 0.56, "l")),
    "decal_boot_print_r": ("pegada da bota do capitao, pe direito (M1.boot)", (0.28, 0.56), lambda: boot_print(0.28, 0.56, "r")),
}


def bbox_m(alpha, size, thr=0.5):
    """Extensao (m) do que aparece (alpha > thr) em x e z."""
    h, w = alpha.shape
    ys, xs = np.nonzero(alpha > thr)
    return (round((xs.max() - xs.min() + 1) / w * size[0], 3), round((ys.max() - ys.min() + 1) / h * size[1], 3))


def main():
    os.makedirs(OUT, exist_ok=True)
    info = {}
    for did, (desc, size, fn) in DECALS.items():
        rgb, a, emis = fn()
        alb = finish(rgb, a)
        em = np.concatenate([np.clip(emis, 0, 1), np.ones(a.shape + (1,))], axis=-1)
        # write_png_rgba espera linha 0 = base da imagem; a grade tem linha 0 = topo
        TX.write_png_rgba(os.path.join(OUT, did + "_albedo.png"), alb[::-1])
        TX.write_png_rgba(os.path.join(OUT, did + "_emission.png"), em[::-1])
        ext = bbox_m(a, size)
        info[did] = {"descricao": desc, "tamanho_decal_m": list(size), "extensao_visivel_m": list(ext),
                     "px": [int(alb.shape[1]), int(alb.shape[0])]}
        print("DEC %-20s decal %.2fx%.2f m  visivel %.2fx%.2f m" % (did, size[0], size[1], ext[0], ext[1]))
    with open(INFO, "w", encoding="utf-8", newline="\n") as f:
        json.dump(info, f, indent=1, ensure_ascii=False, sort_keys=True)


if __name__ == "__main__":
    main()
