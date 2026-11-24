# RB-R1 — Heróis (art3d): evidências

Status: **PROVISÓRIO**, aguardando o Portão 1 (Thiago). Toda a geometria vem de scripts do projeto (SKIN + SUBSURF, metaballs, torno, bmesh). Nada foi baixado ou importado.

## Fontes
- `source_art/scripts/hero_lib.py`: proporções A/B/C, corpo, uniforme com emblema, equipamento, rig (28 ossos + ponteiras do RB-04) e pesos.
- `hero_face.py`: rosto, com expressões, visemas `mouth_A/E/O/M` e olhar `look_left/right/up`.
- `hero_anim.py`: os 12 clipes.
- `hero_build.py`: Rastro final na variação A → `characters/heroes/rastro/rastro.blend` e `game/assets/models/characters/rastro.glb`.
- `hero_studies.py`, `hero_render.py` e `hero_review.py`: pranchas (Eevee toon, contorno por Solidify invertido) em `captures/rb-r1/herois/`, que fica fora do Git. O estudo do trio está salvo em `source_art/studies/heroes/trio_A.blend`.
- Para regenerar: `./tools/export-assets.ps1`.

## Medidas (Godot, `test_characters.gd`)
| Medida | Valor |
|---|---|
| Altura | 1,140 m |
| Cabeça | 0,420 m (36,9% da altura) |
| Olho | 30,6% da altura da cabeça (valor do Blender) |
| Triângulos | 19 204 |
| `walk` | pés a ±2 cm em 100% dos quadros (pior caso 0,7 mm); deslize de 0,014 m/s a 0,448 m/s |
| `run` | pés a ±2 cm em 100% dos quadros (pior caso 12,1 mm); deslize de 0,053 m/s a 0,952 m/s |

**Mão na PawMark real**
- Montagem do teste: `BoatActor` (boat_v2) em `BOAT_DOCKED_POS`/`HEADING`, com o Rastro embarcado em `Ep01Layout.PAW_INSPECT_STAND_LOCAL`.
- Resultado: a ponta da mão fica a 31,4 mm do centro da malha `PawMark` (0,6; 0,504; -5,0).
- A ponta nunca desce abaixo de 0,525 m; o topo do banco está a 0,500 m.

## Mudança de jogo para o defeito herdado
Do cais (`BENCH_INTERACT_POS`) até o banco do barco atracado há cerca de 2,6 m e um trecho de água. Daí, a mão de nenhuma criança alcança a pata.

Como foi resolvido:
- `dock_stage._act_examine` (só para a pata) faz o Rastro embarcar brevemente com `MemberActor.ride_briefly`.
- Ele fica no ponto `PAW_INSPECT_STAND_LOCAL` = (0,08; 0,41; 0,16) do barco, de frente para +Z do barco.
- Toca a marca e, ao fim do clipe, volta ao ponto do cais (`dismount`). Um `teleport` também encerra o embarque.
