# Rastro v2 · proveniência (RB-R1 D11/D13) — PROPOSTA PROVISÓRIA

Herói investigador para aprovação de Thiago num visualizador 3D. **Não substitui** o Rastro do jogo
(`game/assets/models/characters/rastro.glb` continua em uso); aparece só na vitrine `game/lookdev/` (modo `after`).

## Origem de tudo (100% gerado no projeto)
| Item | Como foi feito |
|---|---|
| Traje inteiriço (tronco + braços + pernas numa malha só) | grafo de pele (modificador SKIN) + SUBSURF 3, formas de ombro/cotovelo/quadril/joelho e dobras modeladas por deslocamento em numpy (`rv2_body.shape_suit`), Decimate por colapso |
| Luvas de 4 dedos, botas, gola | SKIN + SUBSURF, achatamento da palma em numpy; sola ajustada ao contorno medido da própria bota; gola por superfície paramétrica + Solidify |
| Equipamento (cinto de equipe, fivela-bússola, emblema, scanner de pulso, lupa, bolsa com caderno, óculos-lupa) | torno (lathe), toros, tubos, prismas e caixas arredondadas em bmesh |
| Cabeça, rosto (olhos com dois brilhos, pálpebras, sobrancelhas, boca, visemas, olhar), esqueleto de 28 ossos | reuso do Rastro atual: `source_art/scripts/hero_lib.py`, `hero_face.py` (proporção ajustada) |
| Cabelo | metaballs (`rv2_body.hair_v2`), suavizado e decimado |
| Animações (12 clipes, mesmos nomes do jogo) | `source_art/scripts/hero_anim.py` + `rv2_anim.py` (idle com scanner e team_pose novos), FK/IK em Python |
| Texturas (cor, normal, ORM) | assadas no Cycles a partir da própria malha (posição, normal, parte, AO) e pintadas em numpy por fórmula: trama de tafetá, frisos, pespontos, vincos, rubor, fios do cabelo (`rv2_tex.py`). Nenhuma imagem de terceiros |

Nenhum modelo, malha, textura, HDRI ou personagem-base baixado ou importado. Paleta da bíblia de estilo (`docs/style-bible.md`).

## Arquivos
- Fonte: `build_rastro_v2.py` (entrada), `rv2_body.py`, `rv2_tex.py`, `rv2_anim.py`, `rv2_render.py`, `render_rastro_v2.py`; `rastro_v2.blend` (texturas empacotadas); `rastro_v2.info.json` (medidas).
- Saída: `game/assets/models/characters/rastro_v2.glb` (glTF 2.0 binário, metros, +Y para cima, PBR metallic-roughness, `KHR_materials_clearcoat`, texturas JPEG embutidas).
- Godot: `rastro_v2.glb.import` usa `game/lookdev/gltf_pbr_import.gd` (gera mipmaps nas texturas embutidas e aplica o verniz lido do próprio GLB, que a Godot 4.7 não importa sozinha).

## Reproduzir
```bash
bash tools/blender.sh --background --factory-startup --python source_art/characters/rastro_v2/build_rastro_v2.py -- \
  --glb $PWD/game/assets/models/characters/rastro_v2.glb --blend $PWD/source_art/characters/rastro_v2/rastro_v2.blend
bash tools/blender.sh --background source_art/characters/rastro_v2/rastro_v2.blend \
  --python source_art/characters/rastro_v2/render_rastro_v2.py -- captures/rastro_v2
```
O GLB não sai byte a byte idêntico entre exportações (JPEG e ordem interna), mas malha, materiais e medidas sim.

## Ciclos v2 de andar e correr (RB-R1, 2026-11-25, PROVISORIO)
Pedido de Thiago ("os pes estao muito acelerados"): `walk` e `run` refeitos por `source_art/scripts/hero_gait_v2.py` (FK/IK em Python, do zero), configurados em `rv2_anim.py` (`WALK`, `RUN`). Passada longa (curso de apoio 0,46 m), quadril calculado quadro a quadro pelo alcance real das pernas, guinada do quadril, pe que rola do calcanhar a ponta e sai/chega rente ao chao. Os demais clipes nao mudaram.
- ciclo / curso de apoio / avanco por ciclo / escala no jogo / passos por s: andar 1,00 s / 0,46 m / 1,186 m / x1,18 / 2,36; correr 0,60 s / 0,46 m / 1,714 m / x1,12 / 3,73 (escala = 1,4 ou 3,2 m/s dividido pela velocidade nominal do clipe).
- Folga minima entre as botas: 4,04 cm (walk), 4,60 cm (run), 0 intersecoes (`measure_feet.py`).

## Olhos abertos nos gestos (RB-R1 G1, 2026-11-26)
Thiago viu o trio de olhos fechados na abertura e no menu. O "alegre" e o sorriso de OLHOS FECHADOS e, em `wave`,
`celebrate`, `team_pose` e `look_to_leme`, durava 0,92-1,22 s seguidos. Agora `short_squint` (`rv2_anim.py`) deixa so um
aperto de ~0,45 s no pico do gesto; fora dele os olhos ficam abertos com a boca neutra (sorriso leve). Medido nas trilhas
importadas na Godot (olho fechado = max(alegre, blink) >= 0,5): wave 27% / 0,45 s; celebrate 36% / 0,45 s; team_pose
29% / 0,45 s; look_to_leme 18% / 0,45 s. Corpo, malha, materiais e medidas (`rastro_v2.info.json` igual) iguais; GLB e
.blend reexportados por `build_rastro_v2.py` (`--glb` e `--blend`).
O `point` (1,2 s, sem laco) piscava em 1,05 s e terminava com o olho 62% fechado; parado no ultimo quadro (close da
abertura) a heroina ficava de olho quase fechado. Agora pisca uma vez em 0,80 s (`blink_once`) e termina de olho aberto.
