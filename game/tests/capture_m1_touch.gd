extends Node
## Captura RB-M1 (toque basico): Ep01 v3 com a camada de toque visivel, joystick segurado (dedo 0), dedo na camera
## (dedo 1) e o Examinar ao alcance. So prova visual; os testes de entrada ficam em test_touch_controls.gd.
## A resolucao vem de game/override.cfg temporario (nunca versionar), como nas outras capturas.
## Uso: xvfb-run -a -s "-screen 0 2560x1440x24" bash tools/godot.sh --path game --rendering-driver vulkan \
##   res://tests/capture_m1_touch.tscn -- --m1-out=/ABS/arquivo.png

var main: Ep01V3Main


static func _arg(key: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return def


func _win(p: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * p


func _touch(index: int, p: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = _win(p)
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(index: int, from: Vector2, to: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = _win(to)
	e.relative = _win(to) - _win(from)
	Input.parse_input_event(e)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	Ep01V3Cutscene.enabled = false
	Ep01V3Main.start_mission = &""
	Ep01V3Main.save_path = ""
	main = (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	add_child(main)
	await _frames(30)
	main.guide.skip_look()
	var vp := main.touch.view_size()
	_touch(0, Vector2(vp.x * 0.7, vp.y * 0.4), true)
	await _frames(2)
	_touch(0, Vector2(vp.x * 0.7, vp.y * 0.4), false)
	var lead := main.controlled_node as Node3D
	var it := Ep01Interactable.new()
	it.radius = 3.0
	it.member = main.active_member
	it.label_key = "ui.action.examine"
	main.world.add_child(it)
	it.global_position = lead.global_position
	main.land.spots[&"m1_capture"] = it
	await _frames(10)
	var o := main.touch.stick_home() + Vector2(40, -30)
	_touch(0, o, true)
	await _frames(1)
	_drag(0, o, o + Vector2(70, -60))
	_touch(1, Vector2(vp.x * 0.66, vp.y * 0.38), true)
	for i in 40:
		it.global_position = lead.global_position  # o ponto acompanha o heroi: o Examinar fica ao alcance na foto
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var out := _arg("--m1-out", "")
	if out != "":
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		print("M1 salvo %s %s err=%d vp=%s" % [out, str(img.get_size()), img.save_png(out), str(vp)])
	_touch(0, o, false)
	_touch(1, Vector2(vp.x * 0.66, vp.y * 0.38), false)
	get_tree().quit(0)
