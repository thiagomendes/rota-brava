# Pico v2 · proveniência (RB-R1 D11/D13) — PROPOSTA PROVISÓRIA

Herói escalador para aprovação de Thiago num visualizador 3D. **Não substitui** o Pico do jogo
(`game/assets/models/characters/pico.glb` continua em uso); aparece só na vitrine `game/lookdev/` (modo `after`, via
`game/lookdev/pico_v2_model.tscn`).

Mesmo acabamento do Rastro v2 (vinil com verniz, tecido com trama assada, pespontos e vincos em normal map, corpo inteiriço,
mãos de 4 dedos, olhos com dois brilhos), com traje, silhueta, cabelo e acessórios próprios (D13).

## Conceito
- **Traje:** jaqueta curta **acolchoada** verde `#3DBE5A` (gomos horizontais no tronco e anéis nas mangas, modelados na
  malha; costuras com pesponto; painéis laterais, axilas, cotoveleiras e punhos em verde-escuro; zíper e gola em pé
  amarelo-corda `#FFD23F`; vivo verde-escuro na bainha; estrela amarela nas costas) + **calça de escalada** cinza-azulada
  (lona, costuras interna/lateral, joelho articulado, bolso de carga na coxa direita, barra franzida) com **joelheiras**
  verdes de vivo amarelo.
- **Silhueta:** capacete de escalada arredondado (listra amarela, respiros, estrela nas laterais, aro de borracha) com
  **lanterna de testa** e jugular amarela até a fivela sob o queixo; **rolo de corda a tiracolo** (ombro direito → quadril
  esquerdo, 5 voltas com hélice e fio traçador, amarrações verdes); **mosquetões grandes** (dourado e verde anodizados) no
  cinto e um preso nas amarrações; **saco de magnésio** nas costas; **luvas de escalada** amarelas com palma de aderência;
  **botas de aproximação** de cano baixo (biqueira e sola de borracha clara, cadarço amarelo, contraforte verde).
- **Cabelo e pele:** ruivo em mechas pontudas de vinil saindo do capacete (cortina atrás, costeletas, franja varrida),
  pele clara `#F3C9A2` com sardas pintadas, olhos azuis (trio diverso: Rastro moreno, Pico ruivo de pele clara, Leme negra).
- **Comum da equipe:** emblema da Rota Brava no peito (esquerdo, livre da corda) e cinto azul-marinho com fivela-bússola dourada.
- **Pés:** eixo das pernas afastado (`HIP_X = 0,088 m`) e botas mais estreitas: chão visível entre os pés de frente, parado;
  nenhum clipe aproxima os pés do eixo (medido por `pv2_check.py`, ver `pico_v2.check.json`).

## Origem de tudo (100% gerado no projeto)
| Item | Como foi feito |
|---|---|
| Corpo inteiriço (tronco + braços + pernas numa malha só) | grafo de pele (modificador SKIN) + SUBSURF 3; gomos do acolchoado, articulações, joelho, bolso de carga e barra deslocados por vértice em numpy (`pv2_body.shape_suit`); Decimate por colapso |
| Capacete | superfície paramétrica (elipsoide com borda variável por azimute) + Solidify; aro, faixa, lanterna e jugular por tubos, torno e projeção na cabeça (BVH) |
| Cabelo | massa por metaballs + mechas como tubos achatados que afinam até a ponta (`pv2_body.hair_tufts`) |
| Luvas, botas, joelheiras | SKIN + SUBSURF, achatamento da palma em numpy; sola ajustada ao contorno medido da própria bota; elipsoides |
| Corda, mosquetões, saco de magnésio, cinto, emblema | laço por raycast no próprio corpo (fechamento morfológico) e tubos fechados; mosquetão em D por tubo; torno, toros e prismas em bmesh |
| Cabeça, rosto (olhos com dois brilhos, pálpebras, sobrancelhas, boca, visemas, olhar), esqueleto de 28 ossos | reuso de `source_art/scripts/hero_lib.py` e `hero_face.py` (os mesmos do Pico atual) |
| Animações (11 clipes, mesmos nomes do `pico.glb`) | `source_art/scripts/hero_anim.py` + `pv2_anim.py` (`idle` novo: quica na ponta dos pés e alonga; `team_pose` nova: pulinho para a base aberta, dois puxões na corda, braço ao alto), FK/IK em Python |
| Texturas (cor, normal, ORM) | assadas no Cycles a partir da própria malha (posição, normal, parte, AO) e pintadas em numpy por fórmula (`pv2_tex.py`). Nenhuma imagem de terceiros |

Nenhum modelo, malha, textura, HDRI ou personagem-base baixado ou importado. Paleta da bíblia de estilo (`docs/style-bible.md` §3).
Scripts copiados e adaptados do Rastro v2 (`source_art/characters/rastro_v2/`), sem editar os originais.

## Arquivos
- Fonte: `build_pico_v2.py` (entrada), `pv2_body.py`, `pv2_tex.py`, `pv2_anim.py`, `pv2_render.py`, `render_pico_v2.py`,
  `pv2_check.py` (medições dos pés); `pico_v2.blend` (texturas empacotadas); `pico_v2.info.json` (medidas);
  `pico_v2.check.json` (folga entre as botas por clipe/quadro, deriva e deslize dos pés).
- Saída: `game/assets/models/characters/pico_v2.glb` (glTF 2.0 binário, metros, +Y para cima, PBR metallic-roughness,
  `KHR_materials_clearcoat`, texturas JPEG embutidas).
- Godot: `pico_v2.glb.import` usa `game/lookdev/gltf_pbr_import.gd` (mipmaps nas texturas embutidas e verniz lido do GLB),
  extração de textura desligada, igual ao Rastro v2.

## Reproduzir
```bash
bash tools/blender.sh --background --factory-startup --python source_art/characters/pico_v2/build_pico_v2.py -- \
  --glb $PWD/game/assets/models/characters/pico_v2.glb --blend $PWD/source_art/characters/pico_v2/pico_v2.blend
bash tools/blender.sh --background source_art/characters/pico_v2/pico_v2.blend \
  --python source_art/characters/pico_v2/pv2_check.py -- $PWD/source_art/characters/pico_v2/pico_v2.check.json
bash tools/blender.sh --background source_art/characters/pico_v2/pico_v2.blend \
  --python source_art/characters/pico_v2/render_pico_v2.py -- $PWD/captures/pico_v2
```
O GLB não sai byte a byte idêntico entre exportações (JPEG e ordem interna), mas malha, materiais e medidas sim.
O build completo leva ~8 min na nuvem (4 CPUs; o bake de AO domina).
