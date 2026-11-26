class_name Ep01V3Dialogue
extends RefCounted
## Falas do Ep01 v3 (RB-R1 E6): ficha em ep01_v3_dialogue.json com quem fala, icones da legenda (res://ui/brand/icons)
## e o take de voz JA EXISTENTE em res://audio/voice_catalog.json (balbucio do mesmo personagem). Texto so no catalogo
## i18n. Momentos: abertura de cada missao (`mission_start`), conclusao (`mission_done`) e chamada de cooperacao na
## troca de heroi (`switch`, chave "Mx:heroi"). As demais falas sao ditas pelo codigo das missoes nos acontecimentos.

const PATH := "res://episodes/ep01/v3/ep01_v3_dialogue.json"

static var _sheet: Dictionary = {}


static func sheet() -> Dictionary:
	if _sheet.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_sheet = parsed if parsed is Dictionary else {"lines": {}}
	return _sheet


static func line(key: String) -> Dictionary:
	return (sheet().get("lines", {}) as Dictionary).get(key, {})


static func emotes(key: String) -> Array[StringName]:
	var out: Array[StringName] = []
	for e: Variant in line(key).get("emotes", []):
		out.append(StringName(str(e)))
	return out


## Id do take para tocar com esta fala: "v3:<chave>" (voz Gemini) se existir, senao o balbucio ja gravado, ou "" (so legenda).
static func take(key: String) -> String:
	if VoiceCatalog.has_v3(key):  # D19: voz Gemini do proprio texto; balbucio so como reserva
		return VoiceCatalog.V3_PREFIX + key
	var v: Variant = line(key).get("take", null)
	return "" if v == null else str(v)


static func _keys(section: String, id: String) -> Array[String]:
	var out: Array[String] = []
	for k: Variant in (sheet().get(section, {}) as Dictionary).get(id, []):
		out.append(str(k))
	return out


static func start_lines(mission: StringName) -> Array[String]:
	return _keys("mission_start", String(mission))


static func done_lines(mission: StringName) -> Array[String]:
	return _keys("mission_done", String(mission))


static func switch_line(mission: StringName, hero: StringName) -> String:
	return str((sheet().get("switch", {}) as Dictionary).get("%s:%s" % [mission, hero], ""))


## Todas as chaves da ficha, em ordem de jogo (roteiro) e depois as dicas do radio.
static func all_keys() -> Array[String]:
	var out: Array[String] = []
	for k: Variant in (sheet().get("lines", {}) as Dictionary).keys():
		out.append(str(k))
	return out


# ---------- F2: falas que apontam (step_start, travel, step_done) e variantes (D19c) ----------

## Sorteio das variantes: semente fixa por padrao (testes reproduziveis); o jogo chama `randomize_picks()`.
static var _rng := RandomNumberGenerator.new()
## Ultima variante dita por grupo (nunca se repete em seguida).
static var _last: Dictionary = {}


static func randomize_picks() -> void:
	_rng.randomize()


static func reset_picks(seed_value: int = 7) -> void:
	_rng.seed = seed_value
	_last.clear()


static func step_start_line(mission: StringName, step: StringName) -> String:
	return str((sheet().get("step_start", {}) as Dictionary).get("%s.%s" % [mission, step], ""))


static func step_done_line(mission: StringName, step: StringName) -> String:
	return str((sheet().get("step_done", {}) as Dictionary).get("%s.%s" % [mission, step], ""))


static func travel_line(from_mission: StringName, to_mission: StringName) -> String:
	return str((sheet().get("travel", {}) as Dictionary).get("%s>%s" % [from_mission, to_mission], ""))


static func speaker(key: String) -> StringName:
	return StringName(str(line(key).get("speaker", "")))


## Gesto da fala: {anim, fallback, target} (vazio se a fala nao aponta).
static func gesture(key: String) -> Dictionary:
	var g: Variant = line(key).get("gesture", {})
	return g if g is Dictionary else {}


static func group_keys(group: String) -> Array[String]:
	var out: Array[String] = []
	for k: Variant in (sheet().get("groups", {}) as Dictionary).get(group, []):
		out.append(str(k))
	return out


## Ja saiu alguma fala deste grupo (desde o ultimo reset_picks)?
static func said(group: String) -> bool:
	return _last.has(group)


## G9: fala de ponte com `vary` na ficha vira uma variante sorteada do grupo (sem repetir a ultima); senao, a propria.
static func vary(key: String) -> String:
	var g := str(line(key).get("vary", ""))
	return pick(g) if g != "" and has_group(g) else key


static func has_group(group: String) -> bool:
	return not group_keys(group).is_empty()


## Uma variante do grupo, nunca igual a ultima dita do mesmo grupo. `prefer`: fala de contexto (ex.: o chamado da
## missao, F2/A1) que SEMPRE vence; o sorteio sem repetir so vale entre as variantes quando nao ha fala de contexto.
## "" se nao ha fala nem grupo.
static func pick(group: String, prefer: String = "") -> String:
	var keys := group_keys(group)
	if prefer != "":
		if prefer in keys:
			_last[group] = prefer
		return prefer
	if keys.is_empty():
		return ""
	var last := str(_last.get(group, ""))
	var pool: Array[String] = []
	for k in keys:
		if k != last:
			pool.append(k)
	if pool.is_empty():
		pool = keys
	var choice := pool[_rng.randi_range(0, pool.size() - 1)]
	_last[group] = choice
	return choice
