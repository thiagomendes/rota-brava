extends RefCounted
## RB-R1 G24a (obstaculo): correndo colado em caixotes, carroca, bancos e paredes da vila v3, com o desvio de obstaculo
## LIGADO, a camera nao vira primeira pessoa. Perto de cada marcador acha um ponto a 0,45 m de uma parede (camada 1),
## corre rente a ela para os dois lados com a camera girada 0,6 rad contra a parede (entrada real: Input Map) e, em
## cada passo de fisica depois de TRANSITION passos, mede:
##  - fracao do AABB visual do heroi dentro do quadro (pior entre 16:9 e 4:3; Godot mantem a altura, FOV vertical);
##  - distancia camera - peito do heroi.
## Exige >= FRAC_MIN do heroi no quadro e distancia >= DIST_MIN em todos os passos medidos.
## Mede estado; nao comprova o que se ve na tela (nem oclusao por objetos alem da parede).

const MARKERS: Array[StringName] = [&"M5_Crates", &"M4_Cart", &"M1_BenchClue", &"M8_FestaPlaza", &"M3_BallStop"]
const ASPECTS: Array[float] = [16.0 / 9.0, 4.0 / 3.0]
const FRAC_MIN := 0.9
const DIST_MIN := 1.9
const TRANSITION := 30
const RUN_TICKS := 90

var r
var main: Ep01V3Main
var _n := 0
var _bad_frac := 0
var _bad_dist := 0
var _min_frac := 1.0
var _min_dist := INF
var _worst: Array[String] = []


func run(runner) -> void:
	r = runner
	Ep01V3Main.start_mission = &""
	Ep01V3Main.save_path = ""
	main = (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	r.tree.root.add_child(main)
	r.tree.current_scene = main
	await r.frames(3)
	main.current = null
	main.set_controlled(main.actors[&"tracker"] as MemberActor)
	var walls := 0
	for mk in MARKERS:
		var m := main.world.marker(mk)
		if m == null:
			continue
		var spot: Variant = _wall_spot(m.global_position)
		if spot == null:
			continue
		walls += 1
		await _along(String(mk), spot[0] as Vector3, spot[1] as Vector3)
	_release()
	print("  medida obstaculo: %d paredes, %d passos medidos; heroi no quadro min %.0f%% (%d passos < %.0f%%); distancia min %.2f m (%d passos < %.1f m); piores %s" % [
		walls, _n, _min_frac * 100.0, _bad_frac, FRAC_MIN * 100.0, _min_dist, _bad_dist, DIST_MIN, _worst.slice(0, 4)])
	r.check(walls >= 4 and _n > 500, "obstaculo: %d paredes e %d passos medidos" % [walls, _n])
	r.check(_bad_frac == 0, "obstaculo: heroi >= %.0f%% no quadro correndo rente (min %.0f%%, %d de %d passos abaixo)" % [FRAC_MIN * 100.0, _min_frac * 100.0, _bad_frac, _n])
	r.check(_bad_dist == 0, "obstaculo: camera nunca a menos de %.1f m do heroi (min %.2f m, %d de %d passos abaixo)" % [DIST_MIN, _min_dist, _bad_dist, _n])
	main.queue_free()
	await r.frames(2)
	r.tree.current_scene = null


func _along(label: String, stand: Vector3, normal: Vector3) -> void:
	var hero := main.actors[&"tracker"] as MemberActor
	var rig := main.camera_rig
	var along := normal.cross(Vector3.UP)
	Input.action_press(&"run")
	for s: float in [1.0, -1.0]:
		hero.teleport(stand)
		rig.set_low_view(atan2(along.x * s, along.z * s) + PI + 0.6 * s)
		rig.follow(hero, true)
		for t in RUN_TICKS:
			_push(along * s - normal * 0.4)
			await r.tree.physics_frame
			if t >= TRANSITION:
				_measure("%s %+d t%d" % [label, int(s), t])
	Input.action_release(&"run")
	_release()


func _measure(label: String) -> void:
	var cam := main.camera_rig.camera
	var hero := main.controlled_node
	var d := cam.global_position.distance_to(hero.global_position + main.camera_rig.look_offset)
	var f := _hero_fraction(cam, hero)
	_n += 1
	_min_frac = minf(_min_frac, f)
	_min_dist = minf(_min_dist, d)
	if f < FRAC_MIN:
		_bad_frac += 1
	if d < DIST_MIN:
		_bad_dist += 1
	if f < FRAC_MIN or d < DIST_MIN:
		_worst.append("%s %.0f%% %.2fm" % [label, f * 100.0, d])


## Fracao (area) do retangulo projetado do AABB visual do heroi que cai dentro do quadro, no pior aspecto.
func _hero_fraction(cam: Camera3D, hero: Node3D) -> float:
	var box := AABB()
	var first := true
	for n in hero.find_children("*", "VisualInstance3D", true, false):
		var vi := n as VisualInstance3D
		if not vi.is_visible_in_tree():
			continue
		var b := vi.global_transform * vi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		return 0.0
	var inv := cam.global_transform.affine_inverse()
	var ty := tan(deg_to_rad(cam.fov) * 0.5)
	var worst := 1.0
	for aspect in ASPECTS:
		var mn := Vector2(INF, INF)
		var mx := Vector2(-INF, -INF)
		for i in 8:
			var p := inv * box.get_endpoint(i)
			if p.z > -0.05:
				return 0.0
			var q := Vector2(p.x / -p.z / (ty * aspect), p.y / -p.z / ty)
			mn = mn.min(q)
			mx = mx.max(q)
		var area := (mx.x - mn.x) * (mx.y - mn.y)
		var vis := (clampf(mx.x, -1, 1) - clampf(mn.x, -1, 1)) * (clampf(mx.y, -1, 1) - clampf(mn.y, -1, 1))
		worst = minf(worst, vis / maxf(area, 0.0001))
	return worst


## Ponto de chao a 0,45 m de uma parede (camada 1) perto de `c`: [posicao, normal da parede] (como test_camera_wall).
func _wall_spot(c: Vector3) -> Variant:
	var space := main.world.get_world_3d().direct_space_state
	for ring: float in [2.0, 3.5, 5.0]:
		for i in 12:
			var p := c + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 12.0) * ring
			var f := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 3, 0), p + Vector3(0, -3, 0), 1))
			if f.is_empty() or absf((f["position"] as Vector3).y - c.y) > 0.5:
				continue
			var g: Vector3 = f["position"]
			for k in 8:
				var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 8.0)
				var q := PhysicsRayQueryParameters3D.create(g + Vector3(0, 1.0, 0), g + Vector3(0, 1.0, 0) + dir * 1.5, 1)
				q.exclude = main.camera_rig.exclude
				var h := space.intersect_ray(q)
				if h.is_empty():
					continue
				var n: Vector3 = h["normal"]
				if absf(n.y) > 0.3:
					continue
				var hp: Vector3 = h["position"]
				var stand := Vector3(hp.x, g.y, hp.z) + Vector3(n.x, 0, n.z).normalized() * 0.45
				return [stand + Vector3(0, 0.05, 0), Vector3(n.x, 0, n.z).normalized()]
	return null


func _push(dir: Vector3) -> void:
	var local := Basis(Vector3.UP, -main.camera_rig.yaw) * dir.normalized()
	for pair: Array in [[&"move_right", local.x], [&"move_left", -local.x], [&"move_down", local.z], [&"move_up", -local.z]]:
		if float(pair[1]) > 0.01:
			Input.action_press(pair[0] as StringName, float(pair[1]))
		else:
			Input.action_release(pair[0] as StringName)


func _release() -> void:
	for a: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"run"]:
		Input.action_release(a)
