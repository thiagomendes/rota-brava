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

## G15: familias de controle (desenho dos botoes). Sem acerto pelo nome/guid, generico.
const XBOX := &"xbox"
const PLAYSTATION := &"playstation"
const NINTENDO := &"nintendo"
const GENERIC := &"generic"
## Fabricante no guid SDL (caracteres 8..11, little-endian): 045e, 054c, 057e.
const GUID_VENDORS := {"5e04": XBOX, "4c05": PLAYSTATION, "7e05": NINTENDO}
## Trechos do nome do joypad (minusculas) por familia. A ordem importa: Nintendo antes de "pro controller" generico.
const NAME_HINTS := {
	XBOX: ["xbox", "xinput", "x-box", "x360", "microsoft"],
	PLAYSTATION: ["playstation", "dualshock", "dualsense", "ps3", "ps4", "ps5", "sony"],
	NINTENDO: ["nintendo", "switch", "joy-con", "joycon", "wii"],
}


## Sinal de troca (classe estatica nao tem sinal proprio): emitido quando muda o aparelho ou a familia do controle.
class Events extends RefCounted:
	signal changed(device: StringName, pad_family: StringName)


static var last: StringName = KEYBOARD
## Familia do ultimo controle usado (vale quando `last == PAD`).
static var pad_family: StringName = GENERIC
## Testes/capturas: se nao vazio, substitui `Input.get_joy_name()` (e ignora o guid) na deteccao da familia.
static var joy_name_override: String = ""
static var events: Events = Events.new()


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


## Registra o evento; devolve true se o ultimo dispositivo mudou (ou, no controle, a familia). Emite `events.changed`.
static func note(event: InputEvent) -> bool:
	var dev := classify(event)
	if dev == &"":
		return false
	var fam := pad_family
	if dev == PAD:
		fam = family_of_device(event.device)
	if dev == last and fam == pad_family:
		return false
	set_device(dev, fam)
	return true


## Troca o aparelho (e a familia do controle) e avisa. Usado por `note` e por testes/capturas.
static func set_device(dev: StringName, fam: StringName = &"") -> void:
	var f := pad_family if fam == &"" else fam
	if dev == last and f == pad_family:
		return
	last = dev
	pad_family = f
	events.changed.emit(last, pad_family)


## Familia do controle `device` pelo nome e guid da Godot (ou `joy_name_override`).
static func family_of_device(device: int) -> StringName:
	if not joy_name_override.is_empty():
		return detect_family(joy_name_override, "")
	return detect_family(Input.get_joy_name(device), Input.get_joy_guid(device))


## Familia por nome e guid; sem acerto, generico. O nome decide antes do guid (adaptadores mudam o fabricante).
static func detect_family(joy_name: String, guid: String) -> StringName:
	var n := joy_name.to_lower()
	for fam: StringName in NAME_HINTS:
		for hint: String in NAME_HINTS[fam]:
			if hint in n:
				return fam
	var g := guid.to_lower()
	if g.length() >= 12:
		return GUID_VENDORS.get(g.substr(8, 4), GENERIC)
	return GENERIC


## Desenho a usar: teclado (inclui mouse), toque, ou a familia do controle.
static func glyph_set() -> StringName:
	match last:
		PAD:
			return pad_family
		TOUCH:
			return TOUCH
		_:
			return KEYBOARD


## Familia para glifos: teclado e mouse dividem os desenhos (E, Espaco); controle; toque.
static func family(dev: StringName = &"") -> StringName:
	var d := last if dev == &"" else dev
	return KEYBOARD if d == MOUSE else d


static func reset() -> void:
	joy_name_override = ""
	set_device(KEYBOARD, GENERIC)
