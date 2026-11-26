# Arte-chave da tela inicial e da capa (RB-R1 G8) · PROPOSTA

Tres propostas para Thiago escolher. **Nada aqui esta ligado ao menu** (`ui/main_menu.tscn` nao mudou).
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

## Como virar fundo do menu (depois da escolha)
No `TitleScreen._build()`, no lugar do `Background` + `HeroStage`:
```gdscript
var art := (load("res://ui/title/keyart/keyart_b.tscn") as PackedScene).instantiate() as KeyArtView
art.framing = &"menu"
art.show_logo = false   # o menu mantem o TextureRect Logo; trocar a textura pelo logo escolhido
add_child(art)
move_child(art, 0)
```
Na exportacao, incluir `ui/title/keyart/logos/*.svg` no filtro de recursos nao-importados para o logo ser
rasterizado no tamanho da tela; sem isso o `KeyArtView` cai para a textura importada (2x o viewBox).

## Pendencias conhecidas
- Olhos: em alguns quadros de clipe Rastro e Leme fecham os olhos fora das formas do rosto (G1, outro agente);
  o palco zera `alegre`/`blink` a cada quadro e escolhe quadros de olho aberto.
- Render medido so em Vulkan por software (llvmpipe); custo em GPU real nao medido.
