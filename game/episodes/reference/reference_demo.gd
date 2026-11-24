class_name ReferenceDemo
extends Control
## Demonstracao unica das referencias do RB-03: elenco, Rastro em 3D, barco e cais, HUD/tipografia, vozes e musica.
## Tudo PROVISORIO; nao altera o estado do episodio. A escolha de producao e de Thiago.

const MENU_SCENE := "res://ui/main_menu.tscn"
const STUDY_SCENE := "res://ui/study/ui_study.tscn"
const IMG := "res://assets/reference/"
const PAGES: Array[StringName] = [&"cast", &"rastro", &"boat", &"hud", &"voice", &"music"]
const THEME_OPTIONS: Array[StringName] = [&"a", &"b", &"c"]
const PAGE_KEYS := {
	&"cast": "ref.page.cast", &"rastro": "ref.page.rastro", &"boat": "ref.page.boat",
	&"hud": "ref.page.hud", &"voice": "ref.page.voice", &"music": "ref.page.music",
}
const EXPRESSION_KEYS: Array[String] = ["ref.rastro.neutral", "ref.rastro.attentive", "ref.rastro.surprised"]
const CHARACTER_LABELS := {"team": "Equipe"}
const INTENT_LABELS := {"normal": "normal", "urgencia": "urgência", "descoberta": "descoberta", "radio": "rádio"}
const MUSIC_KEYS := {&"explore": "ref.music.explore", &"discovery": "ref.music.discovery"}
## Faixas por nome de secao; o arquivo vem do catalogo de audio (AudioDirector.catalog_file), nao de caminho fixo.
const MUSIC: Array[StringName] = [&"explore", &"discovery"]

var page_index: int = 0
var variant: int = 0
var current_page: StringName = &""
var voice_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var last_subtitle: String = ""

var _title: Label
var _page_label: Label
var _content: Control
var _detail: Label
var _hint: Label
var _first_button: Button
var _pivot: Node3D
var _faces: Array[MeshInstance3D] = []
var _caption: Label


func _ready() -> void:
	name = "ReferenceDemo"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.build(&"a")
	var bg := ColorRect.new()
	bg.color = Color("17323a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 96)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 52)
	_title.add_theme_color_override("font_color", Color("ffd24d"))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_page_label = Label.new()
	_page_label.add_theme_font_size_override("font_size", 36)
	head.add_child(_page_label)
	var note := Label.new()
	note.add_theme_font_size_override("font_size", 28)
	note.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	note.text = Loc.t("ref.note")
	box.add_child(note)
	_content = Control.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.clip_contents = false
	box.add_child(_content)
	_detail = Label.new()
	_detail.add_theme_font_size_override("font_size", 30)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(0, 90)
	box.add_child(_detail)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 26)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_hint.text = Loc.t("ref.hint")
	box.add_child(_hint)
	voice_player = AudioStreamPlayer.new()
	voice_player.bus = &"Voz"
	add_child(voice_player)
	music_player = AudioStreamPlayer.new()
	music_player.bus = &"Musica"
	add_child(music_player)
	var start_page := _arg_int("--ref-page")
	show_page(maxi(start_page, 0))
	for i in maxi(_arg_int("--ref-variant"), 0):
		cycle_variant()
	print("[RB] reference_ready")


func _arg_int(flag: String) -> int:
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with(flag + "="):
			return int(arg.trim_prefix(flag + "="))
	return -1


func _process(delta: float) -> void:
	if _pivot != null and is_instance_valid(_pivot):
		_pivot.rotate_y(0.7 * delta)


# ---------- navegacao ----------

func show_page(index: int) -> void:
	page_index = wrapi(index, 0, PAGES.size())
	current_page = PAGES[page_index]
	variant = 0
	voice_player.stop()
	music_player.stop()
	_build_page()


func cycle_variant() -> void:
	variant += 1
	_build_page()


func _input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed():
		return
	if event.is_action_pressed(&"move_right"):
		get_viewport().set_input_as_handled()
		show_page(page_index + 1)
	elif event.is_action_pressed(&"move_left"):
		get_viewport().set_input_as_handled()
		show_page(page_index - 1)
	elif event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		cycle_variant()
	elif event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		leave()


func leave() -> void:
	voice_player.stop()
	music_player.stop()
	print("[RB] reference_leave")
	get_tree().change_scene_to_file(MENU_SCENE)


# ---------- paginas ----------

func _clear() -> void:
	for c in _content.get_children():
		c.queue_free()
	_pivot = null
	_faces.clear()
	_first_button = null
	_caption = null


func _build_page() -> void:
	_clear()
	_title.text = Loc.t("ref.title")
	_page_label.text = "%d/%d · %s" % [page_index + 1, PAGES.size(), Loc.t(String(PAGE_KEYS[current_page]))]
	_detail.text = ""
	match current_page:
		&"cast":
			_page_cast()
		&"rastro":
			_page_rastro()
		&"boat":
			_page_boat()
		&"hud":
			_page_hud()
		&"voice":
			_page_voice()
		&"music":
			_page_music()
	if _first_button != null:
		_first_button.grab_focus.call_deferred()


func _image(path: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path) as Texture2D
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	return t


func _set_caption(text: String) -> void:
	_detail.text = text


func _page_cast() -> void:
	var views := [["elenco_silhuetas.png", "ref.cast.front"], ["elenco_costas.png", "ref.cast.back"], ["elenco_miniatura_48.png", "ref.cast.mini"]]
	var v: Array = views[variant % views.size()]
	_content.add_child(_image(IMG + String(v[0])))
	_set_caption("%s\n%s" % [Loc.t(String(v[1])), Loc.t("ref.rec.cast")])


func _viewport_3d(model_path: String, cam_pos: Vector3, look_at: Vector3) -> Node3D:
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.handle_input_locally = false
	vpc.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9fd3e6")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dfeaf2")
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 40.0
	vp.add_child(cam)
	cam.position = cam_pos
	cam.look_at_from_position(cam_pos, look_at, Vector3.UP)
	_pivot = Node3D.new()
	vp.add_child(_pivot)
	var inst := (load(model_path) as PackedScene).instantiate()
	_pivot.add_child(inst)
	_content.add_child(vpc)
	return inst as Node3D


func _page_rastro() -> void:
	var views := [["rastro_vistas.png", "ref.rastro.views"], ["rastro_jogo.png", "ref.rastro.game"]]
	var mode := variant % 5
	if mode < 3:
		var model := _viewport_3d("res://actors/rastro/rastro.tscn", Vector3(0, 0.9, 2.5), Vector3(0, 0.66, 0))
		for n in model.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh != null and mi.mesh.get_blend_shape_count() > 0:
				_faces.append(mi)
		set_expression(mode)
		_set_caption(Loc.t(EXPRESSION_KEYS[mode]))
	else:
		var v: Array = views[mode - 3]
		_content.add_child(_image(IMG + String(v[0])))
		_set_caption(Loc.t(String(v[1])))


## 0 neutra, 1 atenta, 2 surpresa (shape keys do rosto do Rastro).
func set_expression(index: int) -> void:
	var wanted: String = ["", "atenta", "surpresa"][index]
	for mi in _faces:
		for i in mi.mesh.get_blend_shape_count():
			var shape := String(mi.mesh.get_blend_shape_name(i))
			mi.set_blend_shape_value(i, 1.0 if (shape == wanted and wanted != "") else 0.0)


func _page_boat() -> void:
	var mode := variant % 3
	if mode == 0:
		_viewport_3d("res://actors/boat_model/boat_model.tscn", Vector3(4.0, 2.5, 5.6), Vector3(0, 0.6, 0))
		_set_caption(Loc.t("ref.boat.model"))
	elif mode == 1:
		_content.add_child(_image(IMG + "cais_estudo.png"))
		_set_caption(Loc.t("ref.boat.study"))
	else:
		_content.add_child(_image(IMG + "cais_jogo.png"))
		_set_caption(Loc.t("ref.boat.game"))


func _page_hud() -> void:
	var option := THEME_OPTIONS[variant % THEME_OPTIONS.size()]
	var page := VBoxContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 12)
	_content.add_child(page)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)
	page.add_child(row)
	for r in [["16x9", "ref.hud.ratio_169"], ["20x9", "ref.hud.ratio_209"], ["4x3", "ref.hud.ratio_43"]]:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var img := _image("%shud_%s_%s.png" % [IMG, option, r[0]])
		img.set_anchors_preset(Control.PRESET_TOP_LEFT)
		img.size_flags_vertical = Control.SIZE_EXPAND_FILL
		img.custom_minimum_size = Vector2(0, 200)
		col.add_child(img)
		var l := Label.new()
		l.text = Loc.t(String(r[1]))
		l.add_theme_font_size_override("font_size", 26)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
		row.add_child(col)
	var open := Button.new()
	open.text = Loc.t("ref.hud.open")
	open.custom_minimum_size = Vector2(520, 112)
	open.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	open.pressed.connect(open_study)
	open.name = "OpenStudy"
	page.add_child(open)
	_first_button = open
	_set_caption("%s\n%s" % [Loc.t("ref.hud.option", {"name": UiTheme.NAMES[option]}), Loc.t("ref.rec.hud")])


func open_study() -> void:
	get_tree().change_scene_to_file(STUDY_SCENE)


func _page_voice() -> void:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	list.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.add_child(list)
	for entry: Dictionary in VoiceCatalog.all_lines():
		var b := Button.new()
		var who := Loc.t("ref.voice.meta", {
			"character": String(CHARACTER_LABELS.get(String(entry.get("character", "")), entry.get("character", ""))),
			"intent": String(INTENT_LABELS.get(String(entry.get("intent", "")), entry.get("intent", ""))),
			"voice": String(entry.get("voice", ""))})
		b.text = "%s %s\n%s" % [Loc.t("ref.voice.play"), Loc.t(String(entry.get("subtitle", ""))), who]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 128)
		b.add_theme_font_size_override("font_size", 28)
		b.clip_text = false
		b.pressed.connect(play_voice.bind(String(entry.get("id", ""))))
		list.add_child(b)
		if _first_button == null:
			_first_button = b
	_set_caption(Loc.t("ref.rec.voice"))


func play_voice(id: String) -> void:
	music_player.stop()
	var entry := VoiceCatalog.lookup(id)
	var stream := VoiceCatalog.stream_for(id)
	last_subtitle = Loc.t(String(entry.get("subtitle", id)))
	if stream == null:
		_set_caption("%s\n%s" % [last_subtitle, Loc.t("ref.voice.missing")])
		return
	voice_player.stream = stream
	voice_player.play()
	_set_caption("%s\n%s" % [last_subtitle, Loc.t("ref.rec.voice")])
	print("[RB] reference_voice %s" % id)


func _page_music() -> void:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 14)
	list.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.add_child(list)
	for key: StringName in MUSIC:
		var b := Button.new()
		b.text = Loc.t(String(MUSIC_KEYS[key]))
		b.custom_minimum_size = Vector2(0, 120)
		b.pressed.connect(play_music.bind(key))
		list.add_child(b)
		if _first_button == null:
			_first_button = b
	var stop := Button.new()
	stop.text = Loc.t("ref.music.stop")
	stop.custom_minimum_size = Vector2(0, 120)
	stop.pressed.connect(func() -> void: music_player.stop())
	list.add_child(stop)
	_set_caption(Loc.t("ref.rec.music"))


func play_music(key: StringName) -> void:
	voice_player.stop()
	var path := AudioDirector.catalog_file(String(key))
	var stream := load(path) as AudioStream if path != "" and ResourceLoader.exists(path) else null
	if stream == null:
		return
	music_player.stream = stream
	music_player.play()
	print("[RB] reference_music %s" % key)
