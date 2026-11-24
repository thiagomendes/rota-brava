# Heróis v2 · estudos de direção (RB-R1, D7) — PROVISÓRIO, só para escolha

Geometria 100% procedural feita do zero em `heroes_v2.py` (primitivas do Blender; nenhum modelo de terceiros).
Não é asset de jogo: sem rig, sem GLB, nada entra em `game/`.

- **A · Resgate náutico:** capacete arredondado na cor do herói com viseira de lente erguida, rádio nas laterais, macacão com colete de alças refletivas; cabeça 44% da altura.
- **B · Expedição high-tech:** cabeça maior (50%), sem capacete, visor de lente larga sobre os olhos com fone e antena, traje justo com faixas que brilham e mochila com anel; o cabelo fica à mostra.
- **C · Capacete-máscara em camadas:** capacete fechado com janela para o rosto e crista que diz a habilidade (lente no Rastro, pico no Pico, barbatana no Leme), corpo robusto em bloco com ombreiras, luvas amarelas e botas brancas; cabeça 41%.

Equipamento-assinatura nas três: Rastro lupa + scanner de pulso + mochila com antena; Pico corda a tiracolo + mosquetões + garra; Leme leme de pulso + bússola + boia nas costas.

Reproduzir (Linux, na raiz da worktree):
`xvfb-run -a bash tools/blender.sh --background --factory-startup --python source_art/studies/heroes_v2/heroes_v2.py -- A|B|C $PWD/captures/heroes_v2`

## Imagens (em `captures/heroes_v2/`, fora do Git)
Para cada direção X em A, B, C:
- `X_trio.png` — trio em pose de equipe (1600x1000, Eevee, sol quente + preenchimento frio + contraluz)
- `X_turnaround_<herói>.png` — frente, três-quartos, costas (A: rastro, B: pico, C: leme)
- `X_mini48.png` — os três com ~48 px de altura, de frente e de costas (480x96)
- `X_mini48_x4.png` — a mesma miniatura ampliada 4x sem filtro, só para ver

`heroes_v2_X.blend` = cena do trio de cada direção.
