# Rota Brava · instruções para o Claude Code

@AGENTS.md

## Específico do Claude Code
- **Primeiro passo de toda sessão:** ler `docs/STATE.md` (estado, kanban, como retomar) e o ticket ativo em `specs/features/`.
- **Agentes** em `.claude/agents/` (todos em `claude-opus-5-5`): `rota-lead` é o orquestrador e agente principal da sessão (`.claude/settings.json`, esforço **medium**); `gameplay`, `adventure`, `art3d`, `ux`, `audio`, `build-qa`, `reviewer` são subagentes com esforço **low**. Confira com `/tasks` (mostra modelo e esforço do subagente). Skills em `.claude/skills/`.
- **Equivalência com o OpenCode:** `.opencode/agents/` continua valendo para quem usar o OpenCode (lá `adventure` e `build-qa` rodam em DeepSeek). No Claude Code, todos são Opus por decisão de Thiago.
- **Ambiente Linux (Claude Code na nuvem):** use os scripts bash — `tools/setup-linux.sh` (instala Godot 4.7.2 + templates + Blender 4.5.16 em `.tools/` com SHA-256), `tools/godot.sh`, `tools/blender.sh`, `tools/test.sh`, `tools/build-windows.sh`. Os `.ps1` são para Windows (ou `pwsh` no Linux, se instalado).
- **Paralelismo:** para escritas simultâneas, use subagentes com `isolation: worktree` ou `git worktree add` com branch própria; um responsável por arquivo; `project.godot`, cenas compartilhadas e `.blend` são serializados.
- **Push:** regra em `AGENTS.md` (lead envia a branch em uso a cada etapa; nunca force push).

## Escopo
Entregue o que foi pedido, no escopo pedido. Resolva sozinho as escolhas de rotina e pergunte só quando leituras diferentes levariam a trabalhos muito diferentes. Se concluir que o pedido está errado ou que há jeito melhor, diga numa frase e siga com o que foi pedido, sem estreitar, alargar nem transformar a tarefa por conta própria. Termine a tarefa inteira; se algo não der, faça o resto e diga com clareza o que faltou e por quê.
