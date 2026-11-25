extends RefCounted
## Ep01 v3 E5 (RB-R1): M5-M8 (gaivota, barco na baia, farol, festa), camera que desvia de obstaculos, recuperacao da cadeia
## de saltos do Pico, carrinho religado ao fim real do M4 e salvo de outra versao. Estado e recuperacao, sem render.
## O percurso completo M0->M8 do bot fica em test_ep01_v3.gd. Nao comprova render, som, UX nem desempenho.

var r


func run(runner) -> void:
	r = runner
	Ep01V3Main.save_path = ""
	_pieces()
	await _m5_gull()
	await _m6_boat()
	await _m7_lighthouse()
	await _m8_festival()
	await _camera_shed_top()
	await _orbit()
	await _hop_interrupted()
	await _cart_after_real_m4()
	await _save_other_version()
	Ep01V3Main.start_mission = &""


func _new_main(mission: StringName) -> Ep01V3Main:
	Ep01V3Main.start_mission = mission
	var main := (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	r.tree.root.add_child(main)
	r.tree.current_scene = main
	await r.frames(4)
	return main


func _free(main: Ep01V3Main) -> void:
	main.queue_free()
	await r.frames(2)
	r.tree.current_scene = null
	r.tree.paused = false
	Ep01V3Main.start_mission = &""


## Confirma o cartao de troca de heroi (se aberto) e espera a pose de equipe.
func _confirm(main: Ep01V3Main) -> void:
	await r.frames(2)
	if main.hud.handoff_open:
		# O cartao ignora confirmacao antes de HANDOFF_MIN_SECONDS (aperto acidental).
		await r.tree.create_timer(Hud.HANDOFF_MIN_SECONDS + 0.1).timeout
		main.hud._confirm_handoff()
		await r.tree.create_timer(Ep01V3Main.TEAM_POSE_SECONDS + 0.2).timeout


func _wait_free(main: Ep01V3Main, limit: float = 8.0) -> void:
	var t := 0.0
	while (main.land.busy or main.hud.handoff_open) and t < limit:
		if main.hud.handoff_open:
			main.hud._confirm_handoff()
		await r.tree.process_frame
		t += r.tree.root.get_process_delta_time()
	await r.tree.create_timer(Ep01V3Main.TEAM_POSE_SECONDS + 0.1).timeout


func _step(main: Ep01V3Main) -> StringName:
	return main.current.current_step().get("id", &"") if main.current != null else &""


func _pieces() -> void:
	var holder := Node3D.new()
	var all: Array[Node3D] = [Ep01V3Pieces.cloth(holder, "c", Color.RED), Ep01V3Pieces.leaves(holder), Ep01V3Pieces.ball(holder),
		Ep01V3Pieces.crate(holder, "k", Color.BLUE), Ep01V3Pieces.stall_sign(holder, "s", Color.GREEN), Ep01V3Pieces.emblem(holder),
		Ep01V3Pieces.help_arrow(holder), Ep01V3Pieces.gull_with_fish(holder), Ep01V3Pieces.fish(holder), Ep01V3Pieces.rope(holder),
		Ep01V3Pieces.boat_icon(holder, "i", &"star"), Ep01V3Pieces.compass(holder)]
	# Com props_v3 na base, folhas, bola, emblema, seta, gaivota, peixe e corda
	# saem do modelo final (meta piece_id, sem `provisional`); placa, icone do barquinho e bussola
	# continuam blocos marcados provisorios (roupa sem indice e caixote sem barraca tambem).
	var ok := true
	var finals := 0
	for n in all:
		if n == null:
			ok = false
			continue
		var is_final := n.has_meta(&"piece_id")
		if is_final:
			finals += 1
		ok = ok and (is_final != bool(n.get_meta(Ep01V3Pieces.PROVISIONAL, false)))
	r.check(ok, "v3 E5: %d pecas saem do ponto unico de troca (Ep01V3Pieces); final xor provisoria" % all.size())
	r.check(finals == 7, "v3 E5: 7 pecas usam o modelo final do props_v3 (achou %d)" % finals)
	r.check(all[7].get_node_or_null("Fish") != null, "v3 E5: gaivota traz o peixe como filho (soltar = reparent)")
	holder.free()


func _m5_gull() -> void:
	var main := await _new_main(&"M5")
	await _confirm(main)
	var land := main.land
	r.check(main.current.id == &"M5" and _step(main) == &"feathers" and main.active_member == &"tracker",
		"v3 M5: comeca seguindo penas com o Rastro")
	r.check(land.help_target() == land.spots[&"feather_1"] and (land.spots[&"feather_1"] as Ep01Interactable).global_position
		.distance_to(main.world.marker(&"M5_FeatherTrail_4").global_position) < 0.01, "v3 M5: penas da rua do mercado para o cata-vento")
	for i in 4:
		land._on_spot(StringName("feather_%d" % (i + 1)), main.actors[&"tracker"])
	await _confirm(main)
	r.check(_step(main) == &"compass" and main.active_member == &"pilot", "v3 M5: depois das penas a Leme le a bussola")
	land._on_spot(&"vane", main.actors[&"pilot"])
	await _confirm(main)
	r.check(_step(main) == &"fish" and main.active_member == &"climber", "v3 M5: o Pico vai ao telhado")
	var pico := main.actors[&"climber"] as MemberActor
	pico.teleport(land.points[&"CratesBase"] + Vector3(0, 0.05, 0))
	await r.frames(2)
	r.check((land.spots[&"crates_climb"] as Ep01Interactable).enabled and not (land.spots[&"fish"] as Ep01Interactable).enabled,
		"v3 M5: no chao so a subida aparece")
	land._on_spot(&"crates_climb", pico)
	await _wait_free(main)
	var roof := main.world.marker(&"M5_ShedRoof").global_position
	r.check(pico.global_position.distance_to(roof) < 0.2 and not land.busy, "v3 M5: subida caixote->toldo->telhado (%.2f m do telhado)" % pico.global_position.distance_to(roof))
	r.check((land.spots[&"fish"] as Ep01Interactable).enabled, "v3 M5: no telhado o peixe fica ao alcance")
	var gull := land._gull
	land._on_spot(&"fish", pico)
	await r.frames(2)
	await _wait_free(main)
	r.check(main.missions[5].is_completed(), "v3 M5: pegar o peixe (e descer) conclui a missao")
	r.check(pico.global_position.y < 0.3 and not pico.airborne, "v3 M5: Pico desce sozinho do telhado (y %.2f)" % pico.global_position.y)
	r.check(gull == null or not is_instance_valid(gull) or gull.global_position.y > roof.y + 3.0 or not gull.visible,
		"v3 M5: a gaivota fugiu")
	await _free(main)


func _m6_boat() -> void:
	var main := await _new_main(&"M6")
	await _confirm(main)
	var land := main.land
	var boat := main.boat
	var leme := main.actors[&"pilot"] as MemberActor
	r.check(main.active_member == &"pilot" and _step(main) == &"board", "v3 M6: Leme comeca no cais para embarcar")
	r.check(not leme.model.has_accessory(&"Acc_LifeVest") or leme.model.accessory_visible(&"Acc_LifeVest"),
		"v3 M6: colete da Leme ligado na missao do barco")
	# Folga do casco na rota (o barco NAO e barrado onde deve passar): cais -> boia A -> boia B -> aproximacao.
	var route: Array[Vector3] = [main.world.marker(&"M6_BoatStart").global_position, main.world.marker(&"M6_BuoyA").global_position,
		main.world.marker(&"M6_BuoyB").global_position, main.world.marker(&"M6_DinghyApproach").global_position]
	var worst := 1000.0
	var worst_at := Vector3.ZERO
	for i in route.size() - 1:
		for k in 11:
			var p := route[i].lerp(route[i + 1], k / 10.0)
			var d := route[i + 1] - route[i]
			boat.heading = atan2(-d.x, -d.z)
			var c := land.boat_clearance(p)
			if c < worst:
				worst = c
				worst_at = p
	r.check(worst > 0.6, "v3 M6: rota da baia livre das paredes WaterLimits (folga minima %.2f m em %s)" % [worst, worst_at])
	land._on_spot(&"board", leme)
	await r.frames(2)
	r.check(main.controlled_node == boat and leme.riding_on == boat and (main.actors[&"climber"] as MemberActor).riding_on == boat,
		"v3 M6: Leme pilota e o Pico vai junto")
	# Contencao: motor cheio para o norte (margem z -13) e para o cais (z -3): o barco para antes das paredes.
	boat.set_physics_process(false)
	for case: Array in [[Vector3(5, -0.4, -8.0), 0.0, "norte"], [Vector3(-4, -0.4, -6.5), PI, "cais"], [Vector3(-9, -0.4, -8.0), PI / 2.0, "oeste"]]:
		boat.place(case[0], case[1])
		boat.throttle = 1.0
		boat.steer = 0.0
		var min_c := 1000.0
		for f in 600:
			boat.step(1.0 / 60.0)
			min_c = minf(min_c, land.boat_clearance(boat.global_position))
		var p := boat.global_position
		var inside := p.z > -12.9 and p.z < -3.1 and p.x > -13.9
		r.check(inside and min_c > 0.0, "v3 M6: barco contido ao acelerar para o %s (parou em %s, folga min %.2f)" % [case[2], p, min_c])
	boat.throttle = 0.0
	boat.set_physics_process(true)
	var berth := main.world.marker(&"M6_BoatStart")
	boat.place(berth.global_position, berth.global_rotation.y)
	# Boias e aproximacao pelos pontos automaticos (o caminho real do barco e do bot).
	land._on_spot(&"buoy_a", boat)
	r.check(land.help_target() == land.spots[&"buoy_b"], "v3 M6: depois da boia A a ajuda aponta a boia B")
	land._on_spot(&"buoy_b", boat)
	r.check(_step(main) == &"approach", "v3 M6: 2 boias passadas")
	boat.place(main.world.marker(&"M6_DinghyApproach").global_position + Vector3(-3.0, 0, 0.5), -PI / 2.0)
	land._on_spot(&"approach", boat)
	r.check(land.busy and boat.input_locked, "v3 M6: atracacao assistida trava o leme nos metros finais")
	await _wait_free(main, 4.0)
	var to := main.world.marker(&"M6_DinghyApproach").global_position
	r.check(Vector2(boat.global_position.x - to.x, boat.global_position.z - to.z).length() < 0.1, "v3 M6: barco encostou no bote")
	r.check(_step(main) == &"rope" and main.active_member == &"climber", "v3 M6: o Pico joga a corda (troca no barco)")
	r.check(main.best_interactable() == land.spots[&"rope"], "v3 M6: corda ao alcance do Pico embarcado")
	land._on_spot(&"rope", main.actors[&"climber"])
	await _wait_free(main, 10.0)
	r.check(main.missions[6].is_completed() and main.current.id == &"M7", "v3 M6: reboque e corte concluem o resgate")
	r.check(boat.global_position.distance_to(berth.global_position) < 0.05 and leme.riding_on == null and not land.sailing,
		"v3 M6: barco de volta ao cais e trio desembarcado")
	r.check(main.controlled_node is MemberActor and (main.controlled_node as MemberActor).is_inside_tree()
		and main.controlled_node.global_position.y > -0.2, "v3 M6: heroi em controle a pe no cais")
	r.check(not leme.model.has_accessory(&"Acc_LifeVest") or not leme.model.accessory_visible(&"Acc_LifeVest"),
		"v3 M6: colete desligado fora do barco")
	await _free(main)


func _m7_lighthouse() -> void:
	var main := await _new_main(&"M7")
	await _confirm(main)
	await r.frames(3)
	var land := main.land
	r.check(not main.world.access_ramps_enabled(), "v3 M7: subida do farol por saltos (rampas AccessRamps desligadas)")
	land._on_spot(&"lens", main.actors[&"tracker"])
	await _confirm(main)
	r.check(_step(main) == &"climb" and main.active_member == &"climber", "v3 M7: lente achada; Pico sobe")
	var pico := main.actors[&"climber"] as MemberActor
	pico.teleport(land.points[&"StairFoot"] + Vector3(0, 0.05, 0))
	await r.frames(2)
	land._on_spot(&"stair_climb", pico)
	await _wait_free(main)
	var g := main.world.marker(&"M7_Gallery").global_position
	r.check(pico.global_position.distance_to(g) < 0.2, "v3 M7: escada, 3 patamares e galeria pelos marcadores (%.2f m)" % pico.global_position.distance_to(g))
	r.check((land.spots[&"pup"] as Ep01Interactable).enabled, "v3 M7: filhote ao alcance na galeria")
	land._on_spot(&"pup", pico)
	await _confirm(main)
	await _wait_free(main)
	r.check(main.world.lantern_beam != null and main.world.lantern_beam.visible, "v3 M7: lente de volta acende o feixe")
	r.check(pico.global_position.y < g.y - 4.0, "v3 M7: Pico desceu (y %.2f)" % pico.global_position.y)
	r.check(_step(main) == &"aim" and main.active_member == &"pilot", "v3 M7: Leme gira a lanterna")
	for i in 4:
		land._on_spot(&"aim", main.actors[&"pilot"])
		if i < 3:
			await r.tree.create_timer(0.7).timeout
			r.check(absf(wrapf(main.world.lantern.rotation.y - land.lantern_yaw_to(i), -PI, PI)) < 0.05,
				"v3 M7: feixe virado para o barquinho %d" % (i + 1))
	r.check(main.missions[7].is_completed(), "v3 M7: 4 barquinhos acesos concluem o farol")
	await _free(main)


func _m8_festival() -> void:
	var main := await _new_main(&"M8")
	await r.frames(3)
	r.check(main.world.night and main.world.festival, "v3 M8: noite de festa (set_night + set_festival)")
	var lit := 0
	for s in main.land._icons:
		lit += 1 if s.get_meta(&"lit", false) else 0
	r.check(lit == 4, "v3 M8: 4 barquinhos com lanterna e icone acesos")
	main.missions[1].found_emblems.append(&"emb_m1_mooring")
	main.land._on_spot(&"captain", main.actors[main.active_member])
	await r.frames(4)
	r.check(main.complete and main.hud.complete_open, "v3 M8: capitao agradece e a tela de conclusao abre")
	r.check(main.hud.complete_emblems_text(&"tracker") == "1/3" and main.hud.complete_emblems_text(&"climber") == "0/4"
		and main.hud.complete_emblems_text(&"pilot") == "0/3", "v3 M8: emblemas por heroi na conclusao (%s, %s, %s)" % [
		main.hud.complete_emblems_text(&"tracker"), main.hud.complete_emblems_text(&"climber"), main.hud.complete_emblems_text(&"pilot")])
	var by := main.land.emblems_by_hero(main.missions)
	var total := 0
	for m: StringName in by:
		total += int((by[m] as Array)[1])
	r.check(total == main.emblems_total, "v3 M8: todo emblema tem heroi (%d de %d)" % [total, main.emblems_total])
	await _free(main)


## Defeito da E4: com o Pico no topo do galpao a camera entrava no telhado. Em 8 giros, nada entre a mira e a camera.
func _camera_shed_top() -> void:
	var main := await _new_main(&"M2")
	await _confirm(main)
	var pico := main.actors[&"climber"] as MemberActor
	var top := main.world.marker(&"M2_ShedTop").global_position
	pico.teleport(top + Vector3(0, 0.05, 0))
	main.set_controlled(pico)
	var space := main.world.get_world_3d().direct_space_state
	var bad: Array[int] = []
	var pulled := 0
	for k in 8:
		main.camera_rig.set_low_view(k * TAU / 8.0)
		main.camera_rig.follow(pico, true)
		await r.frames(2)
		var cam := main.camera_rig.camera.global_position
		var look := pico.global_position + main.camera_rig.look_offset
		var q := PhysicsRayQueryParameters3D.create(look, cam, 1, main.camera_rig.exclude)
		if not space.intersect_ray(q).is_empty():
			bad.append(k * 45)
		if main.camera_rig.last_pull > 0.05:
			pulled += 1
	r.check(bad.is_empty(), "v3 camera: Pico no topo do galpao sem parede/telhado entre mira e camera (giros ruins: %s)" % str(bad))
	r.check(pulled >= 1, "v3 camera: a camera encurtou em %d de 8 giros (havia obstaculo)" % pulled)
	# Campo aberto (cais): enquadramento baixo aprovado sem encurtar.
	var t := main.actors[&"tracker"] as MemberActor
	t.teleport(main.world.marker(&"M0_RastroStart").global_position + Vector3(0, 0.05, 0))
	main.active_member = &"tracker"
	main.set_controlled(t)
	main.camera_rig.set_low_view(0.0)
	main.camera_rig.follow(t, true)
	await r.frames(3)
	var h := main.camera_rig.camera.global_position.y - t.global_position.y
	r.check(main.camera_rig.last_pull < 0.01 and absf(h - CameraRig.LOW_OFFSET.y) < 0.1, "v3 camera: no cais fica a camera baixa (%.2f m, sem encurtar)" % h)
	r.check(main.camera_rig.occluders.size() > 100, "v3 camera: %d copas de arvore como obstaculo" % main.camera_rig.occluders.size())
	await _free(main)


## Ressalva da E4: um salto interrompido (teleporte no meio) nao deixa `busy` preso.
func _hop_interrupted() -> void:
	var main := await _new_main(&"M2")
	await _confirm(main)
	var pico := main.actors[&"climber"] as MemberActor
	var aborted := [false]
	main.land.hop_aborted.connect(func() -> void: aborted[0] = true)
	var base: Vector3 = main.land.points[&"ShedBase"]
	pico.teleport(base + Vector3(0, 0.05, 0))
	main.land._hop_chain(pico, [main.world.marker(&"M2_ShedStep_1").global_position, main.world.marker(&"M2_ShedStep_2").global_position])
	await r.frames(3)
	r.check(main.land.busy, "v3 salto: cadeia em curso deixa o episodio ocupado")
	pico.teleport(base + Vector3(0, 0.05, 0))
	await r.tree.create_timer(Ep01V3Land.HOP_TIME + Ep01V3Land.HOP_GRACE + 0.3).timeout
	r.check(not main.land.busy and aborted[0], "v3 salto: interrompido, a cadeia para e solta o controle")
	await _free(main)


## Ressalva da E4: ao CONCLUIR o M4 (fluxo real), a caixa do carrinho do mundo volta a colidir no M5.
func _cart_after_real_m4() -> void:
	var main := await _new_main(&"M4")
	var shape := main.world.get_node_or_null(Ep01V3Land.CART_STATIC_SHAPE) as CollisionShape3D
	r.check(shape != null and shape.disabled, "v3 M4: caixa do carrinho desligada no M4")
	main.current.notify(&"icons_read", &"tracker")
	for i in 3:
		main.current.notify(&"cargo_delivered", &"pilot")
	await r.frames(4)
	r.check(main.current.id == &"M5" and shape != null and not shape.disabled, "v3 M4: concluido o M4, a caixa do carrinho volta no M5")
	await _free(main)


## Ressalva da E4: salvo de outra versao nao e aplicado (comeca do M0, sem travar).
func _save_other_version() -> void:
	var path := "user://test_ep01_v3_version.save.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": MissionSave.VERSION + 1, "episode": "ep01", "current": "M5",
		"missions": [{"id": "M0", "state": 2, "emblems": []}, {"id": "M1", "state": 2, "emblems": ["emb_m1_mooring"]}]}))
	f.close()
	Ep01V3Main.save_path = path
	var main := await _new_main(&"")
	r.check(main.current != null and main.current.id == &"M0" and not main.missions[1].is_completed() and main.emblems_found == 0,
		"v3 salvo: versao diferente e ignorada (comeca no M0)")
	await _free(main)
	Ep01V3Main.save_path = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## C1: orbita pela Input Map (deterministica: passo fixo), inclinacao limitada, heroi anda relativo a camera.
func _orbit() -> void:
	var main := await _new_main(&"M1")
	var rig := main.camera_rig
	r.check(rig.orbit_enabled and rig.pitch == 0.0, "v3 C1: orbita ligada, comeca no enquadramento baixo aprovado")
	var y0 := rig.yaw
	Input.action_press(&"cam_right")
	for i in 30:
		rig.orbit_step(1.0 / 60.0)
	Input.action_release(&"cam_right")
	var dy := wrapf(rig.yaw - y0, -PI, PI)
	r.check(absf(dy + CameraRig.ORBIT_SPEED * 0.5) < 0.001, "v3 C1: cam_right gira %.3f rad em 0,5 s (esperado %.3f)" % [dy, -CameraRig.ORBIT_SPEED * 0.5])
	rig.orbit_step(0.5)
	r.check(absf(wrapf(rig.yaw - y0, -PI, PI) - dy) < 0.0001, "v3 C1: sem acao a camera nao gira (bot deterministico)")
	Input.action_press(&"cam_down")
	for i in 600:
		rig.orbit_step(1.0 / 60.0)
	Input.action_release(&"cam_down")
	r.check(is_equal_approx(rig.pitch, CameraRig.PITCH_MAX), "v3 C1: inclinacao limitada em cima (%.2f)" % rig.pitch)
	Input.action_press(&"cam_up")
	for i in 600:
		rig.orbit_step(1.0 / 60.0)
	Input.action_release(&"cam_up")
	r.check(is_equal_approx(rig.pitch, CameraRig.PITCH_MIN), "v3 C1: inclinacao limitada embaixo (%.2f)" % rig.pitch)
	rig.pitch = 0.0
	# Movimento relativo a camera: "para cima" anda para onde a camera olha.
	var t := main.controlled_node as MemberActor
	await r.frames(2)
	var p0 := t.global_position
	Input.action_press(&"move_up")
	await r.tree.create_timer(0.5).timeout
	Input.action_release(&"move_up")
	var mv := t.global_position - p0
	mv.y = 0.0
	var fwd := Basis(Vector3.UP, rig.yaw) * Vector3(0, 0, -1)
	r.check(mv.length() > 0.3 and mv.normalized().dot(fwd) > 0.95, "v3 C1: heroi anda para a frente da camera girada (dot %.2f)" % (mv.normalized().dot(fwd) if mv.length() > 0 else 0.0))
	await r.frames(2)
	var cam := rig.camera.global_position
	var focus := t.global_position + rig.look_offset
	r.check(rig.camera.global_position.distance_to(focus) <= (CameraRig.LOW_OFFSET.length() + CameraRig.LEAD_MAX + 0.6), "v3 C1: orbita mantem a distancia do enquadramento (%.2f m)" % cam.distance_to(focus))
	await _free(main)
