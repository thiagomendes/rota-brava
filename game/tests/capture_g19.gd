extends Node
## Capturas do G19 (acoes no jogo): abre o Ep01 v3 na missao, executa as acoes pelos proprios pontos da Land (como o
## "agir" da crianca) e salva quadros sequenciais da acao (um a cada --g19-step s) com uma camera de lado que acompanha o
## heroi (--g19-cam=side) ou, por padrao, a propria camera do jogo seguindo o heroi (como a crianca ve). So prova visual; os testes ficam em test_ep01_v3_g19.gd. NAO e jogo.
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" bash tools/godot.sh --path game --rendering-driver vulkan \
##   res://tests/capture_g19.tscn -- --g19-out=/ABS/captures/g19-acoes --g19-act=m2
## Atos: m2 (soltar no galpao, cesto, pendurar no banco), m4 (erguer a caixinha, pousar na barraca), climb (subir e descer
## o chafariz), m3 (folhas), m5 (peixe na corda), m6 (corda do bote), m7 (lente, filhote, bussola), m1 (bota), m8.

const MAIN := "res://episodes/ep01/v3/ep01_v3_main.tscn"

var main: Ep01V3Main
var out := ""
var cam: Camera3D
var step := 0.12
var _shot := 0
var _tag := ""
var _subject: Node3D
var _cam_side := 1.0
var _cam_dist := 3.0
var _cam_h := 1.1


static func _arg(key: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return def


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	out = _arg("--g19-out", "")
	step = float(_arg("--g19-step", "0.12"))
	var act := _arg("--g19-act", "m2")
	DirAccess.make_dir_recursive_absolute(out)
	Ep01V3Main.save_path = ""
	Ep01V3Cutscene.enabled = false
	Ep01V3Main.start_mission = {"m1": &"M1", "m2": &"M2", "m3": &"M3", "climb": &"M3", "m4": &"M4", "m5": &"M5",
		"m6": &"M6", "m7": &"M7", "m8": &"M8"}.get(act, &"M2")
	main = (load(MAIN) as PackedScene).instantiate() as Ep01V3Main
	add_child(main)
	await _wait(1.5)
	main.hud.clear_speech()
	_hide_ui(main)
	if _arg("--g19-cam", "game") == "side":
		cam = Camera3D.new()
		cam.fov = 50.0
		cam.near = 0.03
		add_child(cam)
		cam.current = true
	main.set_followers_enabled(false)
	call("_act_" + act)
	await get_tree().create_timer(600.0).timeout


func _process(_d: float) -> void:
	if _subject != null and is_instance_valid(_subject) and cam != null:
		var a := _subject as MemberActor
		var f := a.facing() if a != null else Vector3.FORWARD
		var side := Vector3(-f.z, 0, f.x) * _cam_side
		var at := _subject.global_position + Vector3(0, 0.6, 0)
		cam.global_position = at + side * _cam_dist + f * 0.8 + Vector3(0, _cam_h - 0.6, 0)
		cam.look_at(at, Vector3.UP)


func _hero(m: StringName) -> MemberActor:
	var a := main.actors[m] as MemberActor
	main.active_member = m
	main.set_controlled(a)
	main.camera_rig.follow(a, true)
	if main.current != null:
		main.current.set_active_hero(m)
	main.hud.clear_speech()
	return a


## Dispara o ponto `id` com o heroi `m` e grava quadros ate a acao terminar (Land livre) ou `max_s`.
func _do(m: StringName, id: StringName, tag: String, max_s: float = 8.0) -> void:
	var a := _hero(m)
	_subject = a
	_tag = tag
	_shot = 0
	main.land.call("_on_spot", id, a)
	var t := 0.0
	var next := 0.0
	await get_tree().process_frame
	while t < max_s:
		if t >= next:
			await _save("%s_%02d.png" % [_tag, _shot])
			_shot += 1
			next += step
		await get_tree().process_frame
		t += get_process_delta_time()
		if not main.land.busy and t > 0.3:
			break
	await _save("%s_%02d.png" % [_tag, _shot])
	await _wait(0.1)


## Leva o heroi ate perto de `p` (teleporte so na captura: o caminho nao e o que se mostra).
func _go(m: StringName, p: Vector3) -> void:
	var a := main.actors[m] as MemberActor
	a.teleport(main.floor_at(p) + Vector3(0, 0.05, 0))
	await _wait(0.3)


func _done() -> void:
	print("[G19CAP] fim ", out)
	get_tree().quit()


func _act_m2() -> void:
	var land := main.land
	var climber := main.actors[&"climber"] as MemberActor
	await _go(&"climber", land.points[&"ShedBase"])
	await _do(&"climber", &"shed_climb", "m2_a_sobe_galpao", 10.0)
	await _do(&"climber", &"shed_free", "m2_b_solta_desce", 10.0)
	await _go(&"climber", land.points[&"Basket"] + Vector3(0.0, 0, 0.6))
	climber.face_now(land.points[&"Basket"])
	await _do(&"climber", &"basket", "m2_c_cesto")
	# as outras duas pelos atalhos de teste (ja cobertos pelos quadros acima): arvore e juncos
	await _do(&"climber", &"tree_climb", "m2_d_sobe_arvore", 10.0)
	await _do(&"climber", &"tree_free", "m2_e_solta_galho", 10.0)
	await _go(&"climber", land.points[&"Basket"] + Vector3(0.0, 0, 0.6))
	await _do(&"climber", &"basket", "m2_f_cesto2")
	await _go(&"tracker", land._mk(&"M2_ReedsPiece") + Vector3(0.6, 0, 0.4))
	await _do(&"tracker", &"reeds", "m2_g_juncos")
	await _go(&"tracker", land.points[&"Basket"] + Vector3(0.0, 0, 0.6))
	await _do(&"tracker", &"basket", "m2_h_cesto3")
	land.call("_set_busy", false)
	for i in 3:
		await _do(&"tracker", &"basket", "m2_i%d_pega_do_cesto" % i)
		_cam_side = -1.0
		await _do(&"tracker", &"hang", "m2_j%d_pendura" % i)
		_cam_side = 1.0
		if i == 0:
			land.call("_set_busy", true)
	await _done()


func _act_m4() -> void:
	var land := main.land
	main.current.notify(&"icons_read", &"tracker")
	await _wait(1.0)
	if main.hud.handoff_open:
		main.hud._handoff_since = -100.0
		main.hud._confirm_handoff()
		await _wait(1.0)
	var leme := _hero(&"pilot")
	land.call("_on_spot", &"take_cart", leme)
	for st: StringName in Ep01V3Land.CARGO_ORDER:
		var m := land._mk(st)
		var to := m + (land.cart.global_position - m).normalized() * 1.6
		var tw := create_tween()
		land.cart_holder = leme
		await _go(&"pilot", to)
		await _wait(0.4)
		await _do(&"pilot", StringName("deliver_" + String(st)), "m4_%s_a_ergue" % String(st).trim_prefix("M4_Stall_").to_lower())
		await _do(&"pilot", StringName("deliver_" + String(st)), "m4_%s_b_pousa" % String(st).trim_prefix("M4_Stall_").to_lower())
		tw.kill()
		land.call("_on_spot", &"take_cart", leme)
	await _done()


func _act_climb() -> void:
	var land := main.land
	main.current.notify(&"stream_followed", &"tracker")
	main.current.notify(&"stream_followed", &"tracker")
	await _wait(1.0)
	if main.hud.handoff_open:
		main.hud._handoff_since = -100.0
		main.hud._confirm_handoff()
		await _wait(1.0)
	await _go(&"climber", land.points[&"FountainBase"])
	_cam_dist = 3.6
	await _do(&"climber", &"fountain_climb", "climb_a_chafariz", 12.0)
	await _do(&"climber", &"leaves", "climb_b_folhas_desce", 12.0)
	await _done()


func _act_m3() -> void:
	await _act_climb()


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
