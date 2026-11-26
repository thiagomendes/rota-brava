extends SceneTree
## RB-R1 G6: relatorio de interpenetracao/flutuacao de props na vila v3 com as pecas de cada missao (M1-M8) montadas.
## Uso: bash tools/prop-overlap.sh [--missions=M4,M5] [--json=<caminho absoluto>]
## Criterios em tests/prop_overlap.gd. Achados do kit e das pecas do mundo se repetem em todas as missoes: saem uma vez.

const MISSIONS: Array[StringName] = [&"M1", &"M2", &"M3", &"M4", &"M5", &"M6", &"M7", &"M8"]


func _initialize() -> void:
	_run.call_deferred()


func _arg(flag: String) -> String:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with(flag + "="):
			return a.trim_prefix(flag + "=")
	return ""


func _run() -> void:
	var missions := MISSIONS
	if _arg("--missions") != "":
		missions = []
		for m in _arg("--missions").split(","):
			missions.append(StringName(m))
	Ep01V3Main.save_path = ""
	Ep01V3Cutscene.enabled = false
	var seen_o := {}
	var seen_f := {}
	var seen_l := {}
	var all_l: Array = []
	var all_o: Array = []
	var all_f: Array = []
	var total_props := 0
	for m in missions:
		var t0 := Time.get_ticks_msec()
		Ep01V3Main.start_mission = m
		var main := (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
		root.add_child(main)
		current_scene = main
		for i in 4:
			await process_frame
		var po := PropOverlap.new()
		po.collect(main)
		for i in 3:
			await physics_frame
		var ov := po.overlaps([], m != missions[0])
		# Cenario fixo x props: o kit e o cenario nao mudam entre missoes; da 2a em diante so as pecas da missao/mundo.
		ov.append_array(po.structure_hits([] if m == missions[0] else po.ids_with_prefix("mission:") + po.ids_with_prefix("world:")
			+ po.ids_with_prefix("boat")))
		var fl := po.floating(main.world.get_world_3d().direct_space_state)
		var lp := po.loose_parts()
		for l: Dictionary in lp:
			if not seen_l.has(l["id"]):
				seen_l[l["id"]] = true
				l["mission"] = String(m)
				all_l.append(l)
		total_props = maxi(total_props, po.props.size())
		var new_o := 0
		var new_f := 0
		for o: Dictionary in ov:
			var key := "%s|%s" % [o["a"], o["b"]]
			if seen_o.has(key):
				continue
			seen_o[key] = true
			o["mission"] = String(m)
			all_o.append(o)
			new_o += 1
		for f: Dictionary in fl:
			if seen_f.has(f["id"]):
				continue
			seen_f[f["id"]] = true
			f["mission"] = String(m)
			all_f.append(f)
			new_f += 1
		print("[G6] %s: %d props, %d pares (%d novos), %d flutuando (%d novos), %d ms" % [m, po.props.size(), ov.size(), new_o,
			fl.size(), new_f, Time.get_ticks_msec() - t0])
		po.free_probes()
		main.queue_free()
		for i in 2:
			await process_frame
		current_scene = null
		paused = false
	print("[G6] INTERPENETRACAO (props entre si e com pecas do cenario fixo) > %.0f cm: %d pares" % [PropOverlap.TOL_PEN * 100.0, all_o.size()])
	for o: Dictionary in all_o:
		var at: Vector3 = o["at"]
		print("[G6]   %-6.1f cm  %s  x  %s  (%d pts) em (%.2f, %.2f, %.2f) [%s]" % [o["depth"] * 100.0, o["a"], o["b"], o["points"],
			at.x, at.y, at.z, o["mission"]])
	print("[G6] FLUTUANDO > %.0f cm: %d props" % [PropOverlap.TOL_FLOAT * 100.0, all_f.size()])
	for f: Dictionary in all_f:
		var at2: Vector3 = f["at"]
		print("[G6]   %-6.1f cm  %s  em (%.2f, %.2f, %.2f) [%s]" % [f["gap"] * 100.0, f["id"], at2.x, at2.y, at2.z, f["mission"]])
	print("[G6] PARTES SOLTAS NO MODELO > %.0f cm: %d modelos" % [PropOverlap.TOL_FLOAT * 100.0, all_l.size()])
	for l: Dictionary in all_l:
		var at5: Vector3 = l["at"]
		print("[G6]   %-6s cm  %s  %d parte(s)  em (%.2f, %.2f, %.2f) [%s]" % ["inf" if is_inf(l["gap"]) else "%.1f" % (l["gap"] * 100.0),
			l["id"], l["parts"], at5.x, at5.y, at5.z, l["mission"]])
	print("[G6] TOTAL: %d pares, %d flutuando, %d modelos com partes soltas" % [all_o.size(), all_f.size(), all_l.size()])
	var path := _arg("--json")
	if path != "":
		var rows_o := []
		for o: Dictionary in all_o:
			var at3: Vector3 = o["at"]
			rows_o.append({"a": o["a"], "b": o["b"], "depth_cm": snappedf(o["depth"] * 100.0, 0.1), "mission": o["mission"],
				"at": [snappedf(at3.x, 0.01), snappedf(at3.y, 0.01), snappedf(at3.z, 0.01)]})
		var rows_f := []
		for f: Dictionary in all_f:
			var at4: Vector3 = f["at"]
			rows_f.append({"id": f["id"], "gap_cm": snappedf(f["gap"] * 100.0, 0.1), "mission": f["mission"],
				"at": [snappedf(at4.x, 0.01), snappedf(at4.y, 0.01), snappedf(at4.z, 0.01)]})
		var fa := FileAccess.open(path, FileAccess.WRITE)
		var rows_l := []
		for l: Dictionary in all_l:
			var at6: Vector3 = l["at"]
			rows_l.append({"id": l["id"], "parts": l["parts"], "gap_cm": -1.0 if is_inf(l["gap"]) else snappedf(l["gap"] * 100.0, 0.1),
				"mission": l["mission"], "at": [snappedf(at6.x, 0.01), snappedf(at6.y, 0.01), snappedf(at6.z, 0.01)]})
		fa.store_string(JSON.stringify({"props": total_props, "overlaps": rows_o, "floating": rows_f, "loose_parts": rows_l}, " ") + "\n")
		fa.close()
		print("[G6] json: ", path)
	quit(0)
