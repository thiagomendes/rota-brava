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
