extends RefCounted
## RB-M1 item 4: controle por toque basico (TouchControls + InputDevice). Toque simulado por InputEventScreenTouch e
## InputEventScreenDrag em Input.parse_input_event (passa pela emulacao de mouse da Godot, como no aparelho):
## joystick move o heroi (e corre perto da borda), pular pula, agir aciona o Examinar, arrastar a direita gira a
## camera, dois dedos ao mesmo tempo, a camada some com teclado/controle/mouse real e com painel aberto, botoes do HUD,
## da pausa, do menu e dos espacos (inclusive segurar Apagar) respondem ao toque, uma vez so.
## Nao comprova aparencia nem conforto no aparelho (pendente de Thiago).

var r
var main: Ep01V3Main
var touch: TouchControls
var lead: MemberActor


class Probe extends Node:
	var counts: Dictionary = {}

	func _input(event: InputEvent) -> void:
		for a: StringName in [&"help", &"interact", &"jump", &"pause"]:
			if event.is_action_pressed(a) and not event.is_echo():
				counts[a] = int(counts.get(a, 0)) + 1


func run(runner) -> void:
	r = runner
	InputDevice.reset()
	Ep01V3Main.start_mission = &""
	Ep01V3Main.save_path = ""
	main = (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	r.tree.root.add_child(main)
	r.tree.current_scene = main
	await r.frames(3)
	main.current = null
	lead = main.actors[&"tracker"] as MemberActor
	main.set_controlled(lead)
	main.hud.clear_speech()
	main.guide.skip_look()
	touch = main.touch
	await r.frames(3)
	await _appear()
	await _stick()
	await _jump()
	await _act()
	await _camera()
	await _two_fingers()
	await _focus_lost()
	await _panel_blocks()
	await _hud_buttons()
	await _hide_on_other_devices()
	await _targets()
	main.get_tree().paused = false
	main.queue_free()
	await r.frames(2)
	r.tree.current_scene = null
	MouseLock.reset()
	await _menu_and_slots()
	InputDevice.reset()
	for a: StringName in InputMap.get_actions():
		Input.action_release(a)


# ---------- toque simulado ----------

## Posicao logica (viewport 1080 de altura) -> coordenadas da janela, que e o que o aparelho envia.
func _win(p: Vector2) -> Vector2:
	return r.tree.root.get_final_transform() * p


func _down(index: int, p: Vector2, pressed: bool = true) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = _win(p)
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(index: int, from: Vector2, to: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = _win(to)
	e.relative = _win(to) - _win(from)
	Input.parse_input_event(e)


func _tap(p: Vector2, index: int = 0) -> void:
	_down(index, p)
	await r.frames(2)
	_down(index, p, false)
	await r.frames(2)


func _physics(n: int) -> void:
	for i in n:
		await r.tree.physics_frame


func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


# ---------- casos ----------

func _appear() -> void:
	r.check(not touch.visible, "toque: camada escondida antes do primeiro toque")
	r.check(touch.layer > main.hud.layer, "toque: camada acima do HUD (%d > %d)" % [touch.layer, main.hud.layer])
	var vp := touch.view_size()
	await _tap(Vector2(vp.x * 0.62, vp.y * 0.3))
	r.check(touch.visible and InputDevice.last == InputDevice.TOUCH, "toque: primeiro toque mostra a camada (ultimo dispositivo = toque)")
	r.check(main.hud.last_device == &"touch", "toque: HUD sabe que o dispositivo e o toque (glifo sem tecla)")
	r.check(not MouseLock.captured(), "toque: o mouse emulado pelo toque nao prende o mouse da camera")


func _stick() -> void:
	main.camera_rig.set_low_view(0.0)
	var start := lead.global_position
	var o := Vector2(420, touch.view_size().y * 0.62)
	_down(0, o)
	await r.frames(2)
	r.check(touch.finger_kind(0) == &"stick" and touch.stick_origin.distance_to(o) < 1.0,
		"joystick: nasce onde o dedo toca na metade esquerda")
	var tip := o + Vector2(TouchControls.STICK_RADIUS * 0.5, 0)
	_drag(0, o, tip)
	await r.frames(2)
	var half := Input.get_action_strength(&"move_right")
	r.check(half > 0.5 and half < 0.95 and not Input.is_action_pressed(&"run"),
		"joystick: meio raio anda com forca analogica %.2f, sem correr" % half)
	var walk := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down").length()
	r.check(walk > 0.3 and walk < 0.7, "joystick: meio raio vira ~metade do vetor de movimento (%.2f)" % walk)
	_drag(0, tip, o + Vector2(TouchControls.STICK_RADIUS * 1.0, 0))
	await r.frames(2)
	r.check(Input.get_action_strength(&"move_right") > 0.98 and Input.is_action_pressed(&"run"),
		"joystick: na borda (> 85%% do raio) corre (run) com forca %.2f" % Input.get_action_strength(&"move_right"))
	await _physics(45)
	var moved := lead.global_position - start
	moved.y = 0.0
	var right := Basis(Vector3.UP, main.camera_rig.yaw) * Vector3.RIGHT
	r.check(moved.length() > 1.0 and moved.normalized().dot(right) > 0.8,
		"joystick: o heroi anda para a direita da camera (%.2f m, alinhamento %.2f)" % [moved.length(), moved.normalized().dot(right) if moved.length() > 0.01 else 0.0])
	_down(0, o + Vector2(TouchControls.STICK_RADIUS, 0), false)
	await r.frames(2)
	r.check(not Input.is_action_pressed(&"move_right") and not Input.is_action_pressed(&"run") and touch.finger_kind(0) == &"",
		"joystick: soltar o dedo solta movimento e corrida")
	# Arrastar muito alem da borda: a base vem junto (joystick flutuante), sem perder a direcao.
	_down(0, o)
	await r.frames(1)
	_drag(0, o, o + Vector2(0, -TouchControls.STICK_RADIUS * 3.0))
	await r.frames(2)
	r.check(Input.get_action_strength(&"move_up") > 0.98 and touch.stick_origin.y < o.y - 10.0,
		"joystick: dedo alem da borda arrasta a base junto e segue andando")
	_down(0, o, false)
	await r.frames(2)


func _jump() -> void:
	await _physics(30)
	var n := lead.jumps
	var p := touch.jump_center()
	_down(0, p)
	await _physics(3)
	r.check(touch.finger_kind(0) == &"jump", "pular: o dedo no botao e do pular")
	_down(0, p, false)
	await _physics(3)
	r.check(lead.jumps == n + 1, "pular: tocar no botao faz o heroi pular (%d -> %d)" % [n, lead.jumps])
	r.check(not Input.is_action_pressed(&"jump"), "pular: soltar o dedo solta a intencao")
	await _physics(60)


func _act() -> void:
	var it := Ep01Interactable.new()
	it.name = "TouchTestSpot"
	it.radius = 2.0
	it.member = &"tracker"
	it.label_key = "ui.action.examine"
	main.world.add_child(it)
	it.global_position = lead.global_position
	main.land.spots[&"touch_test"] = it
	var hits := [0]
	it.triggered.connect(func(_a: Node3D) -> void: hits[0] += 1)
	await r.frames(4)
	r.check(main.hud.prompt_visible() and not main.hud._prompt_panel.visible,
		"agir: com toque, o Examinar e logico no HUD mas o botao do HUD sai de cena (sem botao duplicado)")
	r.check(touch._label_pill.visible and touch._label.text == Loc.t("ui.action.examine"),
		"agir: a camada mostra o rotulo Examinar sobre o botao de agir")
	await _tap(touch.act_center())
	r.check(hits[0] == 1, "agir: tocar no botao de agir aciona o Examinar uma vez (%d)" % hits[0])
	it.global_position = lead.global_position + Vector3(40, 0, 0)
	await r.frames(3)
	r.check(not main.hud.prompt_visible() and not touch._label_pill.visible, "agir: longe do ponto, rotulo some (botao fica apagado)")
	main.land.spots.erase(&"touch_test")
	it.queue_free()
	await r.frames(2)


func _camera() -> void:
	var y0 := main.camera_rig.yaw
	var vp := touch.view_size()
	var p := Vector2(vp.x * 0.62, vp.y * 0.35)
	r.check(touch.button_at(p) == &"", "camera: ponto de teste fora dos botoes")
	_down(0, p)
	await r.frames(1)
	r.check(touch.finger_kind(0) == &"cam", "camera: dedo na metade direita fora dos botoes e da camera")
	_drag(0, p, p + Vector2(200, 0))
	await r.frames(2)
	var dy := angle_difference(y0, main.camera_rig.yaw)
	r.check(absf(dy + 200.0 * TouchControls.TOUCH_YAW_SENS) < 0.05,
		"camera: arrastar 200 px para a direita gira a camera (%.2f rad)" % dy)
	var p0 := main.camera_rig.pitch
	_drag(0, p + Vector2(200, 0), p + Vector2(200, 60))
	await r.frames(2)
	r.check(main.camera_rig.pitch > p0, "camera: arrastar para baixo inclina a camera (%.2f -> %.2f)" % [p0, main.camera_rig.pitch])
	_down(0, p + Vector2(200, 60), false)
	await r.frames(2)
	r.check(not MouseLock.captured(), "camera: arrastar com o dedo nao prende o mouse")


func _two_fingers() -> void:
	main.camera_rig.set_low_view(0.0)
	await _physics(10)
	var start := lead.global_position
	var vp := touch.view_size()
	var o := Vector2(420, vp.y * 0.62)
	var c := Vector2(vp.x * 0.62, vp.y * 0.35)
	_down(0, o)
	_down(1, c)
	await r.frames(2)
	r.check(touch.finger_kind(0) == &"stick" and touch.finger_kind(1) == &"cam", "dois dedos: um no joystick, outro na camera")
	var y0 := main.camera_rig.yaw
	for i in 10:
		_drag(0, o, o + Vector2(0, -TouchControls.STICK_RADIUS))
		_drag(1, c + Vector2(i * 15, 0), c + Vector2((i + 1) * 15, 0))
		await _physics(3)
	var moved := lead.global_position - start
	moved.y = 0.0
	var turned := absf(angle_difference(y0, main.camera_rig.yaw))
	r.check(moved.length() > 0.5 and turned > 0.5 and Input.is_action_pressed(&"move_up"),
		"dois dedos: anda (%.2f m) e gira a camera (%.2f rad) ao mesmo tempo" % [moved.length(), turned])
	_down(1, c + Vector2(150, 0), false)
	await r.frames(2)
	r.check(Input.is_action_pressed(&"move_up"), "dois dedos: soltar o dedo da camera nao solta o joystick")
	_down(0, o, false)
	await r.frames(2)
	r.check(not Input.is_action_pressed(&"move_up"), "dois dedos: soltar o joystick para o heroi")


## App para segundo plano / janela perde o foco com o dedo no joystick e no pular: nada fica pressionado.
func _focus_lost() -> void:
	var o := Vector2(420, touch.view_size().y * 0.62)
	for what: int in [Node.NOTIFICATION_APPLICATION_FOCUS_OUT, Node.NOTIFICATION_APPLICATION_PAUSED,
			Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		_down(0, o)
		await r.frames(1)
		_drag(0, o, o + Vector2(TouchControls.STICK_RADIUS, 0))
		_down(1, touch.jump_center())
		await r.frames(2)
		var held := Input.is_action_pressed(&"move_right") and Input.is_action_pressed(&"run") and Input.is_action_pressed(&"jump")
		touch.notification(what)
		await r.frames(2)
		var free := not Input.is_action_pressed(&"move_right") and not Input.is_action_pressed(&"run") \
			and not Input.is_action_pressed(&"jump") and touch.finger_kind(0) == &"" and touch.finger_kind(1) == &""
		r.check(held and free, "foco: notificacao %d solta joystick, corrida e pular (segurava %s, solto %s)" % [what, held, free])
		# O "soltou" que chega depois (se chegar) nao pertence mais a camada e nao quebra nada.
		_down(0, o, false)
		_down(1, touch.jump_center(), false)
		await r.frames(2)
	var p0 := lead.global_position
	await _physics(20)
	var drift := lead.global_position - p0
	drift.y = 0.0
	r.check(drift.length() < 0.3, "foco: depois de perder o foco o heroi para (%.2f m)" % drift.length())


func _panel_blocks() -> void:
	var probe := Probe.new()
	r.tree.root.add_child(probe)
	main.hud.open_handoff("x", &"climber")
	await r.frames(2)
	r.check(not touch.visible, "painel: com o cartao de troca aberto a camada some")
	var n := lead.jumps
	await _tap(touch.jump_center(), 1)
	await _tap(touch.act_center(), 1)
	await _physics(4)
	r.check(lead.jumps == n and int(probe.counts.get(&"jump", 0)) == 0 and int(probe.counts.get(&"interact", 0)) == 0,
		"painel: com painel aberto, pular e agir pela camada nao agem")
	# O botao Confirmar do cartao responde ao toque (emulacao de mouse da Godot).
	main.hud._handoff_since = -100.0
	var confirms := [0]
	main.hud.handoff_confirmed.connect(func() -> void: confirms[0] += 1, CONNECT_ONE_SHOT)
	await _tap(_center(main.hud._handoff_button))
	r.check(confirms[0] == 1 and not main.hud.handoff_open, "painel: Confirmar da troca responde ao toque, uma vez (%d)" % confirms[0])
	await r.frames(2)
	r.check(touch.visible, "painel: fechado o cartao, a camada volta")
	main.set_controlled(lead)
	main.active_member = &"tracker"
	probe.queue_free()


func _hud_buttons() -> void:
	var probe := Probe.new()
	r.tree.root.add_child(probe)
	var helps := [0]
	main.hud.help_requested.connect(func() -> void: helps[0] += 1)
	var hb := main.hud._help_button
	# G22a: no toque a ajuda e um disco da camada, no lugar do botao do HUD (que fica vazio e sem receber o dedo).
	r.check(not (hb in main.hud.touch_passthrough()), "G22a ajuda: no toque o botao do HUD nao e mais da GUI (a camada desenha)")
	r.check(not main.hud._help_icon.visible and hb.mouse_filter == Control.MOUSE_FILTER_IGNORE and hb.self_modulate.a == 0.0,
		"G22a ajuda: no toque o botao do HUD fica vazio (sem o disco de 72 px e sem pegar o dedo)")
	r.check(TouchControls.HELP_RADIUS * 2.0 >= 110.0 and TouchControls.HELP_RADIUS * 2.0 >= TouchControls.PAUSE_RADIUS * 2.0,
		"G22a ajuda: disco de %d px no toque (>= 110 e >= pausa)" % int(TouchControls.HELP_RADIUS * 2.0))
	var hc := touch.help_center()
	r.check(hc != Vector2.ZERO and hc.distance_to(_center(hb)) < 0.5, "G22a ajuda: disco no lugar do botao do HUD (%s)" % str(hc))
	r.check(touch.button_at(hc) == &"help" and touch.button_at(hc + Vector2(TouchControls.HELP_RADIUS * 1.1, 0)) == &"help",
		"G22a ajuda: alvo do toque cobre o disco e um pouco alem (dedo de crianca)")
	r.check(TouchControls.HELP_ICON_FRACTION >= 0.65, "G22a ajuda: pictograma proporcional ao disco (%.2f do raio)" % TouchControls.HELP_ICON_FRACTION)
	# Nao briga com o painel de objetivo nem com o contador de emblemas (contador aceso para medir).
	main.hud.set_collectibles(1, 10, false)
	await r.frames(2)
	var disc := Rect2(touch.help_center() - Vector2.ONE * TouchControls.HELP_RADIUS, Vector2.ONE * TouchControls.HELP_RADIUS * 2.0)
	var obj := main.hud.find_child("ObjectivePanel", true, false) as Control
	var emb := main.hud._emblem_panel
	r.check(not disc.intersects(obj.get_global_rect()) and not disc.intersects(emb.get_global_rect()),
		"G22a ajuda: disco nao encosta no objetivo (%s) nem nos emblemas (%s)" % [str(obj.get_global_rect()), str(emb.get_global_rect())])
	r.check(touch.button_at(_center(emb)) != &"help", "G22a ajuda: tocar nos emblemas nao pede ajuda")
	r.check(_key_hints_on_screen().is_empty(), "G22a sem tecla no toque: HUD em jogo sem selo/texto de tecla %s" % str(_key_hints_on_screen()))
	await _tap(touch.help_center())
	r.check(helps[0] == 1 and int(probe.counts.get(&"help", 0)) == 1,
		"ajuda: tocar no disco da ajuda envia a intencao help uma vez (sinal %d, intencao %d)" % [helps[0], int(probe.counts.get(&"help", 0))])
	# Toque na borda do lugar (fora do disco desenhado) tambem conta.
	var edge := hb.get_global_rect().position + Vector2(8, 8)
	var h0: int = helps[0]
	await _tap(edge)
	r.check(helps[0] == h0 + 1, "ajuda: tocar no canto do alvo, fora do desenho, tambem pede ajuda (%d)" % (helps[0] - h0))
	# Segundo dedo: com o joystick seguro pelo dedo 0, o dedo 1 na ajuda pede ajuda (a GUI so via o dedo 0).
	h0 = helps[0]
	var so := touch.stick_home()
	_down(0, so)
	await r.frames(1)
	await _tap(touch.help_center(), 1)
	r.check(helps[0] == h0 + 1 and touch.finger_kind(0) == &"stick", "G22a ajuda: segundo dedo na ajuda pede ajuda com o joystick seguro (%d)" % (helps[0] - h0))
	_down(0, so, false)
	await r.frames(2)
	main.hud.set_collectibles(0, 10, false)
	# Pausa pela camada; Continuar e Opcoes da pausa pelo toque.
	await _tap(touch.pause_center())
	r.check(main.hud.pause_open and main.get_tree().paused and not touch.visible, "pausa: o botao de pausa da camada pausa (e a camada some)")
	r.check(_key_hints_on_screen().is_empty(), "G22a sem tecla no toque: pausa aberta sem selo/texto de tecla %s" % str(_key_hints_on_screen()))
	await _tap(_center(main.hud._pause_options))
	r.check(main.hud.options_open, "pausa: Opcoes responde ao toque")
	main.hud.close_options()
	await r.frames(2)
	await _tap(_center(main.hud._pause_resume))
	r.check(not main.hud.pause_open and not main.get_tree().paused and touch.visible, "pausa: Continuar responde ao toque e a camada volta")
	r.check(touch.pause_center().x + TouchControls.PAUSE_RADIUS <= main.hud._member_panel.get_global_rect().position.x
		or not main.hud._member_panel.visible, "pausa: o botao fica a esquerda dos retratos (nao cobre)")
	probe.queue_free()


## G22a: selos de glifo visiveis que nao sao de toque e textos visiveis com nome de tecla (HUD inteiro).
func _key_hints_on_screen() -> Array[String]:
	var bad: Array[String] = []
	var keys := RegEx.create_from_string("(^|[^\\p{L}])(Esc|Enter|Espa[cç]o|Shift|Tab|Tecla|tecla)([^\\p{L}]|$)|\\[[A-Z]\\]|^[A-Z]$")
	for n: Node in main.hud.find_children("*", "", true, false):
		var c := n as CanvasItem
		if c == null or not c.is_visible_in_tree():
			continue
		if n is GlyphView and not String((n as GlyphView).glyph_id()).begins_with("touch_"):
			bad.append("%s=%s" % [n.name, (n as GlyphView).glyph_id()])
		elif n is Label and keys.search((n as Label).text) != null:
			bad.append("%s='%s'" % [n.name, (n as Label).text])
		elif n is Button and keys.search((n as Button).text) != null:
			bad.append("%s='%s'" % [n.name, (n as Button).text])
	return bad


func _hide_on_other_devices() -> void:
	var o := Vector2(420, touch.view_size().y * 0.62)
	_down(0, o)
	await r.frames(1)
	_drag(0, o, o + Vector2(0, -TouchControls.STICK_RADIUS))
	await r.frames(2)
	var k := InputEventKey.new()
	k.physical_keycode = KEY_D
	k.keycode = KEY_D
	k.pressed = true
	Input.parse_input_event(k)
	await r.frames(2)
	r.check(not touch.visible and main.hud.last_device == &"keyboard", "outros: tecla esconde a camada")
	r.check(not Input.is_action_pressed(&"move_up") and touch.finger_kind(0) == &"", "outros: esconder solta o joystick que estava segurado")
	# G22a: no teclado o botao de ajuda do HUD volta (balao + selo H do G15) e a auditoria de tecla acusa o selo (mutacao).
	var hb := main.hud._help_button
	r.check(main.hud._help_icon.visible and hb.mouse_filter == Control.MOUSE_FILTER_STOP and hb.self_modulate.a == 1.0
		and main.hud._help_glyph.is_visible_in_tree() and main.hud._help_glyph.glyph_id() == &"key_h",
		"G22a teclado: botao de ajuda do HUD de volta, com o selo H so no canto")
	r.check(not _key_hints_on_screen().is_empty(), "G22a mutacao: no teclado a auditoria de tecla acusa os selos (%d)" % _key_hints_on_screen().size())
	k = k.duplicate()
	k.pressed = false
	Input.parse_input_event(k)
	await _tap(Vector2(1300, 400))
	r.check(touch.visible, "outros: novo toque mostra de novo")
	var j := InputEventJoypadButton.new()
	j.button_index = JOY_BUTTON_A
	j.pressed = true
	Input.parse_input_event(j)
	await r.frames(2)
	j = j.duplicate()
	j.pressed = false
	Input.parse_input_event(j)
	r.check(not touch.visible and main.hud.last_device == &"pad", "outros: botao do controle esconde a camada")
	await _tap(Vector2(1300, 400))
	var drift := InputEventJoypadMotion.new()
	drift.axis = JOY_AXIS_LEFT_X
	drift.axis_value = 0.2
	Input.parse_input_event(drift)
	await r.frames(2)
	r.check(touch.visible, "outros: deriva pequena da alavanca nao esconde a camada")
	var mm := InputEventMouseMotion.new()
	mm.relative = _win(Vector2(1, 0)) - _win(Vector2.ZERO)
	mm.position = _win(Vector2(500, 500))
	Input.parse_input_event(mm)
	await r.frames(2)
	r.check(touch.visible, "outros: tremida de 1 px (logico) do mouse nao esconde a camada")
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = _win(Vector2(900, 300))
	Input.parse_input_event(mb)
	await r.frames(2)
	mb = mb.duplicate()
	mb.pressed = false
	Input.parse_input_event(mb)
	await r.frames(2)
	r.check(not touch.visible, "outros: clique de mouse real esconde a camada")
	r.check(InputDevice.classify(_emulated_click()) == &"", "outros: mouse emulado do toque nao conta como mouse")
	MouseLock.release()
	await _tap(Vector2(1300, 400))


func _emulated_click() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.device = InputEvent.DEVICE_ID_EMULATION
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e


## Alvos >= 110 px logicos e dentro da area segura em 16:9, 20:9 e 4:3 (mesma conta que a camada usa).
func _targets() -> void:
	r.check(TouchControls.ACT_RADIUS * 2.0 >= 110.0 and TouchControls.JUMP_RADIUS * 2.0 >= 110.0
		and TouchControls.PAUSE_RADIUS * 2.0 >= 110.0 and TouchControls.KNOB_RADIUS * 2.0 >= 110.0,
		"alvos: agir %d, pular %d, pausa %d, ponta do joystick %d px (>= 110)" % [TouchControls.ACT_RADIUS * 2, TouchControls.JUMP_RADIUS * 2,
		TouchControls.PAUSE_RADIUS * 2, TouchControls.KNOB_RADIUS * 2])
	var vp := touch.view_size()
	var m := touch.margins()
	var safe := Rect2(m, vp - m * 2.0)
	var ok := true
	for pair: Array in [[touch.act_center(), TouchControls.ACT_RADIUS], [touch.jump_center(), TouchControls.JUMP_RADIUS],
			[touch.pause_center(), TouchControls.PAUSE_RADIUS], [touch.stick_home(), TouchControls.STICK_RADIUS]]:
		var c: Vector2 = pair[0]
		var rad: float = pair[1]
		ok = ok and safe.grow(0.5).encloses(Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0))
	r.check(ok, "alvos: botoes e joystick dentro da area segura (%s)" % str(vp))
	r.check(touch.act_center().distance_to(touch.jump_center()) >= TouchControls.ACT_RADIUS + TouchControls.JUMP_RADIUS + 20.0,
		"alvos: agir e pular nao se encostam")
	# Movimento reduzido: o botao de agir nao pulsa (brilho fixo) e a dica da camera nao balanca.
	r.check(TouchControls.new().reduced_motion == false, "movimento reduzido: padrao desligado")
	var keep: int = Options.motion_override
	Options.motion_override = 1
	var t2 := TouchControls.new()
	main.add_child(t2)
	r.check(t2.reduced_motion, "movimento reduzido: a camada le a opcao ao nascer")
	t2.queue_free()
	Options.motion_override = keep
	await r.frames(1)


# ---------- menu e espacos ----------

func _menu_and_slots() -> void:
	InputDevice.reset()
	var menu := (load("res://ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	r.tree.root.add_child(menu)
	await r.frames(4)
	await _tap(_center(menu.options_button))
	r.check(menu.options_panel.visible, "menu: Opcoes responde ao toque")
	r.check(menu.get_node_or_null("TouchControls") == null and menu.find_children("*", "TouchControls", true, false).is_empty(),
		"menu: sem camada de toque no menu (so no episodio)")
	menu._close_options()
	await r.frames(2)
	await _tap(_center(menu.play_button))
	r.check(menu.slot_screen.visible, "menu: Jogar responde ao toque (abre os espacos)")
	menu.queue_free()
	await r.frames(3)
	# Espacos: cartao responde ao toque uma vez; Apagar exige segurar 1,5 s com o dedo.
	var f := FileAccess.open(SaveSlots.save_path(2), FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": MissionSave.VERSION, "episode": "ep01", "current": "M2", "missions": [
		{"id": "M0", "state": Mission.State.COMPLETED, "emblems": []},
		{"id": "M1", "state": Mission.State.COMPLETED, "emblems": []},
		{"id": "M2", "state": Mission.State.INACTIVE, "emblems": []}]}))
	f.close()
	var scr := SlotScreen.new()
	r.tree.root.add_child(scr)
	await r.frames(2)
	scr.open()
	await r.frames(3)
	var plays: Array[int] = []
	scr.play_requested.connect(func(s: int) -> void: plays.append(s))
	await _tap(_center(scr.cards[0]))
	r.check(plays == [1], "espacos: tocar no cartao 1 pede para jogar o espaco 1, uma vez (%s)" % str(plays))
	var del := scr.delete_buttons[1]
	var dc := _center(del)
	_down(0, dc)
	await r.frames(2)
	r.check(del.holding == &"pointer", "espacos: o dedo no Apagar comeca a segurar")
	await r.tree.create_timer(0.6).timeout
	_down(0, dc, false)
	await r.frames(2)
	r.check(not scr.confirm_overlay.visible and SaveSlots.has_save(2) and del.progress == 0.0,
		"espacos: soltar o dedo antes de 1,5 s nao apaga")
	_down(0, dc)
	await r.frames(2)
	var t0 := Time.get_ticks_msec()
	while not scr.confirm_overlay.visible and Time.get_ticks_msec() - t0 < 4000:
		await r.frames(1)
	var held_ms := Time.get_ticks_msec() - t0
	_down(0, dc, false)
	await r.frames(2)
	r.check(scr.confirm_overlay.visible and held_ms >= 1300 and SaveSlots.has_save(2),
		"espacos: segurar o dedo 1,5 s no Apagar abre a confirmacao (%d ms)" % held_ms)
	await _tap(_center(scr.confirm_no))
	r.check(not scr.confirm_overlay.visible and SaveSlots.has_save(2), "espacos: Nao da confirmacao responde ao toque e nao apaga")
	scr.queue_free()
	await r.frames(2)
	SaveSlots.erase(2)
