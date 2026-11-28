extends RefCounted
## D19/D21: vozes Gemini do Ep01 v3. Toda chave falada (ficha: lines + groups; cutscenes) tem take v3 ou esta
## na lista explicita de excecoes; arquivos existem e a duracao bate; a ficha prefere o take v3; narrador no HUD.
## NAO comprova audicao (timbre, pronuncia e atuacao ficam com Thiago).

## Takes aceitos apesar do detector de leitura dupla (chave -> motivo). Vazio: nenhuma excecao.
const DOUBLE_EXCEPTIONS: Dictionary = {}


func _spoken_keys() -> Dictionary:
	var out: Dictionary = {}
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://episodes/ep01/v3/ep01_v3_dialogue.json"))
	for k in d["lines"]:
		out[str(k)] = str(d["lines"][k]["speaker"])
	for gid in d["groups"]:
		for k in d["groups"][gid]:
			if not out.has(str(k)):
				out[str(k)] = "?"
	var c: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://episodes/ep01/v3/ep01_v3_cutscenes.json"))
	for s in c["scenes"]:
		for sh in s["shots"]:
			if sh.get("line") is Dictionary:
				out[str(sh["line"]["key"])] = str(sh["line"]["speaker"])
	return out


func run(r) -> void:
	VoiceCatalog.reload()
	var v3 := VoiceCatalog.v3_lines()
	var exc := VoiceCatalog.v3_exceptions()
	var keys := _spoken_keys()
	var pending := VoiceCatalog.v3_pending()
	var missing: Array[String] = []
	for k: String in keys:
		if not v3.has(k) and not exc.has(k) and not pending.has(k):
			missing.append(k)
	r.check(keys.size() >= 200 and missing.is_empty(),
		"voz v3: %d chaves faladas, todas com take, excecao ou pendencia explicita (faltam %d: %s)" % [keys.size(), missing.size(), ", ".join(missing.slice(0, 6))])
	if not pending.is_empty():
		print("[RB] voz v3: %d falas PENDENTES (cota da API), tocam balbucio de reserva" % pending.size())
	# G22c: take gravado com outro texto (ex.: "Vila Farol 7" -> "Vila Mare") nao fica no catalogo; sai e vira pendente
	var stale: Array[String] = []
	for k: String in v3:
		if str(v3[k].get("text_at_generation", "")) != Loc.t(k):
			stale.append(k)
	r.check(stale.is_empty(), "voz v3: todo take foi gravado com o texto atual da legenda (desatualizados: %s)" % ", ".join(stale))
	# Vozes 4: as falas da Vila Mare tem take novo (gravado com "Vila Mare") ou seguem pendentes; nunca o take antigo
	var vila_ok := true
	for k: String in ["ep01.narrator.intro.village", "ep01.narrator.opening.village"]:
		if v3.has(k):
			vila_ok = vila_ok and str(v3[k].get("text_at_generation", "")).contains("Maré") and not pending.has(k)
		else:
			vila_ok = vila_ok and pending.has(k)
	r.check(vila_ok, "voz v3: falas da Vila Mare com take do texto novo ou pendentes (G22c)")
	r.check(Loc.t("ep01.narrator.intro.village").contains("Vila Maré") and not Loc.t("ep01.narrator.opening.village").contains("Farol 7"), "voz v3: a vila se chama Vila Mare no texto do narrador (G22c)")
	var bad_exc: Array[String] = []
	for k: String in exc:
		if keys.get(k, "") != "pup":
			bad_exc.append(k)
	r.check(not exc.is_empty() and bad_exc.is_empty(), "voz v3: excecoes so do filhote (%s)" % ", ".join(exc.keys()))
	var files_ok := true
	var dur_ok := true
	var total := 0.0
	for k: String in v3:
		var s := VoiceCatalog.stream_for(VoiceCatalog.V3_PREFIX + k)
		if s == null:
			files_ok = false
			printerr("take v3 ausente: " + k)
			continue
		total += s.get_length()
		if absf(s.get_length() - float(v3[k]["duration"])) > 0.08:
			dur_ok = false
			printerr("duracao v3 divergente: %s %.2f x %.2f" % [k, s.get_length(), float(v3[k]["duration"])])
		if not FileAccess.file_exists(str(v3[k]["visemes"])) or str(v3[k].get("sha256", "")) == "" or str(v3[k].get("model", "")) == "":
			files_ok = false
	r.check(files_ok, "voz v3: todo take carrega, tem visemas e procedencia (modelo, sha256)")
	# Leitura dupla (tools/voice/detect_double.py, rodado na geracao e gravado em double_check). Excecoes explicitas:
	var double_bad: Array[String] = []
	for k: String in v3:
		var dc: Variant = v3[k].get("double_check", null)
		if DOUBLE_EXCEPTIONS.has(k):
			continue
		if not dc is Dictionary or bool(dc.get("reprova", true)) or dc.get("leitura_dupla") != null or float(dc.get("razao", 9.0)) > 1.35:
			double_bad.append(k)
	r.check(double_bad.is_empty(), "voz v3: nenhum take com leitura dupla nem longo demais pelo detector (%s)" % ", ".join(double_bad))
	r.check(dur_ok, "voz v3: duracao do catalogo bate com o arquivo (total %.1f s)" % total)
	var any_key: String = v3.keys()[0] if not v3.is_empty() else ""
	r.check(any_key != "" and Ep01V3Dialogue.take(any_key) == VoiceCatalog.V3_PREFIX + any_key,
		"voz v3: a ficha prefere o take novo (balbucio so como reserva)")
	var d := AudioDirector.new()
	r.tree.root.add_child(d)
	await r.frames(1)
	var info := d.play_line(VoiceCatalog.V3_PREFIX + any_key)
	r.check(float(info["duration"]) > 0.3 and d.ducked, "voz v3: play_line toca o take e abaixa a musica (%.2f s)" % float(info["duration"]))
	d.stop_all()
	d.queue_free()
	var hud := Hud.new()
	r.check(hud.speaker_for("ep01.narrator.intro.village") == &"narrator" and hud.speaker_icon(&"narrator") == &"storybook"
		and ResourceLoader.exists("res://ui/brand/icons/storybook.svg"), "voz v3: HUD reconhece o narrador e usa o icone storybook")
	hud.free()
	await r.frames(1)
