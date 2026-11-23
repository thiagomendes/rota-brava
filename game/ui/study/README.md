# Estudo de HUD e tipografia (RB-03-ui)

Tudo aqui e **PROVISORIO** ate Thiago escolher. Nenhuma opcao esta aprovada.

## Como ver
- Cena: `res://ui/study/ui_study.tscn`. `←/→` (intencoes `move_left/move_right`) trocam A/B/C; `PgUp/PgDn` trocam a tela; `Esc` volta ao menu.
- HUD real sobre o episodio: `res://ui/study/hud_capture.tscn` (so para o Movie Maker; injeta legendas/escolha pela API publica do `Hud`).
- Temas: `theme_a.tres` (Fredoka + "Cais"), `theme_b.tres` (Nunito + "Entardecer"), `theme_c.tres` (Baloo 2 + "Mata").
  Gerados por `ui_theme.gd` (`./tools/godot.ps1 --headless --path game --script res://ui/study/build_themes.gd`). Fonte e paleta sao independentes em `UiTheme`: da para combinar fonte de uma opcao com paleta de outra.
- O `Hud` aplica `theme_a.tres` por padrao (`Hud.DEFAULT_THEME`); `hud.apply_theme(theme)` troca.

## Fontes
Variaveis, OFL 1.1, em `game/assets/fonts/<familia>/` com `OFL.txt`; origem em `game/assets/fonts/LICENSES.md`.
O eixo de peso so e aplicado com a **chave inteira** da tag (`UiTheme.WGHT_TAG`); com `"wght"` em texto o Godot ignora e usa o peso padrao, que em Nunito e Fredoka e fino.

## Regra de conversao (alvo de toque)
- Viewport virtual de referencia: **1080 de altura** (`canvas_items` + `expand`, base 1920x1080). Em 20:9 o viewport vira 2400x1080; em 4:3 vira 1920x1440.
- `Hud.MIN_TOUCH = 128` unidades virtuais (altura e largura minima de todo botao). Premissa: lado curto do aparelho ~ 411 dp na altura de 1080 → 1 dp ≈ 2,6 unidades → 48 dp ≈ 126. Num aparelho de lado curto maior (tablet) o dp fica maior e o botao tambem.
- O teste exige **>= 96** (48 dp a 2 unidades/dp, regra do ticket) e **>= 128** (a regra acima). **Calibracao fisica fica para o teste em aparelho**: o tamanho em milimetros nao foi medido.
- Foco: contorno de 10 px na cor de foco, margem de 8 px, sombra e escala 1,05 (`UiTheme.make_focusable`); o mouse tambem foca ao passar. Funciona igual para teclado, controle e toque.

## Area segura e polegares
- Margem de **5% de cada lado, minimo 48 unidades** (`Hud.SAFE_FRACTION`, `Hud.SAFE_MIN`, `hud.safe_rect()`), recalculada quando o viewport muda. Tudo do HUD fica dentro; a escala de foco e o contorno podem passar da margem, nunca da tela.
- Cantos superiores: objetivo (esquerda) e quem controla (direita). Sem controles de toque neles.
- Base e centro: acao contextual **acima** da legenda, na mesma pilha (nunca se sobrepoem), entre as zonas dos polegares (18% laterais da metade inferior ficam livres para joystick e botao de acao, que serao do toque do RB-04+).
- Overlays (escolha, troca, pausa, conclusao) centralizados; a troca fica na base, para a cena (quem vai agir) continuar visivel.
- Legenda: ate ~62% da largura (max. 1180), ate 3 linhas na fala +40%, nome do falante acima do texto.

## O que as capturas e os testes provam (e nao provam)
- `game/tests/test_ui_study.gd` confere geometria (dentro da tela/area segura, tamanho de botao, linhas da legenda, foco inicial, fontes). Nao prova aparencia, legibilidade a distancia, toque real nem tamanho fisico.
- As capturas ficam em `captures/rb-03/ui/` (fora do Git) e foram vistas por mim em PNG; a opiniao de legibilidade para criancas e hipotese.
- Captura: o Movie Maker ignora `--resolution` por causa de `window_width_override` do projeto; as capturas usaram um `game/override.cfg` temporario (removido depois, nunca versionado).
