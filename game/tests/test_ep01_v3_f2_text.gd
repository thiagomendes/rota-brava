extends RefCounted
## Texto do F2 e da D21 (RB-R1): falas que apontam (P5), grupos de variantes (D19c) e roteiro das cutscenes.
## Confere catalogo, tamanho de linha (<= 44 caracteres e <= 8 palavras), falante, icones, marcadores do mundo,
## clipes existentes nos GLB e orcamento de tempo. Nao comprova voz, leitura por criancas nem a cena rodando.

const MAX_CHARS := 44
const MAX_WORDS := 8
const CUT_PATH := "res://episodes/ep01/v3/ep01_v3_cutscenes.json"
const WORLD_PATH := "res://worlds/village_v3/village_world.tscn"
const ICON_DIR := "res://ui/brand/icons/"
const MODELS := {"tracker": "res://assets/models/characters/rastro_v2.glb",
	"climber": "res://assets/models/characters/pico_v2.glb", "pilot": "res://assets/models/characters/leme_v2.glb",
	"captain": "res://assets/models/characters/captain_v2.glb", "pup": "res://assets/models/characters/pup_v2.glb",
	"vendor": "res://assets/models/characters/amora_v2.glb", "radio": "res://assets/models/characters/lumi_v2.glb"}
## G21i: planos com `stage` usam os marcadores do palco da base Farol 7.
const STAGE_PATH := "res://worlds/farol7_base/farol7_base.tscn"
const STEPS: Array[String] = ["M1.bench", "M1.boot", "M1.trail", "M2.free_pieces", "M2.find_third", "M2.hang",
	"M3.stream", "M3.leaves", "M4.read", "M4.deliver", "M5.feathers", "M5.compass", "M5.fish", "M6.board", "M6.buoys",
	"M6.approach", "M6.rope", "M7.lens", "M7.climb", "M7.aim", "M8.thanks"]
const CARDINAL: Array[String] = ["oeste", "leste", "norte", " sul"]

var r
var _markers: Dictionary = {}
var _stage_markers: Dictionary = {}
var _stage_src := ""


func run(runner) -> void:
	r = runner
	var src := FileAccess.get_file_as_string(WORLD_PATH)
	var re := RegEx.create_from_string("\\[node name=\"([A-Za-z0-9_]+)\" type=\"Marker3D\"")
	for m in re.search_all(src):
		_markers[m.get_string(1)] = true
	r.check(_markers.size() >= 50, "F2 texto: %d marcadores lidos do mundo" % _markers.size())
	_stage_src = FileAccess.get_file_as_string(STAGE_PATH)
	for m in re.search_all(_stage_src):
		_stage_markers[m.get_string(1)] = true
	r.check(_stage_markers.has("Base_CamFront") and _stage_markers.has("Base_LumiStand"), "G21i: marcadores Base_* lidos do palco (%d)" % _stage_markers.size())
	_pointing_lines()
	_groups()
	_cardinal()
	_cutscenes()


## Falas com mais de MAX_WORDS aceitas por decisao explicita (chave -> motivo).
const LONG_OK := {"ep01.narrator.intro.base": "G21i: texto exato decidido por Thiago (10 palavras, 37 caracteres)"}


func _short(key: String) -> bool:
	var t := Loc.t(key)
	var words_ok := t.split(" ", false).size() <= MAX_WORDS or LONG_OK.has(key)
	return Loc.has_key(key) and t.length() <= MAX_CHARS and words_ok


func _pointing_lines() -> void:
	var sheet := Ep01V3Dialogue.sheet()
	var starts: Dictionary = sheet.get("step_start", {})
	var missing_steps: Array[String] = []
	for s in STEPS:
		if not starts.has(s):
			missing_steps.append(s)
	r.check(missing_steps.is_empty(), "F2 P5: fala de inicio em todos os 21 passos %s" % str(missing_steps))
	var keys: Array[String] = []
	for section in ["step_start", "travel", "step_done"]:
		for k: Variant in (sheet.get(section, {}) as Dictionary).values():
			keys.append(str(k))
	r.check(keys.size() >= 25, "F2 P5: %d falas que apontam" % keys.size())
	var bad: Array[String] = []
	var hud := Hud.new()
	for k in keys:
		var ln := Ep01V3Dialogue.line(k)
		var g: Dictionary = ln.get("gesture", {})
		if not _short(k) or str(ln.get("when", "")) == "" or not _markers.has(str(g.get("target", ""))) \
				or str(g.get("anim", "")) == "" or String(hud.speaker_for(k)) != str(ln.get("speaker", "?")):
			bad.append(k)
		for e: Variant in ln.get("emotes", []):
			if not ResourceLoader.exists(ICON_DIR + str(e) + ".svg"):
				bad.append("%s:%s" % [k, e])
	hud.free()
	r.check(bad.is_empty(), "F2 P5: no catalogo, curtas, com when, gesto, alvo no mundo e falante %s" % str(bad))


func _groups() -> void:
	var groups: Dictionary = Ep01V3Dialogue.sheet().get("groups", {})
	r.check(groups.size() >= 36, "D19c: %d grupos de variantes" % groups.size())
	var bad: Array[String] = []
	var hints := 0
	var hud := Hud.new()
	for gid: Variant in groups:
		var ks: Array = groups[gid]
		if ks.size() < 3 or ks.size() > 5:
			bad.append("%s (%d)" % [gid, ks.size()])
		if str(gid).begins_with("hint.radio."):
			hints += 1
		for k: Variant in ks:
			var key := str(k)
			var ln := Ep01V3Dialogue.line(key)
			if ln.is_empty() or not Loc.has_key(key) or String(hud.speaker_for(key)) != str(ln.get("speaker", "?")):
				bad.append(key)
			elif ln.has("group") and not _short(key):
				bad.append(key + " (longa)")
	hud.free()
	r.check(bad.is_empty(), "D19c: grupos com 3-5 variantes, no catalogo e na ficha; novas curtas %s" % str(bad))
	r.check(hints == STEPS.size(), "D19c: grupo de dica do radio para cada passo (%d/%d)" % [hints, STEPS.size()])


func _cardinal() -> void:
	var bad: Array[String] = []
	for k in Ep01V3Dialogue.all_keys():
		var t := Loc.t(k).to_lower()
		for w in CARDINAL:
			if w in t:
				bad.append(k)
	r.check(bad.is_empty(), "F2 P5: nenhuma fala do episodio usa ponto cardeal %s" % str(bad))


func _anim_names(who: String) -> PackedStringArray:
	var out := PackedStringArray()
	var ps := load(str(MODELS.get(who, ""))) as PackedScene
	if ps == null:
		return out
	var node := ps.instantiate()
	for ap: Node in node.find_children("*", "AnimationPlayer", true, false):
		out.append_array((ap as AnimationPlayer).get_animation_list())
	node.free()
	return out


func _cutscenes() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CUT_PATH))
	r.check(parsed is Dictionary, "D21: ficha de cutscenes le")
	if not parsed is Dictionary:
		return
	var anims: Dictionary = {}
	for who: String in MODELS:
		anims[who] = _anim_names(who)
	var bad: Array[String] = []
	var ep_total := 0.0
	var intro := 0.0
	var ids: Dictionary = {}
	for sc: Variant in (parsed as Dictionary)["scenes"]:
		var s := sc as Dictionary
		ids[str(s["id"])] = true
		var sum := 0.0
		if not _markers.has(str((s["exit_look"] as Dictionary)["marker"])):
			bad.append("%s: exit_look" % s["id"])
		for sh: Variant in s["shots"]:
			var shot := sh as Dictionary
			sum += float(shot["duration"])
			var mk: Dictionary = _stage_markers if str(shot.get("stage", "")) == "farol7_base" else _markers
			for f in ["from", "to", "look", "look_to"]:
				if shot.has(f) and not mk.has(str((shot[f] as Dictionary)["marker"])):
					bad.append("%s: %s" % [s["id"], f])
			for a: Variant in shot["actors"]:
				var ad := a as Dictionary
				var where_ok := mk.has(str(ad.get("marker", "")))
				if ad.has("seat"):
					# G21i: sentado = filho de um no do palco (Chair/Seat)
					where_ok = str(ad["seat"]) == "Chair/Seat" and _stage_src.contains("[node name=\"Seat\" type=\"Marker3D\" parent=\"Chair\"]")
				var have := anims.get(str(ad["who"]), []) as PackedStringArray
				if not where_ok or not str(ad["anim"]) in have or (ad.has("then") and not str(ad["then"]) in have):
					bad.append("%s: %s/%s" % [s["id"], ad["who"], ad["anim"]])
			if shot.has("line"):
				var key := str((shot["line"] as Dictionary)["key"])
				if not _short(key):
					bad.append("%s: %s" % [s["id"], key])
		if absf(sum - float(s["duration"])) > 0.01:
			bad.append("%s: duracao" % s["id"])
		if str(s["id"]) == "game_intro":
			intro = sum
		else:
			ep_total += sum
	r.check(bad.is_empty(), "D21: marcadores, clipes existentes e falas curtas no catalogo %s" % str(bad))
	r.check(ep_total >= 60.0 and ep_total <= 90.0, "D21: cenas do Ep01 somam %.1f s (60-90)" % ep_total)
	r.check(intro >= 30.0 and intro <= 45.0, "D21: abertura do jogo %.1f s (30-45)" % intro)
	for need in ["game_intro", "opening", "m1_intro", "m2_intro", "m3_intro", "m4_intro", "m5_intro", "m6_intro",
			"m7_intro", "boat_departure", "lighthouse_climb", "nightfall", "closing"]:
		if not ids.has(need):
			bad.append(need)
	r.check(bad.is_empty(), "D21: todas as cenas pedidas existem %s" % str(bad))
