# RB-R1 · Reorientação de qualidade (premium)

Branch de integração: `feature/rb-r1-reorientacao` (a partir de `main` com o RB-04 integrado como base técnica) · Referência: SPEC §1 (prioridades), §2, §3, §4, §5, §6, §9, §11, §12.
Origem: avaliação de Thiago após o RB-04 — “personagens nada infantis, gráfico ruim, som primitivo, mapa sem tamanho e densidade, UI longe do pedido”. **O aceite artístico do RB-04 está reprovado e substituído por este ticket.** Do RB-04 fica apenas a base técnica (sombreador, água, `AudioDirector`, pipeline de rig e exportação, sonda de desempenho, testes).

## Objetivo observável
Levar o jogo ao padrão audiovisual de uma série de aventura pré-escolar em 3D (referência de **ritmo e apelo**: Patrulha Canina e PJ Masks; **nada copiado**): crianças-heróis carismáticas com identidade de equipe, mundo grande e denso entre porto e ilha, UI de marca, som rico e vozes com intenção. Ao fim, Thiago joga o **primeiro minuto completo** e percorre o **mapa inteiro** no novo padrão e decide se o padrão está aprovado para estender ao episódio (RB-05).

## Diagnóstico (revisão RB-01 a RB-04)
| Área | Estado real | Lacuna em relação à SPEC/desejo |
|---|---|---|
| Engenharia | Diretor, 1511 testes, build reproduzível, ferramentas fixadas, bot ponta a ponta, medição de desempenho e de áudio. | Sólida; mantida. |
| Personagens | Rig e animações funcionam, mas proporções de boneco adulto (cabeça ~28% da altura), roupas genéricas, sem identidade de equipe. | Não são infantis nem heróis: sem uniforme, emblema, cor-assinatura, equipamento, pose de equipe, fala labial. |
| Mundo | Só o cais tem arte; rio, ilha e atracação em blocos; nada de vila, porto vivo, horizonte. Episódio ~3 min. | Sem tamanho, densidade nem marcos; meta de 8 a 12 min. |
| Visual | Sombreador estilizado e água viva, mas materiais lisos, sem contorno nem textura pintada, luz sem direção de cena. | Sem alvo visual definido (bíblia de estilo). |
| UI | Funcional (foco, área segura, ajuda), mas painéis genéricos, sem marca, sem retratos, sem transições. | Longe de uma UI infantil premium. |
| Áudio | Síntese em Python puro + vozes SAPI; ninguém consegue ouvir. | Primitivo por construção. |
| Processo | “Pronto” medido por testes de correção; provisórios aceitos por tempo demais; agentes em esforço baixo de modelo menor. | Faltou alvo visual e barra de apelo. |

## Decisões de produto (Thiago, 2026-11-23)
- **D1 · Elenco:** crianças-heróis humanas (SPEC §2 mantida), proporções infantis estilizadas, uniformes de equipe com **emblema próprio da Rota Brava** e cor-assinatura: Rastro laranja, Pico verde, Leme azul. Cada um com equipamento próprio (lupa/caderno; corda/mosquetões/capacete com lanterna; colete náutico/bússola de pulso).
- **D2 · Vozes:** TTS neural **local** (Piper, offline) só na produção; vozes pt-BR com licença verificada e registrada; o jogo distribuído continua sem IA. Gravação humana prevista antes do lançamento.
- **D3 · Música e efeitos:** permitido usar amostras e instrumentos de terceiros **CC0/domínio público**, com procedência registrada por arquivo. Composição e mixagem originais. Qualquer licença que não seja CC0/PD exige consulta a Thiago.
- **D4 · Arte conceitual:** **sem modelo de imagem** (decisão de Thiago após a falha do provedor padrão). O alvo visual sai de **estudos renderizados no Blender** feitos pelo `art3d` (proporção, silhueta, paleta, luz, composição de cena na câmera de jogo) e de **SVG** feito pelo `ux` (logo, emblema, pictogramas, telas de UI). Os estudos são fonte do projeto e podem evoluir para arte final; renders ficam fora do Git, scripts e `.blend`/`.svg` dentro.
- **D5 · Modelos dos agentes:** `art3d`, `gameplay`, `ux`, `audio`, `reviewer` → `anthropic/claude-opus-5-5#low`; `adventure`, `build-qa` → `opencode/deepseek-v4.1-flash-free#max`. O revisor fica no Opus porque precisa ler imagens.
- **D6 · Portões:** Portão 1 (direção) e Portão 2 (primeiro minuto + mapa). Entre portões, execução sem parar.

## Barra de qualidade (mensurável e perceptual)
**Personagens (crianças-heróis)**
- Altura ~1,05 a 1,15 m no mundo; **cabeça 33 a 38% da altura** (~3 cabeças); olhos grandes (altura do olho ≥ 20% da altura da cabeça) com íris, pupila e dois brilhos; mãos de 4 dedos legíveis; pés grandes e arredondados.
- Uniforme com emblema no peito, cor-assinatura cobrindo ≥ 40% da silhueta, equipamento que lê a 48 px e de costas.
- **Rosto vivo:** piscar automático, olhar que segue o alvo, sobrancelhas, 6 expressões, **boca falando** sincronizada à voz (visemas A/E/O/M ou abertura por envelope de amplitude).
- **Animações com personalidade:** idle próprio de cada herói, **correr** (crianças correm), parar com assentamento, pular (Pico), apontar, acenar, comemorar, **pose de equipe** na troca de integrante, reação de descoberta. Contato dos pés ±2 cm, mão na pista sem atravessar (já medido no RB-04: manter os testes).
- Materiais: toon suave com gradiente de cor por região, contorno fino nos personagens, textura procedural pintada (tecido, costura, brilho de olho). Figurantes do mesmo estilo e família.

**Mundo (tamanho e densidade)**
- Mapa contínuo do episódio no tamanho final: **vila do porto Farol 7** (8 a 12 construções, mercado, praça, farol como marco visível de todo o mapa), cais, **rio de 150 a 250 m** com margens vegetadas, ponte, banco de areia, boia, enseada, **ilha** com acampamento do piloto e travessia de rocha, horizonte com morros e silhuetas.
- Densidade: nenhum plano vazio visível da câmera de jogo; detalhe ao longo do caminho jogável (adereços, vegetação, rochas, pássaros, peixes, folhas na água); 12 a 20 moradores animados com rotinas simples; marcos que orientam.
- Duração estimada do episódio por percurso medido ≥ 8 min (bot em velocidade humana + falas), sem encher com tempo morto.

**Visual e câmera**
- Bíblia de estilo aprovada (paleta, luz por momento do dia, materiais, contorno, escala). Luz de cena com direção (chave quente, preenchimento frio, contraluz), sombras suaves, céu com nuvens, água com reflexo e espuma, partículas de ambiente (pássaros, poeira de sol, borrifos).
- Câmera dirigida por área com enquadramentos de apresentação (chegada, descoberta, troca, travessia) e transições suaves; modo de movimento reduzido.

**UI/UX infantil premium**
- Marca: logo original da Rota Brava (vetorial, feito no projeto), tela-título com os heróis 3D animados, menu com botões grandes e sons.
- HUD: retratos dos três heróis (renderizados dos modelos 3D, animados), cartão de objetivo ilustrado, **botão de ação grande e redondo** com pictograma, legenda em balão com retrato do falante, ajuda discreta; transições animadas (entrada, troca, conclusão), troca de glifos por dispositivo (teclado, controle, toque), sobreposição de toque.
- Opções: volumes por bus, tamanho de legenda, movimento reduzido, assistência de pilotagem. Tudo testado em 16:9, 20:9 e 4:3.

**Áudio**
- Vozes Piper por personagem com timbre distinto e infantilizado quando possível (ajuste de altura e formante registrado), intenção por fala, sincronizadas com a boca.
- Música original com instrumentos reais (CC0): tema da equipe com motivo memorável, versões exploração, descoberta, travessia e retorno, e vinhetas curtas (pista, troca de herói, vitória).
- Efeitos CC0 em camadas: água, vento, gaivotas, multidão da vila, passos por superfície, barco/motor por RPM, corda, UI.
- Mixagem: loudness integrada medida (alvo ~−16 LUFS no master), pico ≤ −1 dBTP, ducking audível nas falas. **Audição de Thiago obrigatória no Portão 2.**

**Mecânica e jogabilidade (sensação)**
- Correr com aceleração e parada responsivas; Pico **pula** de apoio em apoio (sem laje contínua); barco com inclinação, esteira e motor que respondem; cada interação com retorno visual + sonoro (brilho, partículas, vinheta); troca de integrante com pose de equipe; colecionáveis opcionais na vila (ex.: 10 emblemas escondidos) para recompensar exploração, sem bloquear progresso.

**Desempenho:** manter 1080p com p95 ≤ 16,7 ms no desktop de referência (medir; LOD e instanciamento para a vila).

## Escopo
1. Estudos de direção no Blender (3 variações de herói em proporção infantil, 2 composições do porto na câmera de jogo, paleta e luz) + logo, emblema e telas de UI em SVG + **bíblia de estilo** → **Portão 1**.
2. Novo elenco: Rastro, Pico e Leme crianças-heróis (modelos, rig, rosto falante, animações), piloto, filhote e 4 a 6 tipos de morador.
3. Kit de mundo: vila Farol 7, farol, cais, rio, ponte, ilha, vegetação, horizonte; mapa completo montado e denso.
4. Visual: materiais toon v2, contorno, luz de cena, céu, partículas de ambiente, câmera dirigida.
5. UI: marca, tela-título, HUD com retratos, transições, opções.
6. Áudio: Piper, música com instrumentos CC0, efeitos CC0, mixagem com loudness.
7. Sensação de jogo: correr, pulo do Pico, retorno das interações, pose de equipe, colecionáveis opcionais.
8. Integração no primeiro minuto com qualidade final e no mapa inteiro; rio, ilha e atracação mantêm a mecânica atual com a arte nova → **Portão 2**.

Fora do escopo: save/retomada, locução humana, Android/iOS (RB-05 e RB-06).

## Critérios de aceite
1. **Portão 1:** estudos Blender e SVG, bíblia de estilo e Rastro final renderizado no motor + um trecho do cais/vila na câmera de jogo; Thiago aprova ou ajusta a direção.
2. Elenco cumpre a barra de personagens (medidas em teste: altura, razão cabeça/corpo, olhos, contato, alcance, visemas presentes, clipes nomeados) e lê a 48 px e de costas (imagens).
3. Mapa completo navegável com os marcos e a densidade definidos; nenhum bloco provisório visível na câmera de jogo; duração estimada ≥ 8 min.
4. UI com marca, retratos e transições; sem texto cortado nas três proporções; foco e toque funcionam.
5. Áudio Piper + CC0 integrado; procedência por arquivo; loudness e pico medidos no vídeo; nenhum material sem licença registrada.
6. Sensação de jogo: correr, pulo do Pico com volta ao último apoio seguro, retorno em cada interação, pose de equipe.
7. Desempenho medido em 3 passagens (chegada, vila, atracação) com p95 ≤ 16,7 ms ou problema registrado com causa.
8. Suíte de testes verde, bot ponta a ponta concluindo o episódio, build Windows, vídeo com som, capturas nas 3 proporções.
9. Revisão independente aprovada → **Portão 2:** Thiago joga, ouve e decide.

## Casos de falha
Ativo ou áudio sem procedência, ou com licença diferente de CC0/PD sem aprovação → reprovado. Pranchas de conceito dentro do jogo ou no Git → reprovado. Personagem fora da barra (proporção adulta, sem identidade de equipe) → reprovado. Plano vazio na câmera de jogo → reprovado.

## Divisão (paralelizar só o independente)
| Sub-ticket | Responsável (modelo) | Área de escrita |
|---|---|---|
| R1-direção | lead + `art3d` (estudos Blender) + `ux` (SVG) | `source_art/studies/`, `game/ui/brand/`, `docs/style-bible.md`; renders em `captures/rb-r1/` |
| R1-heróis | `art3d` (Opus low) | `source_art/characters/`, `game/assets/models/characters/`, `game/actors/characters/` |
| R1-mundo | `art3d` (Opus low, outra instância) | `source_art/environment/`, `game/assets/models/environment/`, `game/actors/environment/`, montagem do mapa |
| R1-visual | lead | `game/art/`, câmera e luz de cena |
| R1-ui | `ux` (Opus low) | `game/ui/`, marca e tela-título |
| R1-áudio | `audio` (Opus low) | `source_audio/`, `game/audio/`, ferramentas Piper e CC0 |
| R1-jogo | `gameplay` (Opus low) | atores, pulo, correr, retorno das interações, colecionáveis |
| R1-conteúdo | `adventure` (DeepSeek max) | falas novas, glossário, colecionáveis, dicas |
| R1-build | `build-qa` (DeepSeek max) | build, desempenho, vídeo e medições |
| R1-revisão | `reviewer` (Opus low) | parecer no ticket |

## Verificação
```powershell
./tools/export-assets.ps1 ; ./tools/export-environment.ps1 ; ./tools/gen-audio.ps1
./tools/godot.ps1 --headless --path game --import
./tools/godot.ps1 --headless --path game --script res://tests/run_tests.gd
./tools/build-windows.ps1 ; ./tools/record-playthrough.ps1 ; ./tools/perf-capture.ps1
python tools/measure_video_audio.py captures/ep01-playthrough.avi
```

## Riscos
- **Vozes infantis por TTS:** vozes Piper pt-BR são adultas; a infantilização por ajuste de altura e formante pode soar artificial. Mitigação: registrar e escolher a melhor no Portão 2; a gravação humana resolve.
- **Alvo visual sem ilustração:** estudos Blender são mais crus que arte conceitual pintada; mitigação: render com luz, materiais e contorno da bíblia de estilo, na câmera real, e iteração antes do Portão 1.
- **Custo do Opus** em execuções longas de arte; **tamanho do repositório** com mais áudio e modelos (medir e registrar).
- **Nenhum agente ouve áudio**: o aceite sonoro depende de Thiago.

## Evidências
_(preencher)_

## Revisão
_(pendente)_
