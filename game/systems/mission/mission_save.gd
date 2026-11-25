class_name MissionSave
extends RefCounted
## Salvamento por missao (RB-R1 E2): JSON versionado em user://. Guarda o estado de cada missao (com emblemas) e a
## missao atual; ao carregar, a missao atual recomeca do primeiro passo (nunca do meio).

const VERSION := 1
const DEFAULT_PATH := "user://missions.save.json"


## Missao atual = primeira (na ordem) ainda nao concluida; &"" se todas concluidas.
static func current_id(missions: Array[Mission]) -> StringName:
	for m in missions:
		if not m.is_completed():
			return m.id
	return &""


static func save(path: String, episode_id: StringName, missions: Array[Mission]) -> bool:
	var list: Array = []
	for m in missions:
		list.append(m.snapshot())
	var data := {"version": VERSION, "episode": String(episode_id), "current": String(current_id(missions)), "missions": list}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


## Aplica o salvo sobre `missions` (ja carregadas do JSON do episodio). Retorna o id da missao a retomar; &"" se nao
## ha salvo valido (arquivo ausente/corrompido, versao ou episodio diferente): nesse caso nada muda.
static func load_into(path: String, episode_id: StringName, missions: Array[Mission]) -> StringName:
	if not FileAccess.file_exists(path):
		return &""
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return &""
	var d := parsed as Dictionary
	if int(d.get("version", -1)) != VERSION or str(d.get("episode", "")) != String(episode_id):
		return &""
	var by_id := {}
	for s: Variant in d.get("missions", []):
		if s is Dictionary:
			by_id[StringName(str((s as Dictionary).get("id", "")))] = s
	for m in missions:
		if by_id.has(m.id):
			m.restore(by_id[m.id])
	return current_id(missions)
