class_name InputDevice
extends RefCounted
## RB-M1 (toque basico): ultimo dispositivo de entrada que a crianca usou, num lugar so. Classe estatica (sem autoload,
## sem mexer no project.godot): quem recebe eventos chama `note(event)` no proprio `_input` e le `last`. Quem precisa
## reagir a troca compara `last` com o valor que guardou (ou usa o retorno de `note`). Base para o G15 (desenhos dos
## botoes por aparelho), que so precisa ler `last`/`family()`.
## O mouse que a Godot emula a partir do toque (`device == InputEvent.DEVICE_ID_EMULATION`) NAO conta como mouse.

const KEYBOARD := &"keyboard"
const MOUSE := &"mouse"
const PAD := &"pad"
const TOUCH := &"touch"
## Movimento de mouse real abaixo disto (px logicos) nao troca o dispositivo (tremida da mesa, cursor parado).
const MOUSE_MOTION_MIN := 4.0
## Alavanca do controle: so conta inclinacao clara (deriva da alavanca nao some com a camada de toque).
const PAD_AXIS_MIN := 0.5

static var last: StringName = KEYBOARD


## Dispositivo que o evento indica, ou &"" se o evento nao decide (soltar tecla, mouse emulado, deriva da alavanca).
static func classify(event: InputEvent) -> StringName:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return TOUCH
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return &""
	if event is InputEventKey:
		return KEYBOARD if (event as InputEventKey).pressed else &""
	if event is InputEventMouseButton:
		return MOUSE if (event as InputEventMouseButton).pressed else &""
	if event is InputEventMouseMotion:
		return MOUSE if (event as InputEventMouseMotion).relative.length() >= MOUSE_MOTION_MIN else &""
	if event is InputEventJoypadButton:
		return PAD if (event as InputEventJoypadButton).pressed else &""
	if event is InputEventJoypadMotion:
		return PAD if absf((event as InputEventJoypadMotion).axis_value) >= PAD_AXIS_MIN else &""
	return &""


## Registra o evento; devolve true se o ultimo dispositivo mudou.
static func note(event: InputEvent) -> bool:
	var dev := classify(event)
	if dev == &"" or dev == last:
		return false
	last = dev
	return true


## Familia para glifos: teclado e mouse dividem os desenhos (E, Espaco); controle; toque.
static func family(dev: StringName = &"") -> StringName:
	var d := last if dev == &"" else dev
	return KEYBOARD if d == MOUSE else d


static func reset() -> void:
	last = KEYBOARD
