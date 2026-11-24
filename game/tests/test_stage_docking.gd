extends RefCounted
## Etapas 4 e 5 (Atracar / Voltar): assistencia, tolerancias, nova aproximacao, conclusao unica.

var r


func _meshes(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_meshes(c, out)


func run(runner) -> void:
	r = runner
	Ep01Main.carry_completed = []
	Ep01Main.start_state = &"docking"
	var main := (load("res://episodes/ep01/ep01_main.tscn") as PackedScene).instantiate() as Ep01Main
	r.tree.root.add_child(main)
	r.tree.current_scene = main
	await r.frames(3)
	Ep01Main.start_state = &""

	var st := main.stages[&"docking"] as DockingStage
	var boat := main.boat
	var target := Ep01Layout.DOCKING_TARGET_POS
	r.check(main.stages[&"return_trip"] == st, "docking e return_trip usam a mesma instancia")
	r.check(main.director.state == &"docking", "inicia em docking")
	r.check(main.controlled_node == boat, "Leme controla o barco em docking")
	r.check(st.controlled_node(&"pilot") == boat, "controlled_node(pilot) e o barco")

	# Assistencia
	st.place_boat_for_test(Ep01Layout.BOAT_ARM_START, 0.0, 0.0)
	st.update_docking()
	r.check(boat.assist == 0.0, "longe do alvo a assistencia e 0")
	st.place_boat_for_test(target + Vector3(0, 0, 4), 0.0, 0.0)
	st.update_docking()
	r.check(boat.assist > 0.3 and boat.assist <= 0.9, "perto do alvo a assistencia e > 0 e <= 0.9")
	r.check(is_equal_approx(boat.assist_heading, Ep01Layout.DOCKING_TARGET_HEADING), "assist_heading aponta ao rumo alvo")

	# Convergencia sem entrada: rumo desalinhado, boat.step com assistencia
	st.place_boat_for_test(target + Vector3(0, 0, 1.0), 0.9, 0.5)
	boat.throttle = 0.0
	boat.steer = 0.0
	for i in 600:
		boat.throttle = 0.0
		boat.steer = 0.0
		st.update_docking()
		boat.step(1.0 / 60.0)
	r.check(absf(wrapf(boat.heading, -PI, PI)) <= Ep01Layout.DOCKING_HEADING_TOLERANCE,
		"com assistencia o rumo converge para dentro da tolerancia sem entrada (heading %.3f)" % boat.heading)
	r.check(st.is_aligned(), "apos convergir o barco esta alinhado")

	# Tolerancias
	st.place_boat_for_test(target, 0.0, 0.0)
	r.check(st.is_aligned(), "alvo, rumo 0, velocidade 0: alinhado")
	st.place_boat_for_test(target + Vector3(3.0, 0, 0), 0.0, 0.0)
	r.check(not st.is_aligned(), "posicao fora da tolerancia: nao alinhado")
	st.place_boat_for_test(target, 0.6, 0.0)
	r.check(not st.is_aligned(), "rumo fora da tolerancia: nao alinhado")
	st.place_boat_for_test(target, 0.0, 2.0)
	r.check(not st.is_aligned(), "velocidade acima da tolerancia: nao alinhado")
	st.place_boat_for_test(target + Vector3(1.0, 0, 0), -0.3, 1.0)
	r.check(st.is_aligned(), "dentro das tres tolerancias: alinhado")

	# Interactable Embarcar
	st.place_boat_for_test(target, 0.0, 0.0)
	st.update_docking()
	var best := main.best_interactable()
	r.check(best != null and best.action_id == &"board", "alinhado: 'Embarcar' disponivel")
	r.check(best != null and best.label_key == "ui.action.board", "Embarcar usa ui.action.board")
	st.place_boat_for_test(target + Vector3(0, 0, 4), 0.0, 0.0)
	st.update_docking()
	r.check(main.best_interactable() == null, "desalinhado: 'Embarcar' indisponivel")
	st.place_boat_for_test(target, 1.2, 0.0)
	st.update_docking()
	r.check(main.best_interactable() == null, "rumo errado: 'Embarcar' indisponivel")

	# boat_docked desalinhado e rejeitado
	st.place_boat_for_test(target + Vector3(0, 0, 5), 0.0, 0.0)
	var res := st.board()
	r.check(not res.get("accepted", true), "boat_docked com aligned=false e rejeitado")
	r.check(main.director.state == &"docking", "apos rejeicao continua em docking")

	# Passar do alvo: nova aproximacao sem mudar a etapa
	st.place_boat_for_test(target + Vector3(0, 0, -8.0), 0.0, 2.0)
	st.update_docking()
	r.check(boat.global_position.distance_to(Ep01Layout.BOAT_ARM_START) < 0.1, "passar do alvo devolve o barco a BOAT_ARM_START")
	r.check(main.director.state == &"docking", "nova aproximacao nao muda o estado")

	# Cenografia provisoria
	var meshes: Array[MeshInstance3D] = []
	_meshes(st.pier, meshes)
	_meshes(st.target_zone, meshes)
	_meshes(st.beacons, meshes)
	_meshes(st.passengers, meshes)
	var all_prov := not meshes.is_empty()
	for m in meshes:
		if m.get_meta(Blocks.PROVISIONAL, false) != true:
			all_prov = false
	r.check(all_prov, "blocos do atracadouro, alvo, balizas e passageiros sao PROVISORIOS (%d)" % meshes.size())
	r.check(st.target_zone.visible and st.beacons.visible, "linha fixada: alvo e balizas visiveis")

	# Atracar alinhado -> return_trip
	res = st.dock_now()
	r.check(res.get("accepted", false), "boat_docked alinhado e aceito")
	r.check(main.director.state == &"return_trip", "atracar leva a return_trip")
	await r.frames(2)
	r.check(boat.global_position.distance_to(target) < 0.1, "em return_trip o barco fica atracado no alvo")
	r.check(st.passengers.get_parent() == boat, "passageiros embarcam no convés")
	st.refresh_world()
	st.refresh_world()
	r.check(boat.global_position.distance_to(target) < 0.1 and st.target_zone.visible, "refresh_world idempotente em return_trip")

	# A troca de integrante (Leme -> Leme) espera confirmacao; confirma-se como o HUD faria.
	await r.tree.create_timer(1.2).timeout
	r.check(main.hud.handoff_open, "a entrada em return_trip abre a confirmacao")
	main.hud.handoff_confirmed.emit()
	await r.tree.create_timer(Ep01Main.TEAM_POSE_SECONDS + 0.2).timeout
	r.check(main.controlled_node == boat, "Leme controla o barco em return_trip")
	r.check(main.hud.is_speaking(), "control_started fala a linha de enter")
	st.update_docking()
	r.check(boat.input_locked, "em return_trip o barco nao anda por entrada")
	r.check(main.best_interactable() != null and main.best_interactable().action_id == &"depart", "'Partir' disponivel junto ao barco")

	# Partir
	var before := main.director.completed_episodes.size()
	res = st.depart_now()
	r.check(res.get("accepted", false) and main.director.state == &"complete", "departure_confirmed leva a complete")
	r.check(main.director.completed_episodes.count(&"ep01") == 1 and before == 0, "ep01 registrado UMA vez")
	var dup := st.depart_now()
	r.check(not dup.get("accepted", true) and main.director.completed_episodes.count(&"ep01") == 1, "partida duplicada nao registra de novo")
	r.check(st.is_departing(), "o barco parte durante as falas finais")
	var z0 := boat.global_position.z
	await r.tree.create_timer(1.5).timeout
	r.check(boat.global_position.z > z0 + 0.5, "o barco sai para o sul")

	r.tree.paused = false
	main.queue_free()
	await r.frames(2)
	r.tree.current_scene = null
