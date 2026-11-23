class_name UiTheme
extends RefCounted
## Fabrica dos temas candidatos do estudo de UI (RB-03). PROVISORIOS ate Thiago escolher.
## A = Cais (Fredoka + teal/amarelo), B = Entardecer (Nunito + quentes), C = Mata (Baloo 2 + verdes).
## Gera game/ui/study/theme_a|b|c.tres com `--script res://ui/study/build_themes.gd`.

const FONTS := {
	&"a": "res://assets/fonts/fredoka/Fredoka-VF.ttf",
	&"b": "res://assets/fonts/nunito/Nunito-VF.ttf",
	&"c": "res://assets/fonts/baloo2/Baloo2-VF.ttf",
}
const NAMES := {&"a": "A Cais", &"b": "B Entardecer", &"c": "C Mata"}
const OPTIONS: Array[StringName] = [&"a", &"b", &"c"]
## Peso (eixo wght) por familia: Nunito e mais fina, entao pede peso maior para ler de longe.
const WEIGHTS := {&"a": 600, &"b": 800, &"c": 700}
## Tag OpenType do eixo de peso ('wght'); o Godot so aplica a variacao com a chave inteira.
const WGHT_TAG := 2003265652

## panel: fundo dos paineis; text: texto; accent: acao do momento e titulos; button/button_hover: caixas;
## focus: contorno de foco; water: tom frio de apoio (legenda/objetivo).
const PALETTES := {
	&"a": {"panel": Color("0a2b33e6"), "text": Color("f6f1e1"), "accent": Color("ffd24d"), "button": Color("1f6f78"),
		"button_hover": Color("2b8c96"), "focus": Color("ffd24d"), "prompt": Color("2a2208f0"), "sub": Color("051a20ee")},
	&"b": {"panel": Color("3a1d26e6"), "text": Color("fff1dc"), "accent": Color("ffb347"), "button": Color("a04b3b"),
		"button_hover": Color("bd6149"), "focus": Color("ffe08a"), "prompt": Color("40200af0"), "sub": Color("200f14ee")},
	&"c": {"panel": Color("0f3022e6"), "text": Color("eef5e0"), "accent": Color("d9f36b"), "button": Color("2f7a4a"),
		"button_hover": Color("3f9760"), "focus": Color("fff07a"), "prompt": Color("1b2a08f0"), "sub": Color("07180fee")},
}

const FONT_SIZE := 34
const BUTTON_FONT_SIZE := 40
const FOCUS_BORDER := 10


static func _box(bg: Color, radius: int, margin: int, border: int = 0, border_color: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = border_color
	return sb


static func build(option: StringName) -> Theme:
	var pal: Dictionary = PALETTES[option]
	var th := Theme.new()
	var base := load(FONTS[option]) as FontFile
	var font := FontVariation.new()
	font.base_font = base
	font.variation_opentype = {WGHT_TAG: WEIGHTS[option]}
	th.default_font = font
	th.default_font_size = FONT_SIZE
	var text: Color = pal["text"]
	var accent: Color = pal["accent"]
	# Rotulos
	th.set_color("font_color", "Label", text)
	th.set_constant("outline_size", "Label", 0)
	th.set_type_variation("AccentLabel", "Label")
	th.set_color("font_color", "AccentLabel", accent)
	th.set_type_variation("DimLabel", "Label")
	th.set_color("font_color", "DimLabel", Color(text, 0.8))
	# Paineis
	th.set_stylebox("panel", "PanelContainer", _box(pal["panel"], 20, 18))
	th.set_type_variation("HudPanel", "PanelContainer")
	th.set_stylebox("panel", "HudPanel", _box(pal["panel"], 20, 18))
	# Modal (escolha): opaco, para o cenario nao atrapalhar a leitura.
	th.set_type_variation("ModalPanel", "PanelContainer")
	th.set_stylebox("panel", "ModalPanel", _box(Color(Color(pal["panel"]), 1.0), 24, 24, 4, Color(text, 0.25)))
	th.set_type_variation("PromptPanel", "PanelContainer")
	th.set_stylebox("panel", "PromptPanel", _box(pal["prompt"], 20, 18, 4, accent))
	th.set_type_variation("SubtitlePanel", "PanelContainer")
	th.set_stylebox("panel", "SubtitlePanel", _box(pal["sub"], 20, 18))
	# Botoes: caixa cheia; foco = contorno grosso colorido com recuo claro (a escala leve vem de UiTheme.make_focusable).
	var normal := _box(pal["button"], 22, 16, 4, Color(text, 0.35))
	var hover := _box(pal["button_hover"], 22, 16, 4, Color(text, 0.6))
	var pressed := _box(Color(pal["button"]).darkened(0.25), 22, 16, 4, accent)
	var focus := _box(Color.TRANSPARENT, 26, 16, FOCUS_BORDER, pal["focus"])
	focus.set_expand_margin_all(8)
	focus.shadow_color = Color(0, 0, 0, 0.55)
	focus.shadow_size = 10
	var disabled := _box(Color(pal["button"]).darkened(0.5), 22, 16)
	th.set_stylebox("normal", "Button", normal)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("focus", "Button", focus)
	th.set_stylebox("disabled", "Button", disabled)
	th.set_color("font_color", "Button", text)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_focus_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", accent)
	th.set_font_size("font_size", "Button", BUTTON_FONT_SIZE)
	# Cores de apoio lidas pelo HUD (tema "Hud")
	th.set_color("accent", "Hud", accent)
	th.set_color("text", "Hud", text)
	th.set_color("focus", "Hud", pal["focus"])
	th.set_color("water", "Hud", Color("7fd0e0"))
	return th


## Faz o botao crescer um pouco ao receber foco (alem do contorno grosso do tema). Funciona com teclado, controle e mouse.
static func make_focusable(b: Button) -> void:
	b.focus_mode = Control.FOCUS_ALL
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.focus_entered.connect(func() -> void: _scale_to(b, 1.05))
	b.focus_exited.connect(func() -> void: _scale_to(b, 1.0))
	# So com o mouse de fato em movimento: uma tela nova aberta sob um mouse parado nao pode roubar o foco inicial.
	b.mouse_entered.connect(func() -> void:
		if not b.disabled and Input.get_last_mouse_velocity().length() > 1.0:
			b.grab_focus())


static func _scale_to(b: Button, s: float) -> void:
	if not b.is_inside_tree():
		b.scale = Vector2(s, s)
		return
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(s, s), 0.08)

