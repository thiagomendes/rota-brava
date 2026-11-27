#!/usr/bin/env python3
"""G15 (RB-R1): gera os glifos de teclado, controle e toque em game/ui/glyphs/svg/.

Desenhos 100% originais do projeto (formas simples: tecla, circulo, losango). Sem logo, marca ou desenho oficial de
fabricante. Cada SVG declara no <svg> as cores que o teste de contraste confere:
  data-out  = contorno externo (silhueta sobre o fundo escuro da dica)
  data-body = corpo do botao/tecla
  data-sym  = simbolo (letra/forma) sobre o corpo
Uso: python3 tools/glyphs/make_glyphs.py   (depois: tools/godot.sh --headless --path game --import)
"""
from pathlib import Path

from help_symbol import BALLOON  # G22a: a ajuda e um "?" num balao, nao a letra H

OUT = Path(__file__).resolve().parents[2] / "game" / "ui" / "glyphs" / "svg"

WHITE = "#FFFFFF"
PAPER = "#F7FBFF"
LIP = "#B9C9DA"
INK = "#0B2440"
NAVY = "#123A5E"
DARK = "#2A3342"
GRAY = "#3B4250"
YELLOW = "#FFD23F"

# Letras em traco (caixa 28..72, centro 50), usadas em teclas e botoes.
LETTERS = {
    "A": "M31 72L50 28L69 72M38 57H62",
    "B": "M37 28V72H55Q68 72 68 60.5Q68 50 55 50H37M37 28H53Q64 28 64 39Q64 50 53 50",
    "X": "M34 30L66 70M66 30L34 70",
    "Y": "M33 28L50 50L67 28M50 50V72",
    "E": "M64 28H38V72H64M38 50H59",
    "H": "M36 28V72M64 28V72M36 50H64",
    "W": "M25 30L36 71L50 42L64 71L75 30",
    "S": "M64 35Q59 28 50 28Q36 28 36 39Q36 48 50 50Q64 52 64 61Q64 72 50 72Q40 72 35 65",
    "D": "M37 28V72H48Q67 72 67 50Q67 28 48 28Z",
    "R": "M38 72V28H54Q66 28 66 40Q66 52 54 52H38M53 52L66 72",
    "T": "M32 28H68M50 28V72",
    "Z": "M34 28H66L34 72H66",
    "2": "M36 38Q38 28 50 28Q64 28 64 40Q64 48 52 56L36 72H66",
}


def svg(body: str, colors: tuple[str, str, str], w: int = 100, h: int = 100) -> str:
    out, bod, sym = colors
    px_w = round(256 * w / h)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{px_w}" height="256" viewBox="0 0 {w} {h}" '
        f'data-out="{out}" data-body="{bod}" data-sym="{sym}">{body}</svg>\n'
    )


def stroke(d: str, color: str, width: float = 9.0, fill: str = "none") -> str:
    return (f'<path d="{d}" fill="{fill}" stroke="{color}" stroke-width="{width}" '
            f'stroke-linecap="round" stroke-linejoin="round"/>')


def scaled(inner: str, cx: float, cy: float, s: float) -> str:
    return f'<g transform="translate({cx} {cy}) scale({s}) translate(-50 -50)">{inner}</g>'


# ---------- teclado ----------

def keycap(sym: str, w: int = 100) -> str:
    """Tecla clara: borda branca, degrau azulado embaixo, topo papel, simbolo tinta."""
    body = (f'<rect x="4" y="6" width="{w - 8}" height="90" rx="20" fill="{WHITE}"/>'
            f'<rect x="9" y="11" width="{w - 18}" height="80" rx="15" fill="{LIP}"/>'
            f'<rect x="9" y="11" width="{w - 18}" height="70" rx="15" fill="{PAPER}"/>'
            f'{sym}')
    return svg(body, (WHITE, PAPER, INK), w)


def key_letter(ch: str) -> str:
    return keycap(scaled(stroke(LETTERS[ch], INK, 11), 50, 46, 0.78))


def keys() -> dict[str, str]:
    k = {f"key_{c.lower()}": key_letter(c) for c in "EHWASD"}
    k["key_blank"] = keycap("")
    # Espaco: tecla larga com o colchete deitado.
    k["key_space"] = keycap(stroke("M40 40V54H120V40", INK, 9), 160)
    # Shift: seta grossa vazada para cima.
    k["key_shift"] = keycap(stroke("M65 22L42 46H55V68H75V46H88Z", INK, 7), 130)
    # Enter: seta que desce e volta para a esquerda.
    k["key_enter"] = keycap(stroke("M86 24V54H44M56 41L43 54L56 67", INK, 9), 130)
    # Esc: as tres letras pequenas.
    esc = (stroke("M44 30H28V64H44M28 47H40", INK, 7)
           + stroke("M70 40Q67 36 61 36Q53 36 53 42Q53 47 61 48Q70 49 70 56Q70 64 61 64Q54 64 51 59", INK, 7)
           + stroke("M101 40Q98 36 92 36Q81 36 81 50Q81 64 92 64Q98 64 101 60", INK, 7))
    k["key_escape"] = keycap(esc, 130)
    # Setas.
    arrows = {"up": "M50 28L30 52H42V70H58V52H70Z", "down": "M50 72L30 48H42V30H58V48H70Z",
              "left": "M28 50L52 30V42H70V58H52V70Z", "right": "M72 50L48 30V42H30V58H48V70Z"}
    for n, d in arrows.items():
        k[f"key_{n}"] = keycap(scaled(f'<path d="{d}" fill="{INK}" stroke="{INK}" stroke-width="4" '
                                      f'stroke-linejoin="round"/>', 50, 46, 0.85))
    return k


# ---------- controle ----------

def pad_button(fill: str, sym: str, sym_color: str) -> str:
    body = (f'<circle cx="50" cy="50" r="46" fill="{WHITE}"/>'
            f'<circle cx="50" cy="50" r="39" fill="{fill}"/>{sym}')
    return svg(body, (WHITE, fill, sym_color))


def pad_letter(fill: str, ch: str, color: str = WHITE) -> str:
    return pad_button(fill, scaled(stroke(LETTERS[ch], color, 12), 50, 50, 0.72), color)


def pad_start(sym: str | None = None) -> str:
    lines = sym or stroke("M37 41H63M37 50H63M37 59H63", WHITE, 6)
    body = (f'<rect x="8" y="24" width="84" height="52" rx="26" fill="{WHITE}"/>'
            f'<rect x="14" y="30" width="72" height="40" rx="20" fill="{DARK}"/>{lines}')
    return svg(body, (WHITE, DARK, WHITE))


def pad_trigger(label: str) -> str:
    """Gatilho direito: aba arredondada com duas letras pequenas (ou seta, no generico)."""
    shape_out = "M18 84V44Q18 14 52 12Q84 10 84 38V84Z"
    shape_in = "M25 78V45Q25 21 52 19Q77 17 77 39V78Z"
    if label:
        sym = (scaled(stroke(LETTERS[label[0]], WHITE, 13), 37, 52, 0.5)
               + scaled(stroke(LETTERS[label[1]], WHITE, 13), 63, 52, 0.5))
    else:
        sym = stroke("M51 32V62M39 51L51 63L63 51", WHITE, 8)
    body = f'<path d="{shape_out}" fill="{WHITE}"/><path d="{shape_in}" fill="{DARK}"/>{sym}'
    return svg(body, (WHITE, DARK, WHITE))


def generic_diamond(lit: str) -> str:
    pos = {"north": (50, 19), "east": (81, 50), "south": (50, 81), "west": (19, 50)}
    parts = []
    for n, (x, y) in pos.items():
        parts.append(f'<circle cx="{x}" cy="{y}" r="17" fill="{WHITE}"/>')
        parts.append(f'<circle cx="{x}" cy="{y}" r="11.5" fill="{YELLOW if n == lit else DARK}"/>')
    return svg("".join(parts), (WHITE, DARK, YELLOW))


def pads() -> dict[str, str]:
    p: dict[str, str] = {}
    # Xbox (posicao -> letra em circulo colorido).
    xbox = {"south": ("#1E7B34", "A", WHITE), "east": ("#C42B21", "B", WHITE),
            "west": ("#1D5FC4", "X", WHITE), "north": (YELLOW, "Y", INK)}
    for pos, (fill, ch, col) in xbox.items():
        p[f"xbox_{pos}"] = pad_letter(fill, ch, col)
    # PlayStation: formas em traco claro sobre circulo escuro.
    ps = {"south": ("M36 36L64 64M64 36L36 64", "#9CC8FF"),
          "east": ("M50 33A17 17 0 1 1 49.9 33Z", "#FF9A9A"),
          "west": ("M35 35H65V65H35Z", "#F7A8DE"),
          "north": ("M50 31L68 64H32Z", "#6EE0B4")}
    for pos, (d, col) in ps.items():
        p[f"playstation_{pos}"] = pad_button(DARK, stroke(d, col, 9), col)
    # Nintendo: letra impressa na posicao (B embaixo, A a direita, Y a esquerda, X em cima).
    nin = {"south": "B", "east": "A", "west": "Y", "north": "X"}
    for pos, ch in nin.items():
        p[f"nintendo_{pos}"] = pad_letter(GRAY, ch)
    for pos in ("south", "east", "west", "north"):
        p[f"generic_{pos}"] = generic_diamond(pos)
    p["pad_start"] = pad_start()
    p["nintendo_start"] = pad_start(stroke("M50 37V63M37 50H63", WHITE, 8))
    p["xbox_trigger_right"] = pad_trigger("RT")
    p["playstation_trigger_right"] = pad_trigger("R2")
    p["nintendo_trigger_right"] = pad_trigger("ZR")
    p["pad_trigger_right"] = pad_trigger("")
    p["pad_other"] = generic_diamond("")
    return p


# ---------- toque (o botao que a crianca ve na tela) ----------

HAND = ('<g fill="#FFFFFF" stroke="#0B2440" stroke-width="6" stroke-linejoin="round"><rect x="27" y="22" width="12" '
        'height="40" rx="6"/><rect x="40" y="14" width="12" height="46" rx="6"/><rect x="53" y="17" width="12" '
        'height="44" rx="6"/><rect x="66" y="26" width="11" height="36" rx="5.5"/><path d="M14 52q6-6 13 1l6 7V48h44v16'
        'q0 22-22 22H48q-12 0-20-10z"/></g>')


def touch_disc(fill: str, ring: str, sym: str, sym_color: str) -> str:
    body = (f'<circle cx="50" cy="50" r="47" fill="{WHITE}"/>'
            f'<circle cx="50" cy="50" r="42" fill="{ring}"/>'
            f'<circle cx="50" cy="50" r="36" fill="{fill}"/>{sym}')
    return svg(body, (WHITE, fill, sym_color))


def touches() -> dict[str, str]:
    t: dict[str, str] = {}
    t["touch_interact"] = touch_disc(YELLOW, NAVY, scaled(HAND, 50, 52, 0.62), INK)
    t["touch_ui_accept"] = touch_disc(PAPER, NAVY, scaled(HAND, 50, 52, 0.62), INK)
    jump = ('<path d="M50 14L24 44h15v26h22V44h15z" fill="#E2453A" stroke="#0B2440" stroke-width="7" '
            'stroke-linejoin="round"/><path d="M24 84q26-11 52 0" fill="none" stroke="#0B2440" stroke-width="8" '
            'stroke-linecap="round"/>')
    t["touch_jump"] = touch_disc(PAPER, NAVY, scaled(jump, 50, 50, 0.62), INK)
    # G22a: disco claro (como pular) com o balao amarelo da ajuda; antes era a letra H num disco amarelo.
    t["touch_help"] = touch_disc(PAPER, NAVY, scaled(BALLOON, 50, 51, 0.74), INK)
    bars = (f'<rect x="38" y="34" width="9" height="32" rx="4.5" fill="{WHITE}"/>'
            f'<rect x="53" y="34" width="9" height="32" rx="4.5" fill="{WHITE}"/>')
    t["touch_pause"] = touch_disc("#1D5FC4", NAVY, bars, WHITE)
    t["touch_ui_cancel"] = touch_disc(PAPER, NAVY, stroke("M64 50H36M48 37L35 50L48 63", INK, 9), INK)
    run = (f'<circle cx="44" cy="50" r="19" fill="none" stroke="{INK}" stroke-width="5"/>'
           f'<circle cx="60" cy="50" r="11" fill="{INK}"/>'
           + stroke("M74 40L80 50L74 60", INK, 6))
    t["touch_run"] = touch_disc(PAPER, NAVY, run, INK)
    return t


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    allg = {**keys(), **pads(), **touches()}
    for name, text in sorted(allg.items()):
        (OUT / f"{name}.svg").write_text(text, encoding="utf-8")
    print(f"{len(allg)} glifos em {OUT}")


if __name__ == "__main__":
    main()
