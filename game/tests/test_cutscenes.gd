extends RefCounted
## D21 (RB-R1): player de cutscenes (Ep01V3Cutscene) e abertura do jogo (GameIntroScene). Cada cena roda do comeco ao
## fim e devolve o controle; pular so depois de vista; `exit_look` aplicado; seguidores religados; entrada bloqueada;
## movimento reduzido vira corte; o bot M0->M8 conclui com as cenas (todas tocadas e todas puladas) e mede o acrescimo.
## Tempo acelerado (deterministico). Nao comprova render, som nem leitura pela crianca.

const TIME_SCALE := 8.0
const MAX_FRAMES := 40000
const SEEN_TEST := "user://test_cutscenes.seen.json"

var r


func run(runner) -> void:
	r = runner
	Ep01V3Cutscene.seen_path = ""
	Ep01V3Cutscene.reset_seen()
	await _data_checks()
	_seen_store()
	await _each_scene()
	await _skip_rules()
	await _reduced_motion()
	await _game_intro()
	_menu_target()
	await _bot_with_cutscenes()
	Ep01V3Cutscene.enabled = false
	Ep01V3Cutscene.auto_skip = false
	Ep01V3Cutscene.seen_path = ""
	Ep01V3Cutscene.reset_seen()


func _new_main(cutscenes: bool) -> Ep01V3Main:
	Ep01V3Cutscene.enabled = cutscenes
	var main := (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	r.tree.root.add_child(main)
	r.tree.current_scene = main
	await r.frames(3)
	return main


func _free(main: Node) -> void:
	Engine.time_scale = 1.0
	if r.tree.current_scene == main:
		r.tree.current_scene = null
	main.queue_free()
	await r.frames(3)


func _wait_end(cs: Ep01V3Cutscene, limit_s: float = 60.0) -> void:
	var t0 := Time.get_ticks_msec()
	while cs.playing and Time.get_ticks_msec() - t0 < limit_s * 1000.0:
		await r.tree.process_frame


func _data_checks() -> void:
	var ids := Ep01V3Cutscene.scene_ids()
	r.check(ids.size() == 13 and ids.has(&"game_intro") and ids.has(&"closing"), "cutscene: 13 cenas na ficha (%d)" % ids.size())
	var main := await _new_main(false)
	var missing: Array[String] = []
	var keys_missing: Array[String] = []
	for id in ids:
		var s := Ep01V3Cutscene.scene_data(id)
		var refs: Array = [s.get("exit_look", {})]
		for sh: Variant in s.get("shots", []):
			var d := sh as Dictionary
			for k: String in ["from", "to", "look", "look_to"]:
				if d.has(k):
					refs.append(d[k])
			refs.append_array(d.get("actors", []))
			var line: Variant = d.get("line")
			if line is Dictionary and not Loc.has_key(str((line as Dictionary).get("key", ""))):
				keys_missing.append(str((line as Dictionary).get("key", "")))
		for ref: Variant in refs:
			var mk := StringName(str((ref as Dictionary).get("marker", "")))
			if main.world.marker(mk) == null:
				missing.append("%s:%s" % [id, mk])
	r.check(missing.is_empty(), "cutscene: todos os marcadores existem na vila %s" % str(missing))
	r.check(keys_missing.is_empty(), "cutscene: todas as falas estao no catalogo %s" % str(keys_missing))
	r.check(Loc.has_key("ui.menu.watch_intro") and Loc.has_key("ui.cutscene.skip"), "cutscene: textos do menu e do pular no catalogo")
	r.check(main.cutscene != null and not main.cutscene.playing, "cutscene: desligadas, o episodio comeca sem cena")
	await _free(main)


func _seen_store() -> void:
	Ep01V3Cutscene.seen_path = SEEN_TEST
	Ep01V3Cutscene.reset_seen()
	r.check(not Ep01V3Cutscene.is_seen(&"m1_intro"), "cutscene: salvo de vistas comeca vazio")
	Ep01V3Cutscene.mark_seen(&"m1_intro")
	Ep01V3Cutscene.seen_path = ""
	Ep01V3Cutscene.reset_seen()
	r.check(not Ep01V3Cutscene.is_seen(&"m1_intro"), "cutscene: memoria separada do arquivo")
	Ep01V3Cutscene.seen_path = SEEN_TEST
	r.check(Ep01V3Cutscene.is_seen(&"m1_intro") and FileAccess.file_exists(SEEN_TEST), "cutscene: vista gravada e relida do arquivo")
	Ep01V3Cutscene.reset_seen()
	r.check(not FileAccess.file_exists(SEEN_TEST), "cutscene: reset apaga o arquivo de teste")
	Ep01V3Cutscene.seen_path = ""
	Ep01V3Cutscene.reset_seen()


## Toca cada cena do episodio pelo contrato do jogo (play_cutscene) e confere a saida.
func _each_scene() -> void:
	var main := await _new_main(false)
	Ep01V3Cutscene.enabled = true
	var cs := main.cutscene
	var all_fallbacks: Array[String] = []
	for id in Ep01V3Cutscene.scene_ids():
		if id == &"game_intro":
			continue
		var shots: int = (Ep01V3Cutscene.scene_data(id).get("shots", []) as Array).size()
		Engine.time_scale = TIME_SCALE
		var during := {"blocked": false, "nobody": true, "followers": true, "bars": false, "cam": false}
		var done := [false]
		var t0 := Time.get_ticks_msec()
		(func() -> void:
			await main.play_cutscene(id)
			done[0] = true).call()
		await r.frames(4)
		during["blocked"] = main.blocked()
		during["followers"] = main.followers_enabled
		during["bars"] = cs.bar_height() > 0.0 or cs.reduced_motion
		during["cam"] = cs.camera.current
		for m: StringName in main.actors:
			if (main.actors[m] as MemberActor).controlled:
				during["nobody"] = false
		var limit := 20000
		while not done[0] and limit > 0:
			await r.tree.process_frame
			limit -= 1
		Engine.time_scale = 1.0
		await r.frames(2)
		r.check(done[0] and not cs.playing and cs.shots_played == shots,
			"cutscene %s: rodou %d/%d planos ate o fim (%.1f s reais)" % [id, cs.shots_played, shots, (Time.get_ticks_msec() - t0) / 1000.0])
		r.check(during["blocked"] and during["nobody"] and not during["followers"] and during["cam"],
			"cutscene %s: durante a cena entrada bloqueada, ninguem em controle, seguidores desligados, camera da cena" % id)
		r.check(during["bars"], "cutscene %s: barras de cinema" % id)
		var ctrl := main.controlled_node
		var back := ctrl != null and (ctrl == main.boat or (ctrl as MemberActor).controlled) and main.followers_enabled \
			and main.camera_rig.camera.current and not main.blocked()
		r.check(back, "cutscene %s: controle, seguidores e camera do jogo de volta" % id)
		var p := cs.exit_point(id)
		var cam := main.camera_rig.camera
		var fwd := -cam.global_transform.basis.z
		fwd.y = 0.0
		var want := p - ctrl.global_position
		want.y = 0.0
		var dot := fwd.normalized().dot(want.normalized()) if want.length() > 0.3 else 1.0
		r.check(dot > 0.9, "cutscene %s: camera do jogo aponta para o exit_look (cos %.2f)" % [id, dot])
	for f in cs.fallbacks:
		if not all_fallbacks.has(f):
			all_fallbacks.append(f)
	print("[RB] cutscene fallbacks: ", ", ".join(all_fallbacks))
	r.check(all_fallbacks.is_empty(), "cutscene: nenhum clipe/ator no fallback no Ep01 (Amora 3D incluida) %s" % str(all_fallbacks))
	r.check(main.world.get_node_or_null("Cutscene_vendor") == null, "cutscene: figurante temporario (Amora) removido ao fim")
	r.check(main.world.night or main.world.festival, "cutscene: cair da noite liga a noite na vila")
	await _free(main)


func _press_interact() -> void:
	var ev := InputEventAction.new()
	ev.action = &"interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await r.frames(2)
	var up := InputEventAction.new()
	up.action = &"interact"
	up.pressed = false
	Input.parse_input_event(up)
	await r.frames(1)


func _skip_rules() -> void:
	Ep01V3Cutscene.reset_seen()
	var main := await _new_main(false)
	Ep01V3Cutscene.enabled = true
	var cs := main.cutscene
	main.play_cutscene(&"m2_intro")
	await r.frames(5)
	r.check(cs.playing and not cs.skippable and not cs.skip_hint_visible(), "cutscene: primeira vez nao e pulavel (sem dica de pular)")
	await _press_interact()
	await r.frames(3)
	r.check(cs.playing, "cutscene: interact na primeira vez nao pula")
	var hero := main.controlled_node as MemberActor
	var before := hero.global_position
	Input.action_press(&"move_up")
	await r.frames(20)
	Input.action_release(&"move_up")
	r.check(hero.global_position.distance_to(before) < 0.05, "cutscene: andar bloqueado durante a cena")
	Engine.time_scale = TIME_SCALE
	await _wait_end(cs)
	Engine.time_scale = 1.0
	await r.frames(2)
	r.check(Ep01V3Cutscene.is_seen(&"m2_intro"), "cutscene: vista anotada ao terminar")
	var skipped := [false]
	cs.finished.connect(func(_id: StringName, s: bool) -> void: skipped[0] = s, CONNECT_ONE_SHOT)
	main.play_cutscene(&"m2_intro")
	await r.frames(5)
	r.check(cs.playing and cs.skippable and cs.skip_hint_visible(), "cutscene: ja vista, e pulavel e mostra a dica")
	var t := cs.time
	await _press_interact()
	await r.frames(3)
	r.check(not cs.playing and skipped[0] and t < 1.0, "cutscene: interact pula a cena ja vista")
	r.check((main.controlled_node as MemberActor).controlled and main.followers_enabled, "cutscene: controle volta depois de pular")
	await _free(main)


func _reduced_motion() -> void:
	var main := await _new_main(false)
	Ep01V3Cutscene.enabled = true
	var cs := main.cutscene
	var sh: Dictionary = (Ep01V3Cutscene.scene_data(&"opening")["shots"] as Array)[0]
	cs.reduced_motion = false
	var a: Array[Vector3] = cs.shot_pose(sh, 0.0)
	var b: Array[Vector3] = cs.shot_pose(sh, 1.0)
	var mid: Array[Vector3] = cs.shot_pose(sh, 0.5)
	r.check(a[0].distance_to(b[0]) > 1.0 and mid[0].distance_to(a[0].lerp(b[0], 0.5)) < 0.01,
		"cutscene: dolly desliza suave de from para to")
	cs.reduced_motion = true
	var c0: Array[Vector3] = cs.shot_pose(sh, 0.0)
	var c1: Array[Vector3] = cs.shot_pose(sh, 0.6)
	r.check(c0[0].distance_to(c1[0]) < 0.001 and c0[0].distance_to(b[0]) < 0.001,
		"cutscene: movimento reduzido vira corte (enquadramento final parado)")
	var pan: Dictionary = (Ep01V3Cutscene.scene_data(&"opening")["shots"] as Array)[2]
	var p0: Array[Vector3] = cs.shot_pose(pan, 0.0)
	var p1: Array[Vector3] = cs.shot_pose(pan, 0.9)
	r.check(p0[1].distance_to(p1[1]) < 0.001, "cutscene: pan com movimento reduzido nao gira")
	Engine.time_scale = TIME_SCALE
	main.play_cutscene(&"m1_intro")
	await r.frames(3)
	var pos := cs.camera.global_position
	await r.frames(10)
	r.check(cs.camera.global_position.distance_to(pos) < 0.001 and cs.bar_height() > 0.0,
		"cutscene: com movimento reduzido a camera nao se move dentro do plano; barras sem animar")
	await _wait_end(cs)
	await _free(main)


func _game_intro() -> void:
	Ep01V3Cutscene.enabled = true
	Ep01V3Cutscene.reset_seen()
	GameIntroScene.next_scene = ""
	var intro := (load(GameIntroScene.SELF_SCENE) as PackedScene).instantiate() as GameIntroScene
	r.tree.root.add_child(intro)
	r.tree.current_scene = intro
	await r.frames(4)
	var cs := intro.cutscene
	r.check(cs.playing and cs.scene_id == &"game_intro" and not cs.skippable, "abertura: toca e nao pula na primeira vez")
	await _press_interact()
	r.check(cs.playing, "abertura: interact nao pula na primeira vez")
	Engine.time_scale = TIME_SCALE
	await _wait_end(cs)
	Engine.time_scale = 1.0
	var shots: int = (Ep01V3Cutscene.scene_data(&"game_intro")["shots"] as Array).size()
	r.check(not cs.playing and cs.shots_played == shots and cs.lines_said.size() >= 9,
		"abertura: %d/%d planos e %d falas" % [cs.shots_played, shots, cs.lines_said.size()])
	r.check(Ep01V3Cutscene.is_seen(&"game_intro"), "abertura: anotada como vista")
	print("[RB] game_intro fallbacks: ", ", ".join(cs.fallbacks))
	await _free(intro)
	intro = (load(GameIntroScene.SELF_SCENE) as PackedScene).instantiate() as GameIntroScene
	r.tree.root.add_child(intro)
	r.tree.current_scene = intro
	await r.frames(4)
	r.check(intro.cutscene.skippable, "abertura: revista pelo menu, e pulavel")
	await _press_interact()
	r.check(not intro.cutscene.playing, "abertura: interact pula a abertura ja vista")
	await _free(intro)
	GameIntroScene.next_scene = GameIntroScene.EP01_SCENE


func _menu_target() -> void:
	Ep01V3Cutscene.enabled = true
	Ep01V3Cutscene.reset_seen()
	r.check(GameIntroScene.play_target() == GameIntroScene.SELF_SCENE, "menu: Jogar na primeira vez abre a abertura do jogo")
	Ep01V3Cutscene.mark_seen(&"game_intro")
	r.check(GameIntroScene.play_target() == GameIntroScene.EP01_SCENE, "menu: depois de vista, Jogar vai direto ao Ep01")
	Ep01V3Cutscene.enabled = false
	r.check(GameIntroScene.play_target() == GameIntroScene.EP01_SCENE, "menu: cenas desligadas, Jogar vai direto ao Ep01")
	var src := FileAccess.get_file_as_string("res://ui/main_menu.gd")
	r.check(src.contains("ui.menu.watch_intro") and src.contains("GameIntroScene.MENU_SCENE"), "menu: botao Ver abertura volta ao menu")


func _run_bot(main: Ep01V3Main) -> Ep01V3Bot:
	var bot := Ep01V3Bot.new()
	bot.main = main
	main.add_child(bot)
	Engine.time_scale = TIME_SCALE
	var frames := 0
	while not bot.done and frames < MAX_FRAMES:
		await r.tree.process_frame
		frames += 1
	Engine.time_scale = 1.0
	Ep01V3Bot.release_all()
	return bot


## Bot M0->M8: todas as cenas tocadas (nenhuma vista) e todas puladas (flag de teste). A diferenca e o acrescimo.
func _bot_with_cutscenes() -> void:
	Ep01V3Cutscene.reset_seen()
	Ep01V3Cutscene.auto_skip = false
	var main := await _new_main(true)
	var started: Array[StringName] = []
	main.cutscene.finished.connect(func(id: StringName, _s: bool) -> void: started.append(id))
	var bot := await _run_bot(main)
	var full := bot.elapsed
	r.check(bot.done and bot.fail_reason == "", "cutscene bot: M0->M8 com todas as cenas (%s; %.1f s de jogo)" % [bot.fail_reason, full])
	var expect := Ep01V3Cutscene.scene_ids().size() - 1
	r.check(started.size() == expect, "cutscene bot: %d/%d cenas do Ep01 tocadas %s" % [started.size(), expect, str(started)])
	await _free(main)
	Ep01V3Cutscene.auto_skip = true
	main = await _new_main(true)
	bot = await _run_bot(main)
	var skipped := bot.elapsed
	r.check(bot.done and bot.fail_reason == "", "cutscene bot: M0->M8 com as cenas puladas (%.1f s de jogo)" % skipped)
	print("[RB] cutscene episodio: com cenas %.1f s, puladas %.1f s, acrescimo %.1f s" % [full, skipped, full - skipped])
	Ep01V3Cutscene.auto_skip = false
	await _free(main)
