extends RefCounted
## HUD e estudo de UI (RB-03-ui): tres proporcoes, area segura, alvo de toque, legenda longa, foco inicial e fontes.
## Os tamanhos sao os do viewport virtual com stretch canvas_items/expand a partir de 1920x1080:
## 16:9 = 1920x1080, 20:9 = 2400x1080 (telefone alongado), 4:3 = 1920x1440 (tablet).
## Testes nao comprovam aparencia: isso fica nas capturas (captures/rb-03/ui/).

const RATIOS := {"16:9": Vector2i(1920, 1080), "20:9": Vector2i(2400, 1080), "4:3": Vector2i(1920, 1440)}
const ACCENT_CHARS := "ãõçéêáâôüíúÃÕÇÉÊÁÂÔÜÍÚñÑ"
const TOL := 1.0

var r


func _viewport(size: Vector2i) -> SubViewport:
	var sv := SubViewport.new()
	sv.size = size
	sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	r.tree.root.add_child(sv)
	return sv


func _longest_ep01_line() -> int:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/pt_BR.json"))
	var best := 0
	for k: String in (data as Dictionary).keys():
		if k.begins_with("ep01.") and not k.contains("objective") and not k.contains("complete"):
			best = maxi(best, String(data[k]).length())
	return best


func _visible_ui(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	for c in root.find_children("*", "Control", true, false):
		var ctl := c as Control
		if ctl.is_visible_in_tree() and (ctl is Button or ctl is Label or ctl is PanelContainer or ctl is IconView):
			out.append(ctl)
	return out


## Retorna os controles fora de `bounds` (rect inflado por `grow` para o contorno de foco). Ignora `skip`.
func _outside(root: Node, bounds: Rect2, grow: float, skip: Array[Node] = []) -> Array[String]:
	var bad: Array[String] = []
	for ctl in _visible_ui(root):
		if ctl in skip:
			continue
		var rect := ctl.get_global_rect()
		if ctl is Button:
			rect = rect.grow(grow)
		if not bounds.grow(TOL + 4.0).encloses(rect):
			bad.append("%s %s" % [ctl.name, rect])
	return bad


func _states(hud: Hud) -> Array[Callable]:
	var opts: Array[Dictionary] = [
		{"id": &"bank", "label": Loc.t("study.choice.bank"), "icon": &"bank"},
		{"id": &"harbor", "label": Loc.t("study.choice.harbor"), "icon": &"harbor"}]
	return [
		func() -> void:
			hud.set_objective(Loc.t("study.objective.long"), &"boot")
			hud.set_member(&"climber")
			hud.show_prompt(Loc.t("ui.action.examine"), &"paw")
			hud.say("study.sub.tracker.long"),
		func() -> void:
			hud.clear_speech()
			hud.set_objective(Loc.t("study.objective.accents"), &"helm")
			hud.show_prompt(Loc.t("study.prompt.accents"), &"paw")
			hud.say("study.sub.pilot.accents"),
		func() -> void:
			hud.clear_speech()
			hud.hide_prompt()
			hud.open_choice(Loc.t("study.choice.title"), opts),
		func() -> void:
			hud.close_choice()
			hud.open_handoff(Loc.t("study.handoff.text"), &"climber"),
		func() -> void:
			hud.close_handoff()
			hud.open_pause(),
		func() -> void:
			hud.close_pause()
			hud.open_complete(),
	]


func _focus_in(hud: Hud, overlay_name: String) -> bool:
	var owner := hud.get_viewport().gui_get_focus_owner()
	var overlay := hud.find_child(overlay_name, true, false)
	return owner is Button and overlay != null and overlay.is_ancestor_of(owner) and owner.is_visible_in_tree()


func run(runner) -> void:
	r = runner
	# --- fontes e temas ---
	for o in UiTheme.OPTIONS:
		var base := load(UiTheme.FONTS[o]) as FontFile
		r.check(base != null, "fonte %s carrega" % o)
		var missing := ""
		for ch in ACCENT_CHARS:
			if not base.has_char(ch.unicode_at(0)):
				missing += ch
		r.check(missing.is_empty(), "fonte %s tem os acentos pt-BR (faltam: '%s')" % [o, missing])
		r.check(base.get_string_size(ACCENT_CHARS, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x > 34.0 * 6.0,
			"fonte %s mede largura para os acentuados" % o)
		var th := load("res://ui/study/theme_%s.tres" % o) as Theme
		r.check(th != null and th.default_font is FontVariation, "tema %s carrega com fonte" % o)
		var fv := th.default_font as FontVariation
		r.check(fv.variation_opentype.has(UiTheme.WGHT_TAG), "tema %s aplica o peso (eixo wght por tag inteira)" % o)
		var focus := th.get_stylebox("focus", "Button") as StyleBoxFlat
		r.check(focus.border_width_left >= 8 and focus.border_color.a > 0.9, "tema %s: foco com contorno grosso e opaco" % o)
		r.check(th.get_stylebox("focus", "Button") != th.get_stylebox("normal", "Button"), "tema %s: foco distinto do normal" % o)
	r.check(Hud.MIN_TOUCH >= 96.0, "alvo de toque da referencia >= 96 px (48 dp a 2 px/dp)")

	# --- legenda +40% ---
	var longest := _longest_ep01_line()
	var long_len := Loc.t("study.sub.tracker.long").length()
	r.check(long_len >= int(longest * 1.4), "a legenda longa do estudo tem >= 140%% da maior fala (%d >= %d)" % [long_len, int(longest * 1.4)])

	# --- layout por proporcao ---
	for ratio: String in RATIOS:
		var size: Vector2i = RATIOS[ratio]
		var sv := _viewport(size)
		var hud := Hud.new()
		sv.add_child(hud)
		await r.frames(3)
		var screen := Rect2(Vector2.ZERO, Vector2(size))
		var safe := hud.safe_rect()
		r.check(safe.size.x < screen.size.x and safe.position.x >= Hud.SAFE_MIN and safe.position.y >= Hud.SAFE_MIN,
			"[%s] a area segura existe e tem margem >= %d" % [ratio, int(Hud.SAFE_MIN)])
		var states := _states(hud)
		var names := ["HUD+legenda longa", "pseudoidioma", "escolha", "troca", "pausa", "conclusao"]
		var overlays := ["", "", "ChoicePanel", "HandoffOverlay", "PauseOverlay", "CompleteOverlay"]
		for i in states.size():
			states[i].call()
			await r.frames(3)
			var bad := _outside(hud, safe, 0.0)
			r.check(bad.is_empty(), "[%s] %s: controles visiveis dentro da area segura %s" % [ratio, names[i], str(bad)])
			var small := 0
			for ctl in _visible_ui(hud):
				if ctl is Button and (ctl.size.y < 96.0 or ctl.size.x < 96.0 or ctl.size.y < Hud.MIN_TOUCH):
					small += 1
			r.check(small == 0, "[%s] %s: botoes visiveis >= 96 px e >= %d na altura (%d pequenos)" % [ratio, names[i], int(Hud.MIN_TOUCH), small])
			if overlays[i] != "":
				r.check(_focus_in(hud, overlays[i]), "[%s] %s: foco inicial num botao da propria tela" % [ratio, names[i]])
		# legenda longa e pilha inferior (estado 0)
		states[0].call()
		await r.frames(3)
		var sub := hud.find_child("SubtitlePanel", true, false) as Control
		var prompt := hud.find_child("PromptPanel", true, false) as Control
		var obj := hud.find_child("ObjectivePanel", true, false) as Control
		var mem := hud.find_child("MemberPanel", true, false) as Control
		var sub_text := sub.find_children("*", "Label", true, false)[1] as Label
		r.check(sub.visible and sub_text.get_line_count() <= 3, "[%s] legenda longa cabe em ate 3 linhas (%d)" % [ratio, sub_text.get_line_count()])
		r.check(sub.size.y <= size.y * 0.25, "[%s] a legenda ocupa no maximo 25%% da altura (%d px)" % [ratio, int(sub.size.y)])
		r.check(not sub.get_global_rect().intersects(prompt.get_global_rect()), "[%s] legenda e acao contextual nao se sobrepoem" % ratio)
		r.check(not obj.get_global_rect().intersects(mem.get_global_rect()), "[%s] objetivo e quem controla nao se sobrepoem" % ratio)
		var left_thumb := Rect2(0, size.y * 0.55, size.x * 0.18, size.y * 0.45)
		var right_thumb := Rect2(size.x * 0.82, size.y * 0.55, size.x * 0.18, size.y * 0.45)
		var stack_ok := true
		for p: Control in [sub, prompt]:
			if p.get_global_rect().intersects(left_thumb) or p.get_global_rect().intersects(right_thumb):
				stack_ok = false
		r.check(stack_ok, "[%s] legenda e acao ficam entre as zonas dos polegares (18%% laterais, base)" % ratio)
		hud.clear_speech()
		sv.queue_free()
		await r.frames(2)

	# --- cena de estudo: 3 opcoes x telas x proporcoes ---
	var scene := load("res://ui/study/ui_study.tscn") as PackedScene
	for ratio: String in RATIOS:
		var size: Vector2i = RATIOS[ratio]
		var sv := _viewport(size)
		var study := scene.instantiate() as UiStudy
		sv.add_child(study)
		await r.frames(3)
		var screen := Rect2(Vector2.ZERO, Vector2(size))
		var safe := study.hud.safe_rect()
		var all_ok := true
		var detail := ""
		for o in UiTheme.OPTIONS:
			study.set_option(o)
			for s in UiStudy.SCREENS.size():
				study.show_screen(s)
				await r.frames(3)
				var bad := _outside(study, screen, 22.0, [study.get_node("Caption")])
				bad.append_array(_outside(study.hud, safe, 0.0))
				if not bad.is_empty():
					all_ok = false
					detail += " %s/%d:%s" % [o, s, str(bad)]
		r.check(all_ok, "[%s] estudo: 3 opcoes x %d telas com tudo dentro da tela e da area segura%s" % [ratio, UiStudy.SCREENS.size(), detail])
		var caption := study.get_node("Caption") as Label
		r.check(screen.grow(TOL).encloses(caption.get_global_rect()), "[%s] a legenda do estudo cabe na largura (%s)" % [ratio, str(caption.get_global_rect())])
		study.hud.clear_speech()
		sv.queue_free()
		await r.frames(2)

	# --- menu: foco inicial ---
	var menu := (load("res://ui/main_menu.tscn") as PackedScene).instantiate() as Control
	r.tree.root.add_child(menu)
	await r.frames(3)
	var f := menu.get_viewport().gui_get_focus_owner()
	r.check(f is Button and menu.is_ancestor_of(f), "menu: foco inicial num botao")
	var heights: Array[int] = []
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).is_visible_in_tree():
			heights.append(int((b as Button).size.y))
	print("INFO  alturas dos botoes do menu (nao verificado como PASS/FAIL; menu pertence ao lead): ", heights)
	menu.queue_free()
	await r.frames(2)
