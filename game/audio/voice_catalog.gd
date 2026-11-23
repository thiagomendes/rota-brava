class_name VoiceCatalog extends RefCounted
## Catalogo de falas (SPEC secoes 6 e 8): id, personagem, intencao, idioma, legenda (chave de Loc), arquivo.
## Fala ausente NAO bloqueia: `stream_for` devolve null; quem chama mostra a legenda e libera a sequencia (SPEC secao 7).

const PATH := "res://audio/voice_catalog.json"
const FALLBACK := "pt_BR"

static var missing: Array[String] = []
static var _lines: Array = []
static var _loaded: bool = false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
	if parsed is Dictionary and (parsed as Dictionary).get("lines") is Array:
		_lines = (parsed as Dictionary)["lines"]
	else:
		push_warning("VoiceCatalog: catalogo ausente ou invalido: " + PATH)


static func reload() -> void:
	_loaded = false
	_lines = []
	missing.clear()


static func all_lines() -> Array:
	_ensure()
	return _lines


static func _find(id: String, lang: String) -> Dictionary:
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
