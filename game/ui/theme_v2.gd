class_name ThemeV2
extends RefCounted
## Tema v2 da UI (RB-R1, style-bible secoes 5 e 9): chunky, redondo, contorno claro grosso, sombra suave,
## Fredoka 600/700, foco amarelo-ouro forte com escala em mola. Substitui os candidatos A/B/C do estudo RB-03.

const FONT_PATH := "res://assets/fonts/fredoka/Fredoka-VF.ttf"
const NAVY := Color("123A5E")
const NAVY_DEEP := Color("0B2440")
const GOLD := Color("FFC83D")
const ACTION := Color("FFD23F")
const PAPER := Color("F7FBFF")
const SKY := Color("4FA6E8")
const BLUE := Color("2F8CFF")
const ORANGE_TEXT := Color("D9620B")
const MUTED := Color("5C7189")
const FONT_SIZE := 34
const BUTTON_FONT_SIZE := 42
const RADIUS := 32
const FOCUS_BORDER := 10

static var _cached: Theme


static func font(weight: int = 600) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = load(FONT_PATH) as FontFile
	fv.variation_opentype = {UiTheme.WGHT_TAG: weight}
	return fv


static func box(bg: Color, radius: int = RADIUS, margin: int = 20, border: int = 6, border_color: Color = Color.WHITE,
		shadow: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.content_margin_left = margin + 6
	sb.content_margin_right = margin + 6
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = border_color
	if shadow > 0:
		sb.shadow_color = Color(NAVY_DEEP, 0.35)
		sb.shadow_size = 4
		sb.shadow_offset = Vector2(0, shadow)
	sb.anti_aliasing = true
	return sb


## Botao chunky: `fill` normal, hover mais claro, pressionado afunda (sombra some e o conteudo desce).
static func button_styles(th: Theme, type: StringName, fill: Color, text: Color) -> void:
	var normal := box(fill, RADIUS, 18, 6, Color.WHITE, 10)
	var hover := box(fill.lightened(0.15), RADIUS, 18, 6, Color.WHITE, 10)
	var pressed := box(fill.darkened(0.12), RADIUS, 18, 6, Color.WHITE, 2)
	pressed.content_margin_top += 8
	pressed.content_margin_bottom -= 8
	pressed.expand_margin_top = -8
	pressed.expand_margin_bottom = 0
	var disabled := box(Color("B9C4D0"), RADIUS, 18, 6, Color("E6ECF2"), 4)
	var focus := box(Color.TRANSPARENT, RADIUS + 8, 18, FOCUS_BORDER, ACTION, 0)
	focus.draw_center = false
	focus.set_expand_margin_all(10)
	th.set_stylebox("normal", type, normal)
	th.set_stylebox("hover", type, hover)
	th.set_stylebox("pressed", type, pressed)
	th.set_stylebox("hover_pressed", type, pressed)
	th.set_stylebox("disabled", type, disabled)
	th.set_stylebox("focus", type, focus)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		th.set_color(c, type, text)
	th.set_color("font_disabled_color", type, Color("6F7F90"))
	th.set_color("icon_normal_color", type, Color.WHITE)
	th.set_color("font_outline_color", type, Color(NAVY_DEEP, 0.35 if text == Color.WHITE else 0.0))
	th.set_constant("outline_size", type, 6 if text == Color.WHITE else 0)
	th.set_constant("h_separation", type, 18)
	th.set_font_size("font_size", type, BUTTON_FONT_SIZE)


static func build() -> Theme:
	if _cached != null:
		return _cached
	var th := Theme.new()
	th.default_font = font(600)
	th.default_font_size = FONT_SIZE
	th.set_color("font_color", "Label", NAVY)
	th.set_type_variation("AccentLabel", "Label")
	th.set_color("font_color", "AccentLabel", ORANGE_TEXT)
	th.set_font("font", "AccentLabel", font(700))
	th.set_type_variation("DimLabel", "Label")
	th.set_color("font_color", "DimLabel", MUTED)
	th.set_type_variation("TitleLabel", "Label")
	th.set_font("font", "TitleLabel", font(700))
	th.set_color("font_color", "TitleLabel", NAVY)
	th.set_type_variation("LightLabel", "Label")
	th.set_color("font_color", "LightLabel", Color.WHITE)
	th.set_font("font", "LightLabel", font(700))
	th.set_color("font_outline_color", "LightLabel", NAVY)
	th.set_constant("outline_size", "LightLabel", 10)
	var paper := box(PAPER, RADIUS, 20, 6, NAVY, 8)
	th.set_stylebox("panel", "PanelContainer", paper)
	for v in ["HudPanel", "SubtitlePanel", "ModalPanel"]:
		th.set_type_variation(v, "PanelContainer")
		th.set_stylebox("panel", v, paper)
	th.set_stylebox("panel", "ModalPanel", box(PAPER, 40, 36, 8, GOLD, 12))
	th.set_type_variation("PromptPanel", "PanelContainer")
	th.set_stylebox("panel", "PromptPanel", box(NAVY, 28, 10, 5, Color.WHITE, 6))
	th.set_type_variation("PillPanel", "PanelContainer")
	th.set_stylebox("panel", "PillPanel", box(NAVY, 28, 8, 5, Color.WHITE, 6))
	button_styles(th, &"Button", BLUE, Color.WHITE)
	th.set_font("font", "Button", font(700))
	for pair in [[&"PrimaryButton", ACTION, NAVY], [&"GreenButton", Color("3DBE5A"), Color.WHITE],
			[&"OrangeButton", Color("FF8A1F"), Color.WHITE], [&"QuietButton", PAPER, NAVY]]:
		th.set_type_variation(pair[0], "Button")
		button_styles(th, pair[0], pair[1], pair[2])
	th.set_type_variation("GhostButton", "Button")
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		th.set_stylebox(st, "GhostButton", empty)
	var ghost_focus := box(Color.TRANSPARENT, 64, 0, FOCUS_BORDER, ACTION, 0)
	ghost_focus.draw_center = false
	th.set_stylebox("focus", "GhostButton", ghost_focus)
	# Sliders e caixas de marcar (opcoes)
	var track := box(Color("C9D6E3"), 16, 0, 4, NAVY, 0)
	track.content_margin_top = 14
	track.content_margin_bottom = 14
	var fill := box(BLUE, 16, 0, 4, NAVY, 0)
	fill.content_margin_top = 14
	fill.content_margin_bottom = 14
	th.set_stylebox("slider", "HSlider", track)
	th.set_stylebox("grabber_area", "HSlider", fill)
	th.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var grab := _disc_texture(56, ACTION, NAVY)
	th.set_icon("grabber", "HSlider", grab)
	th.set_icon("grabber_highlight", "HSlider", _disc_texture(64, Color.WHITE, ACTION))
	var focus_slider := box(Color.TRANSPARENT, 24, 0, 8, ACTION, 0)
	focus_slider.draw_center = false
	focus_slider.set_expand_margin_all(14)
	th.set_stylebox("focus", "HSlider", focus_slider)
	th.set_color("accent", "Hud", ACTION)
	th.set_color("text", "Hud", NAVY)
	th.set_color("focus", "Hud", ACTION)
	_cached = th
	return th


static func _disc_texture(d: int, fill: Color, edge: Color) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r := d * 0.5
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - dist, 0.0, 1.0)
			var col := fill if dist < r - 6.0 else edge
			img.set_pixel(x, y, Color(col, a))
	return ImageTexture.create_from_image(img)


## Foco com mola: cresce com overshoot ao receber foco (teclado, controle, mouse). `amount` 0 desliga.
static func springify(c: Control, amount: float = 0.06) -> void:
	c.focus_mode = Control.FOCUS_ALL
	c.resized.connect(func() -> void: c.pivot_offset = c.size * 0.5)
	c.focus_entered.connect(func() -> void: spring_scale(c, 1.0 + amount))
	c.focus_exited.connect(func() -> void: spring_scale(c, 1.0))
	c.mouse_entered.connect(func() -> void:
		if c is BaseButton and not (c as BaseButton).disabled and Input.get_last_mouse_velocity().length() > 1.0:
			c.grab_focus())


static func spring_scale(c: Control, s: float, seconds: float = 0.22) -> void:
	if not c.is_inside_tree() or Options.reduced_motion():
		c.scale = Vector2(s, s)
		return
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(s, s), seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Entrada com mola: aparece de `from` (escala) com overshoot. Respeita movimento reduzido.
static func pop_in(c: Control, from: float = 0.7, seconds: float = 0.35, delay: float = 0.0) -> void:
	c.pivot_offset = c.size * 0.5
	if not c.is_inside_tree() or Options.reduced_motion():
		c.scale = Vector2.ONE
		c.modulate.a = 1.0
		return
	c.scale = Vector2(from, from)
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "scale", Vector2.ONE, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
	tw.tween_property(c, "modulate:a", 1.0, seconds * 0.5).set_delay(delay)
