class_name VoiceCatalog extends RefCounted
## Catalogo de falas (SPEC secoes 6 e 8): id, personagem, intencao, idioma, legenda (chave de Loc), arquivo.
## Fala ausente NAO bloqueia: `stream_for` devolve null; quem chama mostra a legenda e libera a sequencia (SPEC secao 7).

const PATH := "res://audio/voice_catalog.json"
const FALLBACK := "pt_BR"
## D19/D21: vozes Gemini TTS do Ep01 v3 em catalogo proprio; pedidas pelo id "v3:<chave da fala>".
const V3_PATH := "res://audio/voice/v3/voice_v3_catalog.json"
const V3_PREFIX := "v3:"

static var missing: Array[String] = []
static var _lines: Array = []
static var _loaded: bool = false
static var _v3: Dictionary = {}
static var _v3_exceptions: Dictionary = {}
static var _v3_pending: Array = []


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
	if parsed is Dictionary and (parsed as Dictionary).get("lines") is Array:
		_lines = (parsed as Dictionary)["lines"]
	else:
		push_warning("VoiceCatalog: catalogo ausente ou invalido: " + PATH)
	var v3: Variant = JSON.parse_string(FileAccess.get_file_as_string(V3_PATH)) if FileAccess.file_exists(V3_PATH) else null
	if v3 is Dictionary:
		for e in (v3 as Dictionary).get("lines", []):
			_v3[str(e.get("id", ""))] = e
		_v3_pending = ((v3 as Dictionary).get("pending", {}) as Dictionary).get("keys", [])
		for x in (v3 as Dictionary).get("exceptions", []):
			_v3_exceptions[str(x.get("id", ""))] = str(x.get("reason", ""))


static func reload() -> void:
	_loaded = false
	_lines = []
	_v3 = {}
	_v3_exceptions = {}
	_v3_pending = []
	missing.clear()


static func all_lines() -> Array:
	_ensure()
	return _lines


## Ha take Gemini (v3) para esta chave de fala?
static func has_v3(key: String) -> bool:
	_ensure()
	return _v3.has(key)


static func v3_lines() -> Dictionary:
	_ensure()
	return _v3


## Chaves faladas sem take por decisao (ex.: filhote late com o som existente) -> motivo.
static func v3_exceptions() -> Dictionary:
	_ensure()
	return _v3_exceptions


## Chaves ainda sem take por falta de cota (geracao interrompida; tocam o balbucio de reserva).
static func v3_pending() -> Array:
	_ensure()
	return _v3_pending


static func _find(id: String, lang: String) -> Dictionary:
	if id.begins_with(V3_PREFIX):
		var e: Dictionary = _v3.get(id.trim_prefix(V3_PREFIX), {})
		return e if not e.is_empty() and str(e.get("language", "")) == lang else {}
	for e in _lines:
		if e is Dictionary and str(e.get("id", "")) == id and str(e.get("language", "")) == lang:
			return e
	return {}


## Entrada do catalogo para a fala/idioma; cai em pt_BR com registro; {} se nao existe.
static func lookup(id: String, lang: String = "pt_BR") -> Dictionary:
	_ensure()
	var e := _find(id, lang)
	if e.is_empty() and lang != FALLBACK:
		e = _find(id, FALLBACK)
		if not e.is_empty():
			_note_missing("%s [%s -> %s]" % [id, lang, FALLBACK])
	if e.is_empty():
		_note_missing(id)
	return e


static func stream_for(id: String, lang: String = "pt_BR") -> AudioStream:
	var e := lookup(id, lang)
	if e.is_empty():
		return null
	var file := str(e.get("file", ""))
	if file == "" or not ResourceLoader.exists(file):
		_note_missing(id + " (arquivo ausente: " + file + ")")
		return null
	return load(file) as AudioStream


static func _note_missing(what: String) -> void:
	if not missing.has(what):
		missing.append(what)
		push_warning("VoiceCatalog: fala ausente/fallback: " + what)
