# Ep01 v3 · Pontes entre missões (RB-R1 G9)

Status: proposta de texto do `adventure` (2026-11-26), já aplicada nos dados. Origem: Thiago achou que as missões chegam "do nada" ("vai lá e faz isso, vai lá e faz isso"). A meta é que cada missão termine com a equipe conversando sobre a pista e que o motivo para ir ao próximo lugar fique claro antes de a próxima missão começar.

Tempos são estimativas, não medidas. A legenda dura `max(2,4 s; 1,3 s + 0,055 s × caracteres)` (`hud.gd`), então uma fala de 35 caracteres fica cerca de 3,2 s na tela.

## 1. Como cada ponte acontece
Toda ponte segue a mesma forma, em três tempos:
1. **Fim da missão, com controle (conversa andando).** Logo depois do viva, a equipe fala 2 ou 3 réplicas sobre o que achou, às vezes com o narrador ou um morador. Ninguém perde o controle: a criança já pode andar.
   - Dados: `mission_done` em `ep01_v3_dialogue.json`.
   - Gancho: em `Ep01V3Main._cutscene_run`, a cena seguinte espera a conversa acabar, até no máximo `BRIDGE_WAIT_S` = 12 s. Antes, a cena de introdução limpava a legenda e cortava o viva.
2. **Cena curta da próxima missão (D21).** É a cena `mX_intro` que já existia, com a mesma duração. Em duas delas, o primeiro plano do narrador passou a ligar a pista anterior ao lugar novo.
3. **Começo da missão, com controle.** Uma réplica a mais enquanto a criança anda (`mission_start`), junto das falas que apontam (`travel` e `step_start`), que continuam iguais.

Regras de texto:
- Até 8 palavras e 44 caracteres.
- Nenhum ponto cardeal.
- Toda réplica diz o motivo de ir: uma pista, alguém chamando ou alguém que precisa de ajuda.

Vozes:
- **Rastro:** detetive, curiosa, fala de pistas.
- **Pico:** agitado, brincalhão, adora altura, diz "bora".
- **Leme:** calma e prática, deduz o rumo e assume o barco.
- **Narrador:** resume a descoberta.
- **Dona Amora:** carinhosa.
- **Capitão:** gentil.

Variantes (D19c):
- O "vamos seguir as patinhas" da Rastro se repete nas pontes M2→M3 e M6→M7. Por isso virou o grupo `bridge.tracker.follow`, com 3 variantes. A chave `ep01.team.tracker.follow_1` tem `vary` e sai sorteada sem repetir a última.
- Quando a lista não traz um viva, o viva do herói em controle continua vindo dos grupos `cheer.*`.

## 2. Transições

### M0 → M1 · do barco vazio às duas trilhas
- **O que aconteceu:** o barco bateu, a buzina tocou e não há ninguém a bordo.
- **Motivo para seguir:** quem sumiu? A pista está no chão do cais.
- **Onde:** no cais, andando (cerca de 9,7 s). Depois vem a `m1_intro` (6,5 s), em que o filhote passa correndo.

| Quem | Chave | Fala |
|---|---|---|
| Leme | `ep01.arrival.pilot.boat_empty` | Ninguém no barco. Cadê o capitão? |
| Pico | `ep01.arrival.climber.horn_alone` | E a buzina tocou sozinha! Que estranho! |
| Rastro | `ep01.arrival.tracker.clue_dock` | Calma! Toda pista começa no chão. |

### M1 → M2 · das duas trilhas ao varal
- **O que aconteceu:** há uma trilha de pata e uma de bota.
- **Motivo para seguir:** o filhote foi para o varal e o capitão saiu de bote para buscá-lo.
- **Onde:** no cais, andando (viva + cerca de 9,9 s). Depois vem a `m2_intro`, com o varal puxado.

| Quem | Chave | Fala |
|---|---|---|
| (viva) | grupo `cheer.<herói>` | sorteado |
| Narrador | `ep01.narrator.bridge.m1_m2` | Uma trilha de pata, outra de bota. |
| Leme | `ep01.dock.pilot.captain_rowed` | O capitão saiu de bote atrás do filhote. |
| Pico | `ep01.dock.climber.go_line` | Então bora achar o filhote no varal! |

### M2 → M3 · do varal à praça
- **O que aconteceu:** o varal foi arrumado e a meia tem pelo de filhote.
- **Motivo para seguir:** as patinhas molhadas vão para a praça.
- **Onde:** na margem, andando (cerca de 9,4 s). Depois vem a `m3_intro`, cujo 1º plano mudou para "As patinhas chegam à praça do chafariz." (`ep01.narrator.bridge.m2_m3`; antes era "O filhote brincou de bola na praça.").

| Quem | Chave | Fala |
|---|---|---|
| Leme | `ep01.bank.pilot.m2_done` (já existia) | Varal arrumado! Que time! |
| Rastro | `ep01.bank.tracker.sock_fur` | Olha! Pelo de filhote nesta meia! |
| Rastro | `bridge.tracker.follow` (variante) | Vem, equipe! As patinhas mostram o caminho. / Pista nova! Sigam as patinhas comigo. / Meu olho de detetive diz: por aqui! |

### M3 → M4 · do chafariz à feira
- **O que aconteceu:** a água voltou e a bola rolou.
- **Motivo para seguir:** a bola foi para as barracas, onde a Dona Amora pede ajuda (é o morador que fala nesta ponte).
- **Onde:** na praça, andando (cerca de 8,6 s). Depois vem a `m4_intro`, com os caixotes derrubados. Já andando, a Leme diz mais uma fala.

| Quem | Chave | Fala |
|---|---|---|
| Pico | `ep01.plaza.climber.m3_done` (já existia) | Chafariz de volta! Viva! |
| Rastro | `ep01.plaza.tracker.ball_rolls` | A bola rolou para as barracas! |
| Dona Amora | `ep01.plaza.vendor.help_call` | Ai, ai! Quem me ajuda aqui? |
| Leme (início do M4) | `ep01.market.pilot.we_help` | Calma, Dona Amora! A gente arruma. |

### M4 → M5 · da feira à rua do mercado
- **O que aconteceu:** os caixotes foram entregues e a Dona Amora conta da gaivota (`gull_hint`, já existia).
- **Motivo para seguir:** o filhote correu atrás da gaivota, que voou para a rua.
- **Onde:** na feira, andando (viva + cerca de 6,2 s). Depois vem a `m5_intro`, cujo 1º plano mudou para "A gaivota voou para a rua do mercado." (`ep01.narrator.bridge.m4_m5`; antes era "O filhote correu atrás da gaivota!", que repetia a Dona Amora).

| Quem | Chave | Fala |
|---|---|---|
| Rastro | `ep01.market.tracker.gull_where` | Uma gaivota? Vamos achar o filhote! |
| Pico | `ep01.market.climber.see_gull` | Olha ela lá, voando para a rua! |

### M5 → M6 · do telhado à baía
- **O que aconteceu:** o Pico pegou o peixe e, do alto, viu o bote (`sees_boat`, já existia).
- **Motivo para seguir:** o capitão está encalhado, precisa de barco e pode saber do filhote.
- **Onde:** na rua, andando (viva + cerca de 9,5 s). Depois vem a `m6_intro`, com o capitão acenando.

| Quem | Chave | Fala |
|---|---|---|
| Narrador | `ep01.narrator.bridge.m5_m6` | Do telhado, o Pico viu o capitão! |
| Leme | `ep01.street.pilot.to_boat` | Ele precisa de barco. Isso é comigo! |
| Rastro | `ep01.street.tracker.captain_knows` | O capitão pode saber do filhote! |

### M6 → M7 · da baía ao farol
- **O que aconteceu:** o bote foi rebocado e o capitão conta que o filhote subiu o farol (`pup_lighthouse`, já existia).
- **Motivo para seguir:** o filhote está no alto do farol, que está apagado.
- **Onde:** no cais, andando (viva + cerca de 9,5 s). Depois vem a `m7_intro`. A fala de deslocamento `M6>M7`, que já existia, continua.

| Quem | Chave | Fala |
|---|---|---|
| Pico | `ep01.bay.climber.lighthouse_high` | No farol? Lá é bem alto. Oba! |
| Leme | `ep01.bay.pilot.lamp_dark` | E a luz do farol está apagada. |
| Rastro | `bridge.tracker.follow` (variante, nunca a mesma do M2) | uma das 3 acima |

### M7 → M8 · do farol à festa
- **O que aconteceu:** a luz acendeu e o filhote foi salvo.
- **Motivo para seguir:** a festa começou e o filhote precisa voltar ao capitão.
- **Onde:** no promontório, andando (cerca de 9,6 s). Depois vem a cena `nightfall` (8 s). Já andando para a praça, o capitão chama de perto das lanternas.

| Quem | Chave | Fala |
|---|---|---|
| Farol 7 | `ep01.lighthouse.radio.lights_on` (já existia) | Os barquinhos acenderam! Venham à festa. |
| Pico | `ep01.lighthouse.climber.pup_hug` | O filhote está salvo comigo! |
| Leme | `ep01.lighthouse.pilot.to_party` | Agora, todos para a festa na praça! |
| Rastro (início do M8) | `ep01.festival.tracker.pup_home` | Vamos levar o filhote ao capitão! |
| Capitão (início do M8) | `ep01.festival.captain.wave` | Meu filhote! Estou perto das lanternas! |

O M8 termina na cena `closing`, que não mudou.

## 3. Números
- Falas novas: **26**: 21 de conversa (`moment: bridge`), 2 do narrador dentro das cenas (`bridge_cutscene`) e 3 variantes do grupo `bridge.tracker.follow`. Catálogo: `game/i18n/pt_BR.ep01v3_g9.json`. Todas estão sem take e em `pending` no catálogo de voz, e tocam só com legenda até gerar.
- Tempo novo com controle por ponte: cerca de 6 a 12,5 s, dentro do teto de 12 s antes da cena. A duração das cenas não mudou (Ep01: 88,5 s).
- Chaves de narrador que saíram das cenas e ficaram sem uso, sem take: `ep01.narrator.m3.ball` e `ep01.narrator.m5.gull`.
