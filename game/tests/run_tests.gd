extends SceneTree
## Testes deterministicos da fundacao (RB-01). Uso:
##   ./tools/godot.ps1 --headless --path game --script res://tests/run_tests.gd
## Nao comprovam renderizacao, som, UX nem desempenho. `Sair` (codigo de saida 0) e coberto
## pelo tools/smoke-test.ps1, pois encerra o processo.

## Contrato de entrada (SPEC secao 5): acao -> teclas fisicas, botoes e eixos de controle.
const KEYS := {
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"move_up": [KEY_W, KEY_UP],
	&"move_down": [KEY_S, KEY_DOWN],
	&"interact": [KEY_E],
	&"pause": [KEY_ESCAPE],
}
const BUTTONS := {
	&"interact": [JOY_BUTTON_A],
	&"pause": [JOY_BUTTON_START],
}
## acao -> [eixo, sinal]
const AXES := {
	&"move_left": [JOY_AXIS_LEFT_X, -1.0],
	&"move_right": [JOY_AXIS_LEFT_X, 1.0],
	&"move_up": [JOY_AXIS_LEFT_Y, -1.0],
	&"move_down": [JOY_AXIS_LEFT_Y, 1.0],
}

var _failures: int = 0


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  ", label)
	else:
		_failures += 1
		printerr("FAIL  ", label)


func _has_key(action: StringName, keycode: Key) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey and (e as InputEventKey).physical_keycode == keycode:
			return true
	return false


func _has_button(action: StringName, index: JoyButton) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == index:
			return true
	return false


func _has_axis(action: StringName, axis: JoyAxis, sign_value: float) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadMotion:
			var m := e as InputEventJoypadMotion
			if m.axis == axis and signf(m.axis_value) == sign_value:
				return true
	return false


func _frames(count: int = 2) -> void:
	for i in count:
		await process_frame


func _send(action: StringName, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)
	await _frames()


func _tap(action: StringName) -> void:
	await _send(action, true)
	await _send(action, false)


func _swap_to(path: String) -> Node:
	if current_scene:
		current_scene.queue_free()
		await process_frame
	var inst: Node = (load(path) as PackedScene).instantiate()
	root.add_child(inst)
	current_scene = inst
	await _frames()
	return inst


func _focus(node: Node) -> Control:
	return node.get_viewport().gui_get_focus_owner()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for action: StringName in KEYS:
		for key: Key in KEYS[action]:
			_check(_has_key(action, key), "'%s' tem a tecla %s" % [action, OS.get_keycode_string(key)])
	for action: StringName in BUTTONS:
		for index: JoyButton in BUTTONS[action]:
			_check(_has_button(action, index), "'%s' tem o botao de controle %d" % [action, index])
	for action: StringName in AXES:
		_check(_has_axis(action, AXES[action][0], AXES[action][1]), "'%s' tem o eixo do analogico" % action)
	_check(String(ProjectSettings.get_setting("rendering/renderer/rendering_method")) == "mobile",
		"renderizador configurado: mobile")

	var menu := await _swap_to("res://ui/main_menu.tscn") as MainMenu
	_check(_focus(menu) == menu.play_button, "foco inicial em Jogar")

	await _tap(&"ui_down")
	_check(_focus(menu) == menu.options_button, "ui_down move o foco de Jogar para Opcoes")
	await _tap(&"ui_down")
	_check(_focus(menu) == menu.quit_button, "ui_down move o foco de Opcoes para Sair")
	await _tap(&"ui_up")
	await _tap(&"ui_up")
	_check(_focus(menu) == menu.play_button, "ui_up volta o foco para Jogar")

	await _tap(&"pause")
	_check(current_scene == menu and menu.menu.visible and _focus(menu) == menu.play_button,
		"Esc/pause no menu principal nao fecha nem muda o menu")

	await _tap(&"ui_down")
	await _tap(&"ui_accept")
	_check(menu.options_panel.visible and _focus(menu) == menu.back_button,
		"ui_accept em Opcoes abre o painel com foco em Voltar")
	await _tap(&"ui_cancel")
	_check(not menu.options_panel.visible and _focus(menu) == menu.options_button,
		"ui_cancel fecha Opcoes e devolve foco a Opcoes")
	await _tap(&"ui_up")
	_check(_focus(menu) == menu.play_button, "foco continua navegavel depois de fechar Opcoes")

	await _tap(&"ui_accept")
	await _frames(2)
	var play := current_scene as PlayPlaceholder
	_check(play != null, "ui_accept em Jogar abre a tela de jogo")
	if play:
		await _tap(&"interact")
		await _tap(&"interact")
		_check(play.action_count == 2, "interact incrementa o contador (2 pressoes = 2)")
		await _tap(&"move_left")
		_check(play.action_count == 2, "outras intencoes nao contam como interact")
		await _tap(&"pause")
		await _frames(2)
		var back := current_scene as MainMenu
		_check(back != null, "pause volta ao menu")
		if back:
			_check(_focus(back) == back.play_button, "foco recuperado em Jogar apos voltar")

	print("RESULTADO: %s (%d falha(s))" % ["OK" if _failures == 0 else "FALHOU", _failures])
	quit(0 if _failures == 0 else 1)
