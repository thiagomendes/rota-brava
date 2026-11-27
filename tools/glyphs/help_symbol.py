#!/usr/bin/env python3
"""G22a (RB-R1): simbolo da ajuda, um "?" desenhado num balao de fala. Substitui a letra H (tecla) no pictograma.

Desenho 100% original do projeto: balao de cantos redondos com rabicho e um ponto de interrogacao em traco (path, sem
fonte e sem <text>). Nao e letra de tecla: o selo da tecla H (G15) continua so no teclado/controle, fora deste desenho.
Por que balao e nao boia: a boia ja e objeto de missao (M6, "boias" no rio); a ajuda precisa ler como "perguntar".

Um so desenho para os dois usos:
  - pictograma da marca  game/ui/brand/icons/help_balloon.svg  (HUD no teclado/controle e camada de toque)
  - glifo de toque       game/ui/glyphs/svg/touch_help.svg      (tools/glyphs/make_glyphs.py importa BALLOON)
Uso: python3 tools/glyphs/help_symbol.py   (depois: tools/godot.sh --headless --path game --import)
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BRAND_OUT = ROOT / "game" / "ui" / "brand" / "icons" / "help_balloon.svg"

# Cores (as mesmas da marca): balao amarelo, contorno marinho, interrogacao tinta.
BALLOON_FILL = "#FFD23F"
OUTLINE = "#123A5E"
INK = "#0B2440"

# Caixa 100x100: balao de 14..86 x 14..70, rabicho para baixo a esquerda (ate y 88), "?" centrado no corpo.
BALLOON = (
    f'<path d="M30 14H70Q86 14 86 30V54Q86 70 70 70H46L28 88L31 70H30Q14 70 14 54V30Q14 14 30 14Z" '
    f'fill="{BALLOON_FILL}" stroke="{OUTLINE}" stroke-width="6" stroke-linejoin="round"/>'
    f'<path d="M39 33Q39 23 50 23Q61 23 61 33Q61 40 53 43Q50 44.5 50 49V51" fill="none" stroke="{INK}" '
    f'stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/>'
    f'<circle cx="50" cy="61" r="5.5" fill="{INK}"/>'
)


def brand_icon() -> str:
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 100 100" '
            f'data-body="{BALLOON_FILL}" data-sym="{INK}" data-out="{OUTLINE}">{BALLOON}</svg>\n')


def main() -> None:
    BRAND_OUT.write_text(brand_icon(), encoding="utf-8")
    print(f"pictograma da ajuda em {BRAND_OUT}")


if __name__ == "__main__":
    main()
