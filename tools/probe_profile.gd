extends SceneTree
## Perfil de altura da colisao da vila v3 ao longo de uma linha (RB-R1 E3b): lista os degraus (salto de altura entre
## amostras de 2 cm) e a inclinacao maxima. Serve para medir degraus e patamares que o heroi sem step-up nao sobe.
## Uso: bash tools/godot.sh --headless --path game --script res://../tools/probe_profile.gd -- x0,z0 x1,z1 [x2,z2 ...] [/ x,z x,z ...]
## ("/" separa linhas independentes)
## Saida: "PERFIL de (..) a (..)" e uma linha por degrau >= 0,04 m: posicao, altura antes/depois, colisor do topo.

const SCENE := "res://worlds/village_v3/village_collision.tscn"
const STEP := 0.02


func _initialize() -> void:
	var lines: Array = [[]]
	for a in OS.get_cmdline_user_args():
		if a == "/":
			lines.append([])
			continue
		var f := a.split_floats(",")
		if f.size() == 2:
			(lines[-1] as Array).append(Vector2(f[0], f[1]))
	var w := (load(SCENE) as PackedScene).instantiate()
	root.add_child(w)
	await physics_frame
	await physics_frame
	var space := (w as Node3D).get_world_3d().direct_space_state
	for pts: Array in lines:
		_line(space, pts)
	quit(0)


func _line(space: PhysicsDirectSpaceState3D, pts: Array) -> void:
	for k in range(pts.size() - 1):
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[k + 1]
		var n := int(a.distance_to(b) / STEP)
		print("PERFIL de (%.2f; %.2f) a (%.2f; %.2f)" % [a.x, a.y, b.x, b.y])
		var prev := NAN
		var prev_name := ""
		var max_slope := 0.0
		for i in n + 1:
			var p := a.lerp(b, float(i) / n)
			var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 30, p.y), Vector3(p.x, -5, p.y), 1)
			var h := space.intersect_ray(q)
			if h.is_empty():
				continue
			var y := (h.position as Vector3).y
			var nm := "%s/%s" % [(h.collider as Node).name, _shape_name(h)]
			var nrm := h.normal as Vector3
			max_slope = maxf(max_slope, rad_to_deg(acos(clampf(nrm.y, -1.0, 1.0))) if absf(y - prev) < 0.04 or is_nan(prev) else max_slope)
			if not is_nan(prev) and absf(y - prev) >= 0.04:
				print("  DEGRAU em (%.2f; %.2f): %.2f -> %.2f (%+.2f m) [%s -> %s]" % [p.x, p.y, prev, y, y - prev, prev_name, nm])
			prev = y
			prev_name = nm
		print("  inclinacao maxima fora dos degraus: %.1f graus; altura final %.2f" % [max_slope, prev])


func _shape_name(hit: Dictionary) -> String:
	var body := hit.collider as CollisionObject3D
	var owner_id := body.shape_find_owner(int(hit.shape))
	var o := body.shape_owner_get_owner(owner_id) as Node
	return String(o.name) if o != null else "?"
