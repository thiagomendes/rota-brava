---
name: RB SDD Ticket
description: Escrever, executar e fechar um ticket SDD de Rota Brava em specs/features/RB-XX.md (SPEC secoes 10 e 13).
---

## Entradas
Numero e titulo da tarefa (SPEC secao 10), secoes da SPEC aplicaveis, estado atual do Git.

## Procedimento
1. Criar `feature/rb-XX-<nome>` a partir de `main`.
2. Escrever `specs/features/RB-XX.md` antes do codigo, com: objetivo observavel, referencia a SPEC, escopo e fora de escopo, contrato de entrada/saida ou interacao, criterios de aceite numerados, casos de falha, verificacao (comandos).
3. Implementar a menor mudanca que cumpra os criterios; commits focados.
4. Preencher "Evidencias" com comandos realmente executados, resultados e caminhos de captura. Separar o que foi medido/visto do que ficou pendente.
5. Pedir revisao ao `reviewer`; corrigir e repetir. Apos 3 reprovacoes pelo mesmo problema, reduzir o recorte ou trocar o especialista.
6. Merge local `--no-ff` em `main`, repetir o smoke test no resultado integrado e registrar o commit no ticket.

## Teste
O ticket e valido se cada criterio de aceite tem um comando ou observacao que o prove.

## Entrega
Ticket com evidencias, parecer do revisor, hash do merge e proximo ticket pronto.
