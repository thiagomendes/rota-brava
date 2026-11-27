#Requires -Version 7.0
<#
.SYNOPSIS
  RB-M1: instala o APK do Rota Brava num celular Android ligado por cabo ao PC Windows.

.DESCRIPTION
  1. Instala as platform-tools do Google (adb) em .tools/platform-tools, com SHA-256 conferido (tools/toolchain.json).
  2. Pega o APK: opcao A, baixa o ultimo artefato "rota-brava-android-apk" do GitHub Actions com o gh;
     opcao B, usa o APK ja baixado passado em -Apk.
  3. Lista os aparelhos (adb devices) e instala com "adb install -r".
  4. Se a assinatura for diferente da build instalada, avisa que desinstalar apaga o save e pede confirmacao.

.EXAMPLE
  pwsh tools/android-install.ps1
  pwsh tools/android-install.ps1 -Apk "$HOME\Downloads\RotaBrava.apk"
  pwsh tools/android-install.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [string]$Apk = '',
    [string]$Repo = 'thiagomendes/rota-brava',
    [switch]$DryRun
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = Split-Path $PSScriptRoot -Parent
$Tools = Join-Path $Root '.tools'
$Package = 'com.thiagomendes.rotabrava'
$Artifact = 'rota-brava-android-apk'

function Step([string]$msg) { Write-Host "`n> $msg" -ForegroundColor Cyan }

# ---------- 1. platform-tools (adb) ----------
$tc = Get-Content (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json
$pt = $tc.android.platformToolsWindows
$ptDir = Join-Path $Tools 'platform-tools'
$adb = Join-Path $ptDir 'adb.exe'

if (-not (Test-Path $adb)) {
    Step "Instalando platform-tools $($pt.version) em $ptDir"
    $cache = Join-Path $Tools 'cache'
    New-Item -ItemType Directory -Force -Path $cache | Out-Null
    $zip = Join-Path $cache "platform-tools-$($pt.version)-win.zip"
    if ($DryRun) {
        Write-Host "[dry-run] baixaria $($pt.url) e conferiria o SHA-256 '$($pt.sha256)'"
    } else {
        if (-not (Test-Path $zip)) { Invoke-WebRequest -Uri $pt.url -OutFile $zip }
        $got = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($pt.sha256 -eq 'PENDENTE') {
            Write-Warning "O SHA-256 das platform-tools ainda nao esta fixado em tools/toolchain.json."
            Write-Host "SHA-256 do arquivo baixado: $got"
            Write-Host "Compare com o valor do resumo do ultimo job 'Android APK' no GitHub Actions (secao 'platform-tools Windows')."
            $ok = Read-Host 'Os dois sao iguais? Digite SIM para continuar'
            if ($ok -ne 'SIM') { Remove-Item $zip -Force; throw 'Instalacao cancelada: hash nao confirmado.' }
        } elseif ($got -ne $pt.sha256.ToLowerInvariant()) {
            Remove-Item $zip -Force
            throw "SHA-256 divergente nas platform-tools (esperado $($pt.sha256), obtido $got). Arquivo apagado."
        }
        Expand-Archive -Path $zip -DestinationPath $Tools -Force
        if (-not (Test-Path $adb)) { throw "adb.exe nao encontrado depois de extrair $zip" }
    }
}

function Adb {
    # sem param(): assim "-s <serial>" passa direto ao adb em $args
    if ($DryRun -and -not (Test-Path $adb)) { Write-Host "[dry-run] adb $($args -join ' ')"; return '' }
    return (& $adb @args 2>&1 | Out-String)
}

# ---------- 2. APK ----------
if ($Apk) {
    if (-not (Test-Path $Apk)) { throw "APK nao encontrado: $Apk" }
    $Apk = (Resolve-Path $Apk).Path
} else {
    Step "Baixando o ultimo APK do GitHub Actions ($Repo)"
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $gh) {
        throw @"
O GitHub CLI (gh) nao esta instalado. Duas saidas:
  - Instale com: winget install --id GitHub.cli   e depois: gh auth login
  - Ou baixe o APK no site: aba Actions > Android APK > ultima execucao verde > Artifacts > $Artifact,
    descompacte e rode: pwsh tools/android-install.ps1 -Apk <caminho do RotaBrava.apk>
"@
    }
    & gh auth status *> $null
    if ($LASTEXITCODE -ne 0) { throw 'O gh nao esta autenticado. Rode: gh auth login (ou use -Apk <caminho>).' }
    $runId = (& gh run list --repo $Repo --workflow android.yml --status success --limit 1 --json databaseId --jq '.[0].databaseId').Trim()
    if (-not $runId) { throw 'Nenhuma execucao verde do workflow android.yml. Dispare em Actions > Android APK > Run workflow.' }
    $dest = Join-Path $Root "build/android/run-$runId"
    if ($DryRun) {
        Write-Host "[dry-run] gh run download $runId --repo $Repo --name $Artifact --dir $dest"
        $Apk = Join-Path $dest 'RotaBrava.apk'
    } else {
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
        & gh run download $runId --repo $Repo --name $Artifact --dir $dest
        if ($LASTEXITCODE -ne 0) { throw "Falha ao baixar o artefato $Artifact da execucao $runId." }
        $Apk = Join-Path $dest 'RotaBrava.apk'
        $shaFile = "$Apk.sha256"
        if (Test-Path $shaFile) {
            $want = ((Get-Content $shaFile -Raw).Trim() -split '\s+')[0].ToLowerInvariant()
            $got = (Get-FileHash $Apk -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($want -ne $got) { throw "SHA-256 do APK nao confere com o do Actions ($want x $got)." }
            Write-Host "SHA-256 do APK confere: $got"
        }
    }
}
Write-Host "APK: $Apk"

# ---------- 3. Aparelhos ----------
Step 'Procurando aparelhos (adb devices)'
$list = Adb devices
Write-Host $list
$devices = @($list -split "`r?`n" | Where-Object { $_ -match '^\S+\s+device$' })
$unauth = @($list -split "`r?`n" | Where-Object { $_ -match '\sunauthorized$' })
if ($unauth.Count -gt 0) {
    Write-Warning 'O celular esta ligado mas nao autorizou este PC. Desbloqueie a tela e toque em "Permitir" na janela de depuracao USB.'
}
if ($devices.Count -eq 0 -and -not $DryRun) {
    Write-Host @"

Nenhum aparelho pronto. Para ligar a depuracao USB:
  1. No celular: Configuracoes > Sobre o telefone > toque 7 vezes em "Numero da versao" (ativa o modo desenvolvedor).
  2. Configuracoes > Sistema > Opcoes do desenvolvedor > ligue "Depuracao USB".
  3. Ligue o cabo USB (de dados, nao so de carga) e escolha "Transferir arquivos" se o celular perguntar.
  4. Desbloqueie a tela e aceite "Permitir depuracao USB" para este computador.
  5. Rode este script de novo.
"@
    exit 2
}
if ($devices.Count -gt 1) {
    Write-Warning "Ha $($devices.Count) aparelhos; instalando no primeiro. Deixe so um ligado para escolher."
}
$serial = if ($devices.Count -gt 0) { ($devices[0] -split '\s+')[0] } else { '<aparelho>' }

# ---------- 4. Instalar ----------
Step "Instalando em $serial (adb install -r)"
if ($DryRun) {
    Write-Host "[dry-run] adb -s $serial install -r `"$Apk`""
    Write-Host '[dry-run] nada foi instalado.'
    exit 0
}
$res = Adb -s $serial install -r $Apk
Write-Host $res
if ($res -match 'Success') {
    Write-Host "`nPronto: Rota Brava instalado. Abra pelo icone no celular." -ForegroundColor Green
    exit 0
}
if ($res -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE|signatures do not match|INSTALL_FAILED_SHARED_USER_INCOMPATIBLE') {
    Write-Warning @"
A build instalada no celular foi assinada com outra chave (acontece quando o Actions usa keystore temporaria).
Para instalar esta, e preciso DESINSTALAR a anterior. Isso APAGA O SAVE do jogo neste aparelho
(missoes, emblemas e opcoes). Nao ha como recuperar.
"@
    $ok = Read-Host 'Digite APAGAR para desinstalar e reinstalar, ou Enter para cancelar'
    if ($ok -ne 'APAGAR') { Write-Host 'Cancelado. Nada mudou no aparelho.'; exit 3 }
    Write-Host (Adb -s $serial uninstall $Package)
    $res = Adb -s $serial install $Apk
    Write-Host $res
    if ($res -match 'Success') { Write-Host "`nPronto: reinstalado (save anterior apagado)." -ForegroundColor Green; exit 0 }
}
throw "Falha na instalacao. Saida do adb acima."
