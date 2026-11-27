extends Node
## Captura G15 dos selos nos paineis do HUD (pausa, fim, cartao de equipe) sem o mundo 3D: so o HUD sobre fundo liso.
## Uso: xvfb-run -a -s "-screen 0 2560x1440x24" bash tools/godot.sh --path game --rendering-driver vulkan \
##   res://tests/capture_g15_panels.tscn -- --g15-mode=xbox --g15-out=/ABS/prefixo
## Salva <prefixo>_pause.png, _complete.png e _handoff.png.

const PAD_NAMES := {"xbox": "Xbox Wireless Controller", "playstation": "PS5 Controller",
	"nintendo": "Nintendo Switch Pro Controller", "generic": "USB Gamepad"}


static func _arg(key: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return def


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(path: String) -> void:
	await _frames(40)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	print("G15 painel %s err=%d glyph=%s" % [path, img.save_png(path), InputGlyphs.glyph_id(&"interact")])


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("4FA6E8")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var hud := Hud.new()
	add_child(hud)
	await _frames(5)
	var mode := _arg("--g15-mode", "keyboard")
	match mode:
		"keyboard":
			InputDevice.set_device(InputDevice.KEYBOARD)
		"touch":
			InputDevice.set_device(InputDevice.TOUCH)
		_:
			InputDevice.set_device(InputDevice.PAD, InputDevice.detect_family(PAD_NAMES.get(mode, ""), ""))
	var out := _arg("--g15-out", "")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	hud.open_pause()
	await _shot(out + "_pause.png")
	hud.close_pause()
	hud.open_complete()
	await _shot(out + "_complete.png")
	hud.close_complete()
	hud.open_handoff(Loc.t("ui.hud.your_turn"), &"climber")
	await _shot(out + "_handoff.png")
	get_tree().quit(0)
