extends RefCounted
## G17 (RB-R1): sincronia fala x plano em todas as cutscenes (abertura do jogo + Ep01). Roda cada cena com o HUD real
## e um voice_hook que devolve a duracao do .ogg real do catalogo (sem tocar som). A cada quadro: quem fala e o
## personagem em foco no plano atual (`focus` ou primeiro ator) ou o narrador/radio; cada fala comeca no quadro do
## corte do plano dela; nenhuma voz e cortada antes de acabar. Tempo acelerado. Nao comprova o som no aparelho.

const TIME_SCALE := 8.0
const FRAME_TOL := 0.2  # s de cena: um quadro a 8x com folga de CI

var r
var _key: String = ""
var _key_t: float = 0.0
var _cs: Ep01V3Cutscene


func run(runner) -> void:
	r = runner
	var was_enabled := Ep01V3Cutscene.enabled
	Ep01V3Cutscene.enabled = true
	Ep01V3Cutscene.seen_path = ""
	Ep01V3Cutscene.reset_seen()
	var root := Node3D.new()
	r.tree.root.add_child(root)
	var world := (load(GameIntroScene.WORLD_SCENE) as PackedScene).instantiate() as VillageWorld
	root.add_child(world)
	var hud := Hud.new()
	root.add_child(hud)
	# Como o AudioDirector.play_line: numa fala de radio com voz a duracao inclui os cliques (G20).
	hud.voice_hook = func(key: String) -> float: return _voice(key) + Hud.radio_extra_seconds(key) if _voice(key) > 0.0 else 0.0
	_cs = Ep01V3Cutscene.new()
	root.add_child(_cs)
	_cs.setup(world, hud, {})
	var line_frames: Array = []
	hud.line_started.connect(func(k: String) -> void:
		_key = k
		_key_t = _cs.time
		line_frames.append([k, _cs.time, _cs.shot_index]))
	hud.line_finished.connect(func() -> void: _key = "")
	_radio_shot_length()
	var voiced := 0
	for id in Ep01V3Cutscene.scene_ids():
		voiced += await _scene(id, hud, line_frames)
	r.check(voiced >= 8, "cutscene sync: ao menos 8 falas com voz real nas cenas (%d)" % voiced)
	Engine.time_scale = 1.0
	root.queue_free()
	await r.frames(3)
	Ep01V3Cutscene.enabled = was_enabled
	Ep01V3Cutscene.reset_seen()


## G20/G17: shot_length sem o piso da ficha (duration 0) em toda fala de radio com voz das cenas: tem de caber
## voz + cliques + folga. (Com a duracao da ficha o max esconderia um plano planejado sem os cliques.)
func _radio_shot_length() -> void:
	var checked := 0
	var bad: Array[String] = []
	var keys: Array[String] = []
	for id in Ep01V3Cutscene.scene_ids():
		for sh: Variant in Ep01V3Cutscene.scene_data(id).get("shots", []):
			keys.append(Ep01V3Cutscene.line_key(sh as Dictionary))
	# G21i: as falas de radio das cenas podem estar todas pendentes de voz (lote novo); a conta vale para qualquer
	# take de radio do catalogo v3, entao confere tambem esses.
	for k: String in VoiceCatalog.v3_lines():
		keys.append(k)
	for k: String in keys:
		if true:
			var v := _voice(k) if k != "" else 0.0
			if v <= 0.0 or not AudioDirector.is_radio_line(k):
				continue
			checked += 1
			var need := v + Hud.radio_extra_seconds(k) + Hud.VOICE_TAIL
			var got := Ep01V3Cutscene.shot_length({"duration": 0.0, "line": {"key": k}})
			if got + 0.0001 < need:
				bad.append("%s %.3f < %.3f" % [k, got, need])
	r.check(checked >= 1 and bad.is_empty(),
		"cutscene sync: plano de radio sem piso da ficha cabe voz + cliques + folga (%d falas) %s" % [checked, str(bad)])


static func _voice(key: String) -> float:
	var id := Ep01V3Dialogue.take(key)
	if id == "":
		id = key
	if VoiceCatalog.lookup(id, Loc.language).is_empty():
		return 0.0
	var s := VoiceCatalog.stream_for(id, Loc.language)
	return s.get_length() if s != null else 0.0


static func _focus(sh: Dictionary) -> StringName:
	if sh.has("focus"):
		return StringName(str(sh["focus"]))
	var list: Array = sh.get("actors", [])
	return StringName(str((list[0] as Dictionary).get("who", ""))) if not list.is_empty() else &""


func _scene(id: StringName, hud: Hud, line_frames: Array) -> int:
	line_frames.clear()
	_key = ""
	Engine.time_scale = TIME_SCALE
	var shots: Array = Ep01V3Cutscene.scene_data(id).get("shots", [])
	var shot_t: Dictionary = {}
	var wrong: Array[String] = []
	var cut: Array[String] = []
	var prev_key := ""
	var prev_t := 0.0
	var ok := _cs.play(id)
	r.check(ok, "cutscene sync: %s toca" % id)
	var t0 := Time.get_ticks_msec()
	while _cs.playing and Time.get_ticks_msec() - t0 < 60000:
		if not shot_t.has(_cs.shot_index):
			shot_t[_cs.shot_index] = _cs.time
		if _key != "" and _cs.shot_index >= 0:
			var who := hud.speaker_for(_key)
			var f := _focus(shots[_cs.shot_index] as Dictionary)
			if who != &"narrator" and who != &"radio" and who != f and wrong.size() < 4:
				wrong.append("t=%.2f plano %d foco %s fala %s (%s)" % [_cs.time, _cs.shot_index, f, who, _key])
		if _key != prev_key:
			if prev_key != "" and _cs.time - prev_t + FRAME_TOL < _voice(prev_key):
				cut.append("%s %.2f/%.2f s" % [prev_key, _cs.time - prev_t, _voice(prev_key)])
			prev_key = _key
			prev_t = _key_t
		await r.tree.process_frame
	if prev_key != "" and _cs.time - prev_t + FRAME_TOL < _voice(prev_key):
		cut.append("%s %.2f/%.2f s (fim da cena)" % [prev_key, _cs.time - prev_t, _voice(prev_key)])
	Engine.time_scale = 1.0
	r.check(not _cs.playing, "cutscene sync: %s termina" % id)
	r.check(wrong.is_empty(), "cutscene sync: %s fala sempre de quem esta em foco ou do narrador %s" % [id, str(wrong)])
	r.check(cut.is_empty(), "cutscene sync: %s nenhuma voz cortada antes de acabar %s" % [id, str(cut)])
	# Cada fala comeca no quadro do corte do plano dela.
	var late: Array[String] = []
	var voiced := 0
	var expected: Array[String] = []
	for i in shots.size():
		var line: Variant = (shots[i] as Dictionary).get("line")
		var k := str((line as Dictionary).get("key", "")) if line is Dictionary else ""
		if k != "" and Loc.has_key(k):
			expected.append(k)
	for e: Variant in line_frames:
		var row: Array = e
		var k := str(row[0])
		var i := int(row[2])
		var st := float(shot_t.get(i, -1.0))
		if _voice(k) > 0.0:
			voiced += 1
		if absf(float(row[1]) - st) > FRAME_TOL:
			late.append("%s comecou %.2f, plano %d em %.2f" % [k, float(row[1]), i, st])
	r.check(late.is_empty(), "cutscene sync: %s cada fala comeca no corte do plano dela %s" % [id, str(late)])
	r.check(line_frames.size() == expected.size(), "cutscene sync: %s todas as falas tocam (%d/%d)" % [id, line_frames.size(), expected.size()])
	# G20: plano de radio com voz dura >= voz + cliques (0,35) + folga (0,35); o clique de fechar acaba antes do corte.
	var radio_bad: Array[String] = []
	for e: Variant in line_frames:
		var row: Array = e
		var k := str(row[0])
		var i := int(row[2])
		var v := _voice(k)
		if v <= 0.0 or not AudioDirector.is_radio_line(k):
			continue
		var st := float(shot_t.get(i, 0.0))
		var cut_t := float(shot_t.get(i + 1, _cs.time))
		var close_end := float(row[1]) + AudioDirector.RADIO_OPEN_S + v + AudioDirector.RADIO_CLOSE_S
		if cut_t - st + FRAME_TOL < v + AudioDirector.RADIO_EXTRA_S + Hud.VOICE_TAIL or close_end > cut_t:
			radio_bad.append("%s plano %.2f s (voz %.2f), fecha %.2f, corte %.2f" % [k, cut_t - st, v, close_end, cut_t])
	r.check(radio_bad.is_empty(), "cutscene sync: %s planos de radio cabem voz + cliques + folga %s" % [id, str(radio_bad)])
	if id == &"game_intro":
		for i in shots.size():
			var line2: Variant = (shots[i] as Dictionary).get("line")
			var k2 := str((line2 as Dictionary).get("key", "")) if line2 is Dictionary else ""
			print("[RB] g17 game_intro plano %d inicio %.2f ficha %.2f voz %.2f fala %s" % [i, float(shot_t.get(i, -1.0)),
				float((shots[i] as Dictionary).get("duration", 0.0)), _voice(k2) if k2 != "" else 0.0, k2])
		print("[RB] g17 game_intro fim %.2f" % _cs.time)
	return voiced
