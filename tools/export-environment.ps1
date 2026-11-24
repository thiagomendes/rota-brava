#requires -Version 7
# Regenera os .blend do ambiente (RB-04-env) a partir dos scripts em source_art/environment (Blender headless),
# exporta GLB (metros, +Y up, materiais mat_env_*, cor por vertice) em game/assets/models/environment/ e escreve
# source_art/manifest_environment.json. Uso: ./tools/export-environment.ps1 [-Images]
#   -Scenes  reimporta e regenera as cenas .tscn.`n#   -Images  tambem gera renders de conferencia (sombreado e malha) em captures/rb-04/env (fora do Git).
param([switch]$Images, [switch]$Scenes)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root
$env:PYTHONDONTWRITEBYTECODE = '1'
$tc = Get-Content (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json
$bver = $tc.blender.version
$glbDir = 'game/assets/models/environment'

function Invoke-Blender([string[]]$pre, [string]$script, [string[]]$extra) {
    $a = @('--background') + $pre + @('--python', $script, '--') + $extra
    Write-Host ("COMANDO: ./tools/blender.ps1 " + ($a -join ' '))
    $out = & "$PSScriptRoot/blender.ps1" @a 2>&1
    $out | Where-Object { $_ -match '(ENV_INFO|RENDER_OK|Error|Traceback)' } | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0 -or ($out | Where-Object { $_ -match '(Traceback|^\w*Error:)' })) { throw "Blender falhou em $script" }
}

$sets = @(
    @{ id = 'dock_kit'; script = 'source_art/environment/build_dock.py'; blend = 'source_art/environment/dock_kit.blend';
       note = 'Kit modular do cais: deck de tabuas (2 e 4 m), poste com anel de corda, cabeco, defensa de pneu, escada, borda, estaca.' },
    @{ id = 'props'; script = 'source_art/environment/build_props.py'; blend = 'source_art/environment/props.blend';
       note = 'Adercos: caixotes (L, S, com pessegos), barril, rolo de corda, lampiao, rede, placa, balde, remo, boia de cortica, cabana, pegada de bota.' },
    @{ id = 'nature'; script = 'source_art/environment/build_nature.py'; blend = 'source_art/environment/nature.blend';
       note = 'Ladrilhos de chao 4x13 m, 3 arvores, 2 arbustos, grama, juncos, 3 rochas.' },
    @{ id = 'boat_v2'; script = 'source_art/environment/build_boat_v2.py'; blend = 'source_art/environment/boat_v2.blend';
       note = 'Barco v2 (evolucao do RB-03): cabine na popa, banco com PawMark, volante, motor, bandeirola, lampiao, corda. Pivo a 40% da popa.' },
    @{ id = 'village_kit'; script = 'source_art/environment/build_village.py'; blend = 'source_art/environment/village_kit.blend';
       note = 'RB-R1 kit da vila Farol 7 (style-bible): 4 casas parametricas, barracas, poste, banco, canteiro, tufo, cerca, escada, muro, cais de pedra, praca, gramado, arrimo, FAROL, morros, nuvem, gaivota, arvores, barquinho, bandeirolas.' },
    @{ id = 'world_kit'; script = 'source_art/environment/build_world.py'; blend = 'source_art/environment/world_kit.blend';
       note = 'RB-R1 mundo do Ep01: margens do rio, ilha, banco de areia, promontorio do farol, agua distante, ponte em arco, cerca rustica, palmeira, barraca, fogueira, bandeira, rochas da travessia (seguras/iscas), rochedo, concha, pier pequeno, gaivota pousada.' }
)
$harborComp = 'B'   # composicao recomendada (RB-R1, ver game/episodes/ep01/world/LAYOUT_PROPOSTO.md)
$common = @('source_art/environment/envlib.py', 'source_art/scripts/rbart.py')
$entries = @()
foreach ($s in $sets) {
    Invoke-Blender @('--factory-startup') $s.script @('--blend', $s.blend, '--glb-dir', $glbDir)
    $info = Get-Content ([IO.Path]::ChangeExtension($s.blend, '.info.json')) -Raw | ConvertFrom-Json
    foreach ($p in $info.PSObject.Properties) {
        $v = $p.Value
        $entries += [ordered]@{
            id = $p.Name; conjunto = $s.id; agente = 'art3d'
            processo = [ordered]@{ script = $s.script; ferramenta = "Blender $bver (tools/blender.ps1, headless)"; exportador = 'glTF 2.0 binario (GLB), +Y up, metros, modificadores aplicados, cor por vertice' }
            origem = @($s.script) + $common + @($s.blend)
            saida_glb = $v.glb
            glb_sha256 = (Get-FileHash $v.glb -Algorithm SHA256).Hash.ToLower()
            triangulos = $v.tris
            vertices = $v.vertices
            materiais = $v.materials
            tamanho_m = $v.size
            objetos = $v.objects
            empties = $v.empties
            status = 'provisorio'
            aprovacao = 'pendente (Thiago)'
            originalidade = 'geometria procedural propria (bmesh, Bevel, Subdivision); nenhum modelo, malha, textura ou kit de terceiros'
            data = (Get-Date -Format 'yyyy-MM-dd')
            nota = $s.note
        }
    }
}
# layout do trecho do porto (fonte unica em Python) -> JSON lido por game/episodes/ep01/world/gen_harbor_slice.gd
Invoke-Blender @('--factory-startup') 'source_art/environment/village_layout.py' @('--json', $harborComp, 'game/episodes/ep01/world/harbor_layout.json')
Invoke-Blender @('--factory-startup') 'source_art/environment/world_layout.py' @('--out', 'game/episodes/ep01/world')
$manifest = [ordered]@{ projeto = 'Rota Brava'; ticket = 'RB-04-env + RB-R1-mundo'; agente = 'art3d'; ativos = $entries }
$manifest | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $root 'source_art/manifest_environment.json') -Encoding utf8
$tot = 0; foreach ($e in $entries) { $tot += [int]$e.triangulos }
Write-Host ("manifest: source_art/manifest_environment.json ({0} ativos, {1} triangulos)" -f $entries.Count, $tot)

if ($Images) {
    $o = (Join-Path $root 'captures/rb-04/env').Replace('\', '/')
    $pr = @('Crate_L,Crate_S,Crate_Peach,Barrel,Rope_Coil,Bucket,Oar,Cork_Buoy,Boot_Print', 'Lantern_Post,Fishing_Net,Sign_Board,Boat_Hut')
    Invoke-Blender @('source_art/environment/props.blend') 'source_art/environment/render_env.py' @('--out', "$o/props1", '--view', '200,16', '--size', '2000x600', '--only', $pr[0])
    Invoke-Blender @('source_art/environment/props.blend') 'source_art/environment/render_env.py' @('--out', "$o/props2", '--view', '200,16', '--size', '2000x600', '--only', $pr[1])
    Invoke-Blender @('source_art/environment/nature.blend') 'source_art/environment/render_env.py' @('--out', "$o/nature", '--view', '200,16', '--size', '2000x600', '--only', 'Tree_A,Tree_B,Tree_C,Bush_Round,Bush_Flower,Grass_Tuft,Reeds,Rock_A,Rock_B,Rock_C,Ground_Tile_Path')
    Invoke-Blender @('source_art/environment/dock_kit.blend') 'source_art/environment/render_env.py' @('--out', "$o/dock_kit", '--view', '200,25', '--size', '2000x700', '--only', 'Dock_Deck_2m,Dock_Post,Dock_Cleat,Dock_Fender,Dock_Ladder,Dock_Edge,Dock_Pile')
    Invoke-Blender @('source_art/environment/boat_v2.blend') 'source_art/environment/render_env.py' @('--out', "$o/boat_game", '--view', '-90,38', '--size', '1400x800')
    Invoke-Blender @('source_art/environment/boat_v2.blend') 'source_art/environment/render_env.py' @('--out', "$o/boat_34", '--view', '-135,25', '--size', '1400x800')
}
if ($Scenes) {
    # reimporta os GLB e regenera as cenas proprias (game/actors/environment/*.tscn)
    Write-Host 'COMANDO: ./tools/godot.ps1 --headless --path game --import'
    & "$PSScriptRoot/godot.ps1" --headless --path game --import | Out-Null
    # liga o script de pos-importacao (cor por vertice -> albedo) em cada GLB do ambiente e reimporta
    $changed = $false
    foreach ($f in Get-ChildItem (Join-Path $root $glbDir) -Filter '*.glb.import') {
        $txt = Get-Content $f.FullName -Raw
        if ($txt -match 'import_script/path=""') {
            ($txt -replace 'import_script/path=""', 'import_script/path="res://assets/models/environment/vertex_color_postimport.gd"') | Set-Content $f.FullName -NoNewline
            $changed = $true
        }
        # terrenos: sem LOD automatico (a simplificacao some com a lingua de terra do pouso e as bordas do caminho)
        if ($f.Name -match '^(river_bank_|island_ground|sandbar|headland|bank_path|ground_tile_|far_water)') {
            $txt = Get-Content $f.FullName -Raw
            if ($txt -match 'meshes/generate_lods=true') {
                ($txt -replace 'meshes/generate_lods=true', 'meshes/generate_lods=false') | Set-Content $f.FullName -NoNewline
                $changed = $true
            }
        }
    }
    if ($changed) { & "$PSScriptRoot/godot.ps1" --headless --path game --import | Out-Null }
    Write-Host 'COMANDO: ./tools/godot.ps1 --headless --path game --script res://actors/environment/gen_env_scenes.gd'
    & "$PSScriptRoot/godot.ps1" --headless --path game --script res://actors/environment/gen_env_scenes.gd | Select-Object -Last 2 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) { throw 'gen_env_scenes falhou' }
    Write-Host 'COMANDO: ./tools/godot.ps1 --headless --path game --script res://episodes/ep01/world/gen_harbor_slice.gd'
    & "$PSScriptRoot/godot.ps1" --headless --path game --script res://episodes/ep01/world/gen_harbor_slice.gd | Select-Object -Last 3 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) { throw 'gen_harbor_slice falhou' }
    Write-Host 'COMANDO: ./tools/godot.ps1 --headless --path game --script res://episodes/ep01/world/gen_world_scenes.gd'
    & "$PSScriptRoot/godot.ps1" --headless --path game --script res://episodes/ep01/world/gen_world_scenes.gd | Select-Object -Last 4 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) { throw 'gen_world_scenes falhou' }
}
Write-Host 'OK export-environment'
