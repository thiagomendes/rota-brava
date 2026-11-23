---
name: RB Godot Build
description: Instalar a Godot fixada, importar, testar, exportar e dar smoke test na build Windows de Rota Brava (SPEC secao 9).
---

## Entradas
Checkout do repositorio no Windows com PowerShell 7. Versoes e SHA-256 em `tools/toolchain.json`.

## Procedimento
Rodar em primeiro plano, a partir da raiz (o shell em background nao inicia `pwsh`):
```powershell
./tools/setup-toolchain.ps1                                   # instala em .tools/ (idempotente)
./tools/godot.ps1 --headless --path game --import
./tools/godot.ps1 --headless --path game --script res://tests/run_tests.gd
./tools/build-windows.ps1                                     # build/windows/RotaBrava.exe
./tools/smoke-test.ps1                                        # abre o exe, envia teclas por scancode, captura, fecha
```
Notas: `RotaBrava.console.exe` e um lancador que abre `RotaBrava.exe` como filho e repassa stdout. Teclas para o jogo precisam de scancode (`keybd_event`), nao de `SendKeys`.

## Teste
Todos os comandos retornam 0 e o smoke test imprime `RESULTADO: OK`.

## Entrega
Comandos executados, versoes, capturas em `captures/`, log em `logs/`. Headless nao prova render, som, UX nem desempenho.
