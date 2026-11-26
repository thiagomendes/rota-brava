extends RefCounted
## G12 + G13 (RB-R1): menu principal so com Jogar/Opcoes/Sair, "Rever abertura" dentro de Opcoes, e a tela dos 3
## espacos de jogo (SlotScreen): cartao vazio = novo jogo, cheio continua do ponto certo, apagar exige SEGURAR e
## confirmar (soltar antes nao apaga), navegacao por teclado, controle e Tab, `ui_cancel` volta, contraste >= 4,5:1,
## alvos grandes nas 3 proporcoes, movimento reduzido e nada de 3D na tela. Arquivos dos espacos da suite (prefixo
## proprio do run_tests). Nao comprova render: a imagem real fica nas capturas (captures/g13/).

const MENU := "res://ui/main_menu.tscn"
const RATIOS := {"16:9": Vector2i(1920, 1080), "20:9": Vector2i(2400, 1080), "4:3": Vector2i(1920, 1440)}
## Alvo minimo (px na referencia de 1080 de altura); 48 dp num telefone de 1080 px de altura ~ 110 px.
const MIN_TARGET := 110.0

var r


func run(runner) -> void:
	r = runner
	var keep_motion: int = Options.motion_override
	Options.motion_override = 0
	_clean()
	await _menu_case()
	await _replay_intro_case()
	await _cards_case()
	await _choose_case()
	await _navigation_case()
	await _hold_case()
	await _hold_realtime_case()
	await _contrast_case()
	for ratio: String in RATIOS:
		await _layout_case(ratio, RATIOS[ratio])
	await _reduced_motion_case()
	_clean()
	Options.motion_override = keep_motion


func _clean() -> void:
	for i in SaveSlots.COUNT:
		SaveSlots.erase(i + 1)
	SaveSlots.active = 0
	Ep01V3Main.save_path = ""
	Ep01V3Cutscene.seen_path = ""


func _write_m2(slot: int) -> void:
	var f := FileAccess.open(SaveSlots.save_path(slot), FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": MissionSave.VERSION, "episode": "ep01", "current": "M2", "missions": [
		{"id": "M0", "state": Mission.State.COMPLETED, "emblems": []},
		{"id": "M1", "state": Mission.State.COMPLETED, "emblems": ["emb_m1_mooring"]},
		{"id": "M2", "state": Mission.State.INACTIVE, "emblems": []}]}))
	f.close()


func _viewport(size: Vector2i) -> SubViewport:
	var sv := SubViewport.new()
	sv.size = size
	sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	sv.gui_disable_input = false
	r.tree.root.add_child(sv)
	return sv


func _open_screen(size: Vector2i = RATIOS["16:9"]) -> Array:
	var sv := _viewport(size)
	var scr := SlotScreen.new()
	sv.add_child(scr)
	await r.frames(2)
	scr.open()
	await r.frames(3)
	return [sv, scr]


func _close(sv: Node) -> void:
	sv.queue_free()
	await r.frames(3)


func _key(sv: SubViewport, k: Key, shift: bool = false) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.shift_pressed = shift
		e.pressed = pressed
		sv.push_input(e)
	await r.frames(1)


func _pad(sv: SubViewport, b: JoyButton) -> void:
	for pressed in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = pressed
		sv.push_input(e)
	await r.frames(1)


func _action(sv: SubViewport, action: StringName, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	sv.push_input(e)
	await r.frames(1)


func _tap(sv: SubViewport, action: StringName) -> void:
	await _action(sv, action, true)
	await _action(sv, action, false)


func _focus(sv: SubViewport) -> Control:
	return sv.gui_get_focus_owner()


# ---------- G12: menu ----------

func _menu_case() -> void:
	var sv := _viewport(RATIOS["16:9"])
	var menu := (load(MENU) as PackedScene).instantiate() as MainMenu
	sv.add_child(menu)
	await r.frames(3)
	var names: Array[String] = []
	for b in menu.menu.get_children():
		if b is Button and (b as Button).visible:
			names.append(String(b.name))
	r.check(names == ["PlayButton", "OptionsButton", "QuitButton"], "G12 menu: so Jogar, Opcoes e Sair (%s)" % str(names))
	r.check(_focus(sv) == menu.play_button, "G12 menu: foco inicial em Jogar")
	r.check(menu.find_child("ReferencesButton", true, false) == null and menu.find_child("IntroButton", true, false) == null,
		"G12 menu: Referencias e Ver abertura sairam do menu principal")
	r.check(not Loc.has_key("ui.menu.references") and not Loc.has_key("ui.menu.watch_intro") and not Loc.has_key("ui.menu.continue"),
		"G12 i18n: chaves sem uso removidas (references, watch_intro, continue)")
	var src := FileAccess.get_file_as_string("res://ui/main_menu.gd")
	r.check(src.contains("\"--ref-demo\"") and src.contains("REFERENCE_SCENE"), "G12: a demo de referencias continua por --ref-demo")
	# Jogar abre os espacos por cima, sem 3D atras
	await _tap(sv, &"ui_accept")
	await r.frames(2)
	r.check(menu.slot_screen.visible and not menu.menu.visible and _focus(sv) == menu.slot_screen.cards[0],
		"G13 menu: Jogar abre os espacos de jogo com foco no cartao 1")
	r.check(menu.key_art == null or not menu.key_art.visible, "G13 menu: a arte-chave 3D fica escondida atras dos espacos")
	await _tap(sv, &"ui_cancel")
	r.check(not menu.slot_screen.visible and menu.menu.visible and _focus(sv) == menu.play_button,
		"G13 menu: ui_cancel nos espacos volta ao menu com foco em Jogar")
	await _close(sv)


func _replay_intro_case() -> void:
	var menu := (load(MENU) as PackedScene).instantiate() as MainMenu
	r.tree.root.add_child(menu)
	r.tree.current_scene = menu
	await r.frames(3)
	await _wait_loader()
	menu._open_options()
	await r.frames(2)
	var b := menu.options_panel.intro_button
	r.check(b != null and b.is_visible_in_tree() and menu.options_panel.is_ancestor_of(b) and b.text == Loc.t("ui.options.replay_intro"),
		"G12 opcoes: Rever abertura dentro de Opcoes")
	r.check(b != null and b.size.y >= MIN_TARGET, "G12 opcoes: Rever abertura com alvo grande (%.0f px)" % (b.size.y if b else 0.0))
	# o foco chega nele pelo teclado (dentro do painel)
	var reached := false
	for i in 12:
		await _tap_root(&"ui_down")
		if menu.get_viewport().gui_get_focus_owner() == b:
			reached = true
			break
	r.check(reached, "G12 opcoes: Rever abertura alcancavel com setas")
	var hud_panel := OptionsPanel.new()
	r.tree.root.add_child(hud_panel)
	await r.frames(1)
	r.check(hud_panel.intro_button == null, "G12 opcoes: a pausa do jogo (painel sem o menu) nao mostra Rever abertura")
	hud_panel.queue_free()
	# apertar: abertura pelo SceneLoader (tocada de verdade, tempo 8x) e volta ao menu sozinha
	GameIntroScene.next_scene = GameIntroScene.EP01_SCENE
	Ep01V3Cutscene.enabled = true
	Ep01V3Cutscene.reset_seen()
	b.grab_focus()
	await _tap_root(&"ui_accept")
	var loader := SceneLoaderService.instance()
	r.check(loader.target_path == GameIntroScene.SELF_SCENE and GameIntroScene.next_scene == GameIntroScene.MENU_SCENE,
		"G12 opcoes: Rever abertura toca a abertura pelo SceneLoader e pede volta ao menu")
	var saw_intro := false
	var n := 0
	var t0 := Time.get_ticks_msec()
	Engine.time_scale = 8.0
	while Time.get_ticks_msec() - t0 < 240000 and not (saw_intro and r.tree.current_scene is MainMenu and not loader.is_busy()):
		if r.tree.current_scene is GameIntroScene:
			saw_intro = true
		await r.tree.process_frame
		n += 1
	Engine.time_scale = 1.0
	Ep01V3Cutscene.enabled = false
	r.check(saw_intro and r.tree.current_scene is MainMenu, "G12 opcoes: a abertura termina voltando ao menu (%d quadros, %d ms, cena %s)"
		% [n, Time.get_ticks_msec() - t0, r.tree.current_scene.scene_file_path if r.tree.current_scene else "nenhuma"])
	if r.tree.current_scene is MainMenu:
		r.check(r.tree.current_scene.get_viewport().gui_get_focus_owner() == (r.tree.current_scene as MainMenu).play_button,
			"G12: de volta ao menu, foco em Jogar")
		r.tree.current_scene.queue_free()
		await r.frames(2)
		r.tree.current_scene = null
	GameIntroScene.next_scene = GameIntroScene.EP01_SCENE


func _tap_root(action: StringName) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await r.frames(1)


func _wait_loader() -> void:
	var n := 0
	while SceneLoaderService.instance().is_busy() and n < 6000:
		await r.tree.process_frame
		n += 1


# ---------- G13: cartoes ----------

func _cards_case() -> void:
	_clean()
	var opened := await _open_screen()
	var sv := opened[0] as SubViewport
	var scr := opened[1] as SlotScreen
	r.check(scr.cards.size() == 3, "espacos: 3 cartoes")
	var all_new := true
	for c in scr.cards:
		all_new = all_new and c.find_child("NewGame", true, false) != null
	r.check(all_new, "espacos: sem salvo, os 3 cartoes mostram Novo jogo")
	r.check(not scr.delete_buttons[0].visible and not scr.delete_buttons[1].visible and not scr.delete_buttons[2].visible,
		"espacos: cartao vazio nao tem Apagar")
	r.check(scr.find_children("*", "Node3D", true, false).is_empty() and scr.find_children("*", "SubViewport", true, false).is_empty(),
		"espacos: a tela nao tem 3D (so a imagem parada)")
	var still := scr.get_node_or_null("KeyArtStill") as TextureRect
	var veil := scr.get_node_or_null("Veil") as ColorRect
	r.check(still != null and still.texture != null and still.texture.resource_path == SlotScreen.STILL and veil != null and veil.color.a > 0.4,
		"espacos: fundo = imagem parada da arte-chave com veu")
	_write_m2(2)
	scr.refresh()
	await r.frames(2)
	var card := scr.cards[1]
	var name_l := card.find_child("MissionName", true, false) as Label
	var count_l := card.find_child("EmblemCount", true, false) as Label
	var icon := card.find_child("MissionIcon", true, false) as IconView
	var portrait := card.find_child("Portrait", true, false) as IconView
	r.check(name_l != null and name_l.text == Loc.t("ep01v3.mission.M2.title"), "cartao cheio: nome da missao atual (M2)")
	r.check(icon != null and icon.kind == &"rope" and icon.current_texture() != null, "cartao cheio: icone da missao (corda)")
	r.check(count_l != null and count_l.text == "1/10", "cartao cheio: emblemas 1/10 (%s)" % (count_l.text if count_l else "-"))
	r.check(portrait != null and portrait.texture_override != null and portrait.texture_override.resource_path.ends_with("pico_neutra.png"),
		"cartao cheio: retrato do heroi (Pico, retrato do HUD)")
	r.check(scr.delete_buttons[1].visible and card.find_child("NewGame", true, false) == null, "cartao cheio: tem Apagar e nao diz Novo jogo")
	var blocked := false
	for n in card.find_children("*", "Control", true, false):
		blocked = blocked or (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE or (n as Control).focus_mode != Control.FOCUS_NONE
	r.check(not blocked, "cartao: conteudo nao pega mouse nem foco (o cartao inteiro e o alvo)")
	await _close(sv)


func _choose_case() -> void:
	_clean()
	_write_m2(2)
	var opened := await _open_screen()
	var sv := opened[0] as SubViewport
	var scr := opened[1] as SlotScreen
	var chosen: Array[int] = []
	scr.play_requested.connect(func(s: int) -> void: chosen.append(s))
	# vazio -> novo jogo no espaco 1
	scr.focus_slot(1)
	await _tap(sv, &"ui_accept")
	var s1 := SaveSlots.summary(1)
	r.check(chosen == [1] and not s1["empty"] and s1["mission"] == &"M0" and SaveSlots.active == 1
		and Ep01V3Main.save_path == SaveSlots.save_path(1), "escolher vazio: novo jogo no espaco 1 (M0) e o Ep01 grava nele")
	# cheio -> continua do M2, sem mexer no salvo
	var before := FileAccess.get_file_as_string(SaveSlots.save_path(2))
	scr.focus_slot(2)
	await _tap(sv, &"ui_accept")
	r.check(chosen == [1, 2] and SaveSlots.active == 2 and Ep01V3Main.save_path == SaveSlots.save_path(2)
		and FileAccess.get_file_as_string(SaveSlots.save_path(2)) == before, "escolher cheio: continua o espaco 2 sem mexer no salvo")
	# o Ep01 do espaco 2 retoma no M2 (ponto certo)
	var main := (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	r.tree.root.add_child(main)
	await r.frames(3)
	r.check(main.current != null and main.current.id == &"M2" and main.emblems_found == 1, "escolher cheio: o Ep01 retoma no M2 com 1 emblema")
	main.queue_free()
	await r.frames(3)
	# clique do mouse no cartao tambem escolhe
	scr.open()
	await r.frames(2)
	var c3 := scr.cards[2]
	var center := c3.get_global_rect().get_center()
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = center
		e.global_position = center
		e.pressed = pressed
		sv.push_input(e)
		await r.frames(1)
	r.check(chosen.back() == 3 and SaveSlots.has_save(3), "mouse/toque: clique no cartao 3 comeca o jogo nele")
	await _close(sv)
	_clean()


func _navigation_case() -> void:
	_clean()
	_write_m2(2)
	var opened := await _open_screen()
	var sv := opened[0] as SubViewport
	var scr := opened[1] as SlotScreen
	var c := scr.cards
	r.check(_focus(sv) == c[0], "navegacao: foco inicial no cartao 1")
	await _key(sv, KEY_RIGHT)
	var ok := _focus(sv) == c[1]
	await _key(sv, KEY_RIGHT)
	ok = ok and _focus(sv) == c[2]
	await _key(sv, KEY_RIGHT)
	ok = ok and _focus(sv) == c[2]
	await _key(sv, KEY_LEFT)
	ok = ok and _focus(sv) == c[1]
	r.check(ok, "teclado: setas esquerda/direita andam pelos cartoes")
	await _key(sv, KEY_DOWN)
	r.check(_focus(sv) == scr.delete_buttons[1], "teclado: seta para baixo vai ao Apagar do cartao cheio")
	await _key(sv, KEY_UP)
	await _key(sv, KEY_UP)
	r.check(_focus(sv) == scr.back_button, "teclado: para cima volta ao cartao e depois ao Voltar")
	await _pad(sv, JOY_BUTTON_DPAD_DOWN)
	var pad_ok := _focus(sv) == c[0]
	await _pad(sv, JOY_BUTTON_DPAD_RIGHT)
	pad_ok = pad_ok and _focus(sv) == c[1]
	await _pad(sv, JOY_BUTTON_DPAD_DOWN)
	pad_ok = pad_ok and _focus(sv) == scr.delete_buttons[1]
	await _pad(sv, JOY_BUTTON_DPAD_UP)
	pad_ok = pad_ok and _focus(sv) == c[1]
	r.check(pad_ok, "controle: direcional anda por Voltar, cartoes e Apagar")
	# Tab: ordem de leitura (Voltar, cartao 1, cartao 2, Apagar 2, cartao 3) e Shift+Tab volta
	scr.back_button.grab_focus()
	var seq: Array[String] = []
	for i in 5:
		await _key(sv, KEY_TAB)
		seq.append(String(_focus(sv).name))
	r.check(seq == ["Card1", "Card2", "Delete2", "Card3", "BackButton"], "Tab: ordem de leitura e volta ao comeco (%s)" % str(seq))
	await _key(sv, KEY_TAB, true)
	r.check(_focus(sv) == c[2], "Shift+Tab: volta um")
	var backs := [0]
	scr.back_requested.connect(func() -> void: backs[0] += 1)
	await _key(sv, KEY_ESCAPE)
	r.check(backs[0] == 1, "teclado: Esc (ui_cancel) volta")
	# controle: a Input Map nao tem botao de controle em ui_accept/ui_cancel; o controle escolhe com interact (X)
	scr.back_button.grab_focus()
	await _pad(sv, JOY_BUTTON_X)
	r.check(backs[0] == 2, "controle: X (interact) no Voltar volta")
	var chosen: Array[int] = []
	scr.play_requested.connect(func(s: int) -> void: chosen.append(s))
	scr.focus_slot(2)
	await _pad(sv, JOY_BUTTON_X)
	r.check(chosen == [2], "controle: X (interact) no cartao escolhe o espaco")
	await _close(sv)
	_clean()


func _hold_case() -> void:
	_clean()
	_write_m2(2)
	var opened := await _open_screen()
	var sv := opened[0] as SubViewport
	var scr := opened[1] as SlotScreen
	var del := scr.delete_buttons[1]
	del.grab_focus()
	await r.frames(1)
	# toque rapido: nada acontece, so a dica
	await _tap(sv, &"ui_accept")
	r.check(not scr.confirm_overlay.visible and SaveSlots.has_save(2), "apagar: toque rapido nao apaga nem pergunta")
	r.check(scr.hints[1].modulate.a > 0.9, "apagar: toque rapido mostra a dica Segure para apagar")
	# segurar 0,7 s e soltar antes do tempo: anel esvazia, nao apaga
	await _action(sv, &"ui_accept", true)
	del.advance(0.7)
	var mid := del.progress
	await _action(sv, &"ui_accept", false)
	r.check(mid > 0.4 and mid < 0.6 and del.progress == 0.0, "apagar: o anel enche enquanto segura (%.2f) e esvazia ao soltar" % mid)
	r.check(not scr.confirm_overlay.visible and SaveSlots.has_save(2), "apagar: soltar antes de 1,5 s nao apaga nem pergunta")
	# segurar o tempo todo: pergunta, com foco em Nao
	await _action(sv, &"ui_accept", true)
	del.advance(0.8)
	del.advance(0.8)
	await r.frames(1)
	r.check(scr.confirm_overlay.visible and _focus(sv) == scr.confirm_no and SaveSlots.has_save(2),
		"apagar: segurar 1,5 s abre a confirmacao com foco em Nao (ainda nao apagou)")
	await _action(sv, &"ui_accept", false)
	r.check(scr.confirm_overlay.visible and SaveSlots.has_save(2), "apagar: soltar a tecla na confirmacao nao escolhe nada")
	# setas ficam presas dentro da confirmacao
	await _key(sv, KEY_UP)
	await _key(sv, KEY_DOWN)
	r.check(scr.confirm_overlay.visible and (_focus(sv) == scr.confirm_no or _focus(sv) == scr.confirm_yes), "confirmacao: o foco nao sai dela")
	scr.confirm_no.grab_focus()
	await _tap(sv, &"ui_accept")
	r.check(not scr.confirm_overlay.visible and SaveSlots.has_save(2) and _focus(sv) == del, "apagar: Nao mantem o jogo e volta ao Apagar")
	# ui_cancel tambem desiste
	await _action(sv, &"interact", true)
	del.advance(1.6)
	await r.frames(1)
	r.check(scr.confirm_overlay.visible, "apagar: segurar interact (E / X) tambem pede confirmacao")
	await _action(sv, &"interact", false)
	await _tap(sv, &"ui_cancel")
	r.check(not scr.confirm_overlay.visible and SaveSlots.has_save(2), "apagar: ui_cancel na confirmacao desiste")
	# Sim apaga
	await _action(sv, &"ui_accept", true)
	del.advance(1.6)
	await _action(sv, &"ui_accept", false)
	await _key(sv, KEY_RIGHT)
	r.check(_focus(sv) == scr.confirm_yes, "confirmacao: seta para a direita vai a Sim")
	await _tap(sv, &"ui_accept")
	await r.frames(1)
	r.check(not SaveSlots.has_save(2) and scr.cards[1].find_child("NewGame", true, false) != null and not del.visible
		and _focus(sv) == scr.cards[1], "apagar: Sim apaga, o cartao vira Novo jogo e o foco fica nele")
	await _close(sv)
	_clean()


## Tempo real (sem advance manual): mouse segurado ~1,5 s de relogio; clique curto nao apaga.
func _hold_realtime_case() -> void:
	_clean()
	_write_m2(1)
	var opened := await _open_screen()
	var sv := opened[0] as SubViewport
	var scr := opened[1] as SlotScreen
	var del := scr.delete_buttons[0]
	await r.frames(2)
	var center := del.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = center
	down.global_position = center
	down.pressed = true
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	sv.push_input(down)
	await r.frames(3)
	sv.push_input(up)
	await r.frames(2)
	r.check(not scr.confirm_overlay.visible and SaveSlots.has_save(1), "mouse: clique curto no Apagar nao apaga")
	sv.push_input(down)
	var t0 := Time.get_ticks_msec()
	var early := false
	while not scr.confirm_overlay.visible and Time.get_ticks_msec() - t0 < 4000:
		if Time.get_ticks_msec() - t0 < 1300 and scr.confirm_overlay.visible:
			early = true
		await r.tree.process_frame
	var ms := Time.get_ticks_msec() - t0
	sv.push_input(up)
	await r.frames(1)
	r.check(scr.confirm_overlay.visible and not early and ms >= 1400 and ms < 2500,
		"mouse: segurar o clique pede confirmacao depois de ~1,5 s de relogio (%d ms)" % ms)
	r.check(SaveSlots.has_save(1), "mouse: segurar sozinho ainda nao apaga (falta confirmar)")
	await _close(sv)
	_clean()


func _contrast_case() -> void:
	_clean()
	_write_m2(2)
	var opened := await _open_screen()
	var sv := opened[0] as SubViewport
	var scr := opened[1] as SlotScreen
	var bad: Array[String] = []
	var worst := 99.0
	for b: Button in scr.cards + [scr.back_button, scr.confirm_no, scr.confirm_yes] + Array(scr.delete_buttons):
		var sb := b.get_theme_stylebox(&"normal") as StyleBoxFlat
		if sb == null:
			bad.append("%s sem fundo" % b.name)
			continue
		var texts: Array[Color] = [b.get_theme_color(&"font_color")]
		for l in b.find_children("*", "Label", true, false):
			texts.append((l as Label).get_theme_color(&"font_color"))
		for t in texts:
			var cr := ThemeV2.contrast_ratio(t, sb.bg_color)
			worst = minf(worst, cr)
			if cr < 4.5:
				bad.append("%s %.2f" % [b.name, cr])
	r.check(bad.is_empty(), "contraste: texto dos cartoes e botoes >= 4,5:1 (pior %.2f) %s" % [worst, str(bad)])
	var pills := ThemeV2.contrast_ratio(Color.WHITE, ThemeV2.NAVY)
	r.check(pills >= 4.5 and scr.title_label.get_theme_color(&"font_color") == Color.WHITE,
		"contraste: titulo e dica brancos sobre a pilula azul (%.2f:1)" % pills)
	var ring := ThemeV2.contrast_ratio(HoldButton.RING_COLOR, ThemeV2.ORANGE)
	r.check(ring >= 3.0, "contraste: anel do Apagar sobre o laranja >= 3:1 (grafico, %.2f:1)" % ring)
	await _close(sv)
	_clean()


func _layout_case(ratio: String, size: Vector2i) -> void:
	_clean()
	_write_m2(2)
	var opened := await _open_screen(size)
	var sv := opened[0] as SubViewport
	var scr := opened[1] as SlotScreen
	scr.delete_buttons[1].grab_focus()
	await r.frames(3)
	var screen := Rect2(Vector2.ZERO, Vector2(size))
	var targets: Array[Control] = [scr.back_button]
	targets.append_array(scr.cards)
	targets.append(scr.delete_buttons[1])
	var outside: Array[String] = []
	var small: Array[String] = []
	for t in targets:
		var rect := t.get_global_rect()
		if not screen.encloses(rect):
			outside.append("%s %s" % [t.name, str(rect)])
		if rect.size.x < MIN_TARGET or rect.size.y < MIN_TARGET:
			small.append("%s %s" % [t.name, str(rect.size)])
	r.check(outside.is_empty(), "[%s] cartoes, Apagar e Voltar dentro da tela %s" % [ratio, str(outside)])
	r.check(small.is_empty(), "[%s] alvos >= %d px %s" % [ratio, int(MIN_TARGET), str(small)])
	var overlap := false
	for i in targets.size():
		for j in range(i + 1, targets.size()):
			overlap = overlap or targets[i].get_global_rect().intersects(targets[j].get_global_rect())
	r.check(not overlap, "[%s] nenhum alvo se sobrepoe" % ratio)
	var cr := scr.cards[0].get_global_rect()
	r.check(cr.size.y > size.y * 0.38, "[%s] cartoes grandes (%.0f%% da altura)" % [ratio, cr.size.y / size.y * 100.0])
	await _close(sv)
	_clean()


func _reduced_motion_case() -> void:
	Options.motion_override = 1
	var opened := await _open_screen()
	var sv := opened[0] as SubViewport
	var scr := opened[1] as SlotScreen
	scr.open()
	var still := true
	for c in scr.cards:
		still = still and c.scale == Vector2.ONE and c.modulate.a == 1.0
	r.check(still, "movimento reduzido: cartoes aparecem sem mola")
	scr.cards[1].grab_focus()
	await r.frames(1)
	r.check(scr.cards[1].scale == Vector2.ONE * 1.04, "movimento reduzido: foco muda o tamanho direto (sem animacao)")
	Options.motion_override = 0
	await _close(sv)
