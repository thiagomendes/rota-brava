# Procedência das pistas F2 do Ep01 v3 (RB-R1, `art3d`, 2026-11-25)

Origem: auditoria `docs/proposals/ep01_v3_roteiro_intuitivo.md` (padrão "Ver, ouvir, seguir", P1): a bota do M1 não
existia, as pegadas de 0,24 m sumiam na terra marrom e não havia nada no lugar do M1.bench. Peças finais (não são bloco):
nas cenas `metadata/provisional = false`; no manifesto `status: provisorio` como todo o RB-R1 (aprovação estética de Thiago).

## Originalidade
- **Geometria 100% por script** (`bmesh` do Blender e fórmulas próprias, sobre `wv2lib.py` e as utilidades de
  `source_art/props_v3/build_props_v3.py`). Nenhum modelo, malha, kit, textura, foto, HDRI ou scan de terceiros.
- **Decalques 100% por fórmula** (`gen_decals.py`: campos de distância de elipses e polígonos em numpy; PNG escrito pelo
  `wv2_textures.write_png_rgba` do projeto). Forma da pata igual à dos decalques da E3 (`wv3_world.decals()`), ampliada.
  Nenhuma imagem de terceiros; sem modelo de imagem.
- **Cores**: paleta do capitão em `source_art/scripts/hero_lib.py` (botas, azul do uniforme, creme, ouro) e creme da marca
  (`docs/style-bible.md`).

## Arquivos
| Arquivo | Papel |
|---|---|
| `build_clues_v3.py` | bota, pena 3D e pilar de luz; GLB em `game/assets/models/props_v3/`, `clues_v3.blend`, `clues_v3.info.json`; `--renders` = imagem da malha |
| `gen_decals.py` | 6 decalques grandes (albedo + emissão) em `game/worlds/village_v3/decals/tex/`, `decals_v3.info.json` |
| `gen_scenes_clues.py` | cenas `.tscn` das 3 peças e dos 6 decalques; entradas `clues_v3_*` do `source_art/manifest.json` |
| `game/assets/models/props_v3/props_v3_piece.gd` | ganhou o material `pv3_beam` (aditivo, sem luz, sem sombra) |
| `game/assets/models/props_v3/clues_v3_capture.*` | só capturas de legibilidade (não é jogo) |
| `game/tests/test_clues_v3.gd` | teste das peças e decalques |

## Reproduzir
```bash
bash tools/blender.sh --background --factory-startup --python source_art/clues_v3/build_clues_v3.py [-- --renders]
python3 source_art/clues_v3/gen_decals.py
python3 source_art/clues_v3/gen_scenes_clues.py
bash tools/godot.sh --headless --path game --import
bash tools/test.sh clues_v3
```
Sementes fixas (`random.seed(5000 + i)`; respingos `default_rng(7)`). PNG dos decalques iguais byte a byte entre
execuções (conferido com md5sum).

## Peças (metros, +Y para cima, raiz na origem)
| Cena | Missão | Pivô / frente | Tris / orçamento |
|---|---|---|---|
| `props_v3/captain_boot.tscn` galocha do capitão caída de lado (couro marrom, sola e biqueira creme, dobra branca, listra azul, fivela dourada), 0,68 × 0,48 × 0,76 m (escala de desenho 1,45×: a 0,5 m virava um ponto a 8 m) | M1.boot | centro do contato no chão | 2816 / 3500 |
| `props_v3/feather.tscn` pena de gaivota 0,5 m, branca com ponta escura, animação `flutter` (loop); opcional ao decalque | M5 | meio da raque; ponta para −Z | 832 / 1600 |
| `props_v3/target_ring_tall.tscn` anel do chão + anel a 0,55 m + pilar de luz 1,9 m, `pulse` (loop) | geral | centro, no chão | 736 / 1000 (usa `target_ring.glb` 2× + `target_beam.glb`) |

## Decalques (`game/worlds/village_v3/decals/`, raiz `Decal`, tris 0)
Desenho em 3 camadas: miolo (cor da pista) → halo creme → aro escuro fino. O halo separa a pista de piso escuro (terra,
grama, madeira na sombra); o aro separa o halo de piso claro (pedra, madeira clara). Emissão só no halo/realces (noite).
Frente = −Z da cena (dedos, ponta da pena, bico da bota).

| Cena | Missão | Caixa (m) | Visível (m) |
|---|---|---|---|
| `decal_paw_big` pata seca (lama) | M1 / trilhas | 0,60 | ~0,45 |
| `decal_paw_wet_big` pata molhada com gotas | M2 | 0,60 | ~0,55 |
| `decal_paw_dock` pata de lama com respingos (tábua do cais, M1.bench) | M1 | 0,66 | ~0,59 |
| `decal_feather_big` pena | M5 | 0,60 | 0,29 × 0,58 |
| `decal_boot_print_l` / `_r` sola da bota do capitão | M1 | 0,28 × 0,56 | 0,27 × 0,54 |

Os antigos (`decal_paw`, `decal_paw_wet`, `decal_feather`, `decal_scale`) ficam como estavam.

## Provas de legibilidade (`captures/f2_arte/`, fora do Git)
`res://assets/models/props_v3/clues_v3_capture.tscn -- --cv3-view=<boot8|boot4|bench|floor_dirt|floor_grass|floor_stone|floor_wood|feather|ring_grass> [--cv3-night]`
(camera baixa: 1,95 m sobre o chão, 12° para baixo, FOV 50; Vulkan por software, 1280×720).

## Limites conhecidos
- Grama alta: os decalques são projetados no chão e o capim alto tapa boa parte (`floor_grass_dia.png`); a pata grande
  e a pegada de bota ainda aparecem entre as folhas, a antiga some. Melhor pôr as trilhas no caminho de terra/tábua/pedra.
- A bota deitada lê como bota a 4 m; a 8 m lê como objeto escuro com sola e dobra claras (não como silhueta em "L").
- A pena 3D é branca sobre pedra clara: lê menos que o decalque (que tem aro escuro). Escolha: decalque como pista
  principal; a pena 3D é opcional (perto da câmera ou em piso escuro).
- O `.blend` muda a cada build (como o do props v3); os GLB e PNG não.
