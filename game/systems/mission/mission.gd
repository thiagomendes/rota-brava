class_name Mission
extends RefCounted
## Missao curta (RB-R1 E2): passos com icone e condicao, herois exigidos, emblemas, ponto seguro sem castigo.
## Independente do mundo: o jogo informa o que aconteceu com `notify(event, hero)` e escuta os sinais.
## Textos so por chave do catalogo (`*_key`); aqui nunca ha texto visivel.

enum State { INACTIVE, ACTIVE, COMPLETED }

signal started(mission_id: StringName)
signal step_started(mission_id: StringName, step_index: int, step_id: StringName)
signal step_done(mission_id: StringName, step_index: int, step_id: StringName)
signal completed(mission_id: StringName)
signal emblem_found(mission_id: StringName, emblem_id: StringName, found: int, total: int)
## O passo atual pede outro heroi: o jogo mostra o icone e a crianca confirma (nada e forcado).
signal hero_switch_requested(mission_id: StringName, hero: StringName, icon: StringName)
## Erro sem castigo: o jogo devolve o heroi ao ponto seguro e mostra/fala a observacao (`obs_key`).
signal returned_to_safe_point(mission_id: StringName, point_id: StringName, obs_key: StringName)
## Qualquer progresso (contagem de passo, passo novo ou emblema): a ajuda zera a contagem.
signal progressed(mission_id: StringName)

const STEP_FIELDS: Array[String] = ["id", "icon", "hero", "event", "target", "safe_point", "obs_key", "hint_gesture_key",
	"hint_spoken_key"]

var id: StringName = &""
var order: int = 0
var title_key: StringName = &""
var heroes: Array[StringName] = []
## Cada passo: {id, icon, hero (&"" = qualquer), event, count, target, safe_point, obs_key, hint_gesture_key, hint_spoken_key}
var steps: Array[Dictionary] = []
var emblems: Array[StringName] = []
var state: State = State.INACTIVE
var step_index: int = 0
var step_progress: int = 0
var found_emblems: Array[StringName] = []
var active_hero: StringName = &""
var _switch_asked_for: int = -1


static func from_dict(d: Dictionary) -> Mission:
	var m := Mission.new()
	m.id = StringName(str(d.get("id", "")))
	m.order = int(d.get("order", 0))
	m.title_key = StringName(str(d.get("title_key", "")))
	var hs: Variant = d.get("heroes", [])
	for h: Variant in (hs if hs is Array else []):
		m.heroes.append(StringName(str(h)))
	var es: Variant = d.get("emblems", [])
	for e: Variant in (es if es is Array else []):
		m.emblems.append(StringName(str(e)))
	var ss: Variant = d.get("steps", [])
	for s: Variant in (ss if ss is Array else []):
		if not s is Dictionary:
			continue   # item invalido: ignorado
		var sd := s as Dictionary
		var step := {"count": maxi(1, int(sd.get("count", 1)))}
		for f in STEP_FIELDS:
			step[f] = StringName(str(sd.get(f, "")))
		m.steps.append(step)
	return m


## Missoes de um JSON `{"version": 1, "episode": "...", "missions": [...]}`, ordenadas por `order`.
static func load_list(path: String) -> Array[Mission]:
	var out: Array[Mission] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("Mission: JSON invalido: " + path)
		return out
	var list: Variant = (parsed as Dictionary).get("missions", [])
	for d: Variant in (list if list is Array else []):
		if d is Dictionary:
			out.append(Mission.from_dict(d as Dictionary))
	out.sort_custom(func(a: Mission, b: Mission) -> bool: return a.order < b.order)
	return out


## Todas as chaves de catalogo que a missao usa (para testes de i18n).
func text_keys() -> Array[String]:
	var out: Array[String] = []
	if title_key != &"":
		out.append(String(title_key))
	for s in steps:
		for f in ["obs_key", "hint_gesture_key", "hint_spoken_key"]:
			if s[f] != &"":
				out.append(String(s[f]))
	return out


## Comeca (ou recomeca) do primeiro passo. `hero` e o heroi em controle agora.
func start(hero: StringName = &"") -> void:
	state = State.ACTIVE
	step_index = 0
	step_progress = 0
	_switch_asked_for = -1
	if hero != &"":
		active_hero = hero
	started.emit(id)
	_enter_step()


func is_active() -> bool:
	return state == State.ACTIVE


func is_completed() -> bool:
	return state == State.COMPLETED


func current_step() -> Dictionary:
	return steps[step_index] if state == State.ACTIVE and step_index < steps.size() else {}


func required_hero() -> StringName:
	var s := current_step()
	return s["hero"] if not s.is_empty() else &""


## Heroi em controle mudou (troca feita pela crianca).
func set_active_hero(hero: StringName) -> void:
	active_hero = hero
	_check_hero()


## O jogo informa um acontecimento. Conta para o passo atual se `event` bate e o heroi serve; com heroi errado, pede a
## troca (sinal) e nao conta. Retorna true se contou.
func notify(event: StringName, hero: StringName = &"") -> bool:
	if state != State.ACTIVE:
		return false
	var s := current_step()
	if s.is_empty() or s["event"] != event:
		return false
	var who := hero if hero != &"" else active_hero
	var need: StringName = s["hero"]
	if need != &"" and who != need:
		_switch_asked_for = -1
		_check_hero(who)
		return false
	step_progress += 1
	progressed.emit(id)
	if step_progress >= int(s["count"]):
		step_done.emit(id, step_index, s["id"])
		step_index += 1
		step_progress = 0
		if step_index >= steps.size():
			state = State.COMPLETED
			completed.emit(id)
		else:
			_enter_step()
	return true


## Emblema da missao achado. Cada um conta uma vez; ids fora da lista sao ignorados.
func find_emblem(emblem_id: StringName) -> bool:
	if state == State.INACTIVE or not emblem_id in emblems or emblem_id in found_emblems:
		return false
	found_emblems.append(emblem_id)
	emblem_found.emit(id, emblem_id, found_emblems.size(), emblems.size())
	progressed.emit(id)
	return true


## Erro na tentativa (queda, entrega errada): sem perder progresso, avisa o ponto seguro do passo e a observacao.
func return_to_safe_point() -> bool:
	var s := current_step()
	if s.is_empty() or s["safe_point"] == &"":
		return false
	returned_to_safe_point.emit(id, s["safe_point"], s["obs_key"])
	return true


## Estado simples para o salvamento (IDs e numeros).
func snapshot() -> Dictionary:
	var em: Array[String] = []
	for e in found_emblems:
		em.append(String(e))
	return {"id": String(id), "state": int(state), "emblems": em}


## Restaura do salvo. Missao ativa nunca e restaurada no meio: volta inativa, pronta para `start()` do primeiro passo.
func restore(d: Dictionary) -> void:
	var st := int(d.get("state", State.INACTIVE))
	state = State.COMPLETED if st == State.COMPLETED else State.INACTIVE
	found_emblems.clear()
	for e: Variant in d.get("emblems", []):
		var eid := StringName(str(e))
		if eid in emblems and not eid in found_emblems:
			found_emblems.append(eid)
	step_index = steps.size() if state == State.COMPLETED else 0
	step_progress = 0
	_switch_asked_for = -1


func _enter_step() -> void:
	var s := current_step()
	step_started.emit(id, step_index, s["id"])
	_check_hero()


func _check_hero(who: StringName = &"") -> void:
	var need := required_hero()
	var current := who if who != &"" else active_hero
	if need == &"" or current == need or _switch_asked_for == step_index:
		return
	_switch_asked_for = step_index
	hero_switch_requested.emit(id, need, StringName("hero_" + String(need)))
