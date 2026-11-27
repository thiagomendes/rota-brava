# RB-M1 · Builds de validação em Android e iOS, com toque básico

Status: **aberto** (pedido de Thiago em 2026-11-27, em paralelo ao fechamento do RB-R1). Não é o RB-05: o conteúdo do jogo não muda. O que muda é onde ele roda e como se controla.

## Objetivo
Thiago instala e joga o Ep01 v3 nos próprios aparelhos:
- **Android:** APK instalado pelo cabo no celular ligado ao PC Windows.
- **iOS:** build enviada ao TestFlight a partir do GitHub Actions. Thiago tem a conta do Apple Developer Program e não tem Mac.

Por enquanto o objetivo é só validação. Não há publicação em loja.

## Decisões de Thiago (2026-11-27)
- **Android e iOS só sob demanda** (Thiago, 2026-11-27): os dois workflows rodam só por disparo manual (`workflow_dispatch`), nunca a cada push.
- **Android:** o GitHub Actions gera o APK quando disparado. Um script PowerShell no PC baixa o último APK e instala pelo `adb`. Thiago não instala o Android SDK.
- **Toque:** entra um **controle por toque básico** já neste ticket. Ele é provisório e tem UX infantil.
- **Assinatura iOS automática** com chave da App Store Connect API, papel Admin. Thiago cadastra os segredos no GitHub. O Xcode no Actions cria o certificado e o perfil com `-allowProvisioningUpdates` e envia ao TestFlight.
- **Bundle ID:** `com.thiagomendes.rotabrava`, igual no Android e no iOS.

## Escopo
1. **Presets de exportação** Android (APK arm64-v8a) e iOS no `game/export_presets.cfg`.
   - Renderizador móvel nos dois (`rendering_method.mobile`). O desktop continua em Forward+.
   - Ícone e nome do app vindos da identidade do jogo (logo C), sem marca de terceiros.
2. **Workflows do GitHub Actions** em `.github/workflows/`.
   - **`android.yml`:**
     - Linux, Godot 4.7.2 e templates fixados com SHA-256, como em `tools/toolchain.json`; JDK e Android SDK.
     - Disparo manual (`workflow_dispatch`). Exporta o APK e publica como artefato.
     - Keystore: usa o segredo `ANDROID_KEYSTORE_B64`/`ANDROID_KEYSTORE_PASS` se ele existir. Senão, usa uma keystore temporária da execução; nesse caso o script de instalação trata a troca de assinatura.
   - **`ios.yml`:**
     - macOS com Xcode; exporta o projeto Xcode pela Godot.
     - `xcodebuild archive` + `-exportArchive` com destino de envio ao App Store Connect, usando a chave da API.
     - Segredos: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_B64` e `APPLE_TEAM_ID`.
     - Disparo manual (`workflow_dispatch`).
3. **Script `tools/android-install.ps1`** (Windows):
   - Baixa e instala por conta própria as platform-tools, com hash fixado, em `.tools/`.
   - Baixa o último APK do Actions. Usa o `gh` se o Thiago tiver; senão, aceita o caminho de um APK já baixado.
   - Instala com `adb install -r`. Se a assinatura for diferente, avisa que isso apaga o save do aparelho e pede confirmação antes de desinstalar.
4. **Controle por toque básico** (provisório):
   - Aparece só quando há toque.
   - Joystick virtual à esquerda; botões grandes de pular e de agir à direita; arrastar o lado direito gira a câmera.
   - Botões de UI tocáveis, com alvo de 110 px ou mais.
   - Aciona as mesmas intenções da Input Map, sem entrada direta.
   - Some quando a criança usa teclado ou controle.
5. **Passo a passo para Thiago** em `docs/mobile.md`: o que criar no site da Apple e no App Store Connect, quais segredos cadastrar no GitHub, como instalar o APK e o que é verificado onde. Nenhum segredo vai para o repositório nem para o chat.

## Fora do escopo
Publicação em loja; ajuste fino de desempenho; UX de toque definitiva; ícones por dispositivo de entrada (é o G15 do RB-R1).

## Critérios de aceite
- `android.yml` verde no GitHub, com o APK como artefato. Tamanho e SHA-256 registrados aqui.
- `ios.yml`: a exportação e o archive compilam no runner. O envio ao TestFlight funciona assim que Thiago cadastrar os segredos. Até lá, o workflow falha com uma mensagem clara de segredo ausente, não com erro obscuro.
- O script instala o APK num aparelho Android real. Isso só Thiago pode provar.
- Toque básico com testes headless de toque simulado (`InputEventScreenTouch`/`ScreenDrag`) acionando as intenções. Aparência e conforto ficam pendentes de Thiago no aparelho.
- O renderizador móvel abre o menu e o Ep01 sem erro de shader no export. Só dá para provar no aparelho: desempenho e visual no telefone ficam pendentes de Thiago.

## Riscos
- O renderizador móvel pode mudar luz, sombra e pós-processamento. A vila tem custo alto, e o celular pode ficar lento.
- O GitHub cobra minutos de macOS em repositório privado com multiplicador alto; os dois workflows rodam só por disparo manual.
- A Apple exige que o registro do app já exista no App Store Connect antes do primeiro envio. Thiago cria esse registro manualmente uma vez.
- Uma keystore temporária no Android troca a assinatura a cada build. Reinstalar apaga o save do aparelho até existir uma keystore fixa.

## Divisão
- `build-qa`: presets, workflows, script e `docs/mobile.md`. Dono de `export_presets.cfg`, `.github/` e da parte de renderização do `project.godot`.
- `ux` + `gameplay`: controle por toque. Não mexe em `export_presets.cfg` nem em `.github/`; no `project.godot` só toca o que for necessário de entrada, e o lead serializa.

## Evidências
(preencher)

## Decisão de Thiago (2026-11-27): workflows na main
O GitHub só mostra o "Run workflow" quando o arquivo do workflow existe na branch padrão. Thiago autorizou mandar para a `main` **só** `.github/workflows/android.yml` e `ios.yml`, depois da revisão, sem o resto do RB-R1 e do RB-M1. Para rodar, ele escolhe a branch de integração em "Use workflow from".
### build-qa (2026-11-27, nuvem Linux, Godot 4.7.2.stable.official.ed1daf0bf, OpenJDK 21 do sistema)
- **Medido:** `tools/mobile_icons.gd` gerou 4 PNGs em `game/ui/brand/app_icon/` (manifesto `app_icon_m1`). Export iOS (projeto Xcode, `export_project_only`) **concluiu no Linux** com Team ID fictício: esquema `RotaBrava`, assinatura `Automatic`, bundle `com.thiagomendes.rotabrava`, `RotaBrava.pck` de 307 MB. Export Android parou só por falta de SDK (sem erro de preset, ícone ou ETC2/ASTC).
- **Bloqueado:** `dl.google.com` recusado pelo proxy da nuvem (403): sem Android SDK local, sem APK local e sem o SHA-256 das platform-tools Windows (`toolchain.json` marca `PENDENTE`; o `android.yml` mede e mostra no resumo do job).
- **Sintaxe:** `actionlint 1.7` + `shellcheck`: só 2 avisos informativos (SC2012, `ls` em vez de `find`).
- **Testes:** `bash tools/test.sh foundation` OK (72 PASS); `bash tools/test.sh test_assets` OK (280 PASS).
- **Pendente:** `android.yml` e `ios.yml` verdes no GitHub (depois do push e merge em `main`); APK: tamanho e SHA-256; `android-install.ps1` não foi executado (sem `pwsh` aqui); instalação, visual e desempenho no aparelho (Thiago).

## Revisão e integração
- **Revisão** (`reviewer`, 3 rodadas):
  - 1ª, REPROVADA: o artefato de falha do iOS levava o teamID, as actions não estavam fixadas por SHA e a keystore não era apagada.
  - 2ª, REPROVADA: os logs ainda continham Key ID e Issuer ID.
  - 3ª, APROVADA: a máscara dos três valores foi testada com log falso, e o caso forçado de falha sai com 1 e não faz upload.
- `foundation` 72 PASS, `test_assets` 280 PASS, `ui_` 248 PASS.
- **Na `main`:** entraram só os dois workflows (`32969cb`), por decisão de Thiago. O resto do RB-M1 está integrado na `feature/rb-r1-reorientacao`.
- **Ainda não validado:**
  - nenhum dos dois workflows rodou no GitHub;
  - o `android-install.ps1` nunca foi executado (não há pwsh na nuvem);
  - o SHA-256 das platform-tools do Windows segue PENDENTE (`dl.google.com` bloqueado aqui);
  - tamanho e SHA-256 do APK só existem depois da 1ª execução;
  - o toque básico está em andamento.
- **1ª execução do `android.yml`** (Thiago, run 45921259074, `e917b2a`): verde em 1 min 57 s.
  - APK exportado e assinado com a keystore temporária (CN=Rota Brava teste), porque não há segredo de keystore. Cada build sai com assinatura diferente, então reinstalar apaga o save do aparelho.
  - Artefato `rota-brava-android-apk`: 323.341.262 bytes compactados. Digest do zip: `sha256:d0ef6878…04a8`.
  - Tamanho e SHA-256 do APK e das platform-tools do Windows ficam no resumo do job; não aparecem no log.
  - Aviso do GitHub: as actions fixadas rodam em Node 20, que está obsoleto e é forçado para Node 24. Não é erro.
- **Instalação real** (Thiago, 2026-11-27): o APK da execução nº 1 foi instalado num tablet Samsung Galaxy Tab FE pelo cabo. Foi preciso desligar o "Bloqueador automático" da Samsung (Segurança e privacidade) para ligar a depuração USB. Thiago não relatou erro no `android-install.ps1`. Ainda faltam desempenho e visual no aparelho.
- **1ª execução do `ios.yml`** (Thiago, run 45921274599, `e917b2a`): verde em cerca de 6 min 45 s.
  - Export da Godot, `xcodebuild archive` com assinatura automática e envio ao App Store Connect concluídos ("Upload succeeded", "EXPORT SUCCEEDED").
  - O passo de máscara foi pulado porque não houve falha. Nenhum artefato.
  - **Avisos da Apple, válidos a partir de abril de 2027:** o build usou o SDK do iOS 26.5, e passará a ser exigido o SDK 27 (Xcode 27). O alvo é iOS 14.0, e o mínimo passará a ser 15.0. Subir o alvo para 15.0 numa próxima rodada.
  - Pendente de Thiago: processamento no TestFlight, conformidade de exportação, instalar no iPhone e jogar.
