extends RefCounted
## RB-R1 C2 - movimento a pe no Ep01 v3: andar por padrao, correr segurando `run`, pulo `jump` curto, cadencia dos pes
## proporcional a velocidade real e seguidores parando em formacao sem se sobrepor. Entrada so pela Input Map.
## Mede estado (velocidade, altura, distancias, escala do clipe); nao comprova como a corrida parece na tela.

var r
var main: Ep01V3Main


func run(runner) -> void:
	r = runner
	_static_rules()
	Ep01V3Main.start_mission = &""
	Ep01V3Main.save_path = ""
	main = (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	r.tree.root.add_child(main)
	r.tree.current_scene = main
	await r.frames(3)
	# Sem missao ativa: nenhum gatilho, gesto de ajuda ou pose interfere na medida do movimento.
	main.current = null
	r.check(InputMap.has_action(&"run") and InputMap.has_action(&"jump"), "mov: acoes `run` e `jump` na Input Map")
	await _gait_and_formation(false)
	await _gait_and_formation(true)
	await _jump_arc()
	await _jump_blocked()
	await _jump_map_edge()
	await _buttons()
	await _speech_eats_interact()
	await _followers_height_and_teleport()
	await _climb_zones()
	await _bench_jumpable()
	_release()
	main.queue_free()
	await r.frames(2)
	r.tree.current_scene = null


func _static_rules() -> void:
	r.check(is_equal_approx(MemberActor.target_speed(1.0), MemberActor.WALK_SPEED), "mov: sem `run` a inclinacao total anda a %.1f m/s" % MemberActor.WALK_SPEED)
	r.check(is_equal_approx(MemberActor.target_speed(1.0, true), MemberActor.RUN_SPEED), "mov: com `run` corre a %.1f m/s" % MemberActor.RUN_SPEED)
	r.check(MemberActor.target_speed(0.05, true) == 0.0, "mov: zona morta do analogico para")
	var a := MemberActor.new()
	a.setup(&"tracker")
	var w1: Dictionary = a.gait(0.9)
	var w2: Dictionary = a.gait(1.4)
	var r1: Dictionary = a.gait(2.6)
	var r2: Dictionary = a.gait(3.2)
	r.check(w1["anim"] == &"walk" and r2["anim"] == &"run", "mov: 1,4 m/s toca walk e 3,2 m/s toca run")
	r.check(absf(float(w2["scale"]) / float(w1["scale"]) - 1.4 / 0.9) < 0.001 and absf(float(r2["scale"]) / float(r1["scale"]) - 3.2 / 2.6) < 0.001,
		"mov: escala do clipe proporcional a velocidade (walk x%.2f/x%.2f, run x%.2f/x%.2f)" % [w1["scale"], w2["scale"], r1["scale"], r2["scale"]])
	r.check(absf(float(r2["scale"]) * a.model.run_speed_mps - 3.2) < 0.01 and absf(float(w2["scale"]) * a.model.walk_speed_mps - 1.4) < 0.01,
		"mov: pe de apoio anda na velocidade do corpo (escala x avanco do pe = velocidade)")
	print("  medida cadencia Rastro: walk x%.2f a 1,4 m/s (%.2f passos/s), run x%.2f a 3,2 m/s (%.2f passos/s)" % [
		w2["scale"], 2.0 * float(w2["scale"]) / a.model.animation_length(&"walk"),
		r2["scale"], 2.0 * float(r2["scale"]) / a.model.animation_length(&"run")])
	a.free()
	var h := MemberActor.JUMP_VELOCITY * MemberActor.JUMP_VELOCITY / (2.0 * MemberActor.GRAVITY)
	r.check(absf(h - MemberActor.JUMP_HEIGHT) < 0.005, "mov: impulso do pulo bate com a altura %.2f m" % h)


func _physics(n: int) -> void:
	for i in n:
		await r.tree.physics_frame


func _release() -> void:
	for a: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"run", &"jump"]:
		Input.action_release(a)


func _push(dir: Vector3) -> void:
	var local := Basis(Vector3.UP, -main.camera_rig.yaw) * dir.normalized()
	for pair: Array in [[&"move_right", local.x], [&"move_left", -local.x], [&"move_down", local.z], [&"move_up", -local.z]]:
		if float(pair[1]) > 0.01:
			Input.action_press(pair[0] as StringName, float(pair[1]))
		else:
			Input.action_release(pair[0] as StringName)


func _planar(a: MemberActor) -> float:
	return Vector2(a.velocity.x, a.velocity.z).length()


func _floor(x: float, z: float) -> Vector3:
	var space := main.world.get_world_3d().direct_space_state
	var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 6.0, z), Vector3(x, -3.0, z), 1))
	return h.position as Vector3 if not h.is_empty() else Vector3(x, 0.0, z)


## Ponto e direcao de chao livre por `length` m (sem parede a 0,8 m e chao ate o fim), perto da praca da festa.
func _open_lane(length: float) -> Array:
	var space := main.world.get_world_3d().direct_space_state
	var base := main.world.marker(&"M8_FestaPlaza").global_position
	for oz: float in [0.0, 4.0, -4.0, 8.0]:
		for i in 16:
			var d := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 16.0)
			var o := base + Vector3(0, 0, oz)
			var ok := true
			var q := PhysicsShapeQueryParameters3D.new()
			var sph := SphereShape3D.new()
			sph.radius = 1.4
			q.shape = sph
			q.collision_mask = 1
			q.motion = d * (length + 2.5)
			for h: float in [1.5, 2.2]:
				q.transform = Transform3D(Basis(), o - d * 2.5 + Vector3(0, h, 0))
				var res := space.cast_motion(q)
				if res.is_empty() or res[0] < 1.0:
					ok = false
			for k in 9:
				var p := o + d * length * k / 8.0
				if absf(_floor(p.x, p.z).y - o.y) > 0.15:
					ok = false
			if ok:
				return [o, d]
	return []


func _place_trio(origin: Vector3, d: Vector3) -> void:
	var lead := main.actors[&"tracker"] as MemberActor
	main.set_controlled(lead)
	var back := -d
	var side := d.cross(Vector3.UP)
	lead.teleport(origin + Vector3(0, 0.05, 0))
	(main.actors[&"climber"] as MemberActor).teleport(origin + back * 1.2 + side * 1.0 + Vector3(0, 0.05, 0))
	(main.actors[&"pilot"] as MemberActor).teleport(origin + back * 1.2 - side * 1.0 + Vector3(0, 0.05, 0))
	lead.face_now(origin + d)


func _min_gap() -> float:
	var ms: Array = main.actors.keys()
	var best := INF
	for i in ms.size():
		for j in range(i + 1, ms.size()):
			var a := (main.actors[ms[i]] as Node3D).global_position
			var b := (main.actors[ms[j]] as Node3D).global_position
			best = minf(best, Vector2(a.x - b.x, a.z - b.z).length())
	return best


## Anda (ou corre) 2,5 s em linha reta pela entrada real, para, e mede velocidade, clipe, escala e formacao.
func _gait_and_formation(running: bool) -> void:
	var tag := "corrida" if running else "caminhada"
	var lane := _open_lane(10.5 if running else 5.0)
	r.check(not lane.is_empty(), "mov %s: achou faixa livre na praca" % tag)
	if lane.is_empty():
		return
	var d: Vector3 = lane[1]
	_place_trio(lane[0] as Vector3, d)
	await _physics(10)
	var lead := main.actors[&"tracker"] as MemberActor
	main.camera_rig.yaw = 0.0
	if running:
		Input.action_press(&"run")
	_push(d)
	var t := 0.0
	var speeds: Array[float] = []
	var scales_ok := true
	var follower_ran := false
	while t < 2.5:
		await r.tree.physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		if t > 0.5:
			speeds.append(_planar(lead))
			var g := lead.gait(_planar(lead))
			var cur := lead.model.current_animation()
			var want_scale := _planar(lead) / (lead.model.run_speed_mps if cur == &"run" else lead.model.walk_speed_mps)
			if cur != g["anim"] or absf(float(g["scale"]) - want_scale) > 0.01:
				scales_ok = false
			for m: StringName in [&"climber", &"pilot"]:
				follower_ran = follower_ran or ((main.actors[m] as MemberActor).running and _planar(main.actors[m] as MemberActor) > MemberActor.RUN_THRESHOLD)
	var avg := 0.0
	for s in speeds:
		avg += s
	avg /= maxf(speeds.size(), 1)
	var want := MemberActor.RUN_SPEED if running else MemberActor.WALK_SPEED
	r.check(absf(avg - want) < want * 0.04, "mov %s: velocidade media %.2f m/s (alvo %.2f)" % [tag, avg, want])
	var clip := lead.model.current_animation()
	r.check(clip == (&"run" if running else &"walk"), "mov %s: clipe %s" % [tag, clip])
	r.check(scales_ok, "mov %s: escala do clipe = velocidade real / avanco do pe em todos os quadros" % tag)
	if running:
		r.check(follower_ran, "mov corrida: seguidores correm com o lider")
	_release()
	var lead_stop := Vector3.ZERO
	var settle_frames := 0
	await _physics(12)
	lead_stop = lead.global_position
	var last := {}
	var jitter := 0.0
	var frames := 0
	while frames < 300:
		await r.tree.physics_frame
		frames += 1
		if frames > 240:
			for m: StringName in [&"climber", &"pilot"]:
				var p := (main.actors[m] as Node3D).global_position
				if last.has(m):
					jitter += p.distance_to(last[m] as Vector3)
				last[m] = p
		settle_frames = frames
	var gap := _min_gap()
	r.check(gap >= 0.8, "mov %s: distancia minima entre os tres depois de parar %.2f m (>= 0,8)" % [tag, gap])
	r.check(lead.global_position.distance_to(lead_stop) < 0.02, "mov %s: lider nao e empurrado (%.3f m)" % [tag, lead.global_position.distance_to(lead_stop)])
	r.check(jitter < 0.02, "mov %s: seguidores parados sem tremer (%.3f m no ultimo 1 s)" % [tag, jitter])
	var fwd := lead.facing()
	var behind := true
	var sides: Array[float] = []
	for m: StringName in [&"climber", &"pilot"]:
		var rel := (main.actors[m] as Node3D).global_position - lead.global_position
		rel.y = 0.0
		behind = behind and rel.dot(fwd) < -0.3
		sides.append(rel.dot(fwd.cross(Vector3.UP)))
	r.check(behind and sides[0] * sides[1] < 0.0, "mov %s: seguidores atras e um de cada lado do lider (lados %.2f / %.2f)" % [tag, sides[0], sides[1]])
	print("  medida %s: %.2f m/s, gap minimo %.2f m, tremor %.3f m, %d quadros" % [tag, avg, gap, jitter, settle_frames])
	for m: StringName in [&"climber", &"pilot"]:
		var f := main.actors[m] as MemberActor
		print("  medida %s %s: a %.2f m do lugar na formacao (lugar livre=%s)" % [tag, m, f.global_position.distance_to(f.formation_slot()), f.formation_slot() != f.global_position])
	if running:
		# Recuperacao: um seguidor jogado dentro do outro (o caso que Thiago viu) se separa e volta a formacao.
		var climber := main.actors[&"climber"] as MemberActor
		climber.global_position = (main.actors[&"pilot"] as Node3D).global_position + Vector3(0.05, 0, 0)
		await _physics(240)
		r.check(_min_gap() >= 0.8 and lead.global_position.distance_to(lead_stop) < 0.02,
			"mov recuperacao: seguidores sobrepostos se separam (gap %.2f m) sem mover o lider" % _min_gap())


func _jump_arc() -> void:
	var lane := _open_lane(4.0)
	if lane.is_empty():
		r.check(false, "mov pulo: faixa livre")
		return
	_place_trio(lane[0] as Vector3, lane[1] as Vector3)
	var lead := main.actors[&"tracker"] as MemberActor
	await _physics(15)
	var y0 := lead.global_position.y
	r.check(lead.can_jump(), "mov pulo: no chao e livre, pode pular")
	var jumps0 := lead.jumps
	Input.action_press(&"jump")
	await r.tree.physics_frame
	Input.action_release(&"jump")
	var top := y0
	var frames := 1
	while frames < 120:
		await r.tree.physics_frame
		frames += 1
		top = maxf(top, lead.global_position.y)
		if not lead.jumping:
			break
	var dur := float(frames) / Engine.physics_ticks_per_second
	r.check(lead.jumps == jumps0 + 1, "mov pulo: `jump` pula uma vez")
	r.check(absf(top - y0 - MemberActor.JUMP_HEIGHT) < 0.05, "mov pulo: altura %.2f m (alvo %.2f)" % [top - y0, MemberActor.JUMP_HEIGHT])
	r.check(absf(dur - MemberActor.jump_duration()) < 0.06, "mov pulo: duracao %.2f s (alvo %.2f)" % [dur, MemberActor.jump_duration()])
	r.check(absf(lead.global_position.y - y0) < 0.03 and lead.is_on_floor(), "mov pulo: pousa no chao sem dano (y %.3f)" % (lead.global_position.y - y0))
	print("  medida pulo: altura %.3f m, duracao %.3f s" % [top - y0, dur])


func _jump_blocked() -> void:
	var lead := main.actors[&"tracker"] as MemberActor
	await _physics(5)
	var y0 := lead.global_position.y
	var jumps0 := lead.jumps
	main.land.busy = true
	Input.action_press(&"jump")
	await _physics(10)
	Input.action_release(&"jump")
	r.check(lead.jumps == jumps0 and absf(lead.global_position.y - y0) < 0.02, "mov pulo: bloqueado durante `busy`")
	main.land.busy = false
	await _physics(2)
	# Durante o salto programado (`jump_to`) tambem nao pula, e o jump_to chega ao alvo.
	var to := lead.global_position + lead.facing() * 0.8
	lead.jump_to(to, 0.5, 0.6)
	await r.tree.physics_frame
	Input.action_press(&"jump")
	await _physics(3)
	Input.action_release(&"jump")
	r.check(lead.jumps == jumps0, "mov pulo: bloqueado durante `jump_to`")
	await lead.landed
	r.check(lead.global_position.distance_to(to) < 0.01, "mov pulo: salto programado `jump_to` (o do Pico) intacto, chega ao alvo")
	await _physics(5)
	# Recuperacao: livre de novo, volta a pular.
	Input.action_press(&"jump")
	await _physics(3)
	Input.action_release(&"jump")
	r.check(lead.jumps == jumps0 + 1, "mov pulo: depois de `busy`/`jump_to`, pula de novo")
	await _physics(40)


## Beira do cais norte (parede de agua): pular encostado na parede nao passa por cima nem atravessa.
func _jump_map_edge() -> void:
	var space := main.world.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 0.8, -15.0), Vector3(0, 0.8, -10.0), 1))
	r.check(not hit.is_empty(), "mov limite: parede da beira d'agua encontrada")
	if hit.is_empty():
		return
	var wall_z := (hit.position as Vector3).z
	var start := _floor(0.0, wall_z - 1.2)
	var lead := main.actors[&"tracker"] as MemberActor
	_place_trio(start, Vector3.BACK)
	await _physics(10)
	var max_z := -INF
	Input.action_press(&"run")
	_push(Vector3.BACK)
	for i in 8:
		Input.action_press(&"jump")
		await r.tree.physics_frame
		Input.action_release(&"jump")
		for k in 30:
			await r.tree.physics_frame
			max_z = maxf(max_z, lead.global_position.z)
	_release()
	await _physics(10)
	r.check(max_z < wall_z - 0.3 and lead.global_position.y > start.y - 0.1,
		"mov limite: pulando contra a beira d'agua fica do lado de terra (z max %.2f, parede %.2f)" % [max_z, wall_z])


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _pad(button: JoyButton, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.device = 0
	Input.parse_input_event(ev)


## Botoes (decisao do lead): `interact` = E / X, `jump` = Espaco / A. Interagir nao pula; Espaco nao avanca a fala; E avanca.
func _buttons() -> void:
	r.check(not _has_button(&"interact", JOY_BUTTON_A) and _has_button(&"interact", JOY_BUTTON_X) and _has_button(&"jump", JOY_BUTTON_A),
		"mov botoes: interact no X, jump no A (sem botao compartilhado)")
	var lane := _open_lane(3.0)
	if not lane.is_empty():
		_place_trio(lane[0] as Vector3, lane[1] as Vector3)
	var lead := main.actors[&"tracker"] as MemberActor
	await _physics(20)
	var j0 := lead.jumps
	_key(KEY_E, true)
	await _physics(3)
	_key(KEY_E, false)
	_pad(JOY_BUTTON_X, true)
	await _physics(3)
	_pad(JOY_BUTTON_X, false)
	await _physics(30)
	r.check(lead.jumps == j0, "mov botoes: interagir (E e X) nao pula")
	main.hud.say("ep01.test.c2_line_a")
	main.hud.say("ep01.test.c2_line_b")
	await r.frames(2)
	r.check(main.hud.is_speaking(), "mov botoes: fala aberta")
	var q0: int = main.hud._queue.size()
	_key(KEY_SPACE, true)
	await _physics(3)
	_key(KEY_SPACE, false)
	await r.frames(1)
	r.check(main.hud._queue.size() == q0 and q0 > 0, "mov botoes: Espaco nao avanca a fala")
	r.check(lead.jumps == j0 + 1, "mov botoes: Espaco pula (fala aberta nao bloqueia o pulo)")
	await _physics(40)
	_key(KEY_E, true)
	await r.frames(1)
	await r.frames(3)
	var skipped: bool = main.hud._queue.size() < q0
	_key(KEY_E, false)
	r.check(skipped, "mov botoes: E (interact) avanca a fala")
	main.hud.clear_speech()
	await r.frames(2)


func _has_button(action: StringName, b: JoyButton) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == b:
			return true
	return false


## Revisao C2: com fala aberta, um E perto de um ponto de acao so avanca a fala (a acao nao dispara); sem fala, dispara.
func _speech_eats_interact() -> void:
	var lead := main.actors[&"tracker"] as MemberActor
	await _physics(10)
	var it := Ep01Interactable.new()
	it.name = "C2TestSpot"
	it.radius = 2.0
	main.world.add_child(it)
	it.global_position = lead.global_position
	main.land.spots[&"c2_test"] = it
	var hits := [0]
	it.triggered.connect(func(_a: Node3D) -> void: hits[0] += 1)
	main.hud.clear_speech()
	await r.frames(30)
	_key(KEY_E, true)
	await r.frames(2)
	_key(KEY_E, false)
	await r.frames(2)
	r.check(hits[0] == 1, "mov fala: sem fala, E perto do ponto dispara a acao (%d)" % hits[0])
	main.hud.say("ep01.test.c2_line_a")
	main.hud.say("ep01.test.c2_line_b")
	await r.frames(2)
	var q0: int = main.hud._queue.size()
	_key(KEY_E, true)
	await r.frames(2)
	_key(KEY_E, false)
	await r.frames(3)
	r.check(main.hud._queue.size() < q0 and hits[0] == 1, "mov fala: com fala aberta, E so avanca a fala (acao nao disparou: %d)" % hits[0])
	main.hud.clear_speech()
	main.land.spots.erase(&"c2_test")
	it.queue_free()
	await r.frames(2)


## Revisao C2: seguidor nao persegue o lider em outra altura; teleporte de 9 m cai em chao livre, do lado oposto a camera.
func _followers_height_and_teleport() -> void:
	var lane := _open_lane(5.0)
	if lane.is_empty():
		r.check(false, "mov seguidor: faixa livre")
		return
	var o: Vector3 = lane[0]
	var d: Vector3 = lane[1]
	_place_trio(o, d)
	await _physics(10)
	var lead := main.actors[&"tracker"] as MemberActor
	var climber := main.actors[&"climber"] as MemberActor
	climber.teleport(o - d * 4.0 + Vector3(0, 0.05, 0))
	await _physics(5)
	# Lider parado 0,6 m acima (como num degrau): fisica do lider desligada enquanto mede.
	lead.set_physics_process(false)
	lead.global_position = o + Vector3(0, 0.6, 0)
	var c0 := climber.global_position
	await _physics(60)
	r.check(climber.auto_dir == Vector3.ZERO and climber.global_position.distance_to(c0) < 0.05,
		"mov seguidor: lider 0,6 m acima -> seguidor nao corre contra o degrau (andou %.2f m)" % climber.global_position.distance_to(c0))
	lead.global_position = o + Vector3(0, 0.05, 0)
	lead.set_physics_process(true)
	await _physics(10)
	# Seguidor preso a 12 m: teleporte para chao livre, do lado oposto a camera.
	climber.set_physics_process(false)
	climber.global_position = Vector3(o.x, o.y + 0.05, o.z) - d * 12.0
	await _physics(3)
	climber.set_physics_process(true)
	var cam := main.camera_rig.camera.global_position
	var rel := climber.global_position - lead.global_position
	var to_cam := cam - lead.global_position
	rel.y = 0.0
	to_cam.y = 0.0
	var p := climber.global_position
	r.check(rel.length() <= 6.0 + 0.2, "mov seguidor: preso a 12 m foi teleportado para no maximo 6 m do lider (%.2f m)" % rel.length())
	r.check(not main.in_camera_view(climber.global_position), "mov seguidor: teleporte cai fora do enquadramento da camera (F1)")
	r.check(climber.slot_clear(lead.global_position, Vector3(p.x, lead.global_position.y, p.z)), "mov seguidor: destino do teleporte com chao e sem parede")
	await _physics(5)


const CLIMB_SETS := {
	"M2 galpao": [&"M2_ShedStep_1", &"M2_ShedStep_2", &"M2_ShedTop"],
	"M3 chafariz": [&"M3_FountainStep_1", &"M3_FountainStep_2", &"M3_FountainStep_3", &"M3_UpperBasin"],
	"M5 caixotes/toldo/telhado": [&"M5_Crates", &"M5_Awning", &"M5_ShedRoof"],
	"M7 farol": [&"M7_StairStep", &"M7_StairBase", &"M7_Landing_1", &"M7_Landing_2", &"M7_Landing_3", &"M7_Gallery"],
}


## Revisao C2: por estrutura da tabela de degraus, de 12 lados, correndo e pulando a cada 0,5 s por 4 s em direcao aos
## marcadores: no chao, o heroi nunca fica na altura de um marcador perto dele.
func _climb_zones() -> void:
	var lead := main.actors[&"tracker"] as MemberActor
	for label: String in CLIMB_SETS:
		var marks: Array[Vector3] = []
		var center := Vector3.ZERO
		for mk: StringName in CLIMB_SETS[label]:
			var mm := main.world.marker(mk)
			if mm != null:
				marks.append(mm.global_position)
				center += mm.global_position
		center /= maxf(marks.size(), 1)
		var reached: Array[String] = []
		var tries := 0
		var jumps0 := lead.jumps
		for i in 12:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 12.0)
			var start := center + dir * 6.5
			var fl := _floor(start.x, start.z)
			if fl.y > marks[0].y - 0.2 or fl.y < marks[0].y - 1.2:
				continue
			tries += 1
			lead.teleport(fl + Vector3(0, 0.05, 0))
			await _physics(5)
			Input.action_press(&"run")
			for t in 240:
				var tgt := marks[(t / 60) % marks.size()]
				var dd := tgt - lead.global_position
				dd.y = 0.0
				_push(dd if dd.length() > 0.05 else dir)
				if t % 30 == 0:
					Input.action_press(&"jump")
				elif t % 30 == 2:
					Input.action_release(&"jump")
				await r.tree.physics_frame
				if lead.is_on_floor():
					for mp: Vector3 in marks:
						var h := Vector2(mp.x - lead.global_position.x, mp.z - lead.global_position.z).length()
						if h < 1.2 and lead.global_position.y > mp.y - 0.08:
							reached.append("%s y%.2f" % [mp, lead.global_position.y])
			_release()
			await _physics(3)
		r.check(tries >= 4 and reached.is_empty(), "mov subida %s: %d lados correndo e pulando, nenhum marcador alcancado %s (pulos %d)" % [
			label, tries, reached.slice(0, 2), lead.jumps - jumps0])


## Fora das zonas o pulo e livre: o banco de 0,48 m (Props/bench_2 em -6,8; -14,0) e pulavel.
func _bench_jumpable() -> void:
	var lead := main.actors[&"tracker"] as MemberActor
	var bench := Vector3(-6.8, 0, -14.0)
	var best := -INF
	for dir: Vector3 in [Vector3.BACK, Vector3.FORWARD, Vector3.LEFT, Vector3.RIGHT]:
		var start := bench + dir * 1.6
		lead.teleport(_floor(start.x, start.z) + Vector3(0, 0.05, 0))
		await _physics(5)
		var y0 := lead.global_position.y
		for t in 90:
			var dd := bench - lead.global_position
			dd.y = 0.0
			_push(dd if dd.length() > 0.1 else -dir)
			if t == 8:
				Input.action_press(&"jump")
			elif t == 11:
				Input.action_release(&"jump")
			await r.tree.physics_frame
			if lead.is_on_floor():
				best = maxf(best, lead.global_position.y - y0)
		_release()
		await _physics(3)
		if best > 0.4:
			break
	r.check(best > 0.4, "mov banco: fora das zonas o pulo sobe o banco de 0,48 m (%.2f m)" % best)
