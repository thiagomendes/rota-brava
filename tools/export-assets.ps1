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
$chars = @()   # RB-R1: elenco antigo do RB-04 substituido pelos herois/moradores abaixo
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
$heroSrc = @('source_art/scripts/hero_build.py', 'source_art/scripts/pup_build.py', 'source_art/scripts/hero_lib.py', 'source_art/scripts/hero_face.py', 'source_art/scripts/hero_anim.py', 'source_art/scripts/char_lib.py', 'source_art/scripts/char_anim.py', 'source_art/scripts/rbart.py')
$heroes = @(
    @{ id = 'pico'; name = 'Pico'; role = 'climber'; script = 'hero_build'; note = 'RB-R1 direcao A: crianca-heroi (7 anos), verde #3DBE5A, capacete com lanterna, rolo de corda nas costas com alca que nao tapa o emblema, mosquetoes, luvas. 11 clipes (inclui jump e pull_rope).' },
    @{ id = 'leme'; name = 'Leme'; role = 'pilot'; script = 'hero_build'; note = 'RB-R1 direcao A: crianca-heroi (9 anos), azul #2F8CFF, bone nautico, colete salva-vidas com faixas refletivas, bolsos e gola, bussola de pulso. 12 clipes (inclui idle_wheel/steer/react_horn).' },
    @{ id = 'captain'; name = 'Piloto resgatado'; role = 'captain'; script = 'hero_build'; note = 'RB-R1: adulto simpatico com quepe de capitao, bigode e barba, jaqueta com botoes dourados. Clipes idle, walk, wave, thanks.' },
    @{ id = 'villager_a'; name = 'Moradora'; role = 'villager'; script = 'hero_build'; note = 'RB-R1: moradora adulta, menta/limao. Clipes idle, walk, wave, chat.' },
    @{ id = 'villager_b'; name = 'Morador idoso'; role = 'villager'; script = 'hero_build'; note = 'RB-R1: morador idoso de barba, pessego/creme. Clipes idle, walk, wave, chat.' },
    @{ id = 'villager_c'; name = 'Crianca da vila'; role = 'villager'; script = 'hero_build'; note = 'RB-R1: crianca da vila, rosa/ceu. Clipes idle, walk, wave, chat.' },
    @{ id = 'pup'; name = 'Filhote'; role = 'pup'; script = 'pup_build'; note = 'RB-R1: filhote original (caramelo, focinho e mancha creme, orelhas caidas, coleira turquesa com pingente-emblema). Rig proprio de 22 ossos. Clipes idle, wag, jump_happy, bark, step_on_horn.' },
    @{ id = 'rastro'; name = 'Rastro'; role = 'tracker'; script = 'hero_build'; note = 'RB-R1: crianca-heroi (8 anos), variacao A "brinquedo brilhante": cabeca ~37% da altura, olhos grandes com iris, pupila e dois brilhos, maos de 4 dedos, botas grandes com sola creme; jaqueta de equipe laranja #FF8A1F com gola creme, emblema da Rota Brava em relevo no peito esquerdo, cinto com fivela-bussola, chapeu de aba larga com faixa e rosa dos ventos, rabos de cavalo, bolsa com caderno, lupa. Rig 28 ossos + ponteiras (RB-04), expressoes, visemas, olhar, 12 clipes.' }
)
foreach ($c in $heroes) {
    $blend = "source_art/characters/heroes/$($c.id)/$($c.id).blend"
    $glb = "game/assets/models/characters/$($c.id).glb"
    if ($c.script -eq 'pup_build') { Invoke-Blender 'source_art/scripts/pup_build.py' @('--blend', $blend, '--glb', $glb) }
    else { Invoke-Blender 'source_art/scripts/hero_build.py' @('--id', $c.id, '--blend', $blend, '--glb', $glb) }
    $info = Get-Content ([IO.Path]::ChangeExtension($blend, '.info.json')) -Raw | ConvertFrom-Json
    $anims = [ordered]@{}
    foreach ($p in $info.animations.PSObject.Properties | Sort-Object Name) { $anims[$p.Name] = [math]::Round(($p.Value[1] - $p.Value[0]) / 30.0, 3) }
    $entries += [ordered]@{
        id = $c.id; nome = $c.name; papel = $c.role; agente = 'art3d'
        processo = [ordered]@{ script = "source_art/scripts/$($c.script).py"; ferramenta = "Blender $bver (tools/blender.ps1, headless)"; exportador = 'glTF 2.0 binario (GLB), +Y up, metros, skin, shape keys, animacoes por NLA'; tecnicas = 'modificador SKIN + SUBSURF, metaballs (cabelo), torno (chapeu), bmesh; pesos por distancia normalizada pela espessura de cada parte; cinematica FK/IK em Python' }
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
# ---- retratos do HUD (busto 512x512, fundo transparente) gerados dos mesmos scripts
Invoke-Blender 'source_art/scripts/hero_portraits.py' @('--out', 'game/ui/portraits')
$portraits = [ordered]@{}
foreach ($p in Get-ChildItem 'game/ui/portraits' -Filter '*.png' | Sort-Object Name) { $portraits[$p.Name] = (Get-FileHash $p.FullName -Algorithm SHA256).Hash.ToLower() }
$entries += [ordered]@{
    id = 'portraits'; nome = 'Retratos do HUD'; agente = 'art3d'
    processo = [ordered]@{ script = 'source_art/scripts/hero_portraits.py'; ferramenta = "Blender $bver (tools/blender.ps1, headless)"; exportador = 'PNG RGBA 512x512 (Eevee toon, contorno Solidify)' }
    origem = @('source_art/scripts/hero_portraits.py') + $heroSrc
    saida = 'game/ui/portraits'
    arquivos_sha256 = $portraits
    status = 'provisorio'
    aprovacao = 'pendente (Thiago)'
    originalidade = 'renders dos personagens procedurais do projeto; nada de terceiros'
    data = (Get-Date -Format 'yyyy-MM-dd')
    nota = 'rastro, pico, leme, captain, pup x neutra, alegre, surpresa. Uso: Hud.set_portrait_texture(member, tex).'
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







