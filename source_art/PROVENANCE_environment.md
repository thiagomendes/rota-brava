# Proveniencia do ambiente do primeiro minuto (RB-04-env) — PROVISORIO

Agente: `art3d`. Tudo abaixo e **provisorio** ate Thiago aprovar. Manifesto: `source_art/manifest_environment.json`
(gerado por `tools/export-environment.ps1`; sha256 do GLB, triangulos, materiais, origem, data).

## Originalidade
- Toda geometria vem de scripts Blender versionados em `source_art/environment/` (bmesh + modificadores Bevel,
  Subdivision Surface com creases, Solidify, Wireframe). Nenhum modelo, malha, kit, textura, HDRI ou biblioteca de terceiros
  foi baixado, importado ou consultado como base. Nao ha texturas: so cores de material do projeto (`mat_env_*`) e
  cor por vertice (variacao por objeto e AO por altura, pintadas pelos scripts).
- O barco v2 parte do **conceito e das proporcoes** de `source_art/vehicles/boat` (RB-03, tambem do projeto): a funcao de
  casco (secoes) foi reescrita em `build_boat_v2.py`; o resto do barco e novo.
- Ferramentas: Blender 4.5.16 LTS (`tools/blender.ps1`), Godot da `tools/toolchain.json`.

## Fontes
| Script | .blend | GLB (game/assets/models/environment/) |
|---|---|---|
| `build_dock.py` | `dock_kit.blend` | dock_deck_2m, dock_deck_4m, dock_post, dock_cleat, dock_fender, dock_ladder, dock_edge, dock_pile |
| `build_props.py` | `props.blend` | crate_l, crate_s, crate_peach, barrel, rope_coil, lantern_post, fishing_net, sign_board, bucket, oar, cork_buoy, boat_hut, boot_print |
| `build_nature.py` | `nature.blend` | ground_tile_a/b/path, tree_a/b/c, bush_round, bush_flower, grass_tuft, reeds, rock_a/b/c |
| `build_boat_v2.py` | `boat_v2.blend` | boat_v2 |

Biblioteca comum: `envlib.py` (usa `source_art/scripts/rbart.py` do RB-03). Conferencia visual: `render_env.py`.

## Convencoes
- Metros, +Y cima. Pecas modeladas em coordenadas da Godot e convertidas para Blender (x, -z, y); o glTF devolve as mesmas medidas.
- Cais: topo do deck em y = 0; origem do modulo no centro do topo. Barco: proa em -Z, pivo a 40% do comprimento a partir da popa
  (popa z = +2,0; proa z = -3,0), banco em `Ep01Layout.BENCH_LOCAL` (topo y = 0,5), empties `DeckPoint`, `BenchMark`, `WheelPoint`,
  `HornPoint`, `PivotMark`; marca da pata = objeto `PawMark` (`mat_env_paw`).
- Cor por vertice (COLOR_0): o Godot so a usa como albedo com o pos-importador `game/assets/models/environment/vertex_color_postimport.gd`
  (ligado em cada `*.glb.import`; `tools/export-environment.ps1 -Scenes` faz isso).
- Colisao nunca vai dentro do GLB: cenas `game/actors/environment/*.tscn` (geradas por `gen_env_scenes.gd`) trazem `StaticBody3D` simples.

## Reproduzir
`./tools/export-environment.ps1 -Scenes` (Blender headless -> .blend + GLB + manifesto; reimporta e regenera as cenas).
`-Images` gera renders de conferencia em `captures/rb-04/env` (fora do Git).

## RB-R1-mundo (vila Farol 7) - PROVISORIO
- Kit da vila: `source_art/environment/build_village.py` -> `village_kit.blend` + 27 GLB (casas A-D, barracas, poste, banco, canteiro, tufo de flores, cerca, escada, muro, cais de pedra, praca, gramado, arrimo, farol, morros, nuvem, gaivota, arvores, barquinho, bandeirolas). Geometria 100% procedural (bmesh, Bevel, Solidify); nada baixado.
- Paleta nova (docs/style-bible.md sec. 5) aplicada tambem em `envlib.py` (madeira desbotada, folhagem, rochas, cabana) e no chao de `build_nature.py`: os GLB do cais/adercos/natureza do RB-04 foram regenerados com as cores novas (mesma geometria).
- Layout: `source_art/environment/village_layout.py` (fonte unica) -> `game/episodes/ep01/world/harbor_layout.json` -> `gen_harbor_slice.gd` -> `harbor_slice.tscn`.
- Estudos de direcao: `source_art/studies/world/study_village.py` (Eevee; importa os GLB do proprio projeto). Renders em `captures/rb-r1/mundo/` (fora do Git).
- Personagem-escala dos estudos e da preview: cilindro/capsula de 1,10 m, NAO e o heroi.

## RB-R1-mundo etapa 2 (rio, ilha, horizonte, margem sul) - PROVISORIO
- `source_art/environment/build_world.py` -> `world_kit.blend` + 18 GLB (terrenos por SDF em coordenadas do mundo, ponte, cerca rustica, palmeira, barraca, fogueira, bandeira, rochas seguras/iscas, rochedo, concha, pier, gaivota pousada). `world_layout.py` -> `game/episodes/ep01/world/{river,island,horizon}_layout.json` -> `gen_world_scenes.gd`.
- Margem sul: `build_nature.py` (ladrilhos amostram a margem do mundo + `Bank_Path`). Tudo procedural, nada baixado.
- Capturas: `source_art/studies/world/capture-world.ps1` (Movie Maker em `preview_world.tscn`) -> `captures/rb-r1/mundo/` (fora do Git).
