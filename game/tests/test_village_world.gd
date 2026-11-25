extends RefCounted
## Mundo jogavel da vila v2.1 (RB-R1 E3): a cena carrega, tem colisao no chao, limites de agua e de mapa, marcadores
## M0-M8 (raycast para baixo em cada marcador de terra acha chao na altura do marcador; os de agua ficam sobre a agua),
## pecas soltas das missoes, barco v2 jogavel e decalques. Nao comprova visual nem desempenho (ver captures/e3/).

const WORLD := "res://worlds/village_v3/village_world.tscn"
const BOAT := "res://worlds/village_v3/boat_wv2.tscn"
const PROPS := "res://assets/models/environment_v2/wv3_props.glb"
const DECALS := ["paw", "paw_wet", "feather", "scale"]

var r


func run(runner) -> void:
	r = runner
	await _test_collision_and_markers()
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
		r.check(sb.collision_layer == 1 and sb.collision_mask == 0, "village: %s na camada 1, mascara 0" % sb.name)
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
