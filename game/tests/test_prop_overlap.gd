extends RefCounted
## RB-R1 G6: nenhuma peca de missao (M1-M8) atravessa outro objeto ou peca do cenario fixo alem de PropOverlap.TOL_PEN, flutua mais que
## TOL_FLOAT ou tem parte solta no proprio modelo; o mesmo para os aderecos do mundo a ate NEAR m dos marcadores da
## missao (o que a camera ve nela). Criterios em tests/prop_overlap.gd; lista completa da vila: bash tools/prop-overlap.sh.
## Geometrico: nao comprova render.

const MISSIONS: Array[StringName] = [&"M1", &"M2", &"M3", &"M4", &"M5", &"M6", &"M7", &"M8"]
const NEAR := 4.0

var r


func run(runner) -> void:
	r = runner
	Ep01V3Main.save_path = ""
	for m in MISSIONS:
		await _mission(m)
	Ep01V3Main.start_mission = &""


func _new_main(mission: StringName) -> Ep01V3Main:
	Ep01V3Main.start_mission = mission
	var main := (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	r.tree.root.add_child(main)
	r.tree.current_scene = main
	await r.frames(4)
	return main


func _free(main: Ep01V3Main, po: PropOverlap) -> void:
	if po != null:
		po.free_probes()
	main.queue_free()
	await r.frames(2)
	r.tree.current_scene = null
	r.tree.paused = false


func _scan(main: Ep01V3Main) -> PropOverlap:
	var po := PropOverlap.new()
	po.collect(main)
	for i in 3:
		await r.tree.physics_frame
	return po


## Pecas da missao + aderecos do kit/mundo a ate NEAR m de um marcador da missao ou de uma peca dela.
func _watched(main: Ep01V3Main, po: PropOverlap, mission: StringName) -> Array:
	var spots: Array[Vector3] = []
	for mk in main.world.markers_for(String(mission)):
		spots.append(mk.global_position)
	var ids := []
	for p in po.props:
		if (p["id"] as String).begins_with("mission:"):
			ids.append(p["id"])
			spots.append((p["aabb"] as AABB).get_center())
	for p in po.props:
		var c := (p["aabb"] as AABB).get_center()
		for s in spots:
			if Vector2(c.x - s.x, c.z - s.z).length() <= NEAR + (p["aabb"] as AABB).size.length() * 0.5:
				if not p["id"] in ids:
					ids.append(p["id"])
				break
	return ids


func _mission(m: StringName) -> void:
	var main := await _new_main(m)
	var po := await _scan(main)
	var ids := _watched(main, po, m)
	var missions_pieces := po.ids_with_prefix("mission:")
	var ov := po.overlaps(ids)
	ov.append_array(po.structure_hits(ids))
	var fl := po.floating(main.world.get_world_3d().direct_space_state, ids)
	var lp := po.loose_parts(ids)
	# M6 (barco na baia) e M8 (festa) nao montam peca com malha: so pontos de acao, icones e personagens.
	r.check(missions_pieces.size() > 0 or m in [&"M6", &"M8"], "G6 %s: pecas da missao entram na auditoria (%d)" % [m, missions_pieces.size()])
	r.check(ov.is_empty(), "G6 %s: 0 pares se atravessando > %.0f cm entre %d objetos vistos (%s)" % [m, PropOverlap.TOL_PEN * 100.0,
		ids.size(), _fmt(ov, "a", "depth")])
	r.check(fl.is_empty(), "G6 %s: 0 objetos flutuando > %.0f cm (%s)" % [m, PropOverlap.TOL_FLOAT * 100.0, _fmt(fl, "id", "gap")])
	r.check(lp.is_empty(), "G6 %s: 0 modelos com parte solta (%s)" % [m, _fmt(lp, "id", "gap")])
	po.free_probes()
	# Mesma cena (montar a vila de novo custa caro na suite): casos extras do M3 e do M4.
	if m == &"M3":
		await _ball_after_roll(main)
	elif m == &"M4":
		await _detects_old_stack(main)
	await _free(main, null)


## O teste tem dente: uma pilha como a antiga do carrinho (caixotes de 0,32 m a 0,22 m um do outro) e achada.
func _detects_old_stack(main: Ep01V3Main) -> void:
	var cargo := main.land.cart.get_node("Cargo") as Node3D
	cargo.position.y = 0.85
	for i in cargo.get_child_count():
		var c := cargo.get_child(i) as Node3D
		c.position = Vector3(0, 0.01 + i * 0.22, 0)
		c.scale = Vector3.ONE
	await r.frames(1)
	var po := await _scan(main)
	var ov := po.overlaps(po.ids_with_prefix("mission:"))
	var crate_pair := false
	for o: Dictionary in ov:
		if "Crate" in String(o["a"]) and "Crate" in String(o["b"]):
			crate_pair = true
	r.check(crate_pair, "G6: a pilha antiga de caixotes do M4 (um dentro do outro) e detectada (%s)" % _fmt(ov, "a", "depth"))
	po.free_probes()


## M3: a bola que rola ate as barracas para no chao (nem enterrada nem no ar).
func _ball_after_roll(main: Ep01V3Main) -> void:
	var ball := main.land.get("_ball") as Node3D
	ball.global_position = main.world.marker(&"M3_BallStop").global_position + Vector3(0, main.land.call("_ball_lift"), 0)
	await r.frames(1)
	var po := await _scan(main)
	var ids := po.ids_with_prefix("mission:")
	var fl := po.floating(main.world.get_world_3d().direct_space_state, ids)
	var ov := po.overlaps(ids)
	r.check(fl.is_empty() and ov.is_empty(), "G6 M3: bola parada nas barracas apoiada e sem atravessar nada (%s %s)" % [
		_fmt(fl, "id", "gap"), _fmt(ov, "a", "depth")])
	po.free_probes()


func _fmt(rows: Array, key: String, val: String) -> String:
	var parts: PackedStringArray = []
	for row: Dictionary in rows.slice(0, 6):
		var extra := (" x " + String(row["b"])) if row.has("b") else ""
		parts.append("%s%s %.1f cm" % [row[key], extra, float(row[val]) * 100.0])
	return ", ".join(parts)
