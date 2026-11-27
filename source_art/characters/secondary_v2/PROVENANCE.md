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

## Rodada 2 (retorno de Thiago)
- Maos encaixadas na manga (pele do antebraco por dentro da manga, pesos do pulso refeitos) e idle adulto relaxado
  (`sv2_human.py`); calca/meia sem no de juncao.
- Dona Amora com rosto de senhora: `JAW/CHIN/CHEEK` da cabeca adulta por personagem; `mature_face()` afina as sobrancelhas
  e inclina os olhos (~7 graus) aplicando a mesma transformacao em todas as shape keys do rosto gerado pelo `hero_face.py`,
  que nao foi alterado.
- Filhote: pelo curto (tufos, fios, fio fino) na cor e na altura da atlas, fosco.
- Retratos do HUD do capitao e do filhote: `bash tools/blender.sh --background source_art/characters/secondary_v2/<id>_v2.blend
  --python source_art/scripts/hero_portraits_v2.py -- <id>`.

## Rodada 3 (Dona Amora)
- Lenço: tubo cíclico (o anel final liga no inicial; referencial de cada anel pelo raio da cabeça), sem a costura no topo da frente.
- Grisalho: no lugar da faixa lisa #B9B2BC (55–85% da largura, lia como halo), mechas finas pintadas na têmpora e acima da
  orelha, seguindo o penteado puxado para o coque (#A39599, mistura 0,70, só em algumas faixas).
- Calça/meia (também no capitão): as pernas formam uma corrente em U com fundilho baixo, sem nó de bifurcação; fecha o vão
  escuro entre as coxas visto de baixo da barra do casaco.
- GLB: `amora_v2.glb` `4215a7cf6627e316c6ae5aeffdbce718c046e092a13c664ecbee11597cb91749` (23 134 tris),
  `captain_v2.glb` `2c956bac94e0fadb9e1c8f81f429e091719417d441774476f5916fae378805d8` (24 038 tris).
- r3b: Dona Amora sem orelhas modeladas (`EARS = False`; o cabelo puxado as cobre; a orelha furava o cabelo na lateral);
  grisalho em mechas irregulares (duas familias de faixas, uma inclinada que cruza; largura, posicao, comeco e fim
  sorteados por faixa). `amora_v2.glb` `084dfbb49a8f48f76b0f7101cf9b62b3909a15d7167b3522f4e54421541fdd4c` (22 630 tris).

## G21 · Lumi v2 (operador do rádio do Farol 7)
Decisão de Thiago (2026-11-27): homem de uns 30 anos, nome Lumi. Mesmo pipeline do capitão e da Dona Amora
(`sv2_human.py` + `sv2_lib.py` + `rv2_tex.py`), sem contorno, atlas assada em PBR com verniz.
- Fonte: `build_lumi_v2.py`, `lumi_v2.blend`, `lumi_v2.info.json`; provas lado a lado: `render_lineup_g21.py`.
- Silhueta: cabelo crespo curto com o alto arredondado, fone de arco amarelo por cima do cabelo (perfil varrido com raycast
  no cabelo), conchas azuis por torno, haste do microfone coral até o canto da boca (6,5 cm do centro; não cobre a boca),
  antena com bolinha coral na concha direita. Cavanhaque por metaballs colado ao queixo, sombra de barba pintada.
- Roupa: jaqueta 0B2440 com gola amarela (raycast na jaqueta + solidify), emblema do peito por prisma, faixa coral da gola
  ao punho pintada, emblema grande nas costas pintado (escudo por distância com sinal ao contorno), zíper, ribanas e bolsos
  pintados; calça clara; tênis branco com sola amarela.
- Clipes: `idle` (3,6 s, laço, `pose_idle_adult`), `talk` (3,0 s, visemas A/O/E), `wave` (1,6 s, sorriso com olho aberto),
  `point` (1,2 s); sentado (rodada 2, abaixo): `idle_seated` e `turn_chair`.
- Retratos: `bash tools/blender.sh --background source_art/characters/secondary_v2/lumi_v2.blend --python
  source_art/scripts/hero_portraits_v2.py -- lumi` → `game/ui/portraits/lumi_{neutra,alegre,surpresa}.png`.
```bash
bash tools/blender.sh --background --factory-startup --python source_art/characters/secondary_v2/build_lumi_v2.py -- \
  --glb $PWD/game/assets/models/characters/lumi_v2.glb --blend $PWD/source_art/characters/secondary_v2/lumi_v2.blend
bash tools/blender.sh --background --factory-startup --python source_art/characters/secondary_v2/render_lineup_g21.py -- $PWD/captures/g21
python3 -I source_art/farol7_base/manifest_g21.py
```

### G21 rodada 2 (retorno do coordenador)
- Proporção da família do capitão e da Dona Amora: pernas mais curtas e grossas (perna 0,75 m, membro 0,062), tronco e
  ombros com mais volume (tronco 0,52, barriga 0,168, ombro 0,208). Altura 1,715 m, 22 823 tris.
- Calça caqui `#A9844E`; gola em pé trocada por gola baixa canelada pintada com filete amarelo; cavanhaque pequeno e
  arredondado na cor do cabelo (castanho bem escuro `#2A1E18`/`#4E3829`); cabelo fosco (rugosidade ~0,85, verniz 0,02).
- `talk` refeito: braços junto ao corpo, mão direita aberta na altura do peito gesticulando, esquerda solta.
- `wave`/`turn_chair` sorriem pela boca (o `alegre` acima de ~0,3 fecha o olho em arco na Godot: regra G1).
- Clipes sentados para o plano 9a: `idle_seated` (3,6 s, laço) e `turn_chair` (1,0 s), assento a 0,40 m; o Lumi sentado é
  filho de `Chair/Seat` em `farol7_base.tscn` e gira com a cadeira (`Farol7Base.set_chair_yaw`). `idle_seated` entrou em
  `CharacterVisual.LOOPING`.

## G23 · pés encaixados (capitão, Dona Amora, Lumi)
Retorno de Thiago (2026-11-27): o sapato ficava solto da perna, sem tornozelo, com o fundo aparecendo entre a barra e o
sapato. Só geometria por script; rig, pesos por distância e clipes iguais.
- `sv2_human.py`: `shoes(shaft=(z_topo, raio))` sobe um cano por dentro da barra da calça (o cano é a ponta da corrente
  SKIN, sem ramificação no tornozelo); `trousers(ankle_r=...)` continua a perna por um tornozelo mais fino que desce para
  dentro do sapato.
- Capitão: bota de cano (`shaft=(0.125, 0.045)`); Lumi: tênis de cano (`shaft=(0.125, 0.047)`); Dona Amora: meia com
  tornozelo dentro do sapato (`ankle_r=0.040`). Brilho e pintura do sapato iguais (mesma parte `shoe`).
- Medida: `measure_feet_g23.py` (no .blend) e `game/tests/test_feet_gap.gd` (no GLB), mesma conta, todos os quadros de
  todos os clipes: vão perna-sapato antes +35,5 a +39,0 mm no .blend (+37,4 a +41,5 mm no GLB), depois −15,7 a −26,3 mm
  (sobreposição; os dois dão o mesmo número).
- Provas: `render_feet_g23.py` (fila de frente, de lado e de 3/4 e close dos pés) em `captures/g23/` (fora do Git).
- GLB: `captain_v2.glb` `81b3d26d2385e5d56a44cc4fa233a2a6a21267095832202c1b4c2d02d52c22d3` (24 242 tris),
  `amora_v2.glb` `2952973579600daa77a11513d88007b99baba3a75f6bc03cf27d50a8e4a31de8` (22 876 tris),
  `lumi_v2.glb` `f6af8508e3751522477b8b7e0976a50e9c36454b79269a61f1d0de81d9cb3756` (23 027 tris).
```bash
for id in captain amora lumi; do
  bash tools/blender.sh --background --factory-startup --python source_art/characters/secondary_v2/build_${id}_v2.py -- \
    --glb $PWD/game/assets/models/characters/${id}_v2.glb --blend $PWD/source_art/characters/secondary_v2/${id}_v2.blend
  bash tools/blender.sh --background source_art/characters/secondary_v2/${id}_v2.blend \
    --python source_art/characters/secondary_v2/measure_feet_g23.py
done
bash tools/blender.sh --background --factory-startup --python source_art/characters/secondary_v2/render_feet_g23.py -- \
  $PWD/captures/g23 depois_idle
```
