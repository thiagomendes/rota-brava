extends RefCounted
## Ep01 v3 (RB-R1 E1): o jogo abre o episodio na vila v3; trio no M0; barco v2 com encaixes atracado no M6; camera baixa
## com o heroi a ~28% da altura da tela; o bot percorre M0->M8 com entrada real (tempo acelerado, deterministico) e o
## salvamento por missao retoma na missao certa. Nao comprova render, som, UX nem desempenho.

const TIME_SCALE := 8.0
const MAX_FRAMES := 40000
const ORDER: Array[StringName] = [&"M0", &"M1", &"M2", &"M3", &"M4", &"M5", &"M6", &"M7", &"M8"]

var r


func run(runner) -> void:
	r = runner
	r.check((load("res://ui/main_menu.gd") as GDScript).get_script_constant_map().get("PLAY_SCENE", "")
		== "res://episodes/ep01/v3/ep01_v3_main.tscn", "v3: Jogar abre o Ep01 na vila v3")
	await _boat_scene()
	await _walkthrough()
	await _resume_from_save()
	await _resume_from_menu()
	await _help_tiers()
	await _market_wrong_stall()


func _new_main() -> Ep01V3Main:
	var main := (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	r.tree.root.add_child(main)
	r.tree.current_scene = main
	await r.frames(3)
	return main


func _free(main: Ep01V3Main) -> void:
	main.queue_free()
	await r.frames(2)
	r.tree.current_scene = null
	r.tree.paused = false


func _boat_scene() -> void:
	var boat := BoatActor.new()
	r.tree.root.add_child(boat)
	await r.frames(1)
	var model := boat.get_node_or_null("Model")
	r.check(model != null and model.scene_file_path == BoatActor.MODEL_SCENE, "v3: BoatActor usa boat_wv2.tscn")
	r.check(model != null and model.get_node_or_null("Model") != null, "v3: barco v2 tem Model (GLB)")
	r.check(model != null and model.get_node_or_null("Body/Collision") is CollisionShape3D, "v3: barco v2 tem Body/Collision")
	r.check(boat.bow_light != null, "v3: barco v2 tem BowLight")
	r.check(boat.wheel != null and boat.wheel.name == &"WheelPoint", "v3: barco v2 tem WheelPoint")
	var body := model.get_node_or_null("Body") as CollisionObject3D if model != null else null
	r.check(body != null and body.collision_layer == 0, "v3: casco nao barra o heroi (barco anda por funcao)")
	boat.queue_free()
	await r.frames(1)


func _walkthrough() -> void:
	Ep01V3Main.start_mission = &""
	Ep01V3Main.save_path = ""
	var main := await _new_main()
	r.check(main.world is VillageWorld and main.world.scene_file_path == Ep01V3Main.WORLD_SCENE, "v3: mundo e village_world.tscn")
	r.check(main.find_children("*", "StageBase", true, false).is_empty(), "v3: rio/ilha/volta fora do fluxo (sem estagios antigos)")
	var start := main.world.marker(&"M0_RastroStart").global_position
	var tracker := main.actors[&"tracker"] as MemberActor
	r.check(Vector2(tracker.global_position.x - start.x, tracker.global_position.z - start.z).length() < 0.1,
		"v3: Rastro nasce no M0_RastroStart")
	var near := true
	for m: StringName in main.actors:
		near = near and (main.actors[m] as MemberActor).global_position.distance_to(start) < 2.0
	r.check(near and main.actors.size() == 3, "v3: trio junto no M0")
	var berth := main.world.marker(&"M6_BoatStart").global_position
	r.check(main.boat.global_position.distance_to(berth) < 0.01, "v3: barco atracado no marcador do M6")
	r.check(main.current != null and main.current.id == &"M0", "v3: comeca no M0")
	# Camera baixa: altura da camera e fracao da tela ocupada pelo heroi (pes ao topo da cabeca ~1,12 m). F2: o olhar
	# dirigido do inicio (camera no alvo) e pulado antes de medir o enquadramento normal.
	await r.frames(2)
	main.guide.skip_look()
	await r.frames(5)
	var cam := main.camera_rig.camera
	var cam_h := cam.global_position.y - tracker.global_position.y
	r.check(absf(cam_h - CameraRig.LOW_OFFSET.y) < 0.1 and absf(cam.fov - CameraRig.LOW_FOV) < 0.01,
		"v3: camera baixa a %.2f m, FOV %.0f" % [cam_h, cam.fov])
	var frac := _hero_fraction(cam, tracker)
	r.check(frac > 0.24 and frac < 0.32, "v3: heroi ocupa %.1f%% da altura da tela (alvo ~28%%)" % (frac * 100.0))

	var started: Array[StringName] = []
	main.mission_started.connect(func(id: StringName) -> void: started.append(id))
	var switches: Array[StringName] = []
	for m in main.missions:
		m.hero_switch_requested.connect(func(_mid: StringName, hero: StringName, _i: StringName) -> void: switches.append(hero))
	var bot := await _run_bot(main, &"")
	var done_ids: Array[StringName] = []
	var prev := 0.0
	var times: Array[String] = []
	for h: Dictionary in bot.history:
		done_ids.append(h["id"] as StringName)
		times.append("%s %.1f s" % [h["id"], float(h["t"]) - prev])
		prev = float(h["t"])
	print("[RB] v3 tempos do bot (jogo): ", ", ".join(times))
	r.check(bot.done and bot.fail_reason == "", "v3: bot terminou M0->M8 com entrada real (%s; %.1f s de jogo) %s" % [
		bot.fail_reason, bot.elapsed, str(done_ids)])
	r.check(done_ids == ORDER, "v3: missoes concluidas em ordem M0..M8")
	r.check(main.complete and main.hud.complete_open, "v3: episodio concluido e tela de conclusao aberta")
	r.check(main.world.festival, "v3: vila em noite de festa no fim")
	# E4: M1-M4 com mecanica real (pontos de acao, saltos do Pico, carrinho), troca contextual e emblemas.
	r.check(switches.has(&"climber") and switches.has(&"tracker") and switches.has(&"pilot"),
		"v3 E4: troca de heroi pedida para Pico, Rastro e Leme (%s)" % str(switches))
	r.check(bot.switches >= 4, "v3 E4: bot confirmou %d cartoes de troca" % bot.switches)
	r.check(main.emblems_total == 10 and main.emblems_found == 10, "v3 E5: emblemas M1-M8 %d/%d" % [main.emblems_found, main.emblems_total])
	r.check(main.boat.global_position.distance_to(main.world.marker(&"M6_BoatStart").global_position) < 0.05,
		"v3 E5: barco de volta ao cais depois do resgate")
	r.check(bot.presses >= 20, "v3 E4: bot apertou interact %d vezes (acoes reais)" % bot.presses)
	await _free(main)


## Roda o bot ate o fim (ou ate a missao stop_at comecar) com tempo acelerado e limite de quadros. O bot devolve o tempo e
## solta as acoes ao sair da arvore, mesmo se este teste abortar no meio.
func _run_bot(main: Ep01V3Main, stop_at: StringName) -> Ep01V3Bot:
	var bot := Ep01V3Bot.new()
	bot.main = main
	main.add_child(bot)
	Engine.time_scale = TIME_SCALE
	var frames := 0
	while not bot.done and frames < MAX_FRAMES:
		await r.tree.process_frame
		frames += 1
		if stop_at != &"" and main.current != null and main.current.id == stop_at:
			break
	Engine.time_scale = 1.0
	Ep01V3Bot.release_all()
	if not bot.done and stop_at == &"":
		bot.fail_reason = "limite de %d quadros" % MAX_FRAMES
	return bot


func _hero_fraction(cam: Camera3D, hero: Node3D) -> float:
	var vp := cam.get_viewport().get_visible_rect().size
	var feet := cam.unproject_position(hero.global_position)
	var head := cam.unproject_position(hero.global_position + Vector3(0, 1.12, 0))
	return absf(feet.y - head.y) / vp.y


func _resume_from_save() -> void:
	var path := "user://test_ep01_v3.save.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Ep01V3Main.start_mission = &""
	Ep01V3Main.save_path = path
	var main := await _new_main()
	# Completa M0 e M1 pela API da missao (o evento que o mundo dispara) e confere o salvo.
	main.notify_mission(&"marker_reached")
	await r.frames(2)
	for ev: StringName in [&"paw_examined", &"boot_examined", &"paw_followed", &"paw_followed", &"paw_followed", &"paw_followed"]:
		main.current.notify(ev, &"tracker")
	await r.frames(2)
	r.check(main.current != null and main.current.id == &"M2", "v3 salvo: depois de 2 missoes a atual e M2")
	await _free(main)
	var again := await _new_main()
	r.check(again.current != null and again.current.id == &"M2", "v3 salvo: recarregar retoma no M2")
	r.check(again.missions[0].is_completed() and again.missions[1].is_completed(), "v3 salvo: M0 e M1 seguem concluidas")
	await _free(again)
	# Salvo corrompido: comeca do M0, sem travar.
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ quebrado")
	f.close()
	var fresh := await _new_main()
	r.check(fresh.current != null and fresh.current.id == &"M0", "v3 salvo: arquivo corrompido recomeca no M0")
	await _free(fresh)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Ep01V3Main.save_path = ""


func _send(action: StringName, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)
	await r.frames()


func _tap(action: StringName) -> void:
	await _send(action, true)
	await _send(action, false)


## Retomada pelo caminho do jogador: menu -> Jogar; o bot joga M0 e M1 de verdade; pausa -> Menu -> Jogar retoma no M2
## com o trio onde o M1 terminou e o emblema do M1 contado.
func _resume_from_menu() -> void:
	var path := "user://test_ep01_v3_menu.save.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Ep01V3Main.start_mission = &""
	Ep01V3Main.save_path = path
	var menu := (load("res://ui/main_menu.tscn") as PackedScene).instantiate()
	r.tree.root.add_child(menu)
	r.tree.current_scene = menu
	await r.frames(3)
	await _tap(&"ui_accept")
	await r.frames(4)
	var play := r.tree.current_scene as Ep01V3Main
	r.check(play != null and play.current != null and play.current.id == &"M0", "v3 menu: Jogar sem salvo comeca no M0")
	if play == null:
		return
	var bot := await _run_bot(play, &"M2")
	bot.queue_free()
	await r.frames(2)
	r.check(play.current.id == &"M2" and FileAccess.file_exists(path), "v3 menu: depois de jogar M0 e M1 o salvo existe")
	await _tap(&"pause")
	await _tap(&"ui_down")
	await _tap(&"ui_down")
	await _tap(&"ui_accept")
	await r.frames(4)
	var menu2 := r.tree.current_scene as MainMenu
	r.check(menu2 != null, "v3 menu: Menu na pausa volta ao menu")
	if menu2 == null:
		return
	await _tap(&"ui_accept")
	await r.frames(4)
	var again := r.tree.current_scene as Ep01V3Main
	r.check(again != null and again.current != null and again.current.id == &"M2", "v3 menu: Jogar retoma no M2")
	if again != null:
		var p := again.land.start_position(&"M2")
		var t := again.actors[&"tracker"] as MemberActor
		r.check(Vector2(t.global_position.x - p.x, t.global_position.z - p.z).length() < 0.5,
			"v3 menu: trio retoma onde o M1 terminou")
		r.check(again.missions[1].is_completed() and again.emblems_found == 1, "v3 menu: M1 concluida e emblema do M1 contado (%d)" % again.emblems_found)
		await _free(again)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Ep01V3Main.save_path = ""


## Ajuda em 3 degraus no fluxo v3: gesto (pulso no alvo), radio do Farol 7 (chave do passo) e seta no alvo; progresso
## apaga a seta. Tempo simulado pelo MissionHelp (sem esperar 35 s).
func _help_tiers() -> void:
	Ep01V3Main.start_mission = &"M2"
	Ep01V3Main.save_path = ""
	var main := await _new_main()
	await r.frames(3)
	if main.hud.handoff_open:
		await _tap(&"interact")
		await r.frames(3)
	var said: Array[String] = []
	main.hud.line_started.connect(func(k: String) -> void: said.append(k))
	var tiers: Array[int] = []
	main.help.gesture_hint.connect(func(_t: StringName, _k: StringName) -> void: tiers.append(1))
	main.help.radio_hint.connect(func(_k: StringName) -> void: tiers.append(2))
	main.help.pointer_hint.connect(func(_t: StringName, _m: bool) -> void: tiers.append(3))
	# E6: no jogo a ajuda so vem apos ~10 s parado, quando as falas da abertura ja terminaram; aqui o tempo e forcado.
	main.hud.clear_speech()
	await r.frames(2)
	main.help.tick(10.5)
	main.help.tick(10.0)
	main.help.tick(15.0)
	await r.frames(3)
	r.check(tiers == [1, 2, 3], "v3 ajuda: 3 degraus em ordem %s" % str(tiers))
	r.check(said.has("ep01.radio.v3_m2.free_pieces"), "v3 ajuda: Farol 7 fala a dica do passo %s" % str(said))
	var t := main.help_target()
	r.check(main.arrow.visible and t != null and Vector2(main.arrow.global_position.x - t.global_position.x,
		main.arrow.global_position.z - t.global_position.z).length() < 0.05, "v3 ajuda: seta sobre o alvo do passo")
	await _tap(&"help")
	r.check(main.help.tier == 3, "v3 ajuda: botao de ajuda no ultimo degrau nao quebra")
	main.current.notify(&"piece_freed", &"climber")
	await r.frames(2)
	r.check(not main.arrow.visible and main.help.tier == 0, "v3 ajuda: progresso apaga a seta e zera a ajuda")
	# Entrega errada no mercado: sem castigo (carga fica, nada volta).
	await _free(main)
	Ep01V3Main.start_mission = &""


## Mercado: entrega na barraca errada nao castiga (carga fica, progresso igual) e mostra a barraca certa (seta);
## a caixa estatica do carrinho gerado fica desligada so durante o M4.
func _market_wrong_stall() -> void:
	Ep01V3Main.start_mission = &"M4"
	Ep01V3Main.save_path = ""
	var main := await _new_main()
	var shape := main.world.get_node_or_null(Ep01V3Land.CART_STATIC_SHAPE) as CollisionShape3D
	r.check(shape != null and shape.disabled, "v3 M4: caixa estatica do carrinho desligada durante o M4")
	r.check(main.land.cart != null and main.land.cart.global_position.distance_to(Vector3(-18.6, 0, 0.8)) < 0.05,
		"v3 M4: carrinho dirigivel no lugar do carrinho do mundo")
	main.current.notify(&"icons_read", &"tracker")
	await r.frames(3)
	r.check(main.hud.handoff_open, "v3 M4: entregar pede a Leme (cartao de troca)")
	await r.tree.create_timer(0.6).timeout
	await _tap(&"interact")
	await r.tree.create_timer(1.5).timeout
	r.check(main.active_member == &"pilot", "v3 M4: Leme em controle depois do cartao")
	main.land._on_spot(&"take_cart", main.actors[&"pilot"])
	var before := main.current.step_progress
	main.land._on_spot(&"deliver_M4_Stall_Lemon", main.actors[&"pilot"])
	await r.frames(2)
	r.check(main.current.step_progress == before and main.land.cargo_stall() == &"M4_Stall_Apple",
		"v3 M4: barraca errada nao conta e a carga fica no carrinho")
	r.check(main.arrow.visible, "v3 M4: barraca errada mostra a seta na barraca certa")
	main.land._on_spot(&"deliver_M4_Stall_Apple", main.actors[&"pilot"])
	await r.frames(2)
	r.check(main.current.step_progress == before + 1 and main.land.cargo_stall() == &"M4_Stall_Lemon",
		"v3 M4: barraca certa conta e passa para a proxima carga")
	main.land.build(&"M5")
	await r.frames(2)
	r.check(shape != null and not shape.disabled, "v3 M4: fora do M4 a caixa estatica do carrinho volta")
	await _free(main)
	Ep01V3Main.start_mission = &""
