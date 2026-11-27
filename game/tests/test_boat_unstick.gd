extends RefCounted
## RB-R1 G24c (revisao): o barco encostado de frente ou de quina numa boia, num barco parado ou no cais sempre se solta
## so com o leme (gira para os dois lados) em ate UNSTICK_S, sem nenhum quadro de interpenetracao (casco x o que boia
## abaixo de -3 cm; casco x camada 1 pela caixa de colisao). Passo do barco + resolucao de contato da Late a 60 Hz,
## como no jogo. Geometrico: nao comprova render.

const DT := 1.0 / 60.0
const PUSH_S := 3.0
const UNSTICK_S := 3.5

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
	for id: String in ["wv3_buoy_a", "kit:rowboat_b#0"]:
		for f: Dictionary in land.floaters():
			if f["id"] == id:
				var c := ((f["a"] as Vector2) + (f["b"] as Vector2)) * 0.5
				cases.append([id, Vector3(c.x, boat.global_position.y, c.y)])
	# cais: borda sul do cais (z ~ -3,1) a frente de um ponto da baia
	cases.append(["cais", Vector3(4.0, boat.global_position.y, -3.0)])
	for cs: Array in cases:
		for kind: String in ["frente", "quina"]:
			for s: float in [1.0, -1.0]:
				_case(land, boat, cs[0], cs[1], kind, s)
	Ep01V3Main.start_mission = &""
	main.queue_free()
	await r.frames(2)
	r.tree.current_scene = null


func _case(land: Ep01V3Late, boat: BoatActor, id: String, at: Vector3, kind: String, s: float) -> void:
	# boia e barco parado: vem do oeste (agua livre), a 5 m; cais: vem da baia para o norte do cais. Quina: proa
	# desviada 0,5 rad e 0,9 m de lado.
	var hd := -PI / 2.0
	var dist := 5.0
	if id == "cais":
		hd = PI
		dist = 6.0
	var fwd := Vector3(-sin(hd), 0, -cos(hd))
	var side := Vector3(cos(hd), 0, -sin(hd))
	var start := at - fwd * dist
	if kind == "quina":
		start += side * 0.9 * s
		hd += 0.5 * s
	boat.place(start, hd)
	boat.speed = 0.0
	var worst := 1000.0
	var wall_hit := 0
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
		# solto: ja nao encosta (folga do que boia > 0,4 m e longe do cais) ou a proa ja virou para longe (> 1 rad)
		var gap := land.boat_gap(boat.global_position, boat.heading)
		if absf(wrapf(boat.heading - h0, -PI, PI)) > 1.0 or (id != "cais" and gap > 0.4):
			free = true
			break
	var label := "%s %s leme %s" % [id, kind, "esq" if s > 0 else "dir"]
	r.check(free, "G24c: barco encostado (%s) se solta so com o leme (%.1f s, girou %.2f rad, andou %.2f m)" % [label, t,
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
	r.check(worst > -0.03 and wall_hit == 0, "G24c: sem interpenetracao (%s): folga min %.2f m, %d quadros no cais" % [label,
		worst, wall_hit])


func _step(land: Ep01V3Late, boat: BoatActor, throttle: float, steer: float) -> void:
	boat.throttle = throttle
	boat.steer = steer
	boat.step(DT)
	land._guard_boat_turn()
