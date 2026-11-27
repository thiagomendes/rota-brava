extends RefCounted
## RB-R1 G24c (revisao): o barco encostado de frente ou de quina numa boia, num barco parado ou no cais sempre se solta
## so com o leme (gira para os dois lados) em ate UNSTICK_S, sem nenhum quadro de interpenetracao (casco x o que boia
## abaixo de -5 cm; casco x camada 1 pela caixa de colisao em mais de 2 quadros) e sem a correcao saltar mais que
## JUMP_MAX num quadro. Passo do barco + resolucao de contato da Late a 60 Hz,
## como no jogo. Geometrico: nao comprova render.

const DT := 1.0 / 60.0
const PUSH_S := 3.0
const UNSTICK_S := 3.5
## Solto: a proa virou mais que isto (rad, ~43 graus: ja da para seguir ao longo do obstaculo) ou a folga passou de 0,4 m.
const FREE_TURN := 0.75
## Teto do empurrao de saida num quadro (m).
const JUMP_MAX := 0.055

var r


func run(runner) -> void:
	r = runner
	Ep01V3Main.start_mission = &"M6"
	Ep01V3Main.save_path = ""
	var main := (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	r.tree.root.add_child(main)
	r.tree.current_scene = main
	await r.frames(4)
	var land := main.land
	var boat := main.boat
	land.sailing = true
	boat.input_locked = false
	boat.set_physics_process(false)
	var cases: Array = []
	for id: String in ["wv3_buoy_a", "wv3_buoy_b", "kit:rowboat_b#0"]:
		for f: Dictionary in land.floaters():
			if f["id"] == id:
				var c := ((f["a"] as Vector2) + (f["b"] as Vector2)) * 0.5
				cases.append([id, Vector3(c.x, boat.global_position.y, c.y)])
	# cais: borda sul do cais (z ~ -3,1) a frente de um ponto da baia
	cases.append(["cais", Vector3(4.0, boat.global_position.y, -3.0)])
	for cs: Array in cases:
		for kind: String in ["frente", "quina"]:
			var sides: Array[String] = []
			for s: float in [1.0, -1.0]:
				if _case(land, boat, cs[0], cs[1], kind, s):
					sides.append("esq" if s > 0 else "dir")
			# entre a boia e a margem um dos lados fica bloqueado de verdade (a margem); o outro sempre solta
			r.check(sides.size() == 2 or (sides.size() == 1 and _squeezed),
				"G24c: barco encostado (%s %s) se solta so com o leme: lados que soltam %s%s" % [cs[0], kind, sides,
				" (espremido contra a margem)" if _squeezed else ""])
	Ep01V3Main.start_mission = &""
	main.queue_free()
	await r.frames(2)
	r.tree.current_scene = null


var _squeezed := false


func _case(land: Ep01V3Late, boat: BoatActor, id: String, at: Vector3, kind: String, s: float) -> bool:
	if s > 0.0:
		_squeezed = false
	# boia e barco parado: vem do oeste (agua livre), a 5 m; cais: vem da baia para o norte do cais. Quina: proa
	# desviada 0,5 rad e 0,9 m de lado.
	# direcao de chegada: a primeira (de 16, comecando do oeste) com o casco livre no ponto de partida (a 5-6 m)
	var dist := 6.0 if id == "cais" else 5.0
	var hd := PI if id == "cais" else -PI / 2.0
	var start := Vector3.INF
	for k in 16:
		var h := hd + TAU * k / 16.0 * (1.0 if k % 2 == 0 else -1.0) * 0.5
		var f := Vector3(-sin(h), 0, -cos(h))
		var p := at - f * dist
		if land.boat_gap(p, h) > 0.6 and land._hull_free(p, h) and land.boat_clearance(p) > 0.6:
			hd = h
			start = p
			break
	if start == Vector3.INF:
		r.check(false, "G24c: ha agua livre para chegar em %s" % id)
		return false
	var side := Vector3(cos(hd), 0, -sin(hd))
	if kind == "quina":
		start += side * 0.9 * s
		hd += 0.5 * s
	boat.place(start, hd)
	boat.speed = 0.0
	var worst := 1000.0
	var wall_hit := 0
	_jump = 0.0
	for i in int(PUSH_S / DT):
		_step(land, boat, 1.0, 0.0)
		worst = minf(worst, land.boat_gap(boat.global_position, boat.heading))
		if not land._hull_free(boat.global_position, boat.heading):
			wall_hit += 1
	var p0 := boat.global_position
	var h0 := boat.heading
	var t := 0.0
	var free := false
	while t < UNSTICK_S:
		_step(land, boat, 1.0, s)
		t += DT
		worst = minf(worst, land.boat_gap(boat.global_position, boat.heading))
		if not land._hull_free(boat.global_position, boat.heading):
			wall_hit += 1
		if land.boat_clearance(boat.global_position) < 0.8 and land.boat_gap(boat.global_position, boat.heading) < 0.2:
			_squeezed = true
		# solto: ja nao encosta (folga do que boia > 0,4 m e longe do cais) ou a proa ja virou para longe (> 1 rad)
		var gap := land.boat_gap(boat.global_position, boat.heading)
		if absf(wrapf(boat.heading - h0, -PI, PI)) > FREE_TURN or (id != "cais" and gap > 0.4):
			free = true
			break
	var label := "%s %s leme %s" % [id, kind, "esq" if s > 0 else "dir"]
	print("[RB] G24c %s: solto=%s em %.1f s, girou %.2f rad, andou %.2f m" % [label, free, t,
		absf(wrapf(boat.heading - h0, -PI, PI)), boat.global_position.distance_to(p0)])
	if wall_hit > 0:
		var col := boat.find_child("Collision", true, false) as CollisionShape3D
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = col.shape
		q.collision_mask = 1
		q.transform = col.global_transform
		q.transform.origin.y += 0.25
		for h: Dictionary in boat.get_world_3d().direct_space_state.intersect_shape(q, 4):
			print("[G24U] ", label, " ", (h.collider as Node).get_path(), " em ", boat.global_position)
	r.check(_jump <= JUMP_MAX, "G24c: a correcao do contato nao teleporta (%s): maior salto num quadro %.3f m (teto %.2f)" % [
		label, _jump, JUMP_MAX])
	r.check(worst > -0.05 and wall_hit <= 2, "G24c: sem interpenetracao (%s): folga min %.2f m, %d quadros no cais" % [label,
		worst, wall_hit])
	return free


var _jump := 0.0


func _step(land: Ep01V3Late, boat: BoatActor, throttle: float, steer: float) -> void:
	boat.throttle = throttle
	boat.steer = steer
	boat.step(DT)
	var before := boat.global_position
	land._guard_boat_turn()
	_jump = maxf(_jump, before.distance_to(boat.global_position))
