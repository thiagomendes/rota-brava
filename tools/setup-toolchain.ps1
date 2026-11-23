#requires -Version 7
<#
  Instala a Godot fixada em tools/toolchain.json dentro de .tools/godot (ignorado pelo Git).
  Modo self-contained: o arquivo `_sc_` faz a Godot guardar templates e configuracao ao lado do executavel,
  sem tocar em %APPDATA%. Idempotente; verifica SHA-256 de cada download.
#>
[CmdletBinding()]
param([switch]$Force, [switch]$SkipBlender)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$cfg = (Get-Content (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json).godot
$dir = Join-Path $root '.tools/godot'
$cache = Join-Path $root '.tools/cache'
New-Item -ItemType Directory -Force -Path $dir, $cache | Out-Null

function Get-Verified($item, $name) {
    $file = Join-Path $cache $name
    if (-not (Test-Path $file) -or $Force) {
        Write-Host "Baixando $name"
        Invoke-WebRequest -Uri $item.url -OutFile $file -UseBasicParsing
    }
    $hash = (Get-FileHash $file -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne $item.sha256) {
        Remove-Item $file -Force
        throw "SHA-256 divergente em $name (esperado $($item.sha256), obtido $hash)."
    }
    return $file
}

$console = Join-Path $dir $cfg.editor.console
if (-not (Test-Path $console) -or $Force) {
    $zip = Get-Verified $cfg.editor 'godot-editor-win64.zip'
    Expand-Archive -Path $zip -DestinationPath $dir -Force
}
New-Item -ItemType File -Force -Path (Join-Path $dir '_sc_') | Out-Null

$tplTarget = Join-Path $dir "editor_data/export_templates/$($cfg.templatesDir)"
if (-not (Test-Path (Join-Path $tplTarget 'windows_release_x86_64.exe')) -or $Force) {
    $tpz = Get-Verified $cfg.templates 'godot-export-templates.tpz'
    $tmp = Join-Path $cache 'templates-extract'
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    Expand-Archive -Path $tpz -DestinationPath $tmp -Force
    New-Item -ItemType Directory -Force -Path $tplTarget | Out-Null
    Copy-Item (Join-Path $tmp 'templates/*') $tplTarget -Recurse -Force
    Remove-Item $tmp -Recurse -Force
}

& $console --version
if ($LASTEXITCODE -ne 0) { throw 'Godot instalada nao respondeu a --version.' }
Write-Host "Godot pronta em $dir"

# Blender portatil (zip oficial, hash conferido) em .tools/blender. Use -SkipBlender para pular.
if (-not $SkipBlender) {
    $bl = (Get-Content (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json).blender
    $blDir = Join-Path $root '.tools/blender'
    $blExe = Join-Path $blDir "$($bl.folder)/$($bl.exe)"
    if (-not (Test-Path $blExe) -or $Force) {
        $zip = Get-Verified $bl "blender-$($bl.version)-windows-x64.zip"
        New-Item -ItemType Directory -Force -Path $blDir | Out-Null
        Expand-Archive -Path $zip -DestinationPath $blDir -Force
    }
    & $blExe --background --version | Select-Object -First 1
    if ($LASTEXITCODE -ne 0) { throw 'Blender instalado nao respondeu a --version.' }
    Write-Host "Blender pronto em $blDir"
}
