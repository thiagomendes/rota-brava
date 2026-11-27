class_name Ep01V3Bot
extends Node
## Jogador automatico do Ep01 v3 (RB-R1 E1/E4): percorre M0-M8 com ENTRADA REAL (intencoes da Input Map): anda por um
## caminho A* na grade de chao da vila (Ep01V3Nav) ate o alvo que a ajuda mostraria (`main.help_target()`), passa
## antes pelo emblema do heroi em controle, aperta `interact` no ponto de acao e confirma o cartao de troca de heroi.
## Nao altera regras: quem conta o progresso e a Mission. Falha cedo se nao houver caminho, se o heroi ficar preso
## (sem avancar, depois de replanejar) ou se passar do tempo. Ao sair da arvore, solta todas as acoes e devolve
## Engine.time_scale = 1 (mesmo se o teste abortar no meio).

signal finished(success: bool)

const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down", &"interact", &"help", &"run"]
const STUCK_SECONDS := 4.0
const STUCK_MIN_MOVE := 0.4
const DETOUR_SECONDS := 0.8
const WAYPOINT_REACH := 0.6
const PRESS_COOLDOWN := 0.5
## Perto e no mesmo nivel: anda reto (o A* nao precisa).
const DIRECT_RANGE := 1.6
## C2: segura `run` (corre) enquanto o alvo esta a mais que isto; perto, anda para mirar o ponto.
const RUN_DIST := 3.0

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
## Desvio lateral quando um seguidor parado fecha a passagem (o bot empurrava o mesmo seguidor ate desistir).
var _detour_t: float = 0.0
var _detour_dir: Vector3 = Vector3.ZERO
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
		_finish(false, "timeout em %s; %s" % [main.current.id if main.current else &"-", diagnose()])
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
	# F2: enquanto a camera mostra o alvo (olhar dirigido, 1,5 s) o bot espera, como quem assiste (nao pula).
	# G9: missao concluida = conversa da ponte; o bot escuta parado (antes saia atras de emblemas da missao velha).
	if main.blocked() or main.current == null or main.guide.looking or not main.current.is_active():
		_walk(Vector3.ZERO)
		_stuck_t = 0.0
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
		_detour_t = 0.0
	if main.controlled_node is BoatActor:
		_drive(goal.global_position, (goal as Ep01Interactable).radius if goal is Ep01Interactable else 2.0)
		return
	var here := main.controlled_node.global_position
	if _detour_t > 0.0:
		_detour_t -= delta
		_walk(_detour_dir)
		return
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
	_walk(d.normalized() if d.length() > 0.05 else Vector3.ZERO, flat.length() > RUN_DIST)
	_stuck_t += delta
	if _stuck_t >= STUCK_SECONDS:
		if here.distance_to(_stuck_from) < STUCK_MIN_MOVE:
			if _replans >= 4:
				for m: StringName in main.actors:
					print("[RB] v3 bot ator %s em %s" % [m, (main.actors[m] as Node3D).global_position])
				_finish(false, "preso em %s perto de %s indo a %s (%s; rota %s wp %d)" % [main.current.id, here, goal.name, diagnose(), _route, _wp])
				return
			_replans += 1
			var ahead := (_route[_wp] if _wp < _route.size() else target) - here
			var spot := here + ahead.normalized() * 0.6 if ahead.length() > 0.05 else here
			# Seguidor no caminho e obstaculo movel: nao vira parede permanente na grade (antes fechava a passagem).
			if nav != null and not _follower_near(spot, 1.0):
				nav.block(spot, 0.6)
			elif ahead.length() > 0.05:
				# Seguidor no caminho: contorna de lado (um lado por tentativa), como uma crianca faria.
				var side := Vector3(-ahead.z, 0.0, ahead.x).normalized() * (1.0 if _replans % 2 == 1 else -1.0)
				_detour_dir = (side + ahead.normalized() * 0.3).normalized()
				_detour_t = DETOUR_SECONDS
			_route.clear()
			_force_route = true
		_stuck_t = 0.0
		_stuck_from = here


func _follower_near(p: Vector3, dist: float) -> bool:
	for m: StringName in main.actors:
		var a := main.actors[m] as Node3D
		if a != main.controlled_node and Vector2(a.global_position.x - p.x, a.global_position.z - p.z).length() < dist:
			return true
	return false


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
	# G19: o banco do varal (M2) entra depois da grade: bloqueia as celulas dele uma vez
	for b in get_tree().get_nodes_in_group(&"g19_bench"):
		if not b.get_meta(&"nav_blocked", false) and b is Node3D:
			b.set_meta(&"nav_blocked", true)
			var bx := (b as Node3D).global_transform
			for i in 9:
				nav.block(bx * Vector3(-1.0 + i * 0.25, 0, 0.1), 0.6)
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


## Pilotagem (M6) com as mesmas intencoes do jogador: move_up acelera, move_left/right viram. Menos motor em curva fechada.
## G24c: folga (m) da linha do casco ate o que boia ao desviar (meia boca do casco + margem).
const BOAT_PASS := 1.9


func _drive(target: Vector3, reach: float = 2.0) -> void:
	var boat := main.boat
	# preso encostado (o barco nao da re e o casco para no que boia): gira para o lado que abre folga e replaneja
	_boat_still += get_physics_process_delta_time()
	if boat.global_position.distance_to(_still_pos) > 0.4 or absf(wrapf(boat.heading - _still_h, -PI, PI)) > 0.35:
		_still_pos = boat.global_position
		_still_h = boat.heading
		_boat_still = 0.0
	if _boat_still > 2.0 and _escape <= 0.0:
		_escape = 1.6
		_boat_still = 0.0
		_boat_path.clear()
		var g := func(dh: float) -> float:
			return float(main.land.call(&"boat_gap", boat.global_position, boat.heading + dh))
		_escape_dir = 1.0 if g.call(0.3) >= g.call(-0.3) else -1.0
	if _escape > 0.0:
		_escape -= get_physics_process_delta_time()
		_hold(&"move_up", 0.3)
		_hold(&"move_down", 0.0)
		_hold(&"move_left", maxf(_escape_dir, 0.0))
		_hold(&"move_right", maxf(-_escape_dir, 0.0))
		return
	target = _boat_waypoint(boat.global_position, target, reach)
	var d := target - boat.global_position
	d.y = 0.0
	var err := wrapf(atan2(-d.x, -d.z) - boat.heading, -PI, PI)
	var steer := clampf(err * 2.0, -1.0, 1.0)
	_hold(&"move_left", maxf(steer, 0.0))
	_hold(&"move_right", maxf(-steer, 0.0))
	_hold(&"move_up", clampf(1.0 - absf(err) / 1.6, 0.25, 1.0))
	_hold(&"move_down", 0.0)


## G24c: o bot pilota como gente: nao mira o centro de uma boia (passa ao lado, dentro do raio do ponto) e contorna
## barcos parados, boias e a margem. Rota por grafo de visibilidade: nos ao redor de cada obstaculo (a BOAT_NODE m da
## borda), arestas que passam a BOAT_PASS m de tudo e sem tocar a camada 1 nas duas bordas do casco; Dijkstra. Replaneja
## quando o alvo muda ou a cada BOAT_REPLAN s.
const BOAT_NODE := 2.5
## Distancia da borda da boia em que o barco passa por ela (o ponto da boia tem raio BUOY_RADIUS do centro).
const BOAT_GOAL := 2.1
const BOAT_REPLAN := 1.5
## Folga lateral da linha do barco ate a margem e o cais (meia boca + a distancia em que o barco freia).
const BOAT_SHORE := 1.9
var _boat_path: Array[Vector2] = []
var _boat_goal := Vector2.INF
var _boat_plan_at := -INF
var _slack := 1.0
var _boat_still := 0.0
var _still_pos := Vector3.INF
var _still_h := 0.0
var _escape := 0.0
var _escape_dir := 1.0


func _boat_waypoint(from: Vector3, target: Vector3, reach: float = 2.0) -> Vector3:
	if not main.land.has_method(&"floaters"):
		return target
	var p := Vector2(from.x, from.z)
	var t := Vector2(target.x, target.z)
	if t.distance_to(_boat_goal) > 0.1 or elapsed - _boat_plan_at > BOAT_REPLAN or _boat_path.is_empty():
		_boat_goal = t
		_boat_plan_at = elapsed
		_boat_path = _boat_plan(p, t, from.y, reach, 1.0)
		if _boat_path.is_empty():
			_boat_path = _boat_plan(p, t, from.y, reach, 0.6)   # apertado: folgas menores
		if _boat_path.is_empty():
			_boat_path = [t]
	while _boat_path.size() > 1 and p.distance_to(_boat_path[0]) < 1.6:
		_boat_path.pop_front()
	var w: Vector2 = _boat_path[0] if not _boat_path.is_empty() else t
	return Vector3(w.x, target.y, w.y)


func _boat_plan(p: Vector2, t: Vector2, y: float, reach: float = 2.0, slack: float = 1.0) -> Array[Vector2]:
	_slack = slack
	var all: Array[Dictionary] = main.land.call(&"floaters")
	var box := Rect2(p, Vector2.ZERO).expand(t).grow(10.0)
	var obs: Array[Dictionary] = []
	for f in all:
		if box.has_point(f["a"]) or box.has_point(f["b"]):
			obs.append(f)
	# alvo em cima de um obstaculo (boia do percurso) ou rente a um (emblema): os alvos sao um anel dentro do raio do ponto,
	# longe do que boia; na boia, chega de lado (tangente)
	var goals: Array[Vector2] = []
	var target_ob := -1
	for i in obs.size():
		var c: Vector2 = ((obs[i]["a"] as Vector2) + (obs[i]["b"] as Vector2)) * 0.5
		if c.distance_to(t) < float(obs[i]["r"]) + 0.3:
			target_ob = i
	var ring := minf(reach * 0.85, (float(obs[target_ob]["r"]) + BOAT_GOAL) if target_ob >= 0 else reach * 0.85)
	var cands: Array[Vector2] = []
	if target_ob < 0:
		cands.append(t)
	for k in 12:
		cands.append(t + Vector2.from_angle(TAU * k / 12.0) * ring)
	for g in cands:
		var free := true
		for i in obs.size():
			if i != target_ob and Ep01V3Late._pt_seg(g, obs[i]["a"], obs[i]["b"]) < float(obs[i]["r"]) + BOAT_PASS:
				free = false
		if free:
			goals.append(g)
	if goals.is_empty():
		goals.append(t)
	var nodes: Array[Vector2] = [p]
	nodes.append_array(goals)
	var n_goal := goals.size()
	for i in obs.size():
		if i == target_ob:
			continue
		var f := obs[i]
		var a: Vector2 = f["a"]
		var b: Vector2 = f["b"]
		var c := (a + b) * 0.5
		var R := float(f["r"]) + BOAT_NODE + a.distance_to(b) * 0.5
		for k in 10:
			nodes.append(c + Vector2.from_angle(TAU * k / 10.0) * R)
	var n := nodes.size()
	var dist: Array[float] = []
	var prev: Array[int] = []
	var done: Array[bool] = []
	for i in n:
		dist.append(INF)
		prev.append(-1)
		done.append(false)
	dist[0] = 0.0
	var space := main.world.get_world_3d().direct_space_state
	while true:
		var u := -1
		for i in n:
			if not done[i] and dist[i] < INF and (u < 0 or dist[i] < dist[u]):
				u = i
		if u < 0:
			break
		done[u] = true
		if u >= 1 and u <= n_goal:
			var path: Array[Vector2] = []
			var k := u
			while k > 0:
				path.push_front(nodes[k])
				k = prev[k]
			return path
		for v in range(1, n):
			if done[v]:
				continue
			var nd := dist[u] + nodes[u].distance_to(nodes[v])
			if nd >= dist[v] or not _boat_edge(nodes[u], nodes[v], obs, target_ob, u == 0, space, y):
				continue
			if target_ob >= 0 and v >= 1 and v <= n_goal:
				# chega a boia de lado (tangente): de frente a proa comprida bateria nela antes de entrar no raio
				var tob := obs[target_ob]
				var c: Vector2 = ((tob["a"] as Vector2) + (tob["b"] as Vector2)) * 0.5
				var radial := (nodes[v] - c).normalized()
				var dirv := (nodes[v] - nodes[u]).normalized()
				if absf(dirv.dot(radial)) > 0.45 or Ep01V3Late.seg_seg(nodes[u], nodes[v], tob["a"], tob["b"]) < float(tob["r"]) + 1.5:
					continue
			dist[v] = nd
			prev[v] = u
	var none: Array[Vector2] = []
	return none


func _boat_edge(u: Vector2, v: Vector2, obs: Array[Dictionary], skip: int, from_start: bool,
		space: PhysicsDirectSpaceState3D, y: float) -> bool:
	var dn := (v - u).normalized() if u.distance_to(v) > 0.01 else Vector2.ZERO
	if from_start:
		# saindo do lugar: o casco inteiro (capsula) nas poses ao longo da aresta, com o rumo dela
		var steps := maxi(2, int(u.distance_to(v)))
		for k in steps + 1:
			var q := u.lerp(v, float(k) / steps)
			var h := atan2(-dn.x, -dn.y)
			if float(main.land.call(&"boat_gap", Vector3(q.x, y, q.y), h)) < 0.62:
				return false
	else:
		# a proa passa do no antes de virar: a linha conta um pouco alem das pontas
		var u2 := u - dn * 1.0
		var v2 := v + dn * 1.5
		for i in obs.size():
			if i == skip:
				continue
			if Ep01V3Late.seg_seg(u2, v2, obs[i]["a"], obs[i]["b"]) < float(obs[i]["r"]) + BOAT_PASS * _slack:
				return false
	var d := (v - u)
	if d.length() < 0.01:
		return true
	# margem e cais: as duas bordas do casco com folga (o barco freia e para a 0,6 m da margem)
	var side := d.normalized().orthogonal() * BOAT_SHORE * _slack
	var ext := d.normalized() * 1.0 * _slack
	for o: Vector2 in [Vector2.ZERO, side, -side]:
		var a := Vector3(u.x + o.x - ext.x, y + 0.3, u.y + o.y - ext.y)
		var b := Vector3(v.x + o.x + ext.x, y + 0.3, v.y + o.y + ext.y)
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 1)).is_empty():
			return false
	return true


func _walk(dir_world: Vector3, run: bool = false) -> void:
	_hold(&"run", 1.0 if run and dir_world.length() > 0.01 else 0.0)
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


## Estado no estouro (para achar trava): passo, alvo, heroi, bloqueios.
func diagnose() -> String:
	var step: Variant = main.current.current_step().get("id", &"") if main.current else &"-"
	var g := _pick_goal() if main.current else null
	var hero := main.controlled_node
	var best := main.best_interactable()
	return "passo=%s alvo=%s alvo_pos=%s heroi=%s em %s best=%s blocked=%s busy=%s posing=%s looking=%s handoff=%s speaking=%s cutscene=%s pend=%s" % [
		step, g.name if g else "-", g.global_position if g else Vector3.INF, main.active_member,
		hero.global_position if hero else Vector3.INF, best.name if best else "-",
		main.blocked(), main.land.busy, main.posing, main.guide.looking, main.hud.handoff_open, main.hud.is_speaking(),
		main.cutscene.playing if main.cutscene else false, main._pending_switch]


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
