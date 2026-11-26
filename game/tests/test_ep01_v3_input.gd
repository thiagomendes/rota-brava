extends RefCounted
## RB-R1 G5/G7 (retorno de Thiago no Ep01 v3): entrada entre camera, HUD e acao.
##  G5: com painel clicavel aberto (troca de heroi, escolha, pausa, conclusao, cena) o mouse fica solto e um clique no
##      mundo nao o prende; ao fechar, volta a ficar preso se estava preso antes. Os botoes abrem com foco e aceitam
##      `ui_accept` (teclado/controle).
##  G7: com o botao "Examinar" visivel, o primeiro E executa a acao, com fala aberta ou na carencia depois dela.
##      Sem acao ao alcance, o E continua avancando/fechando a legenda (C2/D19b).
## Mede o estado de Input.mouse_mode e do HUD; nao comprova o que se ve na tela nem o cursor real do sistema.

var r
var main: Ep01V3Main


func run(runner) -> void:
	r = runner
	Ep01V3Main.start_mission = &""
	Ep01V3Main.save_path = ""
	main = (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	r.tree.root.add_child(main)
	r.tree.current_scene = main
	await r.frames(3)
	main.current = null
	main.set_controlled(main.actors[&"tracker"] as MemberActor)
	main.hud.clear_speech()
	await r.frames(3)
	await _g5_mouse()
	await _g7_first_e()
	await _g5_cutscene()
	main.get_tree().paused = false
	main.queue_free()
	await r.frames(2)
	r.tree.current_scene = null
	await _g5_cutscene_exit()
	r.check(not MouseLock.blocked() and not MouseLock.captured(), "G5: cena descarregada nao deixa mouse preso nem bloqueio")
	MouseLock.reset()


func _click_world() -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	main.camera_rig._unhandled_input(ev)


func _captured() -> bool:
	# Estado pedido ao dono unico do modo do mouse (headless nao prende o cursor real) + modo aplicado coerente.
	return MouseLock.captured()


func _accept() -> void:
	for p in [true, false]:
		var ev := InputEventAction.new()
		ev.action = &"ui_accept"
		ev.pressed = p
		Input.parse_input_event(ev)
		await r.frames(2)


func _g5_mouse() -> void:
	MouseLock.reset()
	_click_world()
	r.check(_captured(), "G5: clique no mundo prende o mouse para a camera")
	# Troca de heroi (botao Confirmar).
	main.hud.open_handoff("x", &"climber")
	await r.frames(2)
	r.check(not _captured() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "G5: cartao de troca aberto solta o mouse (MOUSE_MODE_VISIBLE)")
	_click_world()
	r.check(not _captured(), "G5: com o cartao aberto, clique no mundo nao prende o mouse")
	r.check(main.get_viewport().gui_get_focus_owner() == main.hud._handoff_button, "G5: Confirmar abre com foco")
	main.hud._handoff_since = -100.0
	await _accept()
	r.check(not main.hud.handoff_open, "G5: ui_accept no Confirmar fecha o cartao")
	r.check(_captured(), "G5: fechado o cartao, o mouse volta a ficar preso")
	# Escolha.
	var opts: Array[Dictionary] = [{"id": "a", "label": "a", "icon": "star"}]
	main.hud.open_choice("t", opts)
	await r.frames(2)
	r.check(not _captured(), "G5: escolha aberta solta o mouse")
	main.hud.close_choice()
	await r.frames(1)
	r.check(_captured(), "G5: escolha fechada prende de novo")
	# Pausa (Esc).
	main._pause()
	await r.frames(1)
	r.check(not _captured(), "G5: pausa solta o mouse")
	r.check(main.get_viewport().gui_get_focus_owner() == main.hud._pause_resume, "G5: Continuar abre com foco")
	await _accept()
	r.check(not main.hud.pause_open and not main.get_tree().paused, "G5: ui_accept no Continuar retoma")
	r.check(_captured(), "G5: saindo da pausa o mouse volta a ficar preso")
	# Conclusao.
	main.hud.open_complete()
	await r.frames(1)
	r.check(not _captured(), "G5: tela de conclusao solta o mouse")
	main.hud.close_complete()
	await r.frames(1)
	r.check(_captured(), "G5: conclusao fechada prende de novo")
	# Dois paineis ao mesmo tempo: so prende quando o ultimo fecha.
	main.hud.open_handoff("x", &"climber")
	main._pause()
	main._resume()
	await r.frames(1)
	r.check(not _captured(), "G5: pausa fecha com o cartao ainda aberto -> mouse segue solto")
	main.hud.close_handoff()
	await r.frames(1)
	r.check(_captured(), "G5: ultimo painel fechado -> mouse preso")
	# Solto antes de abrir: continua solto ao fechar.
	main.camera_rig.release_mouse()
	main.hud.open_choice("t", opts)
	main.hud.close_choice()
	await r.frames(1)
	r.check(not _captured(), "G5: mouse solto antes do painel continua solto depois")


## Cutscene: solta o mouse enquanto toca e devolve a captura ao terminar.
func _g5_cutscene() -> void:
	var was_enabled := Ep01V3Cutscene.enabled
	var was_auto := Ep01V3Cutscene.auto_skip
	Ep01V3Cutscene.enabled = true
	Ep01V3Cutscene.auto_skip = false
	Ep01V3Cutscene.reset_seen()
	MouseLock.reset()
	MouseLock.capture()
	main.play_cutscene(&"m2_intro")
	await r.frames(5)
	r.check(main.cutscene.playing and MouseLock.blocked() and not _captured(), "G5: cutscene tocando solta o mouse")
	Engine.time_scale = 8.0
	var n := 0
	while main.cutscene.playing and n < 4000:
		await r.frames(1)
		n += 1
	Engine.time_scale = 1.0
	await r.frames(2)
	r.check(not main.cutscene.playing and not MouseLock.blocked() and _captured(), "G5: cutscene terminada devolve a captura")
	Ep01V3Cutscene.enabled = was_enabled
	Ep01V3Cutscene.auto_skip = was_auto


## Cena sai da arvore no meio da cutscene: nao sobra bloqueio nem captura; o proximo episodio comeca limpo.
func _g5_cutscene_exit() -> void:
	var was_enabled := Ep01V3Cutscene.enabled
	var was_auto := Ep01V3Cutscene.auto_skip
	Ep01V3Cutscene.enabled = true
	Ep01V3Cutscene.auto_skip = false
	Ep01V3Cutscene.reset_seen()
	var m := (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	r.tree.root.add_child(m)
	r.tree.current_scene = m
	await r.frames(3)
	MouseLock.capture()
	m.play_cutscene(&"m2_intro")
	await r.frames(5)
	r.check(m.cutscene.playing and MouseLock.blocked(), "G5: cutscene em curso bloqueia o mouse")
	m.queue_free()
	await r.frames(2)
	r.tree.current_scene = null
	r.check(not MouseLock.blocked() and not MouseLock.captured(), "G5: saindo da arvore no meio da cutscene, sem bloqueio nem captura")
	MouseLock.block(&"cutscene")
	MouseLock.capture()
	var m2 := (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	Ep01V3Cutscene.enabled = false  # sem a cena de abertura, que bloquearia de proposito
	r.tree.root.add_child(m2)
	await r.frames(3)
	r.check(not MouseLock.blocked() and not MouseLock.captured(), "G5: episodio novo zera o MouseLock ao carregar (heranca: bloqueio cutscene + captura)")
	m2.queue_free()
	await r.frames(2)
	Ep01V3Cutscene.enabled = was_enabled
	Ep01V3Cutscene.auto_skip = was_auto
	MouseLock.reset()


func _press_e() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	ev.pressed = true
	Input.parse_input_event(ev)
	await r.frames(2)
	ev = InputEventKey.new()
	ev.physical_keycode = KEY_E
	ev.pressed = false
	Input.parse_input_event(ev)
	await r.frames(2)


func _g7_first_e() -> void:
	var lead := main.actors[&"tracker"] as MemberActor
	var it := Ep01Interactable.new()
	it.name = "G7TestSpot"
	it.radius = 2.0
	it.member = &"tracker"
	it.label_key = "ui.action.examine"
	main.world.add_child(it)
	it.global_position = lead.global_position
	main.land.spots[&"g7_test"] = it
	var hits := [0]
	it.triggered.connect(func(_a: Node3D) -> void: hits[0] += 1)
	await r.frames(3)
	r.check(main.hud.prompt_visible(), "G7: botao Examinar visivel perto do ponto")
	# Causa 1 (HUD, regra C2): fala aberta + Examinar visivel, sem olhar dirigido -> o primeiro E age.
	main.guide.skip_look()
	main.hud.say("ep01.test.g7_line")
	await r.frames(2)
	r.check(main.hud.is_speaking() and not main.guide.looking, "G7: legenda aberta, sem olhar dirigido")
	await _press_e()
	r.check(hits[0] == 1, "G7: com legenda aberta e Examinar visivel, o primeiro E executa a acao (%d)" % hits[0])
	# Causa 2 (guia F2): olhar dirigido em curso + Examinar visivel -> o primeiro E age (e encerra o olhar).
	main.hud.clear_speech()
	await r.tree.create_timer(0.4).timeout
	# Estado de um olhar em curso (como no inicio de cada passo): heroi sem controle, camera no alvo, Examinar visivel.
	main.guide.looking = true
	main.guide.look_elapsed = 0.0
	main.guide.look_target = Vector3.INF
	main.guide._look_actor = lead
	lead.controlled = false
	await r.frames(2)
	r.check(main.hud.prompt_visible(), "G7: Examinar visivel durante o olhar dirigido")
	if main.guide.looking:
		await _press_e()
		r.check(hits[0] == 2 and not main.guide.looking, "G7: durante o olhar dirigido, o primeiro E executa a acao e encerra o olhar (%d)" % hits[0])
	else:
		r.check(false, "G7: olhar dirigido nao comecou no teste")
		hits[0] = 2
	main.guide.skip_look()
	main.hud.say("ep01.test.g7_line")
	await r.frames(2)
	# Carencia logo apos a fala: o primeiro E tambem age.
	main.hud.clear_speech()
	await r.frames(3)
	r.check(not main.hud.is_speaking(), "G7: fala encerrada")
	await _press_e()
	r.check(hits[0] == 3, "G7: logo depois da fala (carencia de 250 ms), o primeiro E executa a acao (%d)" % hits[0])
	# Sem acao no alcance: E fecha a legenda (D19b) e nao interage.
	it.global_position = lead.global_position + Vector3(30, 0, 0)
	await r.frames(3)
	r.check(not main.hud.prompt_visible(), "G7: longe do ponto, Examinar some")
	main.hud.say("ep01.test.g7_line_a")
	main.hud.say("ep01.test.g7_line_b")
	await r.frames(2)
	var q0: int = main.hud._queue.size()
	await _press_e()
	r.check(main.hud._queue.size() < q0 and hits[0] == 3, "G7: sem acao no alcance, o E avanca a legenda (fila %d -> %d)" % [q0, main.hud._queue.size()])
	main.hud.clear_speech()
	main.land.spots.erase(&"g7_test")
	it.queue_free()
	await r.frames(2)
