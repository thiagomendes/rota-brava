# Rota Brava

Jogo 3D de aventuras episódicas para crianças de 5 a 12 anos (Godot 4.7.2 + Blender 4.5.16, GDScript tipado). Contrato de produto: [`SPEC.md`](SPEC.md). Estado atual e como retomar: [`docs/STATE.md`](docs/STATE.md) — **leia primeiro**.

## Qual branch usar

| Branch | O que tem | Estado |
|---|---|---|
| **`feature/rb-r1-reorientacao`** | **Trabalho mais recente.** RB-01 a RB-04 + todo o RB-R1 (heróis crianças-heróis, vila Farol 7, rio, ilha, UI v2, balbucio + rádio, jogabilidade nova), `docs/STATE.md`, agentes do Claude Code (`.claude/`) e toolchain Linux. Suíte: 2650 PASS. | **Integração ativa — continue daqui.** RB-R1 ~85%; ainda sem revisão independente e sem o Portão 2 de Thiago. |
| `main` | RB-01 (fundação), RB-02 (missão em blocos), RB-03 (referências), RB-04 (primeiro minuto). | Estável e revisado, mas **desatualizado**: a arte/som/UI do RB-04 foi **reprovada** por Thiago e substituída no RB-R1. Só recebe o RB-R1 depois da revisão e do Portão 2. |
| `feature/rb-r1-{herois,mundo,marca-ui,audio,conteudo,jogo}` | Frentes do RB-R1, uma por agente. | Já integradas em `feature/rb-r1-reorientacao`. Reusar só para follow-ups. |
| `feature/rb-01-*` a `feature/rb-04-*` | Histórico de RB-01 a RB-04. | Já integradas em `main`. Só histórico. |

## Tickets (SDD)
`specs/features/RB-01.md` … `RB-04.md` (concluídos; RB-04 reprovado na arte) e **`RB-R1.md` (ativo)**. Cada ticket traz objetivo, critérios, evidências e revisão.

## Começar
- Windows: `./tools/setup-toolchain.ps1`, `./tools/godot.ps1 --headless --path game --script res://tests/run_tests.gd`, `./tools/build-windows.ps1`.
- Linux/nuvem: `bash tools/setup-linux.sh`, `bash tools/test.sh`, `bash tools/build-windows.sh` (só na branch de integração).
- Agentes: `.claude/agents/` (Claude Code) e `.opencode/agents/` (OpenCode). Regras: `CLAUDE.md` / `AGENTS.md`.
