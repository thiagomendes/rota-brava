#requires -Version 7
<# Importa o projeto e exporta o perfil `Windows Desktop` para build/windows/RotaBrava.exe. #>
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$cfg = (Get-Content (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json).godot
. "$PSScriptRoot/common.ps1"
$toolsRoot = Get-ToolsRoot $root
$godot = Join-Path $toolsRoot ".tools/godot/$($cfg.editor.console)"
if (-not (Test-Path $godot)) { throw 'Godot ausente. Rode ./tools/setup-toolchain.ps1' }
$tpl = Join-Path $toolsRoot ".tools/godot/editor_data/export_templates/$($cfg.templatesDir)/windows_release_x86_64.exe"
if (-not (Test-Path $tpl)) { throw "Template de exportacao ausente: $tpl" }

$out = Join-Path $root 'build/windows'
if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Force -Path $out | Out-Null

$game = Join-Path $root 'game'
Write-Host "> $godot --headless --path game --import"
& $godot --headless --path $game --import
if ($LASTEXITCODE -ne 0) { throw 'Falha na importacao do projeto Godot.' }

$target = Join-Path $out 'RotaBrava.exe'
Write-Host "> $godot --headless --path game --export-release 'Windows Desktop' $target"
& $godot --headless --path $game --export-release 'Windows Desktop' $target
if ($LASTEXITCODE -ne 0) { throw 'Falha na exportacao para Windows.' }
if (-not (Test-Path $target)) { throw 'RotaBrava.exe nao foi gerado.' }
Get-Item $target | Select-Object FullName, Length
