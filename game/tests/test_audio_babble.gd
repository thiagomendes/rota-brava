extends RefCounted
## Balbucio e visemas (RB-R1 D2): cada fala de personagem tem arquivo + visemas com duracao compativel (+-10 %),
## silabas no ritmo pedido e nunca a mesma silaba duas vezes seguidas (pelo JSON de geracao). Radio tem visemas.
## NAO comprova audicao (timbre, fofura, entonacao percebida).

const CHARACTERS: Array[String] = ["Rastro", "Pico", "Leme", "captain", "pup"]


func _json(path: String) -> Dictionary:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return v if v is Dictionary else {}


func run(r) -> void:
	VoiceCatalog.reload()
	var ok_vis := true
	var ok_dur := true
	var ok_rep := true
	var ok_rate := true
	var ok_range := true
	var chars: Dictionary = {}
	var n := 0
	var worst_dur := 0.0
	var rates: Array[float] = []
	for e in VoiceCatalog.all_lines():
		var id := str(e["id"])
		var v := _json(str(e.get("visemes", "")))
		if v.is_empty() or not (v.get("open") is Array) or (v["open"] as Array).is_empty():
			ok_vis = false
			printerr("visemas ausentes: " + id)
			continue
		var s := load(str(e["file"])) as AudioStream if ResourceLoader.exists(str(e["file"])) else null
		if s == null:
			ok_vis = false
			continue
		var len_s := s.get_length()
		var vis_len := float((v["open"] as Array).size()) * float(v.get("frame_s", 0.03))
		var rel := maxf(absf(float(v["duration"]) - len_s), absf(vis_len - len_s)) / len_s
		worst_dur = maxf(worst_dur, rel)
		if rel > 0.10:
			ok_dur = false
			printerr("visemas x audio fora de 10%% em %s (%.1f%%)" % [id, rel * 100.0])
		for a in v["open"]:
			if float(a) < 0.0 or float(a) > 1.0:
				ok_range = false
		if str(e["type"]) != "babble":
			continue
		n += 1
		chars[str(e["character"])] = true
		var syl: Array = v.get("syllables", [])
		if syl.size() < 2:
			ok_rep = false
			printerr("silabas ausentes: " + id)
			continue
		var prev := ""
		var sum := 0.0
		for x in syl:
			var lab := str(x["s"])
			if lab == prev:
				ok_rep = false
				printerr("silaba repetida em seguida em %s: %s" % [id, lab])
			prev = lab
			sum += float(x["t1"]) - float(x["t0"])
			if float(x["t1"]) > len_s + 0.05:
				ok_dur = false
		var mean := sum / float(syl.size())
		if str(e["character"]) != "pup":
			rates.append(mean)
			if mean < 0.06 or mean > 0.13:
				ok_rate = false
				printerr("ritmo fora de 0,06-0,13 s/silaba em %s (%.3f)" % [id, mean])
			if absf(float(syl.size()) - float(v.get("target_syllables", syl.size()))) > 0.0:
				ok_rate = false
				printerr("numero de silabas diferente do texto em " + id)
	var lo := 1.0
	var hi := 0.0
	for x in rates:
		lo = minf(lo, x)
		hi = maxf(hi, x)
	r.check(n >= 30, "balbucio: >= 30 falas de personagem (%d)" % n)
	r.check(ok_vis, "balbucio/radio: toda fala tem JSON de visemas com abertura por quadro")
	r.check(ok_dur, "balbucio/radio: duracao dos visemas compativel com o audio (+-10%%; pior %.1f%%)" % (worst_dur * 100.0))
	r.check(ok_range, "balbucio/radio: abertura da boca sempre em 0..1")
	r.check(ok_rep, "balbucio: nunca a mesma silaba duas vezes seguidas")
	r.check(ok_rate, "balbucio: silabas = nucleos do texto e 0,06-0,13 s/silaba (%.3f..%.3f)" % [lo, hi])
	var all_chars := true
	for c in CHARACTERS:
		if not chars.has(c):
			all_chars = false
	r.check(all_chars, "balbucio: Rastro, Pico, Leme, piloto e filhote tem falas (%s)" % ", ".join(chars.keys()))
	var pup := _json(str(VoiceCatalog.lookup("ep01.return.pup.horn").get("visemes", "")))
	var barks := true
	for x in pup.get("syllables", []):
		if not (str(x["s"]).begins_with("au") or str(x["s"]).begins_with("ii")):
			barks = false
	r.check(not pup.is_empty() and barks, "balbucio: filhote fala em latidinhos/ganidos (au/ii)")
