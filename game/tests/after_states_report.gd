extends SceneTree
## RB-R1 G18 (art3d): auditoria dos estados "depois da acao" das missoes com o metodo do prop_overlap (G6). Relatorio,
## nao teste. Uso: bash tools/godot.sh --headless --path game --script res://tests/after_states_report.gd

var main: Ep01V3Main


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	Ep01V3Main.save_path = ""
	Ep01V3Cutscene.enabled = false
	await _m4()
	await _m5()
	await _m6()
	await _m7()
	print("[AFTER] fim")
	quit()


func _open(m: StringName) -> void:
	if main != null:
		main.queue_free()
		await _wait(0.2)
	Ep01V3Main.start_mission = m
	main = (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	root.add_child(main)
	current_scene = main
	await _wait(0.5)


func _wait(s: float) -> void:
	var t := 0.0
	while t < s:
		await process_frame
		t += root.get_process_delta_time()


func _report(tag: String, ids: Array) -> void:
	var po := PropOverlap.new()
	po.collect(main)
	for i in 3:
		await physics_frame
	print("[AFTER] %s missao: %s" % [tag, po.ids_with_prefix("mission:")])
	var want: Array = []
	for p in po.props:
		for k: String in ids:
			if k in String(p["id"]):
				want.append(p["id"])
	var ov := po.overlaps(want)
	ov.append_array(po.structure_hits(want))
	var fl := po.floating(main.world.get_world_3d().direct_space_state, want)
	print("[AFTER] %s: %d objetos %s" % [tag, want.size(), want])
	for o: Dictionary in ov:
		print("[AFTER] %s   atravessa: %s x %s %.1f cm em %s" % [tag, o["a"], o["b"], float(o["depth"]) * 100.0, o["at"]])
	for f: Dictionary in fl:
		print("[AFTER] %s   flutua: %s %.1f cm" % [tag, f["id"], float(f["gap"]) * 100.0])
	for p in po.props:
		if p["id"] in want:
			var b: AABB = p["aabb"]
			print("[AFTER] %s   %s base y=%.3f centro %s" % [tag, p["id"], b.position.y, b.get_center()])
	po.free_probes()


## M4: os 3 caixotes entregues nas barracas; e o que sobra quando o M5 monta.
func _m4() -> void:
	await _open(&"M4")
	var land := main.land
	main.current.notify(&"icons_read", &"tracker")
	main.active_member = &"pilot"
	main.current.set_active_hero(&"pilot")
	land.call("_set_busy", true)
	for st: StringName in Ep01V3Land.CARGO_ORDER:
		land.call("_deliver", st)
		await _wait(0.8)
	await _report("M4 entregue", ["Crate", "@Node3D", "Cart", "stall"])
	land.call("_set_busy", false)
	await _wait(1.5)
	var crates := 0
	for n in land.find_children("*Crate*", "", true, false):
		crates += 1
	print("[AFTER] M4 depois (missao %s): caixotes no mundo = %d" % [land.mission_id, crates])


## M5: peixe baixado na corda ate a rua (ponto final do voo em `_recover_fish`).
func _m5() -> void:
	await _open(&"M5")
	var land := main.land
	var gull := land.get("_gull") as Node3D
	var fish := gull.get_node_or_null("Fish") as Node3D if gull != null else null
	if fish == null and gull != null:
		fish = gull.find_child("Fish", true, false) as Node3D
	if fish == null:
		print("[AFTER] M5 sem peixe")
		return
	var down: Vector3 = (land.points[&"CratesBase"] as Vector3) + Vector3(0.6, 0.1, 0.4)
	fish.get_parent().remove_child(fish)
	land.get("_root").add_child(fish)
	fish.name = "Fish"
	fish.visible = true
	fish.global_position = down
	await _wait(0.3)
	var low := INF
	for mi: Node in fish.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for v in m.mesh.get_faces():
			low = minf(low, (m.global_transform * v).y)
	var q := PhysicsRayQueryParameters3D.create(down + Vector3(0, 1, 0), down - Vector3(0, 3, 0), 1)
	var hit := main.world.get_world_3d().direct_space_state.intersect_ray(q)
	print("[AFTER] M5 peixe no fim da corda: ponto mais baixo y=%.3f, chao y=%.3f (folga %.1f cm)" % [low,
		(hit.position as Vector3).y if not hit.is_empty() else NAN, (low - (hit.position as Vector3).y) * 100.0 if not hit.is_empty() else NAN])
	await _report("M5 peixe", ["Fish"])


## M6: bote rebocado e amarrado no cais (estado do fim do reboque: barco no ancoradouro, bote em DINGHY_DOCKED).
func _m6() -> void:
	await _open(&"M7")
	var berth := main.world.marker(&"M6_BoatStart")
	main.boat.place(berth.global_position, berth.global_rotation.y)
	await _wait(0.3)
	await _report("M6 rebocado", ["wv3_dinghy", "boat"])


## M7: lente devolvida a lanterna (depois do resgate): a lente do capim some; ha lente na lanterna?
func _m7() -> void:
	await _open(&"M7")
	var lens := main.world.props.get("wv3_lens") as Node3D
	var lantern := main.world.lantern
	print("[AFTER] M7 lente no capim visivel=%s em %s; lanterna %s" % [lens.visible if lens else false,
		lens.global_position if lens else Vector3.ZERO, lantern.global_position if lantern else Vector3.ZERO])
	if lantern != null:
		for mi: Node in lantern.find_children("*", "MeshInstance3D", true, false):
			print("[AFTER] M7   malha da lanterna: %s" % mi.name)
	await _report("M7 lente no capim", ["wv3_lens", "wv3_lantern"])
