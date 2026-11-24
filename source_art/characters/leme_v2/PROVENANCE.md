# Leme v2 · proveniência (RB-R1 D11/D13) — PROPOSTA PROVISÓRIA

Heroína piloto (9 anos, a mais velha e calma) para aprovação de Thiago num visualizador 3D. **Não substitui** a Leme do
jogo (`game/assets/models/characters/leme.glb` continua em uso); aparece só na vitrine `game/lookdev/` (modo `after`,
via `game/lookdev/leme_v2_model.tscn`).

## Conceito do traje (D13: distinta do Rastro e do Pico)
- **Silhueta:** boné náutico de capitania (copa branca alta, mais larga em cima, faixa azul-marinho, pala envernizada,
  cordão dourado, emblema da equipe na frente) + cabelo cacheado com volume nas laterais e um **puff grande atrás**;
  colete salva-vidas com **gola-travesseiro em ferradura** atrás do pescoço.
- **Traje:** camisa de capitania branca de **manga curta** (vivo azul, carcela com botões no decote), **colete salva-vidas
  azul** de placas de espuma (abertura na frente, canais costurados, duas faixas refletivas, vivo branco, tira com fivela de
  engate, laterais abertas com tiras, apito no cordão, estrela branca nas costas), **bermuda azul** (faixa lateral branca,
  bolsos com pesponto, barra dobrada), **meias de meio cano** brancas com duas listras azuis, **botinas náuticas** azul-marinho
  com sola branca grossa, friso azul, cadarço e ilhoses.
- **Equipamento:** bússola de pulso (esquerda: aro dourado, mostrador com rosa dos ventos, agulha, cúpula de vidro) e
  pulseira de corda trançada azul e branca (direita).
- **Comum da equipe:** emblema da Rota Brava no peito (placa esquerda do colete) e cinto azul-marinho com fivela-bússola dourada.
- **Pele e cabelo:** pele marrom-escura quente (#8C5634; Rastro #C98B60, Pico #F3C9A2), palmas mais claras; cachos quase pretos.
- **Pernas em leve "A"** (quadril ±0,073 m, tornozelos ±0,092 m): as botinas ficam separadas em todos os quadros.

## Origem de tudo (100% gerado no projeto)
| Item | Como foi feito |
|---|---|
| Corpo inteiriço (tronco + braços + pernas numa malha só) | grafo de pele (SKIN) + SUBSURF 3, ombro/cotovelo/joelho/panturrilha deslocados em numpy, Decimate por colapso; depois cortado por planos exatos em camisa, bermuda, pele (braço e joelho) e meia, com bordas coincidentes cobertas por vivos/barras modelados (`lv2_body.split_body`) |
| Colete salva-vidas | superfície paramétrica (θ, z) projetada no corpo por raycast em BVH, espessura com borda arredondada e canais modelados, vivo (borda) até o corpo; gola-travesseiro por SKIN |
| Mãos de 4 dedos (pele, relaxadas), botinas, sola, cadarço | SKIN + SUBSURF, palma achatada em numpy; sola pelo contorno medido da própria bota; cadarço/ilhoses por tubos e toros sobre a bota (raycast) |
| Boné, cinto, fivela, emblema, bússola, pulseira, apito | torno (lathe), toros, tubos, prismas e caixas arredondadas em bmesh |
| Cabeça, rosto (olhos com dois brilhos, pálpebras, sobrancelhas, boca, visemas, olhar), esqueleto de 28 ossos | biblioteca dos heróis: `source_art/scripts/hero_lib.py`, `hero_face.py` (pernas do esqueleto em leve A) |
| Cabelo | metaballs (calota, três anéis de cachos, puff com cachos na superfície), cabelo escondido dentro do boné removido |
| Animações (12 clipes, os MESMOS nomes do `leme.glb`) | `source_art/scripts/hero_anim.py` + `lv2_anim.py` (idle, team_pose e wave novos), FK/IK em Python |
| Texturas (cor, normal, ORM) | assadas no Cycles a partir da própria malha (posição, normal, parte, AO) e pintadas em numpy: algodão, sarja, canelado, nailon ripstop, faixas refletivas, pespontos, bolsos, botões, cachos em hélice, palmas (`lv2_tex.py`). Nenhuma imagem de terceiros |

Nenhum modelo, malha, textura, HDRI ou personagem-base baixado ou importado. Paleta da bíblia de estilo (`docs/style-bible.md` §3).

## Medidas (Blender, `leme_v2.info.json`)
- 24.674 triângulos; altura 1,131 m (com o boné); cabeça 35,5% da altura; olho 29,3% da cabeça; 28 ossos; 12 clipes.
- **Botas nunca se tocam:** menor distância entre as malhas das duas botinas (sola, cano, cadarço, ilhoses), vértice→superfície
  nos dois sentidos, em todos os quadros dos 12 clipes = **5,22 cm** (pose parada; walk 6,89 cm, run 7,36 cm).
- Pés plantados: no walk/run, vértices da sola em contato recuam à velocidade nominal com erro médio 0,006/0,004 m/s
  (máx. 0,060/0,018 m/s); a sola afunda no máximo 4 mm no chão ao rolar o pé.
- Mãos no volante (`idle_wheel`): ponto médio das mãos a 1,0 cm do centro do volante.

## Arquivos
- Fonte: `build_leme_v2.py` (entrada), `lv2_body.py`, `lv2_tex.py`, `lv2_anim.py`, `lv2_render.py`, `render_leme_v2.py`;
  `leme_v2.blend` (texturas empacotadas); `leme_v2.info.json` (medidas, inclusive folga das botas por clipe e deslize).
- Saída: `game/assets/models/characters/leme_v2.glb` (glTF 2.0 binário, metros, +Y para cima, PBR metallic-roughness,
  `KHR_materials_clearcoat`, texturas JPEG embutidas).
- Godot: `leme_v2.glb.import` igual ao do `rastro_v2` (pós-importação `game/lookdev/gltf_pbr_import.gd`, extração de
  material desligada); cena `game/lookdev/leme_v2_model.tscn`.

## Reproduzir
```bash
bash tools/blender.sh --background --factory-startup --python source_art/characters/leme_v2/build_leme_v2.py -- \
  --glb $PWD/game/assets/models/characters/leme_v2.glb --blend $PWD/source_art/characters/leme_v2/leme_v2.blend
bash tools/blender.sh --background source_art/characters/leme_v2/leme_v2.blend \
  --python source_art/characters/leme_v2/render_leme_v2.py -- $PWD/captures/leme_v2
```
O GLB não sai byte a byte idêntico entre exportações (JPEG e ordem interna), mas malha, materiais e medidas sim.
