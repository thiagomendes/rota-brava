# Funcoes compartilhadas pelos scripts de tools/. Uso: . "$PSScriptRoot/common.ps1"

function Get-ToolsRoot {
    # Onde fica .tools/godot. Em worktrees (.tools e ignorado pelo Git) usa o checkout principal.
    param([string]$Root)
    if ($env:RB_TOOLS_ROOT) { return $env:RB_TOOLS_ROOT }
    if (Test-Path (Join-Path $Root '.tools/godot')) { return $Root }
    $common = git -C $Root rev-parse --path-format=absolute --git-common-dir 2>$null
    if ($LASTEXITCODE -eq 0 -and $common) {
        $main = Split-Path $common -Parent
        if (Test-Path (Join-Path $main '.tools/godot')) { return $main }
    }
    return $Root
}
