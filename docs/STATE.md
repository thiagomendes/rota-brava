# Rota Brava · Estado do projeto (passagem entre sessões)

> **Leia este arquivo primeiro** ao abrir uma nova sessão, com qualquer modelo. Ele é atualizado e commitado a cada etapa.
> Depois leia: `AGENTS.md`, `SPEC.md`, `specs/features/RB-R1.md` (ticket ativo), `docs/style-bible.md`, `docs/agent-scorecard.md`.
> Nunca confie só neste resumo: confirme com `git log`, `git worktree list` e rodando os testes.

**Atualizado em:** 2026-11-24 · **Branch de integração ativa:** `feature/rb-r1-reorientacao` · **`main`:** RB-01 a RB-04 (RB-04 só como base técnica).

## 1. Onde estamos
- **Ticket ativo:** `RB-R1 · Reorientação de qualidade (premium)` (`specs/features/RB-R1.md`). Origem: Thiago reprovou a arte/som/UI do RB-04.
- **Portão 1:** decidido pelo lead por delegação de Thiago (vila **B** “na orla”; heróis direção **A** “brinquedo brilhante”; UI v2). Reversível.
- **Próximo marco:** **Portão 2** (Thiago joga o primeiro minuto + mapa completo e OUVE o som). **Instrução de Thiago: PARAR ao final do RB-R1** (não iniciar RB-05) para uma pausa de análise da sequência.

## 2. Kanban do RB-R1
**Concluído e integrado em `feature/rb-r1-reorientacao`:**
- Bíblia de estilo (`docs/style-bible.md`); decisões D1–D6 no ticket; modelos dos agentes em `.opencode/agents/` (Opus 5.5 low: art3d, gameplay, ux, audio, reviewer; DeepSeek V4.1 Flash Free max: adventure, build-qa).
- Diálogos híbridos (`game/episodes/ep01/ep01_dialogue.json`, `game/i18n/pt_BR.radio.json`).
- Heróis A: Rastro, Pico, Leme (rig 28 ossos, rosto, visemas, corrida, pose de equipe), piloto, filhote, 3 moradores, retratos (`game/ui/portraits/`).
- Mundo: vila Farol 7 + porto (`game/episodes/ep01/world/harbor_slice.tscn`, já no jogo), margem sul, `river_world.tscn`, `island_world.tscn`, `horizon.tscn` (existem; **ainda não ligadas aos estágios**), mapa em `world/LAYOUT_PROPOSTO.md` (adotado).
- UI v2: marca SVG (`game/ui/brand/`), tema v2, tela-título com heróis 3D, HUD com retratos/emotes/botão de ação, opções.
- Áudio: balbucio + rádio Piper + música/foley CC0, `AudioDirector` ligado (fala com boca sincronizada, rádio após instruções, zonas, passos por piso).
- Visual v2: céu com nuvens (`game/art/sky.gdshader`), contorno (`outline.gdshader`), atmosfera.
- Testes: **2563 PASS** (último resultado medido no commit `c69fecc`).

**Em andamento:** frente **jogabilidade** (agente `gameplay`, worktree `C:\Git\rota-brava-wt\rb-r1-jogo`, branch `feature/rb-r1-jogo`): mapa em tamanho final (constantes do LAYOUT), correr, pulo do Pico, pose de equipe na troca, retorno visual, 10 colecionáveis, câmera (herói 12–18% da tela, sem oclusão), ligar cenas de mundo, duração ≥ 8 min. **Incidente 2026-11-24:** teste `game_feel` travou ~12 h; processos encerrados e tarefa devolvida com regra de limite de tempo.

**A fazer pelo lead depois da jogabilidade (nesta ordem):**
1. Merge de `feature/rb-r1-jogo` na integração; resolver conflitos com áudio/elenco.
2. Piloto + filhote no acampamento da ilha; filhote pisando na buzina no final.
3. 12–20 moradores animados na vila.
4. Grama menos saturada (verde-limão) — materiais `mat_env_*` / atmosfera.
5. Contador de colecionáveis no HUD.
6. Opções ligadas ao jogo (volumes por bus, legenda, movimento reduzido, assistência).
7. Capturas 16:9 / 20:9 / 4:3 (menu, cais, inspeção, atracação).
8. Desempenho: `./tools/perf-capture.ps1` (3 passagens).
9. Vídeo com som: `./tools/record-playthrough.ps1` + `python tools/measure_video_audio.py captures/ep01-playthrough.avi`.
10. Revisão independente (`reviewer`); corrigir; nova revisão.
11. Merge em `main`, build, pacote do **Portão 2** e **parar**.

**Dívida conhecida (backlog):** capitão adulto fraco; mancha no olho do filhote ao piscar; faixas do colete da Leme; sem marimba/pizzicato CC0 (xilofone/harpa); ~1000 draw calls (celular); teste de retrato fraco; Godot reescreve `game/audio/default_bus_layout.tres` (só remove comentários; restaurar com `git checkout` antes de commitar).

## 3. Como retomar (comandos)
```powershell
cd C:\Git\rota-brava
git status ; git log --oneline -15 ; git worktree list
./tools/setup-toolchain.ps1                 # Godot 4.7.2 + Blender 4.5.16 em .tools/ (hash conferido)
./tools/setup-audio-tools.ps1               # só para regenerar áudio (Piper, FluidSynth, CC0); roda no worktree de áudio
./tools/godot.ps1 --headless --path game --import
./tools/godot.ps1 --headless --path game --script res://tests/run_tests.gd   # suíte; -- --only=<parte> filtra
./tools/build-windows.ps1                   # build/windows/RotaBrava.exe
git checkout -- game/audio/default_bus_layout.tres   # antes de commitar
```
- Ver o jogo sem desktop livre: `./tools/godot.ps1 --path game res://episodes/ep01/ep01_main.tscn --ep01-start=<estado> --write-movie <pasta>\f.png --fixed-fps 10 --resolution 1280x720 --quit-after 30`. Outra resolução exige `game/override.cfg` temporário (nunca versionar).
- `--ep01-demo` = bot com entrada real; `--ref-demo` = tela de referências; `--perf-probe` = sonda de desempenho.
- Shell: PowerShell 7; use `workdir` (não `cd`); se falhar ao iniciar com “Acesso negado”, repita. Em background o shell não inicia `pwsh`.
- **Limite de tempo:** todo teste com laço de espera precisa de limite; rode suíte com timeout ≤ 15 min.

## 4. Worktrees e branches
| Worktree | Branch | Situação |
|---|---|---|
| `C:\Git\rota-brava` | `feature/rb-r1-reorientacao` | integração ativa |
| `C:\Git\rota-brava-wt\rb-r1-jogo` | `feature/rb-r1-jogo` | **em andamento** (não integrado) |
| `rb-r1-herois`, `rb-r1-mundo`, `rb-r1-marca-ui`, `rb-r1-audio`, `rb-r1-conteudo` | idem | integrados; podem ser reutilizados para follow-ups |

## 5. Regras que não mudam
SDD (ticket antes do código, evidências no ticket); merge só LOCAL; nunca `git push`; geometria 100% do zero; áudio de terceiros só CC0/PD com procedência por arquivo; sem modelo de imagem; balbucio + rádio Piper; nunca afirmar que viu/ouviu/mediu sem ter feito; Thiago é quem ouve e aprova o som.

## 6. Histórico curto
RB-01 fundação → RB-02 missão em blocos → RB-03 referências → RB-04 primeiro minuto (base técnica; arte reprovada) → **RB-R1 reorientação premium (ativo)** → (pausa de análise) → RB-05 episódio final → RB-06 portabilidade → RB-07 candidato.
