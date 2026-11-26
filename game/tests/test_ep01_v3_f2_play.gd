extends RefCounted
## RB-R1 F2 (gameplay): padrao "Ver, ouvir, seguir" no Ep01 v3. Objetos reais no alvo de cada passo (P1), olhar dirigido
## com retorno do controle (P2), anel no alvo (P3), rastros entre missoes (P4), gesto das falas que apontam (P5), ajuda
## mais cedo (P6), variantes sem repetir (D19c) e retomada do M5 (antes: trio despencando num vao, tela azul).

const CLUE_REACH := 1.5
## Excecao medida: a aproximacao do bote e uma zona na agua; o objeto e o bote (com o capitao), a ~2,1 m da borda.
const REACH_EXCEPTIONS := {"M6.approach": 2.5}

var r


func run(runner) -> void:
	r = runner
	Ep01V3Main.save_path = ""
	_variants()
	await _visible_targets()
	await _look_and_ring()
	await _look_reduced_motion()
	await _trail_and_travel()
	await _resume_all()
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
	Ep01V3Main.start_mission = &""


func _wait(sec: float) -> void:
	await r.tree.create_timer(sec).timeout


# ---------------------------------------------------------------- D19c

func _variants() -> void:
	Ep01V3Dialogue.reset_picks(11)
	var groups: Dictionary = Ep01V3Dialogue.sheet().get("groups", {})
	var repeats := 0
	var missing: Array[String] = []
	var seen_all := true
	for g: String in groups:
		var keys := Ep01V3Dialogue.group_keys(g)
		var last := ""
		var seen := {}
		for i in 40:
			var k := Ep01V3Dialogue.pick(g)
			if k == last and keys.size() > 1:
				repeats += 1
			if not Loc.has_key(k) and not missing.has(k):
				missing.append(k)
			seen[k] = true
			last = k
		if seen.size() != keys.size():
			seen_all = false
	r.check(groups.size() >= 30 and repeats == 0, "f2 D19c: %d grupos, 40 sorteios cada, nenhuma fala repete a anterior (%d)" % [groups.size(), repeats])
	r.check(missing.is_empty(), "f2 D19c: toda variante sorteada esta no catalogo %s" % [missing])
	r.check(seen_all, "f2 D19c: o sorteio passa por todas as variantes de cada grupo")
	# A1: a fala de troca da missao sempre vence; os grupos de troca so tem chamados genericos (sem lugar), sorteados
	# sem repetir quando a missao nao tem fala propria.
	Ep01V3Dialogue.reset_picks(3)
	var always := true
	var generic := true
	for key: Variant in (Ep01V3Dialogue.sheet().get("switch", {}) as Dictionary):
		var parts := str(key).split(":")
		var call := Ep01V3Dialogue.switch_line(StringName(parts[0]), StringName(parts[1]))
		for i in 3:
			always = always and Ep01V3Dialogue.pick("switch.to_" + parts[1], call) == call
		generic = generic and not (call in Ep01V3Dialogue.group_keys("switch.to_" + parts[1]))
	r.check(always, "f2 A1: a fala de troca da missao sempre sai (3 vezes seguidas em cada missao)")
	r.check(generic, "f2 A1: grupos de troca sem falas de lugar/missao")
	for hero: String in ["tracker", "climber", "pilot"]:
		var keys := Ep01V3Dialogue.group_keys("switch.to_" + hero)
		var ok := keys.size() >= 2
		var last := ""
		for i in 12:
			var k := Ep01V3Dialogue.pick("switch.to_" + hero)
			ok = ok and k != last and k.begins_with("ep01.team.") and Loc.has_key(k)
			last = k
		r.check(ok, "f2 A1: sem fala da missao, chamado generico para %s sem repetir (%d variantes)" % [hero, keys.size()])


# ---------------------------------------------------------------- P1

## Distancia do ponto a caixa (global) de um VisualInstance3D (malha, decalque, multimalha).
func _dist_to(v: VisualInstance3D, p: Vector3) -> float:
	var box := v.global_transform * v.get_aabb()
	var c := Vector3(clampf(p.x, box.position.x, box.end.x), clampf(p.y, box.position.y, box.end.y), clampf(p.z, box.position.z, box.end.z))
	return c.distance_to(p)


func _visuals(n: Node, out: Array[VisualInstance3D]) -> void:
	if n is VisualInstance3D and (n as VisualInstance3D).is_visible_in_tree():
		out.append(n)
	for c in n.get_children():
		_visuals(c, out)


## Objetos de pista que a crianca ve: pecas da missao (Land), pecas soltas do mundo (props), barco. Nao contam o anel do
## guia (marca o alvo, nao e o objeto), a seta da ajuda, nem a malha estatica inteira da vila.
func _clue_visuals(main: Ep01V3Main) -> Array[VisualInstance3D]:
	var out: Array[VisualInstance3D] = []
	_visuals(main.land, out)
	for k: Variant in main.world.props:
		var n := main.world.props[k] as Node
		if n != null:
			_visuals(n, out)
	_visuals(main.boat, out)
	return out


## Pecas do kit da vila (barracas, caixotes, cercas...) pelo layout: [x, y, z, rumo, escala] e a caixa da malha do tipo.
func _kit_boxes(main: Ep01V3Main) -> Array[AABB]:
	var out: Array[AABB] = []
	var kit: Dictionary = main.world.layout.get("kit", {})
	for kind: String in kit:
		var mmi := main.world.get_node_or_null("Kit/" + kind) as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null or mmi.multimesh.mesh == null:
			continue
		var box := mmi.multimesh.mesh.get_aabb()
		for row: Variant in kit[kind]:
			var rr: Array = row
			var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(float(rr[3]))).scaled(Vector3.ONE * float(rr[4])),
				Vector3(float(rr[0]), float(rr[1]), float(rr[2])))
			out.append(xf * box)
	return out


func _dist_box(box: AABB, p: Vector3) -> float:
	var c := Vector3(clampf(p.x, box.position.x, box.end.x), clampf(p.y, box.position.y, box.end.y), clampf(p.z, box.position.z, box.end.z))
	return c.distance_to(p)


func _visible_targets() -> void:
	var main := await _new_main(&"M1")
	# Lugar das pistas do M1 (auditoria 2.1).
	var bench := main.world.marker(&"M1_BenchClue").global_position
	var moor := main.world.marker(&"M1_EmptyMooring").global_position
	var boot := main.land.clue_point(&"M1_BootPrint")
	var paws := Ep01V3Land.m1_paw_points()
	r.check(Vector2(boot.x - moor.x, boot.z - moor.z).length() < 3.0, "f2 M1: bota junto da amarra vazia (%.1f m)" % Vector2(boot.x - moor.x, boot.z - moor.z).length())
	r.check(Vector2(paws[0].x - bench.x, paws[0].z - bench.z).length() <= 2.0, "f2 M1: 1a pegadinha a <= 2 m da pata do cais")
	var boot_node := main.land.find_child("CaptainBoot", true, false) as Node3D
	r.check(boot_node != null and Vector2(boot_node.global_position.x - boot.x, boot_node.global_position.z - boot.z).length() < 0.05,
		"f2 M1: bota do capitao (props_v3) no lugar da pista")
	var decals := main.land.find_children("*", "Decal", true, false)
	var gaps_ok := true
	var big: Array[Vector3] = []
	for d in decals:
		if str(d.get_meta(&"piece_id", "")) == "decal_paw_big":
			big.append((d as Node3D).global_position)
	for i in big.size() - 1:
		var g := Vector2(big[i + 1].x - big[i].x, big[i + 1].z - big[i].z).length()
		if g < 1.2 or g > 2.1:
			gaps_ok = false
	r.check(big.size() >= 8 and gaps_ok, "f2 M1: %d pegadas grandes em trilha, uma a cada ~1,7 m" % big.size())
	var fails: Array[String] = []
	var checked := 0
	var kit := _kit_boxes(main)
	for m in main.missions:
		if m.id == &"M0":
			continue
		main.land.build(m.id)
		await r.frames(2)
		var vis := _clue_visuals(main)
		for s: Dictionary in m.steps:
			var p := main.land.clue_point(StringName(s["target"]))
			var best := INF
			for v in vis:
				best = minf(best, _dist_to(v, p))
			for b in kit:
				best = minf(best, _dist_box(b, p))
			checked += 1
			if best > float(REACH_EXCEPTIONS.get("%s.%s" % [m.id, s["id"]], CLUE_REACH)):
				fails.append("%s.%s %.1f m" % [m.id, s["id"], best])
	r.check(checked >= 21 and fails.is_empty(), "f2 P1: cada alvo de passo (%d) tem malha ou decalque a <= %.1f m %s" % [checked, CLUE_REACH, fails])
	await _free(main)


# ---------------------------------------------------------------- P2/P3/P6

func _cam_angle_to(main: Ep01V3Main, p: Vector3) -> float:
	var cam := main.camera_rig.camera
	var fwd := -cam.global_transform.basis.z
	return rad_to_deg(fwd.angle_to((p - cam.global_position).normalized()))


func _look_and_ring() -> void:
	var main := await _new_main(&"M1")
	var g := main.guide
	var hero := main.controlled_node as MemberActor
	await r.frames(3)
	r.check(g.looking and not hero.controlled, "f2 P2: no inicio do passo a camera vai ao alvo e o heroi espera")
	r.check(main.help.tier_times == Ep01V3Main.HELP_TIMES_FIRST, "f2 P6: 1o passo da missao com ajuda a 5/12/20 s")
	var target := g.look_target
	var best := 180.0
	var t := 0.0
	while t < Ep01V3Guide.LOOK_SECONDS - 0.1:
		await r.tree.process_frame
		t += r.tree.root.get_process_delta_time()
		best = minf(best, _cam_angle_to(main, target))
	r.check(best < 20.0, "f2 P2: a camera aponta para o alvo dentro do tempo (%.1f graus)" % best)
	await _wait(0.4)
	r.check(not g.looking and hero.controlled and main.camera_rig.target == hero and g.looks_done == 1,
		"f2 P2: depois de %.1f s a camera volta ao heroi e o controle volta" % Ep01V3Guide.LOOK_SECONDS)
	var ht := main.help_target()
	var ring := g.active_ring()
	r.check(ring != null and ht != null and Vector2(ring.global_position.x - ht.global_position.x, ring.global_position.z - ht.global_position.z).length() < 0.05,
		"f2 P3: anel sob o alvo ativo")
	# Passo seguinte: novo olhar, ajuda 8/16/28 s, e `interact` pula o olhar.
	main.notify_mission(&"paw_examined")
	main.land.refresh()
	await r.frames(3)
	r.check(g.looking and main.help.tier_times == Ep01V3Main.HELP_TIMES_NEXT, "f2 P2/P6: passo novo mostra o alvo; ajuda a 8/16/28 s")
	var ring2 := g.active_ring()
	r.check(ring2 != null and ring2.global_position.distance_to(main.land.clue_point(&"M1_BootPrint")) < 0.6, "f2 P3: o anel passa para a bota")
	var ev := InputEventAction.new()
	ev.action = &"interact"
	ev.pressed = true
	main._unhandled_input(ev)
	r.check(not g.looking and hero.controlled and main.camera_rig.target == hero, "f2 P2: interact pula o olhar e devolve o controle")
	# Ajuda nao corre durante o olhar.
	g.request_look()
	await r.frames(2)
	var idle := main.help.idle_time
	await r.frames(10)
	r.check(g.looking and is_equal_approx(main.help.idle_time, idle), "f2 P6: o tempo da ajuda para enquanto a camera mostra o alvo")
	g.skip_look()
	# P5: gesto da fala que aponta (fallback quando o clipe falta).
	var gest := Ep01V3Dialogue.gesture("ep01.dock.tracker.boot_steps")
	r.check(Ep01V3Guide.gesture_anim(hero, gest) != &"", "f2 P5: fala que aponta tem gesto que o Rastro sabe fazer")
	var pico := main.actors[&"climber"] as MemberActor
	var fake := {"anim": "nao_existe", "fallback": "wave", "target": "M2_ShedTop"}
	r.check(Ep01V3Guide.gesture_anim(pico, fake) == (&"wave" if pico.model.has_animation(&"wave") else &""), "f2 P5: clipe que falta usa o fallback")
	await _free(main)
	# Troca de heroi (M2 comeca com o Rastro e pede o Pico): depois do cartao e da pose, a camera mostra o alvo.
	main = await _new_main(&"M2")
	g = main.guide
	var t2 := 0.0
	while not main.hud.handoff_open and t2 < 3.0:
		await r.tree.process_frame
		t2 += r.tree.root.get_process_delta_time()
	var before := g.looks_done
	await _wait(Hud.HANDOFF_MIN_SECONDS + 0.1)
	main.hud._confirm_handoff()
	await _wait(Ep01V3Main.TEAM_POSE_SECONDS + 0.2)
	r.check(main.active_member == &"climber" and g.looks_done == before + 1 and g.looking,
		"f2 P2: depois da troca de heroi a camera mostra o alvo (%d -> %d)" % [before, g.looks_done])
	await _free(main)


func _look_reduced_motion() -> void:
	var main := await _new_main(&"M1")
	main.camera_rig.reduced_motion = true
	main.guide.skip_look()
	main.guide.request_look()
	await r.frames(2)
	var a := _cam_angle_to(main, main.guide.look_target)
	r.check(main.guide.looking and a < 20.0, "f2 P2: movimento reduzido corta direto para o alvo (%.1f graus em 2 quadros)" % a)
	await _free(main)


# ---------------------------------------------------------------- P4

func _trail_and_travel() -> void:
	var main := await _new_main(&"M3")
	var g := main.guide
	r.check(g.trail_count() >= 15, "f2 P4: margem -> chafariz com rastro de pegadinhas (%d)" % g.trail_count())
	var first := g.trail_root.get_child(0) as Node3D
	var last := g.trail_root.get_child(g.trail_count() - 1) as Node3D
	r.check(first.global_position.distance_to(Vector3(11.5, 0, 8.0)) < 1.0
		and Vector2(last.global_position.x + 24.28, last.global_position.z - 2.12).length() < 2.0,
		"f2 P4: o rastro sai da margem e chega a canaleta do chafariz")
	main.notify_mission(&"stream_followed")
	main.notify_mission(&"stream_followed")
	await r.frames(2)
	r.check(g.trail_mission == &"", "f2 P4: o rastro some quando a pista do chafariz e achada")
	await _free(main)
	for id: StringName in [&"M6", &"M7"]:
		var m := await _new_main(id)
		r.check(m.guide.trail_count() >= 5, "f2 P4: rastro ate o 1o alvo do %s (%d)" % [id, m.guide.trail_count()])
		await _free(m)


# ---------------------------------------------------------------- retomada

func _resume_all() -> void:
	for id: StringName in [&"M2", &"M3", &"M4", &"M5", &"M6", &"M7", &"M8"]:
		var main := await _new_main(id)
		for i in 30:
			await r.tree.physics_frame
		var ok := true
		for m: StringName in main.actors:
			var a := main.actors[m] as MemberActor
			if a.global_position.y < -0.3 or not a.is_on_floor():
				ok = false
		var cam_h := main.camera_rig.camera.global_position.y - main.controlled_node.global_position.y
		r.check(ok and cam_h > 0.5 and cam_h < 3.5, "f2 retomada %s: trio no chao e camera baixa (camera %.1f m acima)" % [id, cam_h])
		await _free(main)
