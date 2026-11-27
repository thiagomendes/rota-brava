class_name GlyphView
extends Control
## G15: desenho do botao de uma intencao no aparelho em uso. Escuta `InputDevice.events.changed` e troca no mesmo
## quadro; tambem registra os eventos que chegam (`InputDevice.note`), para funcionar em telas sem HUD (menus).
## `hide_on_touch`: some no toque (selo em cima de um botao que a crianca ja esta tocando).

@export var action: StringName = &"interact":
	set(value):
		action = value
		refresh()
@export var hide_on_touch: bool = false:
	set(value):
		hide_on_touch = value
		refresh()

var _tex: Texture2D
var _id: StringName = &""
var _fallback: String = ""


func _init(p_action: StringName = &"interact", px: float = 56.0, p_hide_on_touch: bool = false) -> void:
	name = "Glyph_" + String(p_action)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(px, px)
	action = p_action
	hide_on_touch = p_hide_on_touch


func _enter_tree() -> void:
	if not InputDevice.events.changed.is_connected(_on_device_changed):
		InputDevice.events.changed.connect(_on_device_changed)
	refresh()


func _exit_tree() -> void:
	if InputDevice.events.changed.is_connected(_on_device_changed):
		InputDevice.events.changed.disconnect(_on_device_changed)


func _input(event: InputEvent) -> void:
	InputDevice.note(event)


func _on_device_changed(_dev: StringName, _fam: StringName) -> void:
	refresh()


## Id do glifo desenhado agora (testes).
func glyph_id() -> StringName:
	return _id


func refresh() -> void:
	_id = InputGlyphs.glyph_id(action)
	_tex = InputGlyphs.texture(_id)
	_fallback = InputGlyphs.fallback_text(action)
	var on_touch := InputDevice.glyph_set() == InputDevice.TOUCH
	visible = not (hide_on_touch and on_touch)
	# Teclas largas (Espaco, Shift, Esc, Enter) ocupam mais largura na mesma altura.
	if _tex != null:
		var h := custom_minimum_size.y
		custom_minimum_size.x = h * float(_tex.get_width()) / maxf(1.0, float(_tex.get_height()))
	queue_redraw()


func _draw() -> void:
	if _tex == null:
		return
	var h := size.y
	var w := h * float(_tex.get_width()) / maxf(1.0, float(_tex.get_height()))
	var r := Rect2(Vector2((size.x - w) * 0.5, 0.0), Vector2(w, h))
	draw_texture_rect(_tex, r, false)
	if not _fallback.is_empty():
		var f := get_theme_default_font()
		var fs := int(h * 0.42)
		var ts := f.get_string_size(_fallback, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var sx := minf(1.0, w * 0.7 / maxf(1.0, ts.x))
		draw_set_transform(r.get_center() - Vector2(ts.x * sx * 0.5, h * 0.04), 0.0, Vector2(sx, sx))
		draw_string(f, Vector2(0, fs * 0.35), _fallback, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("0B2440"))
		draw_set_transform(Vector2.ZERO)
