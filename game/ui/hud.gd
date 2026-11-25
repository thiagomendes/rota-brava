class_name Hud
extends CanvasLayer
## HUD v2 do episodio (RB-R1, style-bible secao 9): cartao de objetivo ilustrado, retratos dos 3 herois (ativo maior),
## botao de acao redondo e grande com o glifo do ultimo dispositivo, balao de legenda com retrato do falante e emotes,
## botao de ajuda discreto, cartao de equipe na troca, conclusao com estrelas e entradas com mola.
## Responde "quem controla, o que posso fazer agora, o que mudou" (SPEC secao 5).
## Layout em unidades virtuais (viewport de referencia 1080 de altura; stretch canvas_items/expand).

signal line_started(key: String)
signal line_finished
signal choice_made(id: StringName)
signal handoff_confirmed
signal replay_requested
signal menu_requested
signal resume_requested
signal skip_requested
signal pause_requested
signal help_requested
## Novo (RB-R1): o botao de acao foi tocado/clicado (alem de injetar a intencao `interact`).
signal action_pressed
## Novo: sons de UI (&"pop", &"confirm", &"focus", &"handoff", &"star", &"emote"). O lead liga ao AudioDirector.
signal ui_sound(name: StringName)
## Novo: ultimo dispositivo usado (&"keyboard", &"pad", &"touch") mudou. Nao altera estado do jogo.
signal device_changed(device: StringName)
## Novo: uma fala com emotes comecou (para o lead disparar o balbucio/emote 3D se quiser).
signal emotes_shown(speaker: StringName, emotes: Array[StringName])

const MEMBERS: Array[StringName] = [&"tracker", &"climber", &"pilot"]
## Cores-assinatura da style-bible (secao 3).
const MEMBER_COLORS := {&"tracker": Color("FF8A1F"), &"climber": Color("3DBE5A"), &"pilot": Color("2F8CFF")}
const SKILL_ICONS := {&"tracker": &"notebook", &"climber": &"rope", &"pilot": &"helm"}
const HANDOFF_MIN_SECONDS := 0.45
const FONT := 34
## Alvo de toque minimo em unidades virtuais (>= 48 dp em aparelho com lado curto >= ~410 dp; ver README).
const MIN_TOUCH := 128.0
const ACTION_SIZE := 236.0
const PORTRAIT_ACTIVE := 148.0
const PORTRAIT_IDLE := 96.0
## Margem da area segura: fracao do lado, com minimo em unidades virtuais.
const SAFE_FRACTION := 0.05
const SAFE_MIN := 48.0

## Ganchos do jogo: devolve a duracao (s) da fala ao iniciar a legenda (0.0 se nao ha audio) e interrompe a fala.
var voice_hook: Callable = Callable()
## Gancho de dados: (key: String) -> Array[StringName] com os emotes da fala quando quem chama nao os informa.
var emotes_hook: Callable = Callable()
var voice_stop_hook: Callable = Callable()
var ui_theme: Theme
var last_device: StringName = &"keyboard"

var _root: Control
var _safe_rects: Array[Control] = []
var _help_button: Button
var _objective_icon: IconView
var _objective_label: Label
var _member_panel: HBoxContainer
var _member_label: Label
var _member_pill: PanelContainer
var _portraits: Dictionary = {}
var _portrait_textures: Dictionary = {}
var _active_member: StringName = &""
var _prompt_panel: VBoxContainer
var _prompt_icon: IconView
var _prompt_label: Label
var _action_button: Button
var _glyph_badge: PanelContainer
var _glyph_label: Label
var _sub_panel: PanelContainer
var _sub_portrait: IconView
var _sub_speaker: Label
var _sub_text: Label
var _emote_box: HBoxContainer
var _skip_label: Label
## Contador de emblemas (colecionaveis): aparece no primeiro emblema achado e pulsa a cada novo.
var _emblem_panel: PanelContainer
var _emblem_label: Label
var _emblem_tween: Tween
var _choice_panel: PanelContainer
var _choice_box: VBoxContainer
var _choice_title: Label
var _handoff_panel: Control
var _handoff_card: PanelContainer
var _handoff_icon: IconView
var _handoff_title: Label
var _handoff_text: Label
var _handoff_button: Button
var _handoff_since: float = 0.0
var _complete_panel: Control
var _complete_box: Control
var _complete_stars: Array[IconView] = []
var _complete_replay: Button
var _complete_emblems: Dictionary = {}
var _pause_panel: Control
var _pause_box: Control
var _pause_resume: Button
var _pause_options: Button
## Opcoes dentro do jogo (pausa): o mesmo painel da tela-titulo; cada mudanca vale na hora.
var options_panel: OptionsPanel
var _options_overlay: Control
var options_open: bool = false
var _queue: Array[Dictionary] = []
var _speaking: bool = false
var _skip_current: bool = false
## C2: fim da ultima fala (ms) e janela em que `interact` e ignorado depois dela (o mesmo E nao vira acao).
const SPEECH_GRACE_MS := 250
var _speech_end_ms: int = -100000
var _hint_active: bool = false
var _pulse: Tween
var choice_open: bool = false
var handoff_open: bool = false
var pause_open: bool = false
var complete_open: bool = false


func _ready() -> void:
	name = "Hud"
	layer = 10
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var safe := _safe_rect(_root)
	safe.name = "Safe"
	_build_top_left(safe)
	_build_member(safe)
	_build_action(safe)
	_build_bottom_stack(safe)
	_build_choice(_root)
	_build_handoff(_root)
	_build_complete(_root)
	_build_pause(_root)
	_root.resized.connect(_layout)
	apply_theme(ThemeV2.build())
	_update_glyph()
	_layout()


## Troca o tema (o estudo RB-03 ainda alterna A/B/C). Nao altera textos nem estado.
func apply_theme(th: Theme) -> void:
	ui_theme = th
	_root.theme = th


func accent_color() -> Color:
	if ui_theme != null and ui_theme.has_color("accent", "Hud"):
		return ui_theme.get_color("accent", "Hud")
	return ThemeV2.ACTION


## Retangulo da area segura em coordenadas do viewport.
func safe_rect() -> Rect2:
	var vp := get_viewport().get_visible_rect().size
	var m := safe_margins(vp)
	return Rect2(m, vp - m * 2.0)


static func safe_margins(vp: Vector2) -> Vector2:
	return Vector2(maxf(SAFE_MIN, vp.x * SAFE_FRACTION), maxf(SAFE_MIN, vp.y * SAFE_FRACTION))


func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var m := safe_margins(vp)
	for c in _safe_rects:
		c.offset_left = m.x
		c.offset_right = -m.x
		c.offset_top = m.y
		c.offset_bottom = -m.y
	# Balao: no maximo 62% da largura, centrado entre os polegares; o texto desconta retrato e margens.
	var bubble := minf(clampf(vp.x - m.x * 2.0 - 36.0, 640.0, 1180.0), vp.x * 0.62)
	_sub_text.custom_minimum_size.x = bubble - 190.0
	_objective_label.custom_minimum_size.x = minf(560.0, vp.x * 0.27)


# ---------- construcao ----------

func _safe_rect(parent: Control) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	_safe_rects.append(c)
	return c


func _panel(parent: Node, variant: StringName = &"HudPanel") -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variant
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


## Ancora o controle num ponto relativo a area (ax, ay em 0..1) com deslocamento em pixels; cresce para os lados indicados.
func _anchor(c: Control, ax: float, ay: float, ox: float, oy: float, grow_h: Control.GrowDirection, grow_v: Control.GrowDirection) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = ox
	c.offset_right = ox
	c.offset_top = oy
	c.offset_bottom = oy
	c.grow_horizontal = grow_h
	c.grow_vertical = grow_v


func _label(parent: Node, size: int = FONT, variant: StringName = &"") -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	if variant != &"":
		l.theme_type_variation = variant
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _icon(parent: Node, kind: StringName, px: float, ring_color: Color = ThemeV2.ACTION, plain: bool = false) -> IconView:
	var i := IconView.new()
	i.kind = kind
	i.color = ring_color
	i.custom_minimum_size = Vector2(px, px)
	if plain:
		i.back_color = Color(0, 0, 0, 0)
	parent.add_child(i)
	return i


func _button(parent: Node, text: String, width: float = 520.0, icon: StringName = &"", variant: StringName = &"Button") -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variant
	b.custom_minimum_size = Vector2(maxf(width, MIN_TOUCH), MIN_TOUCH)
	if icon != &"":
		b.icon = IconView.texture_for(icon)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 84)
	ThemeV2.springify(b, 0.05)
	b.focus_entered.connect(func() -> void: ui_sound.emit(&"focus"))
	b.pressed.connect(func() -> void: ui_sound.emit(&"confirm"))
	parent.add_child(b)
	return b


func _build_top_left(safe: Control) -> void:
	var col := VBoxContainer.new()
	col.name = "TopLeft"
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 6)
	safe.add_child(col)
	var p := _panel(col)
	p.name = "ObjectivePanel"
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	p.add_child(h)
	_objective_icon = _icon(h, &"notebook", 96)
	_objective_label = _label(h, 32)
	_objective_label.custom_minimum_size = Vector2(560, 0)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	# Ajuda: disco pequeno (72) dentro de um alvo de toque de 128 transparente.
	_help_button = Button.new()
	_help_button.name = "HelpButton"
	_help_button.theme_type_variation = &"GhostButton"
	_help_button.custom_minimum_size = Vector2(MIN_TOUCH, MIN_TOUCH)
	_help_button.focus_mode = Control.FOCUS_NONE
	_help_button.tooltip_text = Loc.t("ui.help.repeat_button", {"control": "H"})
	_help_button.pressed.connect(func() -> void:
		ui_sound.emit(&"confirm")
		help_requested.emit())
	row.add_child(_help_button)
	var hi := _icon(_help_button, &"help", 72, ThemeV2.NAVY, false)
	hi.set_anchors_preset(Control.PRESET_CENTER)
	hi.offset_left = -36
	hi.offset_top = -36
	hi.offset_right = 36
	hi.offset_bottom = 36
	hi.ring = 0.05
	var skip_panel := _panel(row, &"PillPanel")
	skip_panel.name = "SkipPanel"
	skip_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_skip_label = _label(skip_panel, 30, &"LightLabel")
	_skip_label.name = "SkipHint"
	_skip_label.text = Loc.t("ui.skip")
	skip_panel.visible = false
	_emblem_panel = _panel(row, &"PillPanel")
	_emblem_panel.name = "EmblemCounter"
	_emblem_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_emblem_panel.pivot_offset = Vector2(90, 36)
	var eh := HBoxContainer.new()
	eh.add_theme_constant_override("separation", 10)
	_emblem_panel.add_child(eh)
	var ei := _icon(eh, &"star", 56, ThemeV2.ACTION)
	ei.texture_override = load("res://ui/brand/emblem_simple.svg") as Texture2D
	_emblem_label = _label(eh, 30, &"LightLabel")
	_emblem_label.name = "EmblemCount"
	_emblem_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_emblem_panel.visible = false


## Mostra "n/total" emblemas. Com `celebrate`, o contador da um pulo (novo emblema). Zero esconde o contador.
func set_collectibles(count: int, total: int, celebrate: bool = true) -> void:
	_emblem_label.text = Loc.t("ui.collectibles.count", {"count": count, "total": total})
	_emblem_label.tooltip_text = Loc.t("ui.collectibles.tooltip")
	_emblem_panel.visible = count > 0
	if not celebrate or count <= 0:
		return
	if _emblem_tween and _emblem_tween.is_valid():
		_emblem_tween.kill()
	_emblem_panel.scale = Vector2.ONE
	_emblem_tween = create_tween()
	_emblem_tween.tween_property(_emblem_panel, "scale", Vector2(1.25, 1.25), 0.12)
	_emblem_tween.tween_property(_emblem_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func collectibles_text() -> String:
	return _emblem_label.text if _emblem_panel.visible else ""


func _build_member(safe: Control) -> void:
	_member_panel = HBoxContainer.new()
	_member_panel.name = "MemberPanel"
	_member_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_member_panel.add_theme_constant_override("separation", 14)
	_member_panel.alignment = BoxContainer.ALIGNMENT_END
	safe.add_child(_member_panel)
	_anchor(_member_panel, 1.0, 0.0, 0.0, 0.0, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)
	for m in MEMBERS:
		var v := VBoxContainer.new()
		v.name = "Portrait_%s" % m
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", -14)
		_member_panel.add_child(v)
		var ic := _icon(v, SKILL_ICONS[m], PORTRAIT_IDLE, MEMBER_COLORS[m])
		ic.name = "Portrait"
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ic.ring = 0.09
		_portraits[m] = ic
	_member_pill = PanelContainer.new()
	_member_pill.theme_type_variation = &"PillPanel"
	_member_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_member_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_member_label = _label(_member_pill, 30, &"LightLabel")
	_member_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_member_panel.visible = false


## Botao de acao: embaixo a direita (zona do polegar), redondo, com pictograma, rotulo e glifo do dispositivo.
func _build_action(safe: Control) -> void:
	_prompt_panel = VBoxContainer.new()
	_prompt_panel.name = "PromptPanel"
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.add_theme_constant_override("separation", 10)
	_prompt_panel.alignment = BoxContainer.ALIGNMENT_END
	safe.add_child(_prompt_panel)
	_anchor(_prompt_panel, 1.0, 1.0, 0.0, 0.0, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BEGIN)
	var pill := _panel(_prompt_panel, &"PillPanel")
	pill.name = "ActionLabel"
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_prompt_label = _label(pill, 40, &"LightLabel")
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_button = Button.new()
	_action_button.name = "ActionButton"
	_action_button.focus_mode = Control.FOCUS_NONE
	_action_button.custom_minimum_size = Vector2(ACTION_SIZE, ACTION_SIZE)
	_action_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var r := int(ACTION_SIZE * 0.5)
	var normal := ThemeV2.box(ThemeV2.ACTION, r, 0, 10, Color.WHITE, 12)
	var hover := ThemeV2.box(ThemeV2.ACTION.lightened(0.15), r, 0, 10, Color.WHITE, 12)
	var pressed := ThemeV2.box(ThemeV2.ACTION.darkened(0.1), r, 0, 10, Color.WHITE, 3)
	_action_button.add_theme_stylebox_override("normal", normal)
	_action_button.add_theme_stylebox_override("hover", hover)
	_action_button.add_theme_stylebox_override("pressed", pressed)
	_action_button.add_theme_stylebox_override("hover_pressed", pressed)
	_action_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_action_button.button_down.connect(func() -> void: _prompt_icon.position.y = ACTION_SIZE * 0.2 + 6.0)
	_action_button.button_up.connect(func() -> void: _prompt_icon.position.y = ACTION_SIZE * 0.2)
	_action_button.pressed.connect(_on_action_pressed)
	_prompt_panel.add_child(_action_button)
	_prompt_icon = _icon(_action_button, &"magnifier", ACTION_SIZE * 0.6, ThemeV2.ACTION, true)
	_prompt_icon.position = Vector2(ACTION_SIZE * 0.2, ACTION_SIZE * 0.2)
	_prompt_icon.size = Vector2(ACTION_SIZE * 0.6, ACTION_SIZE * 0.6)
	_glyph_badge = PanelContainer.new()
	_glyph_badge.name = "GlyphBadge"
	_glyph_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph_badge.add_theme_stylebox_override("panel", ThemeV2.box(ThemeV2.NAVY, 34, 4, 5, Color.WHITE, 0))
	_glyph_badge.custom_minimum_size = Vector2(68, 68)
	_glyph_badge.position = Vector2(4, ACTION_SIZE - 72)
	_action_button.add_child(_glyph_badge)
	_glyph_label = _label(_glyph_badge, 38, &"LightLabel")
	_glyph_label.name = "KeyHint"
	_glyph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glyph_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_panel.visible = false


## Base ao centro: balao de legenda (retrato do falante, nome, emotes e texto). Fica entre os polegares.
func _build_bottom_stack(safe: Control) -> void:
	var v := VBoxContainer.new()
	v.name = "BottomStack"
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_END
	_anchor(v, 0.5, 1.0, 0.0, 0.0, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)
	safe.add_child(v)
	_sub_panel = _panel(v, &"SubtitlePanel")
	_sub_panel.name = "SubtitlePanel"
	_sub_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	_sub_panel.add_child(h)
	_sub_portrait = _icon(h, &"horn", 120, ThemeV2.NAVY)
	_sub_portrait.name = "SpeakerPortrait"
	_sub_portrait.ring = 0.08
	_sub_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 2)
	h.add_child(sv)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	sv.add_child(head)
	_sub_speaker = _label(head, 30, &"AccentLabel")
	_sub_speaker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_emote_box = HBoxContainer.new()
	_emote_box.name = "Emotes"
	_emote_box.add_theme_constant_override("separation", 6)
	_emote_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_emote_box)
	_sub_text = _label(sv, FONT)
	_sub_text.custom_minimum_size = Vector2(900, 0)
	_sub_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub_panel.visible = false


func _build_choice(root: Control) -> void:
	var safe := _safe_rect(root)
	safe.name = "ChoiceSafe"
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(center)
	_choice_panel = _panel(center, &"ModalPanel")
	_choice_panel.name = "ChoicePanel"
	_choice_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 20)
	_choice_panel.add_child(_choice_box)
	_choice_title = _label(_choice_box, 44, &"TitleLabel")
	_choice_title.custom_minimum_size = Vector2(760, 0)
	_choice_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_choice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_choice_panel.visible = false


func _overlay(root: Control, name_: String, dim_alpha: float = 0.45) -> Control:
	var c := Control.new()
	c.name = name_
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(ThemeV2.NAVY_DEEP, dim_alpha)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(dim)
	root.add_child(c)
	c.visible = false
	return c


func _centered_box(overlay: Control) -> VBoxContainer:
	var safe := _safe_rect(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(center)
	var panel := _panel(center, &"ModalPanel")
	panel.name = "Card"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)
	return v


## Cartao de equipe: retrato grande de quem vai agir, "Sua vez!" na cor dele e Confirmar. Sem escurecer a cena:
## a camera enquadra no centro quem vai agir, e a crianca precisa ve-lo.
func _build_handoff(root: Control) -> void:
	_handoff_panel = _overlay(root, "HandoffOverlay", 0.0)
	var safe := _safe_rect(_handoff_panel)
	_handoff_card = _panel(safe, &"ModalPanel")
	_handoff_card.name = "TeamCard"
	_handoff_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_anchor(_handoff_card, 0.5, 1.0, 0.0, 0.0, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 28)
	_handoff_card.add_child(h)
	_handoff_icon = _icon(h, &"rope", 176, MEMBER_COLORS[&"climber"])
	_handoff_icon.ring = 0.09
	_handoff_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	h.add_child(v)
	_handoff_title = _label(v, 56, &"LightLabel")
	_handoff_title.text = Loc.t("ui.hud.your_turn")
	_handoff_text = _label(v, 36)
	_handoff_text.custom_minimum_size = Vector2(620, 0)
	_handoff_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_handoff_button = _button(v, Loc.t("ui.menu.confirm"), 420, &"thumbs_up", &"PrimaryButton")
	_handoff_button.name = "ConfirmButton"
	_handoff_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_handoff_button.pressed.connect(_confirm_handoff)


func _build_complete(root: Control) -> void:
	_complete_panel = _overlay(root, "CompleteOverlay")
	var v := _centered_box(_complete_panel)
	_complete_box = v.get_parent() as Control
	var stars := HBoxContainer.new()
	stars.name = "Stars"
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.add_theme_constant_override("separation", 18)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(stars)
	for i in 3:
		var s := _icon(stars, &"star", 150.0 if i == 1 else 120.0, ThemeV2.ACTION, true)
		s.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if i == 1 else Control.SIZE_SHRINK_END
		_complete_stars.append(s)
	var title := _label(v, 76, &"TitleLabel")
	title.name = "Title"
	title.text = Loc.t("ep01.complete.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body := _label(v, 36)
	body.name = "Body"
	body.text = Loc.t("ep01.complete.body")
	body.custom_minimum_size = Vector2(900, 0)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var team := HBoxContainer.new()
	team.alignment = BoxContainer.ALIGNMENT_CENTER
	team.add_theme_constant_override("separation", 24)
	team.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(team)
	for m in MEMBERS:
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		team.add_child(col)
		_icon(col, SKILL_ICONS[m], 104, MEMBER_COLORS[m]).ring = 0.09
		# Emblemas do heroi (Ep01 v3): so numeros ao lado da estrela; vazio ate set_complete_emblems.
		var row_e := HBoxContainer.new()
		row_e.alignment = BoxContainer.ALIGNMENT_CENTER
		row_e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_e.visible = false
		row_e.name = "Emblems_" + String(m)
		col.add_child(row_e)
		_icon(row_e, &"star", 40, MEMBER_COLORS[m], true)
		var n := _label(row_e, 34)
		n.name = "Count"
		_complete_emblems[m] = row_e
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	v.add_child(row)
	_complete_replay = _button(row, Loc.t("ui.menu.review"), 400, &"star", &"PrimaryButton")
	_complete_replay.pressed.connect(func() -> void: replay_requested.emit())
	var menu := _button(row, Loc.t("ui.menu.menu"), 320, &"home")
	menu.pressed.connect(func() -> void: menu_requested.emit())


func _build_pause(root: Control) -> void:
	_pause_panel = _overlay(root, "PauseOverlay")
	var v := _centered_box(_pause_panel)
	_pause_box = v.get_parent() as Control
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 18)
	v.add_child(head)
	_icon(head, &"pause", 96, ThemeV2.NAVY, true)
	var title := _label(head, 76, &"TitleLabel")
	title.text = Loc.t("ui.pause.title")
	_pause_resume = _button(v, Loc.t("ui.pause.resume"), 520, &"boat", &"PrimaryButton")
	_pause_resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_pause_resume.pressed.connect(func() -> void: resume_requested.emit())
	_pause_options = _button(v, Loc.t("ui.menu.options"), 520, &"gear")
	_pause_options.name = "PauseOptions"
	_pause_options.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_pause_options.pressed.connect(open_options)
	var menu := _button(v, Loc.t("ui.menu.menu"), 520, &"home")
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu.pressed.connect(func() -> void: menu_requested.emit())
	_options_overlay = _overlay(root, "OptionsOverlay", 0.25)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe_rect(_options_overlay).add_child(center)
	options_panel = OptionsPanel.new()
	center.add_child(options_panel)
	options_panel.ui_sound.connect(func(n: StringName) -> void: ui_sound.emit(n))
	options_panel.back_requested.connect(close_options)


func open_options() -> void:
	ui_sound.emit(&"confirm")
	options_open = true
	_options_overlay.visible = true
	options_panel.open()


func close_options() -> void:
	options_open = false
	_options_overlay.visible = false
	if pause_open:
		_pause_options.grab_focus()


# ---------- objetivo, integrante e acao contextual ----------

func set_objective(text: String, icon: StringName) -> void:
	var changed := _objective_label.text != Loc.t("ui.hud.objective", {"text": text})
	_objective_label.text = Loc.t("ui.hud.objective", {"text": text})
	_objective_icon.kind = icon
	if changed and is_inside_tree():
		ThemeV2.pop_in(_objective_icon, 0.5)
		ui_sound.emit(&"pop")


## Retrato do heroi (ex.: render do modelo 3D). null volta ao pictograma da habilidade.
func set_portrait_texture(member: StringName, tex: Texture2D) -> void:
	_portrait_textures[member] = tex
	if _portraits.has(member):
		(_portraits[member] as IconView).texture_override = tex
	if _handoff_icon and handoff_open:
		_handoff_icon.texture_override = tex


func portrait_texture(member: StringName) -> Texture2D:
	return _portrait_textures.get(member, null)


func set_member(member: StringName) -> void:
	if member == &"":
		_member_panel.visible = false
		_active_member = &""
		return
	_member_panel.visible = true
	var changed := member != _active_member
	_active_member = member
	for m in MEMBERS:
		var ic := _portraits[m] as IconView
		var active := m == member
		var px := PORTRAIT_ACTIVE if active else PORTRAIT_IDLE
		ic.custom_minimum_size = Vector2(px, px)
		ic.modulate = Color.WHITE if active else Color(1, 1, 1, 0.85)
		var holder := ic.get_parent()
		if active:
			if _member_pill.get_parent() != holder:
				if _member_pill.get_parent():
					_member_pill.get_parent().remove_child(_member_pill)
				holder.add_child(_member_pill)
	# O ativo fica sempre na ponta direita (mais perto do canto), os outros a esquerda.
	_member_panel.move_child(_member_panel.get_node("Portrait_%s" % member), -1)
	_member_label.text = Loc.member_name(member)
	(_member_pill as PanelContainer).add_theme_stylebox_override("panel",
		ThemeV2.box(MEMBER_COLORS.get(member, ThemeV2.NAVY), 28, 8, 5, Color.WHITE, 6))
	if changed and is_inside_tree():
		ThemeV2.pop_in(_portraits[member], 0.6)


func show_prompt(label: String, icon: StringName) -> void:
	var was := _prompt_panel.visible
	_prompt_label.text = label
	_prompt_icon.kind = icon
	_prompt_panel.visible = true
	if not was:
		ThemeV2.pop_in(_action_button, 0.5)
		ui_sound.emit(&"pop")
		_start_pulse()


func hide_prompt() -> void:
	_prompt_panel.visible = false
	if _pulse:
		_pulse.kill()


func prompt_visible() -> bool:
	return _prompt_panel.visible


func prompt_text() -> String:
	return _prompt_label.text


func _start_pulse() -> void:
	if _pulse:
		_pulse.kill()
	_action_button.self_modulate = Color.WHITE
	if Options.reduced_motion() or not is_inside_tree():
		return
	# A acao do momento e a unica cor que pulsa (style-bible 5): brilho, sem mudar o tamanho.
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_action_button, "self_modulate", Color(1.18, 1.12, 1.0), 0.6).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(_action_button, "self_modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE)


func _on_action_pressed() -> void:
	ui_sound.emit(&"confirm")
	action_pressed.emit()
	# O toque/clique vira a mesma intencao do teclado/controle: o jogo nao precisa saber de onde veio.
	for p in [true, false]:
		var ev := InputEventAction.new()
		ev.action = &"interact"
		ev.pressed = p
		Input.parse_input_event(ev)


func action_button() -> Button:
	return _action_button


func set_skip_hint(on: bool) -> void:
	_skip_label.get_parent().visible = on


# ---------- dispositivo ----------

func _input(event: InputEvent) -> void:
	var dev := last_device
	if event is InputEventKey or event is InputEventMouseButton:
		dev = &"keyboard"
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5):
		dev = &"pad"
	elif event is InputEventScreenTouch:
		dev = &"touch"
	if dev != last_device:
		set_device(dev)


## Troca o glifo exibido (teclado E / controle A / toque sem glifo). Nao altera estado do jogo.
func set_device(dev: StringName) -> void:
	last_device = dev
	_update_glyph()
	device_changed.emit(dev)


func glyph_text() -> String:
	return _glyph_label.text


func _update_glyph() -> void:
	match last_device:
		&"pad":
			_glyph_label.text = Loc.t("ui.glyph.pad")
		&"touch":
			_glyph_label.text = ""
		_:
			_glyph_label.text = Loc.t("ui.glyph.keyboard")
	_glyph_badge.visible = not _glyph_label.text.is_empty()


# ---------- legendas ----------

func speaker_name_for(key: String) -> String:
	var who := speaker_for(key)
	if who != &"":
		return Loc.member_name(who)
	return ""


func speaker_for(key: String) -> StringName:
	# Falas de radio de Farol 7 (RB-R1): ep01.radio.<local>.<id>
	if key.begins_with("ep01.radio."):
		return &"radio"
	var parts := key.split(".")
	if parts.size() >= 3 and Loc.has_key("member.%s.name" % parts[2]):
		return StringName(parts[2])
	return &""


## Fala com legenda. `emotes`: pictogramas de res://ui/brand/icons (ex.: [&"question", &"paw"]) ao lado do nome.
func say(key: String, params: Dictionary = {}, is_hint: bool = false, emotes: Array[StringName] = []) -> void:
	var use_emotes := emotes
	if use_emotes.is_empty() and emotes_hook.is_valid():
		use_emotes = emotes_hook.call(key)
	_queue.append({"key": key, "params": params, "hint": is_hint, "emotes": use_emotes})
	if not _speaking:
		_pump()


## Fala varias chaves em sequencia e retorna quando a ultima terminar.
func say_all(keys: Array[String]) -> void:
	for k in keys:
		say(k)
	await wait_silent()


## Retorna quando nao ha mais fala na fila nem em exibicao.
func wait_silent() -> void:
	while is_speaking():
		if not is_inside_tree():
			return
		await get_tree().process_frame


func is_speaking() -> bool:
	return _speaking or not _queue.is_empty()


func skip_line() -> void:
	_skip_current = true
	if voice_stop_hook.is_valid():
		voice_stop_hook.call()


func clear_speech(only_hints: bool = false) -> void:
	if only_hints:
		_queue = _queue.filter(func(e: Dictionary) -> bool: return not e["hint"])
		if _hint_active:
			_skip_current = true
	else:
		_queue.clear()
		_skip_current = true


func current_emotes() -> Array[StringName]:
	var out: Array[StringName] = []
	for c in _emote_box.get_children():
		if c is IconView and not c.is_queued_for_deletion():
			out.append((c as IconView).kind)
	return out


func _show_line(entry: Dictionary) -> void:
	var key := String(entry["key"])
	var who := speaker_for(key)
	_sub_speaker.text = speaker_name_for(key)
	_sub_speaker.visible = not _sub_speaker.text.is_empty()
	if who != &"":
		_sub_portrait.kind = SKILL_ICONS.get(who, &"notebook")
		_sub_portrait.color = MEMBER_COLORS.get(who, ThemeV2.NAVY)
		_sub_portrait.texture_override = _portrait_textures.get(who, null)
		_sub_speaker.add_theme_color_override("font_color", (MEMBER_COLORS.get(who, ThemeV2.NAVY) as Color).darkened(0.2))
	else:
		# Sem falante (dica de Farol 7 no radio, sons): buzina/radio.
		_sub_portrait.kind = &"horn"
		_sub_portrait.color = ThemeV2.NAVY
		_sub_portrait.texture_override = null
	for c in _emote_box.get_children():
		_emote_box.remove_child(c)
		c.queue_free()
	var emotes: Array = entry.get("emotes", [])
	for e in emotes:
		var ic := _icon(_emote_box, StringName(e), 64, ThemeV2.NAVY)
		ic.ring = 0.06
		ThemeV2.pop_in(ic, 0.3, 0.4, 0.1 * _emote_box.get_child_count())
	_emote_box.visible = not emotes.is_empty()
	if not emotes.is_empty():
		var typed: Array[StringName] = []
		for e in emotes:
			typed.append(StringName(e))
		emotes_shown.emit(who, typed)
		ui_sound.emit(&"emote")
	_sub_text.add_theme_font_size_override("font_size", int(round(FONT * Options.subtitle_scale())))
	_sub_text.text = Loc.t(key, entry["params"])
	var was := _sub_panel.visible
	_sub_panel.visible = true
	if not was:
		ThemeV2.pop_in(_sub_panel, 0.85, 0.3)


func _pump() -> void:
	_speaking = true
	while not _queue.is_empty():
		var entry: Dictionary = _queue.pop_front()
		_show_line(entry)
		var text := _sub_text.text
		_hint_active = bool(entry["hint"])
		_skip_current = false
		line_started.emit(String(entry["key"]))
		var seconds := maxf(2.4, 1.3 + 0.055 * text.length())
		if voice_hook.is_valid():
			var voice_len := float(voice_hook.call(String(entry["key"])))
			if voice_len > 0.0:
				seconds = voice_len + 0.35
		var t := 0.0
		while t < seconds and not _skip_current:
			await get_tree().process_frame
			if not is_inside_tree():
				return
			if not pause_open:
				t += get_process_delta_time()
		_hint_active = false
		line_finished.emit()
	_sub_panel.visible = false
	_speaking = false
	_speech_end_ms = Time.get_ticks_msec()


# ---------- escolha ----------

## options: [{id, label, icon}]. Emite choice_made(id); cancelar emite &"".
func open_choice(title: String, options: Array[Dictionary]) -> void:
	for child in _choice_box.get_children():
		if child != _choice_title:
			child.queue_free()
	_choice_title.text = title
	var first: Button = null
	for o in options:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 28)
		_choice_box.add_child(row)
		var icon := _icon(row, StringName(o.get("icon", "bank")), 112)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var b := _button(row, String(o["label"]), 560)
		var id := StringName(o["id"])
		b.pressed.connect(func() -> void: _pick(id))
		if first == null:
			first = b
	# Voltar visivel para mouse/toque (Esc/cancelar ja fazia o mesmo).
	var back := _button(_choice_box, Loc.t("ui.menu.back"), 360, &"", &"QuietButton")
	back.name = "BackButton"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: _pick(&""))
	_choice_panel.visible = true
	choice_open = true
	ThemeV2.pop_in(_choice_panel, 0.8)
	ui_sound.emit(&"pop")
	if first:
		first.grab_focus()


func close_choice() -> void:
	_choice_panel.visible = false
	choice_open = false


func _pick(id: StringName) -> void:
	close_choice()
	choice_made.emit(id)


# ---------- troca de integrante (cartao de equipe) ----------

func open_handoff(text: String, member: StringName) -> void:
	_handoff_icon.kind = SKILL_ICONS.get(member, &"notebook")
	var col: Color = MEMBER_COLORS.get(member, ThemeV2.NAVY)
	_handoff_icon.color = col
	_handoff_icon.texture_override = _portrait_textures.get(member, null)
	_handoff_title.add_theme_color_override("font_color", col)
	_handoff_title.add_theme_color_override("font_outline_color", Color.WHITE)
	_handoff_card.add_theme_stylebox_override("panel", ThemeV2.box(ThemeV2.PAPER, 40, 30, 10, col, 12))
	_handoff_text.text = text
	_handoff_panel.visible = true
	handoff_open = true
	_handoff_since = Time.get_ticks_msec() / 1000.0
	ThemeV2.pop_in(_handoff_card, 0.6, 0.45)
	ThemeV2.pop_in(_handoff_icon, 0.3, 0.6, 0.15)
	ui_sound.emit(&"handoff")
	_handoff_button.grab_focus()


func close_handoff() -> void:
	handoff_open = false
	_handoff_panel.visible = false


func _confirm_handoff() -> void:
	if not handoff_open or pause_open:
		return
	if Time.get_ticks_msec() / 1000.0 - _handoff_since < HANDOFF_MIN_SECONDS:
		return
	handoff_open = false
	_handoff_panel.visible = false
	handoff_confirmed.emit()


# ---------- pausa e conclusao ----------

func open_pause() -> void:
	pause_open = true
	_pause_panel.visible = true
	ThemeV2.pop_in(_pause_box, 0.85, 0.25)
	_pause_resume.grab_focus()


func close_pause() -> void:
	pause_open = false
	_pause_panel.visible = false
	if options_open:
		close_options()


func open_complete() -> void:
	complete_open = true
	_complete_panel.visible = true
	ThemeV2.pop_in(_complete_box, 0.7, 0.4)
	for i in _complete_stars.size():
		ThemeV2.pop_in(_complete_stars[i], 0.2, 0.5, 0.35 + i * 0.25)
		if is_inside_tree() and not Options.reduced_motion():
			get_tree().create_timer(0.35 + i * 0.25).timeout.connect(func() -> void: ui_sound.emit(&"star"))
	_complete_replay.grab_focus()


## Emblemas por heroi na tela final: heroi -> [achados, total]. So numeros (sem texto fora do catalogo).
func set_complete_emblems(by_hero: Dictionary) -> void:
	for m: StringName in _complete_emblems:
		var row := _complete_emblems[m] as Control
		var v: Array = by_hero.get(m, [])
		row.visible = v.size() == 2 and int(v[1]) > 0
		if row.visible:
			(row.get_node("Count") as Label).text = "%d/%d" % [int(v[0]), int(v[1])]


func complete_emblems_text(member: StringName) -> String:
	var row := _complete_emblems.get(member) as Control
	return (row.get_node("Count") as Label).text if row != null and row.visible else ""


func close_complete() -> void:
	complete_open = false
	_complete_panel.visible = false


# ---------- entrada ----------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if options_open and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause")):
		get_viewport().set_input_as_handled()
		close_options()
		return
	if event.is_action_pressed(&"pause") and not choice_open and not complete_open:
		get_viewport().set_input_as_handled()
		if pause_open:
			resume_requested.emit()
		else:
			pause_requested.emit()
	elif choice_open and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_pick(&"")
	elif handoff_open and not pause_open and event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		_confirm_handoff()
	# C2: a fala avanca por `interact` e consome o aperto (um E so avanca, nao interage). Nunca por `ui_accept`, que
	# inclui Espaco (o pulo). Logo depois da fala acabar, `interact` fica ignorado por SPEECH_GRACE_MS.
	elif event.is_action_pressed(&"interact") and not choice_open and not handoff_open \
			and not pause_open and not complete_open and _speaking:
		get_viewport().set_input_as_handled()
		skip_line()
	elif event.is_action_pressed(&"interact") and not handoff_open and not pause_open \
			and Time.get_ticks_msec() - _speech_end_ms < SPEECH_GRACE_MS:
		get_viewport().set_input_as_handled()
