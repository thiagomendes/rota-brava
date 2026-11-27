# Ep01 v3 · ações "por mágica" (auditoria G19 ampliado)

Ticket: `specs/features/RB-R1.md`, linha G19 e "G19 ampliado", passo 1. Base: `feature/rb-r1-reorientacao` em `fdda20c`.
Responsável pelo documento: `adventure`. Implementação: `art3d` (clipes) e `gameplay` (integração), nos passos 2 e 3.
Este documento é só auditoria e proposta. Nenhum código foi alterado.

## Resumo

- Li o código de M0 a M8: `ep01_v3_land.gd`, `ep01_v3_late.gd`, `ep01_v3_main.gd`, `ep01_v3_pieces.gd`, `ep01_v3_missions.json` e `ep01_v3_cutscenes.json`. Também li a lista de clipes de cada `.glb` v2 dos heróis. **Não rodei o bot.** Tudo aqui vem da leitura do código.
- Encontrei **41 interações** de M0 a M8, mais 3 que valem para o episódio todo.
- **24 são "mágicas":** o objeto voa sozinho por tween, some e aparece, ou o herói salta de ponto em ponto sem escalar.
- **7 são fracas:** têm gesto, mas o gesto é o errado ou genérico.
- As outras já se leem bem: examinar com o clipe certo, seguir uma pista, ou um efeito do mundo (a bola que rola, a lanterna que gira).
- Os três padrões que mais aparecem:
  1. **`_hop_chain`** (`ep01_v3_land.gd:686`): saltos de 0,42 s entre marcadores no lugar de toda subida e descida do Pico. Aparece em 9 lugares, contando ida e volta em M2, M3, M5 e M7.
  2. **`_fly`** (`ep01_v3_land.gd:652`): um tween de posição sem ninguém segurando. Move as roupas, as folhas, as caixas, o peixe e a lente.
  3. **`visible = false/true` e `queue_free`:** a lente some e reaparece na lanterna, as caixas são recriadas, os emblemas somem.
- Bugs vistos na leitura (entram na integração):
  - **Examinar vira apontar.** `_examine` (`ep01_v3_land.gd:677`) procura o clipe `inspect`. O Rastro v2 tem `inspect_touch`, então sempre cai em `crouch`. O Pico e a Leme não têm `inspect` nem `crouch` e caem em `point`.
  - **No M3**, o Pico tem o clipe `pull_rope`, mas o código não o usa para puxar as folhas.
  - **No M4**, `_deliver` (`ep01_v3_land.gd:631-636`) faz a caixa nascer 1 m acima do centro do carrinho, e não na posição dela. Depois, `_refresh_cargo` (`ep01_v3_land.gd:405`) apaga e recria todas as caixas restantes. É isso que Thiago vê como "some a caixa errada".
- Regra proposta para todas as ações:
  - um único "agir" dispara a ação, e um ímã de até 1,2 m põe o herói no ponto, sem pedir precisão;
  - o clipe dura de 0,6 a 1,5 s e o controle volta logo;
  - o objeto vai preso ao `HoldPoint` e termina num encaixe apoiado, sem flutuar;
  - a câmera só faz um plano curto quando a ação sai do enquadramento normal (no alto do farol, no reboque).
- Clipes que faltam além da lista em produção: `climb_down`, `push_cart`, `throw_rope`, `lower_rope`, `untie`, `inspect` para o Pico e a Leme (ou usar o `inspect_touch` do Rastro), `board_step`, `hold_compass`, `catch` e a pose do filhote na corda (`pup_harness`). O `pull_rope` do Pico já existe e pode ser reaproveitado.
- Ordem sugerida (detalhes no fim):
  1. M2: soltar, levar e pendurar as roupas.
  2. M4: a caixa certa sai do carrinho.
  3. O escalar do Pico em M2, M3, M5 e M7 (o mesmo trio de clipes serve a todos).

**Legenda**
- **Atual:**
  - **H** = salto `hop` encadeado;
  - **T** = tween sem ator (o objeto voa sozinho);
  - **S** = some e aparece, ou é recriado;
  - **X** = teleporte;
  - **G** = gesto genérico, sem o objeto;
  - **OK** = já se lê bem.
- **Impacto e custo:** A = alto, M = médio, B = baixo. Custo A = clipe novo, integração e teste.
- **Clipes:**
  - "novo" = ainda não existe;
  - "lista" = um dos clipes em produção agora (`pick_up`, `carry_*`, `place_high`, `place_low`, `climb_up`, `climb_wall`, `climb_top`);
  - "existe" = já está no `.glb` v2.
- **`HoldPoint`:** ainda não existe; os `.glb` v2 têm só os ossos `hand.L` e `hand.R`. Proponho `HoldPoint` na `hand.R` e `HoldPoint_L` na `hand.L`, para carregar com as duas mãos.

## M0 · Chegada ao cais

| # | Interação | Atual | Código | Herói faz | Clipe | HoldPoint | Duração | Câmera | Som | Imp. | Custo |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 0.1 | Chegar ao marcador | OK, anda até lá | `ep01_v3_main.gd:473` | Nada muda. | – | – | – | jogo | – | B | – |
| 0.2 | Trio posto no cais no início | X, escondido pela abertura | `ep01_v3_main.gd:263-267` | Nada muda: a cena `opening` cobre. | – | – | – | cena | – | B | – |

## M1 · Pistas no cais

| # | Interação | Atual | Código | Herói faz | Clipe | HoldPoint | Duração | Câmera | Som | Imp. | Custo |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1.1 | Examinar a pata no banco | G: `crouch` (procura `inspect`, que não existe) | `land.gd:547`, `land.gd:673-681` | O Rastro agacha, encosta o focinho e a mão, ergue a cabeça. | existe: `inspect_touch` (corrigir o nome procurado) | – | 0,8 s | jogo | farejo e "tic" de pista | M | B |
| 1.2 | Examinar a bota | G: `crouch` | `land.gd:551` | O Rastro agacha, pega a bota, olha e pousa de volta. | lista: `pick_up` e `place_low` (ou só `inspect_touch`) | `HoldPoint` (bota) | 1,2 s | jogo | couro e "tic" | M | M |
| 1.3 | Seguir as 4 pegadas | OK, pulso ao passar | `land.gd:556-560` | Nada muda. Opcional: farejar ao passar, só com a parte de cima do corpo. | existe: `inspect_touch` em camada, ou nada | – | 0 a 0,6 s, sem parar | jogo | farejo curto | B | B |

## M2 · O varal (pedido explícito de Thiago)

| # | Interação | Atual | Código | Herói faz | Clipe | HoldPoint | Duração | Câmera | Som | Imp. | Custo |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 2.1 | Subir no galpão | H: 3 saltos (degrau 1, degrau 2, topo) | `land.gd:561-562` | O Pico se agarra no caixote e no beiral, sobe com esforço e passa a perna por cima. | lista: `climb_up` no caixote, `climb_wall` e `climb_top` | – | 1,5 s (dois trechos de 0,7 e 0,8 s, sem parar) | jogo, câmera um pouco mais alta | arranhar de tênis e um "uf" balbuciado | A | A |
| 2.2 | Subir na árvore | H: 1 salto até o galho | `land.gd:563-564` | O Pico abraça o tronco, sobe e senta no galho. | lista: `climb_wall` e `climb_top` | – | 1,2 s | jogo | casca e folhas | A | M (mesmos clipes) |
| 2.3 | Soltar a roupa (galpão ou árvore) | T: a roupa voa 0,6 s do alto até o cesto no chão | `land.gd:565-570`, `_fly` em `land.gd:652` | O Pico estica o braço, solta a roupa do prego ou do galho e fica com ela na mão. | novo: `untie` (soltar no alto); depois lista: `carry_one_hand` | `HoldPoint` (roupa) | 0,9 s | jogo | tecido e um "plim" de achado | A | M |
| 2.4 | Descer do galpão ou da árvore com a roupa | H: salto até a base | `land.gd:573-574` | O Pico desce de costas pela parede, com a roupa no ombro ou na mão livre. | novo: `climb_down` (provisório: `climb_wall` invertido) | `HoldPoint` (roupa) | 1,2 s | jogo | tênis e queda leve no chão | A | M |
| 2.5 | Pôr a roupa no cesto | T (fundido com 2.3) | `land.gd:644-649` | Ao passar perto do cesto, um "agir": o herói se abaixa e solta a roupa dentro. | lista: `place_low` | do `HoldPoint` para o encaixe do cesto | 0,7 s | jogo | tecido no vime | M | B |
| 2.6 | Achar a roupa nos juncos | G e T: o Rastro agacha e a roupa voa até o cesto | `land.gd:575-578` | O Rastro abre os juncos, puxa a roupa e leva na mão até o cesto (ou direto ao varal). | existe: `inspect_touch`; lista: `pick_up` e `carry_one_hand` | `HoldPoint` | 1,0 s | jogo | juncos e água pingando | A | M |
| 2.7 | Pendurar as 3 roupas (3 "agir" no varal) | T: voa 0,45 s do cesto ao varal; ninguém pega nem pendura | `land.gd:581-590` | O herói pega uma roupa do cesto, dá dois passos, ergue os braços, prende no varal; a roupa balança. | lista: `pick_up`, `carry_one_hand` e `place_high` | do `HoldPoint` para o encaixe `LineSlot_n` | 1,4 s por roupa (pegar 0,5 s, pendurar 0,9 s); opcional: um "agir" pendura as 3 seguidas | jogo; plano curto de 1 s só na 3ª roupa | tecido, pregador "tec" e balanço ao vento | A | M |

## M3 · O chafariz

| # | Interação | Atual | Código | Herói faz | Clipe | HoldPoint | Duração | Câmera | Som | Imp. | Custo |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 3.1 | Seguir o filete (2 pontos) | G: `crouch` ou `point` | `land.gd:591-595` | O Rastro agacha e passa a mão na água. | existe: `inspect_touch` | – | 0,8 s | jogo | água | B | B |
| 3.2 | Subir no chafariz | H: 4 saltos (3 degraus e a bacia) | `land.gd:596-598` | O Pico sobe pela borda de pedra, mão no alto e pé na borda, e se ajeita na bacia. | lista: `climb_up` (degrau baixo) e `climb_top` | – | 1,3 s | jogo | pedra molhada e respingo | A | M |
| 3.3 | Puxar as folhas | T: as folhas voam 0,5 s até o chão; o Pico não faz nada | `land.gd:599-606` | O Pico agarra o bolo de folhas, dá dois puxões com esforço e joga para o lado. | existe: `pull_rope` (reusar), com `HoldPoint` | `HoldPoint` (folhas) até soltar | 1,2 s | jogo (a bola rolando já é o efeito) | folhas molhadas e o "glup" da água voltando | A | B |
| 3.4 | Descer do chafariz | H: 2 saltos | `land.gd:606` | O Pico desce pela borda. | novo: `climb_down` | – | 1,0 s | jogo | pedra | M | B (mesmo clipe de 2.4) |
| 3.5 | A bola rola para fora da grade | OK, rola com giro | `land.gd:657-666` | Nada muda. | – | – | 1,4 s | jogo | rolar e quique | B | – |

## M4 · As caixas da feira (pedido explícito de Thiago)

| # | Interação | Atual | Código | Herói faz | Clipe | HoldPoint | Duração | Câmera | Som | Imp. | Custo |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 4.1 | Ler os ícones das barracas | G: `crouch` | `land.gd:607-611` | O Rastro olha para cima e aponta cada placa (o anel já acende). | existe: `point` (melhor que `crouch`) | – | 0,8 s | jogo | "tic" em cada placa | B | B |
| 4.2 | Pegar o carrinho | T: o carrinho gruda à frente por lerp; a Leme anda normal | `land.gd:613-615`, `land.gd:420-422`, `land.gd:445-453` | A Leme segura a alça com as duas mãos e passa a andar empurrando. | novo: `push_cart` (andar de braços à frente; pode ser camada de cima do corpo sobre `walk`); entrada com um `pick_up` curto na alça (lista) | `HoldPoint` e `HoldPoint_L` na alça | 0,6 s para pegar; depois, enquanto empurra | jogo | rodinhas no calçamento, em loop enquanto anda | M | M |
| 4.3 | Entregar a caixa na barraca certa | S e T: a caixa nasce 1 m acima do carrinho e voa 0,5 s; todas as outras são recriadas | `land.gd:622-641`, `land.gd:405-414` | A Leme solta a alça, ergue a caixa certa **da posição dela no carrinho**, carrega dois passos e pousa no balcão; as outras não se mexem; ela volta à alça. | lista: `pick_up`, `carry_two_hands` e `place_low` (balcão) | `HoldPoint` e `HoldPoint_L` | 1,5 s (pegar 0,5 s, levar 0,4 s, pousar 0,6 s) | jogo | madeira no balcão e o "obrigado" da feirante em balbucio | A | M |
| 4.4 | Barraca errada | OK: fala, anel e ajuda; a caixa fica | `land.gd:623-628` | A Leme dá meio passo, a feirante aponta e a caixa nem sai. | existe: `point` na Amora | – | 0,6 s | jogo | "hum?" da feirante | B | B |
| 4.5 | Soltar o carrinho no fim | X: o carrinho fica onde estava | `land.gd:636-638`, `land.gd:424` | A Leme solta a alça e dá um tapinha no carrinho. | lista: `place_low` curto, ou nada | – | 0,5 s | jogo | as rodinhas param | B | B |

Requisito para 4.3:
- Cada caixa guarda o próprio índice, e a entrega retira só aquele nó. Hoje é sempre `get_child(0)`, e o `_refresh_cargo` recria tudo.
- Teste proposto: as caixas que ficam têm o mesmo `instance_id` e a mesma posição antes e depois da entrega.

## M5 · A gaivota e o peixe

| # | Interação | Atual | Código | Herói faz | Clipe | HoldPoint | Duração | Câmera | Som | Imp. | Custo |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 5.1 | Seguir as 4 penas | OK, pulso | `late.gd:371-375` | Nada muda. Opcional: pegar a 1ª pena e olhar. | opcional: lista `pick_up` | `HoldPoint` (pena) | 0,6 s | jogo | pena e "tic" | B | B |
| 5.2 | Ler o cata-vento | G: `point` (a Leme não tem `inspect`) | `late.gd:376-380` | A Leme põe a mão na testa, olha para cima e aponta o oeste. | existe: `point` (aceitável); opcional: um `look_up` novo para a Leme (o Pico já tem) | – | 0,8 s | jogo | rangido do cata-vento | B | B |
| 5.3 | Subir nos caixotes, no toldo e no telhado | H: 3 saltos | `late.gd:381-382` | O Pico sobe nos caixotes, se pendura no toldo e sobe no telhado. | lista: `climb_up`, `climb_wall` e `climb_top` | – | 1,5 s | jogo, com plano curto de 0,8 s no telhado (a gaivota sai do quadro) | lona, telha e "uf" | A | M |
| 5.4 | Pegar o peixe | T: o peixe voa 0,3 s até o peito do Pico | `late.gd:383-384`, `late.gd:420-441` | A gaivota foge (fica como está), o peixe cai na telha e o Pico se abaixa e pega. | lista: `pick_up` (opcional: `catch`, novo) | `HoldPoint` (peixe) | 0,8 s | jogo | asas, peixe na telha, "plaf" | A | B |
| 5.5 | Descer o peixe pela corda | T: a corda aparece pronta e o peixe desliza 0,9 s sozinho | `late.gd:443-451` | O Pico amarra o peixe na ponta e desce a corda mão a mão; a Leme recebe embaixo. | novo: `lower_rope` (provisório: `pull_rope` invertido); na Leme, lista `pick_up` | do `HoldPoint` do Pico para a corda, e dela para o `HoldPoint` da Leme | 1,5 s | jogo, câmera olhando para baixo | corda rangendo | A | M |
| 5.6 | Descer do telhado | H: 3 saltos | `late.gd:454` | O Pico desce pelo toldo e pelos caixotes. | novo: `climb_down` | – | 1,2 s | jogo | lona e madeira | M | B |

## M6 · O barco e o bote

| # | Interação | Atual | Código | Herói faz | Clipe | HoldPoint | Duração | Câmera | Som | Imp. | Custo |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 6.1 | Embarcar | X: `ride` põe a Leme e o Pico no barco na hora; a câmera troca | `late.gd:385-386`, `late.gd:483-496` | A Leme dá um passo largo do cais para o barco e o Pico pula atrás (o colete já estava nela). | novo: `board_step` (provisório: `jump` curto com pouso) | – | 1,0 s | plano curto de 1 s com o barco balançando, depois a vista de barco; a cena `boat_departure` pode absorver | casco, água, madeira | M | B |
| 6.2 | Passar pelas boias | OK, anel ao passar | `late.gd:387-391` | Nada muda. | – | – | – | jogo | sino de boia | B | – |
| 6.3 | Aproximar do bote | X e T: o barco desliza sozinho 1,4 s (atracação assistida) | `late.gd:392-393`, `late.gd:514-533` | Aceitável como ajuda; a Leme gira o leme durante os 1,4 s. | existe: `steer_left` e `steer_right` (hoje fica em `idle_wheel`) | – | 1,4 s | jogo | motor diminuindo | B | B |
| 6.4 | Jogar a corda para o bote | G e S: o Pico aponta e a corda aparece esticada da proa ao bote | `late.gd:394-395`, `late.gd:536-551` | O Pico gira a corda e lança; ela voa em arco; o capitão pega e amarra. | novo: `throw_rope` (Pico); capitão: `catch` ou só `thanks` | `HoldPoint` (rolo de corda) | 1,2 s | plano curto de 1,2 s de lado, com o bote no quadro | corda zunindo e "tchap" na água | A | M |
| 6.5 | Rebocar o bote | T: o barco e o bote recuam 2,4 s; ninguém segura | `late.gd:553-567` | O Pico segura a corda esticada e puxa com esforço; a Leme acelera. | existe: `pull_rope` (Pico) e `steer_*` (Leme) | `HoldPoint` na corda | 2,4 s, como hoje. Passa do teto, mas é a vez do barco e não há espera; dá para cortar para 1,5 s. | jogo | motor forçando, corda estalando | M | B |
| 6.6 | Voltar ao cais | X dentro do corte escuro-claro | `late.gd:569`, `late.gd:578-600`, `late.gd:603-614` | O corte fica; o desembarque passa a mostrar a Leme pulando para o cais. | opcional: `board_step` (novo) ao contrário | – | corte de 0,7 s e pulo de 0,6 s | corte | água | B | B |

## M7 · O farol

| # | Interação | Atual | Código | Herói faz | Clipe | HoldPoint | Duração | Câmera | Som | Imp. | Custo |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 7.1 | Achar a lente nos arbustos | T e S: a lente sobe 0,3 s sozinha e some em 0,4 s | `late.gd:396-403` | O Rastro abre o arbusto, pega a lente com as duas mãos, olha através dela (piscadela) e guarda na bolsa ou passa ao Pico. | existe: `inspect_touch`; lista: `pick_up` e `carry_two_hands` | `HoldPoint` e `HoldPoint_L` (lente) | 1,2 s | jogo | folhas e brilho de vidro | A | M |
| 7.2 | Subir a escada do farol | H: 6 saltos até a galeria | `late.gd:404-406` | O Pico sobe a escada externa com mãos e pés, lance por lance, e no alto passa por cima do parapeito. | lista: `climb_wall` (em loop pelos lances) e `climb_top` | – | 1,5 s (os lances acelerados em um plano) | plano curto de 1,5 s, de baixo para cima (o alto sai do quadro) | metal e "uf" | A | M |
| 7.3 | Pôr a lente na lanterna | S: a lente da cena some e o feixe liga | `late.gd:618-627` | O Pico tira a lente da bolsa, ergue, encaixa na lanterna, e a luz acende. | lista: `place_high` | do `HoldPoint` para o encaixe da lanterna (o `wv3_lens` reaparece ali) | 1,0 s | plano curto de 1 s na lanterna acendendo | "clic" de vidro e zumbido de luz | A | M |
| 7.4 | Descer o filhote pela corda | T: a corda aparece e o filhote desliza 1,2 s sozinho | `late.gd:628-636` | O Pico passa a corda no filhote, que fica com a pose de arnês, desce mão a mão, e o Rastro recebe embaixo. | novo: `lower_rope` (Pico) e `pup_harness` (filhote); Rastro: lista `pick_up` para receber | o filhote vai na corda | 1,5 s | plano curto de 1,5 s acompanhando a descida | corda e latido feliz | A | A |
| 7.5 | Descer a escada do farol | H: 6 saltos | `late.gd:638-639` | O Pico desce a escada. | novo: `climb_down` (em loop) | – | 1,5 s | jogo, ou um corte junto com a cena `lighthouse_climb` | metal | M | B |
| 7.6 | Mirar a lanterna (4 "agir") | G: a Leme aponta e a lanterna gira 0,6 s | `late.gd:409-410`, `late.gd:645-683` | A Leme segura a bússola à frente e gira o corpo para cada barquinho; a lanterna acompanha. | novo: `hold_compass` (pose segurando, sobre `idle`) | `HoldPoint` (a bússola `Ep01V3Pieces.compass` sai do pedestal para a mão) | 0,6 s por barquinho | jogo | tique da bússola e "ding" de luz | M | M |

## M8 · A festa

| # | Interação | Atual | Código | Herói faz | Clipe | HoldPoint | Duração | Câmera | Som | Imp. | Custo |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 8.1 | Ir até a praça | X dentro do corte | `late.gd:284-285` | Nada muda: o corte serve. | – | – | 0,7 s | corte | – | B | – |
| 8.2 | Agradecer ao capitão | G: `crouch` ou `point` | `late.gd:411-414` | O herói ativo acena e o capitão responde com `thanks`. | existe: `wave` (heróis) e `thanks` (capitão) | – | 1,0 s | jogo; depois vem a cena `closing` | balbucio alegre | M | B |

## Em todo o episódio

| # | Interação | Atual | Código | Herói faz | Clipe | HoldPoint | Duração | Câmera | Som | Imp. | Custo |
|---|---|---|---|---|---|---|---|---|---|---|---|
| G.1 | Pegar um dos 10 emblemas | S: anel e `queue_free` na hora | `land.gd:538-545` | O emblema voa curto para a mão; o herói ergue e guarda; o emblema some no fim. | lista: `pick_up` curto (pode ser só a camada de cima do corpo) | `HoldPoint` | 0,6 s | jogo | o "sting" atual | M | B |
| G.2 | Trocar de herói (chamar) | X: o herói chamado aparece ao lado se estiver a mais de 4 m | `ep01_v3_main.gd:633-634` | O herói entra correndo de fora do quadro até o ponto, no lugar do teleporte; depois, a pose de equipe que já existe. | existe: `run` | – | 0,6 a 1,0 s | jogo | passos e balbucio "tô aqui" | B | M |
| G.3 | Os seguidores alcançam o líder | X fora da câmera, por decisão de projeto (F1) | `ep01_v3_main.gd:676-678`, `ep01_v3_main.gd:712-721` | Fica como está: ninguém vê. | – | – | – | – | – | B | – |

## Toque e controle

- **Um "agir" dispara a sequência inteira:** subir, soltar e descer; ou pegar, levar e pousar.
- **Sem precisão:** um ímã de até 1,2 m alinha o herói ao ponto de partida (`face_now` com um passo curto). Os raios atuais dos pontos (1,1 a 3,0 m) continuam valendo.
- **Controle durante o clipe:**
  - o `busy` atual (`_set_busy`) só cobre o clipe, de 0,6 a 1,5 s;
  - entre as etapas o controle volta: com a roupa na mão, a criança anda até o cesto ou o varal;
  - a ajuda continua apontando o próximo alvo.
- **Objeto na mão:**
  - o herói anda com `carry_*` na camada de cima do corpo;
  - se a criança trocar de herói com um objeto na mão, o herói pousa o objeto no chão num ponto visível (`place_low`, 0,6 s), e nada some.
- **Cancelamento:** se a escalada for interrompida (hoje dispara `hop_aborted`), o herói volta ao pé da subida com `climb_down` e o ponto religa. Ninguém pode ficar travado no meio da parede.
- **Movimento reduzido** (`Options.reduced_motion`): sem os planos curtos de câmera; os clipes continuam no jogo.

## Clipes

Da lista em produção:

| Clipe | Usado em |
|---|---|
| `pick_up` | 1.2, 2.5, 2.6, 2.7, 4.3, 5.4, 5.5, 7.1, G.1 |
| `carry_one_hand` | 2.3, 2.6, 2.7 |
| `carry_two_hands` | 4.3, 7.1 |
| `place_high` | 2.7, 7.3 |
| `place_low` | 1.2, 2.5, 4.3, 4.5, troca de herói com objeto na mão |
| `climb_up` | 2.1, 3.2, 5.3 |
| `climb_wall` | 2.1, 2.2, 5.3, 7.2 |
| `climb_top` | 2.1, 2.2, 3.2, 5.3, 7.2 |

**Faltam além da lista:**
1. `climb_down` (Pico): todas as descidas, em 2.4, 3.4, 5.6 e 7.5. É o mais necessário: sem ele, toda descida continua aos pulos.
2. `push_cart` (Leme): andar com os braços à frente segurando a alça (4.2).
3. `throw_rope` (Pico): girar e lançar (6.4).
4. `lower_rope` (Pico): baixar algo mão a mão (5.5 e 7.4). Provisório: `pull_rope` invertido.
5. `untie` (Pico): soltar algo no alto com o braço esticado (2.3).
6. `inspect` para o Pico e a Leme, ou um `inspect_touch` igual ao do Rastro, para examinar não virar apontar. No caso do Rastro basta corrigir o nome no código.
7. `board_step` (Leme e Pico): passo largo do cais para o barco e de volta (6.1 e 6.6).
8. `hold_compass` (Leme): pose segurando a bússola (7.6).
9. `pup_harness` (filhote): pendurado na corda, de patas soltas (7.4).
10. Opcionais: `catch` (5.4 e 6.4) e `look_up` para a Leme (5.2).

**Já existem e dá para reusar:**
- `pull_rope` do Pico, nas folhas (3.3) e no reboque (6.5);
- `inspect_touch` do Rastro;
- `steer_left` e `steer_right` da Leme (6.3 e 6.5);
- `wave` dos heróis e `thanks` do capitão (8.2).

**Rig:** criar `HoldPoint` e `HoldPoint_L` como filhos de `hand.R` e `hand.L` nos três heróis.

## Ordem sugerida

| Ordem | O quê | Por quê | Depende de |
|---|---|---|---|
| 1 | M2 completo (2.3 a 2.7) | Exemplo de Thiago. Impacto A, custo M. | `pick_up`, `carry_one_hand`, `place_high`, `place_low`, `HoldPoint`, mais `untie` e `climb_down` |
| 2 | M4: entregar a caixa certa (4.3), corrigindo o `get_child(0)` e o `_refresh_cargo` | Exemplo de Thiago. Impacto A; código barato. | os mesmos clipes do item 1 |
| 3 | Escalar do Pico em todo o episódio: subidas 2.1, 2.2, 3.2, 5.3, 7.2 e descidas 2.4, 3.4, 5.6, 7.5 | Exemplo de Thiago. O trio `climb_*` e o `climb_down` servem a 9 pontos. | `climb_up`, `climb_wall`, `climb_top`, `climb_down` |
| 4 | Ganhos baratos: folhas com `pull_rope` (3.3); examinar com o clipe certo (1.1, 3.1, 7.1); acenar (8.2); Leme pilotando com `steer_*` (6.3, 6.5) | Custo baixo e todos os clipes já existem. | nada novo |
| 5 | Peixe e filhote (5.4, 5.5, 7.3, 7.4) | Impacto A, mas pede clipes novos e planos de câmera. | `lower_rope`, `pup_harness` |
| 6 | Corda do bote (6.4) | Precisa de `throw_rope` e de um plano curto. | `throw_rope` |
| 7 | Carrinho e bússola na mão (4.2, 7.6) | | `push_cart`, `hold_compass` |
| 8 | Detalhes: embarcar (6.1), emblema na mão (G.1), herói chamado chega correndo (G.2), bota na mão (1.2) | Impacto médio ou baixo. | `board_step` e clipes da lista |

Testes propostos para a integração:
- **Objeto na mão:** em toda ação de pegar ou levar, o objeto é filho do `HoldPoint` em algum quadro e termina apoiado. Um raio para baixo acha o encaixe a menos de 2 cm.
- **M4:** só a caixa entregue sai do carrinho; as outras mantêm o mesmo nó e a mesma posição.
- **Escalada:** nenhuma subida ou descida de missão chama `jump_to`.
- **Duração:** cada clipe fica entre 0,6 e 1,5 s, e o `busy` nunca passa de 1,6 s seguidos. A exceção declarada é o reboque (6.5).
- **Bot:** o bot M0 a M8 continua passando.
