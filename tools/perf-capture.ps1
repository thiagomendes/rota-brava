#requires -Version 7
<#
  Mede tempos de quadro da chegada e do cais na build exportada (renderizacao real, 1080p), em 3 passagens
  com aquecimento. Saida: logs/perf-report.json e logs/perf-report.md. Registra GPU, RAM, SO, renderizador e build.
  Nao mede aparelho movel. Rode com a sessao de desktop desbloqueada.
  Uso: ./tools/perf-capture.ps1 [-Passes 3] [-Warmup 4] [-Seconds 15] [-Resolution 1920x1080] [-VsyncOff]
#>
[CmdletBinding()]
param([int]$Passes = 3, [int]$Warmup = 4, [int]$Seconds = 15, [string]$Resolution = '1920x1080', [switch]$VsyncOff)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$exe = Join-Path $root 'build/windows/RotaBrava.console.exe'
if (-not (Test-Path $exe)) { throw 'Build ausente. Rode ./tools/build-windows.ps1' }
$logs = Join-Path $root 'logs'; New-Item -ItemType Directory -Force -Path $logs | Out-Null
$w, $h = $Resolution.Split('x')

$results = @()
for ($i = 1; $i -le $Passes; $i++) {
    $cli = @('--resolution', $Resolution, '--windowed', '--ep01-demo', '--perf-probe', "--perf-warmup=$Warmup", "--perf-seconds=$Seconds")
    if ($VsyncOff) { $cli += '--disable-vsync' }
    Write-Host "> passagem $i : $exe $($cli -join ' ')"
    $out = & $exe @cli 2>&1
    $line = $out | Select-String '\[RB\] perf (\{.*\})' | Select-Object -Last 1
    if (-not $line) { throw "Passagem $i sem resultado de desempenho. Saida:`n$($out | Select-Object -Last 15 | Out-String)" }
    $results += ($line.Matches[0].Groups[1].Value | ConvertFrom-Json)
}

$gpu = (Get-CimInstance Win32_VideoController | Where-Object Name -match 'NVIDIA|AMD|Radeon' | Select-Object -First 1)
$ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
$commit = (git -C $root rev-parse --short HEAD)
$meta = [ordered]@{
    commit = $commit; gpu = $gpu.Name; gpu_driver = $gpu.DriverVersion; ram_gb = $ram
    os = [System.Environment]::OSVersion.VersionString; renderer = $results[0].renderer; engine = $results[0].engine
    adapter = $results[0].adapter; resolution = $Resolution; vsync_off = [bool]$VsyncOff; warmup_s = $Warmup; sample_s = $Seconds
    date = (Get-Date -Format 'yyyy-MM-dd HH:mm')
}
$report = [ordered]@{ meta = $meta; passes = $results }
$report | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $logs 'perf-report.json') -Encoding utf8

$md = @("# Desempenho · chegada e cais · build $commit", '', "GPU $($gpu.Name) · RAM $ram GB · $($meta.os) · $($meta.renderer) · $Resolution · vsync desligado: $([bool]$VsyncOff)", '',
    '| Passagem | quadros | media ms | p50 | p95 | p99 | max | GPU p95 ms | draw calls (media) | objetos | VRAM MB |', '|---|---|---|---|---|---|---|---|---|---|---|')
$n = 0
foreach ($r in $results) {
    $n++
    $md += "| $n | $($r.frames) | $($r.frame_ms.mean) | $($r.frame_ms.p50) | $($r.frame_ms.p95) | $($r.frame_ms.p99) | $($r.frame_ms.max) | $($r.gpu_ms.p95) | $($r.draw_calls.mean) | $($r.objects_in_frame) | $($r.video_mem_mb) |"
}
$md += ''; $md += 'Meta inicial: 16,7 ms/quadro em 1080p (SPEC secao 9). Medicao em desktop; nao vale para celular.'
$md | Set-Content (Join-Path $logs 'perf-report.md') -Encoding utf8
$md | ForEach-Object { Write-Host $_ }
