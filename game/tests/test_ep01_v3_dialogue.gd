extends RefCounted
## Falas do Ep01 v3 (RB-R1 E6): toda chave dita pelo episodio existe no catalogo i18n, cabe na legenda (<= 60 caracteres
## e <= 9 palavras), tem falante e icones existentes e, quando ha take, ele e do mesmo personagem no catalogo de voz.
## O bot percorre M0->M8 com as falas abertas e sem travar. Nao comprova som, leitura por criancas nem render.

const MAX_CHARS := 60
const MAX_WORDS := 9
const TIME_SCALE := 8.0
const MAX_FRAMES := 40000
const SOURCES: Array[String] = ["res://episodes/ep01/v3/ep01_v3_main.gd", "res://episodes/ep01/v3/ep01_v3_land.gd",
	"res://episodes/ep01/v3/ep01_v3_late.gd"]
const ICON_DIR := "res://ui/brand/icons/"
## Falante na ficha -> personagem no catalogo de voz (res://audio/voice_catalog.json, campo `speaker`).
const VOICE_SPEAKER := {"tracker": "tracker", "climber": "climber", "pilot": "pilot", "captain": "captain", "pup": "pup"}
## Falas que o bot nao provoca (ele nunca erra a barraca).
const NOT_BY_BOT: Array[String] = ["ep01.market.vendor.wrong_stall"]

var r


func run(runner) -> void:
	r = runner
	_catalog_checks()
	_source_checks()
	await _bot_with_lines()


func _fits(key: String) -> bool:
	var t := Loc.t(key)
	return t.length() <= MAX_CHARS and t.split(" ", false).size() <= MAX_WORDS


func _catalog_checks() -> void:
	var keys := Ep01V3Dialogue.all_keys()
	r.check(keys.size() >= 70, "v3 E6: ficha com %d falas (roteiro + dicas do radio)" % keys.size())
	var missing: Array[String] = []
	var long: Array[String] = []
	var bad_icon: Array[String] = []
	var bad_take: Array[String] = []
	var bad_speaker: Array[String] = []
	var hud := Hud.new()
	for k in keys:
		if not Loc.has_key(k):
			missing.append(k)
			continue
		if not _fits(k):
			long.append("%s (%d)" % [k, Loc.t(k).length()])
		var em := Ep01V3Dialogue.emotes(k)
		if em.is_empty():
			bad_icon.append(k + " (sem icone)")
		for e in em:
			if not ResourceLoader.exists(ICON_DIR + String(e) + ".svg"):
				bad_icon.append("%s:%s" % [k, e])
		var sp := str(Ep01V3Dialogue.line(k).get("speaker", ""))
		# O falante da ficha e o que a legenda mostra (nome + retrato) pela chave.
		if String(hud.speaker_for(k)) != sp or hud.speaker_name_for(k).is_empty():
			bad_speaker.append("%s (%s/%s)" % [k, sp, hud.speaker_for(k)])
		var tk := Ep01V3Dialogue.take(k)
		if tk != "":
			var v := VoiceCatalog.lookup(tk)
			# D19: take Gemini (v3:<chave>) do mesmo falante da ficha; senao, balbucio de reserva do mesmo personagem.
			var gem := tk.begins_with(VoiceCatalog.V3_PREFIX)
			if v.is_empty() or (gem and (str(v.get("type", "")) != "gemini_tts" or str(v.get("speaker", "")) != sp)) \
					or (not gem and (str(v.get("type", "")) != "babble" or str(v.get("speaker", "")) != str(VOICE_SPEAKER.get(sp, "?")))):
				bad_take.append("%s -> %s" % [k, tk])
	hud.free()
	r.check(missing.is_empty(), "v3 E6: toda fala da ficha existe no catalogo %s" % str(missing))
	r.check(long.is_empty(), "v3 E6: falas com ate %d caracteres e %d palavras %s" % [MAX_CHARS, MAX_WORDS, str(long)])
	r.check(bad_icon.is_empty(), "v3 E6: icones da legenda existem %s" % str(bad_icon))
	r.check(bad_speaker.is_empty(), "v3 E6: falante da legenda bate com a ficha %s" % str(bad_speaker))
	r.check(bad_take.is_empty(), "v3 E6: takes sao Gemini do mesmo falante ou balbucio do mesmo personagem %s" % str(bad_take))
	r.check(Loc.t("member.vendor.name") == "Dona Amora" and Loc.t("member.captain.name") == "Capitão",
		"v3 E6: nomes da feirante e do capitao na legenda")
	# Passos das missoes: dica falada (radio) na ficha e curta.
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://episodes/ep01/v3/ep01_v3_missions.json"))
	var bad_hint: Array[String] = []
	for m: Variant in (parsed as Dictionary)["missions"]:
		if not Loc.has_key(str((m as Dictionary)["title_key"])) or not _fits(str((m as Dictionary)["title_key"])):
			bad_hint.append(str((m as Dictionary)["title_key"]))
		for s: Variant in (m as Dictionary)["steps"]:
			for f in ["hint_gesture_key", "hint_spoken_key"]:
				var k := str((s as Dictionary).get(f, ""))
				if k != "" and (not Loc.has_key(k) or not _fits(k)):
					bad_hint.append(k)
			var spk := str((s as Dictionary).get("hint_spoken_key", ""))
			if spk != "" and Ep01V3Dialogue.line(spk).is_empty():
				bad_hint.append(spk + " (fora da ficha)")
	r.check(bad_hint.is_empty(), "v3 E6: titulos e dicas das missoes no catalogo, curtos e na ficha %s" % str(bad_hint))
	# Momentos da proposta: abertura M0, conclusao de missao, festa e cooperacao nas trocas.
	r.check(Ep01V3Dialogue.start_lines(&"M0").size() >= 2 and Ep01V3Dialogue.start_lines(&"M8").size() >= 1,
		"v3 E6: abertura M0 e festa M8 tem falas")
	var switches := 0
	for k in ["M2:climber", "M2:tracker", "M3:climber", "M4:pilot", "M5:pilot", "M5:climber", "M6:climber",
			"M7:climber", "M7:pilot"]:
		var parts: PackedStringArray = k.split(":")
		if Loc.has_key(Ep01V3Dialogue.switch_line(StringName(parts[0]), StringName(parts[1]))):
			switches += 1
	r.check(switches == 9, "v3 E6: chamada de cooperacao em cada troca de heroi (%d/9)" % switches)


## Toda chave literal que o codigo do episodio fala (say/"ep01.") esta no catalogo e na ficha.
func _source_checks() -> void:
	var re := RegEx.create_from_string("\"(ep01\\.[a-z0-9_]+\\.[a-z0-9_]+\\.[a-z0-9_]+)\"")
	var found: Array[String] = []
	var bad: Array[String] = []
	for path in SOURCES:
		var src := FileAccess.get_file_as_string(path)
		for m in re.search_all(src):
			var k := m.get_string(1)
			found.append(k)
			if not Loc.has_key(k) or Ep01V3Dialogue.line(k).is_empty():
				bad.append(k)
	r.check(found.size() >= 25, "v3 E6: %d chaves de fala no codigo do episodio" % found.size())
	r.check(bad.is_empty(), "v3 E6: chaves do codigo existem no catalogo e na ficha %s" % str(bad))


func _bot_with_lines() -> void:
	var main := (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	r.tree.root.add_child(main)
	r.tree.current_scene = main
	await r.frames(3)
	var shown: Array[String] = []
	# A primeira fala do M0 ja abriu em _ready (antes de conectar): conta a que esta na legenda agora.
	for k in Ep01V3Dialogue.start_lines(&"M0"):
		if main.hud.is_speaking() and main.hud._sub_text.text == Loc.t(k):
			shown.append(k)
	main.hud.line_started.connect(func(k: String) -> void: shown.append(k))
	var bot := Ep01V3Bot.new()
	bot.main = main
	main.add_child(bot)
	Engine.time_scale = TIME_SCALE
	var frames := 0
	var spoke_frames := 0
	while not bot.done and frames < MAX_FRAMES:
		await r.tree.process_frame
		frames += 1
		if main.hud.is_speaking():
			spoke_frames += 1
	var t_end := bot.elapsed
	# Depois do fim as falas da festa terminam (a fila nao trava).
	var extra := 0
	while main.hud.is_speaking() and extra < 2000:
		await r.tree.process_frame
		extra += 1
	Engine.time_scale = 1.0
	Ep01V3Bot.release_all()
	print("[RB] v3 E6 bot com falas: %.1f s de jogo, %d falas, legenda aberta em %d de %d quadros" % [
		t_end, shown.size(), spoke_frames, frames])
	r.check(bot.done and bot.fail_reason == "" and main.complete,
		"v3 E6: bot M0->M8 conclui com as falas abertas (%.1f s; %s)" % [t_end, bot.fail_reason])
	r.check(not main.hud.is_speaking(), "v3 E6: fila de falas esvazia no fim (%d quadros extras)" % extra)
	var not_shown: Array[String] = []
	for k: Variant in Ep01V3Dialogue.sheet().get("script", []):
		if not shown.has(str(k)) and not NOT_BY_BOT.has(str(k)):
			not_shown.append(str(k))
	r.check(not_shown.is_empty(), "v3 E6: o bot ouviu todo o roteiro (%d falas) %s" % [shown.size(), str(not_shown)])
	var unknown: Array[String] = []
	for k in shown:
		if not Loc.has_key(k):
			unknown.append(k)
	r.check(unknown.is_empty(), "v3 E6: nenhuma legenda sem texto no catalogo %s" % str(unknown))
	main.queue_free()
	await r.frames(3)
