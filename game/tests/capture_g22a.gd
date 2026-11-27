extends Node
## Captura G22a (RB-R1): botao de ajuda no toque (disco da camada com o "?" no balao) e no teclado (botao do HUD com o
## selo H do G15), com o painel de objetivo e o contador de emblemas acesos para conferir a vizinhanca. So prova visual;
## os testes ficam em test_touch_controls.gd e test_ui_glyphs.gd. A resolucao vem de game/override.cfg temporario.
## Uso: xvfb-run -a -s "-screen 0 2560x1440x24" bash tools/godot.sh --path game --rendering-driver vulkan \
##   res://tests/capture_g22a.tscn -- --g22a-out=/ABS/arquivo.png --g22a-mode=touch|keyboard

var main: Ep01V3Main


static func _arg(key: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return def


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
	main.hud.clear_speech()
	main.hud.set_collectibles(3, 10, false)
	var vp := main.touch.view_size()
	if _arg("--g22a-mode", "touch") == "touch":
		var e := InputEventScreenTouch.new()
		e.position = get_tree().root.get_final_transform() * Vector2(vp.x * 0.7, vp.y * 0.4)
		e.pressed = true
		Input.parse_input_event(e)
		await _frames(2)
		e = e.duplicate()
		e.pressed = false
		Input.parse_input_event(e)
	else:
		var k := InputEventKey.new()
		k.physical_keycode = KEY_SHIFT
		k.keycode = KEY_SHIFT
		k.pressed = true
		Input.parse_input_event(k)
		await _frames(2)
		k = k.duplicate()
		k.pressed = false
		Input.parse_input_event(k)
	await _frames(40)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var out := _arg("--g22a-out", "")
	if out != "":
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		print("G22A salvo %s %s err=%d vp=%s ajuda=%s device=%s" % [out, str(img.get_size()), img.save_png(out), str(vp),
			str(main.hud.help_slot_rect()), InputDevice.last])
	get_tree().quit(0)
