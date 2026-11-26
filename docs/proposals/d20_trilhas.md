# D20 · Trilha musical pelo Lyria (proposta, provisória)

Pedido de Thiago: trilhas geradas pelo Lyria, com **coesão** entre si e que **representem os momentos** do jogo. Estado: bíblia, ferramenta e amostras para aprovação. Nada no jogo ainda. O agente não ouve áudio: só há medidas, e o aceite é de Thiago.

## O que o jogo pede hoje

`audio_director.gd` (`MUSIC_ALIASES`) toca `explore`, `explore_low` (mesma base, sem melodia, para baixo da fala), `crossing`, `return`, `discovery`, `victory` e `team_call`, com crossfade entre loops; vinhetas tocam por cima e devolvem a seção, com o loop abaixado em 10 dB (`STING_DIP_DB`). O Ep01 v3 chama `team_call` na troca de herói. A trilha atual (`source_audio/music/compose.py`, FluidSynth + SoundFonts CC0) já usa o tema em Fá maior `C5 F5 A5 G5 C6`. A bíblia mantém esse tema, para que a troca seja de timbre e produção, não de identidade.

Mapa proposto (para o `gameplay`, depois): vila → `explore`; mistério/pista → `discovery` (hoje uma vinheta; vira loop de investigação); barco → `crossing`; farol → nova seção `lighthouse`; festa → nova seção `festival`; vitória de missão → `victory`; emblema → nova vinheta `badge`; troca de herói → `team_call`. `explore_low` passa a ser derivado localmente da faixa da vila (passa-baixas e −7 dB), sem nova chamada.

## Bíblia musical

Os dados estão em `tools/music/music_bible.json`, de onde o `lyria.py` monta o prompt de cada cena.

**Paleta fixa:** ukulele, marimba, violão de náilon, contrabaixo em pizzicato, acordeão leve, glockenspiel e percussão de mão (cajón, shaker, pandeiro). Sem guitarra elétrica, sintetizador, bateria ou orquestra. A mesma paleta é escrita em todos os prompts; o que muda por cena é quem aparece e quanto.

**Centro tonal:** Fá maior. As cenas vizinhas ficam a um passo: Ré dórico (relativo, suave), Si♭ maior (IV) e Ré menor resolvendo em Fá.

**Família de andamentos:** 80 / 100 / 120 BPM. Divisões simples entre si: 80 como meio-tempo de 120 em sensação, e 100 como base.

**Tema principal:** salto ascendente Dó–Fá–Lá (quarta e terça), passo descendo a Sol, salto ao Dó agudo. Ritmo: colcheia, colcheia, semínima, colcheia, semínima pontuada. A resposta desce em graus até Fá. Curto e cantável, com contorno de "pergunta que sobe e sorri".

| Cena | Energia (1–3) | Orquestração | Modo | Andamento |
|---|---|---|---|---|
| Vila de dia (tema) | 2 | marimba no tema, ukulele no contratempo, baixo pizz., shaker/cajón; acordeão responde na 2ª metade | Fá maior | 100, 4/4 |
| Mistério / pista | 1 | baixo pizz. andando na ponta dos pés, glockenspiel com fragmentos lentos do tema, harmônicos de violão, shaker esparso | Ré dórico | 80, 4/4 |
| Barco | 2 | ukulele e violão em 6/8 balançado, acordeão em notas longas (brisa), marimba com o tema "ninado" | Si♭ maior | 100, 6/8 |
| Farol | 2, crescendo | começa com baixo pizz. e marimba em Ré menor, entram brilhos de glockenspiel, e o tema chega em Fá maior no acordeão e na marimba | Ré menor → Fá maior | 80, 4/4 |
| Festa à noite | 3 | paleta inteira: acordeão e marimba juntos no tema, ukulele batido, pandeiro, cajón, palmas, baixo saltitante | Fá maior | 120, 4/4 |
| Vinheta: vitória de missão (~4 s) | 3 | tema inteiro em marimba e acordeão, acorde final de Fá com brilho de glockenspiel | Fá maior | 120 |
| Vinheta: emblema (~3 s) | 2 | Dó–Fá–Lá–Dó no glockenspiel e na marimba, batida de ukulele | Fá maior | 120 |
| Vinheta: troca de herói (~2 s) | 2 | três primeiras notas do tema na marimba e um toque de pandeiro | Fá maior | 120 |

Regras globais escritas no prompt: só instrumental; acolhedor, nunca assustador ou agressivo; mixagem acústica limpa, sem reverb pesado; loop sem fade-out.

## Ferramenta

- `tools/music/lyria.py`: monta o prompt (bíblia + cena + "take" para variar), chama o `generateContent` nativo com `x-goog-api-key: proxy-injected` e reaproveita do `gemini_tts.py` o limite de taxa, o SSL e o erro de autenticação. Para com mensagem clara em 429 de cota. Grava o MP3 com JSON de procedência (modelo, prompt, sha256, data, parte de texto devolvida) e usa cache por hash em `tools/music/.cache/`, fora do Git. `--ref` anexa áudio de referência, mas os modelos recusam (abaixo).
- `tools/music/measure.py`: `stats` mede duração, LUFS, LRA, pico verdadeiro, faixa de frequência (onde ficam 95% e 99% da energia, e a frequência mais alta acima de −80 dB) e andamento estimado. `loop` testa as emendas.
- `tools/music/music_samples.py`: gera as amostras abaixo.

## Referência de áudio e continuação: não aceitas

Mandei a faixa da vila (MP3) como `inlineData`, com o pedido "continue esta peça", para os três modelos. Os três responderam HTTP 400: "Unsupported input mime type for this model: audio/s16le" (3 chamadas). Nenhum aceita entrada de áudio, nem referência nem continuação. Não testei entrada de imagem, `seed` ou `lyria-realtime-exp` (bidi, que na documentação conhecida aceita prompts ponderados e mudança contínua). **Não verificado.** A coesão, então, vem só do texto fixo da bíblia, igual em todos os prompts, e do mesmo modelo para todas as cenas.

## Comparação de modelos (mesmo prompt da vila)

| Modelo | Duração | LUFS | Pico (dBTP) | LRA | 95% / 99% da energia abaixo de | Topo a −80 dB | BPM estimado (pedido 100) |
|---|---|---|---|---|---|---|---|
| `lyria-3-clip-preview` | 30,8 s | −11,8 | +0,5 | 2,2 | 1,6 / 2,1 kHz | 18,7 kHz | 99,4 |
| `lyria-3-pro-preview` | 153,8 s | −12,4 | +0,3 | 3,4 | 1,2 / 2,6 kHz | 18,6 kHz | 105,5 |
| `lyria-3.5` | 141,5 s | −12,5 | +0,5 | 5,6 | 1,1 / 3,1 kHz | 18,7 kHz | 105,5 |

Todos devolvem MP3 estéreo de 44,1 kHz a 192 kbps. O `clip` tem duração fixa de ~30 s; o `pro` e o `3.5` dão faixas de 2 a 2,5 min, com marcadores de seção na parte de texto (`[[A0]] [[B1]] [[C2]] [[B3]] [[D4]]`). Os três passam de 0 dBTP e ficam ~4 LU acima do alvo do jogo: **toda faixa precisa ser normalizada localmente** (proposta: −18 LUFS para música, pico −1 dBTP). A estimativa de BPM é grosseira, por autocorrelação de onsets. Qualidade "soando melhor" não foi avaliada.

Escolha para as amostras: `pro` nas cenas (duração e forma com seções) e `clip` nas vinhetas (nenhum modelo garante a duração curta pedida, então a vinheta é cortada no tamanho com fade).

## Loop

Proposta: emenda em fim de compasso, calculada pelo BPM da bíblia, descartando o último segundo (o modelo tende a fechar a peça). Duas emendas testadas por candidata, com a diferença de energia medida em 50 ms antes e depois da volta:

- (a) corte seco no cruzamento por zero mais próximo do fim de compasso;
- (b) crossfade de 1 batida, equal power, com a cauda dobrada sobre o início (o mesmo método do `compose.py`).

Os números estão em `captures/d19/musica/index.json` (campo `loop`) e no resumo abaixo. Ressalva: se o andamento real do modelo difere do pedido, o compasso calculado escorrega. Na produção, a emenda deve vir de batidas detectadas, não do BPM pedido.

Medido nas 10 candidatas de cena (diferença de RMS na volta do loop):

| Emenda | Diferença de energia |
|---|---|
| (a) corte em zero | 40 a 195 dB |
| (b) crossfade de 1 batida | 0,1 a 2,7 dB em 8 candidatas; 10,5 dB em `boat_2` e 12,9 dB em `festival_2` |

- **Corte em zero não serve:** as faixas do `pro` acabam em fade ou em silêncio mais longo que 1 s, então o corte cai em silêncio.
- **Proposta:** crossfade de 1 batida, com o fim do loop posto antes do fade do modelo, detectado pela queda de RMS, e não por "duração − 1 s". `boat_2` e `festival_2` mostram que isso é necessário.
- **Andamento:** o estimado diverge do pedido em várias faixas (mistério 1 64 contra 80; barco 70 contra 100, possivelmente a pulsação em 6/8; festa 2 62 contra 120, provavelmente meio-tempo). O estimador é grosseiro, e isso não foi verificado de ouvido.

Medidas das candidatas (`pro`): duração de 95 a 181 s, LUFS entre −12,1 e −12,6, pico verdadeiro entre +0,1 e +1,1 dBTP, 99% da energia abaixo de 2,1 a 3,7 kHz. Vinhetas (`clip`): 28,5 a 30,7 s geradas, cortadas em 3 a 5 s.

## Termos (NÃO verificado)

Mesma situação do Gemini TTS (`d19_vozes.md`): páginas oficiais inacessíveis daqui. O Lyria via API costuma aplicar marca d'água SynthID inaudível ao áudio; isso não impede o uso, mas convém confirmar nos termos se a música gerada pode ir para um jogo comercial e se há exigência de atribuição. Modelos "preview" podem mudar.

## Pendências

- Thiago ouvir as cenas, as vinhetas e o medley (aceite perceptual e de coesão).
- Testar o `lyria-realtime-exp` (bidi) para variação contínua com a mesma base.
- Normalização, loop e cortes finais só depois da escolha.
- Mapa de seções no `audio_director.gd` pelo `gameplay`.

## D20a · Escolha de Thiago e trilha no jogo (2026-11-26)

Escolhas de Thiago: candidata 1 de cada cena, as 3 vinhetas geradas e o narrador Sadaltager, cru (`cast.json`).

**Produção** (`tools/music/finalize.py` → `game/audio/music/*.ogg`, Vorbis q6, 44,1 kHz estéreo):
- **Fim musical:** último quadro de 50 ms acima de (mediana − 12 dB), o que exclui o fade do modelo.
- **Batida:** autocorrelação de onsets entre 0,5× e 2× o BPM da bíblia. Em 4 faixas saiu a metade do pedido, o meio-tempo. Isso não afeta a emenda, porque o loop fecha em blocos de 4 batidas medidas.
- **Loop:** termina 1 batida antes do fim musical, e essa batida é dobrada sobre o início (crossfade equal power).
- **Volume:** ganho estático para −18 LUFS (o alvo das músicas do catálogo), limitador com teto de −1,8 dBFS e conferência do pico verdadeiro no OGG.
- **Vinhetas:** cortadas em (segundos da bíblia + 1,5 s), com fade de 0,6 s e silêncio nas pontas.

| Faixa | Duração | LUFS | Pico (dBTP) | BPM medido (pedido) | Compassos | Salto na emenda | Diferença de energia na emenda |
|---|---|---|---|---|---|---|---|
| `music_v3_village` | 146,3 s | −18,0 | −5,2 | 52,5 (100) | 32 | 0,0053 | 0,26 dB |
| `music_v3_mystery` | 168,0 s | −18,0 | −4,7 | 40,0 (80) | 28 | 0,0035 | 4,82 dB |
| `music_v3_boat` | 169,1 s | −18,0 | −5,1 | 52,5 (100) | 37 | 0,0113 | 1,84 dB |
| `music_v3_lighthouse` | 169,8 s | −18,0 | −4,0 | 82,0 (80) | 58 | 0,0052 | 6,45 dB |
| `music_v3_festival` | 155,7 s | −18,0 | −5,1 | 60,1 (120) | 39 | 0,0089 | 1,71 dB |
| `sting_v3_mission_win` | 5,55 s | −18,0 | −5,0 | — | — | — | — |
| `sting_v3_badge` | 4,55 s | −18,0 | −4,1 | — | — | — | — |
| `sting_v3_hero_switch` | 3,55 s | −18,8 | −1,7 | — | — | — | — |

- O salto na emenda é medido no OGG decodificado; o limite do catálogo é 0,02.
- A diferença de energia compara o RMS de 50 ms antes e depois da volta. Mistério (4,8 dB) e farol (6,5 dB) ficaram altos e pedem conferência de ouvido.
- O farol "cresce" ao longo da faixa e volta ao começo esparso. Isso é inerente à forma pedida; se incomodar, a alternativa é fazer o loop só da parte final.

**Ligação** (`audio_director.gd`):
- Aliases `v3_*` e mapa `EP01_V3_MISSION_MUSIC`:

| Missões | Música |
|---|---|
| M0, M4 | vila |
| M1, M2, M3, M5 (pistas) | mistério |
| M6 | barco |
| M7 | farol |
| M8 | festa |

- `bind_episode_music(ep)` escuta `mission_started` e `mission_completed`.
- Ganchos públicos para o `gameplay`:
  - `play_scene_music(secao)`, por exemplo para voltar à vila quando a pista se resolve: hoje o mistério dura a missão inteira;
  - `on_mission_music_started`;
  - `on_mission_music_completed` (vitória);
  - `play_badge_sting`;
  - `play_hero_switch_sting`.
- As vinhetas tocam por cima da seção e a abaixam 10 dB, como antes. O ducking da fala não mudou.
- Em `ep01_v3_main.gd` mudaram 3 linhas de chamada: `bind_episode_music(self)`, `play_badge_sting()` no emblema e `play_hero_switch_sting()` no lugar do `team_call`.

**Procedência:**
- `sfx_catalog.json` traz sha256, modelo e data de cada faixa.
- `source_audio/PROVENANCE.md` traz a licença "gerado (Lyria)", aceita no teste de procedência por decisão D20a.
- O prompt inteiro está em `tools/music/final_tracks.json`.
