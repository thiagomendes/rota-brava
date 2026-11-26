extends RefCounted
## Demonstracao de referencias (RB-03): navegacao, expressoes do Rastro, vozes, musica e saida.

var r


func _press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await r.frames()
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await r.frames()


func _mount() -> ReferenceDemo:
	var demo := (load("res://episodes/reference/reference_demo.tscn") as PackedScene).instantiate() as ReferenceDemo
	r.tree.root.add_child(demo)
	r.tree.current_scene = demo
	await r.frames(3)
	return demo


func _buttons(node: Node) -> Array[Button]:
	var out: Array[Button] = []
	for n in node.find_children("*", "Button", true, false):
		out.append(n as Button)
	return out


func run(runner) -> void:
	r = runner
	var demo := await _mount()
	r.check(demo.current_page == &"cast", "a demonstracao abre na pagina do elenco")

	# Todas as paginas constroem sem erro e mostram texto.
	for i in ReferenceDemo.PAGES.size():
		demo.show_page(i)
		await r.frames(2)
		r.check(demo.current_page == ReferenceDemo.PAGES[i], "pagina %s abre" % ReferenceDemo.PAGES[i])
	demo.show_page(0)
	await r.frames(2)

	# Navegacao por intencoes: move_right avanca, move_left volta, com volta circular.
	await _press(&"move_right")
	r.check(demo.current_page == &"rastro", "move_right avanca para a pagina do Rastro")
	await _press(&"move_left")
	await _press(&"move_left")
	r.check(demo.current_page == &"music", "move_left a partir da primeira pagina volta ao fim (circular)")
	demo.show_page(0)
	await r.frames(2)

	# Elenco: E alterna frente, costas, miniatura.
	var texture_before := (demo.find_children("*", "TextureRect", true, false)[0] as TextureRect).texture
	await _press(&"interact")
	await r.frames(2)
	var texture_after := (demo.find_children("*", "TextureRect", true, false)[0] as TextureRect).texture
	r.check(texture_before != null and texture_after != null and texture_before != texture_after,
		"E alterna a imagem do elenco (frente -> costas)")

	# Rastro em 3D: o modelo existe, tem shape keys e as expressoes mudam o peso.
	demo.show_page(1)
	await r.frames(4)
	r.check(demo._faces.size() > 0, "o Rastro 3D tem malha com shape keys de rosto")
	if demo._faces.size() > 0:
		var face: MeshInstance3D = demo._faces[0]
		var idx_att := -1
		var idx_sur := -1
		for i in face.mesh.get_blend_shape_count():
			match String(face.mesh.get_blend_shape_name(i)):
				"atenta": idx_att = i
				"surpresa": idx_sur = i
		demo.set_expression(1)
		r.check(idx_att >= 0 and is_equal_approx(face.get_blend_shape_value(idx_att), 1.0)
			and is_equal_approx(face.get_blend_shape_value(idx_sur), 0.0), "expressao atenta liga so a shape key atenta")
		demo.set_expression(2)
		r.check(is_equal_approx(face.get_blend_shape_value(idx_sur), 1.0)
			and is_equal_approx(face.get_blend_shape_value(idx_att), 0.0), "expressao surpresa liga so a shape key surpresa")
		demo.set_expression(0)
		r.check(is_equal_approx(face.get_blend_shape_value(idx_att), 0.0)
			and is_equal_approx(face.get_blend_shape_value(idx_sur), 0.0), "expressao neutra zera as shape keys")
	var yaw_a := demo._pivot.rotation.y
	await r.tree.create_timer(0.3).timeout
	r.check(not is_equal_approx(yaw_a, demo._pivot.rotation.y), "o modelo gira")

	# Barco e HUD.
	demo.show_page(2)
	await r.frames(4)
	r.check(demo._pivot != null, "o barco 3D esta na pagina do barco")
	demo.show_page(3)
	await r.frames(3)
	var hud_buttons := _buttons(demo)
	r.check(hud_buttons.size() >= 1 and demo.get_viewport().gui_get_focus_owner() == hud_buttons[0],
		"a pagina do HUD tem foco inicial no botao do estudo")
	r.check(demo.find_children("*", "TextureRect", true, false).size() == 3, "o HUD mostra as 3 proporcoes")

	# Vozes: um botao por fala do catalogo; tocar fala legenda e som; id ausente so legenda.
	demo.show_page(4)
	await r.frames(3)
	var voice_buttons := _buttons(demo)
	r.check(voice_buttons.size() == VoiceCatalog.all_lines().size() and voice_buttons.size() >= 4,
		"ha um botao por fala do catalogo (%d)" % voice_buttons.size())
	r.check(demo.get_viewport().gui_get_focus_owner() == voice_buttons[0], "a pagina de vozes tem foco inicial")
	demo.play_voice("ep01.dock.tracker.small_print")
	await r.frames(2)
	r.check(demo.voice_player.playing and demo.voice_player.bus == &"Voz", "tocar a fala usa o bus Voz")
	r.check(demo.last_subtitle == Loc.t("ep01.dock.tracker.small_print"), "a legenda acompanha a fala")
	demo.play_voice("id.que.nao.existe")
	await r.frames(2)
	r.check(demo._detail.text.contains(Loc.t("ref.voice.missing")), "fala ausente mostra so a legenda")

	# Musica
	demo.show_page(5)
	await r.frames(3)
	demo.play_music(&"explore")
	await r.frames(2)
	r.check(demo.music_player.playing and demo.music_player.bus == &"Musica", "tocar o tema usa o bus Musica")
	demo.show_page(0)
	await r.frames(2)
	r.check(not demo.music_player.playing, "sair da pagina de musica para o som")

	# Esc volta ao menu.
	await _press(&"pause")
	await r.frames(3)
	# G10: a troca passa pelo SceneLoader (assincrona); espera ele terminar.
	await _wait_loader()
	var menu := r.tree.current_scene as MainMenu
	r.check(menu != null, "Esc volta ao menu principal")
	if menu:
		r.check(menu.get_viewport().gui_get_focus_owner() == menu.play_button, "o menu volta com foco em Jogar")
		r.tree.current_scene.queue_free()
		await r.frames(2)
		r.tree.current_scene = null


## G10: espera o SceneLoader terminar a troca, com teto e FAIL claro (nunca trava a suite).
func _wait_loader() -> void:
	var n := 0
	while SceneLoaderService.instance().is_busy() and n < 6000:
		await r.tree.process_frame
		n += 1
	if n >= 6000:
		r.check(false, "G10: SceneLoader nao terminou a troca em 6000 quadros")
