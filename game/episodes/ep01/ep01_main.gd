class_name Ep01Main
extends Node3D
## Cena principal do Episodio 01: monta o mundo, os atores, a camera e o HUD, e liga o EpisodeDirector aos estagios.
## O diretor decide o progresso; os estagios apresentam e enviam eventos por `submit` (SPEC secao 7).

const MENU_SCENE := "res://ui/main_menu.tscn"
const IDLE_HINT_SECONDS := 25.0

## Execucao nova: registro de conclusao sobrevive a recarga da cena (a persistencia em disco e do RB-05).
static var carry_completed: Array[StringName] = []
## Teste/dev: inicia direto neste estado (apos fast_forward pela API do diretor). Vazio = comeco normal.
static var start_state: StringName = &""

## Arquivo do estagio por estado. `return_trip` usa a mesma instancia de `docking`.
const STAGE_DIR := {
	&"arrival": "arrival",
	&"dock_investigation": "dock",
	&"river_search": "river",
	&"island_crossing": "island",
	&"docking": "docking",
	&"return_trip": "docking",
}

var director := EpisodeDirector.new()
var hud: Hud
var camera_rig: CameraRig
var boat: BoatActor
var actors: Dictionary = {}
var stages: Dictionary = {}
var current_stage: StageBase
var controlled_node: Node3D
var world: Node3D
var idle_seconds: float = 0.0
var hint_index: int = 0
var simulating: bool = false

var _current_target: Ep01Interactable
var _pending: Array = []
var _transitioning: bool = false
var _silent: bool = false
var _last_member: StringName = &""


func _ready() -> void:
	name = "Ep01Main"
	director.completed_episodes = carry_completed.duplicate()
	_build_environment()
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	for m: StringName in [&"tracker", &"climber", &"pilot"]:
		var a := MemberActor.new()
		a.setup(m)
		world.add_child(a)
		actors[m] = a
	boat = BoatActor.new()
	world.add_child(boat)
	boat.place(Ep01Layout.BOAT_DOCKED_POS, Ep01Layout.BOAT_DOCKED_HEADING)
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	_load_stages()
	hud = Hud.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	director.state_changed.connect(_on_state_changed)
	director.event_accepted.connect(_on_event_accepted)
	director.event_rejected.connect(func(e: StringName, r: StringName) -> void: print("[RB] rejected %s %s" % [e, r]))
	hud.replay_requested.connect(_on_replay)
	hud.menu_requested.connect(_on_menu)
	hud.resume_requested.connect(_resume)
	hud.pause_requested.connect(_pause)
	var start := String(start_state) if start_state != &"" else _user_arg("--ep01-start")
	if start.is_empty():
		_begin_normal()
	else:
		start_at(StringName(start))


func _user_arg(flag: String) -> String:
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with(flag + "="):
			return arg.trim_prefix(flag + "=")
	return ""


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9fd3e6")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dfeaf2")
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	var water := MeshInstance3D.new()
	water.name = "Water"
	var pm := PlaneMesh.new()
	pm.size = Vector2(340, 160)
	water.mesh = pm
	water.material_override = Blocks.material(Color("2f8f9d"))
	water.position = Vector3(55, Ep01Layout.WATER_Y, 0)
	water.set_meta(Blocks.PROVISIONAL, true)
	add_child(water)


func _load_stages() -> void:
	var cache: Dictionary = {}
	for state: StringName in STAGE_DIR:
		var dir: String = STAGE_DIR[state]
		if cache.has(dir):
			stages[state] = cache[dir]
			continue
		var path := "res://episodes/ep01/stages/%s/%s_stage.gd" % [dir, dir]
		var stage: StageBase
		if ResourceLoader.exists(path):
			stage = (load(path) as GDScript).new() as StageBase
		else:
			stage = PlaceholderStage.new()
		stage.name = "Stage_" + dir
		stage.state_id = state
		world.add_child(stage)
		stage.setup(self)
		cache[dir] = stage
		stages[state] = stage


# ---------- eventos e progresso ----------

func submit(event: StringName, source: StringName, payload: Dictionary = {}) -> Dictionary:
	return director.submit(event, source, payload)


func say_lines(state: StringName, key: String) -> void:
	await hud.say_all(Ep01Content.lines(state, key))


func _on_event_accepted(event: StringName, payload: Dictionary) -> void:
	idle_seconds = 0.0
	hint_index = 0
	print("[RB] event %s %s" % [event, payload])


func _on_state_changed(old: StringName, new: StringName) -> void:
	print("[RB] state %s -> %s" % [old, new])
	if _silent:
		return
	_pending.append([old, new])
	if not _transitioning:
		_run_transitions()


func _run_transitions() -> void:
	_transitioning = true
	while not _pending.is_empty():
		var t: Array = _pending.pop_front()
		await _transition(t[0] as StringName, t[1] as StringName)
	_transitioning = false


func _transition(old: StringName, new: StringName) -> void:
	var prev: StringName = director.ACTIVE_BY_STATE.get(old, &"")
	hud.clear_speech(true)
	set_controlled(null)
	_hide_prompt()
	if stages.has(old):
		(stages[old] as StageBase).exit()
	_enter_stage(new)
	if new == &"complete":
		await hud.wait_silent()
		await get_tree().create_timer(1.0).timeout
		hud.open_complete()
		return
	var next: StringName = director.ACTIVE_BY_STATE.get(new, &"")
	if next != &"":
		await _handoff(prev, next)


func _enter_stage(state: StringName) -> void:
	current_stage = stages.get(state)
	for s: StageBase in _unique_stages():
		s.refresh_world()
	hud.set_objective(Loc.t(Ep01Content.objective_key(state)), Ep01Content.objective_icon(state))
	hud.set_skip_hint(false)
	idle_seconds = 0.0
	hint_index = 0
	if current_stage:
		current_stage.enter()


func _unique_stages() -> Array[StageBase]:
	var out: Array[StageBase] = []
	for s: StageBase in stages.values():
		if not out.has(s):
			out.append(s)
	return out


# ---------- troca de integrante ----------

func _handoff(prev: StringName, next: StringName) -> void:
	var focus := current_stage.focus_node(next)
	if prev != &"" and actors.has(prev) and focus != null:
		(actors[prev] as MemberActor).face_point(focus.global_position)
	if focus != null:
		_apply_view()
		camera_rig.follow(focus)
	await get_tree().create_timer(0.9).timeout
	var next_name := Loc.member_name(next)
	var text := Loc.t("ui.swap.confirm", {"name": next_name, "skill": Loc.member_skill(next)})
	if prev != &"":
		text = Loc.t("ui.swap.look", {"name": Loc.member_name(prev), "other": next_name}) + "\n" + text
	hud.open_handoff(text, next)
	await hud.handoff_confirmed
	_give_control(next)


func _give_control(member: StringName) -> void:
	_last_member = member
	set_controlled(current_stage.controlled_node(member))
	current_stage.control_started(member)


func set_controlled(node: Node3D) -> void:
	controlled_node = node
	for m: StringName in actors:
		(actors[m] as MemberActor).controlled = (actors[m] == node)
	boat.controlled = (node == boat)
	hud.set_member(director.active_member if node != null else &"")
	if node != null:
		_apply_view()
		camera_rig.follow(node)
	idle_seconds = 0.0


func _apply_view() -> void:
	if current_stage:
		var v := current_stage.camera_view()
		camera_rig.set_view(v.get("offset", camera_rig.offset), v.get("yaw", 0.0))


# ---------- inicio ----------

func _begin_normal() -> void:
	_enter_stage(director.state)
	camera_rig.follow(boat, true)


## Atalho de desenvolvimento/verificacao: avanca o diretor pela API publica ate `target` e entrega o controle.
func start_at(target: StringName) -> void:
	_silent = true
	fast_forward(target)
	_silent = false
	_enter_stage(director.state)
	var member: StringName = director.ACTIVE_BY_STATE.get(director.state, &"")
	if member != &"":
		_give_control(member)
	camera_rig.follow(controlled_node if controlled_node else boat, true)


func fast_forward(target: StringName) -> void:
	var script: Array = [
		[&"arrival", &"intro_finished", &"pilot", {}],
		[&"dock_investigation", &"clue_examined", &"tracker", {"clue_id": &"paw_print_bench"}],
		[&"dock_investigation", &"clue_examined", &"tracker", {"clue_id": &"boot_print_bank"}],
		[&"dock_investigation", &"destination_chosen", &"tracker", {"destination": &"bank"}],
		[&"river_search", &"buoy_rounded", &"pilot", {}],
		[&"river_search", &"cove_reached", &"pilot", {}],
		[&"island_crossing", &"foothold_reached", &"climber", {"index": 1}],
		[&"island_crossing", &"foothold_reached", &"climber", {"index": 2}],
		[&"island_crossing", &"foothold_reached", &"climber", {"index": 3}],
		[&"island_crossing", &"line_fixed", &"climber", {}],
		[&"docking", &"boat_docked", &"pilot", {"aligned": true}],
		[&"return_trip", &"departure_confirmed", &"pilot", {}],
	]
	for step: Array in script:
		if director.state == target:
			return
		if director.state == step[0]:
			director.submit(step[1] as StringName, step[2] as StringName, step[3] as Dictionary)


# ---------- interacao contextual ----------

func _process(delta: float) -> void:
	for m: StringName in actors:
		(actors[m] as MemberActor).move_yaw = camera_rig.yaw
	if current_stage:
		current_stage.process_stage(delta)
	_update_prompt()
	_update_idle(delta)


func best_interactable() -> Ep01Interactable:
	if controlled_node == null:
		return null
	var best: Ep01Interactable = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(Ep01Interactable.GROUP):
		var it := n as Ep01Interactable
		if it == null or not it.can_use(director.active_member):
			continue
		var d := it.distance_to(controlled_node.global_position)
		if d <= it.radius and d < best_d:
			best = it
			best_d = d
	return best


func _blocked() -> bool:
	return hud.handoff_open or hud.choice_open or hud.pause_open or hud.complete_open


func _update_prompt() -> void:
	var target: Ep01Interactable = null if _blocked() else best_interactable()
	if target == _current_target and (target == null) == (not hud.prompt_visible()):
		return
	_current_target = target
	if target == null:
		_hide_prompt()
	else:
		hud.show_prompt(Loc.t(target.label_key, target.label_params), target.icon)


func _hide_prompt() -> void:
	_current_target = null
	hud.hide_prompt()


func try_interact() -> bool:
	if _blocked() or controlled_node == null:
		return false
	var target := best_interactable()
	if target == null:
		return false
	idle_seconds = 0.0
	target.trigger(controlled_node)
	return true


func _update_idle(delta: float) -> void:
	if controlled_node == null or _blocked() or hud.is_speaking():
		return
	idle_seconds += delta
	if idle_seconds < IDLE_HINT_SECONDS:
		return
	idle_seconds = 0.0
	var hints := Ep01Content.hints(director.state)
	if hints.is_empty():
		return
	var h: Dictionary = hints[mini(hint_index, hints.size() - 1)]
	hint_index += 1
	hud.say(String(h["key"]), {}, true)
	if String(h.get("kind", "")) == "gesture" and current_stage:
		current_stage.gesture_hint(String(h["key"]))


# ---------- entrada, pausa e fim ----------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed(&"interact"):
		if try_interact():
			get_viewport().set_input_as_handled()


func _pause() -> void:
	get_tree().paused = true
	hud.open_pause()


func _resume() -> void:
	get_tree().paused = false
	hud.close_pause()


func _on_replay() -> void:
	carry_completed = director.completed_episodes.duplicate()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu() -> void:
	carry_completed = director.completed_episodes.duplicate()
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
