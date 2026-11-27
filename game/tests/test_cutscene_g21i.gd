extends RefCounted
## G21i (RB-R1): o plano 9 da abertura vira 9_out, 9a, 9b e 9c na base Farol 7 com o Lumi (lumi_v2). Roda a
## GameIntroScene de verdade (tempo acelerado) e confere, a cada plano da base: palco visivel e vila escondida, o Lumi
## filho do palco (sentado na cadeira no 9a), clipe pedido, cabeca dentro do quadro, fala no corte e plano do tamanho
## G17; no 9c o Lumi aponta no trecho "aperte o botao de ajuda" e o disco da ajuda aparece e pulsa. Tambem: carga do palco fora da
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
		"ep01.radio.intro.help": "Precisou? Aperte o botão de ajuda que eu ajudo!",
		"ep01.radio.help.invite_1": "Na escuta! É o Lumi. Quer ajuda?",
		"ep01.radio.help.invite_4": "Uma dica? Aqui é o Lumi!",
		"member.radio.name": "Lumi"}
	var bad: Array[String] = []
	for k: String in want:
		if Loc.t(k) != want[k]:
			bad.append("%s=%s" % [k, Loc.t(k)])
	r.check(bad.is_empty(), "G21i: textos do Lumi no catalogo %s" % str(bad))
	# retrato do radio: rosto do Lumi em toda fala `radio` do Ep01 v3 (abertura, dicas, convites)
	var hud := Hud.new()
	r.tree.root.add_child(hud)
	var d0: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://episodes/ep01/v3/ep01_v3_dialogue.json"))
	var radio_keys: Array[String] = []
	for k: String in d0.get("lines", {}):
		if hud.speaker_for(k) == &"radio":
			radio_keys.append(k)
	var tex := hud.speaker_texture(&"radio")
	r.check(radio_keys.size() >= 20 and tex != null and tex.resource_path == "res://ui/portraits/lumi_neutra.png",
		"G21i: %d falas radio do Ep01 v3 mostram o retrato do Lumi (%s)" % [radio_keys.size(), tex.resource_path if tex != null else "icone do farol"])
	hud.queue_free()
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
	# Decisao de Thiago: o jogo e multiplataforma, nenhuma fala do Ep01 cita tecla/botao por marcador ({...}); a
	# legenda e igual ao que a voz diz (sem texto falado separado).
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://episodes/ep01/v3/ep01_v3_dialogue.json"))
	var marked: Array[String] = []
	var keys: Array = d.get("lines", {}).keys()
	for gid: String in d.get("groups", {}):
		keys.append_array(d["groups"][gid])
	for id in Ep01V3Cutscene.scene_ids():
		for sh: Variant in Ep01V3Cutscene.scene_data(id).get("shots", []):
			keys.append(Ep01V3Cutscene.line_key(sh as Dictionary))
	for k: Variant in keys:
		if str(k) != "" and Loc.t(str(k)).contains("{"):
			marked.append(str(k))
	r.check(marked.is_empty() and not d.has("spoken"), "G21i: nenhuma fala do Ep01 v3 usa marcador {...} nem texto falado separado %s" % str(marked))


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
			_sea_checks(intro, cs, sh)
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
		var por := hud.find_child("SpeakerPortrait", true, false) as IconView
		if key.begins_with("ep01.radio."):
			r.check(por != null and por.texture_override != null and por.texture_override.resource_path.contains("lumi"),
				"G21i %s: retrato da legenda e o rosto do Lumi (%s)" % [id, por.texture_override.resource_path if por != null and por.texture_override != null else "icone"])
		if id == "9b" or id == "9c":
			await _arm_samples(cs, lumi, i, id)
		if id == "9c":
			r.check(hud.subtitle_glyphs() == null, "G21i 9c: legenda em texto puro, igual a fala (sem glifo de tecla)")
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


## 9_out: o mar (agua da vila, opaca) esta visivel e cobre toda a parte de baixo do quadro do plano inteiro: os raios
## dos cantos de baixo da camera batem no mar dentro do tamanho dele, com a camera acima da agua. Assim a laje do fundo
## do palco (abaixo do nivel do mar) nunca aparece.
func _sea_checks(intro: GameIntroScene, cs: Ep01V3Cutscene, sh: Dictionary) -> void:
	var sea := intro.sea_node
	var mat := sea.material_override as ShaderMaterial if sea != null else null
	r.check(sea != null and sea.is_visible_in_tree() and mat != null and float(mat.get_shader_parameter("alpha_shallow")) >= 1.0
		and float(mat.get_shader_parameter("alpha_deep")) >= 1.0, "G21i 9_out: mar opaco com o material da agua da vila")
	if sea == null:
		return
	var y := sea.global_position.y
	var half := (sea.mesh as PlaneMesh).size.x * 0.5
	var probe := Camera3D.new()
	probe.fov = cs.camera.fov
	cs.add_child(probe)
	var bad: Array[String] = []
	var vp := cs.camera.get_viewport().get_visible_rect().size
	for k in 11:
		var u := k / 10.0
		var pose := cs.shot_pose(sh, u)
		probe.global_position = pose[0]
		probe.look_at(pose[1], Vector3.UP)
		for px: Vector2 in [Vector2(0, vp.y), Vector2(vp.x, vp.y), Vector2(vp.x * 0.5, vp.y)]:
			var o := probe.project_ray_origin(px)
			var d := probe.project_ray_normal(px)
			if o.y <= y + 0.2 or d.y >= -0.0001:
				bad.append("u=%.1f %s sem mar" % [u, str(px)])
				continue
			var hit := o + d * ((y - o.y) / d.y)
			if absf(hit.x - sea.global_position.x) > half or absf(hit.z - sea.global_position.z) > half:
				bad.append("u=%.1f %s fora do mar" % [u, str(px)])
	probe.queue_free()
	r.check(bad.is_empty(), "G21i 9_out: o mar cobre a parte de baixo do quadro do plano inteiro (laje nunca aparece) %s" % str(bad))


## Braco direito do Lumi em varios pontos do plano: no 9c estendido (mao longe do quadril, na altura do ombro) enquanto
## a fala diz "aperte o botao de ajuda"; no 9b o aceno segue ate 80% do plano. Ao soltar, blend para idle.
func _arm_samples(cs: Ep01V3Cutscene, lumi: Node3D, i: int, id: String) -> void:
	var cv := StoryFigure.visual(lumi)
	var dur := Ep01V3Cutscene.shot_length(_intro_shots()[i])
	var bad: Array[String] = []
	var log: Array[String] = []
	# 9c: o trecho "aperte o botao de ajuda" ocupa ~21%-71% da fala (posicao dos caracteres na frase); amostras
	# nesse trecho, em fracao do tempo da fala no HUD (que comeca no corte).
	var key := Ep01V3Cutscene.line_key(_intro_shots()[i])
	var line_s := Hud.line_seconds(key, Ep01V3Cutscene.voice_seconds(key))
	var fracs: Array = [0.21, 0.35, 0.5, 0.62, 0.71] if id == "9c" else [0.25, 0.4, 0.55, 0.7]
	for frac: float in fracs:
		var at := frac * (line_s if id == "9c" else dur)
		while cs.playing and cs.shot_index == i and cs.shot_time < at:
			await r.tree.process_frame
		if cs.shot_index != i:
			bad.append("plano acabou antes de %.2f" % frac)
			break
		var hand := lumi.global_transform.affine_inverse() * cv.bone_position(&"hand.R")
		log.append("%.2f:%s y=%.2f fwd=%.2f" % [frac, cs.holding(&"radio"), hand.y, -hand.z])
		if id == "9c":
			var saying := cs.hud.is_speaking()
			# estendido: mao na altura do ombro (> 1,2 m; em repouso fica a ~0,79 m) e a frente do corpo (> 0,15 m; em
			# repouso ~0,08 m), com a fala no ar
			if not saying or cs.holding(&"radio") != &"point" or hand.y < 1.2 or -hand.z < 0.15:
				bad.append(log[-1])
		elif cs.holding(&"radio") != &"wave" or hand.y < 1.2:
			bad.append(log[-1])
	r.check(bad.is_empty(), "G21i %s: braco %s nas amostras do plano %s (ruins: %s)" % [id,
		"estendido apontando no trecho 'aperte o botao de ajuda'" if id == "9c" else "acenando no alto", str(log), str(bad)])
	while cs.playing and cs.shot_index == i and cs.holding(&"radio") != &"":
		await r.tree.process_frame
	r.check(cs.shot_index != i or StoryFigure.visual(lumi).current_animation() == &"idle",
		"G21i %s: depois do trecho, passa para idle com blend (%s)" % [id, StoryFigure.visual(lumi).current_animation()])


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
