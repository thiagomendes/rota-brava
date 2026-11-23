#requires -Version 7
# Regenera TODO o audio de referencia: takes SAPI (provisorios) -> pos-processamento -> musica. Idempotente.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
  Write-Host "> ./source_audio/synth_voices.ps1"
  & ./source_audio/synth_voices.ps1
  Write-Host "> python source_audio/voice_post.py"
  python source_audio/voice_post.py; if ($LASTEXITCODE) { throw "voice_post falhou" }
  Write-Host "> python source_audio/music/theme_sketch.py"
  python source_audio/music/theme_sketch.py; if ($LASTEXITCODE) { throw "theme_sketch falhou" }
  Write-Host "Pronto. Depois: ./tools/godot.ps1 --headless --path game --import"
} finally { Pop-Location }
