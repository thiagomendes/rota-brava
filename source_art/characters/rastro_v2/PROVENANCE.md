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
