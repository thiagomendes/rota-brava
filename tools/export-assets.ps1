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
    & "$PSScriptRoot/blender.ps1" @a | Where-Object { $_ -match '^(CHAR_INFO|BOAT_INFO|Error|Traceback)' } | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) { throw "Blender falhou em $script" }
}

$assets = @(
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

# ---- personagens organicos (RB-04-chars): malha SKIN+SUBSURF, rig, pesos, shape keys e animacoes -> um GLB por personagem
$chars = @(
    @{ id = 'leme';    name = 'Leme';    role = 'pilot';   note = 'Piloto: gorro de marinheiro, lenco, colete claro com bolsos, maos grandes. Clipes de volante (idle_wheel, steer_left/right, react_horn) + idle/walk.' },
    @{ id = 'pico';    name = 'Pico';    role = 'climber'; note = 'Especialista em travessias: capacete leve, corda enrolada nas costas e a tiracolo, mosquetoes no cinto/mochila/peito, luvas sem dedos, jaqueta verde. Clipes idle, walk, react_surprise, pull_rope (dois puxoes, 1,6 s) e look_up.' },
    @{ id = 'extra_a'; name = 'Figurante A'; role = 'extra'; note = 'Figurante do cais com chapeu de palha. Malha simples, rig completo, clipes idle e walk.' },
    @{ id = 'extra_b'; name = 'Figurante B'; role = 'extra'; note = 'Figurante do cais com lenco na cabeca e tunica. Malha simples, rig completo, clipes idle e walk.' },
    @{ id = 'extra_c'; name = 'Figurante C'; role = 'extra'; note = 'Figurante do cais com boina. Malha simples, rig completo, clipes idle e walk.' }
)
$charSrc = @('source_art/scripts/char_build.py', 'source_art/scripts/char_lib.py', 'source_art/scripts/char_face.py', 'source_art/scripts/char_anim.py', 'source_art/scripts/rbart.py')
foreach ($c in $chars) {
    $blend = "source_art/characters/rb04/$($c.id)/$($c.id).blend"
    $glb = "game/assets/models/characters/$($c.id).glb"
    Invoke-Blender 'source_art/scripts/char_build.py' @('--id', $c.id, '--blend', $blend, '--glb', $glb)
    $info = Get-Content ([IO.Path]::ChangeExtension($blend, '.info.json')) -Raw | ConvertFrom-Json
    $anims = [ordered]@{}
    foreach ($p in $info.animations.PSObject.Properties | Sort-Object Name) { $anims[$p.Name] = [math]::Round(($p.Value[1] - $p.Value[0]) / 30.0, 3) }
    $entries += [ordered]@{
        id = $c.id; nome = $c.name; papel = $c.role; agente = 'art3d'
        processo = [ordered]@{ script = 'source_art/scripts/char_build.py'; ferramenta = "Blender $bver (tools/blender.ps1, headless)"; exportador = 'glTF 2.0 binario (GLB), +Y up, metros, skin, shape keys, animacoes por NLA'; tecnicas = 'modificador SKIN + SUBSURF, bmesh, pesos por distancia ao osso, cinematica FK/IK em Python' }
        origem = $charSrc + @($blend)
        saida_glb = $glb
        glb_sha256 = (Get-FileHash $glb -Algorithm SHA256).Hash.ToLower()
        triangulos = $info.tris
        materiais = $info.materials
        objetos = $info.objects
        ossos = $info.bones
        quantidade_ossos = $info.bone_count
        animacoes_duracao_s = $anims
        shape_keys = $info.shape_keys
        altura_m = $info.height_m
        status = 'provisorio'
        aprovacao = 'pendente (Thiago)'
        originalidade = 'geometria procedural propria (primitivas bmesh, SKIN, SUBSURF); rig e animacoes autorais por script; nenhum modelo, malha, rig, mocap, textura ou personagem-base de terceiros'
        data = (Get-Date -Format 'yyyy-MM-dd')
        nota = $c.note
    }
}
# ---- herois do RB-R1 (criancas-herois, refeitos do zero): Rastro na variacao recomendada; Pico e Leme seguem do RB-04 ate o Portao 1
$heroSrc = @('source_art/scripts/hero_build.py', 'source_art/scripts/hero_lib.py', 'source_art/scripts/hero_face.py', 'source_art/scripts/hero_anim.py', 'source_art/scripts/char_lib.py', 'source_art/scripts/char_anim.py', 'source_art/scripts/rbart.py')
$heroes = @(
    @{ id = 'rastro'; name = 'Rastro'; role = 'tracker'; note = 'RB-R1: crianca-heroi (8 anos), variacao A "brinquedo brilhante": cabeca ~37% da altura, olhos grandes com iris, pupila e dois brilhos, maos de 4 dedos, botas grandes com sola creme; jaqueta de equipe laranja #FF8A1F com gola creme, emblema da Rota Brava em relevo no peito esquerdo, cinto com fivela-bussola, chapeu de aba larga com faixa e rosa dos ventos, rabos de cavalo, bolsa com caderno, lupa. Rig 28 ossos + ponteiras (RB-04), expressoes, visemas, olhar, 12 clipes.' }
)
foreach ($c in $heroes) {
    $blend = "source_art/characters/heroes/$($c.id)/$($c.id).blend"
    $glb = "game/assets/models/characters/$($c.id).glb"
    Invoke-Blender 'source_art/scripts/hero_build.py' @('--id', $c.id, '--blend', $blend, '--glb', $glb)
    $info = Get-Content ([IO.Path]::ChangeExtension($blend, '.info.json')) -Raw | ConvertFrom-Json
    $anims = [ordered]@{}
    foreach ($p in $info.animations.PSObject.Properties | Sort-Object Name) { $anims[$p.Name] = [math]::Round(($p.Value[1] - $p.Value[0]) / 30.0, 3) }
    $entries += [ordered]@{
        id = $c.id; nome = $c.name; papel = $c.role; agente = 'art3d'
        processo = [ordered]@{ script = 'source_art/scripts/hero_build.py'; ferramenta = "Blender $bver (tools/blender.ps1, headless)"; exportador = 'glTF 2.0 binario (GLB), +Y up, metros, skin, shape keys, animacoes por NLA'; tecnicas = 'modificador SKIN + SUBSURF, metaballs (cabelo), torno (chapeu), bmesh; pesos por distancia normalizada pela espessura de cada parte; cinematica FK/IK em Python' }
        origem = $heroSrc + @($blend)
        saida_glb = $glb
        glb_sha256 = (Get-FileHash $glb -Algorithm SHA256).Hash.ToLower()
        triangulos = $info.tris
        materiais = $info.materials
        objetos = $info.objects
        ossos = $info.bones
        quantidade_ossos = $info.bone_count
        animacoes_duracao_s = $anims
        shape_keys = $info.shape_keys
        altura_m = $info.height_m
        razao_cabeca_altura = $info.head_ratio
        velocidade_walk_mps = $info.walk_speed_mps
        velocidade_run_mps = $info.run_speed_mps
        variacao = $info.variant
        status = 'provisorio'
        aprovacao = 'pendente (Thiago, Portao 1 do RB-R1)'
        originalidade = 'geometria procedural propria (primitivas bmesh, SKIN, SUBSURF, metaballs, torno); rig e animacoes autorais por script; nenhum modelo, malha, rig, mocap, textura ou personagem-base de terceiros; nada copiado de series de TV'
        data = (Get-Date -Format 'yyyy-MM-dd')
        nota = $c.note
    }
}
$manifest = [ordered]@{ projeto = 'Rota Brava'; ticket = 'RB-03-art + RB-04-chars + RB-R1-herois'; ativos = $entries }
$manifest | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $root 'source_art/manifest.json') -Encoding utf8
Write-Host 'manifest: source_art/manifest.json atualizado'

if ($Images) {
    $out = 'captures/rb-03/art'
    Invoke-Blender 'source_art/scripts/cast_silhouettes.py' @('--out', $out)
    foreach ($c in $chars) {
        Invoke-Blender 'source_art/scripts/char_render.py' @('--id', $c.id, '--mode', 'views', '--out', 'captures/rb-04/chars')
        Invoke-Blender 'source_art/scripts/char_render.py' @('--id', $c.id, '--mode', 'expr', '--out', 'captures/rb-04/chars')
        Invoke-Blender 'source_art/scripts/char_render.py' @('--id', $c.id, '--mode', 'mesh', '--rest', '--out', 'captures/rb-04/chars')
        Invoke-Blender 'source_art/scripts/char_render.py' @('--id', $c.id, '--mode', 'extremes', '--out', 'captures/rb-04/chars')
    }
    Invoke-Blender 'source_art/scripts/render_views.py' @('--asset', 'boat', '--out', $out)
}
Write-Host 'OK export-assets'







