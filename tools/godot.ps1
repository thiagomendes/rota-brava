#requires -Version 7
# Executa a Godot fixada (console) a partir da raiz do repositorio. Uso: ./tools/godot.ps1 <args da Godot>
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$cfg = (Get-Content (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json).godot
. "$PSScriptRoot/common.ps1"
$exe = Join-Path (Get-ToolsRoot $root) ".tools/godot/$($cfg.editor.console)"
if (-not (Test-Path $exe)) { throw "Godot ausente. Rode ./tools/setup-toolchain.ps1" }
# Depois de um git pull, o cache de classes da Godot (game/.godot) fica velho e o jogo falha com
# "Parse error" ao abrir sem importar. Reimporta uma vez quando o commit muda.
if (-not ($args -contains '--import')) {
    $head = (& git -C $root rev-parse HEAD 2>$null)
    $stamp = Join-Path $root 'game/.godot/rb_import_head.txt'
    $last = if (Test-Path $stamp) { (Get-Content $stamp -Raw).Trim() } else { '' }
    if ($head -and $head -ne $last) {
        Write-Host "Importando o projeto (commit novo: $($head.Substring(0, 7)))..."
        & $exe --headless --path (Join-Path $root 'game') --import | Out-Null
        if ($LASTEXITCODE -eq 0) { Set-Content -Path $stamp -Value $head -NoNewline }
    }
}
& $exe @args
exit $LASTEXITCODE
