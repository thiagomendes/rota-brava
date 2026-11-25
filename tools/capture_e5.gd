extends SceneTree
## Capturas da E5 (RB-R1): monta cada momento das M5-M8 pelo proprio codigo do episodio e salva a tela (PNG 16:9).
## Uso (Linux, sem GPU: Vulkan por software):
##   xvfb-run -a bash tools/godot.sh --path game --rendering-driver vulkan --script res://../tools/capture_e5.gd -- --out=/abs/dir
## Nao e teste: so produz imagens para olhar.

var out_dir := ""
## --part=M5|M6|M7|M8|cam (vazio = todas); o render por software e lento.
var part := ""
var main: Ep01V3Main


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
		if a.begins_with("--part="):
			part = a.trim_prefix("--part=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _open(mission: StringName) -> void:
	if main != null:
		main.queue_free()
		await _wait(0.2)
	Ep01V3Main.save_path = ""
	Ep01V3Main.start_mission = mission
	main = (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	root.add_child(main)
	current_scene = main
	await _wait(0.5)
	await _confirm()


func _confirm() -> void:
	for i in 3:
		await _wait(0.6)
		if main.hud.handoff_open:
			main.hud._confirm_handoff()
			await _wait(1.4)


func _settle() -> void:
	while main.land.busy or main.hud.handoff_open:
		if main.hud.handoff_open:
			main.hud._confirm_handoff()
		await _wait(0.2)
	await _wait(1.5)


func _yaw_to(from: Vector3, to: Vector3) -> void:
	var d := to - from
	main.camera_rig.set_low_view(atan2(d.x, d.z) + PI)
	main.camera_rig.follow(main.controlled_node, true)


func _shot(n: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(n + ".png"))
	print("[RB] shot ", n, " ", img.get_size())


func _mk(n: StringName) -> Vector3:
	return main.world.marker(n).global_position


func _run() -> void:
	if part == "" or part == "M5":
		await _part_M5()
	if part == "" or part == "M6":
		await _part_M6()
	if part == "" or part == "M7":
		await _part_M7()
	if part == "" or part == "M8":
		await _part_M8()
	if part == "" or part == "cam":
		await _part_cam()
	quit(0)


func _part_M5() -> void:
	var t: MemberActor
	var p: MemberActor
	# M5: Rastro nas penas; Pico no telhado com a gaivota.
	await _open(&"M5")
	t = main.actors[&"tracker"] as MemberActor
	t.teleport(_mk(&"M5_FeatherTrail_3") + Vector3(0.6, 0.05, 0.8))
	_yaw_to(t.global_position, _mk(&"M5_FeatherTrail_1"))
	await _wait(1.2)
	await _shot("m5_1_rastro_penas")
	for i in 4:
		main.land._on_spot(StringName("feather_%d" % (i + 1)), t)
	await _confirm()
	main.land._on_spot(&"vane", main.actors[&"pilot"])
	await _confirm()
	p = main.actors[&"climber"] as MemberActor
	p.teleport(main.land.points[&"CratesBase"] + Vector3(0, 0.05, 0))
	await _wait(0.3)
	main.land._on_spot(&"crates_climb", p)
	await _settle()
	_yaw_to(p.global_position, _mk(&"M5_ShedRoof") + Vector3(0.2, 0, -0.3))
	main.camera_rig.set_low_view(main.camera_rig.yaw + 0.6)
	await _wait(1.0)
	await _shot("m5_2_pico_telhado_gaivota")


func _part_M6() -> void:
	var t: MemberActor
	var p: MemberActor
	# M6: barco entre as boias; corda no bote.
	await _open(&"M6")
	main.land._on_spot(&"board", main.actors[&"pilot"])
	var boat := main.boat
	boat.place(_mk(&"M6_BuoyA") + Vector3(-5.0, 0, 1.6), deg_to_rad(-70.0))
	main.camera_rig.yaw = boat.heading
	main.camera_rig.follow(boat, true)
	await _wait(1.5)
	await _shot("m6_1_leme_pilota_boias")
	main.land._on_spot(&"buoy_a", boat)
	main.land._on_spot(&"buoy_b", boat)
	boat.place(_mk(&"M6_DinghyApproach") + Vector3(-3.0, 0, 0.6), -PI / 2.0)
	main.land._on_spot(&"approach", boat)
	await _settle()
	main.land._on_spot(&"rope", main.actors[&"climber"])
	await _wait(1.2)
	main.camera_rig.set_view(Ep01V3Late.BOAT_VIEW, boat.heading + 0.9, Ep01V3Late.BOAT_LOOK_Y)
	main.camera_rig.follow(boat, true)
	await _wait(0.4)
	await _shot("m6_2_pico_corda_bote")


func _part_M7() -> void:
	var t: MemberActor
	var p: MemberActor
	# M7: lente; Pico na galeria com o filhote; feixe nos barquinhos.
	await _open(&"M7")
	t = main.actors[&"tracker"] as MemberActor
	t.teleport(_mk(&"M7_Lens") + Vector3(1.4, 0.3, 1.2))
	_yaw_to(t.global_position, _mk(&"M7_Lens"))
	await _wait(1.5)
	await _shot("m7_1_rastro_lente")
	main.land._on_spot(&"lens", t)
	await _confirm()
	p = main.actors[&"climber"] as MemberActor
	p.teleport(main.land.points[&"StairFoot"] + Vector3(0, 0.05, 0))
	await _wait(0.3)
	main.land._on_spot(&"stair_climb", p)
	await _settle()
	main.camera_rig.set_low_view(deg_to_rad(80.0))
	main.camera_rig.follow(p, true)
	await _wait(1.0)
	await _shot("m7_2_pico_galeria_filhote")
	main.land._on_spot(&"pup", p)
	await _settle()
	for i in 2:
		main.land._on_spot(&"aim", main.actors[&"pilot"])
		await _wait(0.8)
	var l := main.actors[&"pilot"] as MemberActor
	main.camera_rig.set_low_view(deg_to_rad(200.0))
	main.camera_rig.follow(l, true)
	main.world.set_night(true)
	await _wait(1.5)
	await _shot("m7_3_leme_gira_lanterna_noite")


func _part_M8() -> void:
	var t: MemberActor
	var p: MemberActor
	# M8: festa a noite; conclusao com emblemas.
	await _open(&"M8")
	await _wait(1.0)
	var c := main.land.captain.global_position
	main.camera_rig.set_low_view(deg_to_rad(150.0))
	main.camera_rig.follow(main.controlled_node, true)
	_yaw_to(main.controlled_node.global_position, c)
	await _wait(1.5)
	await _shot("m8_1_festa_noite_capitao")
	main.camera_rig.set_low_view(deg_to_rad(250.0))
	main.camera_rig.pitch = CameraRig.PITCH_MAX
	main.camera_rig.follow(main.controlled_node, true)
	await _wait(1.5)
	await _shot("m8_2_festa_noite_porto")
	main.land._on_spot(&"captain", main.controlled_node)
	await _wait(2.5)
	await _shot("m8_3_conclusao_emblemas")


func _part_cam() -> void:
	var t: MemberActor
	var p: MemberActor
	# Camera corrigida: Pico no topo do galpao (defeito da E4), no giro em que a camera encurta.
	await _open(&"M2")
	p = main.actors[&"climber"] as MemberActor
	p.teleport(_mk(&"M2_ShedTop") + Vector3(0, 0.05, 0))
	main.active_member = &"climber"
	main.set_controlled(p)
	var best := 0
	var pull := 0.0
	for k in 8:
		main.camera_rig.set_low_view(k * TAU / 8.0)
		main.camera_rig.follow(p, true)
		await process_frame
		if main.camera_rig.last_pull > pull:
			pull = main.camera_rig.last_pull
			best = k
	print("[RB] camera pull %.2f m no giro %d" % [pull, best * 45])
	main.camera_rig.set_low_view(best * TAU / 8.0)
	main.camera_rig.follow(p, true)
	await _wait(1.2)
	await _shot("camera_pico_topo_galpao_corrigida")
