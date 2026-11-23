class_name EpisodeDirector
extends RefCounted
## Maquina de estados do Episodio 01 (logica pura, sem nos). Contrato: specs/features/RB-02.md.
## Ordem de validacao (decisao de ambiguidade): evento desconhecido -> invalid_payload;
## estado -> wrong_state; fonte -> wrong_member; payload -> invalid_payload;
## depois regras do evento (duplicate, out_of_order, wrong_destination, missing_prerequisite).
## restore() nao emite sinais. destination 'harbor' e rejeitado como wrong_destination
## mesmo com menos de 2 pistas.

signal state_changed(old: StringName, new: StringName)
signal event_accepted(event: StringName, payload: Dictionary)
signal event_rejected(event: StringName, reason: StringName)
signal active_member_changed(member: StringName)
signal episode_completed

const SCHEMA_VERSION := 1
const EPISODE_ID := &"ep01"
const CLUES: Array[StringName] = [&"paw_print_bench", &"boot_print_bank"]
const STATES: Array[StringName] = [&"arrival", &"dock_investigation", &"river_search",
		&"island_crossing", &"docking", &"return_trip", &"complete"]
## Integrante ativo por estado.
const ACTIVE_BY_STATE := {
	&"arrival": &"", &"dock_investigation": &"tracker", &"river_search": &"pilot",
	&"island_crossing": &"climber", &"docking": &"pilot", &"return_trip": &"pilot",
	&"complete": &"",
}
## Regras: evento -> estado exigido, fonte exigida ("" = qualquer).
const RULES := {
	&"intro_finished": {"state": &"arrival", "source": &""},
	&"clue_examined": {"state": &"dock_investigation", "source": &"tracker"},
	&"destination_chosen": {"state": &"dock_investigation", "source": &"tracker"},
	&"buoy_rounded": {"state": &"river_search", "source": &"pilot"},
	&"cove_reached": {"state": &"river_search", "source": &"pilot"},
	&"foothold_reached": {"state": &"island_crossing", "source": &"climber"},
	&"foothold_missed": {"state": &"island_crossing", "source": &"climber"},
	&"line_fixed": {"state": &"island_crossing", "source": &"climber"},
	&"boat_docked": {"state": &"docking", "source": &"pilot"},
	&"departure_confirmed": {"state": &"return_trip", "source": &"pilot"},
}

var state: StringName = &"arrival"
var active_member: StringName = &""
var clues_found: Array[StringName] = []
var buoy_rounded: bool = false
var line_fixed: bool = false
var last_safe_foothold: int = 0
var completed_episodes: Array[StringName] = []


func submit(event: StringName, source: StringName, payload: Dictionary = {}) -> Dictionary:
	if not RULES.has(event):
		return _reject(event, &"invalid_payload")
	var rule: Dictionary = RULES[event]
	if state != rule["state"]:
		return _reject(event, &"wrong_state")
	if rule["source"] != &"" and source != rule["source"]:
		return _reject(event, &"wrong_member")
	var res := _apply(event, payload)
	if not res["accepted"]:
		return _reject(event, res["reason"])
	var next: StringName = res.get("next", &"")
	var out := {"accepted": true, "reason": &"", "state_changed": next != &""}
	for k in res:
		if k != "next" and k != "accepted" and k != "reason":
			out[k] = res[k]
	event_accepted.emit(event, payload)
	if next != &"":
		_enter(next)
	return out


func start_new_run() -> void:
	var old := state
	var old_member := active_member
	_reset_run()
	if old != state:
		state_changed.emit(old, state)
	if old_member != active_member:
		active_member_changed.emit(active_member)


func snapshot() -> Dictionary:
	var clues: Array = []
	for c in clues_found:
		clues.append(String(c))
	var done: Array = []
	for e in completed_episodes:
		done.append(String(e))
	return {
		"schema_version": SCHEMA_VERSION, "state": String(state), "clues_found": clues,
		"buoy_rounded": buoy_rounded, "line_fixed": line_fixed,
		"last_safe_foothold": last_safe_foothold, "completed_episodes": done,
	}


## Devolve false (mantendo o estado) para dado invalido ou versao desconhecida.
func restore(d: Dictionary) -> bool:
	if not _is_int(d.get("schema_version")) or int(d["schema_version"]) != SCHEMA_VERSION:
		return false
	var st: Variant = d.get("state")
	if not (st is String or st is StringName) or not STATES.has(StringName(st)):
		return false
	var s := StringName(st)
	var clues: Variant = _id_list(d.get("clues_found"), CLUES)
	var done: Variant = _id_list(d.get("completed_episodes"), [EPISODE_ID])
	if clues == null or done == null:
		return false
	if not (d.get("buoy_rounded") is bool) or not (d.get("line_fixed") is bool):
		return false
	if not _is_int(d.get("last_safe_foothold")):
		return false
	var foot := int(d["last_safe_foothold"])
	if foot < 0 or foot > 3:
		return false
	# Coerencia do progresso com o estado.
	var idx := STATES.find(s)
	if idx > 1 and clues.size() != 2:
		return false
	if idx > 2 and not d["buoy_rounded"]:
		return false
	if idx > 3 and (foot != 3 or not d["line_fixed"]):
		return false
	if idx <= 3 and d["line_fixed"]:
		return false
	if idx < 3 and foot != 0:
		return false
	if s == &"complete" and not done.has(EPISODE_ID):
		return false
	var typed_clues: Array[StringName] = []
	for c in clues:
		typed_clues.append(c)
	var typed_done: Array[StringName] = []
	for e in done:
		typed_done.append(e)
	var old := state
	var old_member := active_member
	state = s
	active_member = ACTIVE_BY_STATE[s]
	clues_found = typed_clues
	buoy_rounded = d["buoy_rounded"]
	line_fixed = d["line_fixed"]
	last_safe_foothold = foot
	completed_episodes = typed_done
	if old != state:
		state_changed.emit(old, state)
	if old_member != active_member:
		active_member_changed.emit(active_member)
	return true


func _apply(event: StringName, p: Dictionary) -> Dictionary:
	match event:
		&"intro_finished":
			return _ok(&"dock_investigation")
		&"clue_examined":
			var clue: Variant = p.get("clue_id")
			if not (clue is String or clue is StringName) or not CLUES.has(StringName(clue)):
				return _no(&"invalid_payload")
			if clues_found.has(StringName(clue)):
				return _no(&"duplicate")
			clues_found.append(StringName(clue))
			return _ok()
		&"destination_chosen":
			var dest: Variant = p.get("destination")
			if not (dest is String or dest is StringName) or not [&"bank", &"harbor"].has(StringName(dest)):
				return _no(&"invalid_payload")
			if StringName(dest) == &"harbor":
				return _no(&"wrong_destination")
			if clues_found.size() < CLUES.size():
				return _no(&"missing_prerequisite")
			return _ok(&"river_search")
		&"buoy_rounded":
			if buoy_rounded:
				return _no(&"duplicate")
			buoy_rounded = true
			return _ok()
		&"cove_reached":
			if not buoy_rounded:
				return _no(&"missing_prerequisite")
			return _ok(&"island_crossing")
		&"foothold_reached":
			var i: Variant = p.get("index")
			if not _is_int(i) or int(i) < 1 or int(i) > 3:
				return _no(&"invalid_payload")
			if int(i) <= last_safe_foothold:
				return _no(&"duplicate")
			if int(i) != last_safe_foothold + 1:
				return _no(&"out_of_order")
			last_safe_foothold = int(i)
			return _ok()
		&"foothold_missed":
			return _ok(&"", {"respawn_foothold": last_safe_foothold})
		&"line_fixed":
			if last_safe_foothold != 3:
				return _no(&"missing_prerequisite")
			line_fixed = true
			return _ok(&"docking")
		&"boat_docked":
			var al: Variant = p.get("aligned")
			if not (al is bool):
				return _no(&"invalid_payload")
			if not line_fixed or not al:
				return _no(&"missing_prerequisite")
			return _ok(&"return_trip")
		&"departure_confirmed":
			return _ok(&"complete")
	return _no(&"invalid_payload")


func _enter(next: StringName) -> void:
	var old := state
	state = next
	var member: StringName = ACTIVE_BY_STATE[next]
	var member_changed := member != active_member
	active_member = member
	state_changed.emit(old, next)
	if member_changed:
		active_member_changed.emit(member)
	if next == &"complete":
		var first := not completed_episodes.has(EPISODE_ID)
		if first:
			completed_episodes.append(EPISODE_ID)
		episode_completed.emit()


func _reset_run() -> void:
	state = &"arrival"
	active_member = &""
	clues_found = []
	buoy_rounded = false
	line_fixed = false
	last_safe_foothold = 0


func _reject(event: StringName, reason: StringName) -> Dictionary:
	event_rejected.emit(event, reason)
	return {"accepted": false, "reason": reason, "state_changed": false}


func _ok(next: StringName = &"", extra: Dictionary = {}) -> Dictionary:
	var d := {"accepted": true, "next": next}
	d.merge(extra)
	return d


func _no(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason}


static func _is_int(v: Variant) -> bool:
	return (v is int) or (v is float and v == floorf(v))


## Lista de IDs unicos e conhecidos, ou null se invalida.
static func _id_list(v: Variant, allowed: Array) -> Variant:
	if not (v is Array):
		return null
	var out: Array = []
	for x in v:
		if not (x is String or x is StringName) or not allowed.has(StringName(x)):
			return null
		if out.has(StringName(x)):
			return null
		out.append(StringName(x))
	return out

