extends RefCounted
## RB-R1 (revisao R1): o braco com mola nao pode deixar a camera dentro de parede/copa. Herói encostado em paredes da
## vila; gira a camera com `cam_left`/`cam_right` (Input Map) e corre rente a parede. Em todo passo de fisica:
##  - esfera de 0,1 m na posicao da camera nao toca a camada de obstaculo da camera (`collision_mask`, sem `exclude`);
##  - (fora os passos com o braco no minimo de 0,9 m, que o rig aceita de proposito e sao so contados)
##  - raio da mira ate a camera sem obstaculo; camera fora das copas (`occluders`);
##  - G24a2: com `occlusion_fade`, obstaculo entre mira e camera so vale se estiver no pontilhado (`occlusion_covers`).
## Mede estado; nao comprova o que se ve na tela.

const CAM_RADIUS := 0.1
const MARKERS: Array[StringName] = [&"M5_Crates", &"M4_Cart", &"M1_BenchClue", &"M8_FestaPlaza", &"M3_BallStop"]

var r
var main: Ep01V3Main
var _ticks := 0
var _at_min := 0
var _faded := 0
var _blocked_for := 0.0
var _bad: Array[String] = []
var _sphere := SphereShape3D.new()


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
	_sphere.radius = CAM_RADIUS
	var walls := 0
	for mk in MARKERS:
		var m := main.world.marker(mk)
		if m == null:
			continue
		var spot: Variant = _wall_spot(m.global_position)
		if spot == null:
			continue
		walls += 1
		await _at_wall(String(mk), spot[0] as Vector3, spot[1] as Vector3)
	_release()
	print("  medida parede: %d paredes, %d passos medidos, %d com camera dentro/atras de obstaculo %s; %d no braco minimo; %d atras com o oclusor em pontilhado" % [walls, _ticks, _bad.size(), _bad.slice(0, 4), _at_min, _faded])
	r.check(walls >= 3, "parede: %d paredes da vila encontradas" % walls)
	r.check(_bad.is_empty(), "parede: camera nunca dentro nem atras de obstaculo (%d de %d passos %s)" % [_bad.size(), _ticks, _bad.slice(0, 3)])
	main.queue_free()
	await r.frames(2)
	r.tree.current_scene = null


func _release() -> void:
	for a: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"run", &"cam_left", &"cam_right"]:
		Input.action_release(a)


## Ponto de chao a 0,45 m de uma parede (camada 1) perto de `c`: [posicao, normal da parede].
func _wall_spot(c: Vector3) -> Variant:
	var space := main.world.get_world_3d().direct_space_state
	for ring: float in [2.0, 3.5, 5.0]:
		for i in 12:
			var p := c + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 12.0) * ring
			var down := PhysicsRayQueryParameters3D.create(p + Vector3(0, 3, 0), p + Vector3(0, -3, 0), 1)
			var f := space.intersect_ray(down)
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


func _at_wall(label: String, stand: Vector3, normal: Vector3) -> void:
	var lead := main.actors[&"tracker"] as MemberActor
	var rig := main.camera_rig
	lead.teleport(stand)
	# Comeca com a camera de costas para a parede livre e gira contra ela.
	rig.set_low_view(atan2(normal.x, normal.z))
	rig.follow(lead, true)
	for t in 20:
		await _tick(label + " assenta")
	for act: StringName in [&"cam_left", &"cam_right"]:
		Input.action_press(act)
		for t in 150:
			await _tick(label + " " + String(act))
		Input.action_release(act)
	# Corre rente a parede, para os dois lados.
	var along := normal.cross(Vector3.UP)
	Input.action_press(&"run")
	for s: float in [1.0, -1.0]:
		lead.teleport(stand)
		rig.set_low_view(atan2(along.x * s, along.z * s) + PI + 0.6 * s)
		rig.follow(lead, true)
		for t in 90:
			_push(along * s - normal * 0.4)
			await _tick(label + " corre")
	Input.action_release(&"run")
	_release()


func _push(dir: Vector3) -> void:
	var local := Basis(Vector3.UP, -main.camera_rig.yaw) * dir.normalized()
	for pair: Array in [[&"move_right", local.x], [&"move_left", -local.x], [&"move_down", local.z], [&"move_up", -local.z]]:
		if float(pair[1]) > 0.01:
			Input.action_press(pair[0] as StringName, float(pair[1]))
		else:
			Input.action_release(pair[0] as StringName)


func _tick(label: String) -> void:
	await r.tree.physics_frame
	await r.tree.process_frame
	var rig := main.camera_rig
	var cam := rig.camera.global_position
	var look := main.controlled_node.global_position + rig.look_offset
	_ticks += 1
	var space := main.world.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _sphere
	q.transform = Transform3D(Basis(), cam)
	q.collision_mask = rig.collision_mask
	q.exclude = rig.exclude
	var inside := not space.intersect_shape(q, 1).is_empty()
	var ray := PhysicsRayQueryParameters3D.create(look, cam, rig.collision_mask)
	ray.exclude = rig.exclude
	var hit := space.intersect_ray(ray)
	# Mira ja dentro de algo (heroi colado) nao conta: o rig tambem ignora esse caso.
	var behind := not hit.is_empty() and (hit["position"] as Vector3).distance_to(look) > 0.05
	# G24a2: atras de algo so vale se o que tapa esta no pontilhado (ou entrando nele, ate OCCL_TIME depois de tapar).
	if behind and rig.occlusion_fade:
		_blocked_for += 1.0 / Engine.physics_ticks_per_second
		if rig.occlusion_covers(hit["position"] as Vector3) or _blocked_for <= CameraRig.OCCL_TIME + 0.02:
			behind = false
			_faded += 1
	elif hit.is_empty():
		_blocked_for = 0.0
	var canopy := false
	for s in rig.occluders:
		var c := Vector3(s.x, s.y, s.z)
		if cam.distance_to(c) < s.w - CAM_RADIUS and look.distance_to(c) > s.w:
			canopy = true
	var d := cam.distance_to(look)
	if (inside or behind or canopy) and d <= CameraRig.MIN_ARM + 0.02:
		_at_min += 1  # braco minimo (0,9 m) de proposito: a camera nao cola no heroi; igual ao codigo antigo
	elif inside or behind or canopy:
		_bad.append("%s q%d d%.2f%s%s%s" % [label, _ticks, d, " dentro" if inside else "", " atras" if behind else "", " copa" if canopy else ""])
