extends RefCounted
## RB-R1: moradores animados no cais (12 a 20, sem multidao em blocos, longe dos pontos jogaveis, animacao tocando).

const MIN_CLEARANCE := 4.0

var r


func run(runner) -> void:
	r = runner
	Ep01Main.start_state = &"dock_investigation"
	var m := (load("res://episodes/ep01/ep01_main.tscn") as PackedScene).instantiate() as Ep01Main
	r.tree.root.add_child(m)
	r.tree.current_scene = m
	await r.frames(3)
	var dock := m.stages[&"dock_investigation"] as DockStage

	var crowd := dock.find_children("Crowd*", "", true, false)
	r.check(crowd.is_empty(), "nenhum no de multidao em blocos (CrowdBody/CrowdHead) restante (%d)" % crowd.size())

	var vill := dock.villagers
	r.check(vill != null, "estagio do cais tem moradores")
	if vill == null:
		await _drop(m)
		return
	var bodies := vill.villagers()
	r.check(bodies.size() >= 12 and bodies.size() <= 20, "12 a 20 moradores (%d)" % bodies.size())

	var models := {}
	var kinds := {}
	for b in bodies:
		models[b.scene_file_path] = true
		kinds[vill.routine_of(b)] = true
	r.check(models.size() == 3, "usa os tres modelos de morador (%d)" % models.size())
	r.check(kinds.has(&"chat") and kinds.has(&"walk") and kinds.has(&"watch"), "rotinas chat, walk e watch presentes")

	var key_points: Array[Vector3] = [Ep01Layout.RASTRO_START, Ep01Layout.BENCH_INTERACT_POS, Ep01Layout.BANK_PRINT_POS,
		Ep01Layout.BOAT_DOCKED_POS]
	for c in Ep01Collectibles.SPOTS:
		key_points.append(c[0])
	# Varre alguns quadros (os que andam mudam de lugar) e confere distancia, colisao e animacao.
	var too_close := 0
	var no_anim := 0
	var colliding := 0
	var min_d := INF
	for pass_i in 3:
		for b in bodies:
			var body := b as CharacterBody3D
			if body.collision_layer != 0 or body.collision_mask != 0:
				colliding += 1
			for p in key_points:
				var d := Vector2(body.global_position.x - p.x, body.global_position.z - p.z).length()
				min_d = minf(min_d, d)
				if d < MIN_CLEARANCE:
					too_close += 1
			var visual := body.get_node("Model") as CharacterVisual
			var player := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if player == null or not player.is_playing() or visual.current_animation() == &"":
				no_anim += 1
		await r.frames(20)
	r.check(too_close == 0, "nenhum morador a menos de %.1f m dos pontos jogaveis (min %.2f m)" % [MIN_CLEARANCE, min_d])
	r.check(colliding == 0, "moradores sem colisao (camada e mascara 0)")
	r.check(no_anim == 0, "todo morador com animacao tocando")

	# Fases dessincronizadas: posicoes de animacao distintas entre moradores com o mesmo clipe.
	var phases := {}
	for b in bodies:
		var player := (b.get_node("Model") as Node).find_child("AnimationPlayer", true, false) as AnimationPlayer
		phases[snappedf(player.current_animation_position, 0.01)] = true
	r.check(phases.size() >= bodies.size() - 2, "fases de animacao dessincronizadas (%d distintas)" % phases.size())

	# Quem anda se desloca; o barco perto vira o espectador.
	var walker: Node3D = null
	var watcher: Node3D = null
	for b in bodies:
		if walker == null and vill.routine_of(b) == &"walk":
			walker = b
		if watcher == null and vill.routine_of(b) == &"watch":
			watcher = b
	var w0 := walker.global_position
	await r.frames(120)
	r.check(walker.global_position.distance_to(w0) > 0.05, "morador do passeio se desloca")
	r.check(vill.watch_target == m.boat, "espectador tem o barco como alvo")
	var to_boat := m.boat.global_position - watcher.global_position
	var fwd := -watcher.global_transform.basis.z
	var facing := Vector2(fwd.x, fwd.z).normalized().dot(Vector2(to_boat.x, to_boat.z).normalized())
	r.check(to_boat.length() > HarborVillagers.WATCH_RANGE or facing > 0.9, "espectador perto do barco vira para ele (cos %.2f, %.1f m)" % [facing, to_boat.length()])

	# Recuperacao: o estagio continua jogavel com os moradores (a pista e aceita).
	r.check(dock.examine_clue(&"paw_print_bench").accepted, "com moradores, a pista do banco segue aceita")
	await _drop(m)


func _drop(m: Ep01Main) -> void:
	m.queue_free()
	await r.frames(2)
	r.tree.current_scene = null
	Ep01Main.start_state = &""
