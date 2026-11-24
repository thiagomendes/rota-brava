extends RefCounted
## Etapa 3 (island_crossing): apoios, queda e recuperacao, linha fixada, corda e chao.

var r


func _start(state: StringName) -> Ep01Main:
	Ep01Main.start_state = state
	var m := (load("res://episodes/ep01/ep01_main.tscn") as PackedScene).instantiate() as Ep01Main
	r.tree.root.add_child(m)
	r.tree.current_scene = m
	await r.frames(3)
	return m


func _stop(m: Ep01Main) -> void:
	m.queue_free()
	await r.frames(2)
	r.tree.current_scene = null
	Ep01Main.start_state = &""


func _hz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func run(runner) -> void:
	r = runner
	var m: Ep01Main = await _start(&"island_crossing")
	var st := m.stages[&"island_crossing"] as IslandStage
	var pico := m.actors[&"climber"] as MemberActor
	var d := m.director
	r.check(st != null, "estagio da ilha carregado (IslandStage)")
	r.check(m.controlled_node == pico and d.active_member == &"climber", "Pico controla em island_crossing")
	r.check((m.actors[&"pilot"] as MemberActor).riding_on == m.boat, "Leme fica no barco")
	r.check((m.actors[&"tracker"] as MemberActor).riding_on == m.boat, "Rastro fica no barco")
	r.check(m.boat.global_position.distance_to(Ep01Layout.ENSEADA_POS) < 0.5, "barco parado na enseada")
	r.check(not st.rope_visible, "a corda ainda nao aparece")

	# Chao: Pico na margem nao cai.
	await r.frames(60)
	r.check(pico.global_position.y >= -0.5 and _hz(pico.global_position, Ep01Layout.LANDING_POS) < 0.5,
		"Pico em LANDING_POS nao cai (60 quadros fisicos)")
	r.check(d.last_safe_foothold == 0 and d.state == &"island_crossing", "nenhum progresso so por ficar parado")

	# Linha sem apoio 3 nao muda o estado.
	var res := st.fix_line()
	r.check(not res["accepted"] and res["reason"] == &"missing_prerequisite", "linha sem apoio 3 e rejeitada")
	r.check(d.state == &"island_crossing" and not d.line_fixed and not st.rope_visible, "estado e corda inalterados")

	# Fora de ordem
	res = st.step_on_foothold(2)
	r.check(not res["accepted"] and res["reason"] == &"out_of_order", "apoio 2 antes do 1 e rejeitado")
	r.check(d.last_safe_foothold == 0, "progresso nao muda com apoio fora de ordem")

	# Queda no inicio -> LANDING_POS
	pico.teleport(Vector3(185.5, 0.0, 1.0))
	res = st.fall_into_water()
	r.check(res["respawn_foothold"] == 0 and d.last_safe_foothold == 0, "queda no inicio nao avanca; respawn 0")
	r.check(_hz(pico.global_position, Ep01Layout.LANDING_POS) < 0.1, "Pico volta a LANDING_POS")

	# Na ordem; queda no apoio 2
	r.check(st.step_on_foothold(1)["accepted"] and d.last_safe_foothold == 1, "apoio 1 aceito")
	r.check(st.step_on_foothold(2)["accepted"] and d.last_safe_foothold == 2, "apoio 2 aceito")
	pico.teleport(Vector3(186.0, -2.0, 1.0))
	res = st.fall_into_water()
	r.check(res["respawn_foothold"] == 2 and d.last_safe_foothold == 2, "queda apos apoio 2 usa respawn_foothold 2 sem avancar")
	r.check(_hz(pico.global_position, Ep01Layout.ROCK_FOOTHOLDS[1]) < 0.1, "Pico volta ao apoio 2")
	# Deteccao por posicao (isca e queda via process_stage)
	st.process_stage(2.0)
	pico.teleport(IslandStage.DECOYS[2])
	st.process_stage(0.1)
	r.check(d.last_safe_foothold == 2 and _hz(pico.global_position, Ep01Layout.ROCK_FOOTHOLDS[1]) < 0.1,
		"pisar na isca devolve ao apoio 2 sem progresso")
	st.process_stage(2.0)
	pico.teleport(Ep01Layout.ROCK_FOOTHOLDS[2])
	st.process_stage(0.1)
	r.check(d.last_safe_foothold == 3, "pisar no apoio 3 por posicao avanca")

	# Fixar
	res = st.fix_line()
	r.check(res["accepted"] and d.state == &"docking" and d.line_fixed, "fixar com 3 apoios leva a docking")
	r.check(d.active_member == &"pilot", "Leme ativa")
	r.check(st.rope_visible, "corda visivel")
	await r.frames(2)
	var ends := st.rope_ends()
	r.check(ends[0].distance_to(Ep01Layout.ANCHOR_A) < 0.3 and ends[1].distance_to(Ep01Layout.ANCHOR_B) < 0.3,
		"extremos da corda perto de ANCHOR_A e ANCHOR_B")
	var sag_mid := st.rope_point(8, 0.7).y
	r.check(sag_mid < Ep01Layout.ANCHOR_A.y - 0.1, "a corda tem curva (meio abaixo das pontas)")
	await r.tree.create_timer(4.5).timeout
	r.check(st.rope_sag() <= 0.11, "depois dos puxoes a corda fica esticada")
	r.check(pico.global_position.distance_to(Ep01Layout.ANCHOR_B) < 4.5, "Pico seguro na ilha perto de ANCHOR_B %s" % pico.global_position)
	var blocks := 0
	for c in st.get_children():
		if c is MeshInstance3D or c is StaticBody3D:
			blocks += 1
			if c.get_meta(Blocks.PROVISIONAL, false) != true:
				r.check(false, "bloco provisorio: " + c.name)
	r.check(blocks > 10, "cenografia criada com blocos provisorios (%d)" % blocks)
	await _stop(m)

	# Recarga em docking: corda visivel por refresh_world
	var m2: Ep01Main = await _start(&"docking")
	var st2 := m2.stages[&"island_crossing"] as IslandStage
	r.check(st2.rope_visible, "iniciar em docking deixa a corda visivel")
	r.check(st2.rope_sag() <= 0.11, "corda esticada apos carga")
	r.check((m2.actors[&"climber"] as MemberActor).global_position.distance_to(Ep01Layout.ANCHOR_B) < 4.5,
		"Pico na ilha apos carga")
	await _stop(m2)

