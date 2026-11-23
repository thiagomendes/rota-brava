extends RefCounted
## Audio de referencia (RB-03): catalogo de falas, arquivos importaveis, medicoes nos proprios streams,
## loops de musica e layout de buses. NAO comprova audicao: timbre, pronuncia e gosto ficam com Thiago.

const REQUIRED: Array[String] = ["id", "character", "intent", "language", "subtitle", "file", "duration", "peak_dbfs", "status", "tool"]
const INTENTS: Array[String] = ["normal", "urgencia", "descoberta", "radio"]
const MUSIC: Array[String] = ["res://audio/music/theme_explore.wav", "res://audio/music/theme_discovery.wav"]
const PEAK_CEIL_DB := -1.0
const MAX_LEAD_SILENCE_S := 0.150
const SILENCE_AMP := 0.01  # -40 dBFS
const MAX_LOOP_STEP := 0.01


func _s16(data: PackedByteArray, index: int) -> float:
	return data.decode_s16(index * 2) / 32768.0


func run(r) -> void:
	VoiceCatalog.reload()
	var lines := VoiceCatalog.all_lines()
	r.check(lines.size() >= 4, "audio: catalogo carrega com >= 4 falas (%d)" % lines.size())
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
		var n := s.data.size() / 2
		var peak := 0.0
		var lead := n
		for i in n:
			var a := absf(_s16(s.data, i))
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
		r.check(m != null and m.stereo and m.mix_rate == 44100 and m.format == AudioStreamWAV.FORMAT_16_BITS and m.get_length() > 10.0, "audio: %s estereo 44,1 kHz 16 bits" % path.get_file())
		if m == null:
			continue
		var frames := m.data.size() / 4
		var step_l := absf(_s16(m.data, 0) - _s16(m.data, (frames - 1) * 2))
		var step_r := absf(_s16(m.data, 1) - _s16(m.data, (frames - 1) * 2 + 1))
		r.check(step_l <= MAX_LOOP_STEP and step_r <= MAX_LOOP_STEP, "audio: %s loop sem salto na emenda (%.5f, %.5f)" % [path.get_file(), step_l, step_r])
		var mp := 0.0
		for i in range(0, frames * 2, 101):
			mp = maxf(mp, absf(_s16(m.data, i)))
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
