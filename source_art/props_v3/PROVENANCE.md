# Procedência das peças das missões do Ep01 v3 (RB-R1, `art3d`)

Peças finais para o jogo (não são blocos de protótipo). A aprovação estética ainda é de Thiago; por isso o manifesto
marca `status: provisorio`, como todos os ativos do RB-R1. Nas cenas, `metadata/provisional = false` indica que a peça
não é bloco (o mesmo metadado que o `Ep01V3Land` usa nos blocos da E4).

## Originalidade
- **Geometria 100% por script** (`bmesh` do Blender e fórmulas próprias, sobre o `wv2lib.py` do mundo v2): caixas
  chanfradas, tornos, prismas, tubos, esferas, retalhos de esfera, chapas de tecido trianguladas e deslocadas por senos.
  Nenhum modelo, malha, kit, textura, foto, HDRI ou scan de terceiros. Nenhum modelo de imagem.
- **Esqueleto e animação da gaivota por script**: 10 ossos e 5 ações chaveadas por fórmulas (`animate_gull`).
- **Materiais**: os `wv2_*` da vila v2.1 (texturas procedurais do projeto, `wv2_textures.py`) e 5 materiais próprios
  `pv3_*` definidos na Godot (`props_v3_piece.gd`: tecido fosco e vinil sobre a textura `plaster` do projeto, ouro e
  branco com brilho da seta, anel sem luz do pulso).
- **Referências do projeto reaproveitadas**: escudo, faixa e rosa dos ventos de `game/ui/brand/emblem_full.svg` (curvas
  copiadas do SVG do projeto); ícones de fruta iguais aos das placas das barracas (`wv3_world.stall_icons`); cores das
  cargas iguais a `Ep01V3Land.STALL_COLORS`; cores-assinatura dos heróis da `docs/style-bible.md`.

## Arquivos
| Arquivo | Papel |
|---|---|
| `build_props_v3.py` | geometria de todas as peças, esqueleto e ações da gaivota, exportação GLB, `props_v3.blend`, `props_v3.info.json` |
| `render_props_v3.py` | imagens da malha (Workbench, cor de vértice + aramado) em `captures/props_v3/blender/` (fora do Git) |
| `gen_scenes.py` | cenas `.tscn` (metadados, AnimationPlayer) e entradas `props_v3_*` do `source_art/manifest.json` |
| `props_v3.blend` | fonte salva pelo build (uma coleção por peça; ações da gaivota com usuário falso) |
| `props_v3.info.json` | triângulos, orçamento, materiais, pivô, ossos e ações (lido pelo `gen_scenes.py`) |
| `game/assets/models/props_v3/props_v3_piece.gd` | raiz de toda cena: troca de materiais, `play()`, `triangle_count()` |
| `game/assets/models/props_v3/gull.gd`, `tow_rope.gd` | gaivota (loops, peixe no bico) e corda (comprimento, rolo) |
| `game/assets/models/props_v3/props_v3_capture.*` | só capturas (põe as peças na vila na câmera baixa); não é jogo |

## Reproduzir
```bash
bash tools/blender.sh --background --factory-startup --python source_art/props_v3/build_props_v3.py            # GLB + .blend
bash tools/blender.sh --background --factory-startup --python source_art/props_v3/build_props_v3.py -- --renders # + malha
python3 source_art/props_v3/gen_scenes.py        # cenas + manifesto
bash tools/godot.sh --headless --path game --import
bash tools/test.sh props_v3
```
Sementes fixas por peça (`random.seed(1000 + i)`; o `wv2lib` sorteia o deslocamento de UV com o `random` global).
O `bmesh.ops.solidify` dava ordem de faces diferente a cada execução; os tecidos usam `_thicken` (próprio). Duas
execuções seguidas dão os 19 GLB byte a byte iguais (conferido com `cmp` em 2026-11-25).

## Peças
Metros, +Y para cima. Raiz de cada cena na origem com escala 1. Tris = LOD 0 (a Godot gera LODs na importação).

| Cena (`game/assets/models/props_v3/`) | Missão | Pivô | Animações | Tris / orçamento |
|---|---|---|---|---|
| `cloth_tshirt.tscn` camiseta rosa com estrela | M2 | meio da gola, na linha do varal | `sway` (loop), `shake` | 1840 / 2500 |
| `cloth_scarf.tscn` lenço azul de bolinhas | M2 | meio da dobra, na linha | `sway` (loop), `shake` | 1956 / 2500 |
| `cloth_sock.tscn` meia amarela com pelo do filhote | M2 | meio do punho, na linha | `sway` (loop), `shake` | 1300 / 2500 |
| `basket.tscn` cesto de vime | M2 | centro do fundo | — | 3476 / 4000 |
| `fountain_leaves.tscn` tufo que entope a bacia | M3 | centro da base | `rustle` (loop), `pull_out`, `reset` | 1172 / 3000 |
| `ball.tscn` bola do filhote (raio 0,16) | M3 | contato no chão; malha no filho `Spin` | `roll` (loop, rola para +Z), `bounce` | 920 / 1500 |
| `crate_apple/lemon/grapes.tscn` caixotes | M4 | centro do fundo | — | 1404 / 1708 / 1948 de 4500 |
| `fish.tscn` peixe | M5 | meio do corpo; cabeça em +X | `flop` (loop) | 564 / 1500 |
| `gull.tscn` gaivota (+ peixe no bico) | M5 | entre os pés; frente +Z | `perch_idle`, `fly`, `glide` (loops), `land` 1,2 s, `flee` 1,0 s | 3564 + 564 / 6000 |
| `tow_rope.tscn` corda de reboque | M6 | início da corda; vai para +Z | — (`length`, `coiled`) | 2144 / 2500 |
| `emblem_paw/carabiner/helm/compass/star.tscn` | geral | chão; moeda no filho `Coin` a 0,75 m | `spin` (loop), `collect` | 1992 a 2920 / 3000 |
| `help_arrow.tscn` seta de ajuda | geral | ponta da seta | `point` (loop), `appear` | 232 / 600 |
| `target_ring.tscn` pulso do alvo | geral | centro, no chão | `pulse` (loop) | 176 / 400 |

Metadados na raiz: `piece_id`, `mission`, `interactive`, `interaction` (verbo), `member` (herói), `tris`,
`tris_budget`, `pivot`, `note`; caixotes também `stall`, `fruit`, `color`; emblemas `icon`.

**Gaivota:** ossos `root body head tail wing_in_L/R wing_out_L/R leg_L/R`. `land` desce 0,9 m e avança 0,7 m até o
pivô; `flee` agacha, sobe 1,1 m e avança 0,8 m para +Z (deslocamento no osso `root`; o caminho no mapa é do jogo).
O peixe fica em `Model/gull_rig/Skeleton3D/BeakSocket/FishHold/Fish` (segue a cabeça); `carrying_fish = false` esconde.

**Corda:** `length` escala só o trecho `pv3_rope_span` (1 m em +Z) e leva a alça do fim e o marcador `End`; `coiled`
mostra só o rolo.

**M7 (lente):** não refeita. A `wv3_lens` da E3 (aro de latão, vidro, alça) serve; na captura `m7_lente_e3.png` ela aparece
meio tapada pelos arbustos do promontório (posição do mundo, não da peça).

## G6 (RB-R1, 2026-11-26)
- Caixotes do M4 (`crate_*`): fundo falso de palha a 5 cm da borda; as frutas pousam nele (antes ficavam 21 cm acima do
  fundo, soltas). Mesma medida externa. Achado por `bash tools/prop-overlap.sh`.

## G18 (RB-R1, 2026-11-27)
- Cesto (`basket`): a toalha solta a 17,5 cm do fundo virou uma pilha de 3 toalhas dobradas apoiada no fundo (topo a
  0,195 m, onde as roupas soltas do M2 deitam no jogo). 3260 -> 3476 tris. Achado por `test_prop_overlap` (parte solta
  de 13,1 cm) quando o cesto entrou no M2 pela primeira vez. Roupas (`cloth_*`) sem mudanca: o pivo ja era a boca do
  prendedor; o erro estava no jogo (vagas fora da corda).

## Limites conhecidos
- Tecidos são chapas rígidas (balançam inteiros no `sway`, sem simulação de pano).
- Asa recolhida da gaivota é rotação rígida: a face de baixo (cinza-claro) fica para fora.
- Emblema com o mosquetão lê como um "0" com barra a distância.
