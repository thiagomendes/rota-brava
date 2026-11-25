# Procedência do Mundo v2 (RB-R1 W1, vitrine "vila e cais v2") — PROVISÓRIO

Agente: `art3d`. Tudo abaixo é **provisório** até Thiago aprovar. Não substitui o porto do jogo: só a vitrine
`game/lookdev/world_v2/world_v2.tscn` usa estes arquivos. Manifesto: entradas `world_v2_static`, `world_v2_kit`,
`world_v2_boat` e `world_v2_textures` em `source_art/manifest.json` (sha256, triângulos, materiais, origem), escritas pelo próprio build.

## Originalidade
- **Geometria 100% por script** (`bmesh` do Blender e fórmulas próprias): caixas chanfradas, tornos, prismas, tubos,
  esferas deformadas por somas de senos, grades de terreno por função de altura. Nenhum modelo, malha, kit, textura, foto,
  HDRI, scan ou biblioteca de terceiros foi baixado, importado ou usado como base. Sem modelo de imagem.
- **Texturas 100% procedurais** (`wv2_textures.py`, numpy): ruído de valor ladrilhável, células de Voronoi e formas
  analíticas (tábuas, blocos de pedra, paralelepípedos, telha capa, listras de lona, folhas em gota, cascas, corda, rede).
- O mapa parte do layout do projeto (`game/episodes/ep01/world/harbor_layout.json`, `LAYOUT_PROPOSTO.md`) e da paleta da
  `docs/style-bible.md`. Reaproveitados do projeto, sem mudança: `art/sky.gdshader`, `art/water.gdshader`
  (`WaterSurface`, com cores ajustadas só na vitrine), barco `boat_v2` e o trio v2 (`game/lookdev/*_v2_model.tscn`).

## Fontes
| Arquivo | Papel |
|---|---|
| `build_world_v2.py` | ponto de entrada: mapa, cais, cais de pedra, ruas, praça, casas, margem, terreno, dispersão, vistas, percurso, exportação, manifesto |
| `wv2lib.py` | acumulador de malha (Godot -> Blender), primitivas, UV em metros (`box`/`world`/`cyl`/`slope`), cor de vértice |
| `wv2_houses.py` | gerador de casas (fachada com vãos reais, molduras, venezianas, floreiras, sacada, loja com toldo e placa, cunhais, cornijas, telhado com fiadas de telha modeladas, oitões, chaminés) |
| `wv2_kit.py` | kit instanciado (caixotes, barris, rede, boias, cordas, vasos, floreiras, bancos, postes com lanterna, carrinho, placas, café, guarda-sol, barracas, árvores, arbustos, grama, flores, juncos, rochas, botes) |
| `build_boat_wv2.py` | barco do porto v2 (W4): casco em seções (mesma função de casco do `build_boat_v2.py` do RB-04, reescrita com o acabamento novo), cabine com janelas de verdade e interior, convés em tábuas, console e volante, motor, âncora, defensas, cordas; mesmos pontos de encaixe do `boat_v2` |
| `wv2_textures.py` | 18 texturas ladrilháveis (cor JPEG + dados PNG) e os `.import` com mipmaps |
| `render_world_v2.py` | imagens da malha (Workbench, cor de vértice + aramado) em `captures/mundo_v2/blender/` (fora do Git) |
| `wv3_world.py` | E3 (Ep01 v3): farol com patamares/galeria e sala da lanterna, chafariz em 3 degraus + canaleta + grade, anexo do galpão da margem + 2 degraus + galho baixo, placas de fruta, amarra vazia; peças soltas (`wv3_props.glb`) e decalques |
| `wv3_collision.py` | E3: colisão, limites (beira d'água + mapa) e marcadores M0–M8 → `game/worlds/village_v3/village_collision.tscn` e `village_world.tscn` (gerados) |
| `wv3_glb.py` | E3 (peso): compacta o GLB exportado sem extensão (cor de vértice 8 bits, índices 16 bits quando cabem) |
| `world_v2.blend` | fonte salva pelo build (cenário + kit em fila) |

Saídas: `game/assets/models/environment_v2/wv2_static.glb`, `wv2_kit.glb`, `wv2_boat.glb`; `game/assets/textures/environment_v2/*`;
`game/lookdev/world_v2/world_v2_layout.json`; `source_art/environment_v2/world_v2.info.json`.

## Reproduzir
```bash
bash tools/blender.sh --background --factory-startup --python source_art/environment_v2/build_world_v2.py            # tudo
bash tools/blender.sh --background --factory-startup --python source_art/environment_v2/build_world_v2.py -- --no-tex  # sem refazer texturas
bash tools/blender.sh --background --factory-startup --python source_art/environment_v2/build_world_v2.py -- --renders # + imagens da malha
bash tools/godot.sh --headless --path game --import
```
Sementes fixas (`random.seed` e `random.Random(n)` por peça; `numpy.random.default_rng` por textura): duas execuções
seguidas dão GLB com o mesmo sha256 (conferido em 2026-11-25).

## Convenções
- Metros, +Y cima, mesmo referencial do `Ep01Layout` (água em y = −0,4; topo do cais em y = 0). Peças modeladas em
  coordenadas da Godot e convertidas para o Blender (x, −z, y); o glTF devolve as mesmas medidas.
- Materiais `wv2_*` (nome no GLB); a Godot troca cada um por um `ShaderMaterial` de `game/lookdev/world_v2/wv2_materials.gd`.
- Cor de vértice linear (COLOR_0) = tinta da peça; a máscara B da textura de dados decide onde ela tinge.
- A vitrine não tem colisão; o mundo jogável (E3) tem, em `game/worlds/village_v3/` (abaixo). LOD automático da Godot na importação + simplificação por objeto no build (E3).

## Barco v2 (W4) — pontos de encaixe
Pivô no eixo longitudinal a 40% da popa; popa z = +2,0, proa z = −3,0, boca 2,2 m; convés y = 0,40; banco com topo
y = 0,5 em z = 0,6; empties `DeckPoint`, `BenchMark`, `WheelPoint` (0; 1,12; −0,37), `HornPoint`, `PivotMark` iguais aos do
`boat_v2.glb`, mais `RopeBow`, `RopeSternL`, `RopeSternR` (pontos de corda); marca da pata é o objeto `PawMark`
(material `wv2_paw`). Para trocar no jogo falta só a cena com colisão (`StaticBody3D`) e a luz de proa, como em
`game/actors/environment/boat_v2.tscn` (não feito: fora de `game/lookdev/`).

## Provisório / limites conhecidos
- Interiores rasos (0,65 m) atrás de cada janela: paredes, teto, piso de madeira, cortinas, quadro, vaso; ~22% acesos
  (parede do fundo emissiva, forte à noite). Lojas com prateleiras e mercadoria do tipo da loja.
- Grama em tufos de lâminas (MultiMesh) + textura; sem grama em cartão alfa.
- Farol com 3 patamares + galeria desde a E3 (abaixo).

## E3 · Ep01 v3 (RB-R1, art3d, 2026-11-25) — PROVISÓRIO
Mesmas regras de originalidade: tudo por script (`wv3_world.py`, `wv3_collision.py`), decalques por numpy. Um só build
(`build_world_v2.py`) gera o cenário, as peças soltas, os decalques, a colisão, os marcadores e o manifesto.

**Peso (D18, sem Git LFS), medido:**
| Arquivo | Antes | Depois |
|---|---|---|
| `wv2_static.glb` | 13.902.076 B, 273.880 tris | 10.579.376 B, 206.126 tris (com o farol novo e o chafariz novo) |
| `wv2_kit.glb` | 2.019.144 B | 1.741.376 B |
| `wv2_boat.glb` | 657.212 B | 539.792 B |
| texturas `environment_v2/` (36 arquivos) | 18.669.736 B | 7.534.427 B (+ 4 decalques, 67.285 B) |
| `world_v2.blend` | 6.145.684 B | ~5,2 MB |
Como: PNG de dados com filtro adaptativo por linha (sem perda); dados de `plaster`, `stone`, `grass`, `dirt`, `leaf` em meia
resolução (cor continua cheia; cais e calçamento com dados cheios); `MB.lod` por objeto (`wv2_back` 2: sem chanfro ≤ 2 cm e
metade dos lados; rua e praça 1: chanfro em 1 segmento); micro-simplificação em todo o build (chanfro ≤ 1,2 cm em peça ≤ 5 cm
some; esfera ≤ 4,5 cm com 1 subdivisão a menos); cor de vértice em 8 bits no GLB (`wv3_glb.py`). Comparação na mesma tomada:
`captures/e3/peso_antes_depois_{dock,street,plaza,bank}.png` (+ `_detalhe`). JPEG de cor sem mudança.

**Mundo jogável:** `game/worlds/village_v3/village_world.tscn` (script `village_world.gd`: visual da vitrine sem câmera nem
teclas; `set_night`, `set_festival`, `set_beam`, `lantern`, `marker()`, `markers_for()`), `village_collision.tscn`
(Ground, Structures, Props, WaterLimits, MapBounds; camada 1, máscara 0), 54 marcadores M0–M8.
**Barco v2 jogável:** `game/worlds/village_v3/boat_wv2.tscn` (casco + cabine em caixa, `BowLight`, `CabinLight`; nós de encaixe do GLB).
**Peças soltas** (`wv3_props.glb`, origem no pivô): `wv3_lantern` (+ `wv3_lantern_beam`), `wv3_dinghy`, `wv3_buoy_a/b`,
`wv3_festa_boat_1..4` (ícones estrela, lua, peixe, flor), `wv3_festa_lanterns`, `wv3_lens`.
**Decalques:** `decal_paw`, `decal_paw_wet`, `decal_feather`, `decal_scale` (+ cenas em `game/worlds/village_v3/decals/`).
**Materiais novos:** `wv2_paper` (lanterna de papel, `wv2_paper.gdshader`, acende na festa) e `wv2_beam` (`wv2_beam.gdshader`).

Limites conhecidos: `wv2_boat.glb` não é bit a bit reprodutível (mesmo tamanho, sha muda; já era assim antes da E3); demais
saídas conferidas iguais em 2 execuções seguidas. Colisão do terreno em mapa de altura de 1 m (o visual usa 0,5 m).
