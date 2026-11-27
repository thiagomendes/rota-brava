class_name TouchControls
extends CanvasLayer
## RB-M1 (PROVISORIO, UX infantil): controle por toque basico do episodio, numa camada acima do HUD.
## - So aparece depois do primeiro toque na tela e some quando chega teclado, mouse real ou controle (`InputDevice`).
## - Some tambem quando um painel bloqueia (troca de heroi, escolha, pausa, opcoes, conclusao, cena: `MouseLock`).
## - Metade esquerda: joystick flutuante (nasce onde o dedo toca); aciona `move_*` com forca analogica e `run` acima de
##   RUN_AT do raio. Metade direita fora dos botoes: arrastar gira a camera (`CameraRig.orbit_by`, a mesma do mouse).
## - Botoes grandes a direita, com icone e sem texto: agir (`interact`, embaixo, no lugar do botao de acao do HUD) e
##   pular (`jump`). Pausa (`pause`) pequena no alto, a esquerda dos retratos. A ajuda e o botao do proprio HUD.
## - Multitoque: cada dedo (indice) tem um dono (joystick, camera ou botao); dois dedos andam e giram ao mesmo tempo.
## Nada de entrada direta: tudo vira intencao da Input Map (os botoes injetam InputEventAction, o joystick usa
## `Input.action_press(acao, forca)`). Layout em unidades logicas (viewport 1080 de altura, stretch canvas_items/expand).

signal shown_changed(on: bool)

const LAYER := 11
const STICK_RADIUS := 130.0
const KNOB_RADIUS := 64.0
## Abaixo disto (fracao do raio) o joystick nao anda; acima de RUN_AT corre (volta a andar abaixo de RUN_OFF).
const STICK_DEAD := 0.12
const RUN_AT := 0.85
const RUN_OFF := 0.78
## O joystick arrasta a base junto quando o dedo passa deste multiplo do raio.
const STICK_FOLLOW := 1.25
const ACT_RADIUS := 112.0
const JUMP_RADIUS := 90.0
const PAUSE_RADIUS := 60.0
## Alvo de toque um pouco maior que o desenho (dedo de crianca).
const HIT_GROW := 1.15
const GAP := 30.0
## Espaco vertical entre agir e pular, onde fica o rotulo da acao ("Examinar").
const LABEL_ROOM := 86.0
const TOUCH_YAW_SENS := 0.0055
const TOUCH_PITCH_SENS := 0.0035
## Dica de camera (setas curvas) no lado direito ao aparecer pela primeira vez, em segundos.
const CAM_HINT_SECONDS := 4.0
const ICON_DIR := "res://ui/touch/icons/"
const MOVES: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]

const NAVY := Color("0B2440")
const YELLOW := Color("FFD23A")
const CORAL := Color("E2453A")
const PAPER := Color("F7FBFF")

var main: Ep01V3Main
var hud: Hud
var camera: CameraRig
## Toque e o ultimo dispositivo (a camada quer aparecer); `visible` tambem desconta os bloqueios.
var touch_active: bool = false
## Joystick: vetor em fracao do raio (comprimento 0..1), origem e ponta (px logicos).
var stick_vector: Vector2 = Vector2.ZERO
var stick_origin: Vector2 = Vector2.ZERO
var stick_tip: Vector2 = Vector2.ZERO
var running: bool = false
var reduced_motion: bool = false
## Dedo -> {"kind": &"stick"|&"cam"|&"act"|&"jump"|&"pause", "pos": Vector2}
var _fingers: Dictionary = {}
var _pressed_moves: Dictionary = {}
var _canvas: Control
var _label_pill: PanelContainer
var _label: Label
var _tex: Dictionary = {}
var _clock: float = 0.0
var _cam_hint_left: float = 0.0
var _cam_hint_done: bool = false
var _seen_device: StringName = &""


func setup(p_main: Ep01V3Main) -> void:
	main = p_main
	hud = main.hud
	camera = main.camera_rig


func _ready() -> void:
	name = "TouchControls"
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	reduced_motion = Options.reduced_motion()
	for k in ["jump", "hand", "stick_base", "stick_knob", "cam_turn"]:
		_tex[k] = load(ICON_DIR + k + ".svg") as Texture2D
	_tex["pause"] = IconView.texture_for(&"pause")
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)
	if hud != null and hud.ui_theme != null:
		_canvas.theme = hud.ui_theme
	_label_pill = PanelContainer.new()
	_label_pill.name = "ActLabel"
	_label_pill.theme_type_variation = &"PillPanel"
	_label_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_label_pill)
	_label = Label.new()
	_label.theme_type_variation = &"LightLabel"
	_label.add_theme_font_size_override("font_size", 36)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_pill.add_child(_label)
	_label_pill.visible = false
	visible = false
	stick_origin = stick_home()
	stick_tip = stick_origin


# ---------- layout (px logicos) ----------

func view_size() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1920, 1080)


## Margens: as do HUD (5% do lado, minimo 48) ou o recorte do aparelho (entalhe/barra), o que for maior.
func margins() -> Vector2:
	var vp := view_size()
	var m := Hud.safe_margins(vp)
	if OS.has_feature("mobile") and is_inside_tree():
		var win := DisplayServer.window_get_size()
		var safe := DisplayServer.get_display_safe_area()
		if win.x > 0 and win.y > 0 and safe.size.x > 0:
			var k := vp / Vector2(win)
			var left := float(safe.position.x) * k.x
			var top := float(safe.position.y) * k.y
			var right := float(win.x - safe.end.x) * k.x
			var bottom := float(win.y - safe.end.y) * k.y
			m = Vector2(maxf(m.x, maxf(left, right)), maxf(m.y, maxf(top, bottom)))
	return m


func act_center() -> Vector2:
	var vp := view_size()
	var m := margins()
	return Vector2(vp.x - m.x - ACT_RADIUS, vp.y - m.y - ACT_RADIUS)


## Pular: acima do agir (o polegar sobe), com folga para o rotulo da acao entre os dois. Na diagonal o rotulo
## cobria o pular e o pular encostava no balao de legenda (captura de 2026-11-27).
func jump_center() -> Vector2:
	return act_center() + Vector2(-12.0, -(ACT_RADIUS + JUMP_RADIUS + LABEL_ROOM))


## Pausa: no alto, a esquerda dos retratos do HUD (ou no canto se nao ha retratos).
func pause_center() -> Vector2:
	var vp := view_size()
	var m := margins()
	var right := vp.x - m.x
	if hud != null and hud._member_panel != null and hud._member_panel.visible:
		right = minf(right, hud._member_panel.get_global_rect().position.x - GAP)
	return Vector2(right - PAUSE_RADIUS, m.y + PAUSE_RADIUS)


## Onde o joystick descansa (fantasma) e volta ao soltar.
func stick_home() -> Vector2:
	var vp := view_size()
	var m := margins()
	return Vector2(m.x + STICK_RADIUS + 20.0, vp.y - m.y - STICK_RADIUS - 10.0)


func _clamp_stick(p: Vector2) -> Vector2:
	var vp := view_size()
	var m := margins()
	var lo := m + Vector2(STICK_RADIUS, STICK_RADIUS) * 0.6
	var hi := Vector2(vp.x * 0.5 - STICK_RADIUS * 0.6, vp.y - m.y - STICK_RADIUS * 0.6)
	return Vector2(clampf(p.x, lo.x, maxf(lo.x, hi.x)), clampf(p.y, lo.y, maxf(lo.y, hi.y)))


func button_at(p: Vector2) -> StringName:
	if p.distance_to(act_center()) <= ACT_RADIUS * HIT_GROW:
		return &"act"
	if p.distance_to(jump_center()) <= JUMP_RADIUS * HIT_GROW:
		return &"jump"
	if p.distance_to(pause_center()) <= maxf(PAUSE_RADIUS * HIT_GROW, 64.0):
		return &"pause"
	return &""


## Botoes do HUD que continuam sendo da GUI (o dedo neles nao vira joystick nem camera).
func _hud_owns(p: Vector2) -> bool:
	if hud == null:
		return false
	for c: Control in hud.touch_passthrough():
		if c.is_visible_in_tree() and c.get_global_rect().has_point(p):
			return true
	return false


# ---------- estado ----------

## A camada fica escondida (e solta tudo) com painel aberto, pausa ou cena.
func suppressed() -> bool:
	if MouseLock.blocked() or (is_inside_tree() and get_tree().paused):
		return true
	return main != null and (main.cutscene_blocks_look() or main.controlled_node == null)


func _refresh() -> void:
	touch_active = InputDevice.last == InputDevice.TOUCH
	var want := touch_active and not suppressed()
	if hud != null:
		hud.set_touch_mode(touch_active)
		if InputDevice.last != _seen_device:
			hud.sync_device()
	_seen_device = InputDevice.last
	if want == visible:
		return
	visible = want
	if not want:
		release_all()
	elif not _cam_hint_done:
		_cam_hint_done = true
		_cam_hint_left = CAM_HINT_SECONDS
	_canvas.queue_redraw()
	shown_changed.emit(want)


func _process(delta: float) -> void:
	_clock += delta
	_refresh()
	if not visible:
		return
	_cam_hint_left = maxf(0.0, _cam_hint_left - delta)
	_update_label()
	_canvas.queue_redraw()


func _update_label() -> void:
	var on := hud != null and hud.prompt_visible() and hud.prompt_text() != ""
	_label_pill.visible = on
	if not on:
		return
	_label.text = hud.prompt_text()
	_label_pill.reset_size()
	var s := _label_pill.size
	var c := act_center()
	_label_pill.position = Vector2(minf(c.x - s.x * 0.5, view_size().x - margins().x - s.x), c.y - ACT_RADIUS - 8.0 - s.y)


## Solta tudo o que a camada segurava (ao esconder, ao sair da cena).
func release_all() -> void:
	for i: int in _fingers.keys():
		var f: Dictionary = _fingers[i]
		if f["kind"] == &"jump":
			_send(&"jump", false)
	_fingers.clear()
	_set_stick(Vector2.ZERO)
	stick_origin = stick_home()
	stick_tip = stick_origin
	if _canvas != null:
		_canvas.queue_redraw()


func _exit_tree() -> void:
	release_all()
	if hud != null and is_instance_valid(hud):
		hud.set_touch_mode(false)


# ---------- entrada ----------

func _input(event: InputEvent) -> void:
	InputDevice.note(event)
	var touch := event is InputEventScreenTouch or event is InputEventScreenDrag
	if not touch:
		if not (event is InputEventAction):
			_refresh()
		return
	_refresh()
	if not visible:
		_tap_skips_cutscene(event)
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if _begin(t.index, t.position):
				get_viewport().set_input_as_handled()
		elif _fingers.has(t.index):
			_end(t.index)
			get_viewport().set_input_as_handled()
	else:
		var d := event as InputEventScreenDrag
		if _fingers.has(d.index):
			_move(d.index, d.position)
			get_viewport().set_input_as_handled()


## Na cena (camada escondida), um toque pula a cena como o E (so se ela for pulavel).
func _tap_skips_cutscene(event: InputEvent) -> void:
	if main == null or main.cutscene == null or not main.cutscene.playing or not main.cutscene.skippable:
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_send(&"interact", true)
		_send(&"interact", false)


func _begin(index: int, p: Vector2) -> bool:
	if _fingers.has(index):
		_end(index)
	var b := button_at(p)
	if b == &"" and _hud_owns(p):
		return false
	match b:
		&"act":
			hud.trigger_action()
		&"jump":
			_send(&"jump", true)
		&"pause":
			_send(&"pause", true)
			_send(&"pause", false)
		_:
			if p.x < view_size().x * 0.5:
				if _has_kind(&"stick"):
					return true  # segundo dedo na esquerda: ignorado, mas nao vaza para a GUI
				b = &"stick"
				stick_origin = _clamp_stick(p)
				stick_tip = stick_origin
				_move_stick(p)
			else:
				b = &"cam"
				_cam_hint_left = 0.0
	_fingers[index] = {"kind": b, "pos": p}
	_canvas.queue_redraw()
	return true


func _move(index: int, p: Vector2) -> void:
	var f: Dictionary = _fingers[index]
	var prev: Vector2 = f["pos"]
	f["pos"] = p
	match f["kind"]:
		&"stick":
			_move_stick(p)
		&"cam":
			if camera != null and camera.orbit_enabled:
				camera.orbit_by(p - prev, TOUCH_YAW_SENS, TOUCH_PITCH_SENS)
	_canvas.queue_redraw()


func _end(index: int) -> void:
	var f: Dictionary = _fingers[index]
	_fingers.erase(index)
	match f["kind"]:
		&"stick":
			_set_stick(Vector2.ZERO)
			stick_origin = stick_home()
			stick_tip = stick_origin
		&"jump":
			_send(&"jump", false)
	_canvas.queue_redraw()


func _has_kind(kind: StringName) -> bool:
	for i: int in _fingers:
		if (_fingers[i] as Dictionary)["kind"] == kind:
			return true
	return false


func finger_kind(index: int) -> StringName:
	return (_fingers[index] as Dictionary)["kind"] if _fingers.has(index) else &""


func _move_stick(p: Vector2) -> void:
	var d := p - stick_origin
	var follow := STICK_RADIUS * STICK_FOLLOW
	if d.length() > follow:
		stick_origin += d.normalized() * (d.length() - follow)
		d = p - stick_origin
	stick_tip = stick_origin + d.limit_length(STICK_RADIUS)
	_set_stick(d / STICK_RADIUS)


## Vetor do joystick (fracao do raio) -> intencoes `move_*` com forca e `run`. A forca e remapeada para fora da zona
## morta da Input Map (0,5 nas acoes de movimento): o dedo logo depois de STICK_DEAD ja anda devagar.
func _set_stick(v: Vector2) -> void:
	v = v.limit_length(1.0)
	stick_vector = v
	var m := v.length()
	var want := {}
	if m >= STICK_DEAD:
		var dz := 0.0
		for a in MOVES:
			dz += InputMap.action_get_deadzone(a) * 0.25 if InputMap.has_action(a) else 0.0
		var out := lerpf(minf(dz + 0.02, 0.99), 1.0, inverse_lerp(STICK_DEAD, 1.0, m))
		var s := v / m * out
		want = {&"move_right": maxf(s.x, 0.0), &"move_left": maxf(-s.x, 0.0), &"move_down": maxf(s.y, 0.0),
			&"move_up": maxf(-s.y, 0.0)}
	for a: StringName in MOVES:
		var k: float = want.get(a, 0.0)
		if k > 0.001:
			Input.action_press(a, k)
			_pressed_moves[a] = true
		elif _pressed_moves.has(a):
			Input.action_release(a)
			_pressed_moves.erase(a)
	var run_now := running
	if m >= RUN_AT:
		run_now = true
	elif m < RUN_OFF:
		run_now = false
	if run_now != running:
		running = run_now
		if running:
			Input.action_press(&"run")
		else:
			Input.action_release(&"run")


func _send(action: StringName, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


# ---------- desenho ----------

func _draw_controls() -> void:
	var c := _canvas
	# Joystick: fantasma em casa ou base onde o dedo tocou, com a ponta.
	var live := _has_kind(&"stick")
	var a := 1.0 if live else 0.45
	_draw_icon(c, "stick_base", stick_origin, STICK_RADIUS, a)
	_draw_icon(c, "stick_knob", stick_tip if live else stick_origin, KNOB_RADIUS, a)
	# Agir: amarelo e com o pictograma da acao quando ha algo a fazer; apagado (mao) quando nao ha.
	var can_act := hud != null and hud.prompt_visible()
	var act_down := _has_kind(&"act")
	var ac := act_center() + (Vector2(0, 6) if act_down else Vector2.ZERO)
	var glow := 0.0
	if can_act and not reduced_motion:
		glow = 0.5 + 0.5 * sin(_clock * TAU / 1.2)
	_disc(c, ac, ACT_RADIUS, YELLOW.lerp(Color(1.15, 1.1, 0.9), glow * 0.25) if can_act else Color(PAPER, 0.55),
		NAVY if can_act else Color(NAVY, 0.45), act_down)
	var act_tex: Texture2D = IconView.texture_for(hud._prompt_icon.kind) if can_act and hud._prompt_icon != null else _tex["hand"]
	_draw_tex(c, act_tex, ac, ACT_RADIUS * 0.62, 1.0 if can_act else 0.55)
	# Pular.
	var jump_down := _has_kind(&"jump")
	var jc := jump_center() + (Vector2(0, 5) if jump_down else Vector2.ZERO)
	_disc(c, jc, JUMP_RADIUS, PAPER if not jump_down else PAPER.darkened(0.12), NAVY, jump_down)
	_draw_icon(c, "jump", jc, JUMP_RADIUS * 0.7, 1.0)
	# Pausa.
	_draw_icon(c, "pause", pause_center(), PAUSE_RADIUS, 0.95)
	# Dica de camera: setas curvas na direita, somem no primeiro arrasto.
	if _cam_hint_left > 0.0:
		var vp := view_size()
		var bob := 0.0 if reduced_motion else 10.0 * sin(_clock * 3.0)
		var hc := Vector2(vp.x * 0.72 + bob, vp.y * 0.42)
		_draw_icon(c, "cam_turn", hc, 90.0, clampf(_cam_hint_left, 0.0, 1.0) * 0.85)


func _disc(c: Control, center: Vector2, r: float, fill: Color, ring: Color, down: bool) -> void:
	if not down:
		c.draw_circle(center + Vector2(0, 8), r, Color(NAVY, 0.28))
	c.draw_circle(center, r, ring)
	c.draw_circle(center, r - 9.0, fill)


func _draw_icon(c: Control, key: String, center: Vector2, r: float, alpha: float) -> void:
	_draw_tex(c, _tex.get(key) as Texture2D, center, r, alpha)


func _draw_tex(c: Control, t: Texture2D, center: Vector2, r: float, alpha: float) -> void:
	if t == null:
		return
	c.draw_texture_rect(t, Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1, 1, 1, alpha))
