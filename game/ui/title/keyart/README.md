# Arte-chave da tela inicial e da capa (RB-R1 G8)

**Escolha de Thiago (2026-11-26): cena B (Noite das lanternas) + logo C em versao noite** (`logos/logo_c_noite.svg`:
recheio creme quente, halo ambar, sombra e estrela-guia com brilho de farol). Ja ligada ao menu:
`TitleScreen` (e `MainMenu`) poe `keyart_b.tscn` com `framing = &"menu"` atras dos botoes e usa o logo C noite no
`TextureRect` `logo`. `KeyArtPresets.LOGOS[&"b"]` aponta para o logo C noite. A e C ficam como historico.
Tudo e render 3D no motor (vila v3, barco amarelo `boat_wv2`, trio v2) + logotipo SVG do projeto.

| Proposta | Cena | Luz | Logo | Paleta (dominante, apoio, acento, sombra, luz) |
|---|---|---|---|---|
| A · Rumo ao por do sol | `keyart_a.tscn` | hora magica, sol baixo atras do farol | `logos/logo_a.svg` bloco italico, sol nascente, onda | `#FF9A4D` `#2E3A8C` `#FFD23A` `#14213D` `#FFF1D6` |
| B · Noite das lanternas | `keyart_b.tscn` | noite de festa, lanternas acesas, feixe do farol | `logos/logo_b.svg` letras redondas, O = lanterna, varal | `#1A1440` `#FFB347` `#E8504A` `#2A1745` `#FFF4D6` |
| C · Amanhecer no farol | `keyart_c.tscn` | amanhecer rosado vindo do leste | `logos/logo_c.svg` insignia em arco, fita, estrela-guia | `#8FB8F0` `#FFC3A0` `#E2453A` `#102A43` `#FFFFFF` |

Os dados de cada proposta (posicoes, clipes e quadro segurado, luz, ceu, agua, cameras por formato, lugar do logo)
ficam em `keyart_presets.gd`. As poses sao clipes que ja existem nos rigs (`point`, `celebrate`, `wave`,
`react_surprise`), tocados com velocidade 0 no quadro escolhido; nenhum rig foi mexido.

## Arquivos
- `keyart_stage.gd` (`KeyArtStage`): monta vila, barco, trio, luz e camera; movimento leve (barco, camera, pose
  respirando +-0,04 s, lanterna do farol na festa). Sem movimento com `Options.reduced_motion()`.
- `keyart_view.gd` (`KeyArtView`): palco num SubViewport do tamanho da tela + logo SVG rasterizado no tamanho exato +
  veu do lado dos botoes no modo menu. `mouse_filter` ignorado e sem foco: nao rouba foco nem clique do menu.
- `keyart_capture.gd`: renderiza todos os formatos (ver cabecalho). Nao e teste.
- Fonte dos logos: `source_art/ui/keyart/make_logos.py` (lettering proprio, sem fonte de terceiros).

## Formatos (`framing`)
`wide` 16:9 (capa/tela inicial), `portrait` 3:4 (loja), `capsule` 460x215 (render 1840x860 reduzido 4x),
`menu` (grupo no terco esquerdo, calculado pela proporcao da tela: vale para 16:9, 20:9 e 4:3).

## Como o menu usa (aplicado em `ui/title/title_screen.gd`)
`hero_stage`, `hero_root` e `hero_models` passam a apontar para o palco e o trio da arte-chave (mesma API dos testes).
Sem a cena da arte-chave, a tela volta ao ceu/mar e ao palco antigos. Equivalente a:
```gdscript
var art := (load("res://ui/title/keyart/keyart_b.tscn") as PackedScene).instantiate() as KeyArtView
art.framing = &"menu"
art.show_logo = false   # o menu mantem o TextureRect Logo; trocar a textura pelo logo escolhido
add_child(art)
move_child(art, 0)
```
`export_presets.cfg` inclui `ui/title/keyart/logos/*.svg` no filtro de recursos nao-importados: o logo e
rasterizado no tamanho real da tela; sem o arquivo, cai para a textura importada (2x o viewBox).
Custo: o menu carrega a vila v3 inteira (o Jogar carrega a mesma vila depois); medido so em Vulkan por software.

## Pendencias conhecidas
- Olhos: depois do G1 o olho fechado vem so da forma `alegre`/`blink`; o palco zera as duas a cada quadro, depois de o
  clipe ser avaliado (prioridade 10), e usa a expressao `neutra`.
- Render medido so em Vulkan por software (llvmpipe); custo em GPU real nao medido.

## Imagem parada do menu (G10)
`stills/b_bg_16x9.jpg` (1920x1080, SHA-256 `f35d2f930b2c18a02468c2f439b0df5273c6eb9093c7a8d10a1606ad221c0f4c`): fundo do
menu sem logo e sem botoes, mostrado so se o palco 3D faltar/falhar ou se a tela de carregamento estourar o teto de
20 s (o palco entra depois com fade). Gerada de `keyart_b.tscn` com
`xvfb-run -a -s "-screen 0 2560x2048x24" bash tools/godot.sh --path game --rendering-driver vulkan --script res://ui/title/keyart/keyart_capture.gd -- --proposal=b --out=<dir> --only=bg`
(PNG convertido para JPEG qualidade 88 com PIL). Registrada em `source_art/manifest.json` (`keyart_b_bg_still`).
Regerar se a cena B mudar.
