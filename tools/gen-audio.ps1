#requires -Version 7
# Regenera TODO o audio de Rota Brava (RB-R1): balbucio, radio Piper, musica (FluidSynth + SoundFonts CC0),
# efeitos/ambiente (foley CC0 + sintese original), catalogos, procedencia, mixagem de referencia e relatorio.
# Pre-requisito: ./tools/setup-audio-tools.ps1 (ferramentas em .tools/, hashes conferidos). Deterministico por semente.
# Depois: ./tools/godot.ps1 --headless --path game --import
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
  $py = Join-Path $root '.tools/py/Scripts/python.exe'
  if (-not (Test-Path $py)) { throw 'venv ausente: rode ./tools/setup-audio-tools.ps1' }
  function Step([string]$label, [scriptblock]$cmd) {
    Write-Host "> $label"
    & $cmd | Out-Host
    if ($LASTEXITCODE) { throw "$label falhou ($LASTEXITCODE)" }
  }
  $env:PYTHONDONTWRITEBYTECODE = '1'
  $env:PYTHONIOENCODING = 'utf-8'
  $tc = (Get-Content tools/toolchain.json -Raw | ConvertFrom-Json).audio
  $fs = Get-ChildItem .tools/audio/fluidsynth -Recurse -Filter fluidsynth.exe | Select-Object -First 1
  [ordered]@{
    os = [System.Environment]::OSVersion.VersionString
    python = "$(& $py --version 2>&1)"
    packages = @(& $py -m pip freeze)
    fluidsynth = "$(& $fs.FullName --version 2>&1 | Select-Object -First 1)"
    piper_voice = $tc.piper_voice.name
    note = 'registrado por tools/gen-audio.ps1'
  } | ConvertTo-Json | Set-Content source_audio/env.json -Encoding utf8
  Step 'python source_audio/babble/babble.py' { & $py source_audio/babble/babble.py }
  Step 'python source_audio/radio/radio.py' { & $py source_audio/radio/radio.py }
  Step 'python source_audio/music/compose.py' { & $py source_audio/music/compose.py }
  Step 'python source_audio/foley/build_sfx.py' { & $py source_audio/foley/build_sfx.py }
  Step 'python source_audio/r1/build_catalogs.py' { & $py source_audio/r1/build_catalogs.py }
  Step 'python source_audio/r1/fix_imports.py' { & $py source_audio/r1/fix_imports.py }
  Write-Host "Pronto. Depois: ./tools/godot.ps1 --headless --path game --import"
} finally { Pop-Location }
