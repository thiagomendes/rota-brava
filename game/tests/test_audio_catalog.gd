extends RefCounted
## Audio (RB-R1): catalogos de falas e sons, arquivos importaveis, medidas lidas dos proprios streams (WAV PCM) ou
## do relatorio do gerador (OGG, decodificado em Python), loops, cobertura das falas e layout de buses.
## NAO comprova audicao: timbre, pronuncia, musicalidade e mixagem percebida ficam com Thiago.

const REQUIRED: Array[String] = ["id", "character", "intent", "language", "subtitle", "type", "file", "duration", "peak_dbfs", "visemes", "status", "tool"]
const INTENTS: Array[String] = ["normal", "urgencia", "descoberta", "pergunta", "alegria", "dica", "radio"]
const SFX_PATH := "res://audio/sfx_catalog.json"
const CONTENT := "res://episodes/ep01/ep01_content.json"
const PEAK_CEIL_DB := -1.0
const MAX_LEAD_SILENCE_S := 0.150
const SILENCE_AMP := 0.01  # -40 dBFS
const MAX_LOOP_STEP := 0.01
const MAX_OGG_SEAM := 0.02
const RADIO_SPEAKERS: Array[String] = ["radio", "team"]


func _s16(data: PackedByteArray, index: int) -> float:
	return data.decode_s16(index * 2) / 32768.0


func run(r) -> void:
	VoiceCatalog.reload()
	var lines := VoiceCatalog.all_lines()
	r.check(lines.size() >= 45, "audio: catalogo de falas carrega com >= 45 falas (%d)" % lines.size())
	var fields_ok := true
	var ids: Dictionary = {}
	var unique := true
	var n_babble := 0
	var n_radio := 0
	for e in lines:
		for f in REQUIRED:
			if not (e as Dictionary).has(f) or str(e[f]) == "":
				fields_ok = false
				printerr("campo ausente '%s' em %s" % [f, e.get("id", "?")])
		if ids.has(str(e.get("id", ""))):
			unique = false
		ids[str(e.get("id", ""))] = true
		if not INTENTS.has(str(e.get("intent", ""))) or str(e.get("status", "")) != "provisorio" or not str(e.get("type", "")) in ["babble", "radio"]:
			fields_ok = false
			printerr("intencao/tipo/status invalido em " + str(e.get("id", "?")))
		if str(e.get("type", "")) == "babble":
			n_babble += 1
		else:
			n_radio += 1
		if (str(e.get("type")) == "radio") != (str(e.get("speaker", "")) in RADIO_SPEAKERS or str(e.get("id", "")).contains(".hint_spoken")):
			fields_ok = false
			printerr("tipo babble/radio nao segue a regra D2 em " + str(e.get("id", "?")))
	r.check(fields_ok, "audio: campos obrigatorios, intencao/tipo validos e regra D2 (radio = Farol 7/equipe + dicas faladas)")
	r.check(unique, "audio: ids de fala unicos")
	r.check(n_babble >= 30 and n_radio >= 8, "audio: falas de balbucio (%d) e de radio (%d)" % [n_babble, n_radio])

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
		if not FileAccess.file_exists(file) or not ResourceLoader.exists(file):
			all_exist = false
			printerr("fala sem arquivo: " + file)
			continue
		var s := load(file) as AudioStreamWAV
		if s == null or s.format != AudioStreamWAV.FORMAT_16_BITS or s.stereo:
			all_wav = false
			continue
		if s.get_length() <= 0.0 or absf(s.get_length() - float(e["duration"])) > 0.05:
			all_len = false
			printerr("duracao divergente em " + id)
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
		if peak_db > PEAK_CEIL_DB or absf(peak_db - float(e["peak_dbfs"])) > 0.1:
			all_peak = false
			printerr("pico fora do teto ou do catalogo em %s (%.2f)" % [id, peak_db])
		if lead_s > MAX_LEAD_SILENCE_S:
			all_lead = false
	r.check(all_exist, "audio: todo arquivo de fala existe (FileAccess) e importa")
	r.check(all_wav, "audio: falas carregam como AudioStreamWAV mono 16 bits PCM")
	r.check(all_len, "audio: duracao > 0 e coerente com o catalogo")
	r.check(all_sub, "audio: toda legenda existe no catalogo de texto (Loc)")
	r.check(all_peak, "audio: pico lido do stream <= -1 dBFS (pior %.2f) e igual ao catalogo" % worst_peak)
	r.check(all_lead, "audio: silencio de abertura <= 150 ms (pior %.0f ms)" % (worst_lead * 1000.0))

	var radio := VoiceCatalog.lookup("ep01.radio.team.found_boat")
	r.check(not radio.is_empty() and radio["type"] == "radio" and radio["speaker"] == "team" and Loc.t("ep01.radio.team.found_boat") == "Farol 7, aqui é Rota Brava. Achamos o barco.", "audio: teste de pronuncia do radio no catalogo com a legenda exata")
	var before := VoiceCatalog.missing.size()
	r.check(VoiceCatalog.stream_for("nao.existe.fala") == null and VoiceCatalog.lookup("nao.existe.fala").is_empty(), "audio: id inexistente devolve null sem erro")
	r.check(VoiceCatalog.missing.size() == before + 1, "audio: fala ausente e registrada")
	r.check(VoiceCatalog.stream_for("ep01.dock.tracker.small_print", "en") != null and VoiceCatalog.missing.size() > before + 1, "audio: idioma ausente cai em pt_BR com registro")

	_coverage(r)
	_sfx(r)
	_layout(r)


func _content_keys() -> Array[String]:
	var keys: Array[String] = []
	var c: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTENT))
	if not (c is Dictionary):
		return keys
	var d := c as Dictionary
	for state in (d["lines"] as Dictionary):
		for ev in (d["lines"][state] as Dictionary):
			for k in d["lines"][state][ev]:
				var parts := str(k).split(".")
				if parts.size() == 4 and parts[2] in ["tracker", "climber", "pilot", "captain", "pup", "radio", "team"] and not keys.has(str(k)):
					keys.append(str(k))
	for state in (d["hints"] as Dictionary):
		for h in d["hints"][state]:
			for f in (h as Dictionary):
				var v := str(h[f])
				if v.begins_with("ep01.") and Loc.has_key(v) and not keys.has(v):
					keys.append(v)
	return keys


## Toda fala citada no conteudo do episodio tem entrada e arquivo (balbucio ou radio).
func _coverage(r) -> void:
	var keys := _content_keys()
	r.check(keys.size() >= 30, "audio: conteudo do episodio lista >= 30 falas (%d)" % keys.size())
	var uncovered: Array[String] = []
	for k in keys:
		var e := VoiceCatalog.lookup(k)
		if e.is_empty() or not FileAccess.file_exists(str(e["file"])):
			uncovered.append(k)
	r.check(uncovered.is_empty(), "audio: todas as falas do episodio tem entrada e arquivo (faltam: %s)" % ", ".join(uncovered))
	var radio_missing: Array[String] = []
	for k in keys:
		var parts := k.split(".")
		if parts.size() == 4 and (parts[2] in RADIO_SPEAKERS or parts[3].begins_with("hint_spoken")):
			var e := VoiceCatalog.lookup(k)
			if e.is_empty() or str(e.get("type")) != "radio":
				radio_missing.append(k)
	r.check(radio_missing.is_empty(), "audio: toda fala de radio/equipe e dica falada tem arquivo de radio (%s)" % ", ".join(radio_missing))


func _stats(s: AudioStreamWAV) -> Dictionary:
	var data := s.data
	var ch := 2 if s.stereo else 1
	var frames := data.size() / (2 * ch)
	var peak := 0.0
	var lead := frames
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
	var edge := 0.0
	for c in ch:
		edge = maxf(edge, maxf(absf(_s16(data, c)), absf(_s16(data, (frames - 1) * ch + c))))
	return {"peak_db": 20.0 * log(maxf(peak, 1e-9)) / log(10.0), "lead_s": float(lead) / float(s.mix_rate), "seam": seam, "frames": frames, "edge": edge}


func _sfx(r) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SFX_PATH)) if FileAccess.file_exists(SFX_PATH) else null
	r.check(parsed is Dictionary and (parsed as Dictionary).get("entries") is Array, "audio: sfx_catalog.json carrega")
	if not (parsed is Dictionary):
		return
	var entries: Array = (parsed as Dictionary)["entries"]
	var names: Dictionary = {}
	for e in entries:
		names[str(e["name"])] = e
	var required: Array[String] = ["amb_dock_water", "amb_wind_light", "amb_dock_creaks", "amb_gulls_far", "amb_beach_waves", "amb_village_market", "amb_river", "amb_birds",
		"sfx_horn_boat", "sfx_hull_bump", "sfx_crate_slide", "sfx_rope_creak", "sfx_rope_tug", "sfx_rope_tug_02", "sfx_rope_snap", "sfx_engine_loop", "sfx_boat_wake",
		"sfx_ui_confirm", "sfx_ui_move", "sfx_ui_back", "sfx_ui_open", "sfx_ui_swap", "sfx_clue_found", "sfx_ui_star", "sfx_notebook",
		"theme_explore", "theme_explore_low", "theme_discovery", "theme_crossing", "theme_return", "theme_victory", "theme_team_call"]
	for surf in ["wood", "stone", "sand", "grass"]:
		for i in 6:
			required.append("sfx_step_%s_%02d" % [surf, i + 1])
	var missing_names: Array[String] = []
	for n in required:
		if not names.has(n):
			missing_names.append(n)
	r.check(missing_names.is_empty(), "audio: catalogo traz todos os sons exigidos (faltam: %s)" % ", ".join(missing_names))
	var ok := {"fields": true, "exist": true, "peak": true, "lead": true, "dur": true, "cap": true, "loop": true, "ogg": true, "music": true}
	var worst := -120.0
	var worst_seam := 0.0
	var step_sigs: Dictionary = {}
	for e in entries:
		var n := str(e["name"])
		for f in ["name", "file", "type", "duration", "peak_dbfs", "true_peak_dbtp", "bus", "status", "gain_db", "loop", "license", "source"]:
			if not (e as Dictionary).has(f):
				ok["fields"] = false
				printerr("campo %s ausente em %s" % [f, n])
		var file := str(e["file"])
		if not FileAccess.file_exists(file) or not ResourceLoader.exists(file):
			ok["exist"] = false
			printerr("arquivo ausente: " + file)
			continue
		var res := load(file)
		if res == null:
			ok["exist"] = false
			continue
		var kind := str(e["type"])
		if absf((res as AudioStream).get_length() - float(e["duration"])) > 0.05:
			ok["dur"] = false
			printerr("duracao divergente: " + n)
		if e.get("caption_key") != null and not Loc.has_key(str(e["caption_key"])):
			ok["cap"] = false
			printerr("legenda visual sem texto: " + str(e["caption_key"]))
		if kind in ["music", "ambience"] and float(e["true_peak_dbtp"]) > PEAK_CEIL_DB:
			ok["peak"] = false
			printerr("pico verdadeiro > -1 dBTP: " + n)
		if res is AudioStreamOggVorbis:
			if bool(e["loop"]) and (not (e as Dictionary).has("seam_jump") or float(e["seam_jump"]) > MAX_OGG_SEAM):
				ok["ogg"] = false
				printerr("emenda OGG (medida no decodificado) acima do limite: " + n)
			if kind == "ambience" and float(e["duration"]) < 18.0:
				ok["ogg"] = false
			worst_seam = maxf(worst_seam, float(e.get("seam_jump", 0.0)))
			continue
		var s := res as AudioStreamWAV
		if s == null or s.format != AudioStreamWAV.FORMAT_16_BITS:
			ok["exist"] = false
			printerr("WAV nao PCM16 (fixe compress/mode=0): " + n)
			continue
		var st := _stats(s)
		var ceil_db := (-3.0 + 0.1) if not kind in ["music", "ambience", "voice_crowd"] else PEAK_CEIL_DB
		worst = maxf(worst, st["peak_db"])
		if st["peak_db"] > ceil_db or absf(st["peak_db"] - float(e["peak_dbfs"])) > (0.1 if int(st["frames"]) <= 150000 else 1.0):
			ok["peak"] = false
			printerr("pico fora do limite/catalogo: %s %.2f" % [n, st["peak_db"]])
		if kind in ["oneshot", "ui", "step", "loop"] and st["lead_s"] > 0.020:
			ok["lead"] = false
			printerr("silencio de abertura > 20 ms: " + n)
		if bool(e["loop"]):
			worst_seam = maxf(worst_seam, st["seam"])
			if st["seam"] > MAX_LOOP_STEP:
				ok["loop"] = false
				printerr("salto na emenda de %s: %.5f" % [n, st["seam"]])
		elif kind == "music" and st["edge"] > 0.002:
			ok["music"] = false
			printerr("vinheta sem silencio nas pontas: " + n)
		if kind == "music" and (not s.stereo or s.mix_rate != 32000):
			ok["music"] = false
		if kind == "step":
			var surf := n.get_slice("_", 2)
			if not step_sigs.has(surf):
				step_sigs[surf] = {}
			step_sigs[surf][str(hash(s.data))] = n
	r.check(ok["fields"], "audio: toda entrada de sfx_catalog tem os campos exigidos (inclui licenca e fonte)")
	r.check(ok["exist"], "audio: todo arquivo de efeito/ambiente/musica existe, importa e WAV e PCM16")
	r.check(ok["peak"], "audio: picos (stream WAV pior %.2f dBFS; sfx <= -3; musica/ambiente <= -1 dBTP pelo gerador) e iguais ao catalogo" % worst)
	r.check(ok["lead"], "audio: efeitos sem silencio de abertura > 20 ms")
	r.check(ok["dur"], "audio: duracoes coerentes com o catalogo")
	r.check(ok["cap"], "audio: legendas visuais de efeitos existem em Loc")
	r.check(ok["loop"], "audio: loops WAV sem salto na emenda (<= %.2f; pior %.5f)" % [MAX_LOOP_STEP, worst_seam])
	r.check(ok["ogg"], "audio: loops OGG com emenda medida <= %.2f e ambientes >= 18 s" % MAX_OGG_SEAM)
	r.check(ok["music"], "audio: musica WAV estereo 32 kHz; vinhetas comecam e terminam em silencio")
	var steps_ok := step_sigs.size() == 4
	for surf in step_sigs:
		if (step_sigs[surf] as Dictionary).size() < 6:
			steps_ok = false
	r.check(steps_ok, "audio: 4 superficies de passo com 6 variacoes distintas cada")


func _layout(r) -> void:
	var layout := load("res://audio/default_bus_layout.tres") as AudioBusLayout
	r.check(layout != null, "audio: default_bus_layout.tres carrega")
	if layout == null:
		return
	var names := ["Master", "Voz", "Musica", "Efeitos", "Ambiente"]
	var ok := true
	for i in names.size():
		var raw: Variant = layout.get("bus/%d/name" % i)
		if raw == null or String(raw) != names[i]:
			ok = false
	r.check(ok, "audio: layout tem Master, Voz, Musica, Efeitos, Ambiente")
	var lim: Variant = layout.get("bus/0/effect/0/effect")
	r.check(lim is AudioEffectHardLimiter and (lim as AudioEffectHardLimiter).ceiling_db <= -1.0, "audio: Master tem limitador com teto <= -1 dB")
	r.check(float(layout.get("bus/0/volume_db")) <= 0.0, "audio: ganho do Master fica antes do limitador (bus Master <= 0 dB)")
	var duck: Variant = layout.get("bus/2/effect/0/effect")
	r.check(duck is AudioEffectCompressor and (duck as AudioEffectCompressor).sidechain == &"Voz", "audio: Musica tem compressor com sidechain na Voz (ducking suave)")
	var eq: Variant = layout.get("bus/2/effect/1/effect")
	r.check(eq is AudioEffectEQ6 and is_equal_approx((eq as AudioEffectEQ6).get_band_gain_db(0), -6.0) and is_equal_approx((eq as AudioEffectEQ6).get_band_gain_db(4), -3.0), "audio: Musica tem EQ para abrir espaco a voz (ganhos preservados no .tres)")
	r.check(layout.get("bus/4/effect/0/effect") is AudioEffectLowPassFilter, "audio: Ambiente tem passa-baixas opcional")
