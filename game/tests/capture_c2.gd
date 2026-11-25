extends Node
## Captura C2 (RB-R1): Ep01 v3 na praca, entrada real - anda 2,5 s, corre 2,5 s, para, pula duas vezes, trio parado.
## Uso: xvfb-run ... godot.sh --path game res://tests/capture_c2.tscn --write-movie <abs>/f.png --fixed-fps 30 --quit-after 330

var main: Ep01V3Main
var t := 0.0
var dir := Vector3.ZERO


func _ready() -> void:
	Ep01V3Main.start_mission = &""
	Ep01V3Main.save_path = ""
	main = (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main.current = null
	var base := main.world.marker(&"M8_FestaPlaza").global_position
	dir = Vector3.FORWARD.rotated(Vector3.UP, TAU * 0.0 / 16.0)
	var space := main.world.get_world_3d().direct_space_state
	var found := false
	for oz: float in [0.0, 4.0, -4.0, 8.0]:
		for i in 16:
			var d := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 16.0)
			var o := base + Vector3(0, 0, oz)
			var q := PhysicsShapeQueryParameters3D.new()
			var s := SphereShape3D.new()
			s.radius = 1.4
			q.shape = s
			q.collision_mask = 1
			q.motion = d * 14.0
			var ok := true
			for h: float in [1.5, 2.2]:
				q.transform = Transform3D(Basis(), o - d * 2.5 + Vector3(0, h, 0))
				var res := space.cast_motion(q)
				ok = ok and not res.is_empty() and res[0] >= 1.0
			if ok and not found:
				dir = d
				base = o
				found = true
	print("[C2] faixa ", found, " base ", base, " dir ", dir)
	var lead := main.actors[&"tracker"] as MemberActor
	var side := dir.cross(Vector3.UP)
	lead.teleport(base + Vector3(0, 0.05, 0))
	(main.actors[&"climber"] as MemberActor).teleport(base - dir * 1.2 + side + Vector3(0, 0.05, 0))
	(main.actors[&"pilot"] as MemberActor).teleport(base - dir * 1.2 - side + Vector3(0, 0.05, 0))
	lead.face_now(base + dir)


func _push(on: bool) -> void:
	var local := Basis(Vector3.UP, -main.camera_rig.yaw) * dir
	for pair: Array in [[&"move_right", local.x], [&"move_left", -local.x], [&"move_down", local.z], [&"move_up", -local.z]]:
		if on and float(pair[1]) > 0.01:
			Input.action_press(pair[0] as StringName, float(pair[1]))
		else:
			Input.action_release(pair[0] as StringName)


func _physics_process(delta: float) -> void:
	if main == null or main.current != null:
		return
	t += delta
	if t < 0.5:
		return
	if t < 3.0:
		_push(true)
	elif t < 5.5:
		Input.action_press(&"run")
		_push(true)
	elif t < 6.0:
		Input.action_release(&"run")
		_push(false)
	elif t < 9.0:
		var k := int((t - 7.0) * 60.0)
		if t > 7.0 and (k < 3 or (k >= 60 and k < 63)):
			Input.action_press(&"jump")
		else:
			Input.action_release(&"jump")
