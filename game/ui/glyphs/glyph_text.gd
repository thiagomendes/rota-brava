class_name GlyphText
extends HBoxContainer
## G15: texto do catalogo com marcadores de intencao (`{interact}`, `{ui_accept}`...) desenhados como glifo do
## aparelho em uso ao lado das palavras. O catalogo nunca escreve tecla fixa; quem troca o desenho e o GlyphView.

const MARKER := "\\{([a-z_]+)\\}"

var font_size: int = 30
var font_color: Color = Color.WHITE
var label_variant: StringName = &""
var raw: String = ""
var _labels: Array[Label] = []
var _glyphs: Array[GlyphView] = []
static var _re: RegEx


func _init(p_font_size: int = 30, p_color: Color = Color.WHITE, p_variant: StringName = &"") -> void:
	font_size = p_font_size
	font_color = p_color
	label_variant = p_variant
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", int(p_font_size * 0.35))


## Intencoes citadas pelos marcadores de `text` (so as que existem na Input Map).
static func markers(text: String) -> Array[StringName]:
	if _re == null:
		_re = RegEx.create_from_string(MARKER)
	var out: Array[StringName] = []
	for m in _re.search_all(text):
		var a := StringName(m.get_string(1))
		if InputMap.has_action(a):
			out.append(a)
	return out


func set_text(text: String) -> void:
	raw = text
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_labels.clear()
	_glyphs.clear()
	if _re == null:
		_re = RegEx.create_from_string(MARKER)
	var at := 0
	for m in _re.search_all(text):
		var a := StringName(m.get_string(1))
		if not InputMap.has_action(a):
			continue
		_add_label(text.substr(at, m.get_start() - at))
		var g := GlyphView.new(a, roundf(font_size * 1.55))
		g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(g)
		_glyphs.append(g)
		at = m.get_end()
	_add_label(text.substr(at))


func _add_label(part: String) -> void:
	var t := part.strip_edges()
	if t.is_empty():
		return
	var l := Label.new()
	l.text = t
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if label_variant != &"":
		l.theme_type_variation = label_variant
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", font_color)
	add_child(l)
	_labels.append(l)


## Texto visivel sem os glifos (testes).
func plain_text() -> String:
	var parts: PackedStringArray = []
	for l in _labels:
		parts.append(l.text)
	return " ".join(parts)


func glyphs() -> Array[GlyphView]:
	return _glyphs
