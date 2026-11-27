# Rota Brava · Estado do projeto (passagem entre sessões)

> **Leia este arquivo primeiro** ao abrir uma nova sessão, com qualquer modelo/ferramenta. Atualize e commite a cada etapa.
> Depois leia: `CLAUDE.md`/`AGENTS.md`, `SPEC.md`, `specs/features/RB-R1.md` (ticket ativo), `docs/style-bible.md`, `docs/agent-scorecard.md`.
> Nunca confie só neste resumo: confirme com `git log`, `git worktree list`/branches e rodando os testes.

**Atualizado em:** 2026-11-24 (pausa pedida por Thiago; migração do OpenCode/Windows para o Claude Code na nuvem).
**Remoto:** `https://github.com/thiagomendes/rota-brava` (todas as branches enviadas).
**Branch de integração ativa:** `feature/rb-r1-reorientacao` (commit no topo = estado mais recente). **`main`:** RB-01 a RB-04 (RB-04 só base técnica).
**Última suíte medida na integração:** `RESULTADO: OK (2650 PASS, 0 FALHA(S))` (Windows, Godot 4.7.2).
**Nuvem (2026-11-24):** `tools/setup-linux.sh` e `tools/test.sh` verificados no Linux: 2650 PASS em 1 min 42 s no `5f877ec`. Ambiente pessoal `rota-brava` libera `download.blender.org` (o Default bloqueava o Blender).

## 0. Agora (2026-11-25)
- **Ep01 v3 aprovado (D18):** história e 7 missões na vila; som/vozes novas ficam para depois. Plano E1–E7 no ticket.
- **Integrado e revisado** na `feature/rb-r1-reorientacao` (suíte `OK (2877 PASS)`): heróis v2 nas cenas do jogo (E1b), sistema de missão curta em `game/systems/mission/` ainda não ligado (E2), mundo jogável `game/worlds/village_v3/village_world.tscn` com colisão, limites e 54 marcadores M0–M8, barco `boat_wv2.tscn` e geometria das missões (E1a/E3).
- **E1 integrado** (`698d64d`, `OK (2900 PASS)`): Jogar abre `game/episodes/ep01/v3/ep01_v3_main.tscn` na vila v3, câmera baixa, barco v2, M0–M8 provisórias (chegar ao marcador), bot M0→M8 em 123,9 s.
- **E3b integrado** (suíte `OK (2914 PASS)`): passagem praça→rua ~2 m, subida do promontório lisa, rampas `AccessRamps` (camada 5, desligadas), retratos v2 do HUD.
- **E4 integrado** (`OK (2937 PASS)`): M1–M4 em terra com mecânicas reais, troca de herói, ajuda em 3 degraus, 5 emblemas, retomada pelo menu em `user://missions.save.json`.
- **E5 + C1 integrados** (`OK (3351 PASS)`): M5–M8 (gaivota, barco com colete, farol, festa), 10 emblemas, câmera orbital pelo mouse/alavanca e desvio de obstáculos, peças finais do props v3 pelo ponto de troca. Bot M0→M8 ~226 s; ritmo humano estimado ~11 min (acima da meta, medir na E7).
- **C2 integrado** (`OK (3409 PASS)`): andar por padrão, Shift corre, pulo (Espaço/A) bloqueado em zonas de subida das missões, interact E/X, seguidores em formação.
- **Ciclos v2 integrados:** passada longa em `walk`/`run` (2,3–4,1 passos/s). Aguardando Thiago jogar (movimento, câmera, pulo, duração).
- **E6 integrado** (`OK (3425 PASS)`): 53 falas + 21 dicas do Farol 7, legenda no tempo de leitura, Dona Amora.
- **E7 ícones integrados** (`OK (3442 PASS)`, 8 min 16 s): retratos de capitão, filhote, Dona Amora e Farol 7; ícones lua, peixe, flor e mosquetão novo.
- **Retorno de Thiago resolvido e integrado (2026-11-26):** F1 (andar/seguidores), F2 (pistas reais, olhar dirigido, anel, rastros, falas que apontam, variantes, retomada do M5), arte das cenas (filhote andar/correr, apontar, Dona Amora 3D), D21 cutscenes (abertura do jogo + 12 cenas do Ep01). Suíte `OK (3903 PASS)` em 772 s.
- **Som (D19–D21):** trilhas Lyria no jogo; vozes Gemini: 50 de ~227 geradas e integradas (vozes 2, detector de leitura dupla `tools/voice/detect_double.py`, prompt `once_t`). Faltam 177 (151 tocam só legenda, em silêncio); cota de 100/dia do Tier 1, última geração 2026-11-26 13:33 UTC; retomar com `.tools/audio-venv/bin/python tools/voice/gen_v3.py` + `python3 tools/voice/register_v3.py`. Chave via segredo de rede do ambiente (`x-goog-api-key`), nunca no repositório.
- **Terceiro retorno de Thiago (2026-11-26) integrado:** câmera sem tremor na corrida (segue no passo de física, braço com mola + zona macia de 0,9 m, encosta na hora na parede; `test_camera_tremor` e `test_camera_wall` falham no código antigo) e a mesma fala não entra duas vezes na fila em 5 s; suíte `OK (3917 PASS)` em 896 s, a 4 s do limite de 900 s, acelerar é prioridade da E7 (causa da fala dupla: `success.climber` contém `sock_high`, que o M2 também diz). Pendente de Thiago: ver o tremor na tela real, giro do mouse em monitor > 60 Hz, câmera mais perto em lugares apertados.
- **G6 (art3d, branch `feature/rb-r1-g-interpenetracao`, sem merge):** `bash tools/prop-overlap.sh` audita a vila com as peças de M1–M8; antes 44 pares se atravessando, 14 flutuando, 10 modelos com partes soltas; depois 0/0/0 (carrinho do M4 com caixotes em fila no fundo, kit e disposição corrigidos). Guarda: `test_prop_overlap` (~40 s a mais na suíte, que já estava a 4 s do limite de 900 s). Detalhes e limites no ticket.
- **Pacote G integrado (2026-11-26, quarto retorno de Thiago):** G1 olhos abertos; G3 sombra sem xadrez; G2 artigo "a Leme"; G9 pontes entre missões; G5 `MouseLock`; G7 primeiro E age; trava do M2 corrigida; G6 auditoria `prop_overlap` (0 sobreposições); G4 capitão, filhote e Amora no padrão do trio; G8 tela inicial (cena B + logo C noite); G10 `SceneLoader` com estrela e menu liberado só depois do palco 3D (teto 60 s); G11 abertura → menu. Suíte: 4150 PASS em 986 s (passa do limite de 900 s) depois da correção do manifesto.
- **Depois do pacote G (2026-11-27):**
  - Menu com Jogar/Opções/Sair e 3 espaços de jogo (G12/G13).
  - Trio duplicado corrigido.
  - Controle por A/B nos menus e pulo suprimido com painel aberto (G14).
  - Tela de carregamento com teto de 20 s.
  - Fila única de carregamento, e no celular o menu é a imagem parada (G16).
  - G15 (dicas pelo aparelho em uso) foi decidido e não começou.
  - G18 (art3d, branch `feature/rb-r1-g18-varal`, sem merge): roupas do M2 penduradas na corda real (vagas no marcador `M2_Clothesline`), cesto no M2, roupas e caixotes do M4 ficam depois da missão, caixote do M4 no chão (antes 95 cm no ar). Guarda em `test_prop_overlap`; detalhes no ticket.
- **Mobile (RB-M1):**
  - Workflows Android/iOS sob demanda, na `main` só os dois arquivos.
  - O APK foi instalado no Galaxy Tab FE.
  - O build iOS 1 travou na estrela (impasse); o G16 é a correção.
  - O build 2, com toque básico, está esperando Thiago disparar.
- **Vozes:** 101 de 251 com voz. Lote diário agendado.
- **Integrado em 2026-11-27, à tarde:**
  - G15: dicas pelo aparelho em uso.
  - G17: vozes no plano certo, com a cena esperando a tela de carregamento.
  - G20: rádio do Farol 7, aprovado por Thiago.
  - E7: suíte em paralelo, cerca de 7 min.
  - G16b.
  - Vozes 3 (101 com voz).
  - Suíte: `OK (4542 PASS)` em 455 s.
  - O build 2 do iPhone rodou sem o travamento.
- **Em andamento:**
  - G18: varal do M2.
  - G19 e G19b: ações no jogo revisadas e integradas (pausa congela, sem mágica na troca de herói). Lente do M7 na parede da galeria (decisão de Thiago).
  - G21: Lumi aprovado por Thiago. G21i (plano na abertura, falas novas pendentes para o lote de 28/11) com `gameplay`; G23 (pés soltos do capitão, Amora e Lumi) com `art3d`.
  - G24 (iPhone, jogado até o resgate do capitão):
    - G24a, câmera ao correr: com `gameplay`.
    - G24b/c/d, corda que atravessa, barco de ré no meio dos outros e auditoria dinâmica de interpenetração: com `gameplay`.
    - G24e: proposta pronta (`docs/proposals/g24_roteiro.md`). Thiago escolheu pacote mínimo hoje (G25, depois do G21i), fio do filhote fujão, varal de bandeirinhas (no médio) e vozes novas primeiro.
  - G22 (iPhone, build 3):
    - G22b (rádio no nível das vozes, −0,26 LU) e G22c (Vila Maré) estão revisados e integrados; falta Thiago ouvir.
    - G22a ("?" no lugar do "H" e disco de 128 px no toque) revisado e integrado; falta Thiago ver no iPhone.
- **Próximo:**
  - Build de hoje (decisão de Thiago): assim que G23 e G21i estiverem revisados e integrados, avisar Thiago para disparar. Vozes de 28/11 vão num build seguinte.
  - Lote de vozes de 2026-11-28 08:20 UTC.
  - E7 restante: bot humano, capturas, vídeo, build Windows e Portão 2. Depois, PARAR.
- **Páginas para Thiago:** trio 3D https://claude.ai/artifact/1ZKx8zKZ2HxQn85ZtL9EGR (Leme antiga), mundo v2 https://claude.ai/artifact/6WpRQzYXY2hW74LxMiPVww, novidades https://claude.ai/artifact/2WyeZqg8DNSLWegCPcCXAt.
- **Dívidas:** `wv2_static.glb` ainda 10,6 MB e `world_v2.blend` 5,2 MB; materiais do mundo em `game/lookdev/world_v2/`; tris dos heróis no teto; cabelos de trás facetados; luz de parede estoura à noite; GPU real não medida; retratos do HUD antigos; branches `wip/*` a apagar pelo GitHub.

## 1. Onde estamos
- **Ticket ativo:** `RB-R1 · Reorientação de qualidade (premium)`. Origem: Thiago reprovou arte/som/UI do RB-04 (“personagens nada infantis, gráfico ruim, som primitivo, mapa sem tamanho/densidade”).
- **Portão 1:** decidido pelo lead por delegação (vila **B** “na orla”; heróis **A** “brinquedo brilhante”; UI v2). Reversível.
- **Agora (2026-11-24):** direção reaberta (D7–D13). Rastro v2 com caminho aprovado; trio v2 (Rastro v2.1, Pico v2, Leme v2) pronto para aprovação em 3D; mundo e som em seguida.
- **Próximo marco:** **Portão 2** — Thiago joga o primeiro minuto + mapa completo e **ouve** o som.
- **Instrução de Thiago:** concluir o RB-R1 e **PARAR** (não iniciar RB-05) para uma pausa de análise da sequência.

## 2. Kanban do RB-R1
**Concluído e integrado (`feature/rb-r1-reorientacao`):**
- Bíblia de estilo (`docs/style-bible.md`); decisões D1–D6 no ticket.
- Diálogos híbridos: `game/episodes/ep01/ep01_dialogue.json` (emotes, intenção, `radio_key`), `game/i18n/pt_BR.radio.json` (25 falas de Farol 7).
- Heróis direção A: Rastro, Pico, Leme (rig 28 ossos, 7 expressões + visemas, olhar, walk/run/stop/jump/team_pose…), piloto, filhote, 3 moradores, retratos `game/ui/portraits/` — no HUD e na tela-título.
- Mundo: `game/episodes/ep01/world/` — `harbor_slice.tscn` (vila Farol 7 + porto + margem sul), `river_world.tscn` (rio 152 m, ponte, banco de areia, enseada), `island_world.tscn`, `horizon.tscn` — **todos ligados aos estágios**. Mapa: `world/LAYOUT_PROPOSTO.md` (adotado; ilha +90 m em x).
- UI v2: marca SVG (`game/ui/brand/`), tema v2, tela-título com heróis 3D animados, HUD com retratos/emotes/botão de ação, opções (`user://options.cfg`).
- Áudio: balbucio (personagens) + rádio Piper (Farol 7) com boca sincronizada; rádio repete instruções após o balbucio; música e foley CC0; zonas de ambiente; passos por piso; `AudioDirector`. Mixagem de referência −16,2 LUFS / −1,05 dBTP (medida; **ninguém ouviu**).
- Visual v2: céu com nuvens, contorno nos personagens, atmosfera.
- Jogabilidade (merge `ea8e4a8`): mapa em tamanho final, correr com rampa, pulo do Pico (automático na borda + mira assistida; erro volta ao último apoio), pose de equipe 1,2 s na troca (`team_pose_started/finished`), retorno visual (`game/actors/feedback/`), 10 emblemas (`Ep01Main.collectible_found(count,total)`), câmera com herói em 12,4–16,2% da tela nas 3 proporções e sem oclusão. Bot completa o episódio no mapa novo (238 s de jogo no modo rápido).
- Claude Code: `.claude/agents/` (Opus 5.5; lead medium, subagentes low), `.claude/settings.json`, `CLAUDE.md`, skills; toolchain Linux `tools/*.sh`.

**Feito em 2026-11-24 (nuvem):** tarefa 1 (ilha sem pedras duplicadas; piloto e filhote com modelos finais via `StoryFigure`; filhote pisa na buzina na fala final), tarefa 2 (atracação pelo norte, rumo alvo π, partida pelo noroeste) e tarefa 3 (17 moradores animados no cais, `gameplay`, branch `feature/rb-r1-moradores`). Tarefa 5 (contador de emblemas no HUD) e tarefa 6 (opções valem no jogo; Opções na pausa; bug do ducking que perdia o volume escolhido corrigido). Tarefa 7 medida: modo humano 3,94 min (meta 8 min, NÃO atingida; ver evidências no ticket). Suíte: 2687 PASS. **Direção reaberta (D7–D10 no ticket):** heróis v2 em traje de herói em estudo (`art3d`, esforço alto, branch `feature/rb-r1-herois-v2`), vitrine para Thiago antes de entrar no jogo; depois mundo; depois som (talvez Google AI Studio). **Render na nuvem funciona:** `xvfb-run` + Vulkan llvmpipe com `--write-movie` (caminho ABSOLUTO no `--write-movie`).

**Rastro v2 (2026-11-24, art3d, branch `feature/rb-r1-rastro-v2`, sem push):** proposta de herói no padrão D11/D13 lado a lado (só na vitrine `game/lookdev/`). Fontes em `source_art/characters/rastro_v2/`, GLB em `game/assets/models/characters/rastro_v2.glb`; evidências no ticket. Thiago aprovou o caminho; v2.1 (H1: pés com folga ≥ 3 cm medida, mãos relaxadas + punho por shape key, team_pose em contrapposto, olho corrigido na Godot, brilho calibrado no import) feita na mesma branch. Pico e Leme v2 em paralelo reusam `game/lookdev/gltf_pbr_import.gd` e `<id>_v2_model.tscn`.

**A fazer para fechar o RB-R1 (nesta ordem):**
4. Grama menos saturada (verde-limão) — materiais `mat_env_*` em `source_art/environment` ou atmosfera.
5. Contador de emblemas no HUD (ligar `collectible_found`).
6. Opções ligadas ao jogo (volumes por bus, tamanho de legenda, movimento reduzido, assistência de pilotagem).
7. Medir duração em **modo humano** (`--ep01-demo-human`; meta ≥ 8 min) e registrar.
8. Capturas 16:9 / 20:9 / 4:3 (menu, cais, inspeção, pulo do Pico, troca de equipe, atracação).
9. Desempenho (3 passagens) e vídeo com som medido.
10. Evidências no `specs/features/RB-R1.md`; revisão independente (`reviewer`); correções; nova revisão.
11. Merge em `main`, build Windows, pacote do **Portão 2** e **PARAR**.

**Dívida conhecida (backlog):** capitão adulto fraco; mancha no olho do filhote ao piscar; faixas do colete da Leme; sem marimba/pizzicato CC0 (xilofone/harpa); ~1000 draw calls (celular); teste de retrato fraco; Godot reescreve `game/audio/default_bus_layout.tres` (só comentários; restaurar com `git checkout` antes de commitar — `tools/test.sh` já faz).

## 3. Como retomar
### Na nuvem / Linux (Claude Code)
```bash
git clone https://github.com/thiagomendes/rota-brava && cd rota-brava
git checkout feature/rb-r1-reorientacao
sudo apt-get update && sudo apt-get install -y curl unzip xz-utils python3 python3-venv \
  libxi6 libxkbcommon0 libsm6 libgl1 libegl1 libvulkan1 mesa-vulkan-drivers xvfb   # libs para Godot/Blender
bash tools/setup-linux.sh            # Godot 4.7.2 (+templates) e Blender 4.5.16 em .tools/ (SHA-256)
bash tools/test.sh                   # import + suíte com timeout (filtro: bash tools/test.sh dialogue)
bash tools/build-windows.sh          # exporta build/windows/RotaBrava.exe a partir do Linux
```
- **Ver o jogo sem GPU** (não verificado na nuvem): `xvfb-run -a bash tools/godot.sh --path game --rendering-driver vulkan res://episodes/ep01/ep01_main.tscn --ep01-start=dock_investigation --write-movie /tmp/f/f.png --fixed-fps 10 --quit-after 30` (Vulkan por software via lavapipe; se falhar, tente `--rendering-method gl_compatibility`, mas o visual do renderizador Mobile pode diferir). Se não houver renderização possível, registre a captura como pendente para Windows.
- **Áudio** (Piper/FluidSynth): `tools/setup-audio-tools.ps1` é Windows; no Linux use `python3 -m venv .tools/py && .tools/py/bin/pip install piper-tts==1.8.0 numpy scipy soundfile mido onnxruntime` e `apt-get install fluidsynth`; os takes Piper já gerados estão em `source_audio/radio/takes/` (reuso garante WAV idênticos). Só regenere se mudar falas.
### No Windows (OpenCode ou Claude Code)
```powershell
./tools/setup-toolchain.ps1 ; ./tools/godot.ps1 --headless --path game --import
./tools/godot.ps1 --headless --path game --script res://tests/run_tests.gd ; ./tools/build-windows.ps1
```
### Comum
- `--ep01-start=<estado>` inicia num estado; `--ep01-demo` bot com entrada real; `--ep01-demo-human` bot com ritmo humano; `--ref-demo` tela de referências; `--perf-probe` sonda de desempenho.
- **Limite de tempo em testes**: todo laço de espera precisa de limite; suíte com timeout ≤ 15 min (`tools/test.sh`).
- Outra resolução de captura exige `game/override.cfg` temporário (o projeto ignora `--resolution`); nunca versionar.

## 4. Branches
| Branch | Situação |
|---|---|
| `feature/rb-r1-reorientacao` | **integração ativa** (tudo do RB-R1 até agora) |
| `feature/rb-r1-{jogo,herois,mundo,marca-ui,audio,conteudo}` | já integradas; podem ser reusadas para follow-ups |
| `feature/rb-r1-lookdev` | renderizador Forward+ e vitrine de materiais (não integrada) |
| `feature/rb-r1-rastro-v2` | Rastro v2.1 (H1), `7f146fe` + `.gitignore`; caminho aprovado por Thiago, ajustes aplicados |
| `feature/rb-r1-pico-v2` | Pico v2 (H2), `7d293d5`, base `e4edd34` |
| `feature/rb-r1-leme-v2` | Leme v2 (H3), `003ea04`, base `e4edd34` |
| (trio) | **aguarda aprovação de Thiago** no visualizador 3D https://claude.ai/artifact/1ZKx8zKZ2HxQn85ZtL9EGR; depois integrar as três branches (conflito esperado só no fim de `source_art/manifest.json`) e revisar com `reviewer` |
| `main` | RB-01..RB-04; recebe o RB-R1 só após revisão e Portão 2 |

## 5. Agentes
- **Claude Code:** `.claude/agents/` — `rota-lead` (agente principal, `claude-opus-5-5`, esforço **medium**), `art3d` e `ux` (`claude-opus-5-5`, esforço **medium**; eram high em 2026-11-24, Thiago baixou na retomada), `gameplay`, `adventure`, `audio`, `build-qa`, `reviewer` (`claude-opus-5-5`, esforço **low**). Ver com `/tasks`.
- **OpenCode:** `.opencode/agents/` — Opus 5.5 low (art3d, gameplay, ux, audio, reviewer) e DeepSeek V4.1 Flash Free max (adventure, build-qa).
- Placar de qualidade: `docs/agent-scorecard.md`.

## 6. Regras que não mudam
SDD (ticket antes do código, evidências no ticket); merge pelo lead depois da revisão; push da branch em uso pelo lead a cada etapa (autorizado por Thiago em 2026-11-24; inclui o merge em `main` e o push de `main` na tarefa 11, depois da revisão), nunca force; geometria 100% do zero; áudio de terceiros só CC0/PD com procedência por arquivo; sem modelo de imagem; balbucio + rádio Piper; nunca afirmar que viu/ouviu/mediu sem ter feito; Thiago ouve e aprova o som.

## 7. Histórico curto
RB-01 fundação → RB-02 missão em blocos → RB-03 referências → RB-04 primeiro minuto (base técnica; arte reprovada) → **RB-R1 reorientação premium (ativo, ~85%)** → (pausa de análise) → RB-05 episódio final → RB-06 portabilidade → RB-07 candidato.
