extends Node
## Capturas do varal do M2 (RB-R1 G18, art3d): abre o Ep01 v3 no M2, executa as acoes da missao pelos proprios pontos de
## acao da Land (soltar, achar, pendurar) e salva PNG de perto e na camera do jogo. So para capturas; NAO e jogo.
## Linha de comando (apos --):
##   --vc-out=<dir absoluto>        onde salvar (obrigatorio)
##   --vc-state=initial|basket|hung|after   initial: pecas no galpao/galho/juncos; basket: 3 no cesto; hung: logo apos
##                                  pendurar a 3a; after: ja na missao seguinte (M3 montada)
## Exemplo: xvfb-run -a bash tools/godot.sh --path game --rendering-driver vulkan \
##   res://assets/models/props_v3/varal_capture.tscn -- --vc-out=/abs/captures/g18 --vc-state=hung

const MAIN := "res://episodes/ep01/v3/ep01_v3_main.tscn"

var main: Ep01V3Main
var out := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	out = _arg("--vc-out", "")
	var state := _arg("--vc-state", "hung")
	DirAccess.make_dir_recursive_absolute(out)
	Ep01V3Main.save_path = ""
	Ep01V3Main.start_mission = &"M2"
	Ep01V3Cutscene.enabled = false
	main = (load(MAIN) as PackedScene).instantiate() as Ep01V3Main
	add_child(main)
	await _wait(1.0)
	if state != "initial":
		# G19: soltar/achar poe a roupa na mao; o "agir" no cesto deixa ela la
		await _act(&"climber", &"shed_free", 6.0)
		await _act(&"climber", &"basket", 1.5)
		await _act(&"climber", &"tree_free", 6.0)
		await _act(&"climber", &"basket", 1.5)
		await _act(&"tracker", &"reeds", 3.0)
		await _act(&"tracker", &"basket", 1.5)
	if state in ["hung", "after"]:
		if state == "hung":
			# segura a montagem da proxima missao (ela espera a Land livre) para fotografar o varal com o M2 concluido
			main.land.call("_set_busy", true)
		for i in 3:
			await _act(&"tracker", &"basket", 1.2)
			await _act(&"tracker", &"hang", 3.0)
	if state == "after":
		var t := 0.0
		while main.land.mission_id == &"M2" and t < 20.0:
			await get_tree().process_frame
			t += get_process_delta_time()
		await _wait(1.5)
	print("[VC] estado ", state, " missao ", main.land.mission_id)
	await _shots(state)
	get_tree().quit()


func _act(member: StringName, id: StringName, wait: float = 2.2) -> void:
	var a := main.actors[member] as MemberActor
	main.active_member = member
	main.set_controlled(a)
	if main.current != null:
		main.current.set_active_hero(member)
	main.land.call("_on_spot", id, a)
	await _wait(wait)


func _line() -> Dictionary:
	var c := main.world.marker(&"M2_Clothesline").global_position
	var d := Vector3(5.57, 0, -2.38).normalized()   # rumo da corda do mundo (build_world_v2.build_bank)
	return {"c": c, "d": d, "n": Vector3(-d.z, 0, d.x)}


func _shots(state: String) -> void:
	var l := _line()
	var c: Vector3 = l["c"]
	var n: Vector3 = l["n"]
	var d: Vector3 = l["d"]
	# 1) camera do jogo: trio do lado do cesto, camera baixa olhando para o varal
	var lead := main.actors[&"tracker"] as MemberActor
	var stand := main.floor_at(c - n * 2.6 - d * 0.4)
	for m: StringName in [&"tracker", &"climber", &"pilot"]:
		var a := main.actors[m] as MemberActor
		var off := {&"tracker": Vector3.ZERO, &"climber": -d * 0.9 - n * 0.4, &"pilot": d * 0.9 - n * 0.4}[m] as Vector3
		a.teleport(main.floor_at(stand + off) + Vector3(0, 0.05, 0))
		a.face_now(c)
	main.set_followers_enabled(false)
	main.set_controlled(lead)
	main.camera_rig.set_low_view(atan2(n.x, n.z) + PI)
	main.camera_rig.follow(lead, true)
	await _wait(1.2)
	await _save("%s_jogo.png" % state)
	# 2) de perto: camera 1,9 m a frente da corda, na altura dela, de frente para as 3 vagas (sem HUD)
	_hide_ui(main)
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.03
	add_child(cam)
	var y := main.floor_at(c).y + 1.55
	cam.global_position = Vector3(c.x, y, c.z) - n * 1.9
	cam.look_at(Vector3(c.x, y - 0.15, c.z), Vector3.UP)
	cam.current = true
	await _wait(0.4)
	await _save("%s_perto.png" % state)
	# 3) de perto, de lado (rente a corda): mostra se a peca encosta ou flutua
	cam.global_position = Vector3(c.x, y + 0.05, c.z) - d * 2.4 - n * 0.35
	cam.look_at(Vector3(c.x, y - 0.1, c.z), Vector3.UP)
	await _wait(0.4)
	await _save("%s_lado.png" % state)
	if state == "basket" or state == "initial":
		var b: Vector3 = main.land.points[&"Basket"]
		cam.global_position = b + Vector3(0, 1.3, 0) - n * 1.2
		cam.look_at(b + Vector3(0, 0.15, 0), Vector3.UP)
		await _wait(0.4)
		await _save("%s_cesto.png" % state)
	if state == "initial":
		for spot: Array in [[&"M2_ShedTop", "galpao", Vector3(0, 0.9, 0) - n * 2.0 + d * 0.3],
				[&"M2_TreeBranch", "galho", Vector3(0, 0.9, 0) - n * 2.0 + d * 0.3],
				[&"M2_ReedsPiece", "juncos", Vector3(-0.3, 1.1, 1.5)]]:
			var p := main.world.marker(spot[0]).global_position
			cam.global_position = p + (spot[2] as Vector3)
			cam.look_at(p + Vector3(0, 0.1, 0), Vector3.UP)
			await _wait(0.4)
			await _save("%s_%s.png" % [state, spot[1]])


func _hide_ui(n: Node) -> void:
	for c in n.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
		elif c is Control and (c as Control).get_parent() is not Control:
			(c as Control).visible = false
		_hide_ui(c)


func _save(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(file))
	print("[VC] ", out.path_join(file))


func _wait(s: float) -> void:
	var t := 0.0
	while t < s:
		await get_tree().process_frame
		t += get_process_delta_time()


func _arg(flag: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(flag + "="):
			return a.trim_prefix(flag + "=")
	return def
