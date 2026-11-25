# Ep01 v3 · Roteiro intuitivo: auditoria de primeira jogada (RB-R1, F2)

Status: **proposta** (`adventure`, 2026-11-25). Só documento: nada aqui altera código, cenas ou catálogo.
Origem: Thiago jogou o Ep01 v3 e disse: "na segunda pista, onde fala de uma bota, ele vai até o lugar e não tem bota alguma... e a terceira pista nem sei como encontrar".
Base: `game/episodes/ep01/v3/ep01_v3_missions.json`, `ep01_v3_land.gd`, `ep01_v3_late.gd`, `ep01_v3_pieces.gd`, `ep01_v3_main.gd`, `game/systems/mission/mission_help.gd`, marcadores de `game/worlds/village_v3/village_world.tscn`, catálogo `game/i18n/pt_BR.ep01v3.json`. Commit base: `6a9d504`.

## 0. Como foi verificado
- **Capturas do jogo real** (Vulkan por software, 1280×720, 25 quadros a 10 fps, último quadro), em `captures/f2/` (fora do Git):
  `xvfb-run -a -s "-screen 0 1600x900x24" bash tools/godot.sh --path game --rendering-driver vulkan res://episodes/ep01/v3/ep01_v3_main.tscn --write-movie <abs>/f.png --fixed-fps 10 --quit-after 25 -- --ep01v3-mission=Mx [--ep01v3-at=<marcador>] [--ep01v3-yaw=<graus>] [--ep01v3-help=3]`
  Abri cada imagem antes de descrevê-la. Limite: `--ep01v3-at` põe o trio no marcador com a missão no **primeiro passo**; os passos seguintes foram vistos pelo mundo (o que existe no lugar), não com o passo ativo.
- **Distâncias**: calculadas no plano XZ a partir das posições dos marcadores (não medidas andando). "Início" de cada missão = onde a anterior termina no jogo contínuo; o trio não é teleportado entre missões, exceto na festa (M8).
- **Ajuda atual** (`mission_help.gd`): degrau 1 aos 10 s parado (alvo pulsa uma vez com `FeedbackFx.pulse`, herói vira e aponta, fala curta `*.hint_gesture`); degrau 2 aos 20 s (Farol 7 no rádio); degrau 3 aos 35 s (seta amarela sobre o alvo e a câmera gira para ele).
- **Fato de base**: os pontos de ação (`Ep01Interactable`) são **invisíveis**. Só aparecem o botão "Examinar" e o ícone quando o herói já está a ≤ 1–2 m. Tudo o que a criança enxerga antes disso precisa ser um objeto do mundo ou uma peça montada pela missão.

## 1. Auditoria passo a passo

Legenda do veredito: **claro** (a criança vê o alvo e entende sem ler), **fraco** (existe, mas não é visível do ponto de partida ou não se destaca), **quebrado** (o objeto prometido não existe ou não dá para achar).

| Passo | O que o jogo pede (objetivo · fala · ícone) | Onde fica o alvo e o que existe de fato | Visível da câmera ao começar? Distância | Como a criança descobre hoje · o que falta | Veredito |
|---|---|---|---|---|---|
| **M1.bench** | "Duas trilhas no cais" · nenhuma fala ao começar · ícone pata | `M1_BenchClue` (0; −2,4), na beira do cais, colado ao barco. **Nada no lugar**: não há banco nem pegada; só o ponto invisível (`m1_b_banco.png`: o botão "Examinar" aparece em frente à cabine do barco) | Sim, a região do barco está no centro (`m1_a_inicio.png`), mas não há o que ver. 4,9 m | Só descobre quando passa por perto e o botão aparece, ou aos 35 s pela seta (`m1_h_bota_ajuda1.png`: seta sobre a cabine). A fala do rádio "olhe a pegada no **banco**" aponta para um banco que não está ali (o banco real mais perto fica a ~6 m, na margem). Falta: pegada de pata grande e visível (e o objeto "banco" de fato, ou trocar a fala) | **quebrado** |
| **M1.boot** | mesmo objetivo · nenhuma fala que aponte (as falas da bota vêm **depois** de examinar) · ícone bota | `M1_BootPrint` (−6; 10), no caminho de terra da margem, junto à cerca. **Não há bota nem pegada de bota**: `m1_d_bota.png` mostra só terra, grama e cerca. O código monta só o ponto invisível (`_spot(&"boot", ...)`, `ep01_v3_land.gd:210`); não existe decalque de bota em `worlds/village_v3/decals/` | Não. Do banco, olhando para lá (`m1_c_banco_olha_bota.png`), a cabine do barco tapa a vista. 13,8 m, atrás da câmera e virando à esquerda | Não descobre. O degrau 1 diz "Ali, na margem!" e o 2 diz "veja a **bota** na margem", mas ao chegar não há bota: **confirma o relato de Thiago**. Falta: bota real do capitão (objeto 3D) e pegadas de bota do cais até ela | **quebrado** |
| **M1.trail** (a "terceira pista") | mesmo objetivo · falas "A bota é do capitão" / "Duas trilhas! A pata é do filhote." · ícone pata | 4 pegadinhas `M1_PawTrail_1..4` de (1; 3,9) a (7,6; 8,3). Existem como `Sprite3D` deitado de **~0,2 m**, marrom sobre terra marrom (`_paw_decal`, `pixel_size 0.0016`). Em `m1_f_trilha1.png`, com o trio em cima da 1ª, **não dá para ver nenhuma** | Não. Da bota, a 1ª pegadinha fica a 9,3 m para o **leste**, de volta ao cais, na direção oposta à que o caminho segue (`m1_e_bota_olha_trilha.png`: só o caminho, o cais e o farol) | Não descobre: a pista é invisível, fica longe e na contramão, e nenhuma fala diz por onde ir ("A pata é do filhote" não aponta direção). **Confirma o relato de Thiago.** Falta: pegadas grandes e contrastadas (os decalques `decal_paw.tscn`, de 0,24 m, existem e não são usados), começando **junto** da bota e indo em linha até a margem | **quebrado** |
| **M2.free_pieces** | "O varal levado pelo vento" · "Ih! O filhote derrubou o varal!" + troca para Pico · ícone mosquetão | Roupa rosa no topo do galpão (11; 1,5; 10,7) e azul no galho (14,4; 1,7; 7,1): **peças reais** (`cloth_*` do props v3). O galpão é real | Não ao começar: a câmera olha para o cais (`m2_a_inicio.png`) e o galpão fica atrás, a 3,3 m. O cartão "Sua vez!" cobre o centro da tela | A fala diz o problema, mas não onde. Depois da troca, "as roupas estão lá no alto!" ajuda. Falta: mostrar o galpão com a roupa (olhar dirigido) e destacar a roupa | **fraco** |
| **M2.find_third** | · "Rastro, falta uma roupa. Cadê?" · ícone pata | Roupa amarela nos juncos (12,4; 3,6), peça real; 3 pegadinhas molhadas (`Sprite3D` azul) do cesto até lá | Os juncos ficam a 3,4 m, mas a roupa some no capim alto (em `m2_c_juncos.png`, com o trio no marcador, não a vi; vi o emblema da pata flutuando) | Pegadas molhadas pequenas demais (mesmo problema do M1). Falta: pegadas maiores e roupa com brilho | **fraco** |
| **M2.hang** | · "Pegadinha molhada! A roupa está nos juncos." · ícone corda | Varal real com roupas penduradas (`m2_d_varal.png`) | Sim, a ~3 m e alto o bastante para aparecer | Claro: o varal é grande e as roupas que faltam voltam por animação | **claro** |
| **M3.stream** | "O chafariz entupido" · "O chafariz parou. Cadê a água?" · ícone olhos | Canaleta real `M3_ChannelStart` (−24,3; 2,1) → grade com a bola presa (−26; 0,5): **objetos reais** (`m3_c_grade.png`: grade e bola visíveis) | **Não**: o M3 começa onde o M2 termina, na margem (x ≈ 11). O chafariz fica a **~36 m** a oeste, atrás de casas; em `m3_a_inicio.png` a câmera bate numa parede | A fala diz o problema, mas não onde. Nenhuma pista no caminho margem → praça. A meia com pelo do fim do M2 ("o filhote foi à praça") ajuda só quem lê. Falta: trilha entre missões (pegadinhas até a praça), olhar dirigido para o chafariz e ponto de partida mais perto | **quebrado** (deslocamento), passo em si **claro** quando se chega lá (`m3_b_filete.png`: chafariz e canaleta enquadrados) |
| **M3.leaves** | · troca para Pico · ícone folha | Folhas na bacia de cima (−22,4; 1,5; 3,7), peça real `fountain_leaves`, e degraus do chafariz | Sim, de perto: chafariz grande no quadro (`m3_b_filete.png`) | Claro depois de "lá no alto do chafariz", e a bacia está no quadro | **claro** |
| **M4.read** | "O mercado bagunçado" · Dona Amora: "Ai, minhas frutas! Que bagunça!" · ícone olhos | Carrinho com caixotes coloridos `M4_Cart` (−19,5; 1,2), objeto real | Não em `m4_a_inicio.png` (a câmera olha para a árvore da praça; o carrinho fica fora do quadro, a ~4 m). Dona Amora fala, mas não aparece no quadro | Dica "Olhe o carrinho!" só aos 10 s. Falta: olhar dirigido para o carrinho e a feirante apontando para ele | **fraco** |
| **M4.deliver** | · troca para Leme · ícone leme | 3 barracas reais com placa de cor provisória (círculo colorido, `stall_sign`) | Sim: barracas grandes e placas coloridas (`m4_b_barraca.png`) | Claro: cor do caixote = cor da placa. Entrega errada mostra a certa | **claro** |
| **M5.feathers** | "A gaivota com o peixe" · Pico: "A gaivota pegou um peixe da feira!" · ícone pata | 4 pontos `M5_FeatherTrail_4..1` na rua do mercado. **Não há penas no chão**: `_build_m5` monta só os pontos invisíveis (`ep01_v3_late.gd:181`); o decalque `decal_feather.tscn` existe e não é usado. `m5_b_pena1.png` e `m5_c_pena4.png`: chão de pedra sem pena | Não. A rua fica a ~10 m do mercado e a 1ª pena está a 1,5 m do ponto de partida, sem nada para ver | Só pelo botão ao passar em cima (são automáticos, raio 1 m) ou pela seta aos 35 s. Falta: penas visíveis (e a gaivota voando à frente, mostrando o rumo) | **quebrado** |
| **M5.compass** | · troca para Leme · ícone estrela | Cata-vento `M5_Weathervane` (−4,6; −15,6), no fim das penas | Não verifiquei de perto (sem captura com o passo ativo). Pelo código, é um ponto com raio 1,6 m; a peça do cata-vento é do mundo | "Olhe o cata-vento!" aos 10 s. Falta: destaque no alvo | **fraco** (não confirmado em imagem) |
| **M5.fish** | · troca para Pico · ícone mosquetão | Gaivota com peixe no telhado do galpão de redes (−19,6; 2,9; −18,6), peça real; caixotes e toldo reais (`m5_d_telhado.png`) | Não: do cata-vento, o galpão fica a ~15 m de volta pela rua, e a gaivota, 2,9 m acima, sai do quadro da câmera baixa (em `m5_d_telhado.png` ela não aparece) | A fala da Leme diz "oeste: o galpão de redes" (palavra que a criança não lê nem entende). Falta: gaivota grasnando e voando visivelmente até o telhado e olhar dirigido para cima | **fraco** |
| **M5 (retomada)** | — | Ao retomar o M5 pelo salvo (`--ep01v3-mission=M5`), a tela fica azul e o trio aparece minúsculo, visto de muito alto (`m5_a_inicio.png`; repetido com 60 quadros em `m5_a2_inicio_60f.png`) | — | Defeito de retomada, fora do roteiro, mas grave: a criança fica perdida. Para o `gameplay` investigar (`start_position(M5)` = pena 4 + (1,5; 0; 1)) | **quebrado** |
| **M6.board** | "Resgate na baía" · Rastro fala ao começar · troca para Leme · ícone barco | Barco v2 real atracado (`m6_a_inicio.png` no início por retomada) | No jogo contínuo, o M6 começa no telhado do galpão de redes, a **~27 m** do barco. Na retomada, o barco está no centro | Contínuo: falta mostrar o barco. Retomada: claro | **fraco** |
| **M6.buoys** | · ícone boia | 2 boias reais `wv3_buoy_a/b` na bacia, a ~10 m e ~7 m | Prováveis no quadro (boias grandes na água), mas há outras boias decorativas iguais (`m6_a_inicio.png` mostra 3) | Falta: anel/brilho só nas 2 boias da rota | **fraco** |
| **M6.approach / rope** | · ícone leme / corda | Bote real `wv3_dinghy` com o capitão, junto ao promontório, ~11 m | Não verificado em imagem (o render do M6 é lento; não há captura com o barco andando) | Pelo código, objetos reais. Falta: destaque e confirmar em imagem | **fraco** (não confirmado) |
| **M7.lens** | "A lanterna do farol" · Leme: "A lanterna do farol está apagada!" · ícone lupa | Lente real `wv3_lens` na grama do promontório (25,8; 2,3; −21,8), meio tapada por arbustos (`m7_b_lente.png`: o aro dourado aparece sob o arbusto) | **Não**: começa no cais (`m7_a_inicio.png`, câmera virada para a vila; o farol fica fora do quadro), a **~33 m** | A fala diz o problema, não onde. Falta: olhar dirigido para o farol, trilha até o promontório, lente fora do arbusto ou brilhando | **fraco** |
| **M7.climb** | · troca para Pico · ícone mosquetão | Escada externa real com patamares (`m7_c_escada.png`); filhote real no alto (7,8 m) | Ao pé da escada a câmera mostra o patamar; o filhote no alto sai do quadro | "Pico, o filhote está lá no alto!" ajuda. Falta: enquadrar o filhote lá em cima por 1–2 s | **fraco** |
| **M7.aim** | · troca para Leme · ícone estrela | Bússola real ao lado da escada; 4 barquinhos com ícone na água | Não verificado em imagem | Pelo código, objetos reais. Falta confirmar | **não verificado** |
| **M8.thanks** | "A festa no porto" · Farol 7: "A Festa das Lanternas começou!" · ícone coração | Capitão real a ~2 m, na praça iluminada (`m8_a_inicio.png`) | Sim, no quadro e perto | Claro | **claro** |

Resumo: 21 passos (mais a retomada do M5). **Quebrados 5** (M1.bench, M1.boot, M1.trail, deslocamento M2→M3, M5.feathers) + a retomada do M5; **fracos 11**; **claros 5**; **não verificados em imagem 1** (M7.aim), com 2 fracos sem imagem (M5.compass, M6.approach).

## 2. O padrão proposto: "Ver, ouvir, seguir"

Patrulha Canina e PJ Masks guiam sem texto do mesmo jeito: **o objeto está ali de verdade**, **a câmera mostra o objeto antes de pedir**, **um personagem fala e aponta**, e **um rastro liga uma coisa à outra**. Proponho as 6 opções juntas, em camadas, para **todos** os passos de M1–M8. Cada camada cobre uma falha diferente da tabela:

| # | Camada | Regra | Falha que corrige | Dono |
|---|---|---|---|---|
| P1 | **Objeto real no lugar** | Todo alvo de passo é um objeto 3D visível a ≥ 8 m da câmera baixa, com silhueta própria (sem ponto invisível sozinho). Pistas no chão com ≥ 0,45 m e contraste forte com o piso (pegada clara em terra, escura em pedra) | bota e pata inexistentes, penas inexistentes, pegadas de 0,2 m | `art3d` |
| P2 | **Olhar dirigido** | No início de cada passo (e depois de cada troca de herói), a câmera gira e enquadra o próximo alvo por **1,5 s** e volta ao herói. Pulável pelo jogador (qualquer movimento encerra). Com "movimento reduzido", corte seco em vez de giro | alvo atrás da câmera (M1.boot, M2, M4, M7), alvo no alto (M5.fish, M7.climb) | `gameplay` |
| P3 | **Anel de alvo** | O `target_ring` do props v3 (já tem a animação `pulse`) fica no chão sob o alvo ativo enquanto o passo durar; um só por vez; some ao concluir | boias iguais às decorativas, roupa perdida no capim, lente no arbusto | `gameplay` (usa a peça do `art3d`) |
| P4 | **Rastro entre pistas e entre missões** | Pegadinhas grandes (decalques `decal_paw`, `decal_paw_wet`, `decal_feather`, ampliados) a cada **1,5–2 m**, da pista atual à próxima, e **de uma missão à seguinte** (margem → praça, mercado → rua, galpão → cais, cais → farol). Cada pegada brilha ao ser pisada (som curto de "pista") | "terceira pista" sem caminho, 36 m até o chafariz, 33 m até o farol | `art3d` (decalques), `gameplay` (colocação e brilho) |
| P5 | **Fala que aponta + gesto** | Toda fala de início de passo diz **o objeto e o lugar com uma palavra visual** ("lá no barco", "perto da cerca", "no telhado"), e o herói aponta com o braço ao mesmo tempo. Nada de pontos cardeais | M1 sem fala inicial; "oeste" no M5; "pata é do filhote" sem direção | `adventure` (falas), `gameplay` (gesto) |
| P6 | **Ajuda mais cedo no início** | No **primeiro passo do episódio** (M1.bench) e no primeiro passo de cada missão: degraus a **5 / 12 / 20 s** em vez de 10 / 20 / 35 s. Nos demais passos, 8 / 16 / 28 s | criança parada sem saber o que fazer | `gameplay` |

Por que todas e não uma só: o olhar dirigido sozinho mostra um lugar vazio se o objeto não existe (é o caso da bota); o objeto sozinho não ajuda se está atrás da câmera; o rastro resolve o deslocamento longo, mas não diz o que fazer ao chegar. O custo de cada camada é pequeno e reaproveita peças que já existem (`target_ring`, decalques, `help_arrow`, `face_point` + animação de apontar).

### 2.1 Roteiro corrigido do M1 (modelo para as outras missões)
Fio mantido (`ep01_missoes_v3.md` §1): a pata do filhote vai para a vila, a bota do capitão vai para o bote.

| Passo | O que a criança vê e ouve |
|---|---|
| M1.bench | Câmera mostra por 1,5 s a **pegada de pata grande e lamacenta na tábua do cais**, ao lado do barco, com o anel pulsando. Rastro aponta: "Olha! Uma pegada no cais!" (`ep01.dock.tracker.look_paw`, nova). Se a fala do rádio continuar falando de "banco", o `art3d` põe um banquinho ali; senão o texto muda para "cais" |
| M1.boot | Ao examinar a pata, aparecem **3 pegadas de bota grandes** saindo do mesmo ponto para o oeste. A câmera mostra a **bota do capitão caída** junto à amarra vazia `M1_EmptyMooring` (−7,3; −2,7), a ~7 m, em vez de (−6; 10), que fica do outro lado do barco. Rastro: "Pegadas de bota! Vão para lá." (`ep01.dock.tracker.boot_steps`, nova) |
| M1.trail | Ao examinar a bota, Rastro conclui (falas existentes `boot_captain` e `two_trails`), a câmera gira e mostra as **pegadinhas de pata grandes, a cada 1,5 m, saindo da pata do cais** em direção à margem e ao varal. Rastro aponta: "As patinhas vão pela margem. Vamos!" (`ep01.dock.tracker.follow_paws`, nova). Ao final, o filhote aparece ao longe correndo para o varal (1 s) |

Mudança de marcadores pedida (decisão de `gameplay`/`art3d`, só proposta aqui): mover `M1_BootPrint` para perto de `M1_EmptyMooring`, que também conta a história (bote ausente), e iniciar `M1_PawTrail_1` a ≤ 2 m de `M1_BenchClue`.

### 2.2 Aplicação nas demais missões (resumo)
- **M2:** olhar dirigido para a roupa no galpão; anel sob cada roupa; pegadinhas molhadas maiores; filhote visto por 1 s fugindo para a praça no fim.
- **M2→M3:** trilha de pegadinhas da margem até a praça (~36 m, ~20 decalques) **ou** um corte de transição curto (fade, 1 s) que põe o trio na entrada da praça. Recomendo a trilha (é a fantasia de "seguir o filhote") com a câmera mostrando o chafariz ao chegar.
- **M4:** Dona Amora visível ao lado do carrinho, apontando; olhar dirigido para o carrinho.
- **M5:** penas grandes no chão, a gaivota passa voando por cima e pousa no telhado (o olhar dirigido acompanha); trocar "oeste" pela seta do cata-vento apontando para o galpão de redes e a fala "A seta aponta para o galpão de redes!".
- **M5→M6:** trilha ou olhar dirigido para o barco no cais (27 m).
- **M6:** anel só nas boias da rota; olhar para o bote encalhado ao sair do cais.
- **M6→M7 e M7.lens:** olhar dirigido para o farol; lente fora do arbusto ou com brilho; pegadinhas até o promontório.
- **M7.climb:** enquadrar o filhote no alto por 1,5 s.

## 3. Tarefas por agente

### `art3d`
1. **Bota do capitão** (objeto, ~0,3 m, cor forte, lê a 8 m da câmera baixa) para `props_v3`. Falta hoje.
2. **Pegadas de bota** (decalque, ~0,35 × 0,15 m, 3 variações).
3. **Pegada de pata "grande"**: versão de 0,45 m dos decalques `decal_paw`, `decal_paw_wet` e `decal_feather`, com contraste para terra, madeira e pedra (hoje 0,24 m e marrom sobre marrom).
4. **Pena grande 3D** (opcional, para a rua: 0,3 m, branca com ponta escura) se o decalque não ler na pedra.
5. Pegada de pata na tábua do cais (M1.bench) e, se a fala mantiver "banco", um banquinho junto ao barco.
6. Conferir o `target_ring` em grama alta e pedra (altura mínima para não sumir no capim).
Estimativa: média (6 peças pequenas, reuso dos decalques).

### `gameplay`
1. **Olhar dirigido** no início de cada passo e depois de cada troca (P2): `CameraRig` enquadra o alvo 1,5 s; respeita movimento reduzido; não durante a pilotagem.
2. **Anel de alvo** (P3) no alvo ativo, usando `Ep01V3Pieces` (novo `target_ring()` pelo ponto de troca).
3. **Rastros** (P4): instanciar decalques entre pistas e entre missões (M1 pata → margem, M2 → praça, M4 → rua, M5 → cais, cais → farol); brilho ao pisar.
4. **Mover** `M1_BootPrint` e `M1_PawTrail_1..4` conforme §2.1 (pedido ao dono dos marcadores, se for o `art3d`).
5. **Penas no M5** (hoje inexistentes) e gaivota em voo até o telhado.
6. **Ajuda mais cedo** (P6): `tier_times` por passo (5/12/20 s no primeiro passo de cada missão; 8/16/28 s nos demais).
7. **Gesto de apontar** junto com a fala de início de passo (P5).
8. **Defeito:** retomada do M5 mostra tela azul com o trio visto de muito alto (`captures/f2/m5_a_inicio.png`).
9. Teste: para cada passo de M1–M8, o alvo ativo tem um nó visível (não só `Ep01Interactable`) a ≤ 2 m, e existe rastro ou olhar dirigido quando a distância do início do passo for > 8 m.

### `adventure` (falas; catálogo `pt_BR.ep01v3.json` + `ep01_v3_dialogue.json`)
1. Fala de **início de passo** que aponta, para os 21 passos (hoje só há fala no início de algumas missões e nenhuma no M1). Chaves estáveis no padrão `ep01.<lugar>.<falante>.<ação>`, por exemplo `ep01.dock.tracker.look_paw`, `ep01.dock.tracker.boot_steps`, `ep01.dock.tracker.follow_paws`, `ep01.bank.climber.cloth_on_shed`, `ep01.plaza.tracker.paws_to_fountain`, `ep01.street.pilot.vane_points_shed`, `ep01.bay.pilot.see_dinghy`, `ep01.lighthouse.tracker.go_lighthouse`.
2. Revisar as dicas que prometem o que não existe ou usam conceitos abstratos: `ep01.radio.v3_m1.bench` ("banco"), `ep01.radio.v3_m1.boot` (a bota só existirá depois do art3d), `ep01.street.pilot.compass_west` ("oeste").
3. Atualizar este roteiro com o texto final de cada fala.
Estimativa: pequena a média (~25 falas novas + 3 revisões).

## 4. Impacto no tempo do episódio (estimativa, não medida)
- Olhar dirigido: 1,5 s × 21 passos + 6 trocas ≈ **+40 s**, que a criança pode pular.
- Rastros entre missões: não acrescentam caminho (o deslocamento já existe); **tiram** tempo de busca. Hoje, num deslocamento de 30–36 m sem pista, a criança fica parada até a ajuda de 35 s ou anda a esmo; estimo 30–60 s perdidos em cada um dos 4 trechos longos.
- Ajuda mais cedo e alvos visíveis: menos tempo parado nos 5 passos quebrados (hoje, no pior caso, a criança não termina o M1).
- Balanço estimado: **−1 a −3 min** de tempo perdido e **+40 s** de olhar dirigido. O ritmo humano estimado na E5 (~11 min) tende a cair para 9–10 min, **mais perto da meta de 8 min** e com o tempo gasto em jogar, não em procurar. Medir com o bot humano na E7.

## 5. Capturas desta auditoria (`captures/f2/`, fora do Git)
`m1_a_inicio`, `m1_b_banco`, `m1_c_banco_olha_bota`, `m1_d_bota`, `m1_e_bota_olha_trilha`, `m1_f_trilha1`, `m1_g_ajuda3`, `m1_h_bota_ajuda1` (na verdade, ajuda 3 no banco), `m2_a_inicio`, `m2_b_galpao`, `m2_c_juncos`, `m2_d_varal`, `m3_a_inicio`, `m3_b_filete`, `m3_c_grade`, `m4_a_inicio`, `m4_b_barraca`, `m5_a_inicio`, `m5_a2_inicio_60f`, `m5_b_pena1`, `m5_c_pena4`, `m5_d_telhado`, `m6_a_inicio`, `m7_a_inicio`, `m7_b_lente`, `m7_c_escada`, `m8_a_inicio` (todas .png).
Não capturado: M6 com o barco navegando, M7.aim e qualquer passo com o passo já ativo (exige avançar a missão; fica para o `gameplay` com o bot).
