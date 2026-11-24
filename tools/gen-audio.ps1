#requires -Version 7
# Regenera TODO o audio de Rota Brava (RB-04): ambiente, efeitos, takes SAPI (provisorios) -> pos-processamento,
# musica, catalogos e evidencias medidas. Idempotente (sintese deterministica por semente). Imprime cada comando.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
  function Step([string]$label, [scriptblock]$cmd) {
    Write-Host "> $label"
    & $cmd | Out-Host
    if ($LASTEXITCODE) { throw "$label falhou ($LASTEXITCODE)" }
  }
  $env:PYTHONDONTWRITEBYTECODE = '1'
  $os = [System.Environment]::OSVersion.VersionString
  $pyv = (python --version) 2>&1
  @{ os = $os; python = "$pyv"; tool_sapi = 'System.Speech (SAPI) Windows'; note = 'registrado por tools/gen-audio.ps1' } | ConvertTo-Json | Set-Content source_audio/env.json -Encoding utf8
  Write-Host "> OS: $os | $pyv"
  Write-Host "> ./source_audio/synth_voices.ps1"
  & ./source_audio/synth_voices.ps1
  if (Test-Path source_audio/report.json) { Remove-Item source_audio/report.json }
  Step 'python source_audio/voice_post.py' { python source_audio/voice_post.py }
  Step 'python source_audio/ambience.py' { python source_audio/ambience.py }
  Step 'python source_audio/sfx.py' { python source_audio/sfx.py }
  Step 'python source_audio/music/themes.py' { python source_audio/music/themes.py }
  Step 'python source_audio/build_catalogs.py' { python source_audio/build_catalogs.py }
  Step 'python source_audio/evidence.py' { python source_audio/evidence.py }
  Write-Host "Pronto. Depois: ./tools/godot.ps1 --headless --path game --import"
} finally { Pop-Location }
