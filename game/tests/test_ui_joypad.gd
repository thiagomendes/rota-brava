extends RefCounted
## G14 (RB-R1, decisao de Thiago): controle nos menus. O A (botao 0) esta em `ui_accept` e o B (botao 1) em
## `ui_cancel`; com painel de botoes aberto o A so confirma e o heroi nao pula (regra central `MouseLock.jump_suppressed`,
## inclusive no quadro em que o painel fecha). Injeta InputEventJoypadButton de verdade (Input Map), mede estado do
## menu/espacos/HUD e do heroi (`jumps`, `jumping`, chao); nao comprova o que se ve na tela.

const MENU := "res://ui/main_menu.tscn"

var r


func run(runner) -> void:
	r = runner
	var keep_motion: int = Options.motion_override
	Options.motion_override = 0
	_input_map_case()
	await _menu_case()
	await _slots_erase_case()
	await _handoff_case()
	MouseLock.reset()
	Options.motion_override = keep_motion


func _has_pad(action: StringName, b: JoyButton) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == b:
			return true
	return false


func _has_key(action: StringName, k: Key) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey and ((e as InputEventKey).keycode == k or (e as InputEventKey).physical_keycode == k):
			return true
	return false


func _input_map_case() -> void:
	r.check(_has_pad(&"ui_accept", JOY_BUTTON_A) and _has_pad(&"ui_cancel", JOY_BUTTON_B),
		"G14 Input Map: A em ui_accept e B em ui_cancel")
	r.check(_has_key(&"ui_accept", KEY_ENTER) and _has_key(&"ui_accept", KEY_KP_ENTER) and _has_key(&"ui_accept", KEY_SPACE)
		and _has_key(&"ui_cancel", KEY_ESCAPE), "G14 Input Map: teclas padrao mantidas (Enter, Enter do teclado numerico, Espaco, Esc)")


func _pad_sv(sv: SubViewport, b: JoyButton) -> void:
	for pressed in [true, false]:
		var e := InputEventJoypadButton.new()
		e.device = 0
		e.button_index = b
		e.pressed = pressed
		sv.push_input(e)
		await r.frames(1)


func _pad_root(b: JoyButton, hold_frames: int = 2) -> void:
	for pressed in [true, false]:
		var e := InputEventJoypadButton.new()
		e.device = 0
		e.button_index = b
		e.pressed = pressed
		Input.parse_input_event(e)
		await r.tree.physics_frame
		for i in hold_frames:
			await r.tree.physics_frame


func _menu_case() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(1920, 1080)
	sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	r.tree.root.add_child(sv)
	var menu := (load(MENU) as PackedScene).instantiate() as MainMenu
	sv.add_child(menu)
	await r.frames(3)
	# B fecha Opcoes
	menu._open_options()
	await r.frames(2)
	r.check(menu.options_panel.visible, "G14 menu: Opcoes aberto")
	await _pad_sv(sv, JOY_BUTTON_B)
	r.check(not menu.options_panel.visible, "G14 menu: B fecha Opcoes")
	menu.play_button.grab_focus()
	await r.frames(1)
	# A aperta Jogar
	await _pad_sv(sv, JOY_BUTTON_A)
	await r.frames(2)
	r.check(menu.slot_screen.visible and not menu.menu.visible, "G14 menu: A aperta Jogar (abre os espacos)")
	# B volta dos espacos
	await _pad_sv(sv, JOY_BUTTON_B)
	r.check(not menu.slot_screen.visible and menu.menu.visible, "G14 espacos: B volta ao menu")
	sv.queue_free()
	await r.frames(3)


func _slots_erase_case() -> void:
	for i in SaveSlots.COUNT:
		SaveSlots.erase(i + 1)
	var f := FileAccess.open(SaveSlots.save_path(2), FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": MissionSave.VERSION, "episode": "ep01", "current": "M1", "missions": [
		{"id": "M0", "state": Mission.State.COMPLETED, "emblems": []},
		{"id": "M1", "state": Mission.State.INACTIVE, "emblems": []}]}))
	f.close()
	var sv := SubViewport.new()
	sv.size = Vector2i(1920, 1080)
	sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	r.tree.root.add_child(sv)
	var scr := SlotScreen.new()
	sv.add_child(scr)
	await r.frames(2)
	scr.open()
	await r.frames(3)
	scr._ask_confirm(2)
	await r.frames(2)
	r.check(scr.confirm_overlay.visible, "G14 espacos: confirmacao de apagar aberta")
	await _pad_sv(sv, JOY_BUTTON_B)
	r.check(not scr.confirm_overlay.visible and SaveSlots.has_save(2) and scr.visible,
		"G14 espacos: B responde Nao em Apagar (nada apagado, continua nos espacos)")
	sv.queue_free()
	await r.frames(3)
	for i in SaveSlots.COUNT:
		SaveSlots.erase(i + 1)


func _handoff_case() -> void:
	Ep01V3Main.start_mission = &""
	Ep01V3Main.save_path = ""
	var main := (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	r.tree.root.add_child(main)
	r.tree.current_scene = main
	await r.frames(3)
	main.current = null
	var hero := main.actors[&"tracker"] as MemberActor
	main.set_controlled(hero)
	main.hud.clear_speech()
	var n := 0
	while not hero.is_on_floor() and n < 240:
		await r.tree.physics_frame
		n += 1
	# controle: sem painel, o A pula (a regra nao trava o pulo normal)
	var j0 := hero.jumps
	await _pad_root(JOY_BUTTON_A)
	r.check(hero.jumps == j0 + 1, "G14: sem painel, o A pula")
	n = 0
	while (hero.jumping or not hero.is_on_floor()) and n < 600:
		await r.tree.physics_frame
		n += 1
	for i in 10:
		await r.tree.physics_frame
	main.hud.open_handoff("x", &"climber")
	main.hud._handoff_since = -100.0
	await r.frames(2)
	r.check(MouseLock.jump_suppressed(), "G14: com o cartao de troca aberto o pulo fica suprimido")
	var j1 := hero.jumps
	var left_floor := false
	for pressed in [true, false]:
		var e := InputEventJoypadButton.new()
		e.device = 0
		e.button_index = JOY_BUTTON_A
		e.pressed = pressed
		Input.parse_input_event(e)
		for i in 6:
			await r.tree.physics_frame
			left_floor = left_floor or hero.jumping or hero.velocity.y > 0.0
	r.check(not main.hud.handoff_open, "G14: A confirma a troca de heroi")
	r.check(hero.jumps == j1 and not left_floor, "G14: confirmar com A nao faz o heroi pular (jumps %d -> %d)" % [j1, hero.jumps])
	# no quadro em que o painel fecha, o mesmo aperto nao pula (fecha por codigo com o A ja apertado neste quadro)
	main.hud.open_handoff("x", &"climber")
	await r.frames(1)
	var e2 := InputEventJoypadButton.new()
	e2.device = 0
	e2.button_index = JOY_BUTTON_A
	e2.pressed = true
	Input.parse_input_event(e2)
	main.hud.close_handoff()
	await r.tree.physics_frame
	await r.tree.physics_frame
	r.check(hero.jumps == j1, "G14: nao pula no quadro em que o painel fecha")
	e2 = e2.duplicate() as InputEventJoypadButton
	e2.pressed = false
	Input.parse_input_event(e2)
	await r.tree.physics_frame
	main.get_tree().paused = false
	main.queue_free()
	await r.frames(2)
	r.tree.current_scene = null
