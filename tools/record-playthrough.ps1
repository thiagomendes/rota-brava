#requires -Version 7
<#
  Grava o percurso completo do Episodio 01 (bot com entrada real) com o Movie Maker da Godot.
  Saida: captures/ep01-playthrough.avi (MJPEG, sem som: o audio entra no RB-04) e logs/record-stdout.log.
  Usa a build exportada (RotaBrava.console.exe) se existir; caso contrario, o projeto pela Godot fixada.
  Uso: ./tools/record-playthrough.ps1 [-Fps 30] [-Resolution 1280x720] [-FromSource]
#>
[CmdletBinding()]
param([int]$Fps = 30, [string]$Resolution = '1280x720', [switch]$FromSource)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot/common.ps1"
$cap = Join-Path $root 'captures'; $logs = Join-Path $root 'logs'
New-Item -ItemType Directory -Force -Path $cap, $logs | Out-Null
$out = Join-Path $cap 'ep01-playthrough.avi'
$log = Join-Path $logs 'record-stdout.log'
Remove-Item $out, $log -ErrorAction SilentlyContinue

$exe = Join-Path $root 'build/windows/RotaBrava.console.exe'
$common = @('--write-movie', $out, '--fixed-fps', $Fps, '--resolution', $Resolution)
$scene = 'res://episodes/ep01/ep01_main.tscn'
if (-not $FromSource -and (Test-Path $exe)) {
    Write-Host "> $exe $scene $($common -join ' ') --ep01-demo"
    & $exe $scene @common --ep01-demo *> $log
} else {
    $cfg = (Get-Content (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json).godot
    $godot = Join-Path (Get-ToolsRoot $root) ".tools/godot/$($cfg.editor.console)"
    Write-Host "> $godot --path game $scene $($common -join ' ') --ep01-demo"
    & $godot --path (Join-Path $root 'game') $scene @common --ep01-demo *> $log
}
$code = $LASTEXITCODE
Get-Content $log | Select-String '\[RB\] (bot|state)|ERROR|WARNING' | ForEach-Object { $_.Line }
if (Test-Path $out) { Get-Item $out | Select-Object FullName, @{n = 'MB'; e = { [math]::Round($_.Length / 1MB, 1) } } }
if ($code -ne 0) { throw "O bot nao concluiu o episodio (codigo $code). Veja $log" }
Write-Host 'Gravacao concluida: o bot chegou ao fim do episodio.'
