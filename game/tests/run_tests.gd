extends SceneTree
## Testes deterministicos da fundacao (RB-01). Uso:
##   ./tools/godot.ps1 --headless --path game --script res://tests/run_tests.gd
## Nao comprovam renderizacao, som, UX nem desempenho.

const REQUIRED_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down", &"interact", &"pause",
]

var _failures: int = 0


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  ", label)
	else:
		_failures += 1
		printerr("FAIL  ", label)


func _press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	await process_frame


func _swap_to(path: String) -> Node:
	if current_scene:
		current_scene.queue_free()
		await process_frame
	var inst: Node = (load(path) as PackedScene).instantiate()
	root.add_child(inst)
	current_scene = inst
	await process_frame
	await process_frame
	return inst


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for action in REQUIRED_ACTIONS:
		_check(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(),
			"Input Map tem a acao '%s' com eventos" % action)
	_check(String(ProjectSettings.get_setting("rendering/renderer/rendering_method")) == "mobile",
		"renderizador configurado: mobile")

	var menu := await _swap_to("res://ui/main_menu.tscn") as MainMenu
	_check(menu.get_viewport().gui_get_focus_owner() == menu.play_button, "foco inicial em Jogar")

	menu.options_button.pressed.emit()
	await process_frame
	_check(menu.options_panel.visible and menu.get_viewport().gui_get_focus_owner() == menu.back_button,
		"Opcoes abre painel com foco em Voltar")
	await _press(&"ui_cancel")
	_check(not menu.options_panel.visible and menu.get_viewport().gui_get_focus_owner() == menu.options_button,
		"ui_cancel fecha Opcoes e devolve foco a Opcoes")

	menu.play_button.pressed.emit()
	await process_frame
	await process_frame
	await process_frame
	var play := current_scene as PlayPlaceholder
	_check(play != null, "Jogar abre a tela de jogo")
	if play:
		await _press(&"interact")
		await _press(&"interact")
		_check(play.action_count == 2, "interact incrementa o contador (2 pressoes = 2)")
		await _press(&"pause")
		await process_frame
		await process_frame
		var back := current_scene as MainMenu
		_check(back != null, "pause volta ao menu")
		if back:
			_check(back.get_viewport().gui_get_focus_owner() == back.play_button,
				"foco recuperado em Jogar apos voltar")

	print("RESULTADO: %s (%d falha(s))" % ["OK" if _failures == 0 else "FALHOU", _failures])
	quit(0 if _failures == 0 else 1)
