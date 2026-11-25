# Pico v2 · proveniência (RB-R1 D11/D13) — PROPOSTA PROVISÓRIA

Herói escalador para aprovação de Thiago num visualizador 3D. **Não substitui** o Pico do jogo
(`game/assets/models/characters/pico.glb` continua em uso); aparece só na vitrine `game/lookdev/` (modo `after`, via
`game/lookdev/pico_v2_model.tscn`).

Mesmo acabamento do Rastro v2 (vinil com verniz, tecido com trama assada, pespontos e vincos em normal map, corpo inteiriço,
mãos de 4 dedos, olhos com dois brilhos), com traje, silhueta, cabelo e acessórios próprios (D13).

## Conceito
- **Traje:** jaqueta curta **acolchoada** verde `#3DBE5A` (gomos horizontais no tronco e anéis nas mangas, modelados na
  malha; costuras com pesponto; painéis laterais, axilas, cotoveleiras e punhos em verde-escuro; zíper e gola em pé
  amarelo-corda `#FFD23F`; vivo verde-escuro na bainha; estrela amarela nas costas) + **calça de escalada** cinza-azulada
  (lona, costuras interna/lateral, joelho articulado, bolso de carga na coxa direita, barra franzida) com **joelheiras**
  verdes de vivo amarelo.
- **Silhueta:** capacete de escalada arredondado (listra amarela, respiros, estrela nas laterais, aro de borracha) com
  **lanterna de testa** e jugular amarela até a fivela sob o queixo; **rolo de corda a tiracolo** (ombro direito → quadril
  esquerdo, 5 voltas com hélice e fio traçador, amarrações verdes); **mosquetões grandes** (dourado e verde anodizados) no
  cinto e um preso nas amarrações; **saco de magnésio** nas costas; **luvas de escalada** amarelas com palma de aderência;
  **botas de aproximação** de cano baixo (biqueira e sola de borracha clara, cadarço amarelo, contraforte verde).
- **Cabelo e pele:** ruivo em mechas de vinil saindo do capacete; atrás, cabelo solto e bagunçado em três camadas
  sobrepostas (mechas longas rente à nuca, médias que abrem para fora, tufos curtos que espetam), com ângulo, comprimento,
  largura e direção variados (v2.1, no lugar da fileira de pontas iguais); costeletas, franja varrida,
  pele clara `#F3C9A2` com sardas pintadas, olhos azuis (trio diverso: Rastro moreno, Pico ruivo de pele clara, Leme negra).
- **Comum da equipe:** emblema da Rota Brava no peito (esquerdo, livre da corda) e cinto azul-marinho com fivela-bússola dourada.
- **Pés:** eixo das pernas afastado (`HIP_X = 0,088 m`) e botas mais estreitas: chão visível entre os pés de frente, parado;
  nenhum clipe aproxima os pés do eixo (medido por `pv2_check.py`, ver `pico_v2.check.json`).

## Origem de tudo (100% gerado no projeto)
| Item | Como foi feito |
|---|---|
| Corpo inteiriço (tronco + braços + pernas numa malha só) | grafo de pele (modificador SKIN) + SUBSURF 3; gomos do acolchoado, articulações, joelho, bolso de carga e barra deslocados por vértice em numpy (`pv2_body.shape_suit`); Decimate por colapso |
| Capacete | superfície paramétrica (elipsoide com borda variável por azimute) + Solidify; aro, faixa, lanterna e jugular por tubos, torno e projeção na cabeça (BVH) |
| Cabelo | massa por metaballs + mechas como tubos achatados que afinam até a ponta, em três camadas com parâmetros por mecha (`pv2_body.hair_tufts`) |
| Punho fechado | shape keys `fist_R`/`fist_L` na malha do equipamento (dedos da luva dobram na base e no meio, polegar fecha por cima; `pv2_body.add_fist_keys`, mesma técnica do Rastro v2.1); sem ossos de dedo, animadas na `team_pose` e no `celebrate` |
| Luvas, botas, joelheiras | SKIN + SUBSURF, achatamento da palma em numpy; sola ajustada ao contorno medido da própria bota; elipsoides |
| Corda, mosquetões, saco de magnésio, cinto, emblema | laço por raycast no próprio corpo (v2.1: envelope = média curta nunca abaixo do corpo, encosta nas costas sem atravessar; folga medida em `pico_v2.info.json`, `rope_gap`) e tubos fechados; mosquetão em D por tubo; torno, toros e prismas em bmesh |
| Cabeça, rosto (olhos com dois brilhos, pálpebras, sobrancelhas, boca, visemas, olhar), esqueleto de 28 ossos | reuso de `source_art/scripts/hero_lib.py` e `hero_face.py` (os mesmos do Pico atual) |
| Animações (11 clipes, mesmos nomes do `pico.glb`) | `source_art/scripts/hero_anim.py` + `pv2_anim.py` (`idle` novo: quica na ponta dos pés e alonga; `team_pose` nova: pulinho para a base aberta, dois puxões na corda, braço ao alto com punho fechado; `celebrate` com os dois punhos), FK/IK em Python. v2.1 alongou os braços (pulso 8,8 cm mais baixo); a **v2.3 desfez isso** (comprimento na média do trio, ver abaixo) |
| Texturas (cor, normal, ORM) | assadas no Cycles a partir da própria malha (posição, normal, parte, AO) e pintadas em numpy por fórmula (`pv2_tex.py`). Nenhuma imagem de terceiros |

Nenhum modelo, malha, textura, HDRI ou personagem-base baixado ou importado. Paleta da bíblia de estilo (`docs/style-bible.md` §3).
Scripts copiados e adaptados do Rastro v2 (`source_art/characters/rastro_v2/`), sem editar os originais.

## v2.2 · leitura de frente (2026-11-25)
Thiago viu no cais (câmera baixa, de frente) o Pico "sem braços e sem olhos": no alongamento do `idle` as duas mãos iam
para trás/acima da cabeça (as luvas viravam duas "orelhas" no capacete) enquanto o rosto estava no sorriso de olhos
fechados. Correção só em `pv2_anim.py` (malha, texturas, rig e nomes de clipe iguais):
- `idle` (4,0 s): alongamento curto (sobe 1,50–1,82 s, desce 2,28–2,58 s) com os braços em **V largo** (mão a ~0,40 m do
  eixo e ~0,33 m acima do ombro; cabelo e capacete vão até 0,26 m); o resto do ciclo é quique com os braços soltos ao lado
  do corpo (abertura 12–26°). Olhos abertos com duas piscadas; sorriso de olhos fechados só num pulso de 3,12 a 3,68 s.
- `team_pose`: punho ao alto **ao lado** do capacete (não mais por cima/atrás), cabeça menos inclinada; olhos abertos
  (atentos) e sorriso fechado só nos puxões da corda (0,42–0,82 s), nunca no punho ao alto.
- `celebrate`: punhos em V aberto, fora da silhueta da cabeça; surpresa no impulso, sorriso fechado só no alto do salto.
- `wave`: sorriso fechado só num pulso de 0,55 a 1,10 s, olhos abertos e piscada no resto. `jump`: olhos abertos (atento no
  impulso, surpresa no ar) em vez do sorriso parcial.
- `pv2_check.py` mede agora a leitura: fração dos vértices de cada luva que, na projeção frontal (células de 1 cm), cai sobre
  a silhueta da cabeça (pele + cabelo + capacete), e o maior trecho contínuo com `alegre` > 0,5 (`pico_v2.check.json`).
  Antes → depois: `idle` 75% / 39 quadros → **0% / 0**; `team_pose` 66% / 20 → 1,2% / 5 (transição do braço); olhos
  fechados `idle` 1,23 s → **0,43 s**, `team_pose` 1,17 → 0,30 s, `celebrate` 0,90 → 0,47 s, `wave` 1,23 → 0,43 s.
  Folga mínima entre as botas **4,69 cm** em todos os quadros dos 11 clipes; pés plantados (deslize 0,0 mm/quadro).
- `render_pico_leitura.py`: prancha de frente na distância da câmera baixa da vitrine (herói a 4,1 m, ~265 px de altura).

## v2.3 · comprimento dos braços (2026-11-25)
Thiago comparou o trio de frente: as mãos do Pico desciam até o meio da coxa, as da Leme e do Rastro param no quadril/cinto
(herança da v2.1, que alongou os braços para a luva passar do capacete). Medido por `pv2_proporcao.py` nos GLBs (malha
avaliada, rest pose do rig; quadril = cabeça do osso `thigh`; frações da altura total H):

| em repouso (/H) | pulso | ponta dos dedos | dedos − quadril | braço (ombro→pulso) | mão (pulso→ponta) |
|---|---|---|---|---|---|
| Pico v2.2 (antes) | 0,278 | 0,147 | −0,180 | 0,288 | 0,133 |
| Leme v2.2 | 0,384 | 0,282 | −0,058 | 0,198 | 0,104 |
| Rastro v2.1 | 0,373 | 0,243 | −0,097 | 0,212 | 0,133 |
| média Leme/Rastro | 0,378 | 0,263 | −0,077 | 0,205 | 0,119 |
| **Pico v2.3** | **0,378** | **0,261** | **−0,067** | **0,195** | **0,119** |

- `pv2_body.ARM_DROP` 0,088 → **−0,019** (pulso 10,7 cm mais alto que na v2.2) e luva `hand` 1,36 → **1,22**. Largura das
  mangas não mudou (não era o foco; com o braço mais curto a manga acolchoada lê proporcional na prancha).
- Animação: os alvos dos braços erguidos passam a seguir o alcance real do rig (`pv2_anim.v_target`), em V aberto acima
  dos ombros: alongamento do `idle` a 42° (a 55° a luva caía sobre o cabelo de frente: 23–36% em 19 quadros, recusado),
  punho da `team_pose` a 58°, `celebrate` a 48°; o `wave` ganhou cópia própria com alvo a 32° (o alvo fixo do
  `hero_anim` levava a luva sobre a cabeça: 17,9% em 5 quadros). A mão não passa mais do capacete (por pedido).
- Leitura de frente (`pico_v2.check.json`): luva sobre a silhueta da cabeça 0% em `idle`, `celebrate`, `wave`, `jump`;
  `team_pose` 1,5% em 5 quadros (transição do braço, igual à v2.2). Olhos fechados iguais à v2.2. Folga mínima entre as
  botas **4,69 cm** em todos os quadros dos 11 clipes. 24.944 triângulos, 28 ossos, `fist_R`/`fist_L`, GLB 6,82 MB.
- No quadro 0 do `idle` (cotovelo dobrado 24°) a ponta dos dedos fica 3,4% de H acima da média dos outros dois (pulso +1,9%).

## Arquivos
- Fonte: `build_pico_v2.py` (entrada), `pv2_body.py`, `pv2_tex.py`, `pv2_anim.py`, `pv2_render.py`, `render_pico_v2.py`,
  `pv2_check.py` (medições dos pés e da leitura de frente), `render_pico_leitura.py` (prancha de leitura), `pv2_proporcao.py` (proporção dos braços do trio); `pico_v2.blend` (texturas empacotadas); `pico_v2.info.json` (medidas);
  `pico_v2.check.json` (folga entre as botas por clipe/quadro, deriva e deslize dos pés).
- Saída: `game/assets/models/characters/pico_v2.glb` (glTF 2.0 binário, metros, +Y para cima, PBR metallic-roughness,
  `KHR_materials_clearcoat`, texturas JPEG embutidas).
- Godot: `pico_v2.glb.import` usa `game/lookdev/gltf_pbr_import.gd` (mipmaps nas texturas embutidas e verniz lido do GLB),
  extração de textura desligada, igual ao Rastro v2.

## Reproduzir
```bash
bash tools/blender.sh --background --factory-startup --python source_art/characters/pico_v2/build_pico_v2.py -- \
  --glb $PWD/game/assets/models/characters/pico_v2.glb --blend $PWD/source_art/characters/pico_v2/pico_v2.blend
bash tools/blender.sh --background source_art/characters/pico_v2/pico_v2.blend \
  --python source_art/characters/pico_v2/pv2_check.py -- $PWD/source_art/characters/pico_v2/pico_v2.check.json
bash tools/blender.sh --background source_art/characters/pico_v2/pico_v2.blend \
  --python source_art/characters/pico_v2/render_pico_v2.py -- $PWD/captures/pico_v2
```
O GLB não sai byte a byte idêntico entre exportações (JPEG e ordem interna), mas malha, materiais e medidas sim.
O build completo leva ~8 min na nuvem (4 CPUs; o bake de AO domina).

## Ciclos v2 de andar e correr (RB-R1, 2026-11-25, PROVISORIO)
Pedido de Thiago ("os pes estao muito acelerados"): `walk` e `run` refeitos por `source_art/scripts/hero_gait_v2.py` (FK/IK em Python, do zero), configurados em `pv2_anim.py` (`WALK`, `RUN`). Passada longa (curso de apoio 0,44 m), quadril calculado quadro a quadro pelo alcance real das pernas, guinada do quadril, pe que rola do calcanhar a ponta e sai/chega rente ao chao. Os demais clipes nao mudaram.
- ciclo / curso de apoio / avanco por ciclo / escala no jogo / passos por s: andar 1,00 s / 0,44 m / 1,167 m / x1,20 / 2,40; correr 0,567 s / 0,44 m / 1,577 m / x1,15 / 4,06 (escala = 1,4 ou 3,2 m/s dividido pela velocidade nominal do clipe).
- Folga minima entre as botas: 6,62 cm (walk), 7,34 cm (run) (`pv2_check.py`).
