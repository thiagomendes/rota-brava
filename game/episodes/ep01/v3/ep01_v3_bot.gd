class_name Ep01V3Bot
extends Node
## Jogador automatico do Ep01 v3 (RB-R1 E1): percorre M0-M8 com ENTRADA REAL (intencoes da Input Map), por um caminho
## A* na grade de chao da vila (Ep01V3Nav) ate o marcador alvo. Nao altera regras: quem conta o progresso e a Mission.
## Falha cedo se nao houver caminho, se o heroi ficar preso (sem avancar, depois de replanejar) ou se passar do tempo.

signal finished(success: bool)

const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]
const STUCK_SECONDS := 4.0
const STUCK_MIN_MOVE := 0.4
const WAYPOINT_REACH := 0.6

var main: Ep01V3Main
var timeout_seconds: float = 400.0
var elapsed: float = 0.0
var done: bool = false
var fail_reason: String = ""
## Missoes concluidas na ordem, com o tempo de jogo de cada uma.
var history: Array[Dictionary] = []

var _mission: StringName = &""
var _route: Array[Vector3] = []
var _wp: int = 0
var _stuck_t: float = 0.0
var _stuck_from: Vector3 = Vector3.ZERO
var _replans: int = 0
var nav: Ep01V3Nav


func _ready() -> void:
	main.mission_completed.connect(func(id: StringName) -> void: history.append({"id": id, "t": elapsed}))
	main.episode_completed.connect(func() -> void: _finish(true))


func _physics_process(delta: float) -> void:
	if done or main == null or main.controlled_node == null:
		return
	elapsed += delta
	if elapsed > timeout_seconds:
		_finish(false, "timeout em %s" % _mission)
		return
	if main.current == null:
		_walk(Vector3.ZERO)
		return
	if main.current.id != _mission:
		_mission = main.current.id
		_replans = 0
		if not _plan():
			return
	var here := main.controlled_node.global_position
	var goal: Vector3
	if _wp < _route.size():
		goal = _route[_wp]
	else:
		var t := main.target_marker()
		if t == null:
			_walk(Vector3.ZERO)
			return
		goal = t.global_position
	var d := goal - here
	d.y = 0.0
	if _wp < _route.size() and d.length() <= WAYPOINT_REACH:
		_wp += 1
		return
	_walk(d.normalized() if d.length() > 0.05 else Vector3.ZERO)
	_stuck_t += delta
	if _stuck_t >= STUCK_SECONDS:
		if here.distance_to(_stuck_from) < STUCK_MIN_MOVE:
			if _replans >= 4:
				_finish(false, "preso em %s perto de %s (ponto %d de %d)" % [_mission, here, _wp, _route.size()])
				return
			_replans += 1
			# Recuo curto e bloqueio do ponto onde travou; o novo caminho parte de uma celula livre fora dele.
			var ahead := (_route[_wp] if _wp < _route.size() else here) - here
			nav.block(here + ahead.normalized() * 0.6 if ahead.length() > 0.05 else here, 0.6)
			_plan()
			return
		_stuck_t = 0.0
		_stuck_from = here


## Caminho do heroi ate o alvo da missao atual. false (e falha) se nao houver.
func _plan() -> bool:
	if nav == null:
		nav = Ep01V3Nav.new()
		nav.build(main.world.get_world_3d().direct_space_state)
	var t := main.target_marker()
	var from := main.controlled_node.global_position
	_route = nav.route(from, t.global_position, main.target_radius() * 0.8)
	_wp = 0
	_stuck_t = 0.0
	_stuck_from = from
	if _route.is_empty():
		_finish(false, "sem caminho para %s (%s) a partir de %s" % [_mission, t.name, from])
		return false
	return true


func _walk(dir_world: Vector3) -> void:
	var local := Basis(Vector3.UP, -main.camera_rig.yaw) * dir_world
	_hold(&"move_right", maxf(local.x, 0.0))
	_hold(&"move_left", maxf(-local.x, 0.0))
	_hold(&"move_down", maxf(local.z, 0.0))
	_hold(&"move_up", maxf(-local.z, 0.0))


func _hold(action: StringName, strength: float) -> void:
	if strength > 0.01:
		Input.action_press(action, clampf(strength, 0.0, 1.0))
	else:
		Input.action_release(action)


func _finish(ok: bool, reason: String = "") -> void:
	if done:
		return
	done = true
	fail_reason = reason
	for a in ACTIONS:
		Input.action_release(a)
	print("[RB] v3 bot %s %.1fs %s" % ["OK" if ok else "FALHA", elapsed, reason])
	finished.emit(ok)
