extends Node
## Capturas do G24 (cordas e barcos): M5 (peixe baixado na corda do telhado) e M6 (corda do bote e o recuo do reboque com o
## capitao), com camera fixa de lado/de cima que mostra a corda e os barcos parados. So prova visual; a medida fica em
## test_motion_audit.gd. NAO e jogo.
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" bash tools/godot.sh --path game --rendering-driver vulkan \
##   res://tests/capture_g24.tscn -- --g24-out=/ABS/captures/g24/after --g24-act=m5

const MAIN := "res://episodes/ep01/v3/ep01_v3_main.tscn"

var main: Ep01V3Main
var out := ""
var cam: Camera3D


static func _arg(key: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return def


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	out = _arg("--g24-out", "")
	var act := _arg("--g24-act", "m5")
	DirAccess.make_dir_recursive_absolute(out)
	Ep01V3Main.save_path = ""
	Ep01V3Cutscene.enabled = false
	Ep01V3Main.start_mission = &"M5" if act == "m5" else &"M6"
	main = (load(MAIN) as PackedScene).instantiate() as Ep01V3Main
	add_child(main)
	await _wait(1.5)
	main.hud.clear_speech()
	_hide_ui(main)
	main.set_followers_enabled(false)
	cam = Camera3D.new()
	cam.fov = 55.0
	cam.near = 0.05
	add_child(cam)
	cam.current = true
	call("_act_" + act)


func _notify(evs: Array) -> void:
	for ev: StringName in evs:
		for who: StringName in [&"tracker", &"climber", &"pilot"]:
			if main.current.notify(ev, who):
				break
	await _wait(0.2)
	if main.hud.handoff_open:
		main.hud._handoff_since = -100.0
		main.hud._confirm_handoff()
	await _wait(0.3)


func _hero(m: StringName) -> MemberActor:
	var a := main.actors[m] as MemberActor
	main.active_member = m
	main.set_controlled(a)
	if main.current != null:
		main.current.set_active_hero(m)
	return a


## Dispara o ponto e grava um quadro a cada `step` s ate a acao terminar ou `max_s`.
func _do(a: Node3D, id: StringName, tag: String, max_s: float, step: float) -> void:
	main.land.call("_on_spot", id, a)
	var t := 0.0
	var next := 0.0
	var n := 0
	await get_tree().process_frame
	while t < max_s:
		if t >= next:
			await _save("%s_%02d.png" % [tag, n])
			n += 1
			next += step
		await get_tree().process_frame
		t += get_process_delta_time()
		if not main.land.busy and int(main.land.get("_acts")) == 0 and t > 0.5:
			break
	await _save("%s_%02d.png" % [tag, n])


func _act_m5() -> void:
	await _notify([&"feather_followed", &"feather_followed", &"feather_followed", &"feather_followed", &"compass_read"])
	var pico := _hero(&"climber")
	pico.teleport(main.land.points[&"CratesBase"] + Vector3(0, 0.05, 0))
	await _wait(0.3)
	main.land.call("_on_spot", &"crates_climb", pico)
	while main.land.busy or int(main.land.get("_acts")) > 0:
		await get_tree().process_frame
	main.land.call("_set_busy", true)
	var base: Vector3 = main.land.points[&"CratesBase"]
	var mid := pico.global_position.lerp(base, 0.5)
	_place_cam(mid + Vector3(0, 0.8, 0), 6.5, 0.8)
	await _do(pico, &"fish", "m5_fish", 20.0, 0.5)
	_done()


func _act_m6() -> void:
	await _wait(0.5)
	if main.hud.handoff_open:
		main.hud._handoff_since = -100.0
		main.hud._confirm_handoff()
		await _wait(Ep01V3Main.TEAM_POSE_SECONDS + 0.3)
	var land := main.land
	var boat := main.boat
	land.call("_on_spot", &"board", main.actors[&"pilot"])
	while land.busy:
		await get_tree().process_frame
	land.call("_on_spot", &"buoy_a", boat)
	land.call("_on_spot", &"buoy_b", boat)
	var to := main.world.marker(&"M6_DinghyApproach").global_position
	# chega por agua livre (como o bot): a 3,4 m do marcador, na primeira direcao em que o casco nao toca nada
	var start := to + Vector3(-3.0, 0, 0.5)
	var head := -PI / 2.0
	if land.has_method(&"boat_gap"):
		for i in 16:
			var d := Vector3(sin(TAU * i / 16.0), 0, cos(TAU * i / 16.0))
			var p := to + d * 3.4
			var h := atan2(d.x, d.z)   # proa para o marcador
			if float(land.call(&"boat_gap", p, h)) > 0.8:
				start = p
				head = h
				break
	if _arg("--g24-start", "") == "old":
		start = to + Vector3(-3.0, 0, 0.5)
		head = -PI / 2.0
	boat.place(start, head)
	cam.global_position = to + Vector3(-9.0, 9.0, 6.0)
	cam.look_at(to + Vector3(-1.5, 0, 0), Vector3.UP)
	land.call("_on_spot", &"approach", boat)
	while land.busy:
		await get_tree().process_frame
	await _save("m6_docked.png")
	await _wait(0.6)
	if main.hud.handoff_open:
		main.hud._handoff_since = -100.0
		main.hud._confirm_handoff()
		await _wait(0.5)
	await _do(main.actors[&"climber"], &"rope", "m6_tow", 6.0, 0.4)
	_done()


## Camera a `dist` m de `at` na primeira direcao (de 16) com a vista livre ate o alvo.
func _place_cam(at: Vector3, dist: float, up: float) -> void:
	var space := main.world.get_world_3d().direct_space_state
	for i in 16:
		var d := Vector3(sin(TAU * i / 16.0), 0, cos(TAU * i / 16.0))
		var p := at + d * dist + Vector3(0, up, 0)
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(p, at, 1)).is_empty() \
				and space.intersect_ray(PhysicsRayQueryParameters3D.create(at, p, 1)).is_empty():
			cam.global_position = p
			cam.look_at(at, Vector3.UP)
			print("[G24CAP] camera ", i, " ", p)
			return
	cam.global_position = at + Vector3(0, dist, 0.1)
	cam.look_at(at, Vector3.UP)


func _done() -> void:
	print("[G24CAP] fim ", out)
	get_tree().quit()


func _hide_ui(n: Node) -> void:
	for c in n.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
		_hide_ui(c)


func _save(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(file))


func _wait(s: float) -> void:
	var t := 0.0
	while t < s:
		await get_tree().process_frame
		t += get_process_delta_time()
