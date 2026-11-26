extends Node
## Captura F1 (RB-R1): Ep01 v3, entrada real - o lider anda ate os caixotes do M5, raspa neles, para; da toques curtos;
## anda ate o chafariz do M3 e para perto dele. Seguidores em formacao.
## Uso: xvfb-run ... godot.sh --path game res://tests/capture_f1.tscn --write-movie <abs>/f.png --fixed-fps 30 --quit-after 600

var main: Ep01V3Main
var t := 0.0
var targets: Array[Vector3] = []


func _ready() -> void:
	Ep01V3Main.start_mission = &""
	Ep01V3Main.save_path = ""
	main = (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main.current = null
	var crates := main.world.marker(&"M5_Crates").global_position
	targets = [crates, main.world.marker(&"M3_UpperBasin").global_position]
	var space := main.world.get_world_3d().direct_space_state
	var start := crates + Vector3(0, 0, 5)
	for i in 16:
		var p := crates + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 16.0) * 5.0
		var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 4, 0), p + Vector3(0, -4, 0), 1))
		if not h.is_empty() and (h["position"] as Vector3).y < crates.y + 0.3:
			start = h["position"] as Vector3
			break
	var lead := main.actors[&"tracker"] as MemberActor
	var d := (crates - start)
	d.y = 0.0
	d = d.normalized()
	var side := d.cross(Vector3.UP)
	lead.teleport(start + Vector3(0, 0.05, 0))
	(main.actors[&"climber"] as MemberActor).teleport(start - d * 1.2 + side + Vector3(0, 0.05, 0))
	(main.actors[&"pilot"] as MemberActor).teleport(start - d * 1.2 - side + Vector3(0, 0.05, 0))
	lead.face_now(start + d)
	main.camera_rig.set_low_view(atan2(d.x, d.z) + PI)
	main.camera_rig.follow(lead, true)


func _push(dir: Vector3) -> void:
	var local := Basis(Vector3.UP, -main.camera_rig.yaw) * dir.normalized()
	for pair: Array in [[&"move_right", local.x], [&"move_left", -local.x], [&"move_down", local.z], [&"move_up", -local.z]]:
		if dir.length() > 0.01 and float(pair[1]) > 0.01:
			Input.action_press(pair[0] as StringName, float(pair[1]))
		else:
			Input.action_release(pair[0] as StringName)


func _physics_process(delta: float) -> void:
	if main == null or targets.is_empty():
		return
	t += delta
	var lead := main.actors[&"tracker"] as MemberActor
	var to_crates := targets[0] - lead.global_position
	to_crates.y = 0.0
	var to_basin := targets[1] - lead.global_position
	to_basin.y = 0.0
	if t < 3.0:
		_push(to_crates)  # anda e raspa nos caixotes
	elif t < 5.5:
		_push(Vector3.ZERO)  # parado perto dos caixotes
	elif t < 8.0:
		_push(to_crates.cross(Vector3.UP) if int(t * 2.0) % 2 == 0 else Vector3.ZERO)  # toques curtos
	elif t < 10.0:
		_push(Vector3.ZERO)
	elif t < 16.0 and to_basin.length() > 3.0:
		_push(to_basin)
	else:
		_push(Vector3.ZERO)  # parado perto do chafariz
