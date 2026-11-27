extends RefCounted
## G17 (RB-R1): com a tela de carregamento segurando por N quadros, a abertura do jogo e a cena de abertura do Ep01
## nao falam, nao tocam som e nao contam tempo por baixo dela; o primeiro plano comeca no quadro em que a tela libera
## (fase FADING_OUT/IDLE do SceneLoader). Nao comprova o tempo real de carregamento no celular.

const HOLD_FRAMES := 40

var r


func run(runner) -> void:
	r = runner
	var was := Ep01V3Cutscene.enabled
	Ep01V3Cutscene.enabled = true
	Ep01V3Cutscene.seen_path = ""
	Ep01V3Cutscene.reset_seen()
	var prev_next := GameIntroScene.next_scene
	GameIntroScene.next_scene = ""
	await _case("game_intro", "res://episodes/ep01/v3/cutscene/game_intro.tscn")
	Ep01V3Cutscene.reset_seen()
	await _case("ep01", "res://episodes/ep01/v3/ep01_v3_main.tscn")
	await _skip_while_waiting()
	await _released_by(&"hold_timeout")
	await _released_by(&"fail")
	GameIntroScene.next_scene = prev_next
	Ep01V3Cutscene.enabled = was
	Ep01V3Cutscene.reset_seen()


static func _audio_playing(n: Node) -> Array[String]:
	var out: Array[String] = []
	for c in n.find_children("*", "AudioStreamPlayer", true, false):
		var p := c as AudioStreamPlayer
		if p.playing:
			out.append("%s:%s" % [n.get_path_to(p), ("%s %s" % [p.stream.get_class(), p.bus]) if p.stream != null else ""])
	for c in n.find_children("*", "AudioStreamPlayer3D", true, false):
		if (c as AudioStreamPlayer3D).playing:
			out.append(c.name)
	return out


## Sem API nova (o teste roda tambem no codigo de antes do G17).
static func _released(l: SceneLoaderService) -> bool:
	return l.phase == SceneLoaderService.Phase.IDLE or l.phase == SceneLoaderService.Phase.FADING_OUT


func _case(label: String, path: String) -> void:
	var loader := SceneLoaderService.instance()
	var holder := Node.new()
	r.tree.root.add_child(holder)
	r.tree.current_scene = holder
	loader.cover_current()
	loader._settle_left = HOLD_FRAMES + 1000  # segura bem mais que o teste; liberado a mao abaixo
	var scene := (load(path) as PackedScene).instantiate()
	r.tree.root.add_child(scene)
	r.tree.current_scene = scene
	var cs := scene.find_child("Cutscene", true, false) as Ep01V3Cutscene
	var lines: Array[String] = []
	var hud: Hud = null
	for c in scene.find_children("*", "Hud", true, false):
		hud = c as Hud
	if hud != null:
		hud.line_started.connect(func(k: String) -> void: lines.append(k))
	var sounds: Array[String] = []
	var early_shot := false
	for i in HOLD_FRAMES:
		await r.tree.process_frame
		if cs == null:
			cs = scene.find_child("Cutscene", true, false) as Ep01V3Cutscene
		for s in _audio_playing(scene):
			if not sounds.has(s):
				sounds.append(s)
		if cs != null and (cs.shot_index >= 0 or cs.time > 0.0):
			early_shot = true
	r.check(cs != null and cs.playing, "cutscene cover %s: cena pedida e esperando a tela" % label)
	r.check(lines.is_empty(), "cutscene cover %s: nenhuma fala sob a tela de carregamento %s" % [label, str(lines)])
	r.check(sounds.is_empty(), "cutscene cover %s: nenhum som da cena sob a tela %s" % [label, str(sounds)])
	r.check(not early_shot, "cutscene cover %s: relogio parado sob a tela (plano %d t=%.2f)" % [label,
		cs.shot_index if cs != null else -9, cs.time if cs != null else -1.0])
	# Libera: o loader passa para FADING_OUT no proximo quadro dele.
	loader._settle_left = 0
	var frames := 0
	while not _released(loader) and frames < 10:
		await r.tree.process_frame
		frames += 1
	var released_frame := Engine.get_process_frames()
	if cs != null and cs.shot_index < 0:
		await r.tree.process_frame
	var started_frame := Engine.get_process_frames()
	r.check(cs != null and cs.shot_index == 0 and started_frame - released_frame <= 1,
		"cutscene cover %s: primeiro plano comeca no quadro em que a tela libera (%d quadro(s) depois)" % [label,
		started_frame - released_frame])
	r.check(not lines.is_empty(), "cutscene cover %s: a primeira fala entra com a tela liberada %s" % [label, str(lines)])
	while loader.is_busy():
		await r.tree.process_frame
	r.tree.current_scene = null
	scene.queue_free()
	holder.queue_free()
	await r.frames(3)


## Palco leve: vila + HUD + player de cenas (sem o jogo).
func _stage() -> Array:
	var root := Node3D.new()
	r.tree.root.add_child(root)
	var world := (load(GameIntroScene.WORLD_SCENE) as PackedScene).instantiate() as VillageWorld
	root.add_child(world)
	var hud := Hud.new()
	root.add_child(hud)
	var cs := Ep01V3Cutscene.new()
	root.add_child(cs)
	cs.setup(world, hud, {})
	return [root, hud, cs]


func _cover() -> SceneLoaderService:
	var loader := SceneLoaderService.instance()
	loader.cover_current()
	loader._settle_left = 100000
	return loader


func _settle(loader: SceneLoaderService) -> void:
	var t0 := Time.get_ticks_msec()
	while loader.is_busy() and Time.get_ticks_msec() - t0 < 10000:
		await r.tree.process_frame


## Pular (cena ja vista) durante a espera da tela: termina na hora, sem fala, e a cena nao recomeca depois.
func _skip_while_waiting() -> void:
	var st := _stage()
	var hud := st[1] as Hud
	var cs := st[2] as Ep01V3Cutscene
	var lines: Array[String] = []
	hud.line_started.connect(func(k: String) -> void: lines.append(k))
	Ep01V3Cutscene.mark_seen(&"m1_intro")
	var loader := _cover()
	var ended: Array = []
	cs.finished.connect(func(id: StringName, skipped: bool) -> void: ended.append([id, skipped]))
	r.check(cs.play(&"m1_intro") and cs.waiting_screen, "cutscene cover: cena vista espera a tela")
	await r.frames(3)
	r.check(cs.skip(), "cutscene cover: pular funciona durante a espera da tela")
	r.check(not cs.playing and not cs.waiting_screen and ended.size() == 1 and bool(ended[0][1]),
		"cutscene cover: pular na espera termina a cena (pulada) %s" % str(ended))
	loader._settle_left = 0
	await _settle(loader)
	await r.frames(3)
	r.check(lines.is_empty() and cs.shot_index < 0 and ended.size() == 1,
		"cutscene cover: cena pulada na espera nao fala nem recomeca ao liberar %s" % str(lines))
	(st[0] as Node).queue_free()
	await r.frames(3)


## Teto da tela segurada (loading_hold) ou falha de carga: o loader vai a FADING_OUT e a cena comeca.
func _released_by(how: StringName) -> void:
	var st := _stage()
	var cs := st[2] as Ep01V3Cutscene
	var holder := Node.new()
	var gd := GDScript.new()
	gd.source_code = "extends Node\nfunc loading_hold() -> bool:\n\treturn true\n"
	gd.reload()
	holder.set_script(gd)
	r.tree.root.add_child(holder)
	var prev_scene: Node = r.tree.current_scene
	r.tree.current_scene = holder
	var loader := _cover()
	var prev_max := loader.hold_max_ms
	r.check(cs.play(&"m1_intro") and cs.waiting_screen, "cutscene cover %s: cena espera a tela" % how)
	await r.frames(5)
	r.check(cs.shot_index < 0, "cutscene cover %s: sem plano enquanto a tela segura" % how)
	if how == &"hold_timeout":
		loader.hold_max_ms = 50
		loader._settle_left = 0
	else:
		loader._fail("teste G17")
	var t0 := Time.get_ticks_msec()
	while cs.shot_index < 0 and Time.get_ticks_msec() - t0 < 5000:
		await r.tree.process_frame
	r.check(cs.shot_index == 0 and not cs.waiting_screen,
		"cutscene cover %s: tela liberada (fase %d) e a cena comeca" % [how, loader.phase])
	await _settle(loader)
	loader.hold_max_ms = prev_max
	cs._finish(true)
	r.tree.current_scene = prev_scene
	holder.queue_free()
	(st[0] as Node).queue_free()
	await r.frames(3)
