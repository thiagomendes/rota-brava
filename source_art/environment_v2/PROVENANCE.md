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
- Sem colisão (é vitrine). Sem LOD manual (a Godot gera LOD na importação).

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
- Farol sem escada externa (pedida na proposta de missões v3, M7): fica para a implementação.
