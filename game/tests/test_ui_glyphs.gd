extends RefCounted
## G15 (RB-R1, decisao de Thiago): as dicas mostram o desenho do aparelho em uso. Injeta eventos de verdade
## (teclado, controle por familia com `InputDevice.joy_name_override`, toque) no HUD e confere, no MESMO quadro, o glifo
## do botao de agir, do "pular" da cena e do "Segure para apagar". Le a Input Map de verdade (mutacao: trocar o
## botao muda o desenho). Confere o catalogo sem tecla fixa e o contraste dos glifos (ThemeV2.contrast_ratio).
## Nao comprova o que se ve na tela (ver capturas em captures/g15/).

const FAMILIES := {
	"Xbox Wireless Controller": [&"xbox", &"xbox_west"],
	"PS5 Controller": [&"playstation", &"playstation_west"],
	"Nintendo Switch Pro Controller": [&"nintendo", &"nintendo_west"],
	"USB Gamepad 8BitPad": [&"generic", &"generic_west"],
}
## Textos de ferramentas de desenvolvimento (abertas so por linha de comando, nunca pela crianca): ficam de fora.
const DEV_ONLY_KEYS := ["ref.hint", "study.caption", "wv2.help"]
## Fundos das dicas que levam glifo: selo/pilula (NAVY) e barras de cena (NAVY_DEEP).
const HINT_BACKS := {"NAVY": ThemeV2.NAVY, "NAVY_DEEP": ThemeV2.NAVY_DEEP}

var r


func run(runner) -> void:
	r = runner
	_family_detection_case()
	_coverage_case()
	_input_map_case()
	_catalog_case()
	_contrast_case()
	await _live_case()
	InputDevice.reset()


func _family_detection_case() -> void:
	for n: String in FAMILIES:
		r.check(InputDevice.detect_family(n, "") == FAMILIES[n][0], "G15 familia pelo nome: '%s' -> %s" % [n, FAMILIES[n][0]])
	r.check(InputDevice.detect_family("", "030000005e0400008e02000014010000") == InputDevice.XBOX, "G15 familia pelo guid: 045e -> xbox")
	r.check(InputDevice.detect_family("Wireless Controller", "050000004c050000e60c000000810000") == InputDevice.PLAYSTATION,
		"G15 familia pelo guid: 054c -> playstation (nome sem dica)")
	r.check(InputDevice.detect_family("", "030000007e0500000920000011810000") == InputDevice.NINTENDO, "G15 familia pelo guid: 057e -> nintendo")
	r.check(InputDevice.detect_family("", "") == InputDevice.GENERIC and InputDevice.detect_family("?", "xyz") == InputDevice.GENERIC,
		"G15 sem acerto: generico")


## Toda intencao das dicas tem desenho proprio em todo aparelho, pela Input Map atual.
func _coverage_case() -> void:
	var missing: Array[String] = []
	for gs: StringName in [InputDevice.KEYBOARD, InputDevice.TOUCH, InputDevice.XBOX, InputDevice.PLAYSTATION,
			InputDevice.NINTENDO, InputDevice.GENERIC]:
		for a: StringName in InputGlyphs.ACTIONS:
			var id := InputGlyphs.glyph_id(a, gs)
			if not InputGlyphs.has_drawing(id) or InputGlyphs.texture(id) == null:
				missing.append("%s/%s=%s" % [gs, a, id])
	r.check(missing.is_empty(), "G15 7 intencoes x 6 aparelhos com SVG proprio (faltam: %s)" % str(missing))
	var expect := {
		[&"interact", &"keyboard"]: &"key_e", [&"jump", &"keyboard"]: &"key_space", [&"run", &"keyboard"]: &"key_shift",
		[&"help", &"keyboard"]: &"key_h", [&"pause", &"keyboard"]: &"key_escape", [&"ui_accept", &"keyboard"]: &"key_enter",
		[&"jump", &"xbox"]: &"xbox_south", [&"ui_cancel", &"playstation"]: &"playstation_east",
		[&"help", &"nintendo"]: &"nintendo_north", [&"pause", &"xbox"]: &"pad_start", [&"pause", &"nintendo"]: &"nintendo_start",
		[&"run", &"playstation"]: &"playstation_trigger_right", [&"interact", &"touch"]: &"touch_interact",
	}
	for k: Array in expect:
		var got := InputGlyphs.glyph_id(k[0], k[1])
		r.check(got == expect[k], "G15 glifo %s no %s = %s (%s)" % [k[0], k[1], expect[k], got])


## Le a Input Map de verdade: trocar o botao/tecla da intencao troca o desenho (sem tabela de letras).
func _input_map_case() -> void:
	var keep := InputMap.action_get_events(&"interact")
	InputMap.action_erase_events(&"interact")
	var k := InputEventKey.new()
	k.physical_keycode = KEY_F
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_Y
	InputMap.action_add_event(&"interact", k)
	InputMap.action_add_event(&"interact", b)
	var kid := InputGlyphs.glyph_id(&"interact", InputDevice.KEYBOARD)
	r.check(kid == &"key_f" and not InputGlyphs.has_drawing(kid) and InputGlyphs.fallback_text(&"interact", InputDevice.KEYBOARD) == "F"
		and InputGlyphs.texture(kid) != null, "G15 mutacao Input Map: interact em F -> tecla em branco com 'F' (%s)" % kid)
	r.check(InputGlyphs.glyph_id(&"interact", InputDevice.XBOX) == &"xbox_north"
		and InputGlyphs.glyph_id(&"interact", InputDevice.PLAYSTATION) == &"playstation_north",
		"G15 mutacao Input Map: interact no botao de cima -> Y / triangulo")
	InputMap.action_erase_events(&"interact")
	for e in keep:
		InputMap.action_add_event(&"interact", e)
	r.check(InputGlyphs.glyph_id(&"interact", InputDevice.KEYBOARD) == &"key_e"
		and InputGlyphs.glyph_id(&"interact", InputDevice.XBOX) == &"xbox_west", "G15 Input Map restaurada (E / botao da esquerda)")


# ---------- catalogo ----------

static func fixed_key_hits(cat: Dictionary) -> Array[String]:
	var pats := [
		"\\bE\\s*/\\s*X\\b", "\\b(Espaço|Espaco|Space|Shift|Esc|Escape|Enter|Ctrl|Tab|Alt|WASD|PgUp|PgDn|Backspace)\\b",
		"(?<![-\\w])(LB|RB|LT|RT|L1|L2|R1|R2|ZL|ZR)(?![-\\w])", "\\b[Bb]ot[aã]o (A|B|X|Y|Start|Select|Menu)\\b",
		"\\b(Teclado|Controle)\\s*:", "\\b[Tt]ecla [A-Z0-9]\\b", "(^|[\\s(·|])[A-Z0-9](\\s*/\\s*[A-Z0-9])*\\s*:\\s",
		"\\(\\s*[A-Z]\\s*\\)", "[←→↑↓]", "\\b(Start|Select)\\b",
	]
	var hits: Array[String] = []
	for key: String in cat:
		for p: String in pats:
			if RegEx.create_from_string(p).search(str(cat[key])) != null:
				hits.append("%s: %s" % [key, cat[key]])
				break
	return hits


func _catalog_case() -> void:
	var cat: Dictionary = {}
	for f in DirAccess.get_files_at("res://i18n"):
		if f.ends_with(".json"):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/" + f))
			if d is Dictionary:
				cat.merge(d)
	for k: String in DEV_ONLY_KEYS:
		cat.erase(k)
	var hits := fixed_key_hits(cat)
	r.check(cat.size() > 500 and hits.is_empty(), "G15 catalogo (%d textos) sem tecla/botao fixo (achados: %s)" % [cat.size(), str(hits)])
	# mutacao: o detector pega os textos antigos
	var old := {"a": "E / X: pular a cena", "b": "E: pular a abertura", "c": "Teclado: Esc / Controle: botão Start",
		"d": "Repetir instrução (H)", "e": "Segure Espaço"}
	r.check(fixed_key_hits(old).size() == old.size(), "G15 mutacao: os 5 textos antigos seriam reprovados (%d)" % fixed_key_hits(old).size())
	for pair: Array in [["ui.skip", &"interact"], ["ui.cutscene.skip", &"interact"], ["ui.slots.erase_hold", &"ui_accept"]]:
		r.check(GlyphText.markers(Loc.t(pair[0])) == [pair[1]], "G15 '%s' usa o marcador {%s}" % [pair[0], pair[1]])


# ---------- contraste ----------

func _attr(svg: String, name: String) -> Color:
	var m := RegEx.create_from_string(name + "=\"(#[0-9A-Fa-f]{6})\"").search(svg)
	return Color(m.get_string(1)) if m != null else Color(0, 0, 0, 0)


func _contrast_case() -> void:
	var bad: Array[String] = []
	var n := 0
	for f in DirAccess.get_files_at(InputGlyphs.DIR):
		if not f.ends_with(".svg"):
			continue
		n += 1
		var svg := FileAccess.get_file_as_string(InputGlyphs.DIR + f)
		var out := _attr(svg, "data-out")
		var body := _attr(svg, "data-body")
		var sym := _attr(svg, "data-sym")
		if out.a == 0.0 or body.a == 0.0 or sym.a == 0.0:
			bad.append(f + ": sem data-out/body/sym")
			continue
		# as cores declaradas estao mesmo no desenho
		for c: Color in [out, body, sym]:
			if not ("\"#" + c.to_html(false)).to_lower() in svg.to_lower():
				bad.append("%s: cor %s declarada e nao desenhada" % [f, c.to_html(false)])
		for back: String in HINT_BACKS:
			var cr := ThemeV2.contrast_ratio(out, HINT_BACKS[back])
			if cr < 4.5:
				bad.append("%s: contorno x %s = %.2f" % [f, back, cr])
		var cs := ThemeV2.contrast_ratio(sym, body)
		if cs < 4.5:
			bad.append("%s: simbolo x corpo = %.2f" % [f, cs])
	r.check(n >= 40 and bad.is_empty(), "G15 contraste >= 4,5:1 em %d glifos (contorno x fundo da dica e simbolo x botao) %s" % [n, str(bad)])
	r.check(ThemeV2.contrast_ratio(Color("1D5FC4"), ThemeV2.NAVY) < 4.5, "G15 mutacao: um contorno azul sobre o selo seria reprovado")


# ---------- ao vivo: eventos de verdade, troca no mesmo quadro ----------

func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return e


func _pad_button(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = b
	e.pressed = true
	return e


func _live_case() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(1920, 1080)
	sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	r.tree.root.add_child(sv)
	var hud := Hud.new()
	sv.add_child(hud)
	var cs := Ep01V3Cutscene.new()
	sv.add_child(cs)
	cs._build_bars()
	var slots := SlotScreen.new()
	sv.add_child(slots)
	await r.frames(2)
	hud.show_prompt(Loc.t("ui.action.examine"), &"magnifier")
	var skip_g: GlyphView = cs.skip_hint().glyphs()[0]
	var slot_g: GlyphView = (slots.hints[0].get_node("HintText") as GlyphText).glyphs()[0]
	var hud_skip_g: GlyphView = hud.skip_hint().glyphs()[0]
	var seen: Array = []
	var on_change := func(d: StringName, f: StringName) -> void: seen.append([d, f])
	InputDevice.events.changed.connect(on_change)

	sv.push_input(_key(KEY_E))
	r.check(hud.glyph_id() == &"key_e" and skip_g.glyph_id() == &"key_e" and hud_skip_g.glyph_id() == &"key_e"
		and slot_g.glyph_id() == &"key_enter", "G15 teclado: agir E, pular E, apagar Enter (%s %s %s)" % [hud.glyph_id(), skip_g.glyph_id(), slot_g.glyph_id()])
	for n: String in FAMILIES:
		InputDevice.joy_name_override = n
		seen.clear()
		sv.push_input(_pad_button(JOY_BUTTON_X))
		var fam: StringName = FAMILIES[n][0]
		var want: StringName = FAMILIES[n][1]
		# sem esperar quadro: a troca acontece no mesmo quadro do evento
		r.check(hud.glyph_id() == want and skip_g.glyph_id() == want and slot_g.glyph_id() == StringName(String(want).replace("west", "south")),
			"G15 %s: agir/pular %s, apagar %s, no mesmo quadro" % [fam, hud.glyph_id(), slot_g.glyph_id()])
		r.check(seen.size() == 1 and seen[0] == [InputDevice.PAD, fam], "G15 %s: sinal de troca emitido uma vez %s" % [fam, str(seen)])
	# deriva de alavanca nao troca
	sv.push_input(_key(KEY_E))
	var drift := InputEventJoypadMotion.new()
	drift.axis = JOY_AXIS_LEFT_X
	drift.axis_value = 0.2
	seen.clear()
	sv.push_input(drift)
	r.check(hud.glyph_id() == &"key_e" and seen.is_empty(), "G15 deriva da alavanca (0,2) nao troca o desenho")
	drift.axis_value = 0.9
	sv.push_input(drift)
	r.check(hud.glyph_id() == &"generic_west", "G15 alavanca inclinada de verdade troca para o controle (%s)" % hud.glyph_id())
	# toque: o selo do botao de agir some (o botao e o alvo); as dicas de texto mostram a mao
	var t := InputEventScreenTouch.new()
	t.pressed = true
	t.position = Vector2(900, 500)
	sv.push_input(t)
	var badge := hud.find_child("GlyphBadge", true, false) as Control
	r.check(hud.glyph_id() == &"" and not badge.visible and skip_g.glyph_id() == &"touch_interact"
		and slot_g.glyph_id() == &"touch_ui_accept", "G15 toque: sem selo no botao de agir; pular com a mao (%s, %s)" % [skip_g.glyph_id(), slot_g.glyph_id()])
	# volta ao teclado; selos da pausa/fim/cartao acompanham
	sv.push_input(_key(KEY_E))
	var ids: Array[StringName] = []
	for g in hud._button_glyphs:
		ids.append(g.glyph_id())
	r.check(ids == [&"key_e", &"key_enter", &"key_escape"], "G15 selos dos paineis: confirmar E, rever Enter, voltar Esc %s" % str(ids))
	r.check(hud._help_glyph.glyph_id() == &"key_h", "G15 ajuda: selo H no disco da ajuda")
	InputDevice.events.changed.disconnect(on_change)
	InputDevice.joy_name_override = ""
	sv.queue_free()
	await r.frames(2)
