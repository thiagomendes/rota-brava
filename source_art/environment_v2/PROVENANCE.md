# Procedência do Mundo v2 (RB-R1 W1, vitrine "vila e cais v2") — PROVISÓRIO

Agente: `art3d`. Tudo abaixo é **provisório** até Thiago aprovar. Não substitui o porto do jogo: só a vitrine
`game/lookdev/world_v2/world_v2.tscn` usa estes arquivos. Manifesto: entradas `world_v2_static`, `world_v2_kit` e
`world_v2_textures` em `source_art/manifest.json` (sha256, triângulos, materiais, origem), escritas pelo próprio build.

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
| `wv2_textures.py` | 17 texturas ladrilháveis (cor JPEG + dados PNG) e os `.import` com mipmaps |
| `render_world_v2.py` | imagens da malha (Workbench, cor de vértice + aramado) em `captures/mundo_v2/blender/` (fora do Git) |
| `world_v2.blend` | fonte salva pelo build (cenário + kit em fila) |

Saídas: `game/assets/models/environment_v2/wv2_static.glb`, `wv2_kit.glb`; `game/assets/textures/environment_v2/*`;
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

## Provisório / limites conhecidos
- Barco ainda é o `boat_v2` do RB-04 com os materiais do lookdev (não refeito nesta etapa).
- Interiores não modelados: janelas são vidro escuro com reflexo; ~18% "acesas" com brilho quente leve.
- Grama em tufos de lâminas (MultiMesh) + textura; sem grama em cartão alfa.
