class_name SlotScreen
extends Control
## G13 (RB-R1): tela dos 3 espacos de jogo ("memory card"), aberta por Jogar no menu. Cada cartao grande mostra o
## retrato do heroi da missao atual, o icone e o nome da missao e os emblemas (x/10); cartao vazio mostra "Novo jogo".
## Escolher um cartao continua o jogo daquele espaco (ou comeca um novo nele) e emite `play_requested`; quem abriu a
## tela faz a troca de cena pelo SceneLoaderService.
## Apagar: botao "Apagar" embaixo do cartao cheio, que precisa ser SEGURADO (HoldButton, anel enchendo, ~1,5 s) e
## depois confirmado ("Nao" tem o foco). Voltar: botao Voltar ou `ui_cancel`.
## Fundo: imagem parada da arte-chave B com veu azul-noite; esta tela nao carrega 3D.
## Navegacao: setas/direcional entre cartoes (esquerda/direita), para baixo vai ao Apagar, para cima ao Voltar; Tab e
## Shift+Tab percorrem Voltar, cartao 1, Apagar 1, cartao 2... na ordem de leitura.

signal back_requested
signal play_requested(slot: int)
signal ui_sound(name: StringName)

const STILL := "res://ui/title/keyart/stills/b_bg_16x9.jpg"
const EMBLEM_ICON := "res://ui/brand/emblem_simple.svg"
const VEIL := Color(0.043, 0.141, 0.251, 0.62)  # NAVY_DEEP 0B2440 a 62%
const SAFE_FRACTION := 0.05
const SAFE_MIN := 48.0
const HEADER_H := 128.0
const DELETE_H := 112.0
const GAP := 40.0
## Tempo de segurar o Apagar (s).
const HOLD_SECONDS := 1.5
## Quanto tempo a dica "Segure para apagar" fica depois de soltar cedo (s).
const HINT_SECONDS := 2.5

var back_button: Button
var title_label: Label
var cards: Array[Button] = []
var delete_buttons: Array[HoldButton] = []
var hints: Array[Control] = []
var spacers: Array[Control] = []
var summaries: Array[Dictionary] = []
var confirm_overlay: Control
var confirm_label: Label
## Retrato do espaco que vai ser apagado (a crianca ve qual jogo e).
var confirm_portrait: IconView
var confirm_yes: Button
var confirm_no: Button
## Espaco que esta para ser apagado (0 = nenhum).
var confirm_slot: int = 0
var _safe: Control
var _confirm_panel: PanelContainer
var _root: VBoxContainer
var _row: HBoxContainer
var _hint_left: Array[float] = [0.0, 0.0, 0.0]


func _init() -> void:
	name = "SlotScreen"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	theme = ThemeV2.build()
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = ThemeV2.NAVY_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	if ResourceLoader.exists(STILL):
		var still := TextureRect.new()
		still.name = "KeyArtStill"
		still.set_anchors_preset(Control.PRESET_FULL_RECT)
		still.mouse_filter = Control.MOUSE_FILTER_IGNORE
		still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		still.texture = load(STILL) as Texture2D
		add_child(still)
	var veil := ColorRect.new()
	veil.name = "Veil"
	veil.color = VEIL
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	_safe = Control.new()
	_safe.name = "Safe"
	_safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	_safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_safe)
	_root = VBoxContainer.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_theme_constant_override("separation", 36)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe.add_child(_root)
	var head := HBoxContainer.new()
	head.name = "Header"
	head.add_theme_constant_override("separation", 32)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(head)
	back_button = Button.new()
	back_button.name = "BackButton"
	back_button.text = Loc.t("ui.menu.back")
	back_button.icon = IconView.texture_for(&"home")
	back_button.expand_icon = true
	back_button.add_theme_constant_override("icon_max_width", 72)
	back_button.theme_type_variation = &"QuietButton"
	back_button.custom_minimum_size = Vector2(300, HEADER_H)
	ThemeV2.springify(back_button)
	back_button.pressed.connect(_on_back)
	head.add_child(back_button)
	var title_pill := PanelContainer.new()
	title_pill.theme_type_variation = &"PillPanel"
	title_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(title_pill)
	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = Loc.t("ui.slots.title")
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_font_size_override("font_size", 56)
	title_pill.add_child(title_label)
	_row = HBoxContainer.new()
	_row.name = "Cards"
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", int(GAP))
	_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_row)
	for i in SaveSlots.COUNT:
		_build_column(i + 1)
	_build_confirm()
	resized.connect(_layout)
	refresh()
	_layout()


func _build_column(slot: int) -> void:
	var col := VBoxContainer.new()
	col.name = "Slot%d" % slot
	col.add_theme_constant_override("separation", 20)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(col)
	var card := Button.new()
	card.name = "Card%d" % slot
	card.clip_contents = false
	ThemeV2.springify(card, 0.04)
	card.focus_entered.connect(func() -> void: ui_sound.emit(&"focus"))
	card.pressed.connect(_on_card.bind(slot))
	col.add_child(card)
	cards.append(card)
	var del := HoldButton.new()
	del.name = "Delete%d" % slot
	del.hold_seconds = HOLD_SECONDS
	del.text = Loc.t("ui.slots.erase")
	del.theme_type_variation = &"OrangeButton"
	del.alignment = HORIZONTAL_ALIGNMENT_LEFT
	del.add_theme_font_size_override("font_size", 38)
	del.custom_minimum_size = Vector2(300, DELETE_H)
	ThemeV2.springify(del, 0.04)
	del.focus_entered.connect(func() -> void: ui_sound.emit(&"focus"))
	del.hold_started.connect(func() -> void:
		ui_sound.emit(&"tick")
		_show_hint(slot, -1.0))
	del.released_early.connect(func() -> void: _show_hint(slot, HINT_SECONDS))
	del.held.connect(_ask_confirm.bind(slot))
	col.add_child(del)
	delete_buttons.append(del)
	# no cartao vazio o Apagar some, mas o espaco fica (cartoes alinhados na mesma altura)
	var spacer := Control.new()
	spacer.name = "DeleteSpacer%d" % slot
	spacer.custom_minimum_size = Vector2(0, DELETE_H)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	spacers.append(spacer)
	var hint := PanelContainer.new()
	hint.name = "Hint%d" % slot
	hint.theme_type_variation = &"PillPanel"
	hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# G15: "Segure [botao] para apagar" com o desenho do aparelho em uso (Enter, A verde, X azul claro, mao...).
	var hl := GlyphText.new(30, Color.WHITE)
	hl.name = "HintText"
	hl.set_text(Loc.t("ui.slots.erase_hold"))
	hint.add_child(hl)
	hint.modulate.a = 0.0
	col.add_child(hint)
	hints.append(hint)


func _build_confirm() -> void:
	confirm_overlay = Control.new()
	confirm_overlay.name = "ConfirmOverlay"
	confirm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_overlay.visible = false
	add_child(confirm_overlay)
	var dim := ColorRect.new()
	dim.color = Color(ThemeV2.NAVY_DEEP, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "ConfirmPanel"
	panel.theme_type_variation = &"ModalPanel"
	center.add_child(panel)
	_confirm_panel = panel
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 32)
	panel.add_child(v)
	confirm_portrait = IconView.new()
	confirm_portrait.name = "ConfirmPortrait"
	confirm_portrait.custom_minimum_size = Vector2(170, 170)
	confirm_portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(confirm_portrait)
	confirm_label = Label.new()
	confirm_label.name = "Question"
	confirm_label.theme_type_variation = &"TitleLabel"
	confirm_label.add_theme_font_size_override("font_size", 56)
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(confirm_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	v.add_child(row)
	confirm_no = Button.new()
	confirm_no.name = "ConfirmNo"
	confirm_no.text = Loc.t("ui.slots.erase_no")
	confirm_no.icon = IconView.texture_for(&"home")
	confirm_no.expand_icon = true
	confirm_no.add_theme_constant_override("icon_max_width", 72)
	confirm_no.theme_type_variation = &"QuietButton"
	confirm_no.custom_minimum_size = Vector2(320, 128)
	ThemeV2.springify(confirm_no)
	confirm_no.pressed.connect(_cancel_confirm)
	row.add_child(confirm_no)
	confirm_yes = Button.new()
	confirm_yes.name = "ConfirmYes"
	confirm_yes.text = Loc.t("ui.slots.erase_yes")
	confirm_yes.theme_type_variation = &"OrangeButton"
	confirm_yes.custom_minimum_size = Vector2(380, 128)
	ThemeV2.springify(confirm_yes)
	confirm_yes.pressed.connect(_do_erase)
	row.add_child(confirm_yes)
	for b: Button in [confirm_no, confirm_yes]:
		var other := confirm_yes if b == confirm_no else confirm_no
		b.focus_neighbor_left = b.get_path_to(other)
		b.focus_neighbor_right = b.get_path_to(other)
		b.focus_neighbor_top = b.get_path_to(b)
		b.focus_neighbor_bottom = b.get_path_to(b)
		b.focus_next = b.get_path_to(other)
		b.focus_previous = b.get_path_to(other)
		b.focus_entered.connect(func() -> void: ui_sound.emit(&"focus"))


## Abre a tela (foco no espaco em uso, senao no 1).
func open() -> void:
	visible = true
	confirm_overlay.visible = false
	confirm_slot = 0
	refresh()
	_layout()
	var i := 0
	for c in cards:
		ThemeV2.pop_in(c, 0.85, 0.3, i * 0.05)
		i += 1
	focus_slot(SaveSlots.active if SaveSlots.active >= 1 and SaveSlots.active <= SaveSlots.COUNT else 1)


func focus_slot(slot: int) -> void:
	cards[clampi(slot, 1, SaveSlots.COUNT) - 1].grab_focus()


## Rele os 3 espacos e remonta os cartoes.
func refresh() -> void:
	summaries.clear()
	for i in SaveSlots.COUNT:
		var s := SaveSlots.summary(i + 1)
		summaries.append(s)
		_fill_card(cards[i], s)
		delete_buttons[i].visible = not bool(s["empty"])
		spacers[i].visible = bool(s["empty"])
		hints[i].modulate.a = 0.0
		_hint_left[i] = 0.0
	_wire_focus()


func _fill_card(card: Button, s: Dictionary) -> void:
	for c in card.get_children():
		card.remove_child(c)
		c.queue_free()
	var empty := bool(s["empty"])
	card.theme_type_variation = &"PrimaryButton" if empty else &"QuietButton"
	var slot := int(s["slot"])
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	card.add_child(margin)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	margin.add_child(v)
	var num := Label.new()
	num.name = "SlotName"
	num.theme_type_variation = &"TitleLabel"
	num.text = Loc.t("ui.slots.slot", {"n": slot})
	num.add_theme_font_size_override("font_size", 44)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(num)
	var pic := IconView.new()
	pic.name = "Portrait"
	pic.custom_minimum_size = Vector2(210, 210)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(pic)
	if empty:
		pic.kind = &"boat"
		pic.color = ThemeV2.NAVY
		var l := Label.new()
		l.name = "NewGame"
		l.theme_type_variation = &"TitleLabel"
		l.text = Loc.t("ui.slots.new_game")
		l.add_theme_font_size_override("font_size", 52)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		card.tooltip_text = l.text
	else:
		var hero := StringName(str(s["hero"]))
		pic.color = MemberActor.COLORS.get(hero, ThemeV2.ACTION)
		var path := str(s["portrait"])
		if ResourceLoader.exists(path):
			pic.texture_override = load(path) as Texture2D
		var mrow := HBoxContainer.new()
		mrow.name = "Mission"
		mrow.alignment = BoxContainer.ALIGNMENT_CENTER
		mrow.add_theme_constant_override("separation", 14)
		v.add_child(mrow)
		var mi := IconView.new()
		mi.name = "MissionIcon"
		mi.kind = &"star" if bool(s["complete"]) else StringName(str(s["icon"]))
		mi.color = ThemeV2.ACTION
		mi.custom_minimum_size = Vector2(76, 76)
		mi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mrow.add_child(mi)
		var ml := Label.new()
		ml.name = "MissionName"
		ml.text = Loc.t("ui.slots.complete") if bool(s["complete"]) else Loc.t(str(s["title_key"]))
		ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ml.custom_minimum_size = Vector2(220, 0)
		ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ml.add_theme_font_size_override("font_size", 32)
		ml.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mrow.add_child(ml)
		var erow := HBoxContainer.new()
		erow.name = "Emblems"
		erow.alignment = BoxContainer.ALIGNMENT_CENTER
		erow.add_theme_constant_override("separation", 12)
		v.add_child(erow)
		var ei := IconView.new()
		ei.kind = &"star"
		ei.color = ThemeV2.ACTION
		if ResourceLoader.exists(EMBLEM_ICON):
			ei.texture_override = load(EMBLEM_ICON) as Texture2D
		ei.custom_minimum_size = Vector2(64, 64)
		erow.add_child(ei)
		var el := Label.new()
		el.name = "EmblemCount"
		el.theme_type_variation = &"TitleLabel"
		el.text = Loc.t("ui.slots.emblems", {"found": s["emblems_found"], "total": s["emblems_total"]})
		el.add_theme_font_size_override("font_size", 44)
		erow.add_child(el)
		card.tooltip_text = "%s · %s" % [ml.text, el.text]
	_ignore_mouse(margin)


func _ignore_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		(n as Control).focus_mode = Control.FOCUS_NONE
	for c in n.get_children():
		_ignore_mouse(c)


## Vizinhos de foco conforme os botoes visiveis (o Apagar so existe no cartao cheio).
func _wire_focus() -> void:
	var order: Array[Control] = [back_button]
	for i in SaveSlots.COUNT:
		var c := cards[i]
		var d := delete_buttons[i]
		var left := cards[maxi(i - 1, 0)]
		var right := cards[mini(i + 1, SaveSlots.COUNT - 1)]
		c.focus_neighbor_left = c.get_path_to(left)
		c.focus_neighbor_right = c.get_path_to(right)
		c.focus_neighbor_top = c.get_path_to(back_button)
		c.focus_neighbor_bottom = c.get_path_to(d if d.visible else c)
		d.focus_neighbor_top = d.get_path_to(c)
		d.focus_neighbor_bottom = d.get_path_to(d)
		var dl := delete_buttons[maxi(i - 1, 0)]
		var dr := delete_buttons[mini(i + 1, SaveSlots.COUNT - 1)]
		d.focus_neighbor_left = d.get_path_to(dl if dl.visible else left)
		d.focus_neighbor_right = d.get_path_to(dr if dr.visible else right)
		order.append(c)
		if d.visible:
			order.append(d)
	back_button.focus_neighbor_bottom = back_button.get_path_to(cards[0])
	back_button.focus_neighbor_left = back_button.get_path_to(back_button)
	back_button.focus_neighbor_right = back_button.get_path_to(cards[0])
	back_button.focus_neighbor_top = back_button.get_path_to(back_button)
	for k in order.size():
		var cur := order[k]
		cur.focus_next = cur.get_path_to(order[(k + 1) % order.size()])
		cur.focus_previous = cur.get_path_to(order[(k - 1 + order.size()) % order.size()])


func _layout() -> void:
	if _safe == null:
		return
	var vp := size
	var m := Vector2(maxf(SAFE_MIN, vp.x * SAFE_FRACTION), maxf(SAFE_MIN, vp.y * SAFE_FRACTION))
	_safe.offset_left = m.x
	_safe.offset_top = m.y
	_safe.offset_right = -m.x
	_safe.offset_bottom = -m.y
	var area := vp - m * 2.0
	var card_w := clampf((area.x - GAP * 2.0) / 3.0, 340.0, 560.0)
	# altura: o que sobra depois do cabecalho, do Apagar e da dica (~56 px), com as separacoes
	var card_h := clampf(area.y - HEADER_H - DELETE_H - 56.0 - 36.0 - 20.0 * 2.0, 420.0, 620.0)
	for i in SaveSlots.COUNT:
		cards[i].custom_minimum_size = Vector2(card_w, card_h)
		delete_buttons[i].custom_minimum_size = Vector2(card_w, DELETE_H)


func _process(delta: float) -> void:
	for i in SaveSlots.COUNT:
		if _hint_left[i] > 0.0:
			_hint_left[i] -= delta / maxf(Engine.time_scale, 0.0001)
			if _hint_left[i] <= 0.0:
				hints[i].modulate.a = 0.0


## Mostra a dica "Segure para apagar" sob o cartao; seconds < 0 = enquanto segura (some ao soltar sem ser cedo).
func _show_hint(slot: int, seconds: float) -> void:
	hints[slot - 1].modulate.a = 1.0
	_hint_left[slot - 1] = seconds if seconds > 0.0 else 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# G14: o A do controle esta em ui_accept (a GUI aperta o botao em foco). `interact` (E / X) continua apertando o
	# botao em foco, por coerencia com o resto do jogo (E/X e "agir"). (O Apagar trata `interact` sozinho, segurando.)
	if event.is_action_pressed(&"interact") and not event.is_echo():
		var f := get_viewport().gui_get_focus_owner() as BaseButton
		if f != null and is_ancestor_of(f) and not f is HoldButton and not f.disabled:
			get_viewport().set_input_as_handled()
			f.pressed.emit()
		return
	if not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if confirm_overlay.visible:
		_cancel_confirm()
	else:
		_on_back()


func _on_back() -> void:
	ui_sound.emit(&"back")
	back_requested.emit()


func _on_card(slot: int) -> void:
	if confirm_overlay.visible:
		return
	ui_sound.emit(&"confirm")
	if bool(summaries[slot - 1]["empty"]):
		SaveSlots.start_new(slot)
	else:
		SaveSlots.select(slot)
	print("[RB] slots jogar espaco %d (novo=%s)" % [slot, summaries[slot - 1]["empty"]])
	play_requested.emit(slot)


func _ask_confirm(slot: int) -> void:
	confirm_slot = slot
	hints[slot - 1].modulate.a = 0.0
	confirm_label.text = Loc.t("ui.slots.erase_confirm", {"n": slot})
	var sm := summaries[slot - 1]
	confirm_portrait.color = MemberActor.COLORS.get(StringName(str(sm.get("hero", "tracker"))), ThemeV2.ACTION)
	var pp := str(sm.get("portrait", ""))
	confirm_portrait.texture_override = load(pp) as Texture2D if pp != "" and ResourceLoader.exists(pp) else null
	confirm_overlay.visible = true
	ThemeV2.pop_in(_confirm_panel, 0.85)
	ui_sound.emit(&"whoosh")
	confirm_no.grab_focus()
	print("[RB] slots confirmar apagar espaco %d" % slot)


func _cancel_confirm() -> void:
	var slot := confirm_slot
	confirm_overlay.visible = false
	confirm_slot = 0
	ui_sound.emit(&"back")
	if slot > 0:
		delete_buttons[slot - 1].grab_focus()


func _do_erase() -> void:
	var slot := confirm_slot
	confirm_overlay.visible = false
	confirm_slot = 0
	if slot <= 0:
		return
	SaveSlots.erase(slot)
	ui_sound.emit(&"select")
	refresh()
	focus_slot(slot)
