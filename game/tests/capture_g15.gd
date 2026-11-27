extends Node
## Captura G15 (dicas pelo aparelho em uso): Ep01 v3 com o Examinar ao alcance e o aparelho escolhido por um evento
## de verdade que nao age no jogo (tecla sem uso, gatilho esquerdo sem uso, toque na metade direita = camera).
## Salva a tela inteira e um recorte do canto do botao de agir. So prova visual; os testes ficam em test_ui_glyphs.gd.
## A resolucao vem de game/override.cfg temporario (nunca versionar), como nas outras capturas.
## Uso: xvfb-run -a -s "-screen 0 2560x1440x24" bash tools/godot.sh --path game --rendering-driver vulkan \
##   res://tests/capture_g15.tscn -- --g15-mode=xbox --g15-out=/ABS/arquivo.png
## Modos: keyboard, xbox, playstation, nintendo, generic, touch.

const PAD_NAMES := {
	"xbox": "Xbox Wireless Controller", "playstation": "PS5 Controller",
	"nintendo": "Nintendo Switch Pro Controller", "generic": "USB Gamepad",
}

var main: Ep01V3Main


static func _arg(key: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return def


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _device_event(mode: String) -> void:
	match mode:
		"keyboard":
			var k := InputEventKey.new()
			k.physical_keycode = KEY_F12
			k.pressed = true
			Input.parse_input_event(k)
			k = k.duplicate() as InputEventKey
			k.pressed = false
			Input.parse_input_event(k)
		"touch":
			var vp := main.touch.view_size()
			var p := get_tree().root.get_final_transform() * Vector2(vp.x * 0.7, vp.y * 0.4)
			for pressed in [true, false]:
				var t := InputEventScreenTouch.new()
				t.position = p
				t.pressed = pressed
				Input.parse_input_event(t)
		_:
			InputDevice.joy_name_override = PAD_NAMES.get(mode, "USB Gamepad")
			for v in [0.9, 0.0]:
				var m := InputEventJoypadMotion.new()
				m.device = 0
				m.axis = JOY_AXIS_TRIGGER_LEFT
				m.axis_value = v
				Input.parse_input_event(m)


func _ready() -> void:
	Ep01V3Cutscene.enabled = false
	Ep01V3Main.start_mission = &""
	Ep01V3Main.save_path = ""
	main = (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	add_child(main)
	await _frames(30)
	main.guide.skip_look()
	var mode := _arg("--g15-mode", "keyboard")
	var lead := main.controlled_node as Node3D
	var it := Ep01Interactable.new()
	it.radius = 3.0
	it.member = main.active_member
	it.label_key = "ui.action.examine"
	main.world.add_child(it)
	it.global_position = lead.global_position
	main.land.spots[&"g15_capture"] = it
	await _frames(10)
	_device_event(mode)
	for i in 40:
		it.global_position = lead.global_position
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var out := _arg("--g15-out", "")
	if out != "":
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var err := img.save_png(out)
		var s := img.get_size()
		var crop := img.get_region(Rect2i(int(s.x * 0.62), int(s.y * 0.5), int(s.x * 0.38), int(s.y * 0.5)))
		var err2 := crop.save_png(out.get_basename() + "_crop.png")
		print("G15 salvo %s %s err=%d/%d device=%s family=%s glyph=%s" % [out, str(s), err, err2, InputDevice.last,
			InputDevice.pad_family, InputGlyphs.glyph_id(&"interact")])
	get_tree().quit(0)
