class_name SaveSlots
extends RefCounted
## G13 (RB-R1): 3 espacos de jogo "memory card". Cada espaco tem o seu salvo de missoes (MissionSave) e as suas cenas
## vistas (Ep01V3Cutscene), entao um jogo novo ve a abertura e as cenas de novo.
##   user://slot_<n>.save.json            salvo das missoes do espaco n (1..COUNT)
##   user://slot_<n>.cutscenes.seen.json  cenas ja vistas no espaco n
## Migracao (uma vez): o salvo antigo `user://missions.save.json` (e `user://cutscenes.seen.json`) vira o espaco 1.
## `prefix` existe para os testes gravarem em arquivos proprios (nunca nos espacos reais do jogador).

const COUNT := 3
const LEGACY_SAVE := "user://missions.save.json"
const LEGACY_SEEN := "user://cutscenes.seen.json"
const MISSIONS_PATH := "res://episodes/ep01/v3/ep01_v3_missions.json"
const EPISODE_ID := &"ep01"
## Retrato do heroi do cartao (o primeiro heroi da missao atual; episodio completo: o Rastro alegre).
const PORTRAITS := {&"tracker": "rastro", &"climber": "pico", &"pilot": "leme"}

static var prefix: String = "user://"
## Espaco em uso (0 = nenhum escolhido ainda; o jogo usa os caminhos padrao do espaco 1).
static var active: int = 0


static func save_path(slot: int) -> String:
	return "%sslot_%d.save.json" % [prefix, slot]


static func seen_path(slot: int) -> String:
	return "%sslot_%d.cutscenes.seen.json" % [prefix, slot]


static func has_save(slot: int) -> bool:
	return FileAccess.file_exists(save_path(slot))


## Leva o salvo antigo para o espaco 1, uma unica vez, sem perder nada: move (renomeia) o arquivo, entao a proxima
## chamada nao acha mais o antigo. Se o espaco 1 ja existe, o antigo fica onde esta (nada e sobrescrito).
## So as cenas vistas antigas (sem salvo): o espaco 1 nasce no comeco, com as cenas ja vistas.
## Retorna true se migrou algo.
static func migrate(legacy_save: String = LEGACY_SAVE, legacy_seen: String = LEGACY_SEEN) -> bool:
	var target_save := save_path(1)
	var target_seen := seen_path(1)
	if FileAccess.file_exists(target_save) or FileAccess.file_exists(target_seen):
		return false
	var has_old_save := FileAccess.file_exists(legacy_save)
	var has_old_seen := FileAccess.file_exists(legacy_seen)
	if not has_old_save and not has_old_seen:
		return false
	if has_old_save and _move(legacy_save, target_save) != OK:
		return false
	if has_old_seen:
		_move(legacy_seen, target_seen)
	if not has_old_save:
		_write_fresh(target_save)
	print("[RB] slots migrou o salvo antigo para o espaco 1 (salvo=%s vistas=%s)" % [has_old_save, has_old_seen])
	return true


## Passa a usar o espaco `slot`: o Ep01 le e grava o salvo dele e as cenas vistas sao as dele.
static func select(slot: int) -> void:
	active = slot
	Ep01V3Main.save_path = save_path(slot)
	Ep01V3Cutscene.seen_path = seen_path(slot)
	Ep01V3Cutscene.forget_seen_cache()
	print("[RB] slots espaco %d" % slot)


## Comeca um jogo novo no espaco: apaga o que houver nele, grava o comeco (M0, nada concluido) e seleciona.
## O cartao passa a mostrar a missao atual desde ja, mesmo antes da primeira missao terminar.
static func start_new(slot: int) -> void:
	erase(slot)
	_write_fresh(save_path(slot))
	select(slot)


## Apaga o espaco (salvo e cenas vistas).
static func erase(slot: int) -> void:
	for p: String in [save_path(slot), seen_path(slot), save_path(slot) + ".tmp", seen_path(slot) + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	Ep01V3Cutscene.forget_seen_cache()
	print("[RB] slots apagou espaco %d" % slot)


## O que o cartao mostra. Vazio: {"empty": true}. Cheio: missao atual (id, chave do nome, icone), emblemas achados e
## total, heroi e caminho do retrato, `complete` se todas as missoes terminaram. Salvo invalido conta como vazio.
static func summary(slot: int) -> Dictionary:
	var missions := Mission.load_list(MISSIONS_PATH)
	var data := _mission_data()
	var total := 0
	for m in missions:
		total += m.emblems.size()
	var out := {"slot": slot, "empty": true, "emblems_total": total}
	if not has_save(slot) or not _valid(save_path(slot)):
		return out
	var cur := MissionSave.load_into(save_path(slot), EPISODE_ID, missions)
	var found := 0
	for m in missions:
		found += m.found_emblems.size()
	out["empty"] = false
	out["emblems_found"] = found
	out["complete"] = cur == &""
	var mid: StringName = cur if cur != &"" else missions[missions.size() - 1].id
	var d: Dictionary = data.get(mid, {})
	out["mission"] = mid
	out["title_key"] = str(d.get("title_key", ""))
	out["icon"] = StringName(str(d.get("icon", "star")))
	var heroes: Array = d.get("heroes", ["tracker"])
	var hero := StringName(str(heroes[0])) if not heroes.is_empty() else &"tracker"
	if out["complete"]:
		hero = &"tracker"
	out["hero"] = hero
	out["portrait"] = "res://ui/portraits/%s_%s.png" % [PORTRAITS.get(hero, "rastro"), "alegre" if out["complete"] else "neutra"]
	return out


static func _valid(path: String) -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed is Dictionary and int((parsed as Dictionary).get("version", -1)) == MissionSave.VERSION \
		and str((parsed as Dictionary).get("episode", "")) == String(EPISODE_ID)


static func _mission_data() -> Dictionary:
	var out := {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MISSIONS_PATH))
	if parsed is Dictionary:
		for d: Variant in (parsed as Dictionary).get("missions", []):
			out[StringName(str((d as Dictionary)["id"]))] = d
	return out


static func _write_fresh(path: String) -> void:
	MissionSave.save(path, EPISODE_ID, Mission.load_list(MISSIONS_PATH))


static func _move(from: String, to: String) -> Error:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to))
