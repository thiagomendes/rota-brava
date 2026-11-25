extends RefCounted
## Retratos e icones do Ep01 v3 (RB-R1 E7, ux): todo falante da ficha tem retrato na legenda que nao e o caderno
## (render do modelo ou retrato-icone da marca), o HUD acha o mesmo falante pela chave, todo icone referenciado pelo
## episodio existe, os barquinhos da festa usam estrela/lua/peixe/flor e os icones novos ficam legiveis a 48 px
## (cobertura e contorno escuro). Mutacao: sem o retrato-icone da Dona Amora o teste reprova.
## Nao comprova aparencia: isso fica nas capturas (captures/e7_icones/).

const DIALOGUE := "res://episodes/ep01/v3/ep01_v3_dialogue.json"
const MISSIONS := "res://episodes/ep01/v3/ep01_v3_missions.json"
const SOURCES: Array[String] = ["res://episodes/ep01/v3/ep01_v3_main.gd", "res://episodes/ep01/v3/ep01_v3_land.gd",
	"res://episodes/ep01/v3/ep01_v3_late.gd"]
const NEW_ICONS: Array[StringName] = [&"moon", &"fish", &"flower", &"vendor", &"radio", &"carabiner"]
const OUTLINE := Color("123A5E")

var r


func run(runner) -> void:
	r = runner
	await _speaker_checks()
	_icon_refs()
	_boat_icons()
	_legibility()


func _hud() -> Hud:
	var hud := Hud.new()
	r.tree.root.add_child(hud)
	# como Ep01V3Main: retratos renderizados dos 3 herois
	for member: StringName in Ep01V3Main.PORTRAIT_FILES:
		var path := "res://ui/portraits/%s_neutra.png" % Ep01V3Main.PORTRAIT_FILES[member]
		if ResourceLoader.exists(path):
			hud.set_portrait_texture(member, load(path) as Texture2D)
	return hud


## Retrato efetivo da legenda: "tex" (render) ou o nome do pictograma; "" se cai no caderno ou o SVG nao existe.
func _effective(hud: Hud, who: StringName) -> String:
	if hud.speaker_texture(who) != null:
		return "tex"
	var k := hud.speaker_icon(who)
	if k == &"notebook" or not IconView.has_icon(k) or not FileAccess.file_exists(IconView.icon_path(k)):
		return ""
	return String(k)


func _speaker_checks() -> void:
	var sheet := Ep01V3Dialogue.sheet()
	var hud := _hud()
	await r.frames(2)
	var speakers: Dictionary = sheet.get("speakers", {})
	var lines: Dictionary = sheet.get("lines", {})
	var bad: Array[String] = []
	var mismatch: Array[String] = []
	var first: Dictionary = {}
	for key: String in lines:
		var who := StringName(str((lines[key] as Dictionary).get("speaker", "")))
		if not first.has(who):
			first[who] = key
		if hud.speaker_for(key) != who:
			mismatch.append("%s->%s" % [key, hud.speaker_for(key)])
	for who: Variant in speakers:
		if not first.has(StringName(str(who))):
			first[StringName(str(who))] = ""
	for who: StringName in first:
		if _effective(hud, who) == "":
			bad.append(String(who))
	r.check(first.size() >= 7, "v3 E7: ficha com %d falantes (3 herois + capitao, filhote, Dona Amora, Farol 7)" % first.size())
	r.check(bad.is_empty(), "v3 E7: todo falante tem retrato na legenda que nao e o caderno %s" % str(bad))
	r.check(mismatch.is_empty(), "v3 E7: o HUD acha pela chave o mesmo falante da ficha %s" % str(mismatch))
	r.check(_effective(hud, &"captain") == "tex" and _effective(hud, &"pup") == "tex",
		"v3 E7: capitao e filhote usam retrato renderizado do modelo 3D")
	r.check(_effective(hud, &"vendor") == "vendor" and _effective(hud, &"radio") == "radio",
		"v3 E7: Dona Amora e Farol 7 usam retrato-icone da marca (vendor, radio)")
	# portrait/icon declarados na ficha existem
	var missing: Array[String] = []
	for who: Variant in speakers:
		var s: Dictionary = speakers[who]
		if s.has("portrait") and not ResourceLoader.exists(str(s["portrait"])):
			missing.append(str(s["portrait"]))
		if s.has("icon") and not IconView.has_icon(StringName(str(s["icon"]))):
			missing.append(str(s["icon"]))
	r.check(missing.is_empty(), "v3 E7: retratos e icones da ficha existem %s" % str(missing))
	# a legenda mostra mesmo o retrato do falante
	var portrait := hud.find_child("SpeakerPortrait", true, false) as IconView
	var shown: Array[String] = []
	for who: StringName in [&"captain", &"pup", &"vendor", &"radio"]:
		var key: String = first.get(who, "")
		if key == "":
			shown.append("%s sem fala" % who)
			continue
		hud.clear_speech()
		await r.frames(2)
		hud.say(key)
		await r.frames(2)
		var ok := portrait != null and portrait.is_visible_in_tree() and portrait.kind != &"notebook"
		if who in [&"captain", &"pup"]:
			ok = ok and portrait.texture_override != null
		else:
			ok = ok and portrait.texture_override == null and portrait.kind == hud.speaker_icon(who)
		if not ok:
			shown.append(String(who))
	r.check(shown.is_empty(), "v3 E7: a legenda de capitao, filhote, Dona Amora e Farol 7 mostra o retrato deles %s" % str(shown))
	# mutacao: sem o SVG da Dona Amora o falante volta a nao ter retrato e o teste reprova
	var victim := ProjectSettings.globalize_path(IconView.icon_path(&"vendor"))
	var moved := DirAccess.rename_absolute(victim, victim + ".mut") == OK
	r.check(moved and _effective(hud, &"vendor") == "", "mutacao: sem vendor.svg a Dona Amora fica sem retrato e reprova")
	if moved:
		DirAccess.rename_absolute(victim + ".mut", victim)
	r.check(_effective(hud, &"vendor") == "vendor", "mutacao restaurada: vendor.svg de volta")
	hud.clear_speech()
	hud.queue_free()
	await r.frames(1)


func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _collect_missions(v: Variant, out: Array[String]) -> void:
	if v is Dictionary:
		for k: Variant in v:
			if str(k) == "icon" and v[k] is String:
				out.append(str(v[k]))
			else:
				_collect_missions(v[k], out)
	elif v is Array:
		for x: Variant in v:
			_collect_missions(x, out)


func _icon_refs() -> void:
	var refs: Array[String] = []
	var sheet := Ep01V3Dialogue.sheet()
	for key: String in sheet.get("lines", {}):
		for e: Variant in (sheet["lines"][key] as Dictionary).get("emotes", []):
			refs.append(str(e))
	for who: Variant in sheet.get("speakers", {}):
		var s: Dictionary = sheet["speakers"][who]
		if s.has("icon"):
			refs.append(str(s["icon"]))
	_collect_missions(_json(MISSIONS), refs)
	for k: StringName in Ep01V3Pieces.FESTA_BOAT_ICONS:
		refs.append(String(k))
	for d: Dictionary in [Hud.SKILL_ICONS, Hud.SPEAKER_ICONS]:
		for k: Variant in d.values():
			refs.append(str(k))
	# pontos de acao das missoes: _spot(id, pos, &"icone", "ui.action...")
	var re := RegEx.create_from_string("&\"(\\w+)\",\\s*\"ui\\.action\\.")
	var from_code := 0
	for src in SOURCES:
		for m in re.search_all(FileAccess.get_file_as_string(src)):
			refs.append(m.get_string(1))
			from_code += 1
	var missing: Array[String] = []
	for k in refs:
		if not IconView.has_icon(StringName(k)) and not missing.has(k):
			missing.append(k)
	r.check(from_code >= 10, "v3 E7: icones dos pontos de acao lidos do codigo (%d)" % from_code)
	r.check(missing.is_empty(), "v3 E7: todo icone referenciado pelo Ep01 v3 existe (%d refs) %s" % [refs.size(), str(missing)])


func _boat_icons() -> void:
	var icons := Ep01V3Pieces.FESTA_BOAT_ICONS
	var want: Array[StringName] = [&"star", &"moon", &"fish", &"flower"]
	r.check(icons == want,
		"v3 E7: barquinhos da festa com estrela, lua, peixe e flor %s" % str(icons))
	r.check(Ep01V3Late.FESTA_ICONS == icons, "v3 E7: o M7/M8 usa os icones dos barquinhos das pecas")
	var parent := Node3D.new()
	r.tree.root.add_child(parent)
	var ok := true
	for i in icons.size():
		var s := Ep01V3Pieces.boat_icon(parent, "B%d" % i, icons[i])
		ok = ok and s.texture != null and s.texture == IconView.texture_for(icons[i])
	r.check(ok, "v3 E7: placa do barquinho carrega o SVG de cada icone")
	parent.queue_free()


## Luminancia relativa (WCAG): sRGB -> linear.
func _lum(c: Color) -> float:
	var l := c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


## Rasteriza o SVG a 48 px e mede: cobertura opaca e contorno escuro (contraste >= 3:1 com o preenchimento).
func _legibility() -> void:
	var bad: Array[String] = []
	for k in NEW_ICONS:
		var svg := FileAccess.get_file_as_string(IconView.icon_path(k))
		var img := Image.new()
		if svg.is_empty() or img.load_svg_from_string(svg, 48.0 / 256.0) != OK:
			bad.append("%s nao rasteriza" % k)
			continue
		var opaque := 0
		var dark := 0
		var light := 0.0
		var n := img.get_width() * img.get_height()
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a < 0.6:
					continue
				opaque += 1
				if _lum(c) < 0.08:
					dark += 1
				light = maxf(light, _lum(c))
		var cover := float(opaque) / float(n)
		var ratio := (light + 0.05) / (_lum(OUTLINE) + 0.05)
		if img.get_width() != 48 or cover < 0.25 or dark < 40 or ratio < 3.0:
			bad.append("%s %dpx cobre %.0f%% escuro %d contraste %.1f" % [k, img.get_width(), cover * 100.0, dark, ratio])
	r.check(bad.is_empty(), "v3 E7: icones novos legiveis a 48 px (cobertura >= 25%%, contorno escuro, contraste do mais claro com o contorno >= 3:1) %s" % str(bad))
