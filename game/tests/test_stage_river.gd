extends RefCounted
## Etapa 2 (Rio): correnteza por zonas, margem, boia, enseada, folhas e marcacao provisoria.
## Sem fisica de entrada: usa RiverStage.simulate_boat e BoatActor.step (determinista).

var r
var _buoy_events: int = 0
var _cove_events: int = 0


func _make_main() -> Ep01Main:
	Ep01Main.carry_completed = []
	Ep01Main.start_state = &"river_search"
	var main := (load("res://episodes/ep01/ep01_main.tscn") as PackedScene).instantiate() as Ep01Main
	r.tree.root.add_child(main)
	r.tree.current_scene = main
	return main


func _free_main(main: Ep01Main) -> void:
	Ep01Main.start_state = &""
	main.queue_free()
	await r.frames(2)


func _put(main: Ep01Main, pos: Vector3, heading: float) -> void:
	main.boat.place(pos, heading)


func run(runner) -> void:
	r = runner
	var main := _make_main()
	await r.frames(3)
	var stage := main.stages[&"river_search"] as RiverStage
	var boat := main.boat
	var east := -PI / 2.0

	r.check(main.director.state == &"river_search", "inicio direto em river_search")
	r.check(main.current_stage == stage and main.controlled_node == boat, "Leme controla o barco (controlled_node)")
	r.check(stage.controlled_node(&"pilot") == boat, "controlled_node(pilot) devolve o barco")
	r.check(boat.current_func.is_valid() and boat.clearance_func.is_valid(), "correnteza e clearance configuradas")
	var pilot := main.actors[&"pilot"] as MemberActor
	var tracker_a := main.actors[&"tracker"] as MemberActor
	var climber := main.actors[&"climber"] as MemberActor
	r.check(pilot.riding_on == boat and tracker_a.riding_on == boat and climber.riding_on == boat,
		"os tres integrantes embarcam")
	r.check(pilot.ride_offset != tracker_a.ride_offset and tracker_a.ride_offset != climber.ride_offset
		and pilot.ride_offset != climber.ride_offset, "deslocamentos no conves diferentes (sem sobrepor Leme)")

	# --- zonas e distancias (dados puros)
	r.check(RiverZones.zone_at(Vector3(40, 0, 0)) == RiverZones.ZONE_CHANNEL, "centro do rio e canal")
	r.check(RiverZones.zone_at(Vector3(40, 0, 11)) == RiverZones.ZONE_BANK, "perto da margem e zona de margem")
	r.check(RiverZones.zone_at(Ep01Layout.ENSEADA_POS) == RiverZones.ZONE_COVE, "enseada e zona quase parada")
	r.check(RiverZones.zone_current(Vector3(40, 0, 0)).length() > RiverZones.zone_current(Vector3(40, 0, 11)).length()
		and RiverZones.zone_current(Vector3(40, 0, 11)).length() > RiverZones.zone_current(Ep01Layout.ENSEADA_POS).length(),
		"canal forte > margem > enseada")
	r.check(RiverZones.clearance(Vector3(0, 0, 0)) < 0.0 and RiverZones.clearance(Vector3(0, 0, 10)) < 0.0,
		"cais e margem de terra sao obstaculos")
	r.check(RiverZones.clearance(Vector3(-15, 0, -8)) > 4.0 and RiverZones.clearance(Vector3(60, 0, 0)) > 10.0,
		"agua aberta tem folga")
	r.check(RiverZones.clearance(Vector3(40, 0, 13.9)) < 1.0 and RiverZones.clearance(Vector3(40, 0, 15)) < 0.0,
		"margem do rio em |z| = RIVER_Z_HALF")

	# --- correnteza arrasta o barco parado para o oeste; motor sobe
	_put(main, Vector3(60, 0, 5), east)
	var p0 := boat.global_position
	stage.simulate_boat(300, 0.0, 0.0)
	r.check(boat.global_position.x < p0.x - 4.0 and stage.boat_position_changed(p0),
		"barco parado e arrastado para o oeste (x %.1f -> %.1f)" % [p0.x, boat.global_position.x])
	_put(main, Vector3(30, 0, 5), east)
	p0 = boat.global_position
	stage.simulate_boat(300, 1.0, 0.0)
	r.check(boat.global_position.x > p0.x + 10.0, "acelerando para leste ele sobe (x %.1f -> %.1f)" % [p0.x, boat.global_position.x])
	r.check(boat.global_position.x - p0.x < 300.0 / 60.0 * boat.max_speed, "a correnteza reduz o avanco liquido")

	# --- margem: desacelera, nao atravessa, e empurra de volta
	_put(main, Vector3(60, 0, 11), PI)   # proa para o sul (+Z), contra a margem
	var slow_seen := false
	var hits := 0
	var on_hit := func() -> void: hits += 1
	boat.soft_hit.connect(on_hit)
	var max_z := 0.0
	for i in 600:
		stage.simulate_boat(1, 1.0, 0.0)
		max_z = maxf(max_z, absf(boat.global_position.z))
		if boat.last_slow_factor < 1.0:
			slow_seen = true
	boat.soft_hit.disconnect(on_hit)
	r.check(slow_seen, "perto da margem a velocidade maxima cai (last_slow_factor < 1)")
	r.check(max_z < Ep01Layout.RIVER_Z_HALF, "o barco nao atravessa a margem (max |z| = %.2f)" % max_z)
	r.check(boat.last_slow_factor < 0.6, "colado na margem o fator e baixo (%.2f)" % boat.last_slow_factor)
	var guide_pos := Vector3(60, 0, 12.0)
	r.check(RiverZones.guide_push(guide_pos).z < 0.0, "a margem sul empurra suavemente para o norte")

	# --- logica de angulo da boia (isolada)
	var t := RiverBuoyTracker.new(Ep01Layout.BUOY_POS, 9.0)
	var done_count := 0
	for i in 18:
		var a := float(i) * 0.1
		if t.feed(Ep01Layout.BUOY_POS + Vector3(cos(a), 0, sin(a)) * 5.0):
			done_count += 1
	r.check(not t.done and done_count == 0, "1,7 rad ao redor da boia ainda nao completa")
	for i in 18:
		var a := 1.7 + float(i) * 0.1
		if t.feed(Ep01Layout.BUOY_POS + Vector3(cos(a), 0, sin(a)) * 5.0):
			done_count += 1
	r.check(t.done and done_count == 1 and t.accumulated >= PI, "passar de PI completa uma unica vez")
	var t2 := RiverBuoyTracker.new(Ep01Layout.BUOY_POS, 9.0)
	for i in 40:
		var a := 0.0 if i % 2 == 0 else 2.5
		t2.feed(Ep01Layout.BUOY_POS + Vector3(cos(a), 0, sin(a)) * 5.0)
	r.check(not t2.done, "ir e voltar nao acumula")
	var t3 := RiverBuoyTracker.new(Ep01Layout.BUOY_POS, 9.0)
	for i in 70:
		var a := float(i) * 0.1
		t3.feed(Ep01Layout.BUOY_POS + Vector3(cos(a), 0, sin(a)) * 20.0)
	r.check(not t3.done, "voltas fora do raio nao contam")

	# --- enseada SEM boia: rejeitada, estado continua, nao trava
	main.director.event_accepted.connect(func(e: StringName, _p: Dictionary) -> void:
		if e == &"buoy_rounded":
			_buoy_events += 1
		if e == &"cove_reached":
			_cove_events += 1)
	_put(main, Ep01Layout.ENSEADA_POS + Vector3(-3, 0, 0), 0.0)
	r.check(stage.at_cove(boat.global_position), "barco dentro do raio da enseada")
	var res := stage.try_cove()
	r.check(not bool(res["accepted"]) and res["reason"] == &"missing_prerequisite",
		"enseada sem boia: rejeitada (missing_prerequisite)")
	r.check(main.director.state == &"river_search" and _cove_events == 0, "estado continua river_search")
	r.check(main.hud.is_speaking(), "rejeicao mostra a dica curta (hint_gesture_buoy)")
	stage.simulate_boat(60, 1.0, 0.0)
	r.check(main.director.state == &"river_search", "o jogo nao trava depois da rejeicao")

	# --- contornar a boia por posicoes simuladas
	var accepted_at := -1
	for i in 50:
		var a := float(i) * 0.1
		var pos := Ep01Layout.BUOY_POS + Vector3(cos(a), 0, sin(a)) * 5.0
		boat.global_position = pos
		if stage.feed_buoy(pos) and accepted_at < 0:
			accepted_at = i
	r.check(accepted_at > 0 and _buoy_events == 1 and main.director.buoy_rounded,
		"contornar a boia emite buoy_rounded uma vez (%d evento, amostra %d)" % [_buoy_events, accepted_at])
	r.check(accepted_at >= int(PI / 0.1) - 1, "so completa apos ~PI rad")

	# --- chegar a enseada COM boia
	_put(main, Ep01Layout.ENSEADA_POS + Vector3(-3, 0, 0), 0.0)
	res = stage.try_cove()
	r.check(bool(res["accepted"]) and main.director.state == &"island_crossing" and _cove_events == 1,
		"com boia, cove_reached leva a island_crossing")
	r.check(main.director.active_member == &"climber", "Pico fica ativo")
	r.check(stage.captain_figure.visible and stage.pup_figure.visible, "sinalizacao do piloto e do filhote visivel")
	await r.frames(2)
	r.check(boat.global_position.distance_to(Ep01Layout.ENSEADA_POS) < 8.0, "o barco fica na enseada")
	await _free_main(main)

	# --- folhas, marcacao provisoria e sinalizacao
	main = _make_main()
	await r.frames(3)
	stage = main.stages[&"river_search"] as RiverStage
	r.check(stage.leaves.size() >= 15 and stage.leaves.size() <= 25, "existem de 15 a 25 folhas (%d)" % stage.leaves.size())
	var before := stage.leaf_positions()
	stage.step_leaves(1.0)
	var after := stage.leaf_positions()
	var moved_west := 0
	var in_channel := 0
	for i in before.size():
		if before[i].x > 20.0:   # nao reapareceu
			if after[i].x < before[i].x:
				moved_west += 1
			if RiverZones.zone_at(before[i]) == RiverZones.ZONE_CHANNEL:
				in_channel += 1
				var d := after[i] - before[i]
				if absf(d.x - Ep01Layout.RIVER_CURRENT.x * RiverStage.LEAF_GAIN) > 0.01 or absf(d.z) > 0.001:
					moved_west -= 100
	r.check(moved_west > 10 and in_channel > 0, "folhas derivam na direcao e na velocidade da correnteza (%d)" % moved_west)
	for i in 400:
		stage.step_leaves(0.5)
	var inside := true
	for p in stage.leaf_positions():
		inside = inside and p.x >= Ep01Layout.RIVER_X_MIN - 2.5 and p.x <= Ep01Layout.RIVER_X_MAX + 1.5
	r.check(inside, "folhas reaparecem ao sair da area")
	var unmarked := 0
	var meshes := 0
	for n in stage.find_children("*", "MeshInstance3D", true, false):
		meshes += 1
		if (n as Node).get_meta(Blocks.PROVISIONAL, false) != true:
			unmarked += 1
	r.check(meshes > 50 and unmarked == 0, "todos os %d blocos do rio sao provisorios (%d sem marca)" % [meshes, unmarked])
	r.check(stage.buoy_node != null and stage.buoy_node.global_position.distance_to(Ep01Layout.BUOY_POS + Vector3(0, Ep01Layout.WATER_Y, 0)) < 0.01,
		"a boia esta em BUOY_POS")
	var named := {"Captain": false, "Pup": false}
	for n in stage.find_children("Captain*", "Node3D", true, false):
		named["Captain"] = true
	for n in stage.find_children("Pup*", "Node3D", true, false):
		named["Pup"] = true
	r.check(named["Captain"] and named["Pup"], "nos Captain* e Pup* existem")
	stage.gesture_hint("ep01.river.pilot.hint_gesture_buoy")
	stage.process_stage(0.1)
	r.check(stage.buoy_node.scale.x > 1.0 or stage.buoy_node.scale.x == 1.0 and stage._halo.visible,
		"gesture_hint pulsa a boia")
	r.check(stage.camera_view()["offset"].y > main.stages[&"dock_investigation"].camera_view()["offset"].y,
		"camera mais alta que a do cais")
	await _free_main(main)
