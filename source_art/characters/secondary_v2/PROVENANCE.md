# Secundários v2 (RB-R1 G4) · proveniência — PROVISÓRIO

Pedido de Thiago (quarto retorno, 2026-11-26): filhote e capitão "muito mal feitos", bem abaixo do trio Rastro/Pico/Leme
em desenho e textura; Dona Amora parecia criança. Os três foram refeitos no padrão do trio v2 e entram no jogo pelas
mesmas cenas de antes (`game/actors/characters/{captain,pup,amora}_model.tscn`), agora apontando para GLB novos.

## Origem de tudo (100% gerado no projeto)
| Item | Como foi feito |
|---|---|
| Pipeline de textura e material | o do trio, importado só para leitura de `source_art/characters/rastro_v2/rv2_tex.py`: UV Smart Project + pack, mapas de posição/normal/parte/AO assados no Cycles por texel, pintura em numpy por fórmula, normal map tangente da altura (Bump no Cycles), imagens de cor e ORM, Principled com verniz → `KHR_materials_clearcoat`. Pintura nova por tipo (tecido em tafetá, malha, couro, pelo/cabelo com ruído anisotrópico ao longo de um fluxo, pele com rubor) em `sv2_lib.py` |
| Rosto (olhos com dois brilhos, pálpebras, sobrancelhas, boca, 7 expressões, 4 visemas, olhar) | `source_art/scripts/hero_face.py` (o mesmo do trio), materiais de fator do rosto do trio |
| Esqueleto, pesos e clipes | capitão e Dona Amora: 28 ossos do `hero_lib`, clipes do `hero_anim` (capitão) e do `source_art/characters/amora/build_amora.py` (Dona Amora); filhote: 23 ossos, pesos e clipes do `source_art/scripts/pup_build.py`. Tudo importado só para leitura; nomes de nós, ossos e clipes iguais aos de antes |
| Corpo adulto (capitão, Dona Amora) | `sv2_human.py`: cabeça adulta (elipsoide com mandíbula alongada), tronco + mangas numa malha SKIN + SUBSURF 3 com forma em numpy, calça/meia SKIN, mãos de 4 dedos SKIN, sapatos SKIN com sola chanfrada |
| Capitão | quepe por torno (faixa, copa), pala por grade + solidify, cordão por tubo, emblema por prisma; barba, bigode e cabelo por metaballs; gola, lapelas, colarinho, platinas e 6 botões em bmesh; galões, bolsos, abertura, vincos e pespontos pintados |
| Filhote | corpo e pernas numa malha SKIN + SUBSURF 3 (patas assentadas no chão), cabeça por metaballs (crânio + focinho + bochechas), orelhas em concha, nariz, coleira e pingente em bmesh; creme do focinho, mancha do olho, peito, barriga, patas e ponta do rabo pintados |
| Dona Amora | vestido inteiriço (blusa + saia rodada) SKIN, avental por grade projetada na saia + solidify, peitilho, alças, laço, gola, lenço por tubo achatado, coque, amoras e folha; bolinhas de amora, punhos, pregas, pespontos, linhas de sorriso e fios grisalhos pintados |

Nenhum modelo, malha, textura, HDRI ou personagem-base baixado ou importado. Paleta do capitão e do filhote igual à da
geração anterior; Dona Amora segue `game/ui/brand/icons/vendor.svg`.

## Arquivos
- Fonte: `sv2_lib.py`, `sv2_human.py`, `build_captain_v2.py`, `build_pup_v2.py`, `build_amora_v2.py`, `render_sv2.py`,
  `manifest_g4.py`; `<id>_v2.blend` (texturas empacotadas) e `<id>_v2.info.json` (medidas).
- Saída: `game/assets/models/characters/{captain_v2,pup_v2,amora_v2}.glb` (glTF 2.0 binário, metros, +Y para cima, PBR
  metallic-roughness, verniz, texturas JPEG embutidas). `.import` com `game/lookdev/gltf_pbr_import.gd`, como o trio.
- Cenas: `Model` com `metadata/pbr = true` (sem Stylize/contorno, como o trio).
- Os GLB da geração anterior (`captain.glb`, `pup.glb`, `amora.glb`) e suas fontes continuam no disco e no manifesto, sem uso
  no jogo (mesma prática do `rastro.glb`/`pico.glb`/`leme.glb`).

## Reproduzir
```bash
for id in captain pup amora; do
  bash tools/blender.sh --background --factory-startup --python source_art/characters/secondary_v2/build_${id}_v2.py -- \
    --glb $PWD/game/assets/models/characters/${id}_v2.glb --blend $PWD/source_art/characters/secondary_v2/${id}_v2.blend
done
python3 -I source_art/characters/secondary_v2/manifest_g4.py
bash tools/blender.sh --background source_art/characters/secondary_v2/captain_v2.blend \
  --python source_art/characters/secondary_v2/render_sv2.py -- $PWD/captures/g4/blender captain_v2 1.75
```
Texturas intermediárias vão para `captures/g4/build_textures/` (fora do Git); o `.blend` as empacota. O GLB não sai byte a
byte idêntico entre exportações (JPEG e ordem interna), mas malha, materiais e medidas sim.
