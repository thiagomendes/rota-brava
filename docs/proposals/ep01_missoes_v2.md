# Ep01 · Missões v2 para chegar a 8 min ou mais (proposta W2, RB-R1)

Status: **proposta para Thiago aprovar** junto com a vitrine do mundo v2 (W1). Só documento: nada aqui altera código, cenas ou catálogo.
Base: `SPEC.md` §1-3 e §8, `specs/features/RB-R1.md` (D7-D13, evidência "Duração em modo humano"), `docs/style-bible.md`, `game/episodes/ep01/` (`ep01_dialogue.json`, `ep01_content.json`, `ep01_layout.gd`, `stages/`, `collectibles/`), `world/LAYOUT_PROPOSTO.md`.
Coordenadas em metros no referencial do `Ep01Layout` (+X leste, +Z sul). Os tempos da seção 3 são **estimativas, não medidas**.

## 1. Diagnóstico (3,94 min medidos no bot humano)
| Etapa | Hoje (s) | O que a criança decide/faz | Por que é curta |
|---|---|---|---|
| Chegada | 14 | assiste e confirma Rastro | só cena; sem nada para tocar |
| Cais | 61 | 2 pistas + escolha de destino | a única investigação do episódio; 2 pontos a menos de 15 m um do outro |
| Rio | 91 | contornar 1 boia, chegar à enseada | é a etapa com mais tempo, mas é quase só ir para leste; um único obstáculo de decisão |
| Ilha | 28 | 3 apoios em linha + fixar a linha | uma escolha por pedra, sem desvio; Rastro e Leme ficam paradas |
| Atracação | 15 | alinhar ao píer | alvo único, assistido |
| Volta | 13 | acionar partida | cena |
| Conclusão | 14 | menu | — |

Causa principal: **cada herói tem uma ação só, uma vez**. Não há momento em que um precise do outro (troca de herói existe só como passagem de bastão linear), Pico e Leme ficam ociosos por longos trechos, e os 10 emblemas estão espalhados sem pedir habilidade nenhuma (5/10 pegos no caminho). O mapa já cresceu (rio de 152 m), mas espaço sem decisão vira tempo morto.

## 2. Proposta por trecho (mesma história e ordem)
Regras comuns (crianças de 4 a 8 anos): nunca há "perdeu"; erro devolve ao último ponto seguro com uma observação concreta; assistência em 3 degraus (após ~10 s parado: gesto/brilho no alvo; ~20 s: Farol 7 no rádio diz o objeto exato; ~35 s: seta + câmera aponta); objetivo sempre por ícone no HUD; cada bloco de atividade dura 30 a 90 s; ponto de salvamento ao fim de cada bloco. Troca de herói: o herói que "pode" pisca com o ícone da habilidade e a criança confirma (SPEC §2).

### 0 · Chegada (+ ~20 s)
- O barco bate de leve, a caixa escorrega **e solta três objetos no cais**: boné do piloto, apito, mapinha molhado. Rastro recolhe tocando cada um (tutorial de "inspecionar" sem pressão). O mapinha volta na etapa 2 (pista da rota).

### 1 · Cais e vila: "Para onde foi o capitão?" (Rastro + Pico)
- **R1 · Três pistas em vez de duas** (qualquer ordem): pata no banco (já existe), bota na margem (já existe) e **gota de lama + pelo de filhote na escada do cais**. A terceira resolve a ordem: "a bota foi depois da pata".
- **R2 · Seguir rastros**: após a dedução, aparecem 4-5 pegadas espaçadas que a Rastro segue com a lupa (cada uma acende ao chegar perto) da margem até o cais de pedra oeste. Fim: a pegada some numa **escada de cordas para o telhado do galpão** (ou a torre de vigia).
- **Coop 1 · "Lá de cima dá pra ver"**: Rastro não alcança. Troca para **Pico**, que sobe 3 apoios (caixotes → toldo da barraca → telhado), lê a corda deixada pelo capitão e **joga a ponta da corda** para baixo; de cima ele vê o barquinho ao longe no rio (câmera mostra a enseada: objetivo do rio). Erro de apoio: Pico escorrega de volta ao caixote, sem queda.
- **Emblemas com intenção**: 2 só alcançáveis do alto (toldo, telhado) para Pico; 1 escondido "dentro" de uma pista (Rastro inspeciona o barril e acha).
- Escolha do destino (margem/porto) continua, agora com 3 pistas para justificar.

### 2 · Rio: "Subir o rio com a Leme" (Leme + Rastro)
- **L1 · Ler a bússola/mapinha**: antes de sair, Leme abre o mapinha da chegada (ícones: boia, ponte, ilha). A bússola no painel aponta a enseada; a criança só precisa manter a agulha no centro.
- **L2 · Slalom curto de boias** (3 boias em vez de 1, x 80..100), cada uma com cor/ícone; passar do lado certo é guiado pelas folhas; errar só faz a boia "balançar e apontar" o lado bom.
- **L3 · Passar sob a ponte (x 62)**: reduzir velocidade para não molhar a cabine (água espirra, risada, sem dano). Primeiro desafio de dosar velocidade.
- **Coop 2 · "Qual braço?"** junto ao banco de areia (x 112..126): o rio se abre em dois. **Troca para Rastro** no convés, que usa a luneta: marcas de remo na areia e folhas presas indicam o lado. Volta a Leme e escolhe. O lado "errado" é rota cênica mais longa que se junta de novo (não pune; tem 1 emblema).
- **L4 · Corrente forte** perto da enseada: a criança vê as folhas indo contra e encosta na margem calma (rota opcional SPEC "profundidade opcional").
- Emblemas: 3 de barco (já existem em x 60, 119, 170), pedindo manobra (entre boias, atrás do banco, fundo da enseada).

### 3 · Ilha: "Abrir a travessia" (Pico + Rastro + Leme)
- **P1 · Apoios com escolha**: em vez de 3 pedras em linha, 2 caminhos de 4 apoios; pedras seguras são claras e secas, as escuras e molhadas balançam e Pico volta (já existe `DecoyRock`). Rastro, se chamada, aponta a seca com a lupa (assistência por troca).
- **P2 · Fixar a linha** (já existe, os dois puxões).
- **Coop 3 · "Acampamento"**: na ilha, piloto e filhote acenam, mas o **filhote está do outro lado de um tronco caído/rochedo**. Pico pula o tronco e **amarra a corda**; troca para **Rastro**, que segue as pegadinhas do filhote até o esconderijo (barraca, caixote, arbusto: 3 lugares, um com pegada fresca). O filhote vem no colo.
- Emblemas: 2 na ilha (já existem), um no alto do rochedo (Pico).

### 4 · Atracar (Leme)
- **L5 · Entrar pelo norte do braço** com a linha como guia (já existe), agora com **dois toques de guia**: primeiro desacelerar na marca da linha, depois alinhar. Assistido nos metros finais como hoje.
- **Coop 4 · Embarque**: Pico segura a corda no píer enquanto Leme mantém o barco parado 3 s (barra de "firme" por ícone); Rastro ajuda o filhote a pular. Errou: o barco desliza, Leme reaproxima sem reiniciar.

### 5 · Volta e conclusão (curta, recompensa)
- A criança pilota a volta fácil (corrente a favor, 20-30 s) até ver o Farol 7; buzina do filhote (piada já existe). Tela final mostra **emblemas por herói** (ícones), convite a rever.

## 3. Tempo estimado por trecho (ritmo humano)
Estimativa = tempo medido hoje + deslocamento a 3-4 m/s a pé e 5-7 m/s de barco + ~6-10 s por interação + falas curtas (2-4 s cada). Folga de hesitação para 4-8 anos já incluída.
| Trecho | Hoje (s) | Proposto (s) | Base da estimativa | Risco de tempo morto |
|---|---|---|---|---|
| Chegada + 3 objetos | 14 | 35 | 3 toques + 10 s de andar | baixo |
| Cais: 3 pistas + dedução | 61 | 90 | +1 pista, +1 fala | baixo |
| Seguir rastros até a escada | — | 40 | ~40 m a pé + 5 pegadas | **médio**: andar sem nada; pegadas devem ficar a ≤ 8 m uma da outra |
| Coop 1: Pico no telhado + emblemas do alto | — | 70 | troca + 3 apoios + olhar a enseada | baixo |
| Rio: bússola, ponte, slalom | 91 | 120 | 152 m a ~5 m/s + 3 boias + ponte | **médio**: trecho x 30..60 e 130..160 sem evento; pôr folhas/gaivotas/emblema |
| Coop 2: qual braço (luneta) | — | 45 | 2 trocas + leitura | baixo |
| Ilha: apoios com escolha + linha | 28 | 60 | 4 apoios + puxões | baixo |
| Coop 3: achar o filhote | — | 60 | 3 esconderijos | baixo |
| Atracação + Coop 4 | 15 | 45 | aproximação + 3 s firme + embarque | baixo |
| Volta pilotada | 13 | 35 | ~100 m de barco | **médio**: limitar a 30 s, cortar com fade se passar |
| Conclusão | 14 | 20 | tela de emblemas | baixo |
| **Total** | **236 (3,9 min)** | **620 (≈ 10,3 min)** | | |

Margem: se a criança for 25% mais rápida que a estimativa, o total fica em ~7,8 min; o corte da seção 6 foi dimensionado sobre isso. **Medir** com o bot humano e com uma criança real antes de fechar.

## 4. O que o MUNDO precisa ter (para o art3d, W1 e etapa 2)
| Atividade | Lugar (aprox.) | Adereços / geometria necessários |
|---|---|---|
| 3 objetos da caixa | cais x −4..4, z −3..0 | boné, apito, mapinha (adereços pequenos, legíveis da câmera baixa) |
| 3ª pista | escada do cais, ~(−7, 0, 2) | escada para a água; mancha de lama + tufinho de pelo |
| Trilha de pegadas | margem sul (−6, 0, 10) → cais de pedra oeste x −20..−14, z −13..11 | caminho de terra contínuo, sem obstáculo de colisão; 5 decalques de pegada |
| Subida do Pico | junto ao cais oeste / rua do mercado, ~(−16, 0, −14) | **altura em 3 degraus**: caixotes (0,6 m) → toldo de barraca (1,6 m) → telhado/galpão baixo (2,8 m), topo plano ≥ 1,5 m; escada de cordas; ponto de vista com linha de visão para leste (rio/enseada) |
| Emblemas do alto | toldo e telhado acima | superfícies alcançáveis só pela subida |
| Barril-pista | rua do mercado | barril com tampa interativa |
| Mapinha + bússola | barco (painel) | bússola no painel com agulha visível (UI pode suprir) |
| Ponte baixa | x 60..64 (já existe, vão 3,49 m) | respingo por velocidade (VFX), nada a modelar |
| Slalom | x 80..100, z −10..10 | **3 boias** distintas por cor/ícone (hoje 1 em (90, −3)) |
| Bifurcação | banco de areia x 112..126, z 3..9 | os dois lados navegáveis (norte principal, sul cênico que volta em x ~130); marcas de remo na areia, folhas presas num galho |
| Corrente forte / margem calma | x 150..166 perto da enseada | faixa de folhas rápidas no meio, remanso junto à margem sul |
| Apoios com escolha | braço x 182..190, z 2..8 | 2 caminhos de 4 rochas seguras + iscas (ampliar `SafeRock`/`DecoyRock`) |
| Achar o filhote | ilha x 190..212 | tronco caído/rochedo baixo (≤ 1 m) entre o acampamento (195, 3) e a mata; 3 esconderijos: barraca, caixote, arbusto grande |
| Embarque firme | píer (190,5; −2) | cunho/poste no píer para Pico segurar a corda |
| Volta | rio x 174 → 34 | Farol 7 visível ao fim (já existe em (31, −24)) |

## 5. Novas falas (chaves e intenção) e impacto em código
Falas (curtas, cada uma com ícone de legenda; dicas em 2 níveis `hint_gesture`/`hint_spoken` por atividade, Farol 7 no rádio):
- `ep01.arrival.tracker.pick_cap`, `.pick_whistle`, `.pick_map` — Rastro nomeia o objeto.
- `ep01.dock.tracker.mud_hair`, `ep01.dock.tracker.order_deduction` — 3ª pista e conclusão de ordem.
- `ep01.dock.tracker.follow_start`, `ep01.dock.tracker.trail_ends` — começa/termina trilha; `ep01.dock.radio.hint_trail`.
- `ep01.dock.climber.call`, `.climb_top`, `.sees_cove`, `.throws_rope`; `ep01.dock.radio.hint_climb`.
- `ep01.river.pilot.compass`, `.bridge_slow`, `.bridge_splash`, `.buoy_n` (1 por boia), `.fork`; `ep01.river.tracker.spyglass`, `.reads_oars`; `ep01.river.pilot.calm_bank`; `ep01.river.radio.hint_fork`.
- `ep01.island.tracker.dry_rock`, `ep01.island.climber.over_log`, `ep01.island.tracker.pup_trail`, `.pup_found`, `.pup_not_here`; `ep01.island.radio.hint_pup`.
- `ep01.docking.climber.hold_rope`, `ep01.docking.pilot.steady`, `ep01.docking.tracker.pup_jump`.
- `ep01.complete.emblems_by_hero` (com parâmetros nomeados por herói).
Total ≈ 35 chaves novas (+ dicas).

| Item para o `gameplay` | Tamanho |
|---|---|
| Objetos da chegada (3 inspeções reaproveitando o sistema de pista) | P |
| 3ª pista + dedução de ordem (`ep01_content.json`) | P |
| Trilha de pegadas (sequência de gatilhos que acendem) | P |
| Troca de herói contextual no meio da etapa (herói disponível pisca) | M |
| Escalada do Pico na vila (reuso do sistema de apoios fora da ilha) + corda lançada | M |
| Bússola/mapinha no painel (UI) | P |
| Slalom de 3 boias (generalizar `river_buoy_tracker`) | P |
| Ponte com respingo por velocidade | P |
| Bifurcação + luneta da Rastro no barco (troca a bordo) | M |
| Corrente forte/remanso (zona em `river_zones`) | P |
| Apoios com dois caminhos | P |
| Busca do filhote (3 esconderijos, ordem aleatória por execução) | M |
| Embarque "firme" com barra de 3 s | P |
| Volta pilotada com corte por tempo | P |
| Contagem de emblemas por herói na conclusão | P |
| Assistência em 3 degraus unificada por atividade | M |
| Salvar ao fim de cada bloco novo + testes | M |

## 6. Recomendação de corte (mínimo para ≥ 8 min)
Manter, nesta ordem de valor: **Coop 1 (Pico no telhado)** 70 s, **trilha de pegadas** 40 s, **3ª pista** +29 s, **slalom + ponte** +29 s, **Coop 3 (achar o filhote)** 60 s, **apoios com escolha** +32 s, **Coop 4 (embarque firme)** +30 s, **volta pilotada** +22 s. Soma ≈ 236 + 312 ≈ **548 s (≈ 9,1 min)** estimados; mesmo 15% mais rápido fica em ~7,8-8 min.
Cortar primeiro: objetos da chegada, Coop 2 (bifurcação/luneta), corrente forte, bússola. Tudo P/M; nenhum exige trocar os heróis do jogo antes.

Decisão pedida a Thiago: aprovar os 4 cooperativos e a lista de lugares da seção 4 para o art3d fechar o mundo v2.
