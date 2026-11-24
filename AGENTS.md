# Rota Brava — instruções para agentes

**Ao iniciar uma sessão, leia primeiro `docs/STATE.md`** (estado, kanban, como retomar); atualize-o e commite a cada etapa.
Contrato de produto: `SPEC.md`. Processo: seções 10 a 13. Perfis em `.opencode/agents/`, procedimentos em `.opencode/skills/`.

## Regras
- SDD: ticket em `specs/features/RB-XX.md` antes do código; evidências no mesmo arquivo.
- Uma feature branch local por tarefa (`feature/rb-XX-...`), merge local em `main`. Nunca `git push`.
- Godot fixada em `tools/toolchain.json`. Instalar com `tools/setup-toolchain.ps1`; rodar com `tools/godot.ps1`.
- Ficam fora do Git: `.tools/`, `build/`, `captures/`, `logs/`, `game/.godot/`.
- GDScript tipado. Entrada só por intenções da Input Map. Textos fora das regras (catálogo i18n).
- Geometria 100% original. Marque provisórios. Não afirme ter visto, ouvido ou medido sem ter feito.
- Modelos (decisão de Thiago, RB-R1): `art3d`, `gameplay`, `ux`, `audio`, `reviewer` em `anthropic/claude-opus-5-5#low`; `adventure`, `build-qa` em `opencode/deepseek-v4.1-flash-free#max`.
- Áudio: amostras de terceiros só CC0/domínio público com procedência por arquivo; personagens falam em balbucio sintetizado + legenda com ícones; instruções e dicas por Farol 7 no rádio (TTS local Piper, só na produção). Sem modelo de imagem: alvo visual por estudos no Blender e SVG do projeto.
- Windows: PowerShell 7 (`pwsh`). Em background o shell não inicia `pwsh`; rode scripts em primeiro plano.
