#requires -Version 7
# Sintetiza os takes brutos (SAPI, vozes PROVISORIAS) em source_audio/takes/<arquivo>.wav (22,05 kHz mono 16 bits).
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot; $root = Split-Path $here -Parent
$cfg = Get-Content (Join-Path $here 'lines.json') -Raw -Encoding utf8 | ConvertFrom-Json
$text = @{}
foreach ($f in Get-ChildItem (Join-Path $root 'game/i18n') -Filter 'pt_BR*.json') {
  $o = Get-Content $f.FullName -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
  foreach ($k in $o.Keys) { $text[$k] = $o[$k] }
}
Add-Type -AssemblyName System.Speech
$s = New-Object System.Speech.Synthesis.SpeechSynthesizer
$installed = $s.GetInstalledVoices() | ForEach-Object { $_.VoiceInfo.Name }
Write-Host "Vozes instaladas: $($installed -join ', ')"
$fmt = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(22050, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono)
New-Item -ItemType Directory -Force (Join-Path $here 'takes') | Out-Null
foreach ($l in $cfg.lines) {
  $v = $cfg.voices.($l.voice)
  if ($installed -notcontains $v.sapi) { throw "Voz ausente: $($v.sapi)" }
  $pitch = if ($l.pitch) { $l.pitch } else { $v.pitch }
  $rate = if ($l.rate) { $l.rate } else { $v.rate }
  $t = [System.Security.SecurityElement]::Escape($text[$l.key])
  $ssml = "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='pt-BR'><prosody pitch='$pitch' rate='$rate'>$t</prosody></speak>"
  $out = Join-Path $here "takes/$($l.file).wav"
  $s.SelectVoice($v.sapi)
  $s.SetOutputToWaveFile($out, $fmt)
  $s.SpeakSsml($ssml)
  $s.SetOutputToNull()
  Write-Host "take: $($l.id) <- $($v.sapi) pitch=$pitch rate=$rate"
}
$s.Dispose()
