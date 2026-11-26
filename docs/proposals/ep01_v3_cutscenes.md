# Ep01 v3 · Cutscenes, falas que apontam e variantes (RB-R1, F2 + D19c + D21)

Status: **proposta de texto** (`adventure`, 2026-11-25, branch `feature/rb-r1-f2-texto`). Só texto e fichas: nenhum `.gd` mudou; o `gameplay` liga tudo depois.

- Catálogo: textos novos em `game/i18n/pt_BR.ep01v3_f2.json` (151 chaves, carregado sozinho pelo `Loc`); 8 revisões em `game/i18n/pt_BR.ep01v3.json`.
- Ficha das falas: `game/episodes/ep01/v3/ep01_v3_dialogue.json`, seções novas `step_start` (`"M1.bench"` → chave), `travel` (`"M2>M3"`), `step_done`, `groups` (D19c), e por fala `when`, `moment` e `gesture` (`anim`, `fallback`, `target` = marcador do mundo). `take: null` em tudo o que é novo (sem áudio até as vozes D19).
- Ficha das cenas: `game/episodes/ep01/v3/ep01_v3_cutscenes.json`.
- Teste: `game/tests/test_ep01_v3_f2_text.gd` (13 checagens).
- Regras de texto: no máximo 8 palavras e 44 caracteres; nada de ponto cardeal; o lugar é dito por algo que se vê.

## 1. Revisões pedidas pela auditoria (mundo corrigido)
A bota passa para junto da amarra vazia (`M1_EmptyMooring`, um poste sem bote) e as patinhas começam a ≤ 2 m da pata do cais. Por isso:

| Chave | Antes | Agora |
|---|---|---|
| `ep01v3.M1.bench.hint_gesture` | Ali, no banco! | Ali, no cais! |
| `ep01v3.M1.boot.hint_gesture` | Ali, na margem! | Ali, no poste sem bote! |
| `ep01v3.M1.trail.hint_gesture` | Siga as pegadinhas! | Siga as patinhas! |
| `ep01.radio.v3_m1.bench` | Rastro, olhe a pegada no banco. | Rastro, olhe a pegada no cais. |
| `ep01.radio.v3_m1.boot` | Rastro, veja a bota na margem. | Rastro, veja a bota perto do poste. |
| `ep01.radio.v3_m1.trail` | Rastro, siga as pegadinhas. | Rastro, siga as patinhas até o varal. |
| `ep01.bank.tracker.pup_village` | As pegadinhas vão para a margem! | As patinhas vão até o varal! |
| `ep01.street.pilot.compass_west` | A bússola diz oeste: o galpão de redes! | A seta aponta para o galpão de redes! |

A chave `compass_west` foi mantida (estável; o código já a usa), só o texto mudou. `small_print` não mudou (texto da SPEC).

## 2. Falas que apontam (P5)
25 falas: 21 de início de passo (uma por passo), 3 de deslocamento entre missões e 1 de fim de passo (o filhote visto ao longe). Gesto: Rastro e Leme têm o clipe `point`; o Pico não tem `point` e usa `look_up` (alvo no alto) ou `wave`; `fallback` = `wave`.

| Passo | Momento | Quem | Chave | Texto | Gesto · alvo |
|---|---|---|---|---|---|
| M1.bench | start | tracker | `ep01.dock.tracker.look_paw` | Uma pegada no cais, ao lado do barco! | `point` · `M1_BenchClue` |
| M1.boot | start | tracker | `ep01.dock.tracker.boot_steps` | Pegadas de bota até o poste sem bote! | `point` · `M1_EmptyMooring` |
| M1.trail | start | tracker | `ep01.dock.tracker.follow_paws` | As patinhas vão do cais até o varal! | `point` · `M1_PawTrail_1` |
| M2.free_pieces | start | climber | `ep01.bank.climber.cloth_on_shed` | Roupas no telhado do galpão e na árvore! | `look_up` · `M2_ShedTop` |
| M2.find_third | start | tracker | `ep01.bank.tracker.cloth_reeds` | Pegadinhas molhadas até o capim alto! | `point` · `M2_ReedsPiece` |
| M2.hang | start | pilot | `ep01.bank.pilot.hang_line` | Agora, as roupas no varal perto da árvore! | `point` · `M2_Clothesline` |
| M3.stream | start | tracker | `ep01.plaza.tracker.see_channel` | Veja a canaleta seca no chão de pedra! | `point` · `M3_ChannelStart` |
| M3.leaves | start | climber | `ep01.plaza.climber.leaves_top` | Folhas lá no alto do chafariz! | `look_up` · `M3_UpperBasin` |
| M4.read | start | tracker | `ep01.market.tracker.see_cart` | O carrinho de caixotes coloridos, ali! | `point` · `M4_Cart` |
| M4.deliver | start | pilot | `ep01.market.pilot.see_stalls` | Cada caixote vai na barraca da mesma cor! | `point` · `M4_Stall_Lemon` |
| M5.feathers | start | tracker | `ep01.street.tracker.see_feathers` | Penas brancas no chão da rua, olha! | `point` · `M5_FeatherTrail_1` |
| M5.compass | start | pilot | `ep01.street.pilot.see_vane` | O cata-vento, lá no fim da rua! | `point` · `M5_Weathervane` |
| M5.fish | start | climber | `ep01.street.climber.gull_roof` | A gaivota está no telhado do galpão! | `look_up` · `M5_ShedRoof` |
| M6.board | start | pilot | `ep01.bay.pilot.see_boat` | Nosso barco está no cais. Vamos! | `point` · `M6_BoatStart` |
| M6.buoys | start | pilot | `ep01.bay.pilot.see_buoys` | As duas boias que brilham na água! | `point` · `M6_BuoyA` |
| M6.approach | start | pilot | `ep01.bay.pilot.see_dinghy` | O bote do capitão, perto das pedras! | `point` · `M6_Dinghy` |
| M6.rope | start | climber | `ep01.bay.climber.rope_dinghy` | Vou jogar a corda para o bote! | `wave` · `M6_Dinghy` |
| M7.lens | start | tracker | `ep01.lighthouse.tracker.lens_bush` | Algo dourado brilha perto do arbusto! | `point` · `M7_Lens` |
| M7.climb | start | climber | `ep01.lighthouse.climber.pup_top` | O filhote está lá no alto da escada! | `look_up` · `M7_Gallery` |
| M7.aim | start | pilot | `ep01.lighthouse.pilot.see_boats` | Quatro barquinhos esperam luz na água! | `point` · `M7_FestaBoat_1_star` |
| M8.thanks | start | tracker | `ep01.festival.tracker.see_captain` | O capitão está perto das lanternas! | `point` · `M8_FestaPlaza` |
| M2>M3 | travel | tracker | `ep01.bank.tracker.paws_to_fountain` | Pegadinhas até o chafariz grande da praça! | `point` · `M3_ChannelStart` |
| M3>M4 | travel | tracker | `ep01.plaza.tracker.see_market` | As barracas da feira, ao lado da praça! | `point` · `M4_Cart` |
| M6>M7 | travel | tracker | `ep01.lighthouse.tracker.go_lighthouse` | As patinhas sobem até o farol alto! | `point` · `M7_Lens` |
| M1.trail | done | tracker | `ep01.bank.tracker.pup_to_line` | O filhote correu para o varal! | `point` · `M2_Clothesline` |

## 3. Grupos de variantes (D19c)
36 grupos, 90 variantes novas (a primeira de cada lista é a fala que já existia, quando há). Sorteio sem repetir a última fica com o `gameplay`. A direção de cada grupo já está em `tools/voice/direction.json` → `groups`; `hint.radio.<etapa>` virou um grupo por passo (`hint.radio.M1.bench` etc.) e a 1ª variante é a dica falada atual (`hint_spoken_key`), não o `hint_gesture`.

| Grupo | Variantes (existentes + novas) |
|---|---|
| `help.radio.invite` | Farol 7 aqui. Quer uma ajudinha? / Precisam de mim? Estou no rádio. / Tudo bem ir com calma, equipe. / Uma dica? Escutem o Farol 7. / Olhem em volta. Eu ajudo! |
| `success.tracker` | Isso! Pista achada! / Pista certa! Mais uma. / Boa! Meu olho não falha. / Era isso mesmo! |
| `success.climber` | Peguei! Agora a da árvore. / Consegui! Fácil, fácil! / Lá vai! Pronto! / Peguei mais uma! |
| `success.pilot` | Certinho! Próximo! / Tudo no lugar! / Entregue com cuidado! / Isso, bem no alvo! |
| `oops.vendor` | Esta não. Procure a mesma cor! / Quase! Olhe a cor da placa. / Essa não é, querida. Tente outra. / Hum, a cor não combina. Tudo bem! |
| `oops.pilot.buoy` | Opa, encostei na boia. Tudo bem! / Devagar, de novo. Nós conseguimos! / A boia balançou! Vamos outra vez. |
| `oops.tracker` | Quase! Vou olhar de novo. / Hum, não é aqui. Tento ali! / Ops! Vamos mais uma vez. |
| `oops.climber` | Quase! Pulo de novo! / Ops! Já volto a subir. / Escorreguei, mas tudo bem! |
| `oops.pilot` | Quase! Vou com calma. / Ops! Tento de novo, devagar. / Hum, outro jeito. Vamos lá! |
| `switch.to_tracker` | Rastro, falta uma roupa. Cadê? / Rastro, sua vez de achar pistas! / Rastro, pegue a lupa! Sua vez. / Rastro, olhos atentos! Vem! |
| `switch.to_climber` | Pico, as roupas estão lá no alto! / Pico, as folhas estão lá em cima! / Pico, suba no telhado! / Pico, jogue a corda! / Pico, o filhote está lá no alto! |
| `switch.to_pilot` | Leme, você empurra o carrinho! / Leme, para onde ela voou? / Leme, gire a luz! / Leme, sua vez de pilotar! / Leme, leve a gente! |
| `cheer.tracker` | Viva! Cada um ajudou do seu jeito. / Emblema novo! Uhu! / Mais um emblema para a equipe! / Missão cumprida! Que demais! / Equipe Rota Brava, uhu! |
| `cheer.climber` | Chafariz de volta! Viva! / Uhuu! Emblema na mão! / Subi, achei, ganhei! / Que salto! Que emblema! / Mais um! Bate aqui! |
| `cheer.pilot` | Varal arrumado! Que time! / Que equipe! Emblema nosso! / Missão feita com calma e coragem! / Mais um emblema no barco! / Lindo trabalho, equipe! |
| `hint.radio.M1.bench` | Rastro, olhe a pegada no cais. / Rastro, a pegada está ao lado do barco. / Procure a marca de pata na tábua. |
| `hint.radio.M1.boot` | Rastro, veja a bota perto do poste. / Siga as botas até o poste sem bote. / Rastro, a bota caiu junto ao poste. |
| `hint.radio.M1.trail` | Rastro, siga as patinhas até o varal. / As patinhas levam até o varal. / Rastro, pise nas patinhas, uma a uma. |
| `hint.radio.M2.free_pieces` | Pico, suba e solte as roupas. / Pico, uma roupa está no telhado. / Pico, a outra roupa ficou na árvore. |
| `hint.radio.M2.find_third` | Rastro, siga a pegadinha molhada. / Rastro, a roupa amarela está no capim. / Siga as pegadinhas molhadas até a água. |
| `hint.radio.M2.hang` | Equipe, pendurem as roupas no varal. / Levem as roupas ao varal perto da árvore. / O varal espera as três roupas. |
| `hint.radio.M3.stream` | Rastro, siga o filete até a grade. / Rastro, ande junto da canaleta seca. / A canaleta leva até a grade. |
| `hint.radio.M3.leaves` | Pico, suba no chafariz e puxe as folhas. / Pico, suba os degraus do chafariz. / As folhas entopem a bacia de cima. |
| `hint.radio.M4.read` | Rastro, olhe as cores dos caixotes. / Rastro, cada caixote tem uma cor. / Olhe o carrinho perto da Dona Amora. |
| `hint.radio.M4.deliver` | Leme, leve o caixote à mesma cor. / Leme, a placa mostra a cor da barraca. / Empurre o carrinho até a placa igual. |
| `hint.radio.M5.feathers` | Rastro, siga as penas pela rua. / Rastro, as penas brancas seguem pela rua. / Uma pena, depois outra. Siga! |
| `hint.radio.M5.compass` | Leme, olhe a bússola do cata-vento. / Leme, o cata-vento fica no fim da rua. / A seta do cata-vento mostra o caminho. |
| `hint.radio.M5.fish` | Pico, suba no telhado do galpão. / Pico, suba nos caixotes e no toldo. / A gaivota está no telhado do galpão. |
| `hint.radio.M6.board` | Leme, suba no barco. / Leme, o barco espera no cais. / Ande pelo cais até o barco. |
| `hint.radio.M6.buoys` | Leme, passe pelas duas boias. / Leme, passe entre as boias que brilham. / Devagar, de uma boia para a outra. |
| `hint.radio.M6.approach` | Leme, chegue perto do bote. / O bote está perto das pedras do farol. / Leme, chegue devagar perto do bote. |
| `hint.radio.M6.rope` | Pico, jogue a corda para o bote. / Pico, a corda vai para o capitão. / Jogue a corda bem perto do bote. |
| `hint.radio.M7.lens` | Rastro, procure a lente na grama. / Rastro, a lente brilha perto do arbusto. / Procure algo dourado na grama. |
| `hint.radio.M7.climb` | Pico, suba a escada até o filhote. / Pico, suba patamar por patamar. / O filhote espera lá no alto. |
| `hint.radio.M7.aim` | Leme, gire a luz para os barquinhos. / Leme, gire a luz para cada barquinho. / Estrela, lua, peixe e flor esperam luz. |
| `hint.radio.M8.thanks` | Equipe, o capitão espera na praça. / Equipe, o capitão está perto das lanternas. / Vão até a praça iluminada. |


## 4. Cutscenes (D21)
Formato da ficha: câmera por marcador de `village_world.tscn` + deslocamento em metros (`from` → `to` para `dolly`; `look` → `look_to` para `pan`; `orbit` gira em volta de `look`; `cut` = corte). Com movimento reduzido, todo movimento vira corte. Atores usam só clipes que existem nos GLB (conferido no teste). Durações estimadas, não medidas. Cada cena termina com `exit_look` = alvo do passo seguinte (P2).

**Orçamento:** cenas do Ep01 = **88,5 s** (abertura 13 + 7 introduções de 6,5 = 45,5 + partida do barco 6 + subida do farol 5 + cair da noite 8 + festa 11). Abertura do jogo `game_intro` = **34,5 s**. **Total = 123,0 s.**

`game_intro`: aparece na primeira vez que se joga (antes do Ep01); depois pulável e com `replay_from_menu: true` para rever pelo menu. Cada herói tem dois planos (narrador diz o que faz e o equipamento; o herói se apresenta com a própria voz), Farol 7 no farol pelo rádio e fecho com `team_pose` dos três.

Marcadores usados: `M0_BoatArrival`, `M0_BoatDocked`, `M0_RastroStart`, `M1_BenchClue`, `M2_Clothesline`, `M2_ShedTop`, `M3_UpperBasin`, `M3_ChannelStart`, `M3_Grate`, `M4_Cart`, `M5_FeatherTrail_1`, `M5_ShedRoof`, `M6_Dinghy`, `M6_BoatStart`, `M6_BuoyA`, `M7_Lens`, `M7_Gallery`, `M7_Landing_1`, `M7_Landing_3`, `M7_StairStep`, `M7_FestaBoat_1_star`, `M7_LanternPivot`, `M8_FestaPlaza`.

**O que falta no mundo e nas animações** (nenhum marcador novo é obrigatório; tudo cabe nos 54 que existem):
- Filhote não tem clipe de correr/andar (`idle`, `wag`, `jump_happy`, `bark`, `step_on_horn`): "passou correndo" (M1) e "subiu no farol" (M7) pedem `run` do filhote ou um deslize com `jump_happy`.
- Pico não tem `point` (usa `look_up`/`wave`). Leme não tem `jump`; Rastro não tem `jump`.
- Dona Amora não tem modelo 3D (M4: a cena só mostra o carrinho).
- Gaivota em voo (M5) e pôr do sol/acender das lanternas (cair da noite) dependem do ciclo de luz e de peças do `art3d`/`gameplay`.
- `M7_LanternPivot` está a 16,8 m; os planos do farol usam deslocamento negativo em y para ficar perto do chão. Um marcador `Cut_LighthouseView` (vista do farol a partir da baía) e um `Cut_VillageWide` (aéreo da vila) deixariam os planos amplos mais fáceis de ajustar.
- Narrador: o HUD deduz o falante pelo 3º segmento da chave; `ep01.narrator.*` precisa de regra própria no `Hud.speaker_for` (como `ep01.radio.*`) e de retrato/ícone. Adicionei `member.narrator.name` = "Narrador" ao catálogo.
- As falas de abertura das missões (`mission_start`) continuam na ficha; se a cutscene tocar, o `gameplay` decide se elas ainda tocam (o narrador não repete o texto delas).

## 4.1 Roteiro plano a plano

### `game_intro` · quando: `first_play (menu: rever)` · 34.5 s · sai olhando `M0_BoatDocked` [0, 1, 0]

| # | s | Câmera (de → para · olha) | Movimento | Quem e clipe | Fala (chave · texto) |
|---|---|---|---|---|---|
| 1 | 5.0 | `M7_LanternPivot` [-30, -6, 30] → `M0_BoatDocked` [6, 8, 14] · olha `M8_FestaPlaza` [0, 2, 0] | dolly | — | `ep01.narrator.intro.village` (narrator) · Esta é a Vila Farol 7, à beira-mar! |
| 2 | 3.5 | `M0_RastroStart` [0, 2.5, 6] → `M0_RastroStart` [0, 1.8, 4] · olha `M0_RastroStart` [0, 1, 0.9] | dolly | tracker `idle` em `M0_RastroStart`, climber `idle` em `M0_RastroStart`, pilot `idle` em `M0_RastroStart` | `ep01.narrator.intro.team` (narrator) · E esta é a equipe Rota Brava! |
| 3 | 3.5 | `M0_RastroStart` [-0.8, 1.3, 2.2] · olha `M0_RastroStart` [-0.8, 1.2, 0.6] | dolly | tracker `inspect_touch` em `M0_RastroStart` | `ep01.narrator.intro.tracker` (narrator) · Rastro segue pistas, de lupa e óculos. |
| 4 | 2.5 | `M0_RastroStart` [-0.8, 1.3, 2.0] · olha `M0_RastroStart` [-0.8, 1.3, 0.6] | cut | tracker `point` em `M0_RastroStart` | `ep01.intro.tracker.hello` (tracker) · Sou a Rastro! Nenhuma pista me escapa! |
| 5 | 3.5 | `M0_RastroStart` [0, 1.0, 2.6] → `M0_RastroStart` [0, 0.7, 2.4] · olha `M0_RastroStart` [0, 1.4, 0.9] | dolly | climber `jump` em `M0_RastroStart` | `ep01.narrator.intro.climber` (narrator) · Pico sobe em tudo, de capacete e corda. |
| 6 | 2.5 | `M0_RastroStart` [0, 1.3, 2.3] · olha `M0_RastroStart` [0, 1.3, 0.9] | cut | climber `celebrate` em `M0_RastroStart` | `ep01.intro.climber.hello` (climber) · Sou o Pico! Quanto mais alto, melhor! |
| 7 | 3.5 | `M0_RastroStart` [0.8, 1.3, 2.2] · olha `M0_RastroStart` [0.8, 1.2, 0.6] | dolly | pilot `idle_wheel` em `M0_RastroStart` | `ep01.narrator.intro.pilot` (narrator) · Leme pilota e acha o rumo na bússola. |
| 8 | 2.5 | `M0_RastroStart` [0.8, 1.3, 2.0] · olha `M0_RastroStart` [0.8, 1.3, 0.6] | cut | pilot `wave` em `M0_RastroStart` | `ep01.intro.pilot.hello` (pilot) · Sou a Leme! Fones no ouvido, vamos! |
| 9 | 4.0 | `M7_LanternPivot` [-10, -10, 10] · olha `M7_LanternPivot` [0, 0, 0] | orbit | — | `ep01.radio.intro.hello` (radio) · Aqui é o Farol 7, sempre no rádio! |
| 10 | 4.0 | `M0_RastroStart` [0, 1.6, 4.5] → `M0_RastroStart` [0, 1.3, 3.2] · olha `M0_RastroStart` [0, 1.1, 0.8] | dolly | tracker `team_pose` em `M0_RastroStart`, climber `team_pose` em `M0_RastroStart`, pilot `team_pose` em `M0_RastroStart` | `ep01.narrator.intro.call` (narrator) · Rota Brava, para a aventura! |

### `opening` · quando: `episode_start` · 13.0 s · sai olhando `M1_BenchClue` [0, 0.2, 0]

| # | s | Câmera (de → para · olha) | Movimento | Quem e clipe | Fala (chave · texto) |
|---|---|---|---|---|---|
| 1 | 5.0 | `M0_BoatArrival` [0, 6, 8] → `M0_BoatDocked` [8, 4, 8] · olha `M0_BoatDocked` [0, 1.0, 0] | dolly | — | `ep01.narrator.opening.village` (narrator) · Na vila Farol 7, hoje tem festa! |
| 2 | 4.0 | `M0_RastroStart` [2, 1.6, 3] · olha `M0_RastroStart` [0, 1.2, 0] | dolly | tracker `wave` em `M0_RastroStart`, climber `celebrate` em `M0_RastroStart`, pilot `wave` em `M0_RastroStart` | `ep01.narrator.opening.team` (narrator) · Rastro, Pico e Leme chegam ao cais. |
| 3 | 4.0 | `M0_BoatDocked` [3, 2, 4] · olha `M0_BoatDocked` [0, 1.0, 0] → `M1_BenchClue` [0, 0.2, 0] | pan | pilot `point` em `M0_RastroStart` | `ep01.narrator.opening.empty_boat` (narrator) · Mas o barco do capitão está vazio! |

### `m1_intro` · quando: `M1.start` · 6.5 s · sai olhando `M1_BenchClue` [0, 0.1, 0]

| # | s | Câmera (de → para · olha) | Movimento | Quem e clipe | Fala (chave · texto) |
|---|---|---|---|---|---|
| 1 | 3.0 | `M1_BenchClue` [1.5, 0.8, 2.0] · olha `M1_BenchClue` [0, 0.4, 0] | dolly | pup `jump_happy` em `M1_BenchClue` | `ep01.narrator.m1.pup_runs` (narrator) · Um filhote passou correndo pelo cais! |
| 2 | 3.5 | `M1_BenchClue` [1.0, 0.6, 1.2] → `M1_BenchClue` [0.6, 0.9, 1.0] · olha `M1_BenchClue` [0, 0.1, 0] | dolly | — | `ep01.narrator.m1.paw` (narrator) · Ele deixou uma pegada. Olhe ali! |

### `m2_intro` · quando: `M2.start` · 6.5 s · sai olhando `M2_ShedTop` [0, 0.3, 0]

| # | s | Câmera (de → para · olha) | Movimento | Quem e clipe | Fala (chave · texto) |
|---|---|---|---|---|---|
| 1 | 3.0 | `M2_Clothesline` [2, 1.5, -3] · olha `M2_Clothesline` [0, 1.2, 0] | dolly | pup `bark` em `M2_Clothesline` | `ep01.narrator.m2.pup_line` (narrator) · Ih! O filhote puxou o varal! |
| 2 | 3.5 | `M2_Clothesline` [2, 1.5, -3] · olha `M2_Clothesline` [0, 1.2, 0] → `M2_ShedTop` [0, 0.3, 0] | pan | — | `ep01.narrator.m2.wind` (narrator) · O vento levou as roupas lá para cima. |

### `m3_intro` · quando: `M3.start` · 6.5 s · sai olhando `M3_ChannelStart` [0, 0, 0]

| # | s | Câmera (de → para · olha) | Movimento | Quem e clipe | Fala (chave · texto) |
|---|---|---|---|---|---|
| 1 | 3.0 | `M3_UpperBasin` [4, 2.5, 4] · olha `M3_UpperBasin` [0, 1.0, 0] | dolly | pup `jump_happy` em `M3_ChannelStart` | `ep01.narrator.m3.ball` (narrator) · O filhote brincou de bola na praça. |
| 2 | 3.5 | `M3_ChannelStart` [2, 1.2, 2] → `M3_ChannelStart` [1, 0.8, 1.5] · olha `M3_Grate` [0, 0.3, 0] → `M3_ChannelStart` [0, 0, 0] | dolly | — | `ep01.narrator.m3.no_water` (narrator) · E o chafariz parou de jorrar água! |

### `m4_intro` · quando: `M4.start` · 6.5 s · sai olhando `M4_Cart` [0, 0.8, 0]

| # | s | Câmera (de → para · olha) | Movimento | Quem e clipe | Fala (chave · texto) |
|---|---|---|---|---|---|
| 1 | 3.0 | `M4_Cart` [3, 1.8, 3] · olha `M4_Cart` [0, 0.8, 0] | dolly | pup `jump_happy` em `M4_Cart` | `ep01.narrator.m4.crates` (narrator) · Pulo! O filhote derrubou os caixotes! |
| 2 | 3.5 | `M4_Cart` [2, 1.4, 2.5] → `M4_Cart` [1.5, 1.2, 2.0] · olha `M4_Cart` [0, 0.8, 0] | dolly | — | `ep01.narrator.m4.vendor` (narrator) · Dona Amora precisa de ajuda na feira. |

### `m5_intro` · quando: `M5.start` · 6.5 s · sai olhando `M5_FeatherTrail_1` [0, 0, 0]

| # | s | Câmera (de → para · olha) | Movimento | Quem e clipe | Fala (chave · texto) |
|---|---|---|---|---|---|
| 1 | 3.0 | `M5_FeatherTrail_1` [2, 1.5, 3] · olha `M5_ShedRoof` [0, 0.5, 0] | dolly | pup `bark` em `M5_FeatherTrail_1` | `ep01.narrator.m5.gull` (narrator) · O filhote correu atrás da gaivota! |
| 2 | 3.5 | `M5_FeatherTrail_1` [1.5, 1.2, 2] · olha `M5_ShedRoof` [0, 0.5, 0] → `M5_FeatherTrail_1` [0, 0, 0] | pan | — | `ep01.narrator.m5.feathers` (narrator) · Ela fugiu com um peixe. Veja as penas! |

### `m6_intro` · quando: `M6.start` · 6.5 s · sai olhando `M6_BoatStart` [0, 1, 0]

| # | s | Câmera (de → para · olha) | Movimento | Quem e clipe | Fala (chave · texto) |
|---|---|---|---|---|---|
| 1 | 3.0 | `M6_Dinghy` [-4, 3, 4] · olha `M6_Dinghy` [0, 0.8, 0] | dolly | captain `wave` em `M6_Dinghy` | `ep01.bay.captain.stuck` (captain) · Ei! Meu bote encalhou! |
| 2 | 3.5 | `M6_BoatStart` [-3, 2.5, 5] · olha `M6_BoatStart` [0, 1, 0] | dolly | — | `ep01.narrator.m6.boat` (narrator) · Nosso barco espera no cais. |

### `boat_departure` · quando: `M6.board.done` · 6.0 s · sai olhando `M6_BuoyA` [0, 0.5, 0]

| # | s | Câmera (de → para · olha) | Movimento | Quem e clipe | Fala (chave · texto) |
|---|---|---|---|---|---|
| 1 | 3.0 | `M6_BoatStart` [-4, 3, 6] · olha `M6_BoatStart` [0, 1, 0] | dolly | pilot `idle_wheel` em `M6_BoatStart` | `ep01.narrator.boat.go` (narrator) · Leme liga o barco. Para o mar! |
| 2 | 3.0 | `M6_BoatStart` [-2, 3, 4] · olha `M6_BoatStart` [0, 1, 0] → `M6_BuoyA` [0, 0.5, 0] | pan | — | — |

### `m7_intro` · quando: `M7.start` · 6.5 s · sai olhando `M7_Lens` [0, 0, 0]

| # | s | Câmera (de → para · olha) | Movimento | Quem e clipe | Fala (chave · texto) |
|---|---|---|---|---|---|
| 1 | 3.0 | `M7_Lens` [-3, 2, 3] · olha `M7_Gallery` [0, 0.5, 0] | dolly | pup `bark` em `M7_Gallery` | `ep01.narrator.m7.pup_up` (narrator) · O filhote subiu no farol sozinho! |
| 2 | 3.5 | `M7_Lens` [-2, 1.2, 2] · olha `M7_Gallery` [0, 0.5, 0] → `M7_Lens` [0, 0, 0] | pan | — | `ep01.narrator.m7.lens` (narrator) · E a lente do farol caiu na grama. |

### `lighthouse_climb` · quando: `M7.climb.done` · 5.0 s · sai olhando `M7_StairStep` [0, 1, 0]

| # | s | Câmera (de → para · olha) | Movimento | Quem e clipe | Fala (chave · texto) |
|---|---|---|---|---|---|
| 1 | 2.5 | `M7_Landing_1` [-3, 1, 3] → `M7_Landing_3` [-3, 2, 3] · olha `M7_Gallery` [0, 1, 0] | dolly | climber `celebrate` em `M7_Gallery`, pup `wag` em `M7_Gallery` | `ep01.narrator.climb.top` (narrator) · Pico chegou lá no alto! |
| 2 | 2.5 | `M7_Gallery` [-2, 1.5, 2] · olha `M7_Gallery` [0, 1, 0] → `M7_FestaBoat_1_star` [0, 0.3, 0] | pan | — | `ep01.narrator.climb.boats` (narrator) · Lá embaixo, barquinhos esperam luz. |

### `nightfall` · quando: `M7.done` · 8.0 s · sai olhando `M8_FestaPlaza` [0, 1, -1]

| # | s | Câmera (de → para · olha) | Movimento | Quem e clipe | Fala (chave · texto) |
|---|---|---|---|---|---|
| 1 | 4.0 | `M7_LanternPivot` [-12, -4, 12] · olha `M7_LanternPivot` [0, 0, 0] | orbit | — | `ep01.narrator.night.sunset` (narrator) · O sol se põe atrás do mar. |
| 2 | 4.0 | `M8_FestaPlaza` [6, 4, 6] → `M8_FestaPlaza` [4, 3, 4] · olha `M8_FestaPlaza` [0, 1, 0] | dolly | captain `idle` em `M8_FestaPlaza` | `ep01.narrator.night.lanterns` (narrator) · As lanternas acendem. É noite de festa! |

### `closing` · quando: `M8.done` · 11.0 s · sai olhando `M8_FestaPlaza` [0, 1, 0]

| # | s | Câmera (de → para · olha) | Movimento | Quem e clipe | Fala (chave · texto) |
|---|---|---|---|---|---|
| 1 | 3.5 | `M8_FestaPlaza` [3, 1.7, 2] · olha `M8_FestaPlaza` [0, 1.4, -1] | dolly | captain `thanks` em `M8_FestaPlaza` | `ep01.festival.captain.thanks_team` (captain) · Obrigado, Rota Brava! Vocês são demais! |
| 2 | 4.0 | `M8_FestaPlaza` [0, 1.6, 4] · olha `M8_FestaPlaza` [0, 1, 0.9] | dolly | tracker `celebrate` em `M8_FestaPlaza`, climber `celebrate` em `M8_FestaPlaza`, pilot `celebrate` em `M8_FestaPlaza`, pup `wag` em `M8_FestaPlaza` | `ep01.narrator.end.saved` (narrator) · A Rota Brava salvou a Festa das Lanternas! |
| 3 | 3.5 | `M8_FestaPlaza` [4, 3, 6] → `M8_FestaPlaza` [10, 8, 12] · olha `M8_FestaPlaza` [0, 1, 0] | dolly | — | `ep01.narrator.end.bye` (narrator) · Até a próxima aventura! |


## 5. Direção de voz das falas novas (formato do `direction.json` → `lines`)
Para o `audio` incorporar. Variantes dos grupos usam a direção do grupo.

```json
{
 "lines": {
  "ep01.dock.tracker.look_paw": {
   "emotion": "descoberta animada",
   "energy": 2,
   "pace": "normal",
   "note": "aponta a tábua ao lado do barco, convida a olhar"
  },
  "ep01.dock.tracker.boot_steps": {
   "emotion": "curiosidade",
   "energy": 2,
   "pace": "normal",
   "note": "segue as botas com o dedo até o poste vazio"
  },
  "ep01.dock.tracker.follow_paws": {
   "emotion": "chamado animado",
   "energy": 2,
   "pace": "rápido",
   "note": "mostra o caminho das patinhas, vamos juntos"
  },
  "ep01.bank.tracker.pup_to_line": {
   "emotion": "surpresa divertida",
   "energy": 3,
   "pace": "rápido",
   "note": "viu o filhote correndo ao longe, meio rindo"
  },
  "ep01.bank.climber.cloth_on_shed": {
   "emotion": "empolgação",
   "energy": 3,
   "pace": "normal",
   "note": "olha para cima, já pensando em subir"
  },
  "ep01.bank.tracker.cloth_reeds": {
   "emotion": "descoberta atenta",
   "energy": 2,
   "pace": "normal",
   "note": "aponta o capim junto da água"
  },
  "ep01.bank.pilot.hang_line": {
   "emotion": "confiança",
   "energy": 2,
   "pace": "normal",
   "note": "organiza a equipe, tranquila"
  },
  "ep01.bank.tracker.paws_to_fountain": {
   "emotion": "chamado animado",
   "energy": 2,
   "pace": "rápido",
   "note": "a trilha continua; puxa a equipe para a praça"
  },
  "ep01.plaza.tracker.see_channel": {
   "emotion": "atenção",
   "energy": 2,
   "pace": "normal",
   "note": "agachada, mostra o chão"
  },
  "ep01.plaza.climber.leaves_top": {
   "emotion": "empolgação",
   "energy": 3,
   "pace": "rápido",
   "note": "olha para o alto, pronto para subir"
  },
  "ep01.plaza.tracker.see_market": {
   "emotion": "curiosidade",
   "energy": 2,
   "pace": "normal",
   "note": "ouviu a feirante, aponta as barracas"
  },
  "ep01.market.tracker.see_cart": {
   "emotion": "atenção",
   "energy": 2,
   "pace": "normal",
   "note": "aponta o carrinho e as cores"
  },
  "ep01.market.pilot.see_stalls": {
   "emotion": "confiança",
   "energy": 2,
   "pace": "normal",
   "note": "explica o jogo das cores com calma"
  },
  "ep01.street.tracker.see_feathers": {
   "emotion": "descoberta animada",
   "energy": 2,
   "pace": "normal",
   "note": "aponta a primeira pena no chão"
  },
  "ep01.street.pilot.see_vane": {
   "emotion": "confiança",
   "energy": 2,
   "pace": "normal",
   "note": "aponta o cata-vento, segura"
  },
  "ep01.street.climber.gull_roof": {
   "emotion": "empolgação",
   "energy": 3,
   "pace": "rápido",
   "note": "olha para cima, quer subir já"
  },
  "ep01.bay.pilot.see_boat": {
   "emotion": "decisão animada",
   "energy": 2,
   "pace": "normal",
   "note": "aponta o barco, pronta para pilotar"
  },
  "ep01.bay.pilot.see_buoys": {
   "emotion": "atenção calma",
   "energy": 2,
   "pace": "normal",
   "note": "do leme, aponta as boias da rota"
  },
  "ep01.bay.pilot.see_dinghy": {
   "emotion": "surpresa curiosa",
   "energy": 2,
   "pace": "normal",
   "note": "achou o bote, sem susto"
  },
  "ep01.bay.climber.rope_dinghy": {
   "emotion": "coragem alegre",
   "energy": 3,
   "pace": "normal",
   "note": "pega a corda, confiante"
  },
  "ep01.lighthouse.tracker.go_lighthouse": {
   "emotion": "chamado animado",
   "energy": 2,
   "pace": "rápido",
   "note": "a trilha vai para o farol, puxa a equipe"
  },
  "ep01.lighthouse.tracker.lens_bush": {
   "emotion": "descoberta atenta",
   "energy": 1,
   "pace": "lento",
   "note": "viu um brilho, quase sussurrando"
  },
  "ep01.lighthouse.climber.pup_top": {
   "emotion": "cuidado animado",
   "energy": 2,
   "pace": "normal",
   "note": "olha para o alto, vai buscar o amigo"
  },
  "ep01.lighthouse.pilot.see_boats": {
   "emotion": "encanto",
   "energy": 2,
   "pace": "lento",
   "note": "olha o mar de cima, admirada"
  },
  "ep01.festival.tracker.see_captain": {
   "emotion": "alegria",
   "energy": 2,
   "pace": "normal",
   "note": "avista o capitão na praça iluminada"
  },
  "ep01.narrator.intro.village": {
   "emotion": "narração animada",
   "energy": 2,
   "pace": "normal",
   "note": "narrador de desenho infantil, claro e caloroso, aponta o que aparece"
  },
  "ep01.narrator.intro.team": {
   "emotion": "narração animada",
   "energy": 2,
   "pace": "normal",
   "note": "narrador de desenho infantil, claro e caloroso, aponta o que aparece"
  },
  "ep01.narrator.intro.tracker": {
   "emotion": "narração animada",
   "energy": 2,
   "pace": "normal",
   "note": "narrador de desenho infantil, claro e caloroso, aponta o que aparece"
  },
  "ep01.intro.tracker.hello": {
   "emotion": "orgulho alegre",
   "energy": 3,
   "pace": "normal",
   "note": "se apresenta para a câmera, confiante, sorriso aberto"
  },
  "ep01.narrator.intro.climber": {
   "emotion": "narração animada",
   "energy": 2,
   "pace": "normal",
   "note": "narrador de desenho infantil, claro e caloroso, aponta o que aparece"
  },
  "ep01.intro.climber.hello": {
   "emotion": "empolgação",
   "energy": 3,
   "pace": "rápido",
   "note": "se apresenta pulando, vibrante"
  },
  "ep01.narrator.intro.pilot": {
   "emotion": "narração animada",
   "energy": 2,
   "pace": "normal",
   "note": "narrador de desenho infantil, claro e caloroso, aponta o que aparece"
  },
  "ep01.intro.pilot.hello": {
   "emotion": "confiança alegre",
   "energy": 2,
   "pace": "normal",
   "note": "ajeita os fones e se apresenta, segura"
  },
  "ep01.radio.intro.hello": {
   "emotion": "alegria",
   "energy": 2,
   "pace": "normal",
   "note": "voz amiga do rádio, acolhe a equipe"
  },
  "ep01.narrator.intro.call": {
   "emotion": "chamado heroico",
   "energy": 3,
   "pace": "normal",
   "note": "grito de abertura de desenho, convida para a aventura"
  },
  "ep01.narrator.opening.village": {
   "emotion": "narração animada",
   "energy": 2,
   "pace": "normal",
   "note": "narrador de desenho infantil, claro e caloroso, aponta o que aparece"
  },
  "ep01.narrator.opening.team": {
   "emotion": "narração animada",
   "energy": 2,
   "pace": "normal",
   "note": "narrador de desenho infantil, claro e caloroso, aponta o que aparece"
  },
  "ep01.narrator.opening.empty_boat": {
   "emotion": "narração animada",
   "energy": 2,
   "pace": "normal",
   "note": "narrador de desenho infantil, claro e caloroso, aponta o que aparece"
  },
  "ep01.narrator.m1.pup_runs": {
   "emotion": "travessura divertida",
   "energy": 2,
   "pace": "normal",
   "note": "conta a arte do filhote como quem ri, nada grave"
  },
  "ep01.narrator.m1.paw": {
   "emotion": "narração animada",
   "energy": 2,
   "pace": "normal",
   "note": "narrador de desenho infantil, claro e caloroso, aponta o que aparece"
  },
  "ep01.narrator.m2.pup_line": {
   "emotion": "travessura divertida",
   "energy": 2,
   "pace": "normal",
   "note": "conta a arte do filhote como quem ri, nada grave"
  },
  "ep01.narrator.m2.wind": {
   "emotion": "narração animada",
   "energy": 2,
   "pace": "normal",
   "note": "narrador de desenho infantil, claro e caloroso, aponta o que aparece"
  },
  "ep01.narrator.m3.ball": {
   "emotion": "travessura divertida",
   "energy": 2,
   "pace": "normal",
   "note": "conta a arte do filhote como quem ri, nada grave"
  },
  "ep01.narrator.m3.no_water": {
   "emotion": "narração animada",
   "energy": 2,
   "pace": "normal",
   "note": "narrador de desenho infantil, claro e caloroso, aponta o que aparece"
  },
  "ep01.narrator.m4.crates": {
   "emotion": "travessura divertida",
   "energy": 2,
   "pace": "normal",
   "note": "conta a arte do filhote como quem ri, nada grave"
  },
  "ep01.narrator.m4.vendor": {
   "emotion": "narração animada",
   "energy": 2,
   "pace": "normal",
   "note": "narrador de desenho infantil, claro e caloroso, aponta o que aparece"
  },
  "ep01.narrator.m5.gull": {
   "emotion": "travessura divertida",
   "energy": 2,
   "pace": "normal",
   "note": "conta a arte do filhote como quem ri, nada grave"
  },
  "ep01.narrator.m5.feathers": {
   "emotion": "narração animada",
   "energy": 2,
   "pace": "normal",
   "note": "narrador de desenho infantil, claro e caloroso, aponta o que aparece"
  },
  "ep01.bay.captain.stuck": {
   "emotion": "surpresa bem-humorada",
   "energy": 2,
   "pace": "normal",
   "note": "acena do bote, sem medo, até rindo"
  },
  "ep01.narrator.m6.boat": {
   "emotion": "narração animada",
   "energy": 2,
   "pace": "normal",
   "note": "narrador de desenho infantil, claro e caloroso, aponta o que aparece"
  },
  "ep01.narrator.boat.go": {
   "emotion": "narração animada",
   "energy": 2,
   "pace": "normal",
   "note": "narrador de desenho infantil, claro e caloroso, aponta o que aparece"
  },
  "ep01.narrator.m7.pup_up": {
   "emotion": "travessura divertida",
   "energy": 2,
   "pace": "normal",
   "note": "conta a arte do filhote como quem ri, nada grave"
  },
  "ep01.narrator.m7.lens": {
   "emotion": "narração animada",
   "energy": 2,
   "pace": "normal",
   "note": "narrador de desenho infantil, claro e caloroso, aponta o que aparece"
  },
  "ep01.narrator.climb.top": {
   "emotion": "narração animada",
   "energy": 2,
   "pace": "normal",
   "note": "narrador de desenho infantil, claro e caloroso, aponta o que aparece"
  },
  "ep01.narrator.climb.boats": {
   "emotion": "narração animada",
   "energy": 2,
   "pace": "normal",
   "note": "narrador de desenho infantil, claro e caloroso, aponta o que aparece"
  },
  "ep01.narrator.night.sunset": {
   "emotion": "calma encantada",
   "energy": 1,
   "pace": "lento",
   "note": "o dia acaba, voz suave"
  },
  "ep01.narrator.night.lanterns": {
   "emotion": "narração animada",
   "energy": 2,
   "pace": "normal",
   "note": "narrador de desenho infantil, claro e caloroso, aponta o que aparece"
  },
  "ep01.festival.captain.thanks_team": {
   "emotion": "gratidão",
   "energy": 2,
   "pace": "lento",
   "note": "agradece de coração, voz quente"
  },
  "ep01.narrator.end.saved": {
   "emotion": "narração animada",
   "energy": 2,
   "pace": "normal",
   "note": "narrador de desenho infantil, claro e caloroso, aponta o que aparece"
  },
  "ep01.narrator.end.bye": {
   "emotion": "carinho",
   "energy": 2,
   "pace": "lento",
   "note": "despedida de fim de episódio, sorriso"
  }
 }
}
```
