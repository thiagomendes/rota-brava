class_name InputGlyphs
extends RefCounted
## G15 (RB-R1, decisao de Thiago): desenho do botao do aparelho EM USO para uma intencao da Input Map.
## Funcao central: `texture_for(action)` / `glyph_id(action)`. Le o mapeamento real da Input Map:
## - teclado (e mouse): a primeira tecla da intencao -> `key_<nome da tecla>` (nome da Godot, no layout do teclado);
## - controle: o primeiro botao/eixo da intencao -> POSICAO (sul/leste/oeste/norte, start, gatilho direito) desenhada
##   na familia atual (`InputDevice.pad_family`): Xbox, PlayStation, Nintendo ou generico;
## - toque: o botao que a crianca ve na tela para aquela intencao (o toque nao tem Input Map).
## Sem tabela de letras: trocar a tecla/botao na Input Map troca o desenho. SVGs originais em `res://ui/glyphs/svg/`
## (gerados por `tools/glyphs/make_glyphs.py`). Tecla sem desenho proprio: tecla em branco + nome por cima (GlyphView).

const DIR := "res://ui/glyphs/svg/"
## Intencoes com glifo garantido nas dicas do jogo.
const ACTIONS: Array[StringName] = [&"interact", &"jump", &"help", &"pause", &"ui_accept", &"ui_cancel", &"run"]
const BLANK_KEY := &"key_blank"
## Indice de botao do joypad (layout SDL da Godot) -> posicao fisica.
const PAD_POSITIONS := {
	JOY_BUTTON_A: &"south", JOY_BUTTON_B: &"east", JOY_BUTTON_X: &"west", JOY_BUTTON_Y: &"north",
	JOY_BUTTON_START: &"start",
}
const PAD_AXES := {JOY_AXIS_TRIGGER_RIGHT: &"trigger_right"}

static var _cache: Dictionary = {}


## Id do glifo (nome do SVG sem extensao) da intencao no aparelho `glyph_set` (padrao: o atual).
static func glyph_id(action: StringName, glyph_set: StringName = &"") -> StringName:
	var gs := InputDevice.glyph_set() if glyph_set == &"" else glyph_set
	match gs:
		InputDevice.TOUCH:
			return StringName("touch_" + String(action)) if _exists("touch_" + String(action)) else &"touch_interact"
		InputDevice.KEYBOARD:
			return _key_id(action)
		_:
			return _pad_id(action, gs)


static func texture_for(action: StringName, glyph_set: StringName = &"") -> Texture2D:
	return texture(glyph_id(action, glyph_set))


static func texture(id: StringName) -> Texture2D:
	var name := String(id) if _exists(String(id)) else String(BLANK_KEY)
	if not _cache.has(name):
		_cache[name] = load(DIR + name + ".svg") as Texture2D
	return _cache[name]


## Texto para desenhar sobre a tecla em branco (tecla sem SVG proprio); vazio se o glifo ja tem desenho.
static func fallback_text(action: StringName, glyph_set: StringName = &"") -> String:
	var id := glyph_id(action, glyph_set)
	if _exists(String(id)):
		return ""
	var k := _first_key(action)
	return OS.get_keycode_string(k) if k != KEY_NONE else ""


static func has_drawing(id: StringName) -> bool:
	return _exists(String(id))


static func _exists(name: String) -> bool:
	return ResourceLoader.exists(DIR + name + ".svg")


# ---------- teclado ----------

static func _first_key(action: StringName) -> Key:
	if not InputMap.has_action(action):
		return KEY_NONE
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var ek := e as InputEventKey
			if ek.keycode != KEY_NONE:
				return ek.keycode
			# Tecla fisica: o nome segue o layout do teclado da crianca (AZERTY etc.) quando o sistema informa.
			# (o servidor headless dos testes nao sabe o layout: usa a tecla fisica do padrao US.)
			if DisplayServer.get_name() == "headless":
				return ek.physical_keycode
			var k := DisplayServer.keyboard_get_keycode_from_physical(ek.physical_keycode)
			return k if k != KEY_NONE else ek.physical_keycode
	return KEY_NONE


static func _key_id(action: StringName) -> StringName:
	var k := _first_key(action)
	if k == KEY_NONE:
		return BLANK_KEY
	return StringName("key_" + OS.get_keycode_string(k).to_lower().replace(" ", "_"))


# ---------- controle ----------

static func _pad_position(action: StringName) -> StringName:
	if not InputMap.has_action(action):
		return &"other"
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton:
			return PAD_POSITIONS.get((e as InputEventJoypadButton).button_index, &"other")
		if e is InputEventJoypadMotion:
			return PAD_AXES.get((e as InputEventJoypadMotion).axis, &"other")
	return &"other"


static func _pad_id(action: StringName, family: StringName) -> StringName:
	var pos := String(_pad_position(action))
	for name: String in [String(family) + "_" + pos, "pad_" + pos]:
		if _exists(name):
			return StringName(name)
	return &"pad_other"
