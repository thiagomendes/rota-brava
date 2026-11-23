#requires -Version 7
# Executa o Blender fixado (portatil) a partir da raiz. Uso: ./tools/blender.ps1 --background arquivo.blend --python script.py -- args
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot/common.ps1"
$bl = (Get-Content (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json).blender
$exe = Join-Path (Get-ToolsRoot $root) ".tools/blender/$($bl.folder)/$($bl.exe)"
if (-not (Test-Path $exe)) { throw 'Blender ausente. Rode ./tools/setup-toolchain.ps1' }
& $exe @args
exit $LASTEXITCODE
