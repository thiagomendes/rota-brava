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
- **D2 · Vozes (híbrido, decisão de Thiago):** heróis, piloto, filhote e moradores falam em **balbucio** (dialeto de desenho: sílabas rápidas sintetizadas por script, timbre e altura próprios por personagem, entonação por intenção: normal, urgência, descoberta, pergunta, alegria), com **legenda verbal e não verbal** (texto + ícones/emotes no balão, ex.: pata, interrogação, coração, gotas de esforço). As **instruções essenciais e as dicas faladas** vêm de **Farol 7 pelo rádio**, em voz adulta **Piper** (TTS local, offline, só na produção; licença da voz verificada e registrada) com filtro de rádio, para atender quem ainda não lê (SPEC §5). O jogo distribuído continua sem IA. Gravação humana possível antes do lançamento. **Mudança de produto em relação à SPEC §6** (“uma voz consistente por integrante”): a consistência passa a ser do timbre do balbucio; a fala de Farol 7 “Farol 7, aqui é Rota Brava. Achamos o barco.” continua sendo o teste de pronúncia e de filtro de rádio.
- **D3 · Música e efeitos:** permitido usar amostras e instrumentos de terceiros **CC0/domínio público**, com procedência registrada por arquivo. Composição e mixagem originais. Qualquer licença que não seja CC0/PD exige consulta a Thiago.
- **D4 · Arte conceitual:** **sem modelo de imagem** (decisão de Thiago após a falha do provedor padrão). O alvo visual sai de **estudos renderizados no Blender** feitos pelo `art3d` (proporção, silhueta, paleta, luz, composição de cena na câmera de jogo) e de **SVG** feito pelo `ux` (logo, emblema, pictogramas, telas de UI). Os estudos são fonte do projeto e podem evoluir para arte final; renders ficam fora do Git, scripts e `.blend`/`.svg` dentro.
- **D5 · Modelos dos agentes:** `art3d`, `gameplay`, `ux`, `audio`, `reviewer` → `anthropic/claude-opus-5-5#low`; `adventure`, `build-qa` → `opencode/deepseek-v4.1-flash-free#max`. O revisor fica no Opus porque precisa ler imagens.
- **D6 · Portões:** Portão 1 (direção) e Portão 2 (primeiro minuto + mapa). Entre portões, execução sem parar.

## Reabertura da direção (Thiago, 2026-11-24)
Thiago viu as capturas do jogo (render por software na nuvem) e reprovou a direção atual: os heróis não remetem a uma série de heróis infantil (referência de espírito: Patrulha Canina / PJ Masks), o mundo tem planos vazios, rochas que parecem blocos e luz chapada, e o som (balbucio) ficou estranho. Decisões:
- **D7 · Heróis v2:** continuam crianças humanas (SPEC §2), agora com **traje de herói**: uniforme de equipe marcante, capacete/máscara/viseira, cor dominante forte, emblema grande, equipamento-assinatura que mostra a habilidade, proporção mais de desenho e sombreamento de desenho (dois tons + contorno). Nada copiado das séries de referência.
- **D8 · Ordem:** (1) heróis v2 em vitrine de estudos → Thiago aprova antes de entrar no jogo; (2) proposta de mundo refinada, também em vitrine; (3) som profissional. O Portão 1 volta a ficar aberto para heróis e mundo.
- **D9 · Esforço:** `art3d` e `ux` em esforço alto (trabalho visual); demais subagentes seguem baixos.
- **D10 · Som (a decidir na fase 3):** Thiago propõe usar a API do Google AI Studio (vozes Gemini e trilha gerada) para substituir o balbucio e melhorar a música. Antes: conferir termos de uso comercial do áudio gerado e vozes adequadas em pt-BR. Se adotado, substitui D2 (balbucio + Piper) e flexibiliza D3 (só CC0). A chave entra só como segredo do ambiente, nunca no repositório.
- **D11 · Alvo de acabamento (Thiago, 2026-11-24, com print de outro jogo dele feito em Blender por código):** a referência é de QUALIDADE, não de aparência nem de proporção: material macio tipo vinil com brilho suave, tecidos com textura, volume vindo da luz (não cor chapada nem contorno grosso), membros que nascem do corpo sem emenda, luz direcional + luzes quentes locais, sombra de contato, oclusão nos cantos, névoa de profundidade, cenário denso e coeso. Proporção atual pode ficar, com ajustes pontuais. Os estudos heróis v2 (cor chapada) foram reprovados.
- **D12 · Renderizador:** Windows primeiro, com qualidade; o computador passa ao renderizador completo da Godot (Forward+). Portabilidade (celular) fica para depois do episódio fechado.
- Seguem em paralelo as tarefas que não dependem do visual (contador de emblemas, opções no jogo, duração em modo humano).

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
- Balbucio por personagem: timbre e altura distintos (Rastro baixo e calmo, Pico curto e vivo, Leme rápido e melódico, piloto grave, filhote em latidinhos), sílabas variadas sem repetição perceptível, entonação por intenção, duração proporcional ao texto, **boca sincronizada**; legenda com ícones/emotes. Rádio de Farol 7 em Piper com filtro, inteligível com motor e água ligados.
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

## Defeitos herdados do RB-04 (revisão parcial) — corrigir neste ticket
- A mão do Rastro **não alcança a marca real do banco** no jogo; o teste media contra um alvo sintético → o teste deve usar a posição real da marca no barco.
- Câmera ocluída por uma peça na inspeção da bota → teste de oclusão da câmera nos enquadramentos de inspeção.
- Sem testes para a ajuda (H), `BoatActor.CREW`, `Stylize` e volume do passo → cobrir.
- `tools/measure_video_audio.py` pode dar pico verdadeiro menor que o de amostra → corrigir e testar.
- Relatório de desempenho sem RAM do processo nem transparência → acrescentar.
- Captura 4:3 válida nunca feita no jogo → método de captura com `override.cfg` documentado em `tools/`.

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
- **Compreensão sem leitura:** com balbucio, o pré-leitor depende do rádio, de gestos e de ícones; mitigação: toda instrução essencial também vai ao rádio e à dica de gesto; testar uma passagem “sem ler” (só áudio do rádio + imagem).
- **Alvo visual sem ilustração:** estudos Blender são mais crus que arte conceitual pintada; mitigação: render com luz, materiais e contorno da bíblia de estilo, na câmera real, e iteração antes do Portão 1.
- **Custo do Opus** em execuções longas de arte; **tamanho do repositório** com mais áudio e modelos (medir e registrar).
- **Nenhum agente ouve áudio**: o aceite sonoro depende de Thiago.

## Decisões do lead durante a execução (autonomia delegada por Thiago em 2026-11-23, reversíveis)
- **Vila:** composição **B “vila na orla”** (rua do mercado paralela ao cais, farol ao fundo). Motivo: com a câmera do cais só se vê ~4 m de altura além de 15 m; na B essa faixa é a rua do mercado (toldos, bandeirolas, flores, portas). A encosta da A pode voltar como fundo.
- **Mapa:** adotadas as coordenadas de `game/episodes/ep01/world/LAYOUT_PROPOSTO.md` (rio de 152 m, ilha +90 m em x).
- **Heróis:** direção **A “brinquedo brilhante”** (cabeça 36,9% da altura, olhos grandes; lê como criança de série pré-escolar a 48 px). Pico e Leme finais, piloto, filhote e figurantes seguem essa direção.
- **Câmera:** os heróis têm 1,14 m e ficaram com ~80 px em 720p; alvo da bible (12 a 18% da altura da tela na exploração) passa a ser medido em teste em todos os estágios.
- **Portão 1:** aprovado pelo lead com base nos estudos (vila B, heróis A, marca e UI v2), por delegação de Thiago; reversível.

## Evidências (parciais — pausa em 2026-11-24; continuar em `docs/STATE.md`)
- **Suíte na integração:** `RESULTADO: OK (2650 PASS, 0 FALHA(S))` (Windows, Godot 4.7.2, commit de merge `ea8e4a8` + runner corrigido).
- **Heróis (vistos em render e no jogo):** Rastro 1,140 m, cabeça 36,9%; Pico 1,083 m / 37,0%; Leme 1,114 m / 37,7%; ~19–20 mil triângulos; pés ±2 cm em 100% do walk; mão do Rastro a 31 mm da PawMark **real** (defeito herdado corrigido); mão da Leme a 44 mm do volante.
- **Mundo (visto):** vila B, margem sul, rio de 152 m com ponte (vão 3,49 m medido), ilha; draw calls 118–1029 por vista; desktop 1080p p95 ≈ 6,5 ms com o porto (medido antes do mapa completo).
- **Câmera:** herói 12,4–16,2% da altura da tela em 16:9, 20:9 e 4:3 (teste); sem oclusão (teste pegou a cabana na pegada).
- **Áudio (medido, não ouvido):** mixagem de referência −16,2 LUFS / −1,05 dBTP; voz ≥ 9,6 LU acima do fundo; licenças verificadas (Piper `jeff` base CC0; FreePats, Kenney, OpenGameArt CC0).
- **UI:** HUD v2 e tela-título com heróis 3D vistos em 16:9; retratos renderizados no HUD.
- **Duração em modo humano (medida, 2026-11-24, nuvem, headless):** `godot --headless ... --ep01-start=arrival -- --ep01-demo-human` concluiu o episódio em **236,5 s (3,94 min)**, com 5/10 emblemas; por etapa: chegada 14,2 s, cais 60,8, rio 91,2, ilha 27,6, atracação 15,3, volta 13,4, conclusão 14,0. **Abaixo da meta de 8 min.** A atracação pelo norte foi concluída pelo bot (15,3 s). Ressalva: headless usa driver de áudio nulo; as falas contam pela duração do arquivo. Encher com tempo morto está fora da barra; a duração depende do redesenho do mundo e das missões (D8).
- **Lookdev D11/D12 (art3d, 2026-11-24, branch `feature/rb-r1-lookdev`, base técnica com o Rastro antigo):** projeto em Forward+ (`project.godot`; teste do renderizador atualizado para `forward_plus`). Vitrine isolada `game/lookdev/lookdev_dock.tscn` (porto real + barco + Rastro/Pico/Leme em idle), materiais novos em `game/lookdev/materials/` (vinil, tecido trama/canelado/tricô, madeira, pedra, chão com folhas, pintado, folhagem) aplicados só em tempo de execução por `LookdevMaterials`. Câmera baixa: 1,95 m, 12° para baixo, FOV 50, herói medido em 27,8% da altura da tela. Capturas 1600x900 (llvmpipe, fora do Git): `captures/lookdev/lookdev_a_antes_camera_baixa.png` (visual atual, `--rendering-method mobile`) e `lookdev_b_depois_camera_baixa.png`. Chamadas de desenho na vista: 806 antes / 1438 depois (4 cascatas de sombra e adereços pequenos com sombra). Tempo de GPU **não medido** (render por software). Fraco: trama do tecido cintila a 4 m, vinil quase não mostra brilho nesta distância, céu acinzentado, fundo pastel lavado.
- **Rastro v2, proposta lado a lado (art3d, 2026-11-24, branch `feature/rb-r1-rastro-v2` a partir de `feature/rb-r1-lookdev`; D11/D13):** herói investigador refeito do zero, **não substitui** o Rastro do jogo (só a vitrine `game/lookdev/`, modo `after`; `--lookdev-rastro=v1` volta o antigo). Traje inteiriço laranja (uma malha para tronco, braços e pernas, com ombro, cotovelo, quadril, joelho e dobras modeladas), cangalha creme com friso azul-marinho em V até o emblema grande no centro do peito, faixas creme laterais em braços e pernas, rosa dos ventos azul-marinho nas costas, gola em pé; equipe pelo emblema e pelo **cinto azul-marinho com fivela-bússola dourada**; equipamento: óculos-lupa erguidos no alto da cabeça, scanner de pulso com tela que brilha, lupa no coldre, bolsa da coxa com caderno de pistas; luvas de 4 dedos e botas grandes azul-marinho. Rosto, olhos com brilho, 28 ossos, visemas e os 12 clipes preservados (idle novo com o scanner; team_pose nova). Medido (Blender, `rastro_v2.info.json`): **24.441 triângulos**, altura 1,086 m, cabeça 36,8%, olho 29,8% da cabeça; GLB **6,11 MB** (texturas JPEG: traje e equipamento 2K, pele e cabelo 1K; cor, normal e ORM assadas com mipmap na Godot). PBR padrão do glTF + `KHR_materials_clearcoat`; a Godot 4.7 não importa clearcoat nem gera mipmap em textura embutida: `game/lookdev/gltf_pbr_import.gd` (pós-importação do `.import`) resolve os dois; conferido na cena importada (clearcoat ligado, mipmaps, ORM, 12 clipes, 28 ossos). Provas vistas (fora do Git): `captures/rastro_v2/rastro_v2_turnaround.png`, `rastro_v2_close.png`, `rastro_v2_heroi_baixo.png`, `rastro_v2_poses.png`, `rastro_v2_malha.png`, `godot_vitrine_camera_baixa.png`, `godot_vitrine_close.png`. Fraco: cabelo virou chanel com pontas viradas (as marias-chiquinhas se fundiram e foram assumidas); `team_pose` sem punho fechado (sem ossos de dedo); mancha escura sob o olho no close da Godot (provável SSAO forte da vitrine sobre as cascas do olho; no Blender não aparece); `.blend` com 16 MB (texturas empacotadas em PNG); validador Khronos não rodado (instalação bloqueada no ambiente). Suíte: `RESULTADO: OK (2692 PASS, 0 FALHA(S))` (1 execução antes falhou de forma intermitente em `test_options_game` ducking; passou 3/3 isolado e na suíte seguinte).
- **Pico v2, proposta lado a lado (art3d, 2026-11-24, branch `feature/rb-r1-pico-v2` a partir de `feature/rb-r1-rastro-v2` `e4edd34`; D11/D13):** herói escalador refeito no acabamento do Rastro v2, **não substitui** o Pico do jogo (só a vitrine `game/lookdev/`, via `pico_v2_model.tscn`). Traje próprio: jaqueta curta **acolchoada** verde (gomos e anéis modelados, painéis laterais/cotoveleiras verde-escuro, zíper e gola amarelos) + calça de escalada cinza-azulada (bolso de carga, joelho articulado) com joelheiras; capacete arredondado com lanterna de testa e jugular; rolo de corda a tiracolo (hélice com traçador), mosquetões grandes, saco de magnésio, luvas amarelas, botas de aproximação de cano baixo; cabelo ruivo em mechas pontudas saindo do capacete, pele clara com sardas, olhos azuis. Comum da equipe: emblema no peito (esquerdo) e cinto azul-marinho com fivela-bússola. 28 ossos, visemas e os 11 nomes de clipe do `pico.glb` (idle novo: quica na ponta dos pés e alonga; team_pose nova: pulinho para a base aberta, dois puxões na corda, braço ao alto). Medido (Blender, `pico_v2.info.json`): **24.864 triângulos**, altura 1,060 m (com capacete), cabeça 37,1% (39,4% com capacete), olho 31,0% da cabeça; GLB **6,59 MB**. **Pés (`pico_v2.check.json`):** menor distância entre as malhas das botas em todos os quadros dos 11 clipes = **4,69 cm** (repouso/parado; mínimo em walk 6,34 cm q23, run 6,48 cm q12); pé plantado sem deslize entre quadros (0,0 mm) nos clipes parados; pé de apoio no walk com erro ≤ 0,7 mm/s da velocidade nominal. Importado na Godot com o mesmo `.import` do Rastro v2 (clearcoat, mipmaps, 11 clipes, 28 ossos conferidos na cena importada). Provas vistas (fora do Git, `captures/pico_v2/`): `pico_v2_turnaround.png`, `pico_v2_close.png`, `pico_v2_heroi_baixo.png`, `pico_v2_poses.png` (com fileira de frente do walk/run), `pico_v2_malha.png`, `godot_vitrine_camera_baixa.png`, `godot_vitrine_close.png`, `godot_pico_close.png`, `godot_pico_camera_baixa.png`. Fraco: mechas de trás leem como franja de pontas; braços curtos para a cabeça grande (alongamento e punho ao alto ficam em V, sem passar da cabeça); sem punho fechado (sem ossos de dedo); `.blend` ~18 MB; a corda fica um pouco afastada das costas na vista de lado; validador Khronos não rodado. Suíte: `RESULTADO: OK (2697 PASS, 0 FALHA(S))`.
- **Pendentes:** ver `docs/STATE.md` §2 (pedras duplicadas na ilha, piloto/filhote no mundo, entrada norte na atracação, moradores, grama, contador de emblemas, opções no jogo, duração humana, capturas, desempenho final, vídeo, revisão, Portão 2).

## Revisão
_(pendente)_
