#requires -Version 7
<#
  Smoke test da build Windows (RB-01): abre o exe, envia teclas reais, captura a janela e fecha pelo menu.
  Precisa de sessao de desktop interativa. Saida: captures/rb-01-*.png e logs/smoke-stdout.log.
  Exit 0 = todas as verificacoes passaram.
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$exe = Join-Path $root 'build/windows/RotaBrava.console.exe'
if (-not (Test-Path $exe)) { throw 'Build ausente. Rode ./tools/build-windows.ps1' }
$capDir = Join-Path $root 'captures'; $logDir = Join-Path $root 'logs'
New-Item -ItemType Directory -Force -Path $capDir, $logDir | Out-Null
$stdout = Join-Path $logDir 'smoke-stdout.log'; $stderr = Join-Path $logDir 'smoke-stderr.log'
Remove-Item $stdout, $stderr -ErrorAction SilentlyContinue

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @'
using System; using System.Runtime.InteropServices;
public static class RbWin {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
}
'@
[void][RbWin]::SetProcessDPIAware()

$failures = 0
function Check([bool]$ok, [string]$label) {
    if ($ok) { Write-Host "PASS  $label" } else { $script:failures++; Write-Host "FAIL  $label" -ForegroundColor Red }
}
function Log { if (Test-Path $stdout) { Get-Content $stdout -Raw } else { '' } }
function WaitLog([string]$text, [int]$seconds = 20) {
    $end = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $end) { if ((Log) -match [regex]::Escape($text)) { return $true }; Start-Sleep -Milliseconds 200 }
    return $false
}
function Capture([System.Diagnostics.Process]$p, [string]$name) {
    $p.Refresh()
    $r = New-Object RbWin+RECT
    [void][RbWin]::GetWindowRect($p.MainWindowHandle, [ref]$r)
    $w = $r.R - $r.L; $h = $r.B - $r.T
    if ($w -le 0 -or $h -le 0) { return $null }
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
    $path = Join-Path $capDir $name
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
    return $path
}
# Scancodes (set 1) para que a Godot enxergue teclas fisicas, como num teclado real.
$ScanCodes = @{ 'E' = @(0x12, $false); 'ESC' = @(0x01, $false); 'ENTER' = @(0x1C, $false); 'DOWN' = @(0x50, $true); 'UP' = @(0x48, $true) }
function Keys([string]$name) {
    $scan, $ext = $ScanCodes[$name]
    $extFlag = if ($ext) { 1 } else { 0 }
    [RbWin]::keybd_event(0, [byte]$scan, 0x8 -bor $extFlag, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [RbWin]::keybd_event(0, [byte]$scan, 0x8 -bor 0x2 -bor $extFlag, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 700
}

$game = $null
$proc = Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) -PassThru `
    -RedirectStandardOutput $stdout -RedirectStandardError $stderr
try {
    Check (WaitLog '[RB] menu_ready focus=PlayButton') 'menu abre com foco em Jogar'
    Start-Sleep -Seconds 2
    # O .console.exe e um lancador: a janela pertence ao RotaBrava.exe filho.
    $childId = (Get-CimInstance Win32_Process -Filter "ParentProcessId=$($proc.Id) AND Name='RotaBrava.exe'" | Select-Object -First 1).ProcessId
    Check ($null -ne $childId) 'processo do jogo (RotaBrava.exe) encontrado'
    $game = Get-Process -Id $childId
    [void]$game.Handle   # mantem o handle aberto para ler ExitCode depois
    $game.Refresh()
    Check ($game.MainWindowHandle -ne 0 -and [RbWin]::IsWindowVisible($game.MainWindowHandle)) 'janela visivel'
    [void][RbWin]::SetForegroundWindow($game.MainWindowHandle); Start-Sleep -Milliseconds 500
    $shot1 = Capture $game 'rb-01-menu.png'
    Check ($null -ne $shot1) "captura do menu: $shot1"

    Keys 'ENTER'
    Check (WaitLog '[RB] play_ready' 5) 'Enter em Jogar abre a tela de jogo'
    Keys 'E'; Keys 'E'
    Check ((Log) -match 'interact count=2') 'tecla E gera 2 interacoes'
    $shot2 = Capture $game 'rb-01-jogo.png'
    Check ($null -ne $shot2) "captura da tela de jogo: $shot2"
    Keys 'ESC'
    Check (WaitLog 'back_to_menu' 5) 'Esc volta ao menu'
    Start-Sleep -Seconds 1
    Keys 'DOWN'; Keys 'DOWN'; Keys 'ENTER'
    Check (WaitLog '[RB] quit' 5) 'Sair pelo menu por teclado'
    Check ($game.WaitForExit(10000)) 'processo do jogo encerrou'
    if ($game.HasExited) { Check ($game.ExitCode -eq 0) "codigo de saida do jogo 0 (obtido $($game.ExitCode))" }
    Check ($proc.WaitForExit(5000)) 'lancador encerrou junto'
    if ($proc.HasExited) { Check ($proc.ExitCode -eq 0) "codigo de saida do lancador 0 (obtido $($proc.ExitCode))" }
}
finally {
    foreach ($p in @($game, $proc)) {
        if ($p -and -not $p.HasExited) { $p.Kill(); Write-Host "Processo $($p.Id) encerrado a forca." -ForegroundColor Yellow }
    }
}
Write-Host "---- stdout ----"; Log | Write-Host
Write-Host "RESULTADO: $(if ($failures -eq 0) { 'OK' } else { "FALHOU ($failures)" })"
exit ([int]($failures -gt 0))
