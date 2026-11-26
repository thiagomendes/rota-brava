extends SceneTree
## Capturas das cutscenes (RB-R1 D21): quadros da abertura do jogo (um por heroi) e de cenas do Ep01, no jogo real.
## Uso (Linux, Vulkan por software):
##   xvfb-run -a -s "-screen 0 1920x1080x24" bash tools/godot.sh --path game --rendering-driver vulkan \
##     --script res://episodes/ep01/v3/cutscene/cutscene_capture.gd -- --out=/abs/dir
## Nao e teste: so produz imagens para olhar.

const INTRO_SHOTS := [[3.0, "game_intro_1_vila"], [10.0, "game_intro_2_rastro"], [19.0, "game_intro_3_pico"],
	[25.0, "game_intro_4_leme"], [32.5, "game_intro_5_equipe"]]
## cena, missao de partida, tempo na cena, nome
const EP_SHOTS := [[&"opening", &"M0", 7.0, "ep01_opening"], [&"m1_intro", &"M1", 1.6, "ep01_m1_intro"],
	[&"m4_intro", &"M4", 4.5, "ep01_m4_intro_amora"], [&"boat_departure", &"M6", 1.5, "ep01_boat_departure"], [&"nightfall", &"M7", 6.0, "ep01_nightfall"],
	[&"closing", &"M8", 5.5, "ep01_closing"]]

var out_dir := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	_run.call_deferred()


func _shot(n: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(n + ".png"))
	print("[RB] shot ", n, " ", img.get_size())


func _until(cs: Ep01V3Cutscene, t: float) -> void:
	while cs.playing and cs.time < t:
		await process_frame


func _run() -> void:
	Ep01V3Main.save_path = ""
	Ep01V3Cutscene.seen_path = ""
	Ep01V3Cutscene.enabled = true
	GameIntroScene.next_scene = ""
	var intro := (load(GameIntroScene.SELF_SCENE) as PackedScene).instantiate() as GameIntroScene
	root.add_child(intro)
	current_scene = intro
	await process_frame
	for s: Array in INTRO_SHOTS:
		await _until(intro.cutscene, float(s[0]))
		await _shot(str(s[1]))
	intro.queue_free()
	await create_timer(0.3).timeout
	for s: Array in EP_SHOTS:
		Ep01V3Cutscene.enabled = false
		Ep01V3Main.start_mission = s[1]
		var main := (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
		root.add_child(main)
		current_scene = main
		await create_timer(1.0).timeout
		Ep01V3Cutscene.enabled = true
		main.play_cutscene(s[0])
		await process_frame
		await _until(main.cutscene, float(s[2]))
		await _shot(str(s[3]))
		main.queue_free()
		await create_timer(0.3).timeout
	quit(0)
