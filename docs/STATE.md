# Rota Brava · Estado do projeto (passagem entre sessões)

> **Leia este arquivo primeiro** ao abrir uma nova sessão, com qualquer modelo/ferramenta. Atualize e commite a cada etapa.
> Depois leia: `CLAUDE.md`/`AGENTS.md`, `SPEC.md`, `specs/features/RB-R1.md` (ticket ativo), `docs/style-bible.md`, `docs/agent-scorecard.md`.
> Nunca confie só neste resumo: confirme com `git log`, `git worktree list`/branches e rodando os testes.

**Atualizado em:** 2026-11-24 (pausa pedida por Thiago; migração do OpenCode/Windows para o Claude Code na nuvem).
**Remoto:** `https://github.com/thiagomendes/rota-brava` (todas as branches enviadas).
**Branch de integração ativa:** `feature/rb-r1-reorientacao` (commit no topo = estado mais recente). **`main`:** RB-01 a RB-04 (RB-04 só base técnica).
**Última suíte medida na integração:** `RESULTADO: OK (2650 PASS, 0 FALHA(S))` (Windows, Godot 4.7.2).
**Nuvem (2026-11-24):** `tools/setup-linux.sh` e `tools/test.sh` verificados no Linux: 2650 PASS em 1 min 42 s no `5f877ec`. Ambiente pessoal `rota-brava` libera `download.blender.org` (o Default bloqueava o Blender).

## 1. Onde estamos
- **Ticket ativo:** `RB-R1 · Reorientação de qualidade (premium)`. Origem: Thiago reprovou arte/som/UI do RB-04 (“personagens nada infantis, gráfico ruim, som primitivo, mapa sem tamanho/densidade”).
- **Portão 1:** decidido pelo lead por delegação (vila **B** “na orla”; heróis **A** “brinquedo brilhante”; UI v2). Reversível.
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

**Feito em 2026-11-24 (nuvem):** tarefa 1 (ilha sem pedras duplicadas; piloto e filhote com modelos finais via `StoryFigure`; filhote pisa na buzina na fala final), tarefa 2 (atracação pelo norte, rumo alvo π, partida pelo noroeste) e tarefa 3 (17 moradores animados no cais, `gameplay`, branch `feature/rb-r1-moradores`). Suíte: 2673 PASS. **Render na nuvem funciona:** `xvfb-run` + Vulkan llvmpipe com `--write-movie` (caminho ABSOLUTO no `--write-movie`).

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
| `main` | RB-01..RB-04; recebe o RB-R1 só após revisão e Portão 2 |

## 5. Agentes
- **Claude Code:** `.claude/agents/` — `rota-lead` (agente principal, `claude-opus-5-5`, esforço **medium**), `gameplay`, `adventure`, `art3d`, `ux`, `audio`, `build-qa`, `reviewer` (`claude-opus-5-5`, esforço **low**). Ver com `/tasks`.
- **OpenCode:** `.opencode/agents/` — Opus 5.5 low (art3d, gameplay, ux, audio, reviewer) e DeepSeek V4.1 Flash Free max (adventure, build-qa).
- Placar de qualidade: `docs/agent-scorecard.md`.

## 6. Regras que não mudam
SDD (ticket antes do código, evidências no ticket); merge pelo lead depois da revisão; push da branch em uso pelo lead a cada etapa (autorizado por Thiago em 2026-11-24; inclui o merge em `main` e o push de `main` na tarefa 11, depois da revisão), nunca force; geometria 100% do zero; áudio de terceiros só CC0/PD com procedência por arquivo; sem modelo de imagem; balbucio + rádio Piper; nunca afirmar que viu/ouviu/mediu sem ter feito; Thiago ouve e aprova o som.

## 7. Histórico curto
RB-01 fundação → RB-02 missão em blocos → RB-03 referências → RB-04 primeiro minuto (base técnica; arte reprovada) → **RB-R1 reorientação premium (ativo, ~85%)** → (pausa de análise) → RB-05 episódio final → RB-06 portabilidade → RB-07 candidato.
