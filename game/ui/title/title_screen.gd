class_name TitleScreen
extends Control
## Tela-titulo v2 (RB-R1): fundo = arte-chave 3D escolhida por Thiago no G8 (cena B "Noite das lanternas":
## vila em festa, farol, barco amarelo e o trio, animada de leve) + logo C em versao noite, botoes grandes com
## pictograma e sons via `ui_sound(name)`. Sem a arte-chave (cena ausente), volta ao ceu/mar + palco antigo.
## Nomes e comportamento dos botoes sao os do menu antigo (test_foundation.gd).

## Sons da UI: &"focus", &"confirm", &"back", &"tick", &"select", &"whoosh". O lead liga ao AudioDirector.
signal ui_sound(name: StringName)

const LOGO := "res://ui/title/keyart/logos/logo_c_noite.svg"
## Arte-chave do fundo (G8): proposta B com o logo C noite (KeyArtPresets.LOGOS[&"b"]).
const KEY_ART := "res://ui/title/keyart/keyart_b.tscn"
## G10: imagem parada do fundo da arte-chave B (sem logo e sem botoes), mostrada ate o palco 3D ficar pronto.
const KEY_STILL := "res://ui/title/keyart/stills/b_bg_16x9.jpg"
const KEY_ART_DEPS: Array[String] = ["res://worlds/village_v3/village_world.tscn", "res://worlds/village_v3/boat_wv2.tscn",
	"res://assets/models/environment_v2/wv2_static.glb", "res://assets/models/environment_v2/wv2_kit.glb",
	"res://assets/models/environment_v2/wv3_props.glb"]
const KEY_FADE := 0.6
## Quadros do palco recem-criado escondido antes do fade (primeiro quadro paga shader).
const KEY_SETTLE := 3
## Fracao maxima da altura util para o logo (o trio fica embaixo dele no terco esquerdo).
const LOGO_MAX_H := 0.34
const SAFE_FRACTION := 0.05
const SAFE_MIN := 48.0
const BUTTON_HEIGHT := 128.0

var background: ColorRect
## Fundo 3D animado (null se a cena da arte-chave nao existir).
var key_art: KeyArtView
var logo: TextureRect
var _still: TextureRect
var _key_pending: Array[String] = []
var _key_held: Array[Resource] = []
var _key_settle := -1
var hero_stage: SubViewportContainer
## Onde o lead instancia os 3 herois 3D (os placeholders sao filhos chamados Placeholder*).
var hero_root: Node3D
var menu: VBoxContainer
var play_button: Button
var continue_button: Button
var options_button: Button
var references_button: Button
var quit_button: Button
var options_panel: OptionsPanel
var back_button: Button
var _safe: Control
var _t: float = 0.0
var _logo_px := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = ThemeV2.build()
	Options.apply_all()
	_build()
	resized.connect(_layout)
	_layout()
	ThemeV2.pop_in(logo, 0.4, 0.7)
	var i := 0
	for b in [play_button, options_button, references_button, quit_button]:
		ThemeV2.pop_in(b, 0.6, 0.4, 0.25 + i * 0.07)
		i += 1
	play_button.grab_focus()


func _build() -> void:
	background = ColorRect.new()
	background.name = "Background"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# cor de espera (noite da festa) enquanto a arte-chave carrega; sem ela, o ceu/mar animado antigo
	background.color = Color("1a1440")
	if not ResourceLoader.exists(KEY_ART):
		var mat := ShaderMaterial.new()
		mat.shader = load("res://ui/title/sky_sea.gdshader") as Shader
		mat.set_shader_parameter("motion", 0.0 if Options.reduced_motion() else 1.0)
		background.material = mat
	add_child(background)
	if ResourceLoader.exists(KEY_ART):
		# G10: a arte-chave 3D (vila inteira) leva segundos; o menu abre na hora sobre a imagem parada dela e o palco
		# carrega em segundo plano, entrando com fade quando pronto (_poll_key_art).
		if ResourceLoader.exists(KEY_STILL):
			_still = TextureRect.new()
			_still.name = "KeyArtStill"
			_still.set_anchors_preset(Control.PRESET_FULL_RECT)
			_still.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			_still.texture = load(KEY_STILL) as Texture2D
			add_child(_still)
		_key_pending = [KEY_ART]
		_key_pending.append_array(KEY_ART_DEPS)
		for path: String in _key_pending:
			ResourceLoader.load_threaded_request(path, "", true)
	_safe = Control.new()
	_safe.name = "Safe"
	_safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	_safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_safe)
	_build_heroes()
	logo = TextureRect.new()
	logo.name = "Logo"
	logo.texture = load(LOGO) as Texture2D
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe.add_child(logo)
	menu = VBoxContainer.new()
	menu.name = "Menu"
	menu.add_theme_constant_override("separation", 26)
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	_safe.add_child(menu)
	play_button = _button("PlayButton", "ui.menu.play", &"boat", &"PrimaryButton", 170.0)
	play_button.add_theme_font_size_override("font_size", 60)
	continue_button = _button("ContinueButton", "ui.menu.continue", &"notebook", &"Button")
	# Sem sistema de salvamento ainda: Continuar fica oculto (e fora da navegacao) ate existir progresso salvo.
	continue_button.visible = false
	options_button = _button("OptionsButton", "ui.menu.options", &"gear", &"GreenButton")
	references_button = _button("ReferencesButton", "ui.menu.references", &"magnifier", &"QuietButton")
	quit_button = _button("QuitButton", "ui.menu.quit", &"wave", &"OrangeButton")
	options_panel = OptionsPanel.new()
	options_panel.visible = false
	_safe.add_child(options_panel)
	options_panel.ui_sound.connect(func(n: StringName) -> void: ui_sound.emit(n))
	back_button = options_panel.back_button


func _build_heroes() -> void:
	if key_art != null and key_art.stage != null:
		# o trio da arte-chave e o palco dos herois (mesma API: hero_stage, hero_root, hero_models)
		hero_stage = key_art.get_node("Stage") as SubViewportContainer
		hero_root = key_art.stage
		for id: StringName in key_art.stage.heroes:
			hero_models.append(key_art.stage.heroes[id] as CharacterVisual)
		return
	hero_stage = SubViewportContainer.new()
	hero_stage.name = "HeroStage"
	hero_stage.stretch = true
	hero_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe.add_child(hero_stage)
	var sv := SubViewport.new()
	sv.name = "HeroViewport"
	sv.transparent_bg = true
	sv.own_world_3d = true
	hero_stage.add_child(sv)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.82, 3.3)
	cam.fov = 34.0
	sv.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 0.58, 0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.light_color = Color("FFE6BE")
	sv.add_child(sun)
	hero_root = Node3D.new()
	hero_root.name = "Heroes"
	sv.add_child(hero_root)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -140, 0)
	fill.light_color = Color("9CC8E8")
	fill.light_energy = 0.45
	fill.shadow_enabled = false
	sv.add_child(fill)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dfeaf2")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	if _mount_hero_models():
		return
	var i := 0
	for m: StringName in [&"tracker", &"climber", &"pilot"]:
		# Reserva se os modelos nao carregarem: capsulas na cor-assinatura.
		var mi := MeshInstance3D.new()
		mi.name = "Placeholder_%s" % m
		var cap := CapsuleMesh.new()
		cap.radius = 0.32
		cap.height = 1.1
		mi.mesh = cap
		var mat := StandardMaterial3D.new()
		mat.albedo_color = MemberActor.COLORS.get(m, Color.WHITE)
		mi.material_override = mat
		mi.position = Vector3((i - 1) * 0.95, 0.55 + (0.12 if i == 1 else 0.0), 0)
		hero_root.add_child(mi)
		i += 1


## Herois 3D animados no palco da tela-titulo (RB-R1): pose de equipe uma vez, depois o idle de cada um.
const HERO_SCENES := {
	&"pilot": "res://actors/characters/leme_model.tscn",
	&"tracker": "res://actors/characters/rastro_model.tscn",
	&"climber": "res://actors/characters/pico_model.tscn",
}
var hero_models: Array[CharacterVisual] = []


func _mount_hero_models() -> bool:
	var spots := {&"pilot": Vector3(-0.95, 0, 0.1), &"tracker": Vector3(0, 0, 0.35), &"climber": Vector3(0.95, 0, 0.1)}
	for m: StringName in HERO_SCENES:
		if not ResourceLoader.exists(HERO_SCENES[m]):
			return false
	for m: StringName in HERO_SCENES:
		var inst := (load(HERO_SCENES[m]) as PackedScene).instantiate()
		var visual := inst.get_node_or_null("Model") as CharacterVisual
		if visual == null:
			inst.queue_free()
			return false
		inst.remove_child(visual)
		visual.owner = null
		inst.queue_free()
		var holder := Node3D.new()
		holder.name = "Hero_%s" % m
		holder.position = spots[m]
		# Frente dos modelos em -Z; a camera esta em +Z: gira para encarar a crianca, levemente para o centro.
		holder.rotation.y = PI - (spots[m] as Vector3).x * 0.28
		hero_root.add_child(holder)
		holder.add_child(visual)
		CharacterVisual.stylize_if_toon(visual, 0.006)
		hero_models.append(visual)
		var first := &"team_pose" if visual.has_animation(&"team_pose") else &"idle"
		visual.play(first)
		if first != &"idle":
			get_tree().create_timer(visual.animation_length(first) + 0.2).timeout.connect(func() -> void:
				if is_instance_valid(visual):
					visual.play(&"idle"))
		# G1: `neutra` (sorriso leve, olhos abertos). `alegre` e o sorriso de olhos fechados e, mantido, fechava os olhos.
		visual.set_expression(&"neutra")
	return true


func _button(node_name: String, key: String, icon: StringName, variant: StringName, h: float = BUTTON_HEIGHT) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = Loc.t(key)
	b.icon = IconView.texture_for(icon)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", int(h * 0.62))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.theme_type_variation = variant
	b.custom_minimum_size = Vector2(520, h)
	ThemeV2.springify(b)
	b.focus_entered.connect(func() -> void: ui_sound.emit(&"focus"))
	b.pressed.connect(func() -> void: ui_sound.emit(&"confirm"))
	menu.add_child(b)
	return b


func _layout() -> void:
	var vp := size
	var m := Vector2(maxf(SAFE_MIN, vp.x * SAFE_FRACTION), maxf(SAFE_MIN, vp.y * SAFE_FRACTION))
	_safe.offset_left = m.x
	_safe.offset_top = m.y
	_safe.offset_right = -m.x
	_safe.offset_bottom = -m.y
	var area := vp - m * 2.0
	if background.material is ShaderMaterial:
		(background.material as ShaderMaterial).set_shader_parameter("aspect", vp.x / maxf(vp.y, 1.0))
	var menu_w := clampf(area.x * 0.34, 520.0, 640.0)
	for b: Button in [play_button, continue_button, options_button, references_button, quit_button]:
		b.custom_minimum_size.x = menu_w
	menu.size = Vector2(menu_w, 0)
	menu.reset_size()
	menu.position = Vector2(area.x - menu_w - 12.0, (area.y - menu.get_combined_minimum_size().y) * 0.5 + area.y * 0.06)
	var left_w := area.x - menu_w - 60.0
	var tex := logo.texture
	var ratio := float(tex.get_width()) / float(tex.get_height()) if tex != null else 1632.0 / 340.0
	# logo no alto do lado esquerdo, sem passar de LOGO_MAX_H da altura (o trio fica abaixo dele)
	var logo_w := minf(minf(left_w * 0.8, 820.0), area.y * LOGO_MAX_H * ratio)
	logo.size = Vector2(logo_w, logo_w / ratio)
	logo.position = Vector2((left_w - logo_w) * 0.5, 0)
	logo.pivot_offset = logo.size * 0.5
	_raster_logo(logo_w)
	if key_art == null:
		var stage_top := logo.size.y + 20.0
		hero_stage.position = Vector2(0, stage_top)
		hero_stage.size = Vector2(left_w, area.y - stage_top)
	options_panel.reset_size()
	options_panel.position = (area - options_panel.get_combined_minimum_size()) * 0.5


## Logo SVG rasterizado na largura da tela (pixels reais), sem serrilhado; cai na textura importada se nao abrir.
func _raster_logo(logical_w: float) -> void:
	# pixels reais da tela (nunca abaixo da largura logica: em janela minima/headless a escala e quase zero)
	var px := int(logical_w * maxf(get_viewport().get_stretch_transform().get_scale().x, 1.0))
	if px < 16 or absi(px - _logo_px) < 8 or not LOGO.begins_with("res://ui/title/keyart/"):
		return
	_logo_px = px
	var t := KeyArtView.logo_texture_path(LOGO, px)
	if t != null:
		logo.texture = t


func _process(delta: float) -> void:
	_poll_key_art()
	if Options.reduced_motion() or logo == null:
		return
	_t += delta
	logo.rotation = sin(_t * 1.3) * 0.012
	if hero_root:
		for c in hero_root.get_children():
			if c is Node3D and String(c.name).begins_with("Placeholder"):
				(c as Node3D).rotation.y = sin(_t + (c as Node3D).position.x) * 0.3


## G10: recolhe a arte-chave carregada em segundo plano; cria o palco atras da imagem parada (que o cobre), deixa passar
## KEY_SETTLE quadros e some a imagem com fade (movimento reduzido: troca direta).
func _poll_key_art() -> void:
	if _key_settle > 0:
		_key_settle -= 1
		if _key_settle == 0:
			_reveal_key_art()
		return
	if _key_pending.is_empty():
		return
	for path: String in _key_pending.duplicate():
		var st := ResourceLoader.load_threaded_get_status(path)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			_key_held.append(ResourceLoader.load_threaded_get(path))
			_key_pending.erase(path)
		elif st != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_key_pending.erase(path)
	if not _key_pending.is_empty():
		return
	var packed := ResourceLoader.load(KEY_ART) as PackedScene
	if packed == null:
		return
	key_art = packed.instantiate() as KeyArtView
	key_art.name = "KeyArt"
	key_art.framing = &"menu"
	key_art.show_logo = false   # o logo e o TextureRect `logo` abaixo (com mola e escondido nas opcoes)
	add_child(key_art)
	move_child(key_art, background.get_index() + 1)
	_key_settle = KEY_SETTLE
	print("[RB] title key_art_instanced ms=%d" % Time.get_ticks_msec())


func _reveal_key_art() -> void:
	_key_held.clear()
	if _still == null:
		return
	var still := _still
	_still = null
	if Options.reduced_motion():
		still.queue_free()
		return
	var tw := create_tween()
	tw.tween_property(still, "modulate:a", 0.0, KEY_FADE)
	tw.tween_callback(still.queue_free)
