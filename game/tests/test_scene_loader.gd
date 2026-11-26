extends RefCounted
## G10/G11 (RB-R1): carregador unico (autoload SceneLoader) e fim da abertura do jogo. A tela de carregamento entra no
## quadro do pedido, a cena troca, a tela some, pedidos repetidos sao ignorados, movimento reduzido para a estrela e
## o fim natural da abertura (sem entrada) chega ao menu pelo carregador. Nao comprova render nem tempo em GPU real.

const MENU := "res://ui/main_menu.tscn"
const WAIT_FRAMES := 6000

var r
var loader: SceneLoaderService


func run(runner) -> void:
	r = runner
	loader = SceneLoaderService.instance()
	r.check(loader != null, "loader: carregador unico presente")
	if loader == null:
		return
	await _changes_scene()
	await _reduced_motion()
	r.check(not loader.change_scene("res://nao/existe.tscn") and not loader.is_busy(), "loader: caminho inexistente nao muda nada")
	await _intro_end_to_menu()
	await _menu_fast()
	await _menu_timeout()
	await _input_blocked()
	await _corrupt_scene()
	Options.motion_override = -1
	r.tree.unload_current_scene()
	await r.frames(2)


func _wait_idle() -> int:
	var n := 0
	while loader.is_busy() and n < WAIT_FRAMES:
		await r.tree.process_frame
		n += 1
	return n


func _changes_scene() -> void:
	Options.motion_override = 0
	var frame := Engine.get_process_frames()
	var ok := loader.change_scene(MENU)
	r.check(ok and loader.is_showing() and loader.is_busy(), "loader: tela de carregamento visivel no mesmo quadro do pedido")
	r.check(Engine.get_process_frames() == frame, "loader: o pedido nao bloqueia o quadro (mesmo quadro %d)" % frame)
	r.check(not loader.change_scene(MENU), "loader: segundo pedido durante a troca e ignorado")
	await r.tree.process_frame
	await r.tree.process_frame
	r.check(loader.star_spin() > 0.0, "loader: estrela gira durante o carregamento")
	var n := await _wait_idle()
	var cur: Node = r.tree.current_scene
	r.check(cur != null and cur.scene_file_path == MENU, "loader: cena trocada para o menu (%d quadros)" % n)
	r.check(not loader.is_showing() and not loader.is_busy(), "loader: tela some ao fim")
	var tm := cur as TitleScreen
	if tm != null and ResourceLoader.exists(TitleScreen.KEY_ART):
		r.check(tm.key_art != null and tm.key_art.is_inside_tree() and tm.get_node_or_null("KeyArtStill") == null,
			"menu: so aparece depois do palco 3D instanciado e desenhado (sem imagem parada)")
		r.check(tm.play_button.has_focus(), "menu: foco em Jogar ao sair do carregamento")
	r.check(int(loader.last_timings.get("total_ms", 0)) >= SceneLoaderService.MIN_SHOW_MS,
		"loader: tempo minimo de exibicao respeitado (%s)" % loader.last_timings)


func _reduced_motion() -> void:
	Options.motion_override = 1
	loader.change_scene(MENU)
	r.check(loader.is_showing(), "loader movimento reduzido: tela aparece")
	await r.frames(10)
	r.check(loader.star_spin() == 0.0, "loader movimento reduzido: estrela parada")
	await _wait_idle()
	r.check(r.tree.current_scene != null and r.tree.current_scene.scene_file_path == MENU, "loader movimento reduzido: troca a cena")
	Options.motion_override = 0


## G11: a abertura vista pelo menu termina sozinha (sem pular, sem entrada) e volta ao menu pelo carregador.
func _intro_end_to_menu() -> void:
	Ep01V3Cutscene.enabled = true
	Ep01V3Cutscene.reset_seen()
	GameIntroScene.next_scene = GameIntroScene.MENU_SCENE
	loader.change_scene(GameIntroScene.SELF_SCENE)
	await _wait_idle()
	var intro := r.tree.current_scene as GameIntroScene
	r.check(intro != null, "abertura: carregada pelo SceneLoader")
	if intro == null:
		return
	var result := {"skipped": null}
	intro.done.connect(func(s: bool) -> void: result["skipped"] = s)
	Engine.time_scale = 8.0
	var n := 0
	while not (r.tree.current_scene is MainMenu and not loader.is_busy()) and n < 20000:
		await r.tree.process_frame
		n += 1
	Engine.time_scale = 1.0
	r.check(result["skipped"] == false, "abertura: terminou sozinha, sem pular")
	r.check(r.tree.current_scene is MainMenu, "abertura: fim leva ao menu sem entrada (%d quadros)" % n)
	r.check(loader.last_timings.has("total_ms"), "abertura: volta ao menu com a tela de transicao")
	r.check(GameIntroScene.play_target() == GameIntroScene.EP01_SCENE, "abertura: vista, Jogar nao abre de novo")
	Ep01V3Cutscene.enabled = false
	GameIntroScene.next_scene = GameIntroScene.EP01_SCENE


## G10 + G8: o menu abre sem esperar a arte-chave 3D (imagem parada + foco em Jogar ja no _ready) e o palco entra depois.
func _menu_fast() -> void:
	var t0 := Time.get_ticks_msec()
	var m := (load(MENU) as PackedScene).instantiate() as MainMenu
	r.tree.root.add_child(m)
	var ready_ms := Time.get_ticks_msec() - t0
	r.check(m.key_art == null, "menu: _ready nao instancia a arte-chave 3D na hora (%d ms)" % ready_ms)
	r.check(m.play_button.has_focus(), "menu: foco em Jogar desde o primeiro quadro")
	if ResourceLoader.exists(TitleScreen.KEY_STILL):
		r.check(m.get_node_or_null("KeyArtStill") != null, "menu: imagem parada da arte-chave na frente enquanto carrega")
	var n := 0
	while (m.key_art == null or m.get_node_or_null("KeyArtStill") != null) and n < 20000:
		await r.tree.process_frame
		n += 1
	r.check(m.key_art != null and m.key_art.is_inside_tree(), "menu: arte-chave 3D entra depois (%d quadros)" % n)
	r.check(m.play_button.has_focus(), "menu: foco continua em Jogar depois da troca do fundo")
	m.queue_free()
	await r.frames(2)


## Plano B: teto da tela estourado -> menu abre sobre a imagem parada, com foco, e o palco entra depois.
func _menu_timeout() -> void:
	Options.motion_override = 0
	loader.hold_max_ms = 1
	loader.change_scene(MENU)
	await _wait_idle()
	loader.hold_max_ms = SceneLoaderService.HOLD_MAX_MS
	var m := r.tree.current_scene as TitleScreen
	r.check(m != null and not loader.is_showing(), "teto: menu abre mesmo sem o palco pronto")
	if m == null:
		return
	r.check(m.get_node_or_null("KeyArtStill") != null and m.play_button.has_focus(),
		"teto: menu sobre a imagem parada com foco em Jogar")
	var n := 0
	while m.get_node_or_null("KeyArtStill") != null and n < 20000:
		await r.tree.process_frame
		n += 1
	r.check(m.key_art != null and m.key_art.is_inside_tree(), "teto: palco entra depois (%d quadros)" % n)
	r.check(not m.loading_hold(), "teto: menu nao volta a segurar a tela")
	# Palco ausente/falhou (nada pendente e nenhum palco): nao segura a tela; menu fica sobre a imagem parada.
	var m2 := (load(MENU) as PackedScene).instantiate() as TitleScreen
	r.tree.root.add_child(m2)
	m2._key_pending.clear()
	r.check(not m2.loading_hold() and m2.key_art == null, "palco ausente: menu nao segura a tela de carregamento")
	await r.frames(3)
	r.check(m2.key_art == null and m2.play_button.has_focus(), "palco ausente: menu abre sobre a imagem parada com foco")
	m2.queue_free()
	await r.frames(2)


func _key(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await r.tree.process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await r.tree.process_frame


## Revisao G10: uma acao apertada durante a troca nao chega a cena (a nova, ja na arvore atras da tela, nem a velha);
## MouseLock bloqueado durante a troca e solto no fim.
func _input_blocked() -> void:
	var ref := "res://episodes/reference/reference_demo.tscn"
	loader.change_scene(ref)
	r.check(MouseLock.blocked(), "entrada: MouseLock bloqueado durante a troca")
	var n := 0
	while not (r.tree.current_scene is ReferenceDemo) and n < WAIT_FRAMES:
		await r.tree.process_frame
		n += 1
	var demo := r.tree.current_scene as ReferenceDemo
	r.check(demo != null and loader.is_showing(), "entrada: cena nova na arvore com a tela ainda por cima")
	if demo == null:
		return
	var page := demo.page_index
	var variant := demo.variant
	await _key(&"move_right")
	await _key(&"interact")
	r.check(demo.page_index == page and demo.variant == variant,
		"entrada: move_right/interact durante a troca nao mudam a pagina (%d->%d)" % [page, demo.page_index])
	await _wait_idle()
	r.check(not MouseLock.blocked(), "entrada: MouseLock solto no fim da troca")
	await _key(&"move_right")
	r.check(demo.page_index != page, "entrada: depois da troca a cena volta a receber move_right")


## Revisao G10: cena corrompida (status FAILED) -> tela some e o jogador fica na cena anterior, que volta a processar.
func _corrupt_scene() -> void:
	var bad := "user://test_scene_loader_corrupt.tscn"
	var f := FileAccess.open(bad, FileAccess.WRITE)
	f.store_string("[gd_scene format=3]\n[node name=\"X\" type=\"NaoExiste\" parent=\"@@@\"]\nlixo {{{")
	f.close()
	var before: Node = r.tree.current_scene
	var ok := loader.change_scene(bad)
	var n := await _wait_idle()
	r.check(ok and n < WAIT_FRAMES, "corrompida: o carregador nao trava (%d quadros)" % n)
	r.check(r.tree.current_scene == before and not loader.is_showing(), "corrompida: tela some e o jogador fica na cena anterior")
	r.check(loader.last_timings.has("failed"), "corrompida: caminho de erro registrado (%s)" % loader.last_timings)
	r.check(before != null and before.can_process() and not MouseLock.blocked(), "corrompida: cena anterior volta a processar e mouse solto")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bad))
