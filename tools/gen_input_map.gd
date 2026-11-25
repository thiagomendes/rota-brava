extends SceneTree
## Gera as intencoes da Input Map em game/project.godot (SPEC secao 5, Entrada).
## Uso: ./tools/godot.ps1 --headless --path game --script res://../tools/gen_input_map.gd
## (ou veja tools/gen-input-map.ps1). Idempotente.

const DEADZONE := 0.5


func _key(physical: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = physical
	return e


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.device = -1
	e.axis_value = value
	return e


func _button(index: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = index
	e.device = -1
	return e


func _set_action(action: String, events: Array) -> void:
	ProjectSettings.set_setting("input/" + action, {"deadzone": DEADZONE, "events": events})


func _initialize() -> void:
	_set_action("move_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_set_action("move_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_set_action("move_up", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_set_action("move_down", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_set_action("interact", [_key(KEY_E), _button(JOY_BUTTON_X)])
	_set_action("pause", [_key(KEY_ESCAPE), _button(JOY_BUTTON_START)])
	_set_action("help", [_key(KEY_H), _button(JOY_BUTTON_Y)])
	# C2 (RB-R1): andar e o padrao; `run` corre (Shift, gatilho direito). `jump` no A; por isso `interact` foi para o X.
	_set_action("run", [_key(KEY_SHIFT), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_set_action("jump", [_key(KEY_SPACE), _button(JOY_BUTTON_A)])
	# C1 (RB-R1): orbita da camera pela alavanca direita (mouse e lido direto pela CameraRig, capturado com clique).
	for spec: Array in [["cam_left", JOY_AXIS_RIGHT_X, -1.0], ["cam_right", JOY_AXIS_RIGHT_X, 1.0],
			["cam_up", JOY_AXIS_RIGHT_Y, -1.0], ["cam_down", JOY_AXIS_RIGHT_Y, 1.0]]:
		ProjectSettings.set_setting("input/" + String(spec[0]), {"deadzone": 0.2, "events": [_axis(spec[1], spec[2])]})
	var err := ProjectSettings.save()
	if err != OK:
		push_error("Falha ao salvar project.godot: %d" % err)
	quit(0 if err == OK else 1)
