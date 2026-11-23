# Rota Brava — instruções para agentes

Contrato de produto: `SPEC.md`. Processo: seções 10 a 13. Perfis em `.opencode/agents/`, procedimentos em `.opencode/skills/`.

## Regras
- SDD: ticket em `specs/features/RB-XX.md` antes do código; evidências no mesmo arquivo.
- Uma feature branch local por tarefa (`feature/rb-XX-...`), merge local em `main`. Nunca `git push`.
- Godot fixada em `tools/toolchain.json`. Instalar com `tools/setup-toolchain.ps1`; rodar com `tools/godot.ps1`.
- Ficam fora do Git: `.tools/`, `build/`, `captures/`, `logs/`, `game/.godot/`.
- GDScript tipado. Entrada só por intenções da Input Map. Textos fora das regras (catálogo i18n).
- Geometria 100% original. Marque provisórios. Não afirme ter visto, ouvido ou medido sem ter feito.
- Windows: PowerShell 7 (`pwsh`). Em background o shell não inicia `pwsh`; rode scripts em primeiro plano.
