#requires -Version 7
# Executa a Godot fixada (console) a partir da raiz do repositorio. Uso: ./tools/godot.ps1 <args da Godot>
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$cfg = (Get-Content (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json).godot
$exe = Join-Path $root ".tools/godot/$($cfg.editor.console)"
if (-not (Test-Path $exe)) { throw "Godot ausente. Rode ./tools/setup-toolchain.ps1" }
& $exe @args
exit $LASTEXITCODE
