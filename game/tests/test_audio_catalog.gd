extends RefCounted
## Audio de referencia (RB-03): catalogo de falas, arquivos importaveis, medicoes nos proprios streams,
## loops de musica e layout de buses. NAO comprova audicao: timbre, pronuncia e gosto ficam com Thiago.

const REQUIRED: Array[String] = ["id", "character", "intent", "language", "subtitle", "file", "duration", "peak_dbfs", "status", "tool"]
const INTENTS: Array[String] = ["normal", "urgencia", "descoberta", "radio", "observacao", "parcial", "deducao", "pergunta", "correcao", "dica"]
const MUSIC: Array[String] = ["res://audio/music/theme_explore.wav", "res://audio/music/theme_explore_low.wav", "res://audio/music/theme_discovery.wav"]
const NO_LOOP: Array[String] = ["theme_discovery.wav"]
const SFX_PATH := "res://audio/sfx_catalog.json"
const CONTENT := "res://episodes/ep01/ep01_content.json"
const PEAK_CEIL_DB := -1.0
const MAX_LEAD_SILENCE_S := 0.150
const SILENCE_AMP := 0.01  # -40 dBFS
const MAX_LOOP_STEP := 0.01


func _s16(data: PackedByteArray, index: int) -> float:
	return data.decode_s16(index * 2) / 32768.0


func run(r) -> void:
	VoiceCatalog.reload()
	var lines := VoiceCatalog.all_lines()
	r.check(lines.size() >= 21, "audio: catalogo carrega com >= 21 falas (%d)" % lines.size())
	var ids: Dictionary = {}
	var intents: Dictionary = {}
	var fields_ok := true
	var unique := true
	for e in lines:
		for f in REQUIRED:
			if not (e as Dictionary).has(f) or str(e[f]) == "":
				fields_ok = false
				printerr("campo ausente '%s' em %s" % [f, e.get("id", "?")])
		var key := "%s/%s" % [e.get("id", ""), e.get("language", "")]
		if ids.has(key):
			unique = false
		ids[key] = true
		intents[str(e.get("intent", ""))] = true
		if not INTENTS.has(str(e.get("intent", ""))) or str(e.get("status", "")) != "provisorio":
			fields_ok = false
	r.check(fields_ok, "audio: campos obrigatorios, intencao valida e status provisorio")
	r.check(unique, "audio: ids unicos por idioma")
	r.check(intents.has("normal") and intents.has("urgencia") and intents.has("descoberta") and intents.has("radio"), "audio: cobre normal, urgencia, descoberta e radio")

	var all_exist := true
	var all_wav := true
	var all_len := true
	var all_sub := true
	var all_peak := true
	var all_lead := true
	var worst_peak := -120.0
	var worst_lead := 0.0
	for e in lines:
		var id := str(e["id"])
		if not Loc.has_key(str(e["subtitle"])):
			all_sub = false
			printerr("legenda sem texto: " + str(e["subtitle"]))
		var file := str(e["file"])
		# O arquivo-fonte precisa existir de fato: o cache de importacao sozinho nao basta (so vale no editor).
		if not FileAccess.file_exists(file) or not ResourceLoader.exists(file):
			all_exist = false
			continue
		var s := load(file) as AudioStreamWAV
		if s == null:
			all_wav = false
			continue
		if s.get_length() <= 0.0 or absf(s.get_length() - float(e["duration"])) > 0.05:
			all_len = false
			printerr("duracao divergente em " + id)
		if s.format != AudioStreamWAV.FORMAT_16_BITS or s.stereo:
			all_wav = false
		var vdata := s.data
		var n := vdata.size() / 2
		var peak := 0.0
		var lead := n
		for i in n:
			var a := absf(_s16(vdata, i))
			if a > peak:
				peak = a
			if a > SILENCE_AMP and lead == n:
				lead = i
		var peak_db := 20.0 * log(maxf(peak, 1e-9)) / log(10.0)
		var lead_s := float(lead) / float(s.mix_rate)
		worst_peak = maxf(worst_peak, peak_db)
		worst_lead = maxf(worst_lead, lead_s)
		if peak_db > PEAK_CEIL_DB:
			all_peak = false
		if lead_s > MAX_LEAD_SILENCE_S:
			all_lead = false
		if absf(peak_db - float(e["peak_dbfs"])) > 0.1:
			all_peak = false
			printerr("pico do catalogo diverge do stream em " + id)
	r.check(all_exist, "audio: todo arquivo de fala existe e esta importado")
	r.check(all_wav, "audio: falas carregam como AudioStreamWAV mono 16 bits")
	r.check(all_len, "audio: duracao > 0 e coerente com o catalogo")
	r.check(all_sub, "audio: toda legenda existe no catalogo de texto (Loc)")
	r.check(all_peak, "audio: pico lido do stream <= -1 dBFS (pior %.2f) e igual ao catalogo" % worst_peak)
	r.check(all_lead, "audio: silencio de abertura <= 150 ms (pior %.0f ms)" % (worst_lead * 1000.0))

	var radio := VoiceCatalog.lookup("ep01.radio.team.found_boat")
	r.check(not radio.is_empty() and radio["intent"] == "radio" and radio["character"] == "team" and Loc.t("ep01.radio.team.found_boat") == "Farol 7, aqui é Rota Brava. Achamos o barco.", "audio: fala do radio no catalogo com a legenda exata")
	var before := VoiceCatalog.missing.size()
	r.check(VoiceCatalog.stream_for("nao.existe.fala") == null and VoiceCatalog.lookup("nao.existe.fala").is_empty(), "audio: id inexistente devolve null sem erro")
	r.check(VoiceCatalog.missing.size() == before + 1, "audio: fala ausente e registrada")
	r.check(VoiceCatalog.stream_for("ep01.dock.tracker.small_print", "en") != null and VoiceCatalog.missing.size() > before + 1, "audio: idioma ausente cai em pt_BR com registro")

	for path in MUSIC:
		var m := load(path) as AudioStreamWAV if ResourceLoader.exists(path) else null
		r.check(m != null and m.stereo and m.mix_rate == 32000 and m.format == AudioStreamWAV.FORMAT_16_BITS and m.get_length() > 4.0, "audio: %s estereo 32 kHz 16 bits" % path.get_file())
		if m == null:
			continue
		var mdata := m.data
		var frames := mdata.size() / 4
		var step_l := absf(_s16(mdata, 0) - _s16(mdata, (frames - 1) * 2))
		var step_r := absf(_s16(mdata, 1) - _s16(mdata, (frames - 1) * 2 + 1))
		if path.get_file() in NO_LOOP:
			r.check(absf(_s16(mdata, (frames - 1) * 2)) < 0.002 and absf(_s16(mdata, 0)) < 0.002, "audio: %s (sem loop) comeca e termina em silencio, sem corte" % path.get_file())
		else:
			r.check(step_l <= MAX_LOOP_STEP and step_r <= MAX_LOOP_STEP, "audio: %s loop sem salto na emenda (%.5f, %.5f)" % [path.get_file(), step_l, step_r])
		var mp := 0.0
		for i in range(0, frames * 2, 101):
			mp = maxf(mp, absf(_s16(mdata, i)))
		r.check(mp > 0.1 and 20.0 * log(mp) / log(10.0) <= PEAK_CEIL_DB, "audio: %s com conteudo e pico <= -1 dBFS" % path.get_file())

	var layout := load("res://audio/default_bus_layout.tres") as AudioBusLayout
	r.check(layout != null, "audio: default_bus_layout.tres carrega")
	if layout != null:
		var names := ["Master", "Voz", "Musica", "Efeitos", "Ambiente"]
		var ok := true
		for i in names.size():
			var raw: Variant = layout.get("bus/%d/name" % i)
			if raw == null or String(raw) != names[i]:
				ok = false
		r.check(ok, "audio: layout tem Master, Voz, Musica, Efeitos, Ambiente")

	_run_rb04(r)


## Cobertura do primeiro minuto, catalogo de efeitos/ambiente/musica e layout de buses (RB-04).
func _stats(s: AudioStreamWAV) -> Dictionary:
	var data := s.data
	var ch := 2 if s.stereo else 1
	var frames := data.size() / (2 * ch)
	var peak := 0.0
	var lead := frames
	# Pico: todas as amostras em sons curtos (< 150 mil quadros); em loops longos, passo fixo (GDScript e lento).
	var stride := maxi(1, frames / 150000)
	var i := 0
	while i < frames:
		for c in ch:
			var a := absf(_s16(data, i * ch + c))
			if a > peak:
				peak = a
		i += stride
	for j in mini(frames, 4000):
		if absf(_s16(data, j * ch)) > SILENCE_AMP:
			lead = j
			break
	var seam := 0.0
	for c in ch:
		seam = maxf(seam, absf(_s16(data, c) - _s16(data, (frames - 1) * ch + c)))
	return {"peak_db": 20.0 * log(maxf(peak, 1e-9)) / log(10.0), "lead_s": float(lead) / float(s.mix_rate), "seam": seam, "frames": frames}


func _first_minute_keys() -> Array[String]:
	var keys: Array[String] = []
	var c: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTENT))
	if not (c is Dictionary):
		return keys
	var d := c as Dictionary
	for state in ["arrival", "dock_investigation"]:
		for ev in (d["lines"][state] as Dictionary):
			for k in d["lines"][state][ev]:
				keys.append(str(k))
		for h in d["hints"][state]:
			keys.append(str(h["key"]))
	for cl in d["clues"]:
		keys.append(str(cl["observation_key"]))
		keys.append(str(cl["partial_key"]))
	keys.append(str(d["deduction_key"]))
	keys.append(str(d["destination_prompt_key"]))
	for dest in d["destinations"]:
		if dest.has("observation_key"):
			keys.append(str(dest["observation_key"]))
	keys.append("ep01.dock.tracker.wrong_bank_hint")
	return keys


func _run_rb04(r) -> void:
	var keys := _first_minute_keys()
	r.check(keys.size() >= 18, "audio: conteudo do primeiro minuto lista >= 18 falas (%d)" % keys.size())
	var uncovered: Array[String] = []
	for k in keys:
		var e := VoiceCatalog.lookup(k)
		if e.is_empty() or not FileAccess.file_exists(str(e["file"])):
			uncovered.append(k)
	r.check(uncovered.is_empty(), "audio: todas as falas de chegada e cais tem entrada e arquivo (%s)" % ", ".join(uncovered))
	var seen: Dictionary = {}
	var dup := false
	for e in VoiceCatalog.all_lines():
		var id := str(e["id"])
		if seen.has(id):
			dup = true
		seen[id] = true
	r.check(not dup and seen.size() == VoiceCatalog.all_lines().size(), "audio: ids de fala unicos (%d)" % seen.size())

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SFX_PATH)) if FileAccess.file_exists(SFX_PATH) else null
	r.check(parsed is Dictionary and (parsed as Dictionary).get("entries") is Array, "audio: sfx_catalog.json carrega")
	if not (parsed is Dictionary):
		return
	var entries: Array = (parsed as Dictionary)["entries"]
	var names: Dictionary = {}
	for e in entries:
		names[str(e["name"])] = e
	var required: Array[String] = ["amb_dock_water", "amb_wind_light", "amb_dock_creaks", "amb_gulls_far", "sfx_horn_boat", "sfx_hull_bump", "sfx_crate_slide", "sfx_rope_creak", "sfx_rope_tug", "sfx_engine_loop", "sfx_ui_confirm", "sfx_ui_move", "sfx_clue_found", "sfx_notebook", "theme_explore", "theme_explore_low", "theme_discovery"]
	for i in 6:
		required.append("sfx_step_wood_%02d" % (i + 1))
	var missing_names: Array[String] = []
	for n in required:
		if not names.has(n):
			missing_names.append(n)
	r.check(missing_names.is_empty(), "audio: catalogo traz todos os sons exigidos (faltam: %s)" % ", ".join(missing_names))
	var ok_exist := true
	var ok_peak := true
	var ok_lead := true
	var ok_dur := true
	var ok_fields := true
	var ok_cap := true
	var ok_loop := true
	var worst := -120.0
	var worst_lead := 0.0
	var worst_seam := 0.0
	var step_sigs: Dictionary = {}
	for e in entries:
		var n := str(e["name"])
		for f in ["name", "file", "type", "duration", "peak_dbfs", "bus", "status", "gain_db"]:
			if not (e as Dictionary).has(f):
				ok_fields = false
		var file := str(e["file"])
		if not FileAccess.file_exists(file) or not ResourceLoader.exists(file):
			ok_exist = false
			printerr("arquivo ausente: " + file)
			continue
		var s := load(file) as AudioStreamWAV
		if s == null:
			ok_exist = false
			continue
		var st := _stats(s)
		var kind := str(e["type"])
		var ceil_db := -3.0 + 0.1 if kind != "music" and kind != "ambience" else PEAK_CEIL_DB
		worst = maxf(worst, st["peak_db"])
		if st["peak_db"] > ceil_db or absf(st["peak_db"] - float(e["peak_dbfs"])) > (0.1 if int(st["frames"]) <= 150000 else 1.0):
			ok_peak = false
			printerr("pico fora do limite/catalogo: %s %.2f" % [n, st["peak_db"]])
		if kind in ["oneshot", "ui", "step", "loop"] and st["lead_s"] > 0.020:
			ok_lead = false
			printerr("silencio de abertura > 20 ms: " + n)
		worst_lead = maxf(worst_lead, st["lead_s"])
		if absf(s.get_length() - float(e["duration"])) > 0.05:
			ok_dur = false
		if e.get("caption_key") != null and not Loc.has_key(str(e["caption_key"])):
			ok_cap = false
			printerr("legenda visual sem texto: " + str(e["caption_key"]))
		if bool(e.get("loop", false)):
			worst_seam = maxf(worst_seam, st["seam"])
			if st["seam"] > MAX_LOOP_STEP:
				ok_loop = false
				printerr("salto na emenda de %s: %.5f" % [n, st["seam"]])
			if kind == "ambience" and (not s.stereo or s.get_length() < 18.0):
				ok_loop = false
		if kind == "step":
			step_sigs[str(hash(s.data))] = n
	r.check(ok_fields, "audio: toda entrada de sfx_catalog tem os campos exigidos")
	r.check(ok_exist, "audio: todo arquivo de efeito/ambiente/musica existe e e importavel")
	r.check(ok_peak, "audio: picos medidos nos streams (pior %.2f dBFS; sfx <= -3, ambiente/musica <= -1) e iguais ao catalogo" % worst)
	r.check(ok_lead, "audio: efeitos sem silencio de abertura > 20 ms (pior %.1f ms)" % (worst_lead * 1000.0))
	r.check(ok_dur, "audio: duracoes coerentes com o catalogo")
	r.check(ok_cap, "audio: legendas visuais de efeitos existem em Loc")
	r.check(ok_loop, "audio: loops de ambiente e motor sem salto na emenda (pior %.5f)" % worst_seam)
	r.check(step_sigs.size() == 6, "audio: 6 variacoes de passo distintas (%d)" % step_sigs.size())

	var layout := load("res://audio/default_bus_layout.tres") as AudioBusLayout
	if layout != null:
		var lim: Variant = layout.get("bus/0/effect/0/effect")
		r.check(lim is AudioEffectHardLimiter and (lim as AudioEffectHardLimiter).ceiling_db <= -1.0, "audio: Master tem limitador com teto <= -1 dB")
		var duck: Variant = layout.get("bus/2/effect/0/effect")
		r.check(duck is AudioEffectCompressor and (duck as AudioEffectCompressor).sidechain == &"Voz", "audio: Musica tem compressor com sidechain na Voz")
		r.check(layout.get("bus/2/effect/1/effect") is AudioEffectEQ6, "audio: Musica tem EQ para abrir espaco a voz")
		r.check(layout.get("bus/4/effect/0/effect") is AudioEffectLowPassFilter, "audio: Ambiente tem passa-baixas opcional")
