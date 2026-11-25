extends RefCounted
## Mundo jogavel da vila v2.1 (RB-R1 E3): a cena carrega, tem colisao no chao, limites de agua e de mapa, marcadores
## M0-M8 (raycast para baixo em cada marcador de terra acha chao na altura do marcador; os de agua ficam sobre a agua),
## pecas soltas das missoes, barco v2 jogavel e decalques. Nao comprova visual nem desempenho (ver captures/e3/).
## E3b: uma capsula de heroi (raio 0,35, altura 1,5, sem step-up, mesma do MemberActor) anda de verdade com
## move_and_slide pela passagem praca -> rua do mercado e pela subida do promontorio ate a base da escada do farol;
## a passagem tem 1,6 m livres (caixa de 1,6 m varrida com cast_motion); rampas de acesso (camada 5) desligadas por
## padrao, e ligadas levam a capsula ao embasamento do farol e a borda do chafariz.

const WORLD := "res://worlds/village_v3/village_world.tscn"
const BOAT := "res://worlds/village_v3/boat_wv2.tscn"
const PROPS := "res://assets/models/environment_v2/wv3_props.glb"
const DECALS := ["paw", "paw_wet", "feather", "scale"]

var r


func run(runner) -> void:
	r = runner
	await _test_collision_and_markers()
	await _test_hero_paths()
	await _test_visual_states()
	_test_props()
	_test_boat()
	_test_decals()


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	return space.intersect_ray(q)


func _test_collision_and_markers() -> void:
	var packed := load(WORLD) as PackedScene
	r.check(packed != null, "village: cena do mundo jogavel carrega")
	if packed == null:
		return
	var w := packed.instantiate() as VillageWorld
	w.build_on_ready = false   # so colisao e marcadores aqui (o visual e testado abaixo)
	r.tree.root.add_child(w)
	await r.tree.physics_frame
	await r.tree.physics_frame
	var bodies := {}
	for b in w.find_children("*", "StaticBody3D", true, false):
		var sb := b as StaticBody3D
		bodies[String(sb.name)] = sb.get_child_count()
		var want_layer := VillageWorld.ACCESS_RAMPS_LAYER if String(sb.name) == "AccessRamps" else 1
		r.check(sb.collision_layer == want_layer and sb.collision_mask == 0, "village: %s na camada %d, mascara 0" % [sb.name, want_layer])
	r.check(int(bodies.get("Ground", 0)) >= 10, "village: chao com calcamento, cais, terraco e mapas de altura (%d)" % int(bodies.get("Ground", 0)))
	r.check(int(bodies.get("Structures", 0)) >= 50, "village: casas, galpoes, chafariz e farol com colisao (%d)" % int(bodies.get("Structures", 0)))
	r.check(int(bodies.get("Props", 0)) >= 100, "village: aderecos grandes com colisao (%d)" % int(bodies.get("Props", 0)))
	r.check(int(bodies.get("WaterLimits", 0)) >= 10, "village: paredes na beira d'agua (%d)" % int(bodies.get("WaterLimits", 0)))
	r.check(int(bodies.get("MapBounds", 0)) == 4, "village: 4 limites de mapa")
	var space := w.get_world_3d().direct_space_state
	var ms := w.get_node("Markers").get_children()
	r.check(ms.size() >= 40, "village: marcadores das missoes (%d)" % ms.size())
	for mis in ["M0", "M1", "M2", "M3", "M4", "M5", "M6", "M7", "M8"]:
		r.check(w.markers_for(mis).size() >= 1, "village: marcador da missao %s" % mis)
	var bad: Array = []
	var land := 0
	for n in ms:
		var m := n as Marker3D
		var p := m.global_position
		if bool(m.get_meta("water", false)):
			var hw := _ray(space, p + Vector3(0, 1.5, 0), p + Vector3(0, -3.0, 0))
			if not hw.is_empty() and String((hw.collider as Node).name) == "Ground" and (hw.position as Vector3).y > -0.3:
				bad.append(String(m.name) + "(agua com chao seco)")
			continue
		if String(m.name) == "M7_LanternPivot":
			continue
		land += 1
		var h := _ray(space, p + Vector3(0, 1.0, 0), p + Vector3(0, -3.0, 0))
		if h.is_empty():
			bad.append(String(m.name) + "(sem chao)")
		elif absf((h.position as Vector3).y - p.y) > 0.3:
			bad.append("%s(chao %.2f vs %.2f)" % [m.name, (h.position as Vector3).y, p.y])
	r.check(land >= 30, "village: marcadores em terra (%d)" % land)
	r.check(bad.is_empty(), "village: raycast para baixo em cada marcador acha chao na altura certa %s" % [bad])
	# beira d'agua: andar do cais de pedra para a bacia bate numa parede invisivel antes de cair
	var hq := _ray(space, Vector3(0, 0.8, -15.0), Vector3(0, 0.8, -10.0))
	r.check(not hq.is_empty() and String((hq.collider as Node).name) == "WaterLimits", "village: borda do cais norte segura (agua)")
	var hd := _ray(space, Vector3(0, 0.8, 0.0), Vector3(12.0, 0.8, 0.0))
	r.check(not hd.is_empty() and (hd.position as Vector3).x < 9.0, "village: borda leste do cais de madeira segura")
	var hb := _ray(space, Vector3(-20, 3.0, 0.0), Vector3(-60, 3.0, 0.0))
	r.check(not hb.is_empty(), "village: limite oeste do mapa")
	w.queue_free()
	await r.frames(2)


## Anda uma capsula de heroi pelos pontos (x, z) com move_and_slide (3,2 m/s, gravidade 20, como o MemberActor).
## Devolve {"ok": chegou ao ultimo ponto, "pos": posicao final, "stuck_at": ponto onde parou de avancar}.
func _walk(w: Node3D, from: Vector3, pts: Array, mask: int = 1) -> Dictionary:
	var body := CharacterBody3D.new()
	body.collision_layer = 0
	body.collision_mask = mask
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.5
	cs.shape = cap
	cs.position.y = 0.75
	body.add_child(cs)
	w.add_child(body)
	body.global_position = from
	await r.tree.physics_frame
	var dt := 1.0 / 60.0
	var out := {"ok": false, "pos": from, "stuck_at": Vector3.INF}
	for p: Vector2 in pts:
		var best := INF
		var still := 0
		for i in 1800:
			var d := Vector2(p.x - body.global_position.x, p.y - body.global_position.z)
			if d.length() < 0.25:
				break
			if d.length() < best - 0.01:
				best = d.length()
				still = 0
			else:
				still += 1
			if still > 90:
				out["stuck_at"] = body.global_position
				break
			var v := d.normalized() * 3.2
			body.velocity.x = v.x
			body.velocity.z = v.y
			body.velocity.y = -0.5 if body.is_on_floor() else body.velocity.y - 20.0 * dt
			body.move_and_slide()
		if out["stuck_at"] != Vector3.INF:
			break
	out["pos"] = body.global_position
	out["ok"] = out["stuck_at"] == Vector3.INF
	body.queue_free()
	return out


func _test_hero_paths() -> void:
	var w := (load(WORLD) as PackedScene).instantiate() as VillageWorld
	w.build_on_ready = false
	r.tree.root.add_child(w)
	await r.tree.physics_frame
	await r.tree.physics_frame
	var space := w.get_world_3d().direct_space_state
	# 1. passagem praca -> rua do mercado (entre os caixotes do Pico e a beira d'agua, perto de (-15; -14))
	var box := BoxShape3D.new()
	box.size = Vector3(0.1, 1.2, 1.6)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.collision_mask = 1
	q.transform = Transform3D(Basis(), Vector3(-16.0, 0.7, -14.2))
	q.motion = Vector3(3.0, 0.0, 0.0)
	var cm := space.cast_motion(q)
	r.check(cm.size() == 2 and cm[0] >= 1.0, "village E3b: faixa de 1,6 m livres na passagem praca -> rua (x -16 a -13, z -15,0 a -13,4) %s" % [cm])
	var a := await _walk(w, Vector3(-16.5, 0.05, -10.0), [Vector2(-14.85, -12.8), Vector2(-14.7, -13.9), Vector2(-11.5, -14.3)])
	r.check(a["ok"], "village E3b: capsula (r 0,35) passa da praca para a rua do mercado (parou em %s)" % [a["stuck_at"]])
	var crates := w.marker(&"M5_Crates")
	var awning := w.marker(&"M5_Awning")
	r.check(crates != null and awning != null and Vector2(crates.global_position.x - awning.global_position.x,
			crates.global_position.z - awning.global_position.z).length() < 2.0,
			"village E3b: caixotes do Pico continuam ao lado do toldo (subida do M5 mantida)")
	# 2. subida do promontorio ate a base da escada do farol (e ramal ate a lente)
	var base := Vector2(29.45, -20.2)
	var b := await _walk(w, Vector3(14.5, 0.05, -16.9), [Vector2(18.4, -16.9), Vector2(22.8, -17.3), Vector2(26.6, -19.5),
			Vector2(28.0, -19.75), base])
	r.check(b["ok"], "village E3b: capsula sobe da rua (perto de (20; -16)) ate a base da escada do farol (parou em %s)" % [b["stuck_at"]])
	var c := await _walk(w, Vector3(18.4, 0.05, -16.9), [Vector2(22.8, -17.3), Vector2(24.4, -18.3), Vector2(25.8, -21.3)])
	r.check(c["ok"], "village E3b: capsula chega a lente caida (M7) (parou em %s)" % [c["stuck_at"]])
	# 3. degraus sem step-up: sem rampa o heroi para; com as rampas de acesso ligadas, sobe
	r.check(not w.access_ramps_enabled(), "village E3b: rampas de acesso desligadas por padrao (camada 5)")
	var stair := w.marker(&"M7_StairBase").global_position
	var fstep := w.marker(&"M3_FountainStep_1").global_position
	var k0 := await _walk(w, Vector3(-3.0, 0.1, 5.5), [Vector2(-3.0, 1.5)])
	r.check(k0["ok"] and absf((k0["pos"] as Vector3).y) < 0.06, "village E3b: sem rampa, capsula volta da margem para o cais (borda de 0,12 m)")
	var d0 := await _walk(w, Vector3(base.x, 2.4, base.y), [Vector2(stair.x, stair.z)])
	r.check(not d0["ok"] and (d0["pos"] as Vector3).y < 2.6, "village E3b: sem rampa, a capsula nao sobe o degrau do farol (%.2f m)" % (d0["pos"] as Vector3).y)
	w.set_access_ramps(true)
	await r.tree.physics_frame
	var top := Vector2(31.0 + 2.6 * cos(deg_to_rad(122.0)), -24.0 + 2.6 * sin(deg_to_rad(122.0)))   # no embasamento, fora do patamar 1
	var d1 := await _walk(w, Vector3(28.0, 2.4, -19.75), [Vector2(29.3, -19.9), top])
	r.check(d1["ok"] and absf((d1["pos"] as Vector3).y - 3.0) < 0.15, "village E3b: com rampa, capsula chega ao embasamento do farol (%s, parou em %s)" % [d1["pos"], d1["stuck_at"]])
	var f1 := await _walk(w, Vector3(-18.6, 0.05, 5.0), [Vector2(fstep.x, fstep.z)])
	r.check(f1["ok"] and absf((f1["pos"] as Vector3).y - 0.5) < 0.12, "village E3b: com rampa, capsula sobe a borda do chafariz (y %.2f)" % (f1["pos"] as Vector3).y)
	w.set_access_ramps(false)
	r.check(not w.access_ramps_enabled(), "village E3b: rampas de acesso desligam de novo")
	w.queue_free()
	await r.frames(2)


func _test_visual_states() -> void:
	var w := (load(WORLD) as PackedScene).instantiate() as VillageWorld
	r.tree.root.add_child(w)
	await r.frames(2)
	r.check(w.get_node_or_null("Static") != null and w.get_node_or_null("Kit") != null, "village: visual da vila montado")
	r.check(w.lantern != null and w.lantern_beam != null, "village: lanterna giratoria do farol com feixe")
	r.check(w.find_children("*", "Camera3D", true, false).is_empty(), "village: sem camera da vitrine")
	r.check(w.festa_lights.size() >= 10 and not w.festa_lights[0].visible, "village: luzes da festa criadas e apagadas de dia")
	w.set_festival(true)
	r.check(w.night and w.festa_lights[0].visible and w.lantern_beam.visible, "village: noite de festa acende lanternas e feixe")
	w.set_festival(false)
	w.set_night(false)
	w.queue_free()
	await r.frames(2)


func _test_props() -> void:
	var s := (load(PROPS) as PackedScene).instantiate()
	var names: Array = []
	for n in s.find_children("wv3_*", "Node3D", true, false):
		names.append(String(n.name))
	for k in ["wv3_lantern", "wv3_lantern_beam", "wv3_dinghy", "wv3_buoy_a", "wv3_buoy_b", "wv3_festa_boat_1", "wv3_festa_boat_2",
			"wv3_festa_boat_3", "wv3_festa_boat_4", "wv3_festa_lanterns", "wv3_lens"]:
		r.check(names.has(k), "village: peca solta %s" % k)
	var lan := s.find_child("wv3_lantern", true, false) as Node3D
	r.check(lan != null and absf(lan.position.y - 16.75) < 0.05, "village: pivo da lanterna no piso da sala do farol")
	s.free()


func _test_boat() -> void:
	var ps := load(BOAT) as PackedScene
	r.check(ps != null, "village: barco v2 jogavel carrega")
	if ps == null:
		return
	var b := ps.instantiate()
	for k in ["WheelPoint", "HornPoint", "DeckPoint", "BenchMark", "PivotMark", "PawMark", "RopeBow", "RopeSternL", "RopeSternR"]:
		r.check(b.find_child(k, true, false) != null, "village: barco v2 tem %s" % k)
	var body := b.get_node_or_null("Body") as StaticBody3D
	r.check(body != null and body.get_child_count() >= 1, "village: barco v2 com colisao (Body)")
	r.check(b.get_node_or_null("BowLight") is OmniLight3D, "village: barco v2 com luz de proa")
	b.free()


func _test_decals() -> void:
	for k: String in DECALS:
		var ps := load("res://worlds/village_v3/decals/decal_%s.tscn" % k) as PackedScene
		var d := ps.instantiate() if ps != null else null
		r.check(d is Decal and (d as Decal).texture_albedo != null, "village: decalque %s" % k)
		if d != null:
			d.free()
