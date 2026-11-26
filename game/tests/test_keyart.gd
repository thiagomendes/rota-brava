extends RefCounted
## Arte-chave da tela inicial (RB-R1 G8): o fundo 3D (KeyArtView/KeyArtStage, cena B) atras do menu.
## Cobre: foco por teclado e controle (nada do fundo pega foco, Jogar comeca focado), movimento reduzido (camera, barco
## e pose parados), liberacao da cena ao sair do menu, o trio projetado na tela fora da coluna de botoes nas 3
## proporcoes (tamanhos logicos do projeto com stretch "expand") e o contraste WCAG dos botoes do menu.
## Nao comprova render: a projecao e calculada pela camera do palco, a imagem real fica nas capturas.

const MENU := "res://ui/main_menu.tscn"
## Tamanhos logicos com stretch canvas_items + expand (base 1920x1080).
const RATIOS := {"16:9": Vector2i(1920, 1080), "20:9": Vector2i(2400, 1080), "4:3": Vector2i(1920, 1440)}

var r


func run(runner) -> void:
	r = runner
	var keep_motion: int = Options.motion_override
	await _contrast()
	Options.motion_override = 0
	for ratio: String in RATIOS:
		await _layout_case(ratio, RATIOS[ratio])
	await _focus_case()
	await _reduced_motion_case()
	await _release_case()
	Options.motion_override = keep_motion


## Menu dentro de um SubViewport do tamanho pedido; espera o palco ficar pronto.
func _open(size: Vector2i) -> Array:
	var sv := SubViewport.new()
	sv.size = size
	sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	sv.gui_disable_input = false
	r.tree.root.add_child(sv)
	var menu := (load(MENU) as PackedScene).instantiate() as MainMenu
	sv.add_child(menu)
	var waited := 0
	while (menu.key_art == null or not menu.key_art.stage.ready_to_shoot) and waited < 600:
		await r.frames(1)
		waited += 1
	await r.frames(3)
	return [sv, menu]


func _close(sv: SubViewport) -> void:
	sv.queue_free()
	await r.frames(3)


func _layout_case(ratio: String, size: Vector2i) -> void:
	var opened := await _open(size)
	var sv := opened[0] as SubViewport
	var menu := opened[1] as MainMenu
	r.check(menu.key_art != null and menu.key_art.stage != null and menu.key_art.stage.ready_to_shoot,
		"[%s] menu com a arte-chave 3D pronta" % ratio)
	if menu.key_art == null:
		await _close(sv)
		return
	menu._layout()
	await r.frames(2)
	var hr := menu.key_art.stage.hero_screen_rect()
	var kr := menu.key_art.get_global_rect()
	var trio_right := kr.position.x + hr.end.x * kr.size.x
	var trio_left := kr.position.x + hr.position.x * kr.size.x
	var buttons_left := INF
	for b: Button in [menu.play_button, menu.options_button, menu.quit_button]:
		if b.visible:
			buttons_left = minf(buttons_left, b.get_global_rect().position.x)
	r.check(trio_right < buttons_left and trio_left >= 0.0,
		"[%s] trio projetado (x %.0f..%.0f) todo a esquerda dos botoes (x >= %.0f) e dentro da tela"
		% [ratio, trio_left, trio_right, buttons_left])
	r.check(hr.size.x > 0.12, "[%s] o trio continua grande na tela (%.0f%% da largura)" % [ratio, hr.size.x * 100.0])
	# mutacao: sem a area livre (tela inteira) o trio invade a coluna de botoes, entao a medida pega o defeito
	if ratio == "4:3":
		menu.key_art.stage.set_free_rect(Rect2(0, 0, 1, 1))
		var bad := menu.key_art.stage.hero_screen_rect()
		r.check(kr.position.x + bad.end.x * kr.size.x > buttons_left, "mutacao [4:3]: sem a area livre o trio passa da borda dos botoes")
	await _close(sv)


func _focus_case() -> void:
	var opened := await _open(RATIOS["16:9"])
	var sv := opened[0] as SubViewport
	var menu := opened[1] as MainMenu
	var bad: Array[String] = []
	for n in menu.key_art.find_children("*", "Control", true, false) + [menu.key_art]:
		var c := n as Control
		if c.focus_mode != Control.FOCUS_NONE or c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			bad.append(String(c.name))
	r.check(bad.is_empty(), "fundo 3D sem foco nem mouse em nenhum Control (%s)" % str(bad))
	r.check(sv.gui_get_focus_owner() == menu.play_button, "foco inicial em Jogar com o fundo 3D")
	var buttons: Array = [menu.play_button, menu.options_button, menu.quit_button]
	var visited := {}
	# teclado: setas para baixo e para cima; controle: direcional para baixo e para cima
	var events: Array[InputEvent] = []
	for k in [KEY_DOWN, KEY_DOWN, KEY_DOWN, KEY_DOWN, KEY_DOWN, KEY_UP, KEY_UP]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = true
		events.append(e)
	for bt in [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_UP]:
		var j := InputEventJoypadButton.new()
		j.button_index = bt
		j.pressed = true
		events.append(j)
	var stray := false
	for e in events:
		sv.push_input(e)
		var up := e.duplicate() as InputEvent
		if up is InputEventKey:
			(up as InputEventKey).pressed = false
		else:
			(up as InputEventJoypadButton).pressed = false
		sv.push_input(up)
		await r.frames(1)
		var f := sv.gui_get_focus_owner()
		if f == null or not buttons.has(f):
			stray = true
		else:
			visited[f.name] = true
	r.check(not stray, "teclado e controle: o foco anda so pelos botoes do menu, nunca pelo fundo")
	r.check(visited.size() == 3, "teclado e controle percorrem a coluna de botoes (G12: Jogar, Opcoes, Sair) (%s)" % str(visited.keys()))
	# clique no fundo (lado esquerdo, sobre o trio) nao tira o foco dos botoes
	menu.play_button.grab_focus()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(300, 700)
	click.pressed = true
	sv.push_input(click)
	var release := click.duplicate() as InputEventMouseButton
	release.pressed = false
	sv.push_input(release)
	await r.frames(1)
	r.check(sv.gui_get_focus_owner() == menu.play_button, "clique no fundo 3D nao muda o foco (Jogar continua focado)")
	await _close(sv)


func _snapshot(stage: KeyArtStage) -> Array:
	var poses := []
	for id: StringName in stage.heroes:
		poses.append((stage.heroes[id] as CharacterVisual).animation_player().current_animation_position)
	return [stage.cam.global_transform, stage.boat.transform, poses]


func _same(a: Array, b: Array) -> bool:
	if not (a[0] as Transform3D).is_equal_approx(b[0]) or not (a[1] as Transform3D).is_equal_approx(b[1]):
		return false
	for i in (a[2] as Array).size():
		if not is_equal_approx(float(a[2][i]), float(b[2][i])):
			return false
	return true


func _reduced_motion_case() -> void:
	var opened := await _open(RATIOS["16:9"])
	var sv := opened[0] as SubViewport
	var menu := opened[1] as MainMenu
	var stage := menu.key_art.stage
	r.check(stage.animate, "o fundo do menu e animado por padrao")
	Options.motion_override = 1
	var before := _snapshot(stage)
	for i in 12:
		stage._process(0.25)
	await r.frames(3)
	r.check(_same(before, _snapshot(stage)), "movimento reduzido: camera, barco e pose do trio parados (3 s simulados)")
	Options.motion_override = 0
	for i in 12:
		stage._process(0.25)
	var moved := _snapshot(stage)
	r.check(not (before[1] as Transform3D).is_equal_approx(moved[1]) and not (before[0] as Transform3D).is_equal_approx(moved[0]),
		"mutacao: com movimento normal o barco e a camera se mexem")
	await _close(sv)


func _release_case() -> void:
	var opened := await _open(RATIOS["16:9"])
	var sv := opened[0] as SubViewport
	var menu := opened[1] as MainMenu
	var stage_ref: WeakRef = weakref(menu.key_art.stage)
	var world_ref: WeakRef = weakref(menu.key_art.stage.world)
	var boat_ref: WeakRef = weakref(menu.key_art.stage.boat)
	var hero_ref: WeakRef = weakref(menu.hero_models[0])
	# sair do menu (Jogar troca de cena e libera o menu): aqui o menu sai da arvore e e liberado
	menu.queue_free()
	await r.frames(4)
	r.check(stage_ref.get_ref() == null and world_ref.get_ref() == null and boat_ref.get_ref() == null and hero_ref.get_ref() == null,
		"sair do menu libera palco, vila, barco e trio da arte-chave")
	await _close(sv)


func _contrast() -> void:
	var th := ThemeV2.build()
	for t: StringName in [&"PrimaryButton", &"GreenButton", &"OrangeButton", &"QuietButton"]:
		var sb := th.get_stylebox("normal", t) as StyleBoxFlat
		var hover := th.get_stylebox("hover", t) as StyleBoxFlat
		var pressed := th.get_stylebox("pressed", t) as StyleBoxFlat
		var fg := th.get_color("font_color", t)
		var worst := minf(ThemeV2.contrast_ratio(fg, sb.bg_color),
			minf(ThemeV2.contrast_ratio(fg, hover.bg_color), ThemeV2.contrast_ratio(fg, pressed.bg_color)))
		r.check(worst >= 4.5, "contraste WCAG do texto em %s >= 4,5:1 (pior entre normal/hover/pressionado: %.2f)" % [t, worst])
	r.check(ThemeV2.contrast_ratio(Color.WHITE, ThemeV2.GREEN) < 4.5, "mutacao: branco sobre o verde reprova (%.2f)"
		% ThemeV2.contrast_ratio(Color.WHITE, ThemeV2.GREEN))
