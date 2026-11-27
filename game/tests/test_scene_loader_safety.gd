extends RefCounted
## G16 (RB-M1, travamento no iOS): carregamento seguro de impasse por construcao.
## (1) No maximo um `load_threaded_request` ativo por vez no jogo inteiro (menu + SceneLoader).
## (2) Nenhum `load()` sincrono passando pelo carregador enquanto ha pedido em segundo plano pendente.
## (3) Modo mobile (forcado): menu sem palco 3D, com a imagem parada e foco em Jogar.
## Prova so o lado da Godot no desktop/headless: o impasse do iOS so se confirma no aparelho.

const MENU := "res://ui/main_menu.tscn"
const TITLE_SCRIPT := "res://ui/title/title_screen.gd"
const WAIT_FRAMES := 20000

var r
var loader: SceneLoaderService


func run(runner) -> void:
	r = runner
	loader = SceneLoaderService.instance()
	_source_guard()
	var has_stats := loader.has_method(&"bg_stats")
	r.check(has_stats, "carga segura: carregador instrumentado (contador de pedidos e registro de load sincrono)")
	if has_stats:
		loader.call(&"bg_reset_stats")
	await _title_single_request()
	await _loader_single_request()
	await _mobile_title()
	if has_stats:
		var st: Dictionary = loader.call(&"bg_stats")
		r.check(int(st["max_active"]) <= 1, "carga segura: maximo de pedidos ativos registrado = %d" % int(st["max_active"]))
		r.check((st["sync_during_pending"] as Array).is_empty(),
			"carga segura: nenhum load sincrono com pedido pendente %s" % [st["sync_during_pending"]])
	r.tree.unload_current_scene()
	await r.frames(2)


## Fora do carregador ninguem chama `load_threaded_request` direto (todo pedido passa pela fila unica).
func _source_guard() -> void:
	var bad: Array[String] = []
	_scan("res://", bad)
	r.check(bad.is_empty(), "carga segura: so o SceneLoader chama load_threaded_request %s" % [bad])


func _scan(dir: String, bad: Array[String]) -> void:
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with(".") or d == "tests" or d == "addons":
			continue
		_scan(dir.path_join(d), bad)
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".gd") or f == "scene_loader.gd":
			continue
		var p := dir.path_join(f)
		if FileAccess.get_file_as_string(p).contains("ResourceLoader.load_threaded_request"):
			bad.append(p)


## Caminhos que o menu e o carregador costumam pedir em segundo plano.
func _probe_paths() -> Array[String]:
	var out: Array[String] = [TitleScreen.KEY_ART, TitleScreen.KEY_STILL, TitleScreen.LOGO, MENU]
	for p in KeyArtStage.resource_paths():
		out.append(p)
	out.append_array(TitleScreen.KEY_ART_GLBS)
	for k: String in SceneLoaderService.WARM:
		out.append(k)
		out.append_array(SceneLoaderService.WARM[k] as Array[String])
	var uniq: Array[String] = []
	for p in out:
		if not uniq.has(p):
			uniq.append(p)
	return uniq


## Pedidos em segundo plano em andamento agora, vistos pela propria Godot (vale tambem para o codigo antigo).
func _in_progress(paths: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for p in paths:
		if ResourceLoader.load_threaded_get_status(p) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			out.append(p)
	return out


func _new_title(mobile: int) -> TitleScreen:
	var t := (load(MENU) as PackedScene).instantiate() as TitleScreen
	t.set(&"mobile_override", mobile)
	return t


func _drain() -> void:
	var n := 0
	while (loader.is_busy() or (loader.has_method(&"bg_idle") and not bool(loader.call(&"bg_idle")))) and n < WAIT_FRAMES:
		await r.tree.process_frame
		n += 1


## Menu de desktop: arte-chave carregando em segundo plano, um pedido por vez ate o palco entrar.
func _title_single_request() -> void:
	await _drain()
	var paths := _probe_paths()
	var t := _new_title(0)
	r.tree.root.add_child(t)
	var worst: Array[String] = _in_progress(paths)
	var n := 0
	while t.key_art == null and n < WAIT_FRAMES:
		await r.tree.process_frame
		var now := _in_progress(paths)
		if now.size() > worst.size():
			worst = now
		n += 1
	r.check(worst.size() <= 1, "carga segura menu: no maximo 1 pedido em segundo plano por vez (pior: %s)" % [worst])
	if ResourceLoader.exists(TitleScreen.KEY_ART):
		r.check(t.key_art != null, "carga segura menu: palco 3D ainda entra no desktop (%d quadros)" % n)
	t.queue_free()
	await r.frames(2)
	await _drain()


## SceneLoader com aquecimento (WARM do menu): dependencias e cena em sequencia, nunca juntas; o menu ao abrir tambem.
func _loader_single_request() -> void:
	await _drain()
	var paths := _probe_paths()
	Options.motion_override = 1
	var ok := loader.change_scene(MENU)
	var worst: Array[String] = _in_progress(paths)
	var n := 0
	while ok and n < WAIT_FRAMES:
		var cur := r.tree.current_scene as TitleScreen
		if not loader.is_busy() and cur != null and (cur.key_art != null or not ResourceLoader.exists(TitleScreen.KEY_ART)):
			break
		await r.tree.process_frame
		var now := _in_progress(paths)
		if now.size() > worst.size():
			worst = now
		n += 1
	r.check(ok and r.tree.current_scene is TitleScreen, "carga segura loader: menu aberto pelo SceneLoader (%d quadros)" % n)
	r.check(worst.size() <= 1, "carga segura loader: no maximo 1 pedido em segundo plano por vez (pior: %s)" % [worst])
	Options.motion_override = -1
	await _drain()


## Mobile forcado: imagem parada como fundo, sem palco 3D, sem pedido em segundo plano, foco em Jogar.
func _mobile_title() -> void:
	await _drain()
	var paths := _probe_paths()
	var t := _new_title(1)
	r.tree.root.add_child(t)
	await r.frames(3)
	var worst := _in_progress(paths)
	for i in 30:
		await r.tree.process_frame
		var now := _in_progress(paths)
		if now.size() > worst.size():
			worst = now
	var still := t.get_node_or_null("KeyArtStill") as TextureRect
	r.check(still != null and still.texture != null and still.visible, "mobile: imagem parada da arte-chave como fundo")
	r.check(t.key_art == null and t.get_node_or_null("KeyArt") == null, "mobile: sem palco 3D da arte-chave")
	r.check(t.get_node_or_null("Safe/HeroStage") == null, "mobile: sem palco 3D antigo dos herois")
	r.check(worst.is_empty(), "mobile: nenhum pedido em segundo plano %s" % [worst])
	r.check(not t.loading_hold(), "mobile: nao segura a tela de carregamento")
	r.check(t.play_button.has_focus(), "mobile: foco em Jogar")
	t.queue_free()
	await r.frames(2)
