#!/usr/bin/env python3
"""Logotipos "Rota Brava" das 3 propostas de arte-chave (RB-R1 G8). Lettering proprio, sem fonte.

Cada letra e um esqueleto de tracos (cap height 100, y para baixo) desenhado aqui; o estilo vem das camadas de
contorno, extrusao, gradiente e brilho. So 6 glifos: R, O, T, A, B, V.

Uso:  python3 source_art/ui/keyart/make_logos.py
Saida: source_art/ui/keyart/logo_{a,b,c}.svg e copia em game/ui/title/keyart/logos/ (o jogo rasteriza na hora).
Sem dependencias alem da biblioteca padrao. Geometria 100% original (PROVISORIO ate Thiago escolher).
"""
from __future__ import annotations

import math
import pathlib
import shutil

HERE = pathlib.Path(__file__).resolve().parent
GAME_DIR = HERE.parents[2] / "game" / "ui" / "title" / "keyart" / "logos"

# ------------------------------------------------------------------ glifos (esqueletos)
# Cada glifo: (largura do esqueleto, [paths]) com origem no canto superior esquerdo e altura 100.


def _glyph(ch: str, round_style: bool = True) -> tuple[float, list[str]]:
    if ch == "R":
        return 58.0, ["M0 100V0h30a25 25 0 0 1 0 50H0", "M30 52L58 100"]
    if ch == "O":
        # elipse em 4 arcos (ThorVG aceita arcos em path)
        return 66.0, ["M33 0A33 50 0 0 1 66 50A33 50 0 0 1 33 100A33 50 0 0 1 0 50A33 50 0 0 1 33 0Z"]
    if ch == "T":
        return 58.0, ["M0 0H58", "M29 0V100"]
    if ch == "A":
        return 60.0, ["M0 100L30 0L60 100", "M12 64H48"]
    if ch == "B":
        return 58.0, ["M0 50H28a24 24 0 0 0 0-50H0V100H32a25 25 0 0 0 0-50"]
    if ch == "V":
        return 60.0, ["M0 0L30 100L60 0"]
    raise ValueError(ch)


def _word_layout(word: str, stroke: float, gap: float) -> list[tuple[str, float, float]]:
    """[(letra, x, largura)] com avanco = largura do esqueleto + traco + folga."""
    out = []
    x = 0.0
    for ch in word:
        if ch == " ":
            x += stroke * 1.2
            continue
        w, _ = _glyph(ch)
        out.append((ch, x, w))
        x += w + stroke + gap
    return out


def _word_width(word: str, stroke: float, gap: float) -> float:
    lay = _word_layout(word, stroke, gap)
    ch, x, w = lay[-1]
    return x + w


def _paths(ch: str) -> str:
    return " ".join(_glyph(ch)[1])


def _svg(w: float, h: float, vb: tuple[float, float, float, float], body: str, defs: str = "") -> str:
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w:.0f}" height="{h:.0f}" '
        f'viewBox="{vb[0]:.1f} {vb[1]:.1f} {vb[2]:.1f} {vb[3]:.1f}">\n'
        f"<!-- Rota Brava: lettering original do projeto (RB-R1 G8), gerado por source_art/ui/keyart/make_logos.py -->\n"
        f"<defs>{defs}</defs>\n{body}\n</svg>\n"
    )


# ------------------------------------------------------------------ A: "Sol da Rota" (hora magica)
# Bloco italico de pontas retas, extrusao azul-noite, gradiente sol (creme -> ouro -> laranja) com faixa de brilho,
# sol nascente atras e onda turquesa embaixo. Uma linha so: le bem na capsula e no 16:9.

def logo_a() -> str:
    S, GAP = 34.0, 6.0
    word = "ROTA BRAVA"
    lay = _word_layout(word, S, GAP)
    width = _word_width(word, S, GAP)
    skew = -12.0
    navy = "#14213D"

    def letters(attrs: str, dx: float = 0.0, dy: float = 0.0) -> str:
        parts = []
        for ch, x, _w in lay:
            parts.append(f'<path d="{_paths(ch)}" transform="translate({x + dx:.2f} {dy:.2f})"/>')
        return f'<g {attrs} transform="skewX({skew})">' + "".join(parts) + "</g>"

    defs = (
        '<linearGradient id="sunfill" x1="0" y1="-17" x2="0" y2="117" gradientUnits="userSpaceOnUse">'
        '<stop offset="0" stop-color="#FFF8C8"/><stop offset="0.38" stop-color="#FFD83A"/>'
        '<stop offset="0.39" stop-color="#FFC21E"/><stop offset="1" stop-color="#FF6B1F"/></linearGradient>'
        '<radialGradient id="sundisc" cx="0" cy="0" r="1" gradientUnits="objectBoundingBox">'
        '<stop offset="0" stop-color="#FFE9A0"/><stop offset="1" stop-color="#FF8A3D"/></radialGradient>'
        '<linearGradient id="wave" x1="0" y1="0" x2="1" y2="0">'
        '<stop offset="0" stop-color="#18B7B0"/><stop offset="1" stop-color="#2C7BE5"/></linearGradient>'
    )
    o_x = width * 0.5
    sun = (
        f'<g transform="translate({o_x:.1f} 40)">'
        # raios do sol: 12 fatias finas (poligonos), atras de tudo
        + "".join(
            f'<polygon points="0,0 {math.cos(a - 0.07) * 230:.1f},{math.sin(a - 0.07) * 230:.1f} '
            f'{math.cos(a + 0.07) * 230:.1f},{math.sin(a + 0.07) * 230:.1f}" fill="#FFC857" opacity="0.55"/>'
            for a in [math.radians(180 + 10 + i * 16) for i in range(0, 11)]
        )
        + "".join(f'<path d="M{-r} 100 V0 A{r} {r} 0 0 1 {r} 0 V100 Z" fill="{c}"/>'
                  for r, c in ((132, navy), (124, "#FF8A3D"), (104, "#FFB547"), (82, "#FFD66B")))
        + "</g>"
    )
    extr = "".join(
        letters(f'fill="none" stroke="{navy}" stroke-width="{S + 18}" stroke-linejoin="round" stroke-linecap="butt"',
                dx=k * 1.0, dy=k * 1.5)
        for k in range(1, 13)
    )
    outline = letters(f'fill="none" stroke="{navy}" stroke-width="{S + 18}" stroke-linejoin="round" stroke-linecap="butt"')
    edge = letters(f'fill="none" stroke="#FFFFFF" stroke-width="{S + 6}" stroke-linejoin="round" stroke-linecap="butt"')
    fill = letters(f'fill="none" stroke="url(#sunfill)" stroke-width="{S}" stroke-linejoin="round" stroke-linecap="butt"')
    # onda (swash) sob a palavra
    y0 = 142
    wave_d = f"M-20 {y0}"
    n = 8
    seg = (width + 60) / n
    for i in range(n):
        x1 = -20 + seg * i
        wave_d += f" Q{x1 + seg * 0.5:.1f} {y0 + (-16 if i % 2 == 0 else 16)} {x1 + seg:.1f} {y0}"
    wave = (
        f'<path d="{wave_d}" fill="none" stroke="{navy}" stroke-width="30" stroke-linecap="round"/>'
        f'<path d="{wave_d}" fill="none" stroke="url(#wave)" stroke-width="16" stroke-linecap="round"/>'
        f'<path d="{wave_d}" fill="none" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round" opacity="0.7" '
        f'transform="translate(0 -4)"/>'
    )
    body = sun + wave + extr + outline + edge + fill
    pad = 40
    vb = (-pad - 60, -210, width + pad * 2 + 80, 400)
    return _svg(vb[2] * 2, vb[3] * 2, vb, body, defs)


# ------------------------------------------------------------------ B: "Festa das Lanternas" (noite)
# Duas linhas, tracos redondos e linha de base saltitante; creme quente com contorno ameixa e halo ambar.
# O "O" de ROTA vira uma lanterna de papel; varal de lanterninhas por cima.

def logo_b() -> str:
    S, GAP = 30.0, 9.0
    plum = "#2A1745"
    top = "ROTA"
    bot = "BRAVA"
    lay_t = _word_layout(top, S, GAP)
    lay_b = _word_layout(bot, S * 1.0, GAP)
    w_t = _word_width(top, S, GAP)
    w_b = _word_width(bot, S, GAP)
    sc_t = 0.78  # ROTA menor
    total_w = max(w_t * sc_t, w_b)
    ox_t = (total_w - w_t * sc_t) * 0.5
    ox_b = (total_w - w_b) * 0.5
    y_t, y_b = 0.0, 112.0

    def place(lay, i, ch, x, sc, oy):
        rot = (-5 if i % 2 == 0 else 4)
        dy = (-4 if i % 2 == 0 else 5)
        return x, rot, dy

    def word(lay, sc, ox, oy, attrs, skip_o=False):
        parts = []
        for i, (ch, x, w) in enumerate(lay):
            if skip_o and ch == "O":
                continue
            _, rot, dy = place(lay, i, ch, x, sc, oy)
            cx = x + w * 0.5
            parts.append(
                f'<path d="{_paths(ch)}" transform="translate({ox:.2f} {oy:.2f}) scale({sc}) '
                f'translate({x:.2f} {dy}) rotate({rot} {w * 0.5:.1f} 50)"/>'
            )
        return f"<g {attrs}>" + "".join(parts) + "</g>"

    def both(attrs):
        return word(lay_t, sc_t, ox_t, y_t, attrs, skip_o=True) + word(lay_b, 1.0, ox_b, y_b, attrs)

    defs = (
        '<linearGradient id="cream" x1="0" y1="0" x2="0" y2="212" gradientUnits="userSpaceOnUse">'
        '<stop offset="0" stop-color="#FFF9E8"/><stop offset="0.42" stop-color="#FFE9B8"/>'
        '<stop offset="0.5" stop-color="#FFF6DE"/><stop offset="1" stop-color="#FFB45E"/></linearGradient>'
        '<radialGradient id="paper" cx="0.4" cy="0.38" r="0.7">'
        '<stop offset="0" stop-color="#FFE38A"/><stop offset="0.55" stop-color="#FF7A3D"/>'
        '<stop offset="1" stop-color="#D93A4A"/></radialGradient>'
    )
    glow = "".join(
        both(f'fill="none" stroke="#FFB347" stroke-width="{S + wd}" stroke-linecap="round" stroke-linejoin="round" '
             f'opacity="{op}"')
        for wd, op in [(70, 0.08), (52, 0.12), (38, 0.18)]
    )
    shadow = both(f'fill="none" stroke="#120A22" stroke-width="{S + 20}" stroke-linecap="round" stroke-linejoin="round" '
                  f'transform="translate(3 7)" opacity="0.6"')
    outline = both(f'fill="none" stroke="{plum}" stroke-width="{S + 18}" stroke-linecap="round" stroke-linejoin="round"')
    fill = both(f'fill="none" stroke="url(#cream)" stroke-width="{S}" stroke-linecap="round" stroke-linejoin="round"')
    shine = both(f'fill="none" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round" stroke-linejoin="round" '
                 f'opacity="0.55" transform="translate(-3 -6)"')
    # lanterna no lugar do O de ROTA
    ch, ox_o, w_o = [t for t in lay_t if t[0] == "O"][0]
    i_o = [i for i, t in enumerate(lay_t) if t[0] == "O"][0]
    lx = ox_t + (ox_o + 33) * sc_t
    ly = y_t + 50 * sc_t + (-4 if i_o % 2 == 0 else 5) * sc_t
    rx, ry = 36 * sc_t * 1.3, 50 * sc_t * 1.25
    ribs = "".join(
        f'<path d="M0 {-ry:.1f} Q{rx * k:.1f} 0 0 {ry:.1f}" fill="none" stroke="#A3243A" stroke-width="3" opacity="0.7"/>'
        for k in (-0.95, -0.5, 0.5, 0.95)
    )
    lantern = (
        f'<g transform="translate({lx:.1f} {ly:.1f})">'
        f'<ellipse rx="{rx + 44:.1f}" ry="{ry + 40:.1f}" fill="#FFB347" opacity="0.10"/>'
        f'<ellipse rx="{rx + 26:.1f}" ry="{ry + 24:.1f}" fill="#FFB347" opacity="0.16"/>'
        f'<line x1="0" y1="{-ry - 30:.1f}" x2="0" y2="{-ry:.1f}" stroke="{plum}" stroke-width="5"/>'
        f'<ellipse rx="{rx + 9:.1f}" ry="{ry + 9:.1f}" fill="{plum}"/>'
        f'<ellipse rx="{rx:.1f}" ry="{ry:.1f}" fill="url(#paper)"/>' + ribs +
        f'<line x1="0" y1="{-ry:.1f}" x2="0" y2="{ry:.1f}" stroke="#A3243A" stroke-width="3" opacity="0.7"/>'
        f'<rect x="{-rx * 0.55:.1f}" y="{-ry - 8:.1f}" width="{rx * 1.1:.1f}" height="14" rx="5" fill="{plum}"/>'
        f'<rect x="{-rx * 0.55:.1f}" y="{ry - 6:.1f}" width="{rx * 1.1:.1f}" height="14" rx="5" fill="{plum}"/>'
        f'<path d="M0 {ry + 8:.1f} v18" stroke="#E8504A" stroke-width="6" stroke-linecap="round"/>'
        f'<ellipse cx="{-rx * 0.35:.1f}" cy="{-ry * 0.45:.1f}" rx="{rx * 0.22:.1f}" ry="{ry * 0.16:.1f}" '
        f'fill="#FFFFFF" opacity="0.55"/>'
        f"</g>"
    )
    # varal com lanterninhas
    gx0, gx1, gy = -70, total_w + 70, -92
    sag = 36
    string = f'<path d="M{gx0} {gy} Q{total_w * 0.5:.1f} {gy + sag * 2} {gx1} {gy}" fill="none" stroke="{plum}" stroke-width="4"/>'
    small = ""
    cols = ["#FF6B4A", "#FFC23A", "#4FC3F7", "#FF8FB1", "#8BD450", "#FFC23A", "#FF6B4A"]
    for i, c in enumerate(cols):
        t = (i + 0.5) / len(cols)
        x = (1 - t) ** 2 * gx0 + 2 * (1 - t) * t * (total_w * 0.5) + t ** 2 * gx1
        y = (1 - t) ** 2 * gy + 2 * (1 - t) * t * (gy + sag * 2) + t ** 2 * gy
        if abs(x - lx) < 60:
            continue
        small += (
            f'<g transform="translate({x:.1f} {y + 14:.1f})"><ellipse rx="26" ry="24" fill="#FFB347" opacity="0.15"/>'
            f'<ellipse rx="15" ry="17" fill="{plum}"/><ellipse rx="11" ry="13" fill="{c}"/>'
            f'<ellipse cx="-4" cy="-5" rx="3" ry="4" fill="#FFFFFF" opacity="0.6"/></g>'
        )
    body = string + small + glow + shadow + outline + fill + shine + lantern
    vb = (-110, -110, total_w + 220, 390)
    return _svg(vb[2] * 2, vb[3] * 2, vb, body, defs)


# ------------------------------------------------------------------ C: "Farol do Amanhecer" (insignia em arco)
# BRAVA em arco (letras giradas sobre um circulo), pontas quadradas e juncao em quina: ar de placa/insignia.
# ROTA numa fita coral; estrela-guia de 4 pontas (o brilho do farol) no alto. Branco com sombra azul-ceu.

def logo_c(night: bool = False) -> str:
    """night=True: versao da escolha de Thiago (cena B + logo C): recheio creme quente, halo ambar, sombra e
    estrela-guia com brilho de farol, para ler sobre o ceu roxo e as fachadas acesas."""
    S, GAP = 32.0, 7.0
    navy = "#102A43"
    lay_b = _word_layout("BRAVA", S, GAP)
    w_b = _word_width("BRAVA", S, GAP)
    R = 900.0  # raio do arco (centro abaixo)
    cx = w_b * 0.5
    cy = R + 60.0

    def arc_word(attrs: str, dy: float = 0.0) -> str:
        parts = []
        for ch, x, w in lay_b:
            mid = x + w * 0.5
            ang = (mid - cx) / R  # rad, comprimento de arco
            px = cx + math.sin(ang) * R
            py = cy - math.cos(ang) * R
            parts.append(
                f'<path d="{_paths(ch)}" transform="translate({px:.2f} {py + dy:.2f}) rotate({math.degrees(ang):.2f}) '
                f'translate({-w * 0.5:.2f} -50)"/>'
            )
        return f"<g {attrs}>" + "".join(parts) + "</g>"

    defs = (
        '<linearGradient id="skyfill" x1="0" y1="-20" x2="0" y2="140" gradientUnits="userSpaceOnUse">'
        '<stop offset="0" stop-color="#FFFFFF"/><stop offset="0.55" stop-color="#FFFFFF"/>'
        + ('<stop offset="0.56" stop-color="#FFF0D2"/><stop offset="1" stop-color="#FFC27A"/></linearGradient>' if night else
           '<stop offset="0.56" stop-color="#DDF1FF"/><stop offset="1" stop-color="#8CCBF5"/></linearGradient>') +
        '<linearGradient id="ribbon" x1="0" y1="0" x2="0" y2="1">'
        '<stop offset="0" stop-color="#FF7A5C"/><stop offset="1" stop-color="#E2453A"/></linearGradient>'
        '<linearGradient id="star" x1="0" y1="0" x2="0" y2="1">'
        '<stop offset="0" stop-color="#FFF6C2"/><stop offset="1" stop-color="#FFC233"/></linearGradient>'
    )
    common = 'fill="none" stroke-linejoin="miter" stroke-miterlimit="2.2" stroke-linecap="square"'
    extr = "".join(arc_word(f'{common} stroke="{navy}" stroke-width="{S + 18}"', dy=k * 0.7) for k in range(1, 17))
    outline = arc_word(f'{common} stroke="{navy}" stroke-width="{S + 18}"')
    fill = arc_word(f'{common} stroke="url(#skyfill)" stroke-width="{S}"')
    # fita com ROTA (menor), acima do arco
    rs = 0.5
    lay_r = _word_layout("ROTA", S, GAP)
    w_r = _word_width("ROTA", S, GAP) * rs
    rib_w = w_r + 120
    rib_x = cx - rib_w * 0.5
    rib_y = -96.0
    rib_h = 74.0
    ribbon = (
        # pontas dobradas
        f'<polygon points="{rib_x - 46:.1f},{rib_y + 14:.1f} {rib_x + 10:.1f},{rib_y + 14:.1f} {rib_x + 10:.1f},{rib_y + rib_h + 14:.1f} '
        f'{rib_x - 46:.1f},{rib_y + rib_h + 14:.1f} {rib_x - 26:.1f},{rib_y + rib_h * 0.5 + 14:.1f}" '
        f'fill="#B8323A" stroke="{navy}" stroke-width="7" stroke-linejoin="round"/>'
        f'<polygon points="{rib_x + rib_w + 46:.1f},{rib_y + 14:.1f} {rib_x + rib_w - 10:.1f},{rib_y + 14:.1f} '
        f'{rib_x + rib_w - 10:.1f},{rib_y + rib_h + 14:.1f} {rib_x + rib_w + 46:.1f},{rib_y + rib_h + 14:.1f} '
        f'{rib_x + rib_w + 26:.1f},{rib_y + rib_h * 0.5 + 14:.1f}" fill="#B8323A" stroke="{navy}" stroke-width="7" '
        f'stroke-linejoin="round"/>'
        f'<rect x="{rib_x:.1f}" y="{rib_y:.1f}" width="{rib_w:.1f}" height="{rib_h:.1f}" rx="10" fill="url(#ribbon)" '
        f'stroke="{navy}" stroke-width="7"/>'
    )
    rx0 = cx - w_r * 0.5
    ry0 = rib_y + (rib_h - 100 * rs) * 0.5
    rota = "".join(
        f'<path d="{_paths(ch)}" transform="translate({rx0 + x * rs:.2f} {ry0:.2f}) scale({rs})"/>' for ch, x, w in lay_r
    )
    rota_g = (
        f'<g fill="none" stroke="{navy}" stroke-width="{(S * 0.62 + 10) / rs:.1f}" stroke-linejoin="round" '
        f'stroke-linecap="round">{rota}</g>'
        f'<g fill="none" stroke="#FFFFFF" stroke-width="{S * 0.62 / rs:.1f}" stroke-linejoin="round" '
        f'stroke-linecap="round">{rota}</g>'
    )

    def star(x, y, r, rot=0.0):
        pts = []
        for i in range(8):
            a = math.radians(rot + i * 45 - 90)
            rr = r if i % 2 == 0 else r * 0.3
            pts.append(f"{x + math.cos(a) * rr:.1f},{y + math.sin(a) * rr:.1f}")
        return " ".join(pts)

    sparkle = (
        f'<polygon points="{star(cx, rib_y - 46, 52)}" fill="{navy}" stroke="{navy}" stroke-width="12" stroke-linejoin="round"/>'
        f'<polygon points="{star(cx, rib_y - 46, 52)}" fill="url(#star)"/>'
        f'<polygon points="{star(rib_x - 70, rib_y + 10, 20)}" fill="#FFE07A"/>'
        f'<polygon points="{star(rib_x + rib_w + 70, rib_y + 10, 20)}" fill="#FFE07A"/>'
    )
    body = extr + outline + fill + ribbon + rota_g + sparkle
    vb = (-120, -200, w_b + 240, 420)
    if night:
        round_ = 'fill="none" stroke-linejoin="round" stroke-linecap="round"'
        halo = "".join(
            arc_word(f'{round_} stroke="#FFB347" stroke-width="{S + wd}" opacity="{op}"', dy=6)
            + f'<rect x="{rib_x - 30:.1f}" y="{rib_y:.1f}" width="{rib_w + 60:.1f}" height="{rib_h + 14:.1f}" rx="30" '
            f'fill="none" stroke="#FFB347" stroke-width="{wd}" opacity="{op}"/>'
            for wd, op in ((84, 0.07), (60, 0.11), (40, 0.16))
        )
        shadow = arc_word(f'{common} stroke="#0A0B22" stroke-width="{S + 26}" opacity="0.55"', dy=16)
        sx, sy = cx, rib_y - 46
        rays = "".join(
            f'<polygon points="{sx:.1f},{sy:.1f} {sx + math.cos(a - 0.05) * 150:.1f},{sy + math.sin(a - 0.05) * 150:.1f} '
            f'{sx + math.cos(a + 0.05) * 150:.1f},{sy + math.sin(a + 0.05) * 150:.1f}" fill="#FFE9A8" opacity="0.30"/>'
            for a in [math.radians(i * 30 + 15) for i in range(12)]
        )
        glow = "".join(f'<circle cx="{sx:.1f}" cy="{sy:.1f}" r="{r}" fill="#FFE39A" opacity="{op}"/>'
                       for r, op in ((110, 0.10), (80, 0.16), (56, 0.24)))
        body = halo + shadow + extr + outline + fill + ribbon + rota_g + rays + glow + sparkle
        vb = (-130, -310, w_b + 260, 540)
    return _svg(vb[2] * 2, vb[3] * 2, vb, body, defs)


def main() -> None:
    GAME_DIR.mkdir(parents=True, exist_ok=True)
    for name, fn in (("logo_a", logo_a), ("logo_b", logo_b), ("logo_c", logo_c), ("logo_c_noite", lambda: logo_c(True))):
        p = HERE / f"{name}.svg"
        p.write_text(fn(), encoding="utf-8")
        shutil.copyfile(p, GAME_DIR / f"{name}.svg")
        print("ok", p)


if __name__ == "__main__":
    main()
