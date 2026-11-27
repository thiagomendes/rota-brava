# G24e · Roteiro do Ep01 v3: fio condutor entre as missões

Proposta do `adventure` (RB-R1, linha G24e). **Só documento**: nada aplicado em código, cenas, catálogo ou vozes. Thiago aprova antes de qualquer implementação.

Base lida: `SPEC.md` (seções 1 a 3), `ep01_v3_missions.json`, `ep01_v3_dialogue.json` (`mission_start`, `step_start`, `step_done`, `mission_done`, `travel`, `script`), `ep01_v3_cutscenes.json`, `game/i18n/pt_BR*.json`, `docs/proposals/ep01_v3_cutscenes.md`, `docs/proposals/g21_farol7.md`. Dos scripts `ep01_v3_land.gd`/`ep01_v3_late.gd` conferi só os eventos (`notify_mission`) que fecham cada etapa; não li a lógica inteira.

Decisões que já valem: Farol 7 é a base, operada pelo **Lumi** (homem; o G21 descreve uma mulher, aqui vale "o Lumi"); vila = **Vila Maré**; final = **Noite das Lanternas**; personagens em balbucio + legenda + ícones; narrador e Lumi em TTS.

Retorno de Thiago que motiva o ticket: *"É muito solto, do nada. Vamos ali ver um varal, mas tem uma bota no chão. Parece que não tem conexão as coisas."* E antes: *"mais storytelling e conexão entre missões, mais interação do narrador, tipo Patrulha Canina"*.

---

## 1. Diagnóstico missão a missão

Legenda da coluna "Conexão": **OK** liga bem · **fraca** liga por fala solta · **QUEBRA** a criança não entende por que está ali.

| Missão | O que a criança faz | Por que faz (visão da criança) | O que causa | Gancho para a próxima | Conexão |
|---|---|---|---|---|---|
| **M0** Olhe o barco | Anda até o banco do cais | "O barco chegou sem o capitão" (`ep01.arrival.pilot.no_captain`) | Nada no mundo; só abre o M1 | "Toda pista começa no chão" | fraca: o rádio fala da festa e o piloto do capitão, dois assuntos na mesma abertura, nenhum vira objetivo ("achar o capitão para quê?") |
| **M1** Duas trilhas | Examina pata, examina bota, segue 4 patas | Procurar o capitão | Revela: capitão saiu de bote; filhote correu | "Bora achar o filhote no varal" | **QUEBRA**: a criança veio pelo capitão, acha a bota dele e o jogo manda seguir o *filhote*. A bota abre um fio que some até o M5. É a bota da fala de Thiago |
| **M2** Varal | Pico solta 2 roupas no alto, Rastro acha a 3ª nos juncos, penduram 3 | "O filhote derrubou o varal" | Varal arrumado; meia com pelo | "Pegadinhas até o chafariz" | **QUEBRA**: arrumar roupa de alguém que não aparece não ajuda a achar ninguém. O "dono" do varal não existe, e a recompensa (pelo na meia) é pista que a criança já tinha (as patas) |
| **M3** Chafariz | Segue a canaleta seca, Pico tira folhas do alto | "O chafariz parou" | Água volta, bola rola para a feira | "A bola rolou para as barracas" + Amora chama | fraca: a causa (bola do filhote) é boa, mas chega como fala; o chafariz não importa para nada depois |
| **M4** Mercado | Lê ícones do carrinho, Leme entrega 3 caixotes por cor | Dona Amora pede ajuda | Barracas arrumadas; Amora conta da gaivota | "Olha ela lá, voando para a rua" | OK como pedido de ajuda (há uma pessoa); fraca como história: o filhote vira coadjuvante de uma gaivota |
| **M5** Gaivota | Segue penas, Leme lê o cata-vento, Pico pega o peixe no telhado | "A gaivota pegou um peixe" | Peixe recuperado (para quem?); do telhado, Pico vê o bote | Narrador: "Do telhado, o Pico viu o capitão!" | fraca → OK: a missão em si é desvio (o peixe não volta para ninguém em cena), mas o final religa o fio do capitão. É o melhor gancho do episódio, e chega tarde (minuto ~7) |
| **M6** Baía | Embarca, passa 2 boias, chega ao bote, Pico joga a corda | Salvar o capitão encalhado | Capitão a salvo; conta que o filhote subiu no farol | "Lá é bem alto. Oba!" / "a luz está apagada" | OK: primeira missão em que causa e motivo são claros |
| **M7** Farol | Rastro acha a lente, Pico resgata o filhote, Leme gira a luz para 4 barcos | Filhote no alto; farol apagado | Luz volta, barcos acendem, festa liberada | "Todos para a festa" | OK, mas a ameaça à festa ("sem luz, os barcos não chegam") **nunca foi anunciada antes**; a criança descobre o que estava em jogo no fim |
| **M8** Festa | Leva o filhote ao capitão | Devolver o filhote | Fim, agradecimento | — | OK |

### Onde e por que quebra (resumo)

1. **Dois problemas disputando o centro.** "Capitão sumiu" (M0) e "filhote bagunçando" (M1–M5) correm juntos sem hierarquia. A bota do M1 é uma promessa que o jogo esquece por 4 missões.
2. **O filhote é um antagonista invisível.** Ele causa M2, M3 e M4, mas a criança nunca o vê. Arrumar a bagunça dele parece faxina, não perseguição.
3. **A festa não está em risco até o M7.** O título do episódio é a Noite das Lanternas, mas nenhuma missão até o M6 contribui para ela.
4. **O rádio não chama.** O Farol 7 fala 3 vezes no episódio (abertura, M3, M7), sempre narrando o que já aconteceu. Não há o momento "problema → base chama → equipe parte", que é o que dá urgência no formato que Thiago citou.
5. **Recompensa sem acúmulo visível.** São 10 emblemas, mas nada no mundo cresce missão após missão; a criança não vê "estamos chegando".

---

## 2. Fio condutor proposto

### Problema central (uma frase para a criança)
> **"O filhote do capitão fugiu, e o capitão foi atrás dele. Sem o capitão, ninguém acende o farol, e os barcos não acham a Noite das Lanternas."**

Tudo o que a equipe faz serve a duas metas que se somam: **achar o filhote** (o fio de perseguição) e **juntar as lanternas da festa** (o progresso visível). O capitão deixa de ser um mistério paralelo: ele mesmo chama a base pelo rádio no começo ("meu filhote fugiu, vou atrás de bote"), então a bota do M1 **confirma** o que a criança já ouviu em vez de abrir outro assunto.

### Cadeia causal (cada missão termina com a pista da seguinte)

| Missão | Problema | Ação | Resultado que empurra para a próxima |
|---|---|---|---|
| M0 | Chamado do capitão pelo Lumi | Ir ao cais | Barco vazio confirma o chamado |
| M1 | Onde estão os dois? | Ler pata e bota | Bota: capitão foi de bote (pelo mar). Pata: filhote foi pela vila. "A gente segue o filhote; o capitão segue pelo mar." |
| M2 | O filhote puxou as **bandeirinhas da festa** (proposta média) ou o varal | Recuperar 3 peças e pendurar | Na 3ª peça, o **lenço do filhote** preso (pista nova, não repetida). 1ª lanterna |
| M3 | A bola do filhote entupiu o chafariz onde boiam as lanternas de água | Seguir canaleta, tirar folhas | Água volta, a bola rola **até a feira** (a criança vê). 2ª lanterna |
| M4 | O filhote derrubou os caixotes de **lanternas** de Dona Amora | Ler cores, entregar caixotes | Amora agradece com lanterna e conta: "ele foi atrás da gaivota". 3ª lanterna |
| M5 | Gaivota com o peixe (o filhote vai atrás dela) | Penas, cata-vento, telhado | Peixe volta para a Amora (fecha o laço). Do telhado, Pico vê o bote encalhado → **chamado 2** |
| M6 | Capitão encalhado | Barco, boias, corda | Capitão: "o filhote subiu no farol, e a luz está apagada!" → **chamado 3** (o Lumi vê a luz apagada do Farol 7) |
| M7 | Farol apagado, filhote no alto | Lente, escada, girar a luz | Barcos acendem; as lanternas juntadas acendem na praça |
| M8 | Devolver o filhote | Levar ao capitão | Capitão acende a lanterna principal: festa |

### Papel de cada personagem

| Quem | Papel no fio | Como aparece |
|---|---|---|
| **Lumi** (Farol 7, rádio, TTS) | Despachante e torcedor: recebe os chamados, diz o problema em uma frase, diz quem parte, comemora cada lanterna | 3 chamados fixos (M0, M5→M6, M6→M7) + 1 fala de lanterna no fim de M2, M3, M4 + dicas já existentes. Expressão "Na escuta!" só na abertura de chamado |
| **Capitão** (balbucio) | Quem pede ajuda no começo e quem acende a festa no fim. Prova que a equipe resolveu o problema de verdade | Voz no rádio no chamado 1 (balbucio + legenda, filtrada como rádio), resgate no M6, lanterna principal no M8 |
| **Dona Amora** (balbucio) | A vila que precisa de ajuda; dona das lanternas, ou seja, liga a feira à festa | M4 (pedido), M5 (recebe o peixe de volta), M8 (na festa, acena) |
| **Filhote** | Motor das missões, sempre **visto de relance** fugindo no fim de cada missão (cauda sumindo na esquina) | Aparição de 2–3 s em M1, M2, M3, M4 (média/completa); resgate no M7 |
| **Narrador** (TTS) | Liga uma missão à outra em uma frase ("e lá vai o filhote, rumo à praça!"); nunca repete o que o Lumi disse | Ponte no fim de cada missão (hoje só M1→M2 e M5→M6 no jogo, M2→M3 e M4→M5 nas cenas) |

### Momentos de "chamado" (formato próprio, sem copiar marca)
Estrutura fixa de 3 tempos, sempre igual para a criança reconhecer:
1. **Sinal**: o rádio do Farol 7 pisca e toca o bipe do rádio (G20 já existe).
2. **Lumi diz o problema** em 1 frase e **chama quem parte** pelo nome ("Leme, o barco é com você!").
3. **Grito da equipe**: o herói chamado responde com o bordão do trio ("Rota Brava, partiu!", balbucio + legenda). O bordão é nosso; não usar "nenhum trabalho é grande demais" nem estrutura de torre/elevador.

Chamados: **C1** abertura (capitão pede ajuda), **C2** fim do M5 (bote encalhado), **C3** fim do M6 (farol apagado, festa em risco).

### Recompensa e progresso visível
- **Varal de lanternas** na praça (o mesmo marco que a criança vê do M3): cada missão resolvida pendura uma lanterna apagada. No pôr do sol (cena `nightfall`) todas acendem de uma vez. É a consequência da própria intervenção que o SPEC pede.
- No HUD, ao lado dos emblemas, uma fileira de **5 lanternas** (M2, M3, M4, M5, M7) que se preenche; o Lumi diz "Mais uma lanterna!" em cada uma.
- Os 10 emblemas continuam; a lanterna é o progresso da história, o emblema é o do jogador.

---

## 3. Mudanças concretas

Custo: **P** até meio dia, só dado/catálogo · **M** 1 a 2 dias, cena curta ou objeto · **G** 3 dias ou mais, mundo/mecânica. "Voz" = falas novas ou reescritas que precisam de áudio (TTS para Lumi/narrador; balbucio sintetizado para personagens, que custa menos que voz Gemini).

**Sobre a ordem das missões:** a ordem M0–M8 segue a geografia da vila (cais → margem → praça → feira → rua → baía → farol). Trocar a ordem custa G (mundo, marcadores, bot) e não resolve a falta de conexão. Proponho **manter a ordem** e mudar a ordem das *falas* dentro das missões.

### 3.1 Falas (IDs propostos; textos com até 8 palavras)

| # | ID | Quem | Texto proposto | Substitui | Pacote |
|---|---|---|---|---|---|
| 1 | `ep01.call.c1.lumi_alert` | Lumi | Na escuta! O capitão chamou no rádio. | `ep01.arrival.radio.festival` | mín |
| 2 | `ep01.call.c1.captain_radio` | Capitão | Meu filhote fugiu! Vou atrás de bote! | nova | mín |
| 3 | `ep01.call.c1.lumi_stakes` | Lumi | Sem o capitão, o farol não acende! | nova | mín |
| 4 | `ep01.call.c1.lumi_go` | Lumi | Rastro, ache as pistas no cais! | `ep01.arrival.tracker.look_dock` (vira resposta) | mín |
| 5 | `ep01.call.team_go` | Rastro | Rota Brava, partiu! | nova (bordão, reusada em C2/C3) | mín |
| 6 | `ep01.dock.tracker.boot_captain` | Rastro | A bota do capitão vai até o bote! | reescrita | mín |
| 7 | `ep01.narrator.bridge.m1_m2` | Narrador | O capitão foi pelo mar. O filhote, pela vila! | reescrita | mín |
| 8 | `ep01.dock.climber.go_line` | Pico | A gente segue o filhote! | reescrita | mín |
| 9 | `ep01.bank.tracker.next_clue` | Rastro | O lenço do filhote! Ele foi à praça. | reescrita (troca "meia com pelo") | mín |
| 10 | `ep01.lumi.lantern_1` | Lumi | Varal salvo! Mais uma lanterna para a festa! | nova | mín |
| 11 | `ep01.lumi.lantern_2` | Lumi | Água de volta! Mais uma lanterna! | substitui `ep01.plaza.radio.water_back` | mín |
| 12 | `ep01.market.vendor.mess` | Amora | Ai, minhas lanternas da festa! | reescrita | mín |
| 13 | `ep01.market.vendor.gull_hint` | Amora | Tome uma lanterna! O filhote foi atrás da gaivota. | reescrita (10 palavras; dividir em 2 se passar no teste de leitura) | mín |
| 14 | `ep01.street.climber.fish_got` | Pico | Peguei! O peixe volta para a Dona Amora. | reescrita | mín |
| 15 | `ep01.call.c2.lumi_alert` | Lumi | Na escuta! O bote do capitão encalhou! | substitui `ep01.narrator.bridge.m5_m6` | mín |
| 16 | `ep01.call.c2.lumi_go` | Lumi | Leme, o barco é com você! | substitui `ep01.street.pilot.to_boat` | mín |
| 17 | `ep01.call.c3.lumi_alert` | Lumi | O farol apagou! Os barcos não acham a festa! | substitui `ep01.bay.pilot.lamp_dark` | mín |
| 18 | `ep01.call.c3.lumi_go` | Lumi | Pico, suba e salve o filhote! | nova | mín |
| 19 | `ep01.lumi.lanterns_lit` | Lumi | Todas as lanternas acesas! Que equipe! | substitui `ep01.lighthouse.radio.lights_on` | mín |
| 20 | `ep01.festival.captain.first_lantern` | Capitão | Obrigado! Agora eu acendo a primeira! | substitui `ep01.festival.captain.thanks` | mín |
| 21–24 | `ep01.narrator.pup_glimpse.m1..m4` | Narrador | "Lá vai ele, rumo à praça!" (uma por missão, destino diferente) | novas | méd |
| 25 | `ep01.narrator.bridge.m3_m4` | Narrador | A bola rola até a feira! | nova | méd |
| 26 | `ep01.bank.pilot.pup_clothes` | Leme | Ih! As bandeirinhas da festa caíram! | reescrita (só se trocar o objeto) | méd |
| 27 | `ep01.bank.pilot.m2_done` | Leme | Bandeirinhas no lugar! Que time! | reescrita (idem) | méd |
| 28 | `ep01.lumi.lantern_counter` | Lumi | Faltam só duas lanternas! | nova (varia por contagem: 3 variantes) | comp |

**Removidas ou cortadas** (no mínimo): `ep01.bank.tracker.sock_fur` (pista repetida), `ep01.arrival.climber.horn_alone` (abre um terceiro mistério que nunca fecha; a buzina já tem piada no final do SPEC), `ep01.arrival.pilot.boat_empty` (o chamado já explica). Três falas a menos para ler.

**Contagem de voz**
- Mínimo: 20 falas (13 Lumi/narrador em TTS; 7 balbucio: 2 capitão, 2 Amora, 3 trio). 3 cortadas.
- Médio: +7 (4 narrador pup_glimpse, 1 narrador ponte, 2 Leme) = 27.
- Completo: +3 variantes de contador do Lumi = 30, mais as falas de cena nova da seção 3.2.

### 3.2 Objetos e cenas

| # | Mudança | O que é | Custo | Voz nova | Pacote |
|---|---|---|---|---|---|
| O1 | Reordenar entradas em `mission_start`/`mission_done` conforme 3.1 (chamado antes, lanterna no fim) | dado em `ep01_v3_dialogue.json` | P | já contada | mín |
| O2 | Texto do título do M2 e do M1 ("Para onde foi o filhote?") | catálogo | P | 0 (títulos são texto + ícone) | mín |
| O3 | Cena curta **chamado** reutilizável (3,5 s): close no rádio do Lumi piscando + herói chamado vira para a câmera | 1 cena em `ep01_v3_cutscenes.json` com parâmetro de herói; usada 3 vezes | M | 0 além das falas 1–5, 15–18 | méd |
| O4 | **Relance do filhote** (2–3 s) no fim de M1–M4: filhote atravessa na direção da próxima missão | 4 planos curtos; o filhote já anda e corre (arte das cenas) | M | falas 21–24 | méd |
| O5 | **Lenço do filhote** preso na 3ª peça do M2 (troca da meia com pelo) | 1 prop pequeno + ícone | P | 0 | mín (sem o prop, só a fala) / méd (com prop) |
| O6 | **Varal de lanternas** na praça: 5 vagas, uma lanterna apagada aparece a cada missão; acende na `nightfall` | prop + estado salvo (`lanterns` no save) + cena | M | 0 | méd |
| O7 | Fileira de 5 lanternas no HUD | `ux` | P | 0 | méd |
| O8 | Varal de **roupas** vira varal de **bandeirinhas** da festa (mesma mecânica, peças trocadas) | `art3d` troca 3 peças + o G18 em curso | M | falas 26–27 | méd |
| O9 | Caixotes do M4 com **lanternas** visíveis dentro | `art3d`, troca de conteúdo do caixote | P/M | 0 | méd |
| O10 | Peixe entregue à Amora no fim do M5 (cena 3 s ou só fala) | cena curta ou fala 14 | P (fala) / M (cena) | 0 além da 14 | mín (fala) |
| O11 | Capitão acende a lanterna principal no `closing` | ajuste de plano na cena `closing` | M | fala 20 | comp |
| O12 | Lumi aparece em quadro (retrato no HUD durante o chamado; o `art3d` já tem o Lumi no G21/G23) | `ux` | P | 0 | méd |
| O13 | Contador falado do Lumi ("faltam duas") e lanterna extra escondida opcional por missão para quem explora | `gameplay` + `adventure` | G | 3 | comp |

### 3.3 Os três pacotes

| Pacote | Inclui | Custo total | Voz | O que resolve |
|---|---|---|---|---|
| **Mínimo** (só falas e ordem) | Falas 1–20, 3 cortes, O1, O2, O5 só fala, O10 só fala | ~1 dia (`adventure` + `gameplay` para religar chaves) | 20 falas (13 TTS, 7 balbucio) | Problema central claro em 30 s; a bota confirma em vez de confundir; chamados do Lumi; festa em risco desde o início; cada missão termina com a pista da seguinte. **Não resolve** o filhote invisível nem o progresso visível |
| **Médio** (+ cenas curtas) | Mínimo + O3, O4, O5 com prop, O6, O7, O8, O9, O12, falas 21–27 | +3 a 4 dias (`art3d`, `ux`, `gameplay`) | 27 falas | Filhote visto fugindo; lanternas penduradas que acendem à noite; M2 e M4 passam a ser "festa" e não "faxina" |
| **Completo** | Médio + O11, O13, fala 28, revisar as 21 dicas do Lumi para citar a lanterna da missão | +3 dias | ~30 falas + revisão de dicas (até 21 regravações) | Laço fechado (capitão acende a festa), exploração opcional recompensada |

---

## 4. Riscos para 4 a 8 anos

| Risco | Onde | Mitigação |
|---|---|---|
| **Leitura**: aos 4–6 anos a criança não lê a legenda | Chamados e pistas | Todo chamado tem ícone (rádio + rosto do herói chamado + ícone do problema: bote, farol); Lumi e narrador têm voz TTS. As falas em balbucio (capitão, Amora) precisam de ícone que diga o essencial sozinho (filhote, lanterna, bote) |
| **Tamanho das falas** | Falas 13 e 17 passam de 8 palavras | Dividir em 2 falas ou cortar; passar todas pelo tempo de leitura que o jogo já calcula |
| **Excesso de fala antes de jogar** | Abertura (C1) tem 5 falas | Cortamos 3 da abertura atual; o total fica igual ao de hoje (5 vs. 6). Teto: 15 s entre o fim da cena e o primeiro controle |
| **Medo/urgência demais** | "O farol apagou! Os barcos não acham a festa!" | Tom do Lumi calmo (traço do G21); o problema sempre vem com quem resolve na fala seguinte. Sem relógio na tela, sem perder |
| **Frustração com o "relance" do filhote** | O4: a criança pode tentar pegar o filhote | O relance é cena (sem controle), curta, e o narrador diz para onde ele foi; não há etapa de alcançar o filhote antes do M7 |
| **Confusão "segue o filhote ou o capitão?"** | M1 | A fala 7 dá a regra uma vez e a fala 8 decide ("a gente segue o filhote") |
| **Lanterna que não aparece** (O6) após retomar o jogo | Save | `lanterns` derivado das missões concluídas, não um contador à parte |

---

## 5. Perguntas para Thiago

**P1. Quanto entra agora?**
- (a) Mínimo hoje, médio amanhã com o lote de vozes.
- (b) Só o mínimo e revisar depois de jogar.
- (c) Médio inteiro de uma vez.
- **Recomendado: (a).** O mínimo cabe no build de hoje sem arte nova e já ataca o "do nada"; o médio depende de vozes de amanhã de qualquer jeito.

**P2. O varal do M2 continua de roupas ou vira bandeirinhas da festa?**
- (a) Roupas, com o lenço do filhote como pista (só fala/prop pequeno).
- (b) Bandeirinhas da festa (troca 3 peças; mexe na área do G18 em curso).
- **Recomendado: (b)**, depois que o G18 for integrado. É a mudança que mais liga uma missão "solta" à festa com o mesmo jogo.

**P3. Quem é o motor da história: o filhote fujão ou o capitão sumido?**
- (a) Filhote fujão; o capitão pede ajuda no rádio no começo (esta proposta).
- (b) Capitão sumido; o filhote vira ajudante que leva a equipe até ele (exige reescrever M2–M5 e é G).
- **Recomendado: (a).** Mantém todas as mecânicas e a ordem, e transforma a bota do M1 em confirmação em vez de mistério esquecido.
