extends RefCounted
## G21i (RB-R1): o plano 9 da abertura vira 9_out, 9a, 9b e 9c na base Farol 7 com o Lumi (lumi_v2). Roda a
## GameIntroScene de verdade (tempo acelerado) e confere, a cada plano da base: palco visivel e vila escondida, o Lumi
## filho do palco (sentado na cadeira no 9a), clipe pedido, cabeca dentro do quadro, fala no corte e plano do tamanho
## G17; no 9c a legenda desenha {help} com glifo e o disco da ajuda aparece e pulsa. Tambem: carga do palco fora da
## tela de carregamento, cortes com movimento reduzido e textos/vozes do Lumi. Nao comprova o visual (capturas).

const TIME_SCALE := 4.0
const BASE_SHOTS: Array[String] = ["9_out", "9a", "9b", "9c"]
const CLIPS := {"9a": &"turn_chair", "9b": &"wave", "9c": &"point"}

var r


func run(runner) -> void:
	r = runner
	_data()
	_texts_and_voice()
	await _play()
	_reduced_motion()


static func _intro_shots() -> Array:
	return Ep01V3Cutscene.scene_data(&"game_intro").get("shots", [])


func _data() -> void:
	var shots := _intro_shots()
	var ids: Array[String] = []
	for sh: Variant in shots:
		ids.append(str((sh as Dictionary).get("id", "")))
	var at := ids.find("9_out")
	r.check(at == 8 and ids.slice(8, 12) == BASE_SHOTS and shots.size() == 13,
		"G21i: plano 9 trocado por 9_out, 9a, 9b, 9c (planos %s)" % str(ids))
	var old_gone := true
	for sh: Variant in shots:
		if str((sh as Dictionary).get("move", "")) == "orbit" and str(((sh as Dictionary).get("look", {}) as Dictionary).get("marker", "")) == "M7_LanternPivot":
			old_gone = false
	r.check(old_gone, "G21i: o plano antigo do farol da vila (orbit M7_LanternPivot) saiu")
	var last: Dictionary = shots[-1]
	r.check(str((last["line"] as Dictionary)["key"]) == "ep01.narrator.intro.call" and float(last["duration"]) == 4.0,
		"G21i: plano 10 sem mudanca (intro.call, 4,0 s)")
	var exit: Dictionary = Ep01V3Cutscene.scene_data(&"game_intro")["exit_look"]
	r.check(str(exit["marker"]) == "M0_BoatDocked", "G21i: exit_look sem mudanca")
	var lines := {}
	for i in range(8, 12):
		var sh: Dictionary = shots[i]
		lines[sh["id"]] = str((sh.get("line", {}) as Dictionary).get("key", ""))
	r.check(lines == {"9_out": "", "9a": "ep01.narrator.intro.base", "9b": "ep01.radio.intro.hello", "9c": "ep01.radio.intro.help"},
		"G21i: falas dos planos da base %s" % str(lines))


func _texts_and_voice() -> void:
	var want := {
		"ep01.narrator.intro.base": "E aqui é o Farol 7, a base da equipe!",
		"ep01.radio.intro.hello": "Na escuta! Sou o Lumi, do rádio.",
		"ep01.radio.intro.help": "Precisou? Aperte {help} que eu ajudo!",
		"ep01.radio.help.invite_1": "Na escuta! É o Lumi. Quer ajuda?",
		"ep01.radio.help.invite_4": "Uma dica? Aqui é o Lumi!",
		"member.radio.name": "Lumi"}
	var bad: Array[String] = []
	for k: String in want:
		if Loc.t(k) != want[k]:
			bad.append("%s=%s" % [k, Loc.t(k)])
	r.check(bad.is_empty(), "G21i: textos do Lumi no catalogo %s" % str(bad))
	r.check(Loc.member_name(&"radio") == "Lumi", "G21i: a legenda do radio diz Lumi (%s)" % Loc.member_name(&"radio"))
	VoiceCatalog.reload()
	var v3 := VoiceCatalog.v3_lines()
	var pending := VoiceCatalog.v3_pending()
	var not_pending: Array[String] = []
	for k: String in ["ep01.narrator.intro.base", "ep01.radio.intro.hello", "ep01.radio.intro.help",
			"ep01.radio.help.invite_1", "ep01.radio.help.invite_4"]:
		if v3.has(k) or not pending.has(k):
			not_pending.append(k)
	r.check(not_pending.is_empty(), "G21i: falas novas/trocadas sem take antigo e pendentes para o lote %s" % str(not_pending))
	r.check(not FileAccess.file_exists("res://audio/voice/v3/ep01_radio_intro_hello.visemes.json"),
		"G21i: visemas do take antigo da intro.hello removidos")
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://episodes/ep01/v3/ep01_v3_dialogue.json"))
	var spoken: Dictionary = d.get("spoken", {})
	r.check(str(spoken.get("ep01.radio.intro.help", "")) == "Precisou? Aperte o botão de ajuda que eu ajudo!",
		"G21i: texto falado da intro.help sem o glifo (%s)" % str(spoken.get("ep01.radio.intro.help", "")))
	# toda fala com marcador de glifo tem texto falado (a voz nao le "{help}")
	var no_spoken: Array[String] = []
	for k: String in d.get("lines", {}):
		if Loc.t(k).contains("{") and not spoken.has(k):
			no_spoken.append(k)
	for sh: Variant in _intro_shots():
		var k := Ep01V3Cutscene.line_key(sh as Dictionary)
		if k != "" and Loc.t(k).contains("{") and not spoken.has(k):
			no_spoken.append(k)
	r.check(no_spoken.is_empty(), "G21i: fala com marcador tem texto falado %s" % str(no_spoken))


func _play() -> void:
	var was := Ep01V3Cutscene.enabled
	var was_seen := Ep01V3Cutscene.seen_path
	Ep01V3Cutscene.enabled = true
	Ep01V3Cutscene.seen_path = ""
	Ep01V3Cutscene.reset_seen()
	GameIntroScene.next_scene = ""
	var intro := (load(GameIntroScene.SELF_SCENE) as PackedScene).instantiate() as GameIntroScene
	r.tree.root.add_child(intro)
	r.tree.current_scene = intro
	r.check(intro.stage == null and (SceneLoaderService.bg_pending() or SceneLoaderService.bg_status(GameIntroScene.STAGE_SCENE) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE),
		"G21i: o palco carrega em segundo plano pela fila do SceneLoader, fora do _ready da abertura")
	var cs := intro.cutscene
	var hud := intro.hud
	var shots := _intro_shots()
	var starts: Dictionary = {}
	hud.line_started.connect(func(k: String) -> void: starts[k] = [cs.shot_index, cs.shot_time])
	Engine.time_scale = TIME_SCALE
	r.check(not hud.help_spotlit(), "G21i: disco da ajuda nao fica em destaque antes do 9c")
	var entered: Dictionary = {}
	cs.shot_entered.connect(func(i: int, _sh: Dictionary) -> void: entered[i] = cs.time)
	for i in range(8, 12):
		var sh: Dictionary = shots[i]
		var id := str(sh["id"])
		while cs.playing and cs.shot_index < i:
			await r.tree.process_frame
		await r.frames(2)
		var st := intro.stage
		if i == 8:
			r.check(st != null and intro.stage_from_queue, "G21i: palco veio da fila em segundo plano (sem load sincrono)")
		r.check(st != null and st.visible and intro.village_hidden() and not (intro.world.get_node("Static") as Node3D).visible,
			"G21i %s: palco da base visivel, vila escondida" % id)
		var lumi := cs.actors.get(&"radio") as Node3D
		if id == "9_out":
			r.check(lumi == null or not lumi.is_visible_in_tree() or not _in_frame(cs.camera, lumi.global_position + Vector3(0, 1.0, 0)),
				"G21i 9_out: casa-torre por fora, sem o Lumi no quadro")
			continue
		r.check(lumi != null and st.is_ancestor_of(lumi), "G21i %s: Lumi (lumi_v2) no palco" % id)
		if lumi == null:
			continue
		var cv := StoryFigure.visual(lumi)
		r.check(cv != null and cv.current_animation() == CLIPS[id], "G21i %s: clipe %s (%s)" % [id, CLIPS[id], cv.current_animation() if cv != null else &"?"])
		if id == "9a":
			r.check(lumi.get_parent() == st.get_node("Chair/Seat"), "G21i 9a: Lumi sentado, filho de Chair/Seat")
		else:
			r.check(lumi.get_parent() == st.get_node("Actors"), "G21i %s: Lumi de pe (levantou da cadeira)" % id)
		var head := lumi.global_position + Vector3(0, 1.1 if id == "9a" else 1.55, 0)
		r.check(_in_frame(cs.camera, head), "G21i %s: cabeca do Lumi dentro do quadro (%s)" % [id, str(_frame_pos(cs.camera, head))])
		var key := Ep01V3Cutscene.line_key(sh)
		var s: Array = starts.get(key, [-1, 99.0])
		r.check(int(s[0]) == i and float(s[1]) <= 0.05, "G21i %s: a fala %s comeca no corte (plano %d, %.3f s)" % [id, key, s[0], s[1]])
		var need := Hud.line_seconds(key, Ep01V3Cutscene.voice_seconds(key))
		r.check(Ep01V3Cutscene.shot_length(sh) >= maxf(float(sh["duration"]), need) - 0.0001,
			"G21i %s: plano dura >= max(ficha, voz/leitura + folga) (%.2f >= %.2f)" % [id, Ep01V3Cutscene.shot_length(sh), need])
		if id == "9c":
			var g := hud.subtitle_glyphs()
			var acts: Array[StringName] = []
			if g != null:
				for gv in g.glyphs():
					acts.append(gv.action)
			r.check(g != null and acts == [&"help"] and not g.plain_text().contains("{"),
				"G21i 9c: legenda desenha {help} com o glifo do aparelho (%s / %s)" % [str(acts), g.plain_text() if g != null else "?"])
			r.check(hud.help_spotlit() and hud.help_pulsing(), "G21i 9c: disco da ajuda visivel e pulsando")
			var s0 := (hud.find_child("HelpButton", true, false) as Control).scale
			await r.frames(8)
			var s1 := (hud.find_child("HelpButton", true, false) as Control).scale
			r.check(s0 != s1, "G21i 9c: o disco muda de tamanho (pulso) %s -> %s" % [str(s0), str(s1)])
			r.check(not (hud.find_child("ObjectivePanel", true, false) as CanvasItem).is_visible_in_tree(),
				"G21i 9c: so o disco no canto (objetivo escondido)")
		else:
			r.check(not hud.help_spotlit(), "G21i %s: disco da ajuda fora de destaque" % id)
	# duracao medida do plano (G17): do corte ao corte seguinte, em tempo de cena
	while cs.playing and cs.shot_index < 12:
		await r.tree.process_frame
	await r.frames(2)
	var bad_len: Array[String] = []
	for i in range(8, 12):
		var got := float(entered.get(i + 1, 0.0)) - float(entered.get(i, 0.0))
		var want := Ep01V3Cutscene.shot_length(shots[i])
		if absf(got - want) > 0.25:
			bad_len.append("%s %.2f x %.2f" % [shots[i]["id"], got, want])
	r.check(bad_len.is_empty(), "G21i: planos da base duram o que o G17 calcula %s" % str(bad_len))
	r.check(not intro.village_hidden() and not intro.stage.visible and (intro.world.get_node("Static") as Node3D).visible
		and not hud.help_spotlit(), "G21i: no plano 10 a vila volta, o palco some e o disco sai do destaque")
	while cs.playing:
		await r.tree.process_frame
	Engine.time_scale = 1.0
	r.check(not cs.actors.has(&"radio"), "G21i: o Lumi temporario sai ao fim da cena")
	print("[RB] G21i abertura: %.2f s (ficha %.1f s); fallbacks: %s" % [Ep01V3Cutscene.scene_length(&"game_intro"),
		float(Ep01V3Cutscene.scene_data(&"game_intro")["duration"]), ", ".join(cs.fallbacks)])
	r.tree.current_scene = null
	intro.queue_free()
	await r.frames(3)
	GameIntroScene.next_scene = GameIntroScene.EP01_SCENE
	Ep01V3Cutscene.enabled = was
	Ep01V3Cutscene.seen_path = was_seen
	Ep01V3Cutscene.reset_seen()


func _reduced_motion() -> void:
	var cs := Ep01V3Cutscene.new()
	cs.reduced_motion = true
	var bad: Array[String] = []
	for i in range(8, 12):
		var sh: Dictionary = _intro_shots()[i]
		var a := cs.shot_pose(sh, 0.0)
		var b := cs.shot_pose(sh, 0.7)
		if a[0] != b[0] or a[1] != b[1]:
			bad.append(str(sh["id"]))
	cs.free()
	r.check(bad.is_empty(), "G21i: com movimento reduzido os planos da base sao cortes %s" % str(bad))


static func _frame_pos(cam: Camera3D, p: Vector3) -> Vector2:
	var vp := cam.get_viewport().get_visible_rect().size
	return cam.unproject_position(p) / vp


static func _in_frame(cam: Camera3D, p: Vector3) -> bool:
	if cam.is_position_behind(p):
		return false
	var f := _frame_pos(cam, p)
	return f.x > 0.05 and f.x < 0.95 and f.y > 0.05 and f.y < 0.95
