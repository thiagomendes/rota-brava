# D19 · Vozes neurais dos personagens (proposta, provisória)

Pedido de Thiago (RB-R1, retorno do Ep01 v3): vozes dos personagens pelo Gemini TTS (Google AI Studio), neurais, sem "voz padrão de IA", moduladas localmente "na pegada do personagem", com tom infantil para os heróis. Depois: cada fala com emoção que combine com o momento do jogo.

Estado: ferramentas prontas e amostras geradas para aprovação. **Nada disto está no jogo ainda.** Aceite perceptual pendente: o agente não ouve áudio; só há medidas.

## Cadeia

1. `tools/voice/gemini_tts.py`: texto + voz pré-pronta + estilo → WAV bruto (24 kHz mono) + JSON de procedência (modelo, voz, prompt de estilo, modo, data, sha256 do áudio e da entrada). Cache por hash da entrada em `tools/voice/.cache/` (fora do Git), limite de taxa local (4 s entre chamadas, `RB_TTS_MIN_INTERVAL`), repetição com espera em 429/5xx/rede, `--dry-run`, mensagem clara em 401/403. A chave nunca passa pelo script: ele envia `x-goog-api-key: proxy-injected` e o proxy injeta o segredo.
   - `--character rastro --line <chave>` monta o estilo: estilo base (`cast.json`) + direção da fala (`direction.json`).
2. `tools/voice/treat.py`: tratamento local por personagem, ffmpeg + rubberband. Apara silêncio inicial e final → altura com formantes deslocados (`rubberband` pitch + `formant=shifted`) → EQ (corte de grave, presença) → loudnorm em 2 passadas (−16 LUFS, −1 dBTP) → correção de ganho com limitador quando a fala curta não chega ao alvo → 48 kHz mono PCM16. Sem reverb. Farol 7: banda 300–3400 Hz, compressão, saturação leve e chiado rosa **sintetizado** pelo ffmpeg (`anoisesrc`), sem amostra de terceiros.
3. `tools/voice/prove.py`: espectrogramas antes/depois (`showspectrumpic`), F0 por autocorrelação, LUFS e pico verdadeiro (ebur128).
4. `tools/voice/samples.py`: amostras para aprovação em `captures/d19/amostras/` (fora do Git).

## Como a instrução não é lida em voz alta (medido)

Frase de teste "O barco chegou sem o capitão!", voz Leda, `gemini-3.8-flash-tts`, 2026-11-25:

| Modo | Como vai o estilo | Duração | F0 mediana |
|---|---|---|---|
| texto puro | sem estilo | 2,26 s | 279 Hz |
| `prefix` | `"<estilo>: <texto>"` (forma dos exemplos do Google) | 7,42 s | 279 Hz |
| `system` | `systemInstruction` | HTTP 400 "Developer instruction is not enabled for this model" | — |
| `notes` (padrão) | `### NOTAS DE DIRECAO (nao ler em voz alta)` + estilo, `### TRANSCRICAO` + texto | 2,28 s | 397 Hz |

Leitura das medidas: no `prefix` a duração triplica e a F0 não muda, o que indica que a instrução foi falada (o teste do lead, 7,55 s, é o mesmo caso; o retorno do 3.8 já vem como WAV com cabeçalho, `audio/wav`, e o script grava como está). No `notes` a duração é a do texto puro e a F0 sobe ~6 semitons: a instrução agiu e não foi lida. **Não verificado por transcrição** (não há reconhecedor local; o modelo Whisper/Piper não baixa daqui, Hugging Face bloqueado). `samples.py` marca `suspeita_instrucao_lida` quando a duração passa de 2,2× a estimada.

## Elenco (`tools/voice/cast.json`)

Modelo: `gemini-3.8-flash-tts`. Rótulos de timbre são os de uma palavra que o Google dá a cada voz, de memória (página oficial inacessível daqui: **não verificado**); o gênero de cada voz também não foi verificado. Evitadas: Zephyr (padrão do AI Studio), Kore e Puck (as dos exemplos oficiais).

| Personagem | Recomendada | Candidatas (motivo) | Preset |
|---|---|---|---|
| Rastro (menina atenta) | Leda | Leda "Youthful", Autonoe "Bright", Achernar "Soft", Laomedeia "Upbeat" | `rastro` +3 st |
| Pico (menino energético) | Fenrir | Fenrir "Excitable", Sadachbia "Lively", Achird "Friendly" | `pico` +3,5 st, 4% mais rápido |
| Leme (menina firme, pilota) | Pulcherrima | Pulcherrima "Forward", Erinome "Clear", Despina "Smooth", Aoede "Breezy" | `leme` +2 st, compressão leve |
| Capitão (adulto caloroso) | Algieba | Algieba "Smooth", Umbriel "Easy-going" | `capitao` 0 st, calor 160 Hz |
| Farol 7 (rádio) | Iapetus | Iapetus "Clear", Schedar "Even" | `farol7` rádio |
| Dona Amora (feirante) | Vindemiatrix | Vindemiatrix "Gentle", Gacrux "Mature" (sem amostra nesta rodada) | `amora` −0,5 st, 3% mais lenta |

## Direção por fala (`tools/voice/direction.json`), decisão D19b

Pedido de Thiago: aproveitar o controle de tom e emoção para cada fala combinar com o momento. Decidido:
- Cada uma das 52 falas faladas do roteiro (a do filhote late, sem TTS) tem `emotion`, `energy` (1–3), `pace` (lento/normal/rápido) e `note` de atuação. Sem medo nem bronca (público 4–8 anos); "preocupação leve" é o máximo de tensão.
- Elenco e direção ficam em arquivos separados: a voz e o estilo base são do personagem; a direção é da fala.
- Cada chamada junta estilo base + direção nas notas de direção (modo `notes`), que o modelo não lê em voz alta (medido acima).
- O tratamento local é sempre o preset do personagem, igual em todas as suas falas, para manter a identidade; a emoção vem só da atuação do TTS.
- Prova: `emocoes.mp3` tem a mesma frase de cada herói "curiosa" (energia 1, lento) e "animada" (energia 3, rápido).

## Termos de uso (resumo, NÃO verificado nesta sessão)

As páginas de termos não abriram pela rede daqui. O que se sabe de memória, a confirmar por Thiago antes de usar no jogo:
- Termos adicionais da Gemini API: o Google declara não reivindicar a propriedade do conteúdo gerado; o uso é responsabilidade de quem gera, sujeito à Política de Uso Proibido. Uso comercial do resultado não é proibido de forma geral. *(não verificado)*
- Nível gratuito: dados de entrada e saída podem ser usados pelo Google para melhorar produtos; no nível pago, não. Os textos do roteiro não são sensíveis, mas convém usar chave paga para a produção. *(não verificado)*
- Modelos "preview" podem mudar ou sair; versões de produção (`gemini-3.8-flash-tts`) são preferíveis para reprodutibilidade, e o cache + procedência guardam o áudio já gerado. *(não verificado)*
- Restrições de idade nos termos valem para o usuário da API (Thiago), não para o público do jogo. *(não verificado)*
- Imitar voz de pessoa real é vetado; aqui só vozes pré-prontas. Não há exigência conhecida de aviso de "voz sintética" em jogo, mas verificar a regra da loja de destino.
- Áudio não é de terceiros no sentido da regra CC0 do projeto, mas é de ferramenta externa: cada arquivo leva JSON de procedência.

## Pendências
- Thiago ouvir e escolher vozes (aceite perceptual).
- Confirmar termos nas páginas oficiais.
- Piper local para a prova do tratamento: o modelo `pt_BR-jeff-medium` não baixa daqui (Hugging Face bloqueado pelo proxy). A prova usou takes Piper já gerados no projeto (`source_audio/radio/takes/`, cache do `radio.py`). Os rótulos "voz um..." das amostras foram gerados pelo Gemini (voz Schedar, sem estilo nem tratamento), não pelo Piper.
- Gerar o roteiro inteiro só depois da aprovação; ligar no jogo é outra etapa.
