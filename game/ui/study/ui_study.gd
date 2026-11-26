class_name UiStudy
extends Control
## Estudo de HUD e tipografia (RB-03). Mostra o HUD real (Hud) com o tema candidato A/B/C.
## Controles: move_left/move_right trocam A/B/C; ui_page_up/ui_page_down trocam a tela; Esc volta.
## Argumentos para captura: --study-option=a|b|c  --study-screen=N (0..)  --study-tour (avanca uma tela a cada TOUR_FRAMES quadros).

signal closed

const SCREENS: Array[StringName] = [&"hud", &"long", &"accents", &"choice", &"handoff", &"complete", &"pause", &"icons"]
const ICON_KINDS: Array[StringName] = [&"notebook", &"line", &"helm", &"paw", &"boot"]
const ICON_KEYS := {&"notebook": "study.icon.notebook", &"line": "study.icon.line", &"helm": "study.icon.helm", &"paw": "study.icon.paw", &"boot": "study.icon.boot"}
const TOUR_FRAMES := 5

var hud: Hud
var option: StringName = &"a"
var screen_index: int = 0
var tour: bool = false
var _caption: Label
var _icons_panel: PanelContainer
var _frame: int = 0
var _resay_at: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := _Backdrop.new()
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	hud = Hud.new()
	add_child(hud)
	_caption = Label.new()
	_caption.name = "Caption"
	_caption.add_theme_font_size_override("font_size", 24)
	_caption.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_caption.offset_top = 8
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	_build_icons()
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--study-option="):
			option = StringName(arg.trim_prefix("--study-option="))
		elif arg.begins_with("--study-screen="):
			screen_index = clampi(int(arg.trim_prefix("--study-screen=")), 0, SCREENS.size() - 1)
		elif arg == "--study-tour":
			tour = true
	set_option(option)
	show_screen(screen_index)


func set_option(o: StringName) -> void:
	option = o
	var th := load("res://ui/study/theme_%s.tres" % o) as Theme
	theme = th
	hud.apply_theme(th)
	_icons_panel.theme = th
	_update_caption()


func _update_caption() -> void:
	var key := "study.screen." + String(SCREENS[screen_index])
	_caption.text = Loc.t("study.caption", {"option": UiTheme.NAMES[option], "screen": screen_index + 1,
		"total": SCREENS.size(), "name": Loc.t(key)})


func _build_icons() -> void:
	_icons_panel = PanelContainer.new()
	_icons_panel.name = "IconsPanel"
	_icons_panel.theme_type_variation = &"HudPanel"
	_icons_panel.set_anchors_preset(Control.PRESET_CENTER)
	_icons_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_icons_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_icons_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icons_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	_icons_panel.add_child(v)
	for size_px in [150, 48]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 28)
		v.add_child(row)
		for kind in ICON_KINDS:
			var col := VBoxContainer.new()
			col.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_child(col)
			var icon := IconView.new()
			icon.kind = kind
			icon.custom_minimum_size = Vector2(size_px, size_px)
			icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			col.add_child(icon)
			if size_px > 100:
				var l := Label.new()
				l.text = Loc.t(ICON_KEYS[kind])
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				col.add_child(l)
	_icons_panel.visible = false


func show_screen(i: int) -> void:
	screen_index = posmod(i, SCREENS.size())
	hud.clear_speech()
	hud.hide_prompt()
	hud.close_choice()
	hud.close_pause()
	hud.close_complete()
	hud.close_handoff()
	hud.set_member(&"")
	hud.set_skip_hint(false)
	_icons_panel.visible = false
	var screen := SCREENS[screen_index]
	match screen:
		&"hud":
			hud.set_objective(Loc.t("study.objective.normal"), &"notebook")
			hud.set_member(&"tracker")
			hud.show_prompt(Loc.t("ui.action.examine"), &"paw")
		&"long":
			hud.set_objective(Loc.t("study.objective.long"), &"boot")
			hud.set_member(&"climber")
			hud.show_prompt(Loc.t("ui.action.examine"), &"paw")
		&"accents":
			hud.set_objective(Loc.t("study.objective.accents"), &"helm")
			hud.set_member(&"pilot")
			hud.show_prompt(Loc.t("study.prompt.accents"), &"paw")
		&"choice":
			hud.set_objective(Loc.t("study.objective.normal"), &"notebook")
			hud.set_member(&"tracker")
			var opts: Array[Dictionary] = [
				{"id": &"bank", "label": Loc.t("study.choice.bank"), "icon": &"bank"},
				{"id": &"harbor", "label": Loc.t("study.choice.harbor"), "icon": &"harbor"}]
			hud.open_choice(Loc.t("study.choice.title"), opts)
		&"handoff":
			hud.set_objective(Loc.t("study.objective.normal"), &"line")
			hud.open_handoff(Loc.t("study.handoff.text"), &"climber")
		&"complete":
			hud.set_objective(Loc.t("study.objective.normal"), &"notebook")
			hud.open_complete()
		&"pause":
			hud.set_objective(Loc.t("study.objective.normal"), &"notebook")
			hud.set_member(&"tracker")
			hud.open_pause()
		&"icons":
			hud.set_objective(Loc.t("study.objective.normal"), &"notebook")
			_icons_panel.visible = true
	_say_for(screen)
	_update_caption()


func _say_for(screen: StringName) -> void:
	match screen:
		&"hud":
			hud.say("study.sub.tracker.normal")
		&"long":
			hud.say("study.sub.tracker.long")
		&"accents":
			hud.say("study.sub.pilot.accents")


func _process(delta: float) -> void:
	_frame += 1
	if tour and _frame % TOUR_FRAMES == 0 and screen_index < SCREENS.size() - 1:
		show_screen(screen_index + 1)
		return
	# Repete a legenda para a tela poder ser observada sem pressa.
	if not tour and not hud.is_speaking() and SCREENS[screen_index] in [&"hud", &"long", &"accents"]:
		_resay_at += delta
		if _resay_at > 0.8:
			_resay_at = 0.0
			_say_for(SCREENS[screen_index])


func _input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed():
		return
	if event.is_action_pressed(&"move_right"):
		set_option(UiTheme.OPTIONS[(UiTheme.OPTIONS.find(option) + 1) % 3])
	elif event.is_action_pressed(&"move_left"):
		set_option(UiTheme.OPTIONS[(UiTheme.OPTIONS.find(option) + 2) % 3])
	elif event.is_action_pressed(&"ui_page_down"):
		show_screen(screen_index + 1)
	elif event.is_action_pressed(&"ui_page_up"):
		show_screen(screen_index - 1)
	elif event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		leave()
		return
	else:
		return
	get_viewport().set_input_as_handled()


func leave() -> void:
	closed.emit()
	if get_tree().current_scene == self:
		SceneLoaderService.go("res://ui/main_menu.tscn")


## Fundo provisorio: ceu, agua, tabuas do cais e tres figuras e o barco amarelo no centro, para ver se a UI cobre a acao.
class _Backdrop extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h * 0.45), Color("a9c8c2"))
		draw_rect(Rect2(0, h * 0.45, w, h * 0.55), Color("2f7f84"))
		draw_rect(Rect2(0, h * 0.62, w, h * 0.38), Color("7a6a55"))
		for i in 14:
			draw_line(Vector2(0, h * 0.62 + i * h * 0.03), Vector2(w, h * 0.62 + i * h * 0.03), Color("5c4e3d"), 3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.55, h * 0.38), Vector2(w * 0.85, h * 0.38),
			Vector2(w * 0.8, h * 0.48), Vector2(w * 0.6, h * 0.48)]), Color("f2c230"))
		for k in 3:
			var x := w * (0.36 + 0.07 * k)
			draw_rect(Rect2(x - 22, h * 0.44, 44, h * 0.2), [Color("e07a5f"), Color("3d405b"), Color("81b29a")][k])
			draw_circle(Vector2(x, h * 0.41), 30, Color("f2cc8f"))


