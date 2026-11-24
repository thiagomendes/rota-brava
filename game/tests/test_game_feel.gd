extends RefCounted
## RB-R1 - sensacao de jogo: rampa a pe, corrida, salto do Pico (sem laje), pose de equipe, emblemas, retorno visual,
## camera. Cada verificacao importante tem uma MUTACAO que precisa reprovar e e restaurada em seguida.
## Nao comprova render, som nem como uma crianca sente o jogo.

var r


func _start(state: StringName) -> Ep01Main:
	Ep01Main.start_state = state
	var m := (load("res://episodes/ep01/ep01_main.tscn") as PackedScene).instantiate() as Ep01Main
	r.tree.root.add_child(m)
	r.tree.current_scene = m
	await r.frames(3)
	return m


func _stop(m: Ep01Main) -> void:
	_release()
	m.queue_free()
	await r.frames(2)
	r.tree.current_scene = null
	Ep01Main.start_state = &""


func _physics(n: int) -> void:
	for i in n:
		await r.tree.physics_frame


func _release() -> void:
	for a: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(a)


## Empurra o analogico na direcao do MUNDO `dir` (com o giro da camera), forca `tilt`.
func _push(m: Ep01Main, dir: Vector3, tilt: float = 1.0) -> void:
	_release()
	var local := Basis(Vector3.UP, -m.camera_rig.yaw) * dir.normalized() * tilt
	if local.x > 0.01: Input.action_press(&"move_right", local.x)
	if local.x < -0.01: Input.action_press(&"move_left", -local.x)
	if local.z > 0.01: Input.action_press(&"move_down", local.z)
	if local.z < -0.01: Input.action_press(&"move_up", -local.z)


func _planar(a: MemberActor) -> float:
	return Vector2(a.velocity.x, a.velocity.z).length()


static func _ramp_time(from: float, to_speed: float, want: float) -> float:
	var v := Vector3(from, 0, 0)
	var t := 0.0
	for i in 600:
		if absf(v.x - to_speed) < 0.05:
			return t
		v = MemberActor.step_planar(v, Vector3(want, 0, 0), 1.0 / 240.0)
		t += 1.0 / 240.0
	return INF


func run(runner) -> void:
	r = runner
	await _walk_feel()
	await _jump()
	await _team_pose()
	await _collectibles()
	await _feedback_and_camera()
	await _framing()


# ---------- enquadramento (style bible: heroi com 12 a 18% da altura da tela na exploracao) ----------

## Altura da tela ocupada pelo heroi: projeta o pe e o topo da cabeca (AABB do modelo) com unproject_position.
func _hero_fraction(m: Ep01Main, a: MemberActor) -> float:
	var top := -INF
	var bottom := INF
	for mi in a.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		if not g.is_visible_in_tree() or g.mesh == null:
			continue
		var box := g.global_transform * g.get_aabb()
		top = maxf(top, box.end.y)
		bottom = minf(bottom, box.position.y)
	if top == -INF:
		return 0.0
	var p := a.global_position
	var cam := m.camera_rig.camera
	var head := cam.unproject_position(Vector3(p.x, top, p.z))
	var feet := cam.unproject_position(Vector3(p.x, bottom, p.z))
	return absf(feet.y - head.y) / float(m.get_viewport().get_visible_rect().size.y)


func _occluded(m: Ep01Main, from: Vector3, to: Vector3, exclude: Array[RID]) -> String:
	# Muros invisiveis (sem malha visivel) nao ocluem: sao ignorados; ate 8 tentativas, nunca laco infinito.
	var ex := exclude.duplicate()
	for i in 8:
		var q := PhysicsRayQueryParameters3D.create(from, to, 1, ex)
		var hit := m.get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			return ""
		var col := hit["collider"] as Node
		var seen := false
		for mi in col.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).is_visible_in_tree():
				seen = true
				break
		if seen:
			return String(col.get_path())
		ex.append((col as CollisionObject3D).get_rid())
	return "muitos colisores"


func _framing() -> void:
	# [estado, integrante, alvo da acao do momento]
	var cases := [
		[&"dock_investigation", &"tracker", Ep01Layout.BENCH_INTERACT_POS + Vector3(0, 0.3, 0)],
		[&"dock_investigation", &"tracker", Ep01Layout.BANK_PRINT_POS + Vector3(0, 0.2, 0)],
		# Rio: no inicio a boia esta a 90 m; o alvo do momento e a agua a frente da proa (ler a correnteza).
		[&"river_search", &"pilot", Ep01Layout.BOAT_DOCKED_POS + Vector3(5.0, -0.3, 0.0)],
		[&"island_crossing", &"climber", (Ep01Layout.ROCK_FOOTHOLDS[0] as Vector3) + Vector3(0, 0.1, 0)],
		[&"docking", &"pilot", Ep01Layout.DOCKING_TARGET_POS + Vector3(0, 0.4, 0)],
	]
	var sizes := [Vector2i(1280, 720), Vector2i(1600, 720), Vector2i(960, 720)]
	var root_vp: Window = r.tree.root
	var old_size: Vector2i = root_vp.size
	for c: Array in cases:
		var m: Ep01Main = await _start(c[0] as StringName)
		var a := m.actors[c[1] as StringName] as MemberActor
		if c[2] == Ep01Layout.BANK_PRINT_POS + Vector3(0, 0.2, 0):
			a.teleport(Ep01Layout.BANK_PRINT_POS + Vector3(0.8, 0.05, -1.0))
			await _physics(3)
		m.camera_rig.follow(m.camera_rig.target, true)
		await r.frames(2)
		for s: Vector2i in sizes:
			r.tree.root.size = s
			await r.frames(2)
			m.camera_rig.follow(m.camera_rig.target, true)
			var f := _hero_fraction(m, a)
			r.check(f >= 0.12 and f <= 0.18, "%s %s em %dx%d: heroi ocupa %.1f%% da altura (12-18%%)" % [c[0], c[1], s.x, s.y, f * 100.0])
		r.tree.root.size = old_size
		await r.frames(1)
		if c[0] == &"river_search":
			c[2] = m.boat.global_position + m.boat.forward() * 6.0
		var cam_pos := m.camera_rig.camera.global_position
		var ex: Array[RID] = [a.get_rid()]
		var o1 := _occluded(m, cam_pos, a.global_position + Vector3(0, 0.7, 0), ex)
		r.check(o1 == "", "%s: raio camera->heroi livre %s" % [c[0], o1])
		var o2 := _occluded(m, cam_pos, c[2] as Vector3, ex)
		r.check(o2 == "", "%s: raio camera->alvo livre %s" % [c[0], o2])
		var tgt := m.camera_rig.camera.unproject_position(c[2] as Vector3)
		var vr := m.get_viewport().get_visible_rect()
		r.check(vr.has_point(tgt) and not m.camera_rig.camera.is_position_behind(c[2] as Vector3),
			"%s: alvo da acao visivel no quadro (%.0f, %.0f)" % [c[0], tgt.x, tgt.y])
		await _stop(m)
	# MUTACAO: camera antiga do cais (0; 7,5; 9,5) reprova a faixa; restaurada.
	var mm: Ep01Main = await _start(&"dock_investigation")
	mm.camera_rig.set_view(Vector3(0, 7.5, 9.5), 0.0, 1.0)
	mm.camera_rig.follow(mm.camera_rig.target, true)
	var fm := _hero_fraction(mm, mm.actors[&"tracker"] as MemberActor)
	r.check(fm < 0.12, "mutacao (camera antiga) reprova a faixa (%.1f%%)" % (fm * 100.0))
	await _stop(mm)


# ---------- a pe ----------

func _walk_feel() -> void:
	var up := _ramp_time(0.0, MemberActor.SPEED, MemberActor.SPEED)
	var down := _ramp_time(MemberActor.SPEED, 0.0, 0.0)
	r.check(absf(MemberActor.SPEED - 3.2) < 0.01, "velocidade alvo de crianca 3,2 m/s")
	r.check(absf(up - 0.12) <= 0.02, "rampa de partida ~0,12 s ate a velocidade (medido %.3f s)" % up)
	r.check(absf(down - 0.08) <= 0.02, "parada em ~0,08 s (medido %.3f s)" % down)
	r.check(MemberActor.target_speed(0.3) < 1.0 and MemberActor.target_speed(0.3) > 0.3, "analogico pouco inclinado anda devagar (%.2f m/s)" % MemberActor.target_speed(0.3))
	r.check(MemberActor.target_speed(1.0) == MemberActor.SPEED and MemberActor.target_speed(0.05) == 0.0, "inclinacao total corre; zona morta para")

	var m: Ep01Main = await _start(&"dock_investigation")
	var a := m.actors[&"tracker"] as MemberActor
	r.check(m.controlled_node == a, "Rastro controla no cais")
	a.teleport(Vector3(0, 0.05, 8.0))
	await _physics(5)
	_push(m, Vector3.RIGHT)
	var frames := 0
	while _planar(a) < MemberActor.SPEED * 0.95 and frames < 60:
		await r.tree.physics_frame
		frames += 1
	var t_up := float(frames) / float(Engine.physics_ticks_per_second)
	r.check(t_up <= 0.2, "no jogo, chega a 95%% da corrida em %.3f s (<= 0,2 s)" % t_up)
	await _physics(10)
	var anim := a.model.current_animation() if a.model != null else &""
	if a.model != null and a.model.has_animation(&"run"):
		r.check(anim == &"run", "acima de %.1f m/s toca `run` (%s)" % [MemberActor.RUN_THRESHOLD, anim])
	else:
		r.check(anim == &"walk", "modelo sem `run`: acima do limiar usa `walk` (%s)" % anim)
	_release()
	frames = 0
	while _planar(a) > 0.05 and frames < 60:
		await r.tree.physics_frame
		frames += 1
	var t_down := float(frames) / float(Engine.physics_ticks_per_second)
	r.check(t_down <= 0.15, "no jogo, para em %.3f s (<= 0,15 s)" % t_down)
	# Analogico leve: anda devagar, sem `run`.
	_push(m, Vector3.LEFT, 0.62)
	await _physics(30)
	r.check(_planar(a) > 0.3 and _planar(a) < MemberActor.RUN_THRESHOLD, "analogico leve anda devagar (%.2f m/s)" % _planar(a))
	_release()
	await _physics(10)
	# MUTACAO: escala de velocidade baixa -> a medida da rampa reprova; restaurada.
	a.speed_scale = 0.4
	_push(m, Vector3.RIGHT)
	frames = 0
	while _planar(a) < MemberActor.SPEED * 0.95 and frames < 30:
		await r.tree.physics_frame
		frames += 1
	r.check(frames >= 30, "mutacao (speed_scale 0,4) reprova a medida da corrida")
	a.speed_scale = 1.0
	_release()
	await _stop(m)


# ---------- salto do Pico ----------

func _jump() -> void:
	var m: Ep01Main = await _start(&"island_crossing")
	var st := m.stages[&"island_crossing"] as IslandStage
	var pico := m.actors[&"climber"] as MemberActor
	var d := m.director
	var fh: Array = Ep01Layout.ROCK_FOOTHOLDS
	r.check(st.get_node_or_null("RockSlab") == null, "nao ha laje continua entre margem e ilha")
	r.check(not st.has_ground((fh[0] as Vector3).lerp(fh[1] as Vector3, 0.5)), "entre os apoios 1 e 2 ha agua (sem chao)")

	# Mira assistida: do apoio 1, analogico mais ou menos para o apoio 2 -> mira o apoio 2.
	var aim: Variant = st.aim_from(fh[0] as Vector3, ((fh[1] as Vector3) - (fh[0] as Vector3)).rotated(Vector3.UP, 0.35))
	r.check(aim is Vector3 and (aim as Vector3).distance_to(fh[1] as Vector3) < 0.01, "mira assistida escolhe o apoio 2 com o analogico 20 graus desviado")

	# Salto automatico na borda com entrada real: da margem para o apoio 1.
	pico.teleport(Ep01Layout.LANDING_POS)
	await _physics(5)
	var jumps0 := st.jumps
	_push(m, (fh[0] as Vector3) - Ep01Layout.LANDING_POS)
	var frames := 0
	while d.last_safe_foothold < 1 and frames < 300:
		await r.tree.physics_frame
		frames += 1
	_release()
	r.check(st.jumps > jumps0, "Pico pulou sozinho ao chegar a borda empurrando para o apoio")
	r.check(d.last_safe_foothold == 1, "o salto pousou no apoio 1 (%d quadros)" % frames)
	await _physics(20)
	r.check(absf(pico.global_position.y - (fh[0] as Vector3).y) < 0.15, "Pico fica em pe sobre o apoio 1 (y=%.2f)" % pico.global_position.y)

	# Salto programado: apoio 1 -> 2 alcanca o alvo (arco acima da reta).
	var top := -INF
	st.jump_to(fh[1] as Vector3)
	r.check(pico.airborne, "durante o salto Pico esta no ar")
	frames = 0
	while pico.airborne and frames < 120:
		top = maxf(top, pico.global_position.y)
		await r.tree.process_frame
		frames += 1
	await _physics(2)
	st.process_stage(0.016)
	r.check(top > (fh[1] as Vector3).y + 0.4, "o salto faz arco (pico do arco y=%.2f)" % top)
	r.check(d.last_safe_foothold == 2 and IslandStage._horiz(pico.global_position, fh[1] as Vector3) < 0.2, "o salto alcanca o apoio 2")

	# Errar: pular na isca devolve ao ULTIMO apoio seguro (2), sem progresso.
	st.process_stage(2.0)
	st.jump_to(IslandStage.DECOYS[2] as Vector3)
	frames = 0
	while pico.airborne and frames < 120:
		await r.tree.process_frame
		frames += 1
	await r.frames(2)
	r.check(d.last_safe_foothold == 2 and IslandStage._horiz(pico.global_position, fh[1] as Vector3) < 0.2,
		"pular na isca devolve ao apoio 2 sem progresso")

	# Agua entre apoios: soltar Pico no vao -> cai e volta ao apoio 2.
	await r.tree.create_timer(1.1).timeout
	var gap := (fh[1] as Vector3).lerp(fh[2] as Vector3, 0.5)
	pico.teleport(Vector3(gap.x, 0.3, gap.z + 0.2))
	frames = 0
	var fell := false
	while frames < 120:
		await r.tree.physics_frame
		frames += 1
		if pico.global_position.y < -0.5:
			fell = true
		if fell and IslandStage._horiz(pico.global_position, fh[1] as Vector3) < 0.2:
			break
	r.check(fell, "no vao entre apoios Pico cai (nao ha laje)")
	r.check(IslandStage._horiz(pico.global_position, fh[1] as Vector3) < 0.2 and d.last_safe_foothold == 2,
		"cair na agua devolve ao ultimo apoio seguro")

	# MUTACAO: laje continua de volta -> Pico nao cai no vao; restaurada.
	await r.tree.create_timer(1.1).timeout
	var slab := Blocks.solid_box(st, "RockSlab", Vector3(9.0, 1.0, 6.0), Vector3(186.0, -0.5, 5.4), Color.GRAY)
	await _physics(2)
	pico.teleport(Vector3(gap.x, 0.3, gap.z + 0.2))
	await _physics(40)
	r.check(pico.global_position.y > -0.5, "mutacao (laje continua) reprova a verificacao de queda")
	slab.free()
	await _physics(2)
	r.check(st.get_node_or_null("RockSlab") == null, "mutacao da laje restaurada")
	await _stop(m)


# ---------- troca de integrante ----------

func _team_pose() -> void:
	Ep01Main.start_state = &""
	var m := (load("res://episodes/ep01/ep01_main.tscn") as PackedScene).instantiate() as Ep01Main
	r.tree.root.add_child(m)
	r.tree.current_scene = m
	await r.frames(3)
	var started: Array[StringName] = []
	m.team_pose_started.connect(func(who: StringName) -> void: started.append(who))
	(m.stages[&"arrival"] as ArrivalStage).skip_intro()
	await r.tree.create_timer(1.2).timeout
	r.check(m.hud.handoff_open, "troca aberta")
	m.hud.handoff_confirmed.emit()
	await r.frames(2)
	r.check(started == [&"tracker"] and m.posing, "confirmar dispara a pose de equipe de Rastro")
	r.check(m.controlled_node == null, "durante a pose o controle ainda nao voltou")
	r.check(m.camera_rig.framing_world and m.camera_rig.target == m.actors[&"tracker"], "a camera enquadra o heroi de frente")
	var a := m.actors[&"tracker"] as MemberActor
	if a.model != null:
		var expected: StringName = &""
		for anim: StringName in Ep01Main.TEAM_POSE_ANIMS:
			if a.model.has_animation(anim):
				expected = anim
				break
		r.check(m.last_pose_anim == expected, "clipe da pose: %s (esperado %s)" % [m.last_pose_anim, expected])
	await r.tree.create_timer(Ep01Main.TEAM_POSE_SECONDS * 0.5).timeout
	r.check(m.controlled_node == null, "na metade da pose ainda sem controle")
	await r.tree.create_timer(Ep01Main.TEAM_POSE_SECONDS * 0.5 + 0.2).timeout
	r.check(not m.posing and m.controlled_node == a, "depois da pose o controle volta a Rastro")
	r.check(not m.camera_rig.framing_world, "a camera volta a vista do estagio")
	await _stop(m)


# ---------- emblemas ----------

func _collectibles() -> void:
	Ep01Collectibles.reset_run()
	var m: Ep01Main = await _start(&"dock_investigation")
	var c := m.collectibles
	r.check(c != null and c.emblems.size() == 10 and Ep01Collectibles.total() == 10, "10 emblemas existem")
	await _physics(3)
	var space := m.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.5
	var free_ok := 0
	var floor_ok := 0
	var foot := 0
	for i in Ep01Collectibles.SPOTS.size():
		var spot: Array = Ep01Collectibles.SPOTS[i]
		var p: Vector3 = spot[0]
		if spot[1] == &"boat":
			r.check(RiverZones.clearance(p) > 0.6, "emblema %d de barco esta em agua navegavel (folga %.1f m)" % [i + 1, RiverZones.clearance(p)])
			continue
		foot += 1
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cap
		q.collision_mask = 1
		q.transform = Transform3D(Basis(), p + Vector3(0, 0.85, 0))
		var hits := space.intersect_shape(q, 4)
		if hits.is_empty():
			free_ok += 1
		else:
			r.check(false, "emblema %d bloqueado por %s" % [i + 1, (hits[0]["collider"] as Node).get_path()])
		var ray := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.0, 0), p - Vector3(0, 1.0, 0), 1)
		if not space.intersect_ray(ray).is_empty():
			floor_ok += 1
		else:
			r.check(false, "emblema %d sem chao embaixo" % (i + 1))
	r.check(free_ok == foot, "emblemas a pe sem colisao bloqueando (shape cast %d/%d)" % [free_ok, foot])
	r.check(floor_ok == foot, "emblemas a pe tem chao para pisar (%d/%d)" % [floor_ok, foot])

	var counts: Array[int] = []
	m.collectible_found.connect(func(n: int, _t: int) -> void: counts.append(n))
	var tracker := m.actors[&"tracker"] as MemberActor
	tracker.teleport(Ep01Collectibles.SPOTS[0][0] as Vector3)
	await r.frames(3)
	r.check(Ep01Collectibles.count() == 1 and counts == [1], "encostar coleta o emblema (sinal 1/10)")
	await r.frames(3)
	r.check(not c.collect(0) and Ep01Collectibles.count() == 1 and counts.size() == 1, "a contagem nao duplica")
	r.check(not c.emblems[0].visible, "emblema coletado some")
	r.check(m.director.state == &"dock_investigation", "coletar nao mexe no progresso")
	# MUTACAO: duplicata forcada -> a verificacao de unicidade reprova; restaurada.
	Ep01Collectibles.collected.append(0)
	var unique := {}
	for i in Ep01Collectibles.collected:
		unique[i] = true
	r.check(unique.size() != Ep01Collectibles.collected.size(), "mutacao (duplicata) e detectada")
	Ep01Collectibles.collected.pop_back()
	r.check(Ep01Collectibles.count() == 1, "mutacao da duplicata restaurada")
	await _stop(m)
	# Recarga na mesma execucao: o emblema continua coletado.
	var m2: Ep01Main = await _start(&"dock_investigation")
	r.check(not m2.collectibles.emblems[0].visible and Ep01Collectibles.count() == 1, "contagem sobrevive a recarga da cena")
	await _stop(m2)
	Ep01Collectibles.reset_run()


# ---------- retorno visual e camera ----------

func _feedback_and_camera() -> void:
	var m: Ep01Main = await _start(&"dock_investigation")
	var s0 := FeedbackFx.count(&"sparkle")
	var p0 := FeedbackFx.count(&"pulse")
	var tracker := m.actors[&"tracker"] as MemberActor
	tracker.teleport(Ep01Layout.BENCH_INTERACT_POS)
	await r.frames(3)
	r.check(FeedbackFx.count(&"pulse") > p0, "pulso no alvo quando a acao fica disponivel")
	r.check(m.try_interact(), "examinar perto do banco")
	r.check(FeedbackFx.count(&"sparkle") > s0, "estrelinhas ao examinar")
	r.check(not m.get_tree().get_nodes_in_group(FeedbackFx.GROUP).is_empty(), "efeitos existem na cena")
	# Camera: antecipacao com movimento; sem antecipacao e sem tremor em reduced_motion.
	await r.tree.create_timer(2.5).timeout
	tracker.teleport(Vector3(-4.0, 0.05, 9.0))
	m.camera_rig.follow(tracker, true)
	await _physics(3)
	_push(m, Vector3.RIGHT)
	await r.tree.create_timer(0.8).timeout
	r.check(m.camera_rig.lead.length() > 0.3, "camera antecipa na direcao do movimento (%.2f m)" % m.camera_rig.lead.length())
	m.camera_rig.reduced_motion = true
	await r.frames(3)
	m.camera_rig.shake(0.5, 1.0)
	r.check(m.camera_rig.lead.length() == 0.0, "reduced_motion: sem antecipacao")
	r.check(m.camera_rig.get(&"_shake_time") == 0.0, "reduced_motion: sem tremor")
	m.camera_rig.reduced_motion = false
	_release()
	await _stop(m)

	var m2: Ep01Main = await _start(&"island_crossing")
	var st := m2.stages[&"island_crossing"] as IslandStage
	for i in 3:
		st.step_on_foothold(i + 1)
	var r0 := FeedbackFx.count(&"ring")
	st.fix_line()
	r.check(FeedbackFx.count(&"ring") >= r0 + 2, "anel de luz ao fixar a linha")
	await r.frames(2)
	var dk := m2.stages[&"docking"] as DockingStage
	var sp0 := FeedbackFx.count(&"splash")
	dk.dock_now()
	r.check(FeedbackFx.count(&"splash") > sp0, "respingo ao atracar")
	await _stop(m2)
