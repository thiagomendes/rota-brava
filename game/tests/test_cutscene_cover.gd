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
