class_name Loc extends RefCounted
## Localizacao (SPEC secao 8): catalogo plano chave -> texto em res://i18n/<idioma>.json.
## Falta de chave: devolve a propria chave, registra em `missing` (sem repetir) e avisa.

const FALLBACK := "pt_BR"

static var language: String = "pt_BR"
static var missing: Array[String] = []
static var _cache: Dictionary = {}


static func _catalog(lang: String) -> Dictionary:
	if _cache.has(lang):
		return _cache[lang]
	var data: Dictionary = {}
	# <idioma>.json e, opcionalmente, <idioma>.<parte>.json (um por estagio/area; chaves nao se repetem).
	var paths: Array[String] = ["res://i18n/%s.json" % lang]
	var extra: Array[String] = []
	for file in DirAccess.get_files_at("res://i18n"):
		if file != lang + ".json" and file.begins_with(lang + ".") and file.ends_with(".json"):
			extra.append("res://i18n/" + file)
	extra.sort()
	paths.append_array(extra)
	for path in paths:
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			data.merge(parsed, true)
		else:
			push_warning("Loc: catalogo invalido: " + path)
	_cache[lang] = data
	return data


static func has_key(key: String) -> bool:
	return _catalog(language).has(key) or _catalog(FALLBACK).has(key)


static func t(key: String, params: Dictionary = {}) -> String:
	var text := ""
	var found := false
	for lang in [language, FALLBACK]:
		var cat := _catalog(lang)
		if cat.has(key):
			text = str(cat[key])
			found = true
			break
	if not found:
		if not missing.has(key):
			missing.append(key)
			push_warning("Loc: chave ausente: " + key)
		return key
	for name in params:
		text = text.replace("{%s}" % str(name), str(params[name]))
	return text


static func reload() -> void:
	_cache.clear()
	missing.clear()


## Nome e habilidade localizados de um integrante (tracker, climber, pilot). Chaves montadas aqui, validadas em test_content.
static func member_name(member: StringName) -> String:
	return t("member." + String(member) + ".name")


static func member_skill(member: StringName) -> String:
	return t("member." + String(member) + ".skill")

