class_name OptionsPanel
extends PanelContainer
## Painel de opcoes funcional (RB-R1): Voltar no topo (foco inicial), volumes por bus, tamanho da legenda,
## movimento reduzido e assistencia de pilotagem. Cada mudanca salva em user://options.cfg.

const BUS_KEYS := {"Master": "ui.options.bus.master", "Voz": "ui.options.bus.voz", "Musica": "ui.options.bus.musica",
	"Efeitos": "ui.options.bus.efeitos", "Ambiente": "ui.options.bus.ambiente"}
const SIZE_KEYS: Array[String] = ["ui.options.size.0", "ui.options.size.1", "ui.options.size.2"]

signal back_requested
## G12: "Rever abertura" (so no menu principal; a pausa do jogo nao mostra o botao).
signal intro_requested
signal ui_sound(name: StringName)

var back_button: Button
var sliders: Dictionary = {}
var size_buttons: Array[Button] = []
var motion_check: CheckButton
var assist_check: CheckButton
var intro_button: Button
var _right: VBoxContainer


func _init() -> void:
	name = "OptionsPanel"
	theme_type_variation = &"ModalPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	v.add_child(head)
	back_button = Button.new()
	back_button.name = "BackButton"
	back_button.text = Loc.t("ui.menu.back")
	back_button.icon = IconView.texture_for(&"home")
	back_button.expand_icon = true
	back_button.theme_type_variation = &"QuietButton"
	back_button.custom_minimum_size = Vector2(300, 128)
	ThemeV2.springify(back_button)
	back_button.pressed.connect(func() -> void:
		ui_sound.emit(&"back")
		back_requested.emit())
	head.add_child(back_button)
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = Loc.t("ui.menu.options")
	title.add_theme_font_size_override("font_size", 64)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 56)
	v.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	cols.add_child(left)
	for bus in Options.BUSES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		left.add_child(row)
		var l := Label.new()
		l.text = Loc.t(BUS_KEYS[bus])
		l.custom_minimum_size = Vector2(230, 0)
		row.add_child(l)
		var s := HSlider.new()
		s.name = "Volume" + bus
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.1
		s.custom_minimum_size = Vector2(420, 96)
		s.value = float(Options.get_value("audio", bus))
		s.focus_mode = Control.FOCUS_ALL
		s.value_changed.connect(func(val: float) -> void:
			Options.set_value("audio", bus, val)
			ui_sound.emit(&"tick"))
		row.add_child(s)
		sliders[bus] = s
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 16)
	cols.add_child(right)
	_right = right
	var sl := Label.new()
	sl.text = Loc.t("ui.options.subtitle_size")
	right.add_child(sl)
	var sizes := HBoxContainer.new()
	sizes.add_theme_constant_override("separation", 14)
	right.add_child(sizes)
	var group := ButtonGroup.new()
	for i in 3:
		var b := Button.new()
		b.name = "SubtitleSize%d" % i
		b.toggle_mode = true
		b.button_group = group
		b.text = Loc.t(SIZE_KEYS[i])
		b.add_theme_font_size_override("font_size", int(30 * Options.SUBTITLE_SCALES[i]))
		b.custom_minimum_size = Vector2(150, 128)
		b.button_pressed = int(Options.get_value("access", "subtitle_size")) == i
		ThemeV2.springify(b)
		var level := i
		b.pressed.connect(func() -> void:
			Options.set_value("access", "subtitle_size", level)
			ui_sound.emit(&"select"))
		sizes.add_child(b)
		size_buttons.append(b)
	motion_check = _check(right, "ReducedMotion", "ui.options.reduced_motion", "reduced_motion")
	assist_check = _check(right, "SteeringAssist", "ui.options.steering_assist", "steering_assist")


func _check(parent: Control, node_name: String, key: String, opt: String) -> CheckButton:
	var c := CheckButton.new()
	c.name = node_name
	c.text = Loc.t(key)
	c.theme_type_variation = &"QuietButton"
	c.custom_minimum_size = Vector2(500, 128)
	c.button_pressed = bool(Options.get_value("access", opt))
	ThemeV2.springify(c, 0.03)
	c.toggled.connect(func(on: bool) -> void:
		Options.set_value("access", opt, on)
		ui_sound.emit(&"select"))
	parent.add_child(c)
	return c


## G12: acrescenta "Rever abertura" no fim da coluna da direita (o menu principal chama; a pausa nao).
func add_intro_button() -> Button:
	if intro_button != null:
		return intro_button
	intro_button = Button.new()
	intro_button.name = "ReplayIntroButton"
	intro_button.text = Loc.t("ui.options.replay_intro")
	intro_button.icon = IconView.texture_for(&"storybook")
	intro_button.expand_icon = true
	intro_button.add_theme_constant_override("icon_max_width", 72)
	intro_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	intro_button.theme_type_variation = &"QuietButton"
	intro_button.custom_minimum_size = Vector2(500, 128)
	ThemeV2.springify(intro_button, 0.03)
	intro_button.pressed.connect(func() -> void:
		ui_sound.emit(&"confirm")
		intro_requested.emit())
	_right.add_child(intro_button)
	return intro_button


func open() -> void:
	visible = true
	ThemeV2.pop_in(self, 0.85)
	back_button.grab_focus()
