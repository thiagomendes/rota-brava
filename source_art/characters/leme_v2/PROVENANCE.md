# Leme v2.2 pilota · proveniência (RB-R1 D11/D13/D16) — PROPOSTA PROVISÓRIA

Heroína **pilota e navegadora** da equipe (9 anos, a mais velha e calma): conduz qualquer veículo (barco, carrinho, kart,
balão, drone) e lê bússola e mapas (D16). Para aprovação de Thiago num visualizador 3D. **Não substitui** a Leme do jogo
(`game/assets/models/characters/leme.glb` continua em uso); aparece só na vitrine `game/lookdev/` (modo `after`, via
`game/lookdev/leme_v2_model.tscn`). A versão "capitã de barco" (v2.1) fica no histórico do Git (commit `003ea04` e seguintes).

## Conceito do traje (D13: distinta do Rastro e do Pico; D16: nada náutico fixo)
- **Silhueta:** **boné de pilota com fones** — copa arredondada de seis gomos (branca, gomo da frente azul, vivo azul-marinho
  na base, botão no alto), pala curta quase reta (olhos livres), emblema da equipe na frente; por cima, **fones de pilota**:
  arco azul-marinho com almofada branca passando sobre o boné, conchas grandes azuis com tampa branca e estrela azul-marinho,
  almofadas azul-marinho assentadas no cabelo e **haste de microfone** saindo da concha esquerda e parando ao lado da boca
  (liga com o rádio de Farol 7). Conchas largas + arco + haste = silhueta própria, diferente do chapéu/óculos-lupa do Rastro e
  do capacete redondo com lanterna do Pico. Cachos com volume nas laterais e **puff grande atrás** continuam à mostra.
- **Traje:** **jaqueta curta de pilota** azul `#2F8CFF` em sarja técnica (gola alta branca com friso azul, zíper com dentes
  prata e puxador, ombros brancos em recorte com pesponto, laterais azul-marinho sob os braços, **faixa refletiva** no peito e
  em cada braço, barra canelada), **calça de pilota** azul `#1F5FBF` (vivo branco lateral, bolsos com
  pesponto), **cotoveleiras** azul-marinho e **joelheiras** brancas com vivo azul-marinho e filete refletivo (cascas
  acolchoadas leves), **luvas de pilota** brancas de 4 dedos (protetor azul-marinho nos nós dos dedos, palma lisa) com
  **punho largo** azul de borda branca, **botas de pilota** azuis com biqueira e cano brancos, duas **tiras de velcro**
  azul-marinho com passador prata, aba refletiva no calcanhar e sola branca com friso azul-marinho.
- **Equipamento:** bússola de pulso (esquerda, sobre a manga acima do punho da luva: aro dourado, mostrador com rosa dos
  ventos, agulha, cúpula de vidro).
- **Comum da equipe:** emblema da Rota Brava no peito esquerdo (na jaqueta) e cinto azul-marinho com fivela-bússola dourada.
- **Pele e cabelo:** pele marrom-escura quente (#8C5634; Rastro #C98B60, Pico #F3C9A2); cachos quase pretos.
- **Pernas em leve "A"** (quadril ±0,073 m, tornozelos ±0,092 m): as botas ficam separadas em todos os quadros.

## Equipamento por missão (D16): colete salva-vidas como acessório
- Nó próprio no mesmo GLB: **`Acc_LifeVest`** (malha com pele no mesmo esqueleto, pesos só do tronco: hips, spine, chest,
  neck; material próprio `mat_leme_v2_acc_lifevest`, textura 1K). Contém o colete de placas de espuma com canais costurados,
  faixas refletivas, gola-travesseiro, tiras e fivela, apito no cordão e o emblema da equipe na placa esquerda.
- **Cor do colete (v2.2, D17, 2026-11-25):** nailon **amarelo da equipe `#FFC83D`** (o amarelo do emblema, `docs/style-bible.md`
  §4), para não se confundir com a jaqueta azul; faixas refletivas prata `#B9C7D4` com vivos azul-marinho `#1F3A5F` dos dois
  lados; vivo da borda, tiras e cordão do apito em azul-marinho; apito azul-marinho claro `#2B5285` com argola prata (o antigo
  apito âmbar sumia no amarelo); emblema azul-marinho com estrela dourada, inalterado. Sem laranja (cor da Rastro). Antes:
  colete azul `#1F5FBF`. Malha, rig, clipes e visibilidade padrão não mudaram (só `lv2_tex.py`).
- **Oculto por padrão** na Godot: `game/lookdev/gltf_pbr_import.gd` esconde na importação todo nó cujo nome começa com `Acc_`.
  Ligar no jogo ou na vitrine: `modelo.find_child("Acc_LifeVest", true, false).visible = true`
  (na cena: `LemeV2/Model/Rig/<Armature>/Skeleton3D/Acc_LifeVest`). Vitrine: `--lookdev-hero=leme --lookdev-acc=Acc_LifeVest`.
- glTF não tem visibilidade de nó (o exportador do Blender 4.5 não grava `KHR_node_visibility`): num visualizador web o
  colete aparece até ser escondido pelo próprio visualizador.

## Origem de tudo (100% gerado no projeto)
| Item | Como foi feito |
|---|---|
| Corpo inteiriço (tronco + braços + pernas numa malha só) | grafo de pele (SKIN) + SUBSURF 3, ombro/cotovelo/joelho/panturrilha deslocados em numpy, Decimate por colapso; depois cortado por planos exatos em jaqueta e calça (cintura sob o cinto; fim da manga no pulso, sob o punho da luva; calça entra na bota) (`lv2_body.split_body`) |
| Cotoveleiras e joelheiras | casca paramétrica sobre o tecido (raycast em BVH em volta do eixo do membro, grade levada para um disco = contorno oval), espessura com borda arredondada e vivo até o tecido; pesos copiados da jaqueta/calça (`lv2_body._shell`) |
| Colete (acessório) | superfície paramétrica (θ, z) projetada no corpo por raycast em BVH, espessura com borda arredondada e canais modelados, vivo até o corpo; gola-travesseiro por SKIN |
| Luvas de 4 dedos (relaxadas e levemente curvas, polegar à mostra), botas, sola | SKIN + SUBSURF, palma achatada em numpy; shape keys `fist_R/fist_L` (punho) e `thumb_up_R/thumb_up_L` (joinha) por rotação das falanges em numpy, pesos suaves pela distância aos esqueletos dos dedos (`lv2_body.add_hand_keys`, agora na malha das luvas); punho largo por torno; sola pelo contorno medido da própria bota |
| Tiras de velcro e aba das botas | fitas que seguem a superfície da bota (raycast em BVH) com seção arredondada; passadores e aba por caixas arredondadas |
| Boné, fones, microfone, cinto, fivela, emblema, bússola, zíper | torno (lathe), toros, tubos, prismas e caixas arredondadas em bmesh; o arco dos fones tem o raio medido por raycast na própria copa do boné (com folga) e é suavizado |
| Cabeça, rosto (olhos com dois brilhos, pálpebras, sobrancelhas, boca, visemas, olhar), esqueleto de 28 ossos | biblioteca dos heróis: `source_art/scripts/hero_lib.py`, `hero_face.py` (pernas do esqueleto em leve A) |
| Cabelo | massa de base por metaball (o que fica dentro dos cachos ou do boné sai da malha) + cachos individuais (elipsoides lisos de tamanho variado); os cachos que cairiam dentro das conchas, do arco ou da haste do microfone não são criados (`headset_layout`); mola de dois fios e verniz pintados por cacho (`lv2_tex.paint_hair`) |
| Animações (12 clipes, os MESMOS nomes do `leme.glb`) | `source_art/scripts/hero_anim.py` + `lv2_anim.py` (idle, team_pose e wave próprios; **team_pose de pilota**: mão direita no fone + joinha da esquerda; punhos no celebrate; pegada leve no volante; correção de contato que impede a sola de afundar ao rolar o pé), FK/IK em Python |
| Texturas (cor, normal, ORM) | assadas no Cycles a partir da própria malha (posição, normal, parte, AO) e pintadas em numpy: sarja técnica, recortes, zíper, faixas refletivas, pespontos, velcro, acolchoado, ripstop (colete), gomos do boné, cachos em hélice (`lv2_tex.py`). Nenhuma imagem de terceiros |

Nenhum modelo, malha, textura, HDRI ou personagem-base baixado ou importado. Paleta da bíblia de estilo (`docs/style-bible.md` §3).
O render de prova do trio importa `rastro_v2.glb` e `pico_v2.glb` (do próprio projeto) só para a comparação lado a lado.

## Medidas (Blender, `leme_v2.info.json`)
- v2.2 pilota (2026-11-25): **24.531 triângulos com o colete** (21.017 sem: `Acc_LifeVest` tem 3.514); altura 1,137 m (com os
  fones); cabeça 35,3% da altura; olho 29,3% da cabeça; 28 ossos; 12 clipes; shape keys das luvas `fist_R`, `fist_L`,
  `thumb_up_R`, `thumb_up_L` (Actions `<clipe>_hand`).
- **Botas nunca se tocam:** menor distância entre as malhas das duas botas (bota, sola, colarinho, tiras, passadores e aba),
  vértice→superfície nos dois sentidos, em todos os quadros dos 12 clipes = **5,22 cm** (team_pose quadro 4; walk 6,63 cm,
  run 7,09 cm).
- Pés plantados: walk erro médio 0,0075 m/s (máx. 0,058 m/s), run 0,0; a sola desce no máximo 0,7 mm abaixo do chão no walk
  e 0,1 mm no run.
- Mãos no volante (`idle_wheel`): ponto médio das mãos a 0,97 cm do centro do volante.

## Arquivos
- Fonte: `build_leme_v2.py` (entrada), `lv2_body.py`, `lv2_tex.py`, `lv2_anim.py`, `lv2_render.py`, `render_leme_v2.py`;
  `leme_v2.blend` (texturas empacotadas); `leme_v2.info.json` (medidas, inclusive folga das botas por clipe e deslize).
- Saída: `game/assets/models/characters/leme_v2.glb` (glTF 2.0 binário, metros, +Y para cima, PBR metallic-roughness,
  `KHR_materials_clearcoat`, texturas JPEG embutidas).
- Godot: `leme_v2.glb.import` igual ao do `rastro_v2` (pós-importação `game/lookdev/gltf_pbr_import.gd`, extração de
  material desligada); cena `game/lookdev/leme_v2_model.tscn`.

## Reproduzir
```bash
bash tools/blender.sh --background --factory-startup --python source_art/characters/leme_v2/build_leme_v2.py -- \
  --glb $PWD/game/assets/models/characters/leme_v2.glb --blend $PWD/source_art/characters/leme_v2/leme_v2.blend
bash tools/blender.sh --background source_art/characters/leme_v2/leme_v2.blend \
  --python source_art/characters/leme_v2/render_leme_v2.py -- $PWD/captures/leme_pilota
```
O GLB não sai byte a byte idêntico entre exportações (JPEG e ordem interna), mas malha, materiais e medidas sim.

## Ciclos v2 de andar e correr (RB-R1, 2026-11-25, PROVISORIO)
Pedido de Thiago ("os pes estao muito acelerados"): `walk` e `run` refeitos por `source_art/scripts/hero_gait_v2.py` (FK/IK em Python, do zero), configurados em `lv2_anim.py` (`WALK`, `RUN`). Passada longa (curso de apoio 0,47 m), quadril calculado quadro a quadro pelo alcance real das pernas, guinada do quadril, pe que rola do calcanhar a ponta e sai/chega rente ao chao. Os demais clipes nao mudaram.
- ciclo / curso de apoio / avanco por ciclo / escala no jogo / passos por s: andar 1,00 s / 0,47 m / 1,217 m / x1,15 / 2,30; correr 0,633 s / 0,47 m / 1,762 m / x1,15 / 3,63 (escala = 1,4 ou 3,2 m/s dividido pela velocidade nominal do clipe).
- Folga minima entre as botas: 6,47 cm (walk), 7,28 cm (run) (`lv2_anim.measure_feet`).

## Olhos abertos no idle e nos gestos (RB-R1 G1, 2026-11-26)
Thiago viu a Leme de olhos fechados no menu e nas cenas. O "alegre" e o sorriso de OLHOS FECHADOS e durava demais:
no idle seguia toda a virada para o mar (39% do ciclo de 5,2 s, 1,80 s seguidos) e em `wave`, `celebrate` e `team_pose`
ficava 0,92-1,22 s seguidos. Agora e um aperto curto: no idle (`squint`, ~0,5 s quando o rosto chega ao mar) e nos gestos
por `short_squint` (`lv2_anim.py`, janela de ~0,45 s no pico do gesto); fora dele os olhos ficam abertos com a boca neutra
(que ja sorri de leve). Medido nas trilhas importadas na Godot (olho fechado = max(alegre, blink) >= 0,5): idle 17% / 0,50 s;
wave 27% / 0,45 s; celebrate 36% / 0,45 s; team_pose 29% / 0,45 s. Corpo, malha, materiais e medidas
(`leme_v2.info.json` igual) iguais; GLB reexportado pelo mesmo comando de "Reproduzir".
O `point` (1,2 s, sem laco) piscava em 1,05 s e terminava com o olho 62% fechado; parado no ultimo quadro (close da
abertura) a heroina ficava de olho quase fechado. Agora pisca uma vez em 0,80 s (`blink_once`) e termina de olho aberto.
