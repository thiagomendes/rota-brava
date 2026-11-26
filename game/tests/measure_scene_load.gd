extends SceneTree
## G10 (RB-R1): mede cada troca de cena a partir do menu, separando carregar recurso, instanciar, _ready (add_child)
## e os primeiros quadros (onde entra a compilacao de shader). Uso (janela real, nao headless):
##   xvfb-run -a bash tools/godot.sh --path game --rendering-driver vulkan --script res://tests/measure_scene_load.gd \
##     -- --target=res://episodes/ep01/v3/ep01_v3_main.tscn
## Um alvo por execucao (sem cache de recurso nem de shader entre alvos). --threaded mede pelo SceneLoader.

const TARGETS := ["res://ui/main_menu.tscn", "res://episodes/ep01/v3/ep01_v3_main.tscn",
	"res://episodes/ep01/v3/cutscene/game_intro.tscn", "res://episodes/reference/reference_demo.tscn"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Ep01V3Cutscene.seen_path = ""
	GameIntroScene.next_scene = ""
	var target := ""
	var threaded := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--target="):
			target = a.trim_prefix("--target=")
		if a == "--threaded":
			threaded = true
	var list: Array = TARGETS if target == "" else [target]
	for t: String in list:
		if threaded:
			await _measure_loader(t)
		else:
			await _measure(t)
	quit(0)


func _measure(path: String) -> void:
	for i in 5:
		await process_frame
	var t0 := Time.get_ticks_usec()
	var packed := ResourceLoader.load(path) as PackedScene
	var t1 := Time.get_ticks_usec()
	var node := packed.instantiate()
	var t2 := Time.get_ticks_usec()
	root.add_child(node)
	var t3 := Time.get_ticks_usec()
	var fr: Array[String] = []
	var last := t3
	var first := 0.0
	for i in 6:
		await process_frame
		var now := Time.get_ticks_usec()
		if i == 0:
			first = (now - last) / 1000.0
		fr.append("%.0f" % ((now - last) / 1000.0))
		last = now
	print("[RB] load_measure %s load=%.0fms instantiate=%.0fms ready=%.0fms frames=[%s]ms clique_ate_1o_quadro=%.0fms" % [
		path.get_file(), (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0, ", ".join(fr),
		(t3 - t0) / 1000.0 + first])
	node.queue_free()
	await process_frame


## Mesmo alvo pelo SceneLoader: tempo ate a tela de carregamento, maior quadro durante a espera e tempo total.
func _measure_loader(path: String) -> void:
	for i in 5:
		await process_frame
	var loader := SceneLoaderService.instance()
	var t0 := Time.get_ticks_usec()
	loader.change_scene(path)
	var screen_now := loader.is_showing()
	var worst := 0.0
	var last := Time.get_ticks_usec()
	var frames_n := 0
	while loader.is_busy():
		await process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		frames_n += 1
	var t1 := Time.get_ticks_usec()
	var fr: Array[String] = []
	for i in 4:
		await process_frame
		var now := Time.get_ticks_usec()
		fr.append("%.0f" % ((now - last) / 1000.0))
		last = now
	# Menu: espera a arte-chave 3D entrar atras da imagem parada e mede o pior quadro do menu ja interativo.
	var menu := current_scene as TitleScreen
	if menu != null:
		var worst_menu := 0.0
		var n := 0
		var tm := Time.get_ticks_usec()
		while (menu.key_art == null or menu.get_node_or_null("KeyArtStill") != null) and n < 3000:
			await process_frame
			var now := Time.get_ticks_usec()
			worst_menu = maxf(worst_menu, (now - last) / 1000.0)
			last = now
			n += 1
		print("[RB] menu_keyart %s ate_palco=%.0fms pior_quadro_menu=%.0fms foco=%s" % [menu.key_art != null,
			(Time.get_ticks_usec() - tm) / 1000.0, worst_menu, menu.play_button.has_focus()])
	print("[RB] loader_measure %s tela_no_pedido=%s quadros=%d pior_quadro=%.0fms total=%.0fms depois=[%s]ms" % [
		path.get_file(), screen_now, frames_n, worst, (t1 - t0) / 1000.0, ", ".join(fr)])
