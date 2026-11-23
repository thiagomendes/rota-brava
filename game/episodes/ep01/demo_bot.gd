class_name Ep01DemoBot
extends Node
## Jogador automatico: percorre o episodio inteiro injetando ENTRADA REAL (acoes da Input Map), como um jogador.
## Usos: gravacao do percurso (--ep01-demo) e teste ponta a ponta (test_playthrough.gd). Nao altera regras:
## o progresso continua sendo decidido pelo EpisodeDirector.

signal finished(success: bool)

var main: Ep01Main
var timeout_seconds: float = 600.0
var show_wrong_choice: bool = true
var elapsed: float = 0.0
var done: bool = false
var log_steps: bool = true

var _idle: float = 0.0
var _handoff_wait: float = 0.0
var _choice_stage: int = 0
var _wp_index: int = 0
var _wp_state: StringName = &""
var _tapped_at: float = -10.0
var _complete_wait: float = 0.0
var _held: Dictionary = {}
var _tries: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _physics_process(delta: float) -> void:
	if done or main == null or main.hud == null:
		return
	elapsed += delta
	if elapsed > timeout_seconds:
		_finish(false, "timeout em %s" % main.director.state)
		return
	var hud := main.hud
	if hud.complete_open:
		_release_all()
		_complete_wait += delta
		if _complete_wait > 3.0:
			_finish(main.director.state == &"complete")
		return
	if hud.pause_open:
		return
	if hud.handoff_open:
		_release_all()
		_handoff_wait += delta
		if _handoff_wait > 0.8:
			_handoff_wait = 0.0
			_tap(&"interact")
		return
	_handoff_wait = 0.0
	if hud.choice_open:
		_release_all()
		_handle_choice(delta)
		return
	var state := main.director.state
	if state != _wp_state:
		_wp_state = state
		_wp_index = 0
		_tries.clear()
		_step("estado %s" % state)
	if main.controlled_node == null:
		_release_all()
		return
	match state:
		&"dock_investigation":
			_seek_interactable(delta)
		&"river_search":
			_drive_boat_waypoints(_river_waypoints(), 2.8, 0.6)
		&"island_crossing":
			_island(delta)
		&"docking":
			_dock(delta)
		&"return_trip":
			_seek_interactable(delta)
		_:
			_release_all()


func _step(text: String) -> void:
	if log_steps:
		print("[RB] bot %s (t=%.1fs)" % [text, elapsed])


func _finish(success: bool, reason: String = "") -> void:
	if done:
		return
	done = true
	_release_all()
	print("[RB] bot fim success=%s %s" % [success, reason])
	finished.emit(success)


# ---------- entrada ----------

func _tap(action: StringName) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	get_tree().create_timer(0.08).timeout.connect(func() -> void: Input.parse_input_event(up))


func _hold(action: StringName, strength: float) -> void:
	if strength > 0.01:
		Input.action_press(action, clampf(strength, 0.0, 1.0))
		_held[action] = true
	elif _held.has(action):
		Input.action_release(action)
		_held.erase(action)


func _release_all() -> void:
	for a: StringName in _held.keys():
		Input.action_release(a)
	_held.clear()


## Direcao desejada em coordenadas do mundo -> intencoes de movimento (considera o giro da camera).
func _walk_dir(dir_world: Vector3) -> void:
	var local := Basis(Vector3.UP, -main.camera_rig.yaw) * dir_world
	_hold(&"move_right", maxf(local.x, 0.0))
	_hold(&"move_left", maxf(-local.x, 0.0))
	_hold(&"move_down", maxf(local.z, 0.0))
	_hold(&"move_up", maxf(-local.z, 0.0))


func _walk_to(target: Vector3, stop_distance: float) -> bool:
	var here := main.controlled_node.global_position
	var d := target - here
	d.y = 0.0
	if d.length() <= stop_distance:
		_walk_dir(Vector3.ZERO)
		return true
	_walk_dir(d.normalized())
	return false


func _handle_choice(delta: float) -> void:
	_idle += delta
	if _idle < 0.9:
		return
	_idle = 0.0
	if show_wrong_choice and _choice_stage == 0:
		_choice_stage = 1
		_step("escolhe o cais (errado, para ver a observacao)")
		_tap(&"ui_down")
		get_tree().create_timer(0.4).timeout.connect(func() -> void: _tap(&"ui_accept"))
	else:
		_step("escolhe a margem")
		_tap(&"ui_accept")


# ---------- estagios a pe ----------

func _usable_targets() -> Array[Ep01Interactable]:
	var out: Array[Ep01Interactable] = []
	for n in get_tree().get_nodes_in_group(Ep01Interactable.GROUP):
		var it := n as Ep01Interactable
		if it != null and it.can_use(main.director.active_member):
			out.append(it)
	return out


func _seek_interactable(delta: float) -> void:
	if main.hud.is_speaking():
		_release_all()
		return
	var here := main.controlled_node.global_position
	var best: Ep01Interactable = null
	var best_d := INF
	var best_tries := 1 << 30
	for it in _usable_targets():
		var d := it.distance_to(here)
		var tries: int = _tries.get(it.action_id, 0)
		# Prefere o que ainda nao tentou; entre iguais, o mais proximo.
		if tries < best_tries or (tries == best_tries and d < best_d):
			best = it
			best_d = d
			best_tries = tries
	if best == null:
		_release_all()
		return
	if best_d <= best.radius * 0.6:
		_release_all()
		_idle += delta
		if _idle > 0.5 and elapsed - _tapped_at > 1.5:
			_idle = 0.0
			_tapped_at = elapsed
			_step("interage %s" % best.action_id)
			_tries[best.action_id] = int(_tries.get(best.action_id, 0)) + 1
			_tap(&"interact")
	else:
		_idle = 0.0
		_walk_to(best.global_position, best.radius * 0.5)


func _island(delta: float) -> void:
	var stones: Array = Ep01Layout.ROCK_FOOTHOLDS
	var progress := main.director.last_safe_foothold
	if main.hud.is_speaking() and progress < 3:
		_release_all()
		return
	if progress < 3:
		var target: Vector3 = stones[progress]
		_walk_to(target, 0.25)
		return
	_seek_interactable(delta)


# ---------- barco ----------

func _river_waypoints() -> Array[Vector3]:
	var b := Ep01Layout.BUOY_POS
	var pts: Array[Vector3] = [Vector3(-6, 0, -9), Vector3(10, 0, -8), Vector3(26, 0, -7)]
	for deg in [180, 225, 270, 315, 360, 405, 450, 495, 540]:
		var a := deg_to_rad(float(deg))
		pts.append(b + Vector3(cos(a), 0, sin(a)) * 6.0)
	pts.append_array([Vector3(58, 0, 4), Vector3(76, 0, 9), Ep01Layout.ENSEADA_POS])
	return pts


func _drive_boat_waypoints(points: Array[Vector3], reach: float, throttle: float) -> bool:
	if _wp_index >= points.size():
		_hold(&"move_up", 0.0)
		_hold(&"move_left", 0.0)
		_hold(&"move_right", 0.0)
		return true
	var boat := main.boat
	var d := points[_wp_index] - boat.global_position
	d.y = 0.0
	if log_steps and int(elapsed) % 5 == 0 and absf(elapsed - roundf(elapsed)) < 0.02:
		print("[RB] bot barco pos=(%.1f, %.1f) rumo=%.2f vel=%.2f alvo#%d=(%.1f, %.1f) dist=%.1f" % [
			boat.global_position.x, boat.global_position.z, boat.heading, boat.speed,
			_wp_index, points[_wp_index].x, points[_wp_index].z, d.length()])
	if d.length() <= reach:
		_wp_index += 1
		return false
	_steer_boat(d, throttle)
	return false


func _steer_boat(d: Vector3, throttle: float) -> void:
	var boat := main.boat
	var wanted := atan2(-d.x, -d.z)
	var err := wrapf(wanted - boat.heading, -PI, PI)
	var steer := clampf(err * 2.0, -1.0, 1.0)
	_hold(&"move_left", maxf(steer, 0.0))
	_hold(&"move_right", maxf(-steer, 0.0))
	var t := throttle * (0.35 if absf(err) > 0.9 else 1.0)
	_hold(&"move_up", t)


func _dock(delta: float) -> void:
	var boat := main.boat
	var target := Ep01Layout.DOCKING_TARGET_POS
	var to_target := target - boat.global_position
	to_target.y = 0.0
	var usable := false
	for it in _usable_targets():
		if it.action_id != &"":
			usable = true
	if usable:
		_hold(&"move_up", 0.0)
		_hold(&"move_left", 0.0)
		_hold(&"move_right", 0.0)
		_idle += delta
		if boat.speed < 0.6 and _idle > 0.5 and elapsed - _tapped_at > 1.5:
			_idle = 0.0
			_tapped_at = elapsed
			_step("embarcar")
			_tap(&"interact")
		return
	_idle = 0.0
	var approach := Vector3(target.x, 0, target.z + 8.0)
	var aim := target if boat.global_position.z < approach.z + 1.0 else approach
	var d := aim - boat.global_position
	d.y = 0.0
	var dist := to_target.length()
	var throttle := clampf(dist / 8.0, 0.25, 1.0)
	_steer_boat(d, throttle)
