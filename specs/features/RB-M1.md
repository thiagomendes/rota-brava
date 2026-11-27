# RB-M1 · Builds de validação em Android e iOS, com toque básico

Status: **aberto** (pedido de Thiago em 2026-11-27, em paralelo ao fechamento do RB-R1). Não é o RB-05: o conteúdo do jogo não muda. O que muda é onde ele roda e como se controla.

## Objetivo
Thiago instala e joga o Ep01 v3 nos próprios aparelhos:
- **Android:** APK instalado pelo cabo no celular ligado ao PC Windows.
- **iOS:** build enviada ao TestFlight a partir do GitHub Actions. Thiago tem a conta do Apple Developer Program e não tem Mac.

Por enquanto o objetivo é só validação. Não há publicação em loja.

## Decisões de Thiago (2026-11-27)
- **Android:** o GitHub Actions gera o APK a cada push. Um script PowerShell no PC baixa o último APK e instala pelo `adb`. Thiago não instala o Android SDK.
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
     - Exporta o APK e publica como artefato.
     - Keystore: usa o segredo `ANDROID_KEYSTORE_B64`/`ANDROID_KEYSTORE_PASS` se ele existir. Senão, usa uma keystore temporária da execução; nesse caso o script de instalação trata a troca de assinatura.
   - **`ios.yml`:**
     - macOS com Xcode; exporta o projeto Xcode pela Godot.
     - `xcodebuild archive` + `-exportArchive` com destino de envio ao App Store Connect, usando a chave da API.
     - Segredos: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_B64` e `APPLE_TEAM_ID`.
     - Disparo manual (`workflow_dispatch`), porque minuto de macOS custa caro.
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
- O GitHub cobra minutos de macOS em repositório privado com multiplicador alto. Por isso o iOS roda só por disparo manual.
- A Apple exige que o registro do app já exista no App Store Connect antes do primeiro envio. Thiago cria esse registro manualmente uma vez.
- Uma keystore temporária no Android troca a assinatura a cada build. Reinstalar apaga o save do aparelho até existir uma keystore fixa.

## Divisão
- `build-qa`: presets, workflows, script e `docs/mobile.md`. Dono de `export_presets.cfg`, `.github/` e da parte de renderização do `project.godot`.
- `ux` + `gameplay`: controle por toque. Não mexe em `export_presets.cfg` nem em `.github/`; no `project.godot` só toca o que for necessário de entrada, e o lead serializa.

## Evidências
(preencher)
