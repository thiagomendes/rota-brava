#requires -Version 7
# Regenera os .blend a partir dos scripts (Blender headless), exporta GLB (metros, +Y up, materiais, shape keys)
# e atualiza source_art/manifest.json. Uso: ./tools/export-assets.ps1 [-Images]
#   -Images  tambem regenera pranchas/vistas/malhas em captures/rb-03/art (fora do Git).
param([switch]$Images)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root
$env:PYTHONDONTWRITEBYTECODE = '1'
$tc = Get-Content (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json
$bver = $tc.blender.version

function Invoke-Blender([string]$script, [string[]]$extra) {
    $a = @('--background', '--factory-startup', '--python', $script, '--') + $extra
    Write-Host ("COMANDO: ./tools/blender.ps1 " + ($a -join ' '))
    & "$PSScriptRoot/blender.ps1" @a | Where-Object { $_ -match '^(RASTRO_INFO|BOAT_INFO|Error|Traceback)' } | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) { throw "Blender falhou em $script" }
}

$assets = @(
    @{ id = 'rastro'; name = 'Rastro'; script = 'source_art/scripts/build_rastro.py'; blend = 'source_art/characters/rastro/rastro.blend';
       glb = 'game/assets/models/rastro.glb'; extra = @('source_art/scripts/rbart.py', 'source_art/scripts/rbchars.py', 'source_art/params/rastro.json');
       note = 'Corpo-base provisorio da rastreadora (candidata A: chapeu de aba larga, caderno lateral, postura curvada). Sem rig/animacao (RB-04). 3 expressoes como shape keys em Rastro_Face. Recomendacao da candidata A: a aba larga e o torso curvado leem melhor em 48 px e se distinguem de Pico (arco/corda) e Leme (bracos abertos) - gosto e decisao de Thiago.' },
    @{ id = 'boat'; name = 'Barco'; script = 'source_art/scripts/build_boat.py'; blend = 'source_art/vehicles/boat/boat.blend';
       glb = 'game/assets/models/boat.glb'; extra = @('source_art/scripts/rbart.py');
       note = 'Barco amarelo provisorio. Pivo = centro de giro: eixo longitudinal, 40% do comprimento a partir da popa. Proa em -Z na Godot. Empties DeckPoint e BenchMark.' }
)

$entries = @()
foreach ($a in $assets) {
    Invoke-Blender $a.script @('--blend', $a.blend, '--glb', $a.glb)
    $info = Get-Content ([IO.Path]::ChangeExtension($a.blend, '.info.json')) -Raw | ConvertFrom-Json
    $entries += [ordered]@{
        id = $a.id; nome = $a.name; agente = 'art3d'
        processo = [ordered]@{ script = $a.script; ferramenta = "Blender $bver (tools/blender.ps1, headless)"; exportador = 'glTF 2.0 binario (GLB), +Y up, metros, shape keys' }
        origem = @($a.script) + $a.extra + @($a.blend)
        saida_glb = $a.glb
        glb_sha256 = (Get-FileHash $a.glb -Algorithm SHA256).Hash.ToLower()
        triangulos = $info.tris
        materiais = $info.materials
        objetos = $info.objects
        status = 'provisorio'
        aprovacao = 'pendente (Thiago)'
        originalidade = 'geometria procedural propria; nenhum modelo, malha, textura ou kit de terceiros'
        data = (Get-Date -Format 'yyyy-MM-dd')
        nota = $a.note
    }
}
$manifest = [ordered]@{ projeto = 'Rota Brava'; ticket = 'RB-03-art'; ativos = $entries }
$manifest | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $root 'source_art/manifest.json') -Encoding utf8
Write-Host 'manifest: source_art/manifest.json atualizado'

if ($Images) {
    $out = 'captures/rb-03/art'
    Invoke-Blender 'source_art/scripts/cast_silhouettes.py' @('--out', $out)
    Invoke-Blender 'source_art/scripts/render_views.py' @('--asset', 'rastro', '--out', $out)
    Invoke-Blender 'source_art/scripts/render_views.py' @('--asset', 'boat', '--out', $out)
}
Write-Host 'OK export-assets'



