# Rota Brava no celular (RB-M1): passo a passo para o Thiago

Builds de **validação** (sem publicação em loja). Android: APK pelo cabo. iOS: TestFlight a partir do GitHub Actions, sem Mac.

> **Nunca cole senha, chave `.p8`, base64 de chave ou keystore no chat** (nem com o Claude, nem em issue ou commit). Segredos vão só no GitHub, em Settings > Secrets and variables > Actions.

## 1. Custo antes de tudo
- Os dois workflows só rodam quando você clica em **Run workflow**. Nada roda a cada push.
- Em repositório **privado**, minutos de **macOS** contam com multiplicador alto (10x os de Linux no plano atual do GitHub; confira em Settings > Billing). Uma build iOS leva em torno de 20 a 40 min de runner, ou seja, centenas de minutos da cota. Dispare o iOS só quando houver algo novo para testar.
- O Android roda em Linux (multiplicador 1x).

## 2. Apple (uma vez só)
Você precisa da conta do Apple Developer Program ativa.

1. **Bundle ID** `com.thiagomendes.rotabrava`
   - O workflow usa assinatura automática: o Xcode no Actions registra o bundle ID, cria o certificado e o perfil sozinho (`-allowProvisioningUpdates`).
   - Se preferir registrar à mão: developer.apple.com > Certificates, Identifiers & Profiles > Identifiers > **+** > App IDs > App. Descrição "Rota Brava", Bundle ID **Explicit** `com.thiagomendes.rotabrava`. Nenhuma capability extra.
2. **Criar o app no App Store Connect** (obrigatório antes do primeiro envio)
   - appstoreconnect.apple.com > Apps > **+** > New App.
   - Plataforma iOS, nome "Rota Brava" (se o nome estiver em uso, use outro só no App Store Connect, como "Rota Brava Jogo"), idioma Português (Brasil), Bundle ID `com.thiagomendes.rotabrava` (se ele não aparecer na lista, faça o item 1 à mão), SKU `rotabrava`, acesso total.
3. **Chave da App Store Connect API**
   - App Store Connect > **Users and Access > Integrations > App Store Connect API** > Team Keys > **+**.
   - Nome "GitHub Actions", papel (Access) **Admin**. O papel Admin é o que deixa o Xcode criar certificado e perfil.
   - Clique em **Download API Key**: baixa `AuthKey_XXXXXXXXXX.p8`. **Só dá para baixar uma vez**; guarde num lugar seguro.
   - Anote o **Key ID** (coluna da chave) e o **Issuer ID** (no topo da página).
4. **Team ID**: developer.apple.com > Account > Membership details > Team ID (10 caracteres).

## 3. GitHub: segredos
No repositório: **Settings > Secrets and variables > Actions > New repository secret**. Um por vez, nome exato:

| Segredo | Valor | Usado por |
|---|---|---|
| `ASC_KEY_ID` | Key ID da chave da API | iOS |
| `ASC_ISSUER_ID` | Issuer ID | iOS |
| `ASC_KEY_P8_B64` | conteúdo do `.p8` em base64 (abaixo) | iOS |
| `APPLE_TEAM_ID` | Team ID | iOS |
| `ANDROID_KEYSTORE_B64` | keystore em base64 (opcional) | Android |
| `ANDROID_KEYSTORE_PASS` | senha da keystore (opcional) | Android |
| `ANDROID_KEY_ALIAS` | alias da chave (opcional) | Android |

**Converter o `.p8` em base64 no Windows** (PowerShell, na pasta onde está o arquivo). O comando copia direto para a área de transferência, sem mostrar na tela:
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$PWD\AuthKey_XXXXXXXXXX.p8")) | Set-Clipboard
```
Cole no campo do segredo `ASC_KEY_P8_B64` e salve.

**Keystore fixa do Android (opcional, recomendado).** Sem ela, cada APK sai com uma assinatura nova e, para instalar por cima, é preciso desinstalar, o que apaga o save. Para criar uma vez (precisa de Java; o `keytool` vem com qualquer JDK):
```powershell
keytool -genkeypair -v -keystore rotabrava.keystore -alias rotabrava -keyalg RSA -keysize 2048 -validity 10000
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$PWD\rotabrava.keystore")) | Set-Clipboard
```
Cadastre `ANDROID_KEYSTORE_B64` (área de transferência), `ANDROID_KEYSTORE_PASS` (a senha que você escolheu) e `ANDROID_KEY_ALIAS` = `rotabrava`. Guarde o arquivo `rotabrava.keystore` fora do repositório; ele não vai para o Git.

## 4. Disparar os workflows
1. No GitHub, aba **Actions**.
2. À esquerda, escolha **Android APK** ou **iOS TestFlight**.
3. Botão **Run workflow** > escolha a branch > **Run workflow**.
4. Ao terminar, abra a execução: o **resumo** mostra tamanho e SHA-256 do APK, ou o envio ao TestFlight. Se faltar segredo do iOS, o primeiro passo falha com a lista do que falta.

Os workflows só existem no GitHub depois que a branch com `.github/workflows/` for enviada (push). O GitHub só oferece **Run workflow** para workflows que já estão na branch padrão (`main`). Depois disso, dá para rodar sobre outra branch escolhendo-a no botão, ou pela linha de comando: `gh workflow run android.yml --ref <branch>`.

## 5. iOS: TestFlight
1. Depois de um **iOS TestFlight** verde, a Apple processa a build (de 5 a 30 min; chega um e-mail).
2. App Store Connect > Apps > Rota Brava > **TestFlight**.
   - A primeira vez pede a informação de conformidade de criptografia: o jogo não usa criptografia própria (responda "None of the algorithms mentioned above" / não usa).
3. **Testadores internos**: TestFlight > Internal Testing > **+** > crie um grupo ("Casa") > adicione pessoas da sua equipe do App Store Connect (você já é membro). Marque a build no grupo.
4. No iPhone/iPad: instale o app **TestFlight** da App Store, entre com o mesmo Apple ID e toque em **Instalar** no Rota Brava.
- Testadores internos não precisam de revisão da Apple. Cada build vale por 90 dias.

## 6. Android: instalar pelo cabo
**No celular, uma vez:**
1. Configurações > Sobre o telefone > toque **7 vezes** em "Número da versão" (ativa o modo desenvolvedor).
2. Configurações > Sistema > Opções do desenvolvedor > ligue **Depuração USB**.
3. Ligue o cabo (de dados) ao PC, desbloqueie a tela e aceite **Permitir depuração USB**.

**No PC (PowerShell 7, na pasta do repositório):**
```powershell
pwsh tools/android-install.ps1                       # baixa o último APK do Actions (precisa do gh: winget install GitHub.cli; gh auth login)
pwsh tools/android-install.ps1 -Apk C:\caminho\RotaBrava.apk   # sem gh: baixe o artefato pelo site e passe o caminho
pwsh tools/android-install.ps1 -DryRun               # só mostra o que faria
```
- O script instala o `adb` sozinho em `.tools/platform-tools` (não precisa do Android SDK).
- Se o celular tiver uma build com outra assinatura, o script avisa que desinstalar **apaga o save** e só continua se você digitar `APAGAR`.
- Sem o `gh`: Actions > Android APK > última execução verde > **Artifacts** > `rota-brava-android-apk` (vem em .zip; descompacte).

## 7. O que é verificado onde
| Item | Onde | Quem |
|---|---|---|
| Presets, ícones, sintaxe dos workflows | nuvem de desenvolvimento | build-qa |
| Export do APK, tamanho e SHA-256 | Actions (Android APK) | automático |
| Archive iOS e envio ao TestFlight | Actions (iOS TestFlight) | automático, depois dos segredos |
| Instalação, visual, som, toque e desempenho no aparelho | celular e iPad reais | **só o Thiago** |
