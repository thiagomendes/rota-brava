extends RefCounted
## Marca e HUD v2 (RB-R1): SVG de emotes/logo/emblema importam; HUD nas 3 proporcoes dentro da area segura;
## botao de acao >= 128; retratos; legenda com emotes e texto +40%; glifo por dispositivo; foco inicial; opcoes
## salvam e recarregam. Inclui mutacoes (encolher o botao de acao, tirar um SVG) que precisam reprovar.
## Testes nao comprovam aparencia: isso fica nas capturas (captures/rb-r1/ui/).

const EMOTES: Array[StringName] = [&"paw", &"boot", &"notebook", &"rope", &"helm", &"boat", &"buoy", &"leaf",
	&"island", &"horn", &"question", &"exclamation", &"idea", &"heart", &"star", &"sweat", &"music", &"look",
	&"wave", &"thumbs_up"]
const BRAND := ["res://ui/brand/emblem_full.svg", "res://ui/brand/emblem_simple.svg", "res://ui/brand/emblem_mono.svg",
	"res://ui/brand/logo_h.svg", "res://ui/brand/logo_stack.svg", "res://ui/brand/screens/title.svg",
	"res://ui/brand/screens/hud.svg", "res://ui/brand/screens/handoff.svg", "res://ui/brand/screens/complete.svg"]
const RATIOS := {"16:9": Vector2i(1920, 1080), "20:9": Vector2i(2400, 1080), "4:3": Vector2i(1920, 1440)}
const TEST_CFG := "user://test_options.cfg"

var r


## Emotes ausentes (arquivo SVG sumiu ou nao importa como textura legivel a 48 px).
func _missing_emotes() -> Array[String]:
	var bad: Array[String] = []
	for e in EMOTES:
		var p := IconView.icon_path(e)
		var tex: Texture2D = load(p) as Texture2D if FileAccess.file_exists(p) else null
		if tex == null or tex.get_width() < 48:
			bad.append(String(e))
	return bad


func _action_ok(hud: Hud) -> bool:
	var b := hud.action_button()
	return b.size.x >= Hud.MIN_TOUCH and b.size.y >= Hud.MIN_TOUCH


func _outside(hud: Hud, bounds: Rect2) -> Array[String]:
	var bad: Array[String] = []
	for c in hud.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree() or not (ctl is Button or ctl is Label or ctl is PanelContainer or ctl is IconView):
			continue
		if not bounds.grow(5.0).encloses(ctl.get_global_rect()):
			bad.append("%s %s" % [ctl.name, ctl.get_global_rect()])
	return bad


## Olho fechado agora no rosto do visual: max(alegre, blink) da malha do rosto (G1; `alegre` fecha os olhos nos herois v2).
static func eyes_closed_now(vis: CharacterVisual) -> float:
	var face := vis.face_mesh()
	if face == null:
		return 0.0
	var v := 0.0
	for key in ["alegre", "blink"]:
		var idx := face.find_blend_shape_by_name(key)
		if idx >= 0:
			v = maxf(v, face.get_blend_shape_value(idx))
	return v


## G1 (RB-R1): os herois do palco da tela-titulo no idle, com a expressao que a tela mantem, ficam de olhos abertos quase
## sempre (<= 25% do tempo e <= 0,6 s seguidos com o olho fechado). Antes a tela mantinha `alegre` 0,6: olhos sempre fechados.
func _eyes_open_on_stage(scr: TitleScreen, label: String) -> void:
	r.check(scr.hero_models.size() == 3, "%s: tres herois 3D no palco" % label)
	for vis in scr.hero_models:
		vis.play(&"idle", 1.0, 0.0)
		var closed := 0
		var run := 0.0
		var longest := 0.0
		var steps := 360
		for i in steps:
			vis._process(1.0 / 30.0)
			if eyes_closed_now(vis) >= 0.5:
				closed += 1
				run += 1.0 / 30.0
				longest = maxf(longest, run)
			else:
				run = 0.0
		r.check(float(closed) / steps <= 0.25 and longest <= 0.6, "%s: %s de olhos abertos no idle (fechados %.0f%%, maior trecho %.2f s)"
			% [label, vis.get_parent().name, 100.0 * closed / steps, longest])


func run(runner) -> void:
	r = runner
	Options.motion_override = 1
	# --- arquivos da marca ---
	var missing := _missing_emotes()
	r.check(missing.is_empty(), "os 20 emotes existem e importam como textura >= 48 px (faltam: %s)" % str(missing))
	for p: String in BRAND:
		r.check(load(p) is Texture2D, "marca importa: %s" % p.get_file())
	for k: StringName in [&"line", &"bank", &"harbor", &"magnifier", &"help", &"pause", &"gear", &"home"]:
		r.check(IconView.texture_for(k) != null, "pictograma '%s' resolve para um SVG" % k)

	# --- mutacao: tirar um SVG reprova e e restaurado ---
	var victim := ProjectSettings.globalize_path(IconView.icon_path(&"paw"))
	var moved := DirAccess.rename_absolute(victim, victim + ".mut") == OK
	r.check(moved and not _missing_emotes().is_empty(), "mutacao: sem paw.svg o teste de emotes reprova")
	if moved:
		DirAccess.rename_absolute(victim + ".mut", victim)
	r.check(_missing_emotes().is_empty(), "mutacao restaurada: paw.svg de volta")

	# --- HUD nas 3 proporcoes ---
	var long_key := "study.sub.tracker.long"
	for ratio: String in RATIOS:
		var size: Vector2i = RATIOS[ratio]
		var sv := SubViewport.new()
		sv.size = size
		sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
		r.tree.root.add_child(sv)
		var hud := Hud.new()
		sv.add_child(hud)
		await r.frames(2)
		hud.set_objective(Loc.t("study.objective.long"), &"paw")
		hud.set_member(&"climber")
		hud.show_prompt(Loc.t("ui.action.examine"), &"magnifier")
		var emotes: Array[StringName] = [&"question", &"paw", &"idea"]
		hud.say(long_key, {}, false, emotes)
		await r.frames(3)
		var safe := hud.safe_rect()
		var bad := _outside(hud, safe)
		r.check(bad.is_empty(), "[%s] HUD v2 com legenda longa + emotes: tudo na area segura %s" % [ratio, str(bad)])
		r.check(_action_ok(hud), "[%s] botao de acao >= %d px (%s)" % [ratio, int(Hud.MIN_TOUCH), str(hud.action_button().size)])
		var portraits := hud.find_children("Portrait", "IconView", true, false)
		var visible_p := portraits.filter(func(p: Node) -> bool: return (p as Control).is_visible_in_tree())
		r.check(visible_p.size() == 3, "[%s] 3 retratos de herois visiveis (%d)" % [ratio, visible_p.size()])
		var active := hud.find_child("Portrait_climber", true, false).get_node("Portrait") as Control
		var idle := hud.find_child("Portrait_tracker", true, false).get_node("Portrait") as Control
		r.check(active.size.x > idle.size.x * 1.3, "[%s] o retrato ativo e maior (%d > %d)" % [ratio, int(active.size.x), int(idle.size.x)])
		r.check(hud.current_emotes() == emotes, "[%s] o balao mostra os emotes pedidos %s" % [ratio, str(hud.current_emotes())])
		var sub := hud.find_child("SubtitlePanel", true, false) as Control
		var text := sub.find_children("*", "Label", true, false)[1] as Label
		r.check(text.get_line_count() <= 3 and sub.size.y <= size.y * 0.25,
			"[%s] legenda +40%% com emotes cabe em 3 linhas e 25%% da altura (%d linhas, %d px)" % [ratio, text.get_line_count(), int(sub.size.y)])
		r.check(not sub.get_global_rect().intersects(hud.action_button().get_global_rect()), "[%s] balao e botao de acao nao se sobrepoem" % ratio)
		# glifo por dispositivo, sem mudar estado
		var before := hud.prompt_text()
		hud.set_device(&"pad")
		r.check(hud.glyph_text() == Loc.t("ui.glyph.pad"), "[%s] controle: glifo '%s'" % [ratio, hud.glyph_text()])
		hud.set_device(&"touch")
		var badge := hud.find_child("GlyphBadge", true, false) as Control
		r.check(not badge.visible and hud.prompt_text() == before and hud.prompt_visible(), "[%s] toque: sem glifo e o prompt nao muda" % ratio)
		hud.set_device(&"keyboard")
		r.check(hud.glyph_text() == Loc.t("ui.glyph.keyboard"), "[%s] teclado: glifo '%s'" % [ratio, hud.glyph_text()])
		# retrato renderizado
		var tex := IconView.texture_for(&"star")
		hud.set_portrait_texture(&"climber", tex)
		r.check((active as IconView).current_texture() == tex, "[%s] set_portrait_texture troca o retrato" % ratio)
		# mutacao: encolher o botao de acao
		if ratio == "16:9":
			var b := hud.action_button()
			var keep := b.custom_minimum_size
			b.custom_minimum_size = Vector2(80, 80)
			b.reset_size()
			await r.frames(2)
			r.check(not _action_ok(hud), "mutacao: botao de acao de 80 px reprova")
			b.custom_minimum_size = keep
			await r.frames(2)
			r.check(_action_ok(hud), "mutacao restaurada: botao de acao de volta a %d px" % int(keep.x))
		hud.clear_speech()
		sv.queue_free()
		await r.frames(2)

	# --- telas com botoes: foco inicial ---
	for path: String in ["res://ui/title/title_screen.tscn", "res://ui/main_menu.tscn"]:
		var scr := (load(path) as PackedScene).instantiate() as TitleScreen
		r.tree.root.add_child(scr)
		await r.frames(3)
		var f := scr.get_viewport().gui_get_focus_owner()
		r.check(f == scr.play_button, "%s: foco inicial em Jogar" % path.get_file())
		r.check(scr.logo.texture != null and scr.hero_root != null, "%s: logo SVG e palco dos herois presentes" % path.get_file())
		_eyes_open_on_stage(scr, path.get_file())
		scr.options_panel.open()
		await r.frames(2)
		r.check(scr.get_viewport().gui_get_focus_owner() == scr.options_panel.back_button, "%s: opcoes abrem com foco em Voltar" % path.get_file())
		scr.queue_free()
		await r.frames(2)

	# --- opcoes salvam e recarregam (arquivo de teste; o do jogador e preservado) ---
	Options.load_file()
	Options.set_value("audio", "Musica", 0.3, false)
	Options.set_value("access", "subtitle_size", 2, false)
	Options.set_value("access", "steering_assist", false, false)
	r.check(Options.save_file(TEST_CFG) == OK, "opcoes: salvar em arquivo")
	Options.load_file("user://nao_existe.cfg")
	r.check(is_equal_approx(float(Options.get_value("audio", "Musica")), 0.7), "opcoes: sem arquivo volta ao padrao")
	Options.load_file(TEST_CFG)
	r.check(is_equal_approx(float(Options.get_value("audio", "Musica")), 0.3) and int(Options.get_value("access", "subtitle_size")) == 2
		and not bool(Options.get_value("access", "steering_assist")), "opcoes: recarregar devolve os valores salvos")
	r.check(is_equal_approx(Options.subtitle_scale(), Options.SUBTITLE_SCALES[2]), "opcoes: tamanho de legenda 3 aplica a escala")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))
	Options.load_file()
	Options.apply_all()
	Options.motion_override = -1
