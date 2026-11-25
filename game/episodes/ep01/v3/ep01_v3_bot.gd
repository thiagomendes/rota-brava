class_name Ep01V3Bot
extends Node
## Jogador automatico do Ep01 v3 (RB-R1 E1/E4): percorre M0-M8 com ENTRADA REAL (intencoes da Input Map): anda por um
## caminho A* na grade de chao da vila (Ep01V3Nav) ate o alvo que a ajuda mostraria (`main.help_target()`), passa
## antes pelo emblema do heroi em controle, aperta `interact` no ponto de acao e confirma o cartao de troca de heroi.
## Nao altera regras: quem conta o progresso e a Mission. Falha cedo se nao houver caminho, se o heroi ficar preso
## (sem avancar, depois de replanejar) ou se passar do tempo. Ao sair da arvore, solta todas as acoes e devolve
## Engine.time_scale = 1 (mesmo se o teste abortar no meio).

signal finished(success: bool)

const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down", &"interact", &"help"]
const STUCK_SECONDS := 4.0
const STUCK_MIN_MOVE := 0.4
const WAYPOINT_REACH := 0.6
const PRESS_COOLDOWN := 0.5
## Perto e no mesmo nivel: anda reto (o A* nao precisa).
const DIRECT_RANGE := 1.6

var main: Ep01V3Main
var timeout_seconds: float = 600.0
var elapsed: float = 0.0
var done: bool = false
var fail_reason: String = ""
var collect_emblems: bool = true
## Missoes concluidas na ordem, com o tempo de jogo de cada uma.
var history: Array[Dictionary] = []
var presses: int = 0
var switches: int = 0

var _goal: Node3D
var _route: Array[Vector3] = []
var _wp: int = 0
var _stuck_t: float = 0.0
var _stuck_from: Vector3 = Vector3.ZERO
var _replans: int = 0
var _press_t: float = 0.0
var _hand_t: float = 0.0
## Depois de travar no caminho reto, este alvo so vai por A*.
var _force_route: bool = false
var nav: Ep01V3Nav


func _ready() -> void:
	main.mission_completed.connect(func(id: StringName) -> void: history.append({"id": id, "t": elapsed}))
	main.episode_completed.connect(func() -> void: _finish(true))


func _exit_tree() -> void:
	release_all()
	Engine.time_scale = 1.0


static func release_all() -> void:
	for a in ACTIONS:
		Input.action_release(a)


func _physics_process(delta: float) -> void:
	if done or main == null:
		return
	elapsed += delta
	_press_t -= delta
	if elapsed > timeout_seconds:
		_finish(false, "timeout em %s" % (main.current.id if main.current else &"-"))
		return
	if main.hud.handoff_open:
		_walk(Vector3.ZERO)
		_hand_t += delta
		if _hand_t > 0.6:
			_hand_t = 0.0
			switches += 1
			_tap(&"interact")
		return
	_hand_t = 0.0
	if main.blocked() or main.current == null:
		_walk(Vector3.ZERO)
		return
	var goal := _pick_goal()
	if goal == null:
		_walk(Vector3.ZERO)
		return
	if goal != _goal:
		_goal = goal
		_replans = 0
		_route.clear()
		_wp = 0
		_force_route = false
		_stuck_t = 0.0
		_stuck_from = main.controlled_node.global_position
	var here := main.controlled_node.global_position
	var it := goal as Ep01Interactable
	if it != null and not it.get_meta(&"auto", false) and main.best_interactable() == it:
		_walk(Vector3.ZERO)
		if _press_t <= 0.0:
			_press_t = PRESS_COOLDOWN
			presses += 1
			_tap(&"interact")
		return
	var target := goal.global_position
	var reach := (it.radius * 0.6) if it != null else main.target_radius() * 0.8
	var flat := target - here
	flat.y = 0.0
	var d: Vector3
	if not _force_route and flat.length() <= DIRECT_RANGE + reach and absf(target.y - here.y) < 0.6:
		d = flat
	else:
		if _route.is_empty() and not _plan(target, reach):
			return
		var g := _route[_wp] if _wp < _route.size() else target
		d = g - here
		d.y = 0.0
		if _wp < _route.size() and d.length() <= WAYPOINT_REACH:
			_wp += 1
			return
	_walk(d.normalized() if d.length() > 0.05 else Vector3.ZERO)
	_stuck_t += delta
	if _stuck_t >= STUCK_SECONDS:
		if here.distance_to(_stuck_from) < STUCK_MIN_MOVE:
			if _replans >= 4:
				_finish(false, "preso em %s perto de %s indo a %s" % [main.current.id, here, goal.name])
				return
			_replans += 1
			var ahead := (_route[_wp] if _wp < _route.size() else target) - here
			if nav != null:
				nav.block(here + ahead.normalized() * 0.6 if ahead.length() > 0.05 else here, 0.6)
			_route.clear()
			_force_route = true
		_stuck_t = 0.0
		_stuck_from = here


## Emblema do heroi em controle primeiro (opcional, mas o bot pega todos); depois o que a ajuda mostraria.
func _pick_goal() -> Node3D:
	if collect_emblems and main.land.handles(main.current.id):
		var e := main.land.emblem_for(main.active_member)
		# So emblemas no mesmo nivel (o do topo do galpao e pego quando o Pico esta la em cima).
		if e != null and absf(e.global_position.y - main.controlled_node.global_position.y) <= Ep01V3Main.INTERACT_DY:
			return e
	return main.help_target()


func _plan(target: Vector3, reach: float) -> bool:
	if nav == null:
		nav = Ep01V3Nav.new()
		nav.build(main.world.get_world_3d().direct_space_state)
	var from := main.controlled_node.global_position
	_route = nav.route(from, target, maxf(reach, 0.5))
	_wp = 0
	_stuck_t = 0.0
	_stuck_from = from
	if _route.is_empty():
		for m: StringName in main.actors:
			print("[RB] v3 bot ator %s em %s" % [m, (main.actors[m] as Node3D).global_position])
		_finish(false, "sem caminho em %s para %s (%s) a partir de %s" % [main.current.id, _goal.name, target, from])
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


## Aperto real: o mesmo evento que teclado/controle/toque geram (passa pelo HUD e pelo episodio).
func _tap(action: StringName) -> void:
	for p in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = p
		Input.parse_input_event(ev)


func _finish(ok: bool, reason: String = "") -> void:
	if done:
		return
	done = true
	fail_reason = reason
	release_all()
	print("[RB] v3 bot %s %.1fs %s" % ["OK" if ok else "FALHA", elapsed, reason])
	for h in history:
		print("[RB] v3 bot %s %.1f" % [h["id"], h["t"]])
	finished.emit(ok)
