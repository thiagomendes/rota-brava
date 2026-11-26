# Dona Amora · proveniência (RB-R1, arte das cenas) — PROVISÓRIA

Feirante da vila (falas `ep01.market.vendor.*`), parada atrás da barraca azul das uvas (marcador `M4_Vendor`,
(-18,1; 0; -6,4), virada para o cliente em -X). Aprovação estética: Thiago (pendente).

## Conceito
- Senhora calorosa, coerente com o retrato SVG da E7 `game/ui/brand/icons/vendor.svg`: vestido roxo `#7A3E9D`,
  avental branco `#F7FBFF` com bolinhas de amora `#4A2370` em cachos de 4, cabelo `#5A2E3A` em **coque no alto**,
  **lenço roxo** passado por cima da cabeça e amarrado na nuca (laço e duas pontas) com **três amoras e uma folha**
  `#3DBE5A` do lado esquerdo, pele `#D9976A`, bochechas rosadas.
- Saia rodada até o meio da canela com pregas leves na barra, avental com peitilho, bolso com uma amora, alças até a
  nuca e laço nas costas; gola redonda e punhos brancos; sapatos marrons.
- Proporção adulta "EL" do construtor da vila (cabeça ~27% da altura), altura 1,56 m.
- **Acabamento vinil** dos heróis v2: Principled com verniz (`Coat`) por cor, exportado como `KHR_materials_clearcoat`;
  sem textura assada (os v2 têm trama e pespontos assados; a Amora não). Cena marcada `metadata/pbr = true`.

## Origem (100% gerado no projeto)
| Item | Como |
|---|---|
| Corpo, mãos, cabeça, cabelo curto, rosto (olhos, pálpebras, boca, visemas, olhar), rig de 28 ossos, pesos | `source_art/scripts/hero_lib.py` (`Builder`, proporção `EL`) e `hero_face.py`, os mesmos dos adultos da vila |
| Coque, lenço, amoras, folha | elipsoides, toro e tubos `bmesh` em `build_amora.py`; a faixa do lenço é um tubo fechado projetado no elipsoide da cabeça e achatado |
| Saia | torno (`char_lib.lathe`) com raio por altura e pregas por seno na barra |
| Avental e peitilho | grades `bmesh` sobre a saia (mesma função de raio) e sobre a blusa (raycast `snap_y`), com `bmesh.ops.solidify` |
| Clipes | `idle` (3,6 s, loop), `wave` (1,6 s), `thanks` (2,0 s), `point` (1,2 s), `talk` (3,0 s, visemas A/O/E animados) — FK/IK em Python (`hero_anim` + poses próprias) |

Nenhum modelo, malha, textura, HDRI, rig, mocap ou personagem-base de terceiros. Nenhum modelo de imagem.

## Números (de `amora.info.json`)
- 22 574 triângulos (heróis v2: 24 229 a 24 944); 27 objetos; 28 ossos; 15 shape keys do rosto.
- `talk` começa e termina na mesma pose (pode repetir sem salto). O loop no jogo vem de `CharacterVisual.LOOPING`,
  que hoje não lista `talk` (ligação do `gameplay`).

## Arquivos e sha256
| Arquivo | sha256 |
|---|---|
| `game/assets/models/characters/amora.glb` | `85f0a93ec3e9ee0a31b3a24a7d1275fe9c0580e632ce7ee2d7fd53178b68b7b1` (também no manifesto, entrada `amora`) |
| `source_art/characters/amora/amora.blend` | `6c7d0f0b4839c3173909a064474648273254917fb060c1ced00f26751bf81f91` |
| `source_art/characters/amora/amora.info.json` | `3aab4173489ebd2ebad0cbd60f67fd3484b8c444abfb6234514f1840a2d279bd` |
| `source_art/characters/amora/build_amora.py` | script (versionado) |

## Reproduzir
```bash
bash tools/blender.sh --background --factory-startup --python source_art/characters/amora/build_amora.py -- \
  --blend $PWD/source_art/characters/amora/amora.blend --glb $PWD/game/assets/models/characters/amora.glb
python3 -I source_art/scripts/manifest_arte_cenas.py          # sha256 e medidas no manifesto
bash tools/blender.sh --background source_art/characters/amora/amora.blend --python source_art/scripts/render_arte_cenas.py -- \
  $PWD/captures/arte_cenas/blender amora --target 0,0,0.78 --dist 4.4 --turn --wire
```
Como nos outros personagens, os bytes do GLB podem mudar entre exportações; malha, nomes e medidas não.
