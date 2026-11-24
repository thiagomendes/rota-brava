# RB-R1 — Mapa proposto do Episódio 01 (art3d) — PROVISÓRIO

Status: **proposta para o lead e para Thiago (Portão 1)**. Nada aqui altera `ep01_layout.gd`; a integração é do lead.
Unidades: metros, mesmo referencial do `Ep01Layout` (+X leste, +Z sul, +Y cima, água em y = −0,4).
Diagrama de cima: `captures/rb-r1/mundo/mapa_topo.png` (render ortográfico do Blender, `study_village.py --comp MAP`; esquemático: margens em blocos, rótulos aproximados).

## 1. Composição recomendada: **B — vila na orla**
Estudos: `captures/rb-r1/mundo/vila_A.png`, `vila_A_aberto.png`, `vila_B.png`, `vila_B_aberto.png` (Eevee, câmera de jogo FOV 55, alvo no cais, offset (0; 4,6; 6,2), olhar +1 m).

Por que B:
1. **A câmera do cais olha quase na horizontal no topo do quadro** (raio superior a ~2,6° abaixo do horizonte). Tudo que fica além de ~15 m só aparece até ~4 m de altura. Na A, os terraços da encosta ficam **fora do quadro** do jogo; o que se vê é a mesma fileira de térreos, sem as barracas. Na B, o cais norte tem **barracas listradas, bandeirolas, flores, bancos, postes e portas** exatamente na faixa que a câmera mostra: o fundo do quadro fica cheio e vivo.
2. **Caminhável sem degraus**: a rua do mercado fica em y = 0 (como o cais), boa para criança e para a colisão; a segunda fileira em terraço baixo (+1,2 m) dá variação de telhados no plano aberto sem obrigar escadas no caminho jogável.
3. **Marco**: o farol na ponta leste da baía, na boca do rio, fica no caminho de quem sai de barco e aparece em todos os planos abertos.
A composição A rende um plano aberto mais "cartão-postal" (casario em encosta); pode voltar como fundo (morro atrás da segunda fileira), sem mudar a rua da orla.

## 2. Mapa completo (tamanho final)
| Região | Coordenadas (m) | Observação |
|---|---|---|
| Cais de madeira (atual) | x −8..8, z −3..3, topo y 0 | sem mudança (`DOCK_*`) |
| Barco atracado | (0, 0, −5), rumo π/2 | sem mudança |
| Margem sul (atual) | x −10..10, z 3..16 | sem mudança; pegada em (−6, 0, 10) |
| Bacia do porto | x −14..26, z −3..−13 | água; 4 barquinhos ancorados |
| Cais de pedra norte (rua do mercado) | x −22..26, z −13..−19, topo y 0 | meio-fio de 18 cm na borda da água; 3 barracas; postes a cada 8 m |
| Fileira 1 (orla) | 7 casas, centros z −18,7, x −12,4..17,4 | fachadas para o sul (para a câmera) |
| Terraço + fileira 2 | arrimo em z −23 (topo y 1,2); 5 casas em z −27 | só fundo; acesso futuro por escada |
| Cais de pedra oeste | x −20..−14, z −13..11 | liga a margem sul à rua do mercado |
| Praça do mercado | x −38..−22, z −16..8 | 4 casas viradas para o leste, canteiro, banco, árvores |
| Ligação margem sul → cais oeste | x −14..−10, z 3..11 | gramado |
| **Farol 7** | (31, 2,4, −24), altura 19,8 m (topo y ≈ 22) | promontório na boca do rio; visível de todo o mapa nos planos abertos |
| Rio | x 30..182, corredor z −14..14 (**152 m**) | margens vegetadas (árvores/arbustos a cada ~5 m nas margens z ±16..30) |
| Ponte (pedestre, arco) | x 60..64, sobre z −16..16, vão livre ≥ 3,6 m | a modelar (kit ainda não tem ponte) |
| Boia | (90, 0, −3), raio 5 | era `BUOY_POS` (40, 0, −3) |
| Banco de areia | x 112..126, z 3..9 | o barco passa ao norte |
| Enseada | centro (166, 0, 21), raio 8 (margem sul recortada x 158..174, z 14..28) | era `ENSEADA_POS` (88, 0, 12) |
| Braço do rio | entre a margem oeste x 182 e a ilha x 190, z −14..20 | era x 92..100 |
| Ilha | x 190..212, z −14..16; centro (198, 0, 0) | era `ISLAND_POS` (108, 0, 0) |
| Acampamento do piloto | (195, 0, 3) | era `PILOT_CAPTAIN_POS` (105, 0, 3) |
| Travessia de rochas | âncoras (182, 1,2, 4) → (190, 1,2, 4); apoios (183,5; 0,3; 6,5), (186; 0,5; 5), (188,5; 0,3; 4,2) | +90 m em x sobre os atuais |
| Atracadouro da ilha | `PIER_POS` (190,5, 0, −2); alvo (187, 0, −2); entrada do braço pelo norte (185,5, 0, −12), rumo alvo π (proa ao sul); partida para (174, 0, −6) | +90 m em x |

Constantes propostas para `ep01_layout.gd` (o lead decide): `RIVER_X_MIN 30`, `RIVER_X_MAX 182`, `BUOY_POS (90,0,−3)`,
`ENSEADA_POS (166,0,21)`, `ENSEADA_RADIUS 8`, e **+90 m em x** para todas as constantes da etapa 3–5 (pouso, âncoras,
apoios, ilha, piloto, pier, alvo de atracação, entrada do braço). `BOAT_ARRIVAL_START` pode ficar em (34, 0, −5).
Tempo de rio: a 7 m/s (limite) 152 m ≈ 22 s de travessia pura; com boia, banco de areia, enseada e falas, a etapa
tende a 1,5–2,5 min (estimativa, **não medida**).

## 3. Trecho no motor (Portão 1)
- Cena: `game/episodes/ep01/world/harbor_slice.tscn` (gerada por `gen_harbor_slice.gd` a partir de `harbor_layout.json`, composição B). **Não está ligada ao jogo.**
- Preview: `preview_harbor.tscn` (Atmosphere + WaterSurface do jogo, câmera do cais e plano aberto).
- Conteúdo: cais RB-04 (`dock_assembled.tscn`, paleta nova) + 16 casas (4 malhas compartilhadas, cor por material de superfície `mat_env_wall_*`/`mat_env_roof_*`) + 81 peças instanciadas (barracas, postes, bancos, canteiros, bandeirolas, árvores, barquinhos, gaivotas, nuvens, morros, farol) + 109 instâncias em MultiMesh (cais de pedra, praça, gramado, tufos de flores) + 159 colisões simples (caixa/cilindro) fora dos GLB + limites de água.
- Kit: 27 GLB, 63 866 triângulos (soma de uma cópia de cada; casa A 5 624, B 9 396, C 9 960, D 3 624; farol 3 554). Manifesto completo: 62 ativos, 162 182 triângulos.

### Custo medido (Godot 4.7.2, Movie Maker 1280×720, `preview_harbor.tscn`, monitores de render no quadro 8 e 18)
| Vista | draw calls | primitivas | objetos |
|---|---|---|---|
| Câmera do cais | 869 | 771 136 | 869 |
| Plano aberto | 1 201 | 802 694 | 1 201 |
Não medi tempo de quadro nem p95 (o Movie Maker não representa o tempo real). **Risco**: ~870 draw calls é alto para o
alvo de 16,7 ms. Próximas reduções (não feitas): mesclar por material as partes de cada peça (casa: 12 → 8 superfícies),
MultiMesh também para adereços repetidos (postes, caixas, tufos de grama do cais), `visibility_range` nos pequenos,
e LOD das casas da segunda fileira.

## 4. O que o lead precisa para integrar
1. Instanciar `harbor_slice.tscn` no lugar de `dock_assembled.tscn` no estágio do cais (o cais continua igual em posição e colisão).
2. Decidir as novas constantes da seção 2 (rio de 152 m, +90 m na etapa da ilha) em `ep01_layout.gd`.
3. Ajustar `art/atmosphere.gd` (fora da minha área): o céu e a névoa do jogo ficaram mais claros/lavados que a bible (`SKY_TOP #4FA6E8`, horizonte `#FDE9C9`; névoa 0,0035 apaga os morros no plano aberto).
4. Câmera: o `CameraRig` atual usa offset (0; 7,5; 9,5); os estudos usaram (0; 4,6; 6,2) como pedido.

## 5. RB-R1 etapa 2 — mundo inteiro (cenas prontas para o lead)
Coordenadas do MUNDO: as três cenas se instanciam **na origem** (sem deslocamento), irmãs do porto.
| Cena | Nó raiz | Conteúdo | Pisos (colisão) |
|---|---|---|---|
| `res://episodes/ep01/world/river_world.tscn` | `RiverWorld` | margens norte/sul (barrancos arredondados, praia, mata), ponte em arco em x 62 (vão livre medido 3,49 m em \|z\| ≤ 10), banco de areia (x 112..126) com conchas e 2 gaivotas, enseada (166, 21) com palmeiras, rochedos e barquinho, cabana de pescador + pier de pesca em x ~100 (margem norte), pouso de Pico na margem oeste do braço (x 175,5..182, z 1,5..18, topo y 0) | `Floors/PicoLanding` (caixa, topo y 0) |
| `res://episodes/ep01/world/island_world.tscn` | `IslandWorld` | ilha x 190..212 (acampamento em y 0); travessia: `SafeRock0..2` claras de topo plano nos apoios (183,5; 0,3; 6,5), (186; 0,5; 5), (188,5; 0,3; 4,2) + `DecoyRock0..3` escuras/molhadas (topo ≤ −0,16); `CampTent`, `CampFire` (apagada), `CampCrate`, `CampFlag`; atracadouro `IslandPier` (z −2, topo y 0) | `Floors/IslandFloor` (caixa 15×22, topo y 0), cilindros em palmeiras/árvores/rochedos e nas rochas seguras |
| `res://episodes/ep01/world/horizon.tscn` | `Horizon` | moldura de mar distante em volta do `WaterSurface` (sem sobrepor: a água do jogo faz espuma por profundidade), 16 morros distantes + 11 próximos no perímetro, 22 nuvens | — |

Porto (`harbor_slice.tscn`, já integrado): margem sul refeita (caminho de terra `BankPath` com bordas irregulares e lama em volta da pegada, grama com morrinhos e cor por vértice, 170 tufos + 26 flores em MultiMesh, cerca rústica, barco virado com gaivota, caixotes, banco, juncos e pedras na beira), promontório arredondado (`Headland`) sob o farol, árvore alta em gota, faixas do farol sem costura.

Atenção (lead/gameplay): `LANDING_POS` (180,5; 0; 10) e a âncora A (182; 1,2; 4) ficam na língua de terra; o barco entra no braço pelo norte (z < 1,5). A cabana do RB-04 em (−7; 0; 13,5) pode tapar a câmera quando Rastro está na pegada (não mudei a posição).

### Custo medido por trecho (Godot 4.7.2, Movie Maker 1280×720, `preview_world.tscn` = porto + rio + ilha + horizonte juntos)
| Vista | draw calls | primitivas |
|---|---|---|
| cais (câmera de jogo) | 925 | 974 510 |
| margem sul (câmera de jogo) | 1 029 | 1 032 026 |
| farol / promontório | 358 | 1 197 272 |
| rio — ponte | 339 | 1 726 714 |
| rio — banco de areia | 238 | 1 353 488 |
| enseada | 161 | 544 998 |
| ilha — travessia | 136 | 365 886 |
| ilha — acampamento | 118 | 385 182 |
| aéreo (tudo) | 922 | 1 911 582 |
Tempo de quadro não medido aqui. As primitivas incluem os passes de sombra.

### Reduções propostas para celular (não implementadas)
1. Árvores: variante de baixa contagem (copa ~250 tri em vez de ~1 000) na mata/margens e `visibility_range_end` ~80 m nos MultiMesh; a mata domina as primitivas (vista da ponte 1,7 M).
2. Sombras: só o porto projeta sombra; mata, arbustos, juncos e rochas sem sombra; 1 cascata.
3. Porto: mesclar por material as partes de cada peça (casas 12 → 8 superfícies) e passar postes, caixotes, bandeirolas e tufos para MultiMesh (estimo ~925 → ~450 draw calls na câmera do cais).
4. Carregar por trecho: `river_world`/`island_world` só a partir do estágio do rio; liberar o porto ao chegar à ilha.
5. Terrenos: grade de 1,5 m → 3 m longe das margens.
