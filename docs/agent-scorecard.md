# Placar dos agentes (RB-R1 em diante)

Pedido de Thiago: monitorar desempenho e qualidade, em especial do DeepSeek (gratuito), e avisar se estiver ruim.

Critérios por tarefa (0 a 2 cada): **Contrato** (fez o que foi pedido, na área de escrita), **Verificação** (rodou o que afirmou; nada inventado), **Qualidade** (resultado utilizável sem retrabalho do lead), **Regras** (originalidade, Git, sem push, sem tocar fora da área). Retrabalho = correções que o lead ou outro agente precisou fazer.

| Data | Agente | Modelo (confirmado?) | Tarefa | Contrato | Verificação | Qualidade | Regras | Retrabalho / observações |
|---|---|---|---|---|---|---|---|---|
| 2026-11-23 | adventure | DeepSeek V4.1 Flash Free (opencode) — confirmado pelo agente | RB-R1 diálogos híbridos: `ep01_dialogue.json` (47 falas, emotes), 25 falas de rádio, `test_dialogue.gd` | 2 | 2 | 1 | 2 | Seguiu o contrato à risca; suíte 1532 PASS e mutação real com restauração byte a byte. Texto bom, curto e gentil. 2 erros de conteúdo que teste não pega: “água corre para a esquerda” (depende da câmera) e “botão de partida perto do volante” (não existe). Devolvido para correção (teste de iteração). |
| 2026-11-23 | adventure | DeepSeek V4.1 Flash Free — confirmado | Correção das 2 falas de rádio + revisão das demais | 2 | 2 | 2 | 2 | Corrigiu em 1 rodada, sem mexer fora do arquivo; checou por iniciativa própria no código que os objetos citados existem. Sem retrabalho. **Avaliação parcial do DeepSeek: adequado para tarefas de conteúdo bem especificadas.** |
| 2026-11-23 | ux | Claude Opus 5.5 — confirmado | RB-R1 marca SVG (emblema, logo, 28 pictogramas), tema v2, tela-título, HUD v2 com retratos/ação/emotes, opções | 2 | 2 | 2 | 2 | Salto visível na UI (vi 16:9 e título). Achou e corrigiu 3 falhas próprias; mutações reais. Pendências honestas: retratos ainda são pictogramas, heróis do título são cápsulas, estudos SVG com ícone antigo da corda. Integração (emotes, sons de UI) feita pelo lead. |
