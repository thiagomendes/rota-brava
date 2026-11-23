class_name Hud
extends CanvasLayer
## HUD do episodio: objetivo, quem controla, acao contextual, legendas, escolha, troca, pausa e conclusao.
## Responde "quem controla, o que posso fazer agora, o que mudou" (SPEC secao 5). Visual PROVISORIO.

signal line_started(key: String)
signal line_finished
signal choice_made(id: StringName)
signal handoff_confirmed
signal replay_requested
signal menu_requested
signal resume_requested
signal skip_requested
signal pause_requested

const MEMBER_COLORS := MemberActor.COLORS
const SKILL_ICONS := {&"tracker": &"notebook", &"climber": &"line", &"pilot": &"helm"}
const HANDOFF_MIN_SECONDS := 0.45
const FONT := 34

var _objective_icon: IconView
var _objective_label: Label
var _member_panel: PanelContainer
var _member_icon: IconView
var _member_label: Label
var _prompt_panel: PanelContainer
var _prompt_icon: IconView
var _prompt_label: Label
var _sub_panel: PanelContainer
var _sub_speaker: Label
var _sub_text: Label
var _skip_label: Label
var _choice_panel: PanelContainer
var _choice_box: VBoxContainer
var _choice_title: Label
var _handoff_panel: Control
var _handoff_icon: IconView
var _handoff_text: Label
var _handoff_button: Button
var _handoff_since: float = 0.0
var _complete_panel: Control
var _complete_replay: Button
var _pause_panel: Control
var _pause_resume: Button
var _queue: Array[Dictionary] = []
var _speaking: bool = false
var _skip_current: bool = false
var _hint_active: bool = false
var choice_open: bool = false
var handoff_open: bool = false
var pause_open: bool = false
var complete_open: bool = false


func _ready() -> void:
	name = "Hud"
	layer = 10
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_objective(root)
	_build_member(root)
	_build_prompt(root)
	_build_subtitle(root)
	_build_choice(root)
	_build_handoff(root)
	_build_complete(root)
	_build_pause(root)


# ---------- construcao ----------

func _panel(parent: Node, color: Color = Color(0.04, 0.1, 0.13, 0.82)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(14)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


## Ancora o controle num ponto relativo a tela (ax, ay em 0..1) com deslocamento em pixels; cresce para os lados indicados.
func _anchor(c: Control, ax: float, ay: float, ox: float, oy: float, grow_h: Control.GrowDirection, grow_v: Control.GrowDirection) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = ox
	c.offset_right = ox
	c.offset_top = oy
	c.offset_bottom = oy
	c.grow_horizontal = grow_h
	c.grow_vertical = grow_v


func _label(parent: Node, size: int = FONT, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, width: float = 520.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 88)
	b.add_theme_font_size_override("font_size", 40)
	parent.add_child(b)
	return b


func _build_objective(root: Control) -> void:
	var p := _panel(root)
	p.name = "ObjectivePanel"
	p.set_anchors_preset(Control.PRESET_TOP_LEFT)
	p.position = Vector2(32, 28)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	_objective_icon = IconView.new()
	_objective_icon.custom_minimum_size = Vector2(72, 72)
	h.add_child(_objective_icon)
	_objective_label = _label(h, 32)
	_objective_label.custom_minimum_size = Vector2(620, 0)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _build_member(root: Control) -> void:
	_member_panel = _panel(root)
	_member_panel.name = "MemberPanel"
	_anchor(_member_panel, 1.0, 0.0, -32.0, 28.0, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	_member_panel.add_child(h)
	_member_icon = IconView.new()
	_member_icon.custom_minimum_size = Vector2(72, 72)
	h.add_child(_member_icon)
	_member_label = _label(h, 34)
	_member_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_member_panel.visible = false


func _build_prompt(root: Control) -> void:
	_prompt_panel = _panel(root, Color(0.1, 0.07, 0.02, 0.9))
	_prompt_panel.name = "PromptPanel"
	_anchor(_prompt_panel, 0.5, 1.0, 0.0, -230.0, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	_prompt_panel.add_child(h)
	_prompt_icon = IconView.new()
	_prompt_icon.custom_minimum_size = Vector2(84, 84)
	_prompt_icon.color = Color("ffd24d")
	h.add_child(_prompt_icon)
	var v := VBoxContainer.new()
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(v)
	_prompt_label = _label(v, 42, Color("ffd24d"))
	var hint := _label(v, 26, Color(1, 1, 1, 0.8))
	hint.name = "KeyHint"
	hint.text = Loc.t("ui.control.interact")
	_prompt_panel.visible = false


func _build_subtitle(root: Control) -> void:
	_sub_panel = _panel(root, Color(0, 0, 0, 0.78))
	_sub_panel.name = "SubtitlePanel"
	_anchor(_sub_panel, 0.5, 1.0, 0.0, -40.0, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)
	var v := VBoxContainer.new()
	_sub_panel.add_child(v)
	_sub_speaker = _label(v, 30, Color("ffd24d"))
	_sub_text = _label(v, FONT)
	_sub_text.custom_minimum_size = Vector2(1100, 0)
	_sub_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub_panel.visible = false
	_skip_label = _label(root, 30)
	_skip_label.name = "SkipHint"
	_skip_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_skip_label.position = Vector2(40, 160)
	_skip_label.text = Loc.t("ui.skip")
	_skip_label.visible = false


func _build_choice(root: Control) -> void:
	_choice_panel = _panel(root, Color(0.04, 0.1, 0.13, 0.94))
	_choice_panel.name = "ChoicePanel"
	_choice_panel.set_anchors_preset(Control.PRESET_CENTER)
	_choice_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_choice_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_choice_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 20)
	_choice_panel.add_child(_choice_box)
	_choice_title = _label(_choice_box, 38)
	_choice_title.custom_minimum_size = Vector2(760, 0)
	_choice_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_choice_panel.visible = false


func _overlay(root: Control, name_: String) -> Control:
	var c := Control.new()
	c.name = name_
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(dim)
	root.add_child(c)
	c.visible = false
	return c


func _centered_box(overlay: Control) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 24)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)
	return v


func _build_handoff(root: Control) -> void:
	_handoff_panel = _overlay(root, "HandoffOverlay")
	(_handoff_panel.get_child(0) as ColorRect).color = Color(0, 0, 0, 0.35)
	var v := _centered_box(_handoff_panel)
	v.position.y = 200
	var p := _panel(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	p.add_child(h)
	_handoff_icon = IconView.new()
	_handoff_icon.custom_minimum_size = Vector2(120, 120)
	h.add_child(_handoff_icon)
	_handoff_text = _label(h, 38)
	_handoff_text.custom_minimum_size = Vector2(760, 0)
	_handoff_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_handoff_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_handoff_button = _button(v, Loc.t("ui.menu.confirm"), 420)
	_handoff_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_handoff_button.pressed.connect(_confirm_handoff)


func _build_complete(root: Control) -> void:
	_complete_panel = _overlay(root, "CompleteOverlay")
	var v := _centered_box(_complete_panel)
	var title := _label(v, 84, Color("ffd24d"))
	title.name = "Title"
	title.text = Loc.t("ep01.complete.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body := _label(v, 40)
	body.name = "Body"
	body.text = Loc.t("ep01.complete.body")
	body.custom_minimum_size = Vector2(1000, 0)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_complete_replay = _button(v, Loc.t("ui.menu.review"))
	_complete_replay.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_complete_replay.pressed.connect(func() -> void: replay_requested.emit())
	var menu := _button(v, Loc.t("ui.menu.menu"))
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu.pressed.connect(func() -> void: menu_requested.emit())


func _build_pause(root: Control) -> void:
	_pause_panel = _overlay(root, "PauseOverlay")
	var v := _centered_box(_pause_panel)
	var title := _label(v, 76, Color("ffd24d"))
	title.text = Loc.t("ui.pause.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_resume = _button(v, Loc.t("ui.pause.resume"))
	_pause_resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_pause_resume.pressed.connect(func() -> void: resume_requested.emit())
	var menu := _button(v, Loc.t("ui.menu.menu"))
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu.pressed.connect(func() -> void: menu_requested.emit())


# ---------- objetivo, integrante e acao contextual ----------

func set_objective(text: String, icon: StringName) -> void:
	_objective_label.text = Loc.t("ui.hud.objective", {"text": text})
	_objective_icon.kind = icon


func set_member(member: StringName) -> void:
	if member == &"":
		_member_panel.visible = false
		return
	_member_panel.visible = true
	_member_icon.kind = SKILL_ICONS.get(member, &"notebook")
	_member_icon.color = MEMBER_COLORS.get(member, Color.WHITE)
	_member_label.text = Loc.t("ui.hud.controls_label", {"name": Loc.member_name(member)})


func show_prompt(label: String, icon: StringName) -> void:
	_prompt_label.text = label
	_prompt_icon.kind = icon
	_prompt_panel.visible = true


func hide_prompt() -> void:
	_prompt_panel.visible = false


func prompt_visible() -> bool:
	return _prompt_panel.visible


func prompt_text() -> String:
	return _prompt_label.text


func set_skip_hint(on: bool) -> void:
	_skip_label.visible = on


# ---------- legendas ----------

func speaker_name_for(key: String) -> String:
	var parts := key.split(".")
	if parts.size() >= 3:
		var who := parts[2]
		var name_key := "member.%s.name" % who
		if Loc.has_key(name_key):
			return Loc.t(name_key)
	return ""


func say(key: String, params: Dictionary = {}, is_hint: bool = false) -> void:
	_queue.append({"key": key, "params": params, "hint": is_hint})
	if not _speaking:
		_pump()


## Fala varias chaves em sequencia e retorna quando a ultima terminar.
func say_all(keys: Array[String]) -> void:
	for k in keys:
		say(k)
	await wait_silent()


## Retorna quando nao ha mais fala na fila nem em exibicao.
func wait_silent() -> void:
	while is_speaking():
		if not is_inside_tree():
			return
		await get_tree().process_frame


func is_speaking() -> bool:
	return _speaking or not _queue.is_empty()


func skip_line() -> void:
	_skip_current = true


func clear_speech(only_hints: bool = false) -> void:
	if only_hints:
		_queue = _queue.filter(func(e: Dictionary) -> bool: return not e["hint"])
		if _hint_active:
			_skip_current = true
	else:
		_queue.clear()
		_skip_current = true


func _pump() -> void:
	_speaking = true
	while not _queue.is_empty():
		var entry: Dictionary = _queue.pop_front()
		var text := Loc.t(String(entry["key"]), entry["params"])
		_sub_speaker.text = speaker_name_for(String(entry["key"]))
		_sub_speaker.visible = not _sub_speaker.text.is_empty()
		_sub_text.text = text
		_sub_panel.visible = true
		_hint_active = bool(entry["hint"])
		_skip_current = false
		line_started.emit(String(entry["key"]))
		var seconds := maxf(2.4, 1.3 + 0.055 * text.length())
		var t := 0.0
		while t < seconds and not _skip_current:
			await get_tree().process_frame
			if not is_inside_tree():
				return
			if not pause_open:
				t += get_process_delta_time()
		_hint_active = false
		line_finished.emit()
	_sub_panel.visible = false
	_speaking = false


# ---------- escolha ----------

## options: [{id, label, icon}]. Emite choice_made(id); cancelar emite &"".
func open_choice(title: String, options: Array[Dictionary]) -> void:
	for child in _choice_box.get_children():
		if child != _choice_title:
			child.queue_free()
	_choice_title.text = title
	var first: Button = null
	for o in options:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var icon := IconView.new()
		icon.kind = StringName(o.get("icon", "bank"))
		icon.custom_minimum_size = Vector2(88, 88)
		row.add_child(icon)
		var b := _button(row, String(o["label"]), 560)
		var id := StringName(o["id"])
		b.pressed.connect(func() -> void: _pick(id))
		_choice_box.add_child(row)
		if first == null:
			first = b
	_choice_panel.visible = true
	choice_open = true
	if first:
		first.grab_focus()


func close_choice() -> void:
	_choice_panel.visible = false
	choice_open = false


func _pick(id: StringName) -> void:
	close_choice()
	choice_made.emit(id)


# ---------- troca de integrante ----------

func open_handoff(text: String, member: StringName) -> void:
	_handoff_icon.kind = SKILL_ICONS.get(member, &"notebook")
	_handoff_icon.color = MEMBER_COLORS.get(member, Color.WHITE)
	_handoff_text.text = text
	_handoff_panel.visible = true
	handoff_open = true
	_handoff_since = Time.get_ticks_msec() / 1000.0
	_handoff_button.grab_focus()


func _confirm_handoff() -> void:
	if not handoff_open:
		return
	if Time.get_ticks_msec() / 1000.0 - _handoff_since < HANDOFF_MIN_SECONDS:
		return
	handoff_open = false
	_handoff_panel.visible = false
	handoff_confirmed.emit()


# ---------- pausa e conclusao ----------

func open_pause() -> void:
	pause_open = true
	_pause_panel.visible = true
	_pause_resume.grab_focus()


func close_pause() -> void:
	pause_open = false
	_pause_panel.visible = false


func open_complete() -> void:
	complete_open = true
	_complete_panel.visible = true
	_complete_replay.grab_focus()


func close_complete() -> void:
	complete_open = false
	_complete_panel.visible = false


# ---------- entrada ----------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed(&"pause") and not choice_open and not complete_open:
		get_viewport().set_input_as_handled()
		if pause_open:
			resume_requested.emit()
		else:
			pause_requested.emit()
	elif choice_open and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_pick(&"")
	elif handoff_open and event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		_confirm_handoff()
	elif event.is_action_pressed(&"ui_accept") and not choice_open and not handoff_open \
			and not pause_open and not complete_open and _speaking:
		skip_line()
