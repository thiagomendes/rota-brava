#requires -Version 7
# Capturas do mundo do Ep01 (RB-R1, art3d): Movie Maker da Godot em preview_world.tscn -> captures/rb-r1/mundo/<vista>.png
# e PERF por vista em captures/rb-r1/mundo/perf_world.txt. Uso: ./source_art/studies/world/capture-world.ps1
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$out = Join-Path $root 'captures/rb-r1/mundo'
$mov = Join-Path $out 'movie_world'
New-Item -ItemType Directory -Force $mov | Out-Null
Get-ChildItem $mov -File | Remove-Item
$log = & "$root/tools/godot.ps1" --path (Join-Path $root 'game') res://episodes/ep01/world/preview_world.tscn --write-movie (Join-Path $mov 'f.png') --fixed-fps 10 --resolution 1280x720 --quit-after 36 2>&1
$perf = $log | Where-Object { "$_" -match '^PERF ' }
$perf | Set-Content (Join-Path $out 'perf_world.txt')
foreach ($l in $perf) {
    if ("$l" -match '^PERF (\S+) frame=(\d+)') {
        $src = Join-Path $mov ('f{0:D8}.png' -f [int]$Matches[2])
        Copy-Item $src (Join-Path $out ($Matches[1] + '.png')) -Force
    }
    Write-Host $l
}
