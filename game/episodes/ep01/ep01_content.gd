class_name Ep01Content
extends RefCounted
## Acesso tipado a game/episodes/ep01/ep01_content.json (so chaves e IDs; textos ficam em Loc).

const PATH := "res://episodes/ep01/ep01_content.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			push_error("Conteudo do ep01 ausente: " + PATH)
			return {}
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed
	return _data


static func objective_key(state: StringName) -> String:
	return String(data().get("objectives", {}).get(String(state), {}).get("objective_key", ""))


static func objective_icon(state: StringName) -> StringName:
	return StringName(data().get("objectives", {}).get(String(state), {}).get("icon", "notebook"))


static func lines(state: StringName, key: String) -> Array[String]:
	var out: Array[String] = []
	for k: Variant in data().get("lines", {}).get(String(state), {}).get(key, []):
		out.append(String(k))
	return out


static func hints(state: StringName) -> Array:
	return data().get("hints", {}).get(String(state), [])


static func clue(clue_id: StringName) -> Dictionary:
	for c: Dictionary in data().get("clues", []):
		if c.get("id", "") == String(clue_id):
			return c
	return {}


static func destination(dest_id: StringName) -> Dictionary:
	for d: Dictionary in data().get("destinations", []):
		if d.get("id", "") == String(dest_id):
			return d
	return {}
