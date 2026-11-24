#requires -Version 7
<#
  RB-R1: instala as ferramentas de audio de producao em .tools/ (fora do Git). Idempotente; confere SHA-256.
  - .tools/py            venv Python (numpy, scipy, soundfile, mido, piper-tts) com versoes fixadas
  - .tools/audio/fluidsynth   FluidSynth (LGPL-2.1) para render dos SoundFonts CC0
  - .tools/audio/voices  voz Piper pt_BR (dataset CC0)
  - .tools/audio/src/<id>     amostras/SoundFonts CC0 de tools/audio_assets.json
  Versoes e hashes: tools/toolchain.json (chave "audio") e tools/audio_assets.json.
  -Pin grava hashes ainda vazios (uso do mantenedor ao adicionar um item; revise a licenca antes).
#>
[CmdletBinding()]
param([switch]$Pin, [switch]$Force)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$tcPath = Join-Path $PSScriptRoot 'toolchain.json'
$assetsPath = Join-Path $PSScriptRoot 'audio_assets.json'
$tc = Get-Content $tcPath -Raw | ConvertFrom-Json
$cfg = $tc.audio
$assets = Get-Content $assetsPath -Raw | ConvertFrom-Json
$base = Join-Path $root '.tools/audio'
$cache = Join-Path $base 'cache'
$src = Join-Path $base 'src'
New-Item -ItemType Directory -Force -Path $base, $cache, $src | Out-Null
$dirty = $false

function Sha([string]$f) { (Get-FileHash $f -Algorithm SHA256).Hash.ToLowerInvariant() }

function Fetch([string]$url, [string]$file) {
  Write-Host "Baixando $url"
  curl.exe -sSfL -A 'Mozilla/5.0' -o $file $url
  if ($LASTEXITCODE) { throw "download falhou: $url" }
}

function Get-Kenney([string]$slug, [string]$file) {
  $jar = Join-Path $cache 'kenney.cookies'
  $page = "https://kenney.nl/$slug"
  curl.exe -s -c $jar -b $jar -A 'Mozilla/5.0' -o NUL $page
  $id = -join ([Text.Encoding]::ASCII.GetBytes($slug) | ForEach-Object { $_.ToString('x2') })
  $j = curl.exe -s -c $jar -b $jar -A 'Mozilla/5.0' -e $page "https://kenney.nl/download-link/$id" | ConvertFrom-Json
  if (-not $j.url) { throw "Kenney: link nao obtido para $slug" }
  Fetch $j.url $file
}

function Verify($item, [string]$file) {
  $h = Sha $file
  if (-not $item.sha256) {
    if (-not $Pin) { throw "sem sha256 fixado para $file (rode com -Pin apos revisar a licenca)" }
    $item | Add-Member -Force -NotePropertyName sha256 -NotePropertyValue $h
    $script:dirty = $true
    Write-Host "  fixado $h"
  } elseif ($h -ne $item.sha256) {
    Remove-Item $file -Force
    throw "SHA-256 divergente em $file (esperado $($item.sha256), obtido $h)"
  }
}

# 1) Python venv
$py = Join-Path $root '.tools/py/Scripts/python.exe'
if (-not (Test-Path $py) -or $Force) {
  Write-Host "> python -m venv .tools/py"
  python -m venv (Join-Path $root '.tools/py')
}
$want = ($cfg.python_packages.PSObject.Properties | ForEach-Object { "$($_.Name)==$($_.Value)" })
$have = & $py -m pip freeze 2>$null
$missing = $want | Where-Object { $have -notcontains $_ }
if ($missing) {
  Write-Host "> pip install $($want -join ' ')"
  & $py -m pip install -q --disable-pip-version-check @want
  if ($LASTEXITCODE) { throw 'pip falhou' }
}

# 2) FluidSynth
$fsDir = Join-Path $base 'fluidsynth'
if (-not (Get-ChildItem $fsDir -Recurse -Filter fluidsynth.exe -ErrorAction SilentlyContinue) -or $Force) {
  $zip = Join-Path $cache 'fluidsynth.zip'
  if (-not (Test-Path $zip)) { Fetch $cfg.fluidsynth.url $zip }
  Verify $cfg.fluidsynth $zip
  Expand-Archive $zip -DestinationPath $fsDir -Force
}

# 3) Voz Piper
$vDir = Join-Path $base 'voices'
New-Item -ItemType Directory -Force -Path $vDir | Out-Null
foreach ($f in $cfg.piper_voice.files) {
  $out = Join-Path $vDir $f.name
  if (-not (Test-Path $out) -or $Force) { Fetch $f.url $out }
  Verify $f $out
}

# 4) Amostras e SoundFonts CC0
foreach ($a in $assets.assets) {
  if ($a.license -notin @('CC0-1.0', 'PD')) { throw "$($a.id): licenca $($a.license) nao permitida (D3)" }
  $ext = if ($a.kenney) { '.zip' } else { [IO.Path]::GetExtension(([uri]$a.url).AbsolutePath) }
  if ($a.url -match '\.tar\.xz$') { $ext = '.tar.xz' }
  $file = Join-Path $cache "$($a.id)$ext"
  $dest = Join-Path $src $a.id
  if (-not (Test-Path $file) -or $Force) {
    if ($a.kenney) { Get-Kenney $a.kenney $file } else { Fetch $a.url $file }
  }
  Verify $a $file
  if (-not (Test-Path $dest) -or $Force) {
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    if ($ext -in @('.zip', '.7z', '.tar.xz')) { tar -xf $file -C $dest; if ($LASTEXITCODE) { throw "extracao falhou: $file" } }
    else { Copy-Item $file (Join-Path $dest ([uri]::UnescapeDataString([IO.Path]::GetFileName(([uri]$a.url).AbsolutePath)))) }
  }
}

if ($dirty) {
  # toolchain.json nao e reescrito (preserva godot/blender): copie os hashes impressos acima para a chave "audio".
  $assets | ConvertTo-Json -Depth 8 | Set-Content $assetsPath -Encoding utf8
  Write-Host 'Hashes gravados em tools/toolchain.json e tools/audio_assets.json'
}
$pip = & $py -m pip freeze
Write-Host "OK: venv ($($pip.Count) pacotes), FluidSynth, voz $($cfg.piper_voice.name), $($assets.assets.Count) itens CC0 em .tools/audio/src"
