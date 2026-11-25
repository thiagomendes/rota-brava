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
	# Camera baixa: altura da camera e fracao da tela ocupada pelo heroi (pes ao topo da cabeca ~1,12 m).
	await r.frames(5)
	var cam := main.camera_rig.camera
	var cam_h := cam.global_position.y - tracker.global_position.y
	r.check(absf(cam_h - CameraRig.LOW_OFFSET.y) < 0.1 and absf(cam.fov - CameraRig.LOW_FOV) < 0.01,
		"v3: camera baixa a %.2f m, FOV %.0f" % [cam_h, cam.fov])
	var frac := _hero_fraction(cam, tracker)
	r.check(frac > 0.24 and frac < 0.32, "v3: heroi ocupa %.1f%% da altura da tela (alvo ~28%%)" % (frac * 100.0))

	var started: Array[StringName] = []
	main.mission_started.connect(func(id: StringName) -> void: started.append(id))
	var bot := Ep01V3Bot.new()
	bot.main = main
	main.add_child(bot)
	var result := {"done": false, "ok": false}
	bot.finished.connect(func(ok: bool) -> void:
		result["done"] = true
		result["ok"] = ok)
	Engine.time_scale = TIME_SCALE
	var frames := 0
	while not result["done"] and frames < MAX_FRAMES:
		await r.tree.process_frame
		frames += 1
	Engine.time_scale = 1.0
	var done_ids: Array[StringName] = []
	for h: Dictionary in bot.history:
		done_ids.append(h["id"] as StringName)
	r.check(bool(result["ok"]), "v3: bot terminou M0->M8 com entrada real (%s; %.1f s de jogo) %s" % [
		bot.fail_reason, bot.elapsed, str(done_ids)])
	r.check(done_ids == ORDER, "v3: missoes concluidas em ordem M0..M8")
	r.check(main.complete and main.hud.complete_open, "v3: episodio concluido e tela de conclusao aberta")
	r.check(main.world.festival, "v3: vila em noite de festa no fim")
	await _free(main)


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
	main.notify_mission(&"marker_reached")
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
