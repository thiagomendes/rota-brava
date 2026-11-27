extends SceneTree
## Capturas da E7 (RB-R1, ux): legenda com cada falante que nao e heroi (Farol 7, Dona Amora, capitao, filhote) na cena
## real do Ep01 v3, os 4 barquinhos da festa com os icones (estrela, lua, peixe, flor) e uma prancha dos icones novos
## a 48 e 96 px (pictograma solto e no disco do HUD), com o mosquetao antigo ao lado do novo.
## A fala e pedida ao HUD com hud.say(chave) no momento da captura (mesma chave e ficha que o jogo usa).
## Uso (Linux, Vulkan por software):
##   xvfb-run -a -s "-screen 0 2560x1440x24" bash tools/godot.sh --path game --rendering-driver vulkan \
##     --script res://../tools/capture_e7.gd -- --out=/abs/dir [--part=lines|boats|sheet|ratios] [--old-carabiner=/abs.svg]
## Nao e teste: so produz imagens para olhar.

var out_dir := ""
var part := ""
var old_carabiner := ""
var main: Ep01V3Main


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
		if a.begins_with("--part="):
			part = a.trim_prefix("--part=")
		if a.begins_with("--old-carabiner="):
			old_carabiner = a.trim_prefix("--old-carabiner=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _size(s: Vector2i) -> void:
	DisplayServer.window_set_size(s)
	root.size = s
	await _wait(0.3)


func _shot(n: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(n + ".png"))
	print("[RB] shot ", n, " ", img.get_size())


func _open(mission: StringName) -> void:
	if main != null:
		main.queue_free()
		await _wait(0.2)
	Ep01V3Main.save_path = ""
	Ep01V3Main.start_mission = mission
	main = (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	root.add_child(main)
	current_scene = main
	await _wait(0.5)
	for i in 3:
		await _wait(0.6)
		if main.hud.handoff_open:
			main.hud._confirm_handoff()
			await _wait(1.4)


func _mk(n: StringName) -> Vector3:
	return main.world.marker(n).global_position


func _yaw_to(from: Vector3, to: Vector3) -> void:
	var d := to - from
	main.camera_rig.set_low_view(atan2(d.x, d.z) + PI)
	main.camera_rig.follow(main.controlled_node, true)


func _say(key: String) -> void:
	main.hud.clear_speech()
	await _wait(0.4)
	main.hud.say(key)
	await _wait(0.9)


func _run() -> void:
	if part == "" or part == "lines":
		await _lines()
	if part == "" or part == "ratios":
		await _ratios()
	if part == "" or part == "boats":
		await _boats()
	if part == "" or part == "sheet":
		await _sheet()
	quit(0)


func _lines() -> void:
	await _size(Vector2i(1280, 720))
	await _open(&"M0")
	await _say("ep01.call.c1.lumi_alert")
	await _shot("legenda_farol7_m0")
	await _open(&"M4")
	await _say("ep01.market.vendor.mess")
	await _shot("legenda_dona_amora_m4")
	await _open(&"M7")
	await _say("ep01.lighthouse.pup.horn")
	await _shot("legenda_filhote_m7")
	await _open(&"M8")
	await _wait(1.0)
	_yaw_to(main.controlled_node.global_position, main.land.captain.global_position)
	await _say("ep01.festival.captain.first_lantern")
	await _shot("legenda_capitao_m8")


func _ratios() -> void:
	await _open(&"M4")
	for r: Array in [["16x9", Vector2i(1280, 720)], ["20x9", Vector2i(1600, 720)], ["4x3", Vector2i(960, 720)]]:
		await _size(r[1])
		await _say("ep01.market.vendor.pup_crates")
		await _shot("legenda_dona_amora_%s" % r[0])
	await _size(Vector2i(1280, 720))


func _boats() -> void:
	await _size(Vector2i(1280, 720))
	await _open(&"M8")
	await _wait(1.0)
	var c := Vector3.ZERO
	for b in Ep01V3Late.FESTA_BOATS:
		c += _mk(b)
	c /= float(Ep01V3Late.FESTA_BOATS.size())
	main.hud.clear_speech()
	# de longe: o heroi na beira, os 4 barquinhos a frente
	var a := main.controlled_node as MemberActor
	var shore := main.world.marker(&"M7_Lens").global_position
	print("[RB] barquinhos centro ", c, " lente ", shore)
	main.camera_rig.set_low_view(0.0)
	main.camera_rig.pitch = CameraRig.PITCH_MAX
	await _wait(0.3)
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.fov = 50.0
	cam.make_current()
	for b in Ep01V3Late.FESTA_BOATS:
		print("[RB] barquinho ", b, " ", _mk(b))
	# vistas altas e obliquas (sem paredes no caminho); a mais limpa vai para o ticket
	# visao geral (do oeste, alta) e um close de cada barquinho com o icone aceso
	cam.global_position = c + Vector3(-16.0, 9.0, 2.0)
	cam.look_at(c + Vector3(0, 1.2, 0))
	await _wait(1.2)
	await _shot("barquinhos_festa_noite_geral")
	for i in Ep01V3Late.FESTA_BOATS.size():
		var bp := _mk(Ep01V3Late.FESTA_BOATS[i])
		var away := Vector3(bp.x - c.x, 0, bp.z - c.z)
		var side := Vector3(0, 0, 1) if away.length() < 0.5 else away.normalized().rotated(Vector3.UP, 0.6)
		cam.global_position = bp + Vector3(0, 3.0, 0) - side * -6.5 + Vector3(0, 0, 0)
		cam.look_at(bp + Vector3(0, 1.6, 0))
		await _wait(1.0)
		await _shot("barquinho_%d_%s" % [i + 1, Ep01V3Pieces.FESTA_BOAT_ICONS[i]])
	cam.queue_free()
	if a != null:
		main.camera_rig.follow(a, true)


func _tex_from_svg(path: String, px: int) -> Texture2D:
	var img := Image.new()
	if img.load_svg_from_string(FileAccess.get_file_as_string(path), float(px) / 256.0) != OK:
		return null
	return ImageTexture.create_from_image(img)


func _sheet() -> void:
	if main != null:
		main.queue_free()
		main = null
		await _wait(0.3)
	await _size(Vector2i(1920, 1080))   # 1:1 com a base de 1080 (48 px = 48 px de tela)
	var bg := ColorRect.new()
	bg.color = Color("4FA6E8")
	bg.size = Vector2(1920, 1080)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	layer.add_child(bg)
	var kinds: Array[StringName] = [&"star", &"moon", &"fish", &"flower", &"vendor", &"radio", &"carabiner"]
	var paper := ColorRect.new()
	paper.color = Color("F7FBFF")
	paper.position = Vector2(40, 40)
	paper.size = Vector2(1840, 1000)
	bg.add_child(paper)
	var font := load(ThemeV2.FONT_PATH) as Font
	for i in kinds.size():
		var x := 70.0 + i * 220.0
		var l := Label.new()
		l.text = String(kinds[i])
		l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", 30)
		l.add_theme_color_override("font_color", ThemeV2.NAVY)
		l.position = Vector2(x, 60)
		bg.add_child(l)
		var col := 0
		for px: int in [48, 96]:
			# pictograma solto (como no barquinho e no balao) e no disco do HUD (IconView com anel)
			var t := TextureRect.new()
			t.texture = IconView.texture_for(kinds[i])
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.size = Vector2(px, px)
			t.position = Vector2(x, 130 + col * 130)
			bg.add_child(t)
			var iv := IconView.new()
			iv.kind = kinds[i]
			iv.color = ThemeV2.NAVY
			iv.size = Vector2(px, px)
			iv.position = Vector2(x + 110, 130 + col * 130)
			bg.add_child(iv)
			col += 1
		# fundo escuro (noite da festa): pictograma a 48 px
		var dark := ColorRect.new()
		dark.color = Color("0B2440")
		dark.position = Vector2(x - 10, 400)
		dark.size = Vector2(200, 120)
		bg.add_child(dark)
		for j in 2:
			var t2 := TextureRect.new()
			t2.texture = IconView.texture_for(kinds[i])
			t2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t2.size = Vector2(48, 48) * (j + 1)
			t2.position = Vector2(x + j * 70, 420)
			t2.modulate = Color(1.0, 0.92, 0.55)
			bg.add_child(t2)
	# mosquetao antes x depois a 48 e 96 px
	var row := 600.0
	var hl := Label.new()
	hl.text = "carabiner: antes | depois"
	hl.add_theme_font_override("font", font)
	hl.add_theme_font_size_override("font_size", 30)
	hl.add_theme_color_override("font_color", ThemeV2.NAVY)
	hl.position = Vector2(70, row)
	bg.add_child(hl)
	var k := 0
	for src: String in [old_carabiner, ProjectSettings.globalize_path(IconView.icon_path(&"carabiner"))]:
		if src == "":
			k += 1
			continue
		for px: int in [48, 96, 192]:
			var t3 := TextureRect.new()
			t3.texture = _tex_from_svg(src, px)
			t3.position = Vector2(70 + k * 520 + (0 if px == 48 else (70 if px == 96 else 190)), row + 60)
			bg.add_child(t3)
		k += 1
	# retratos da legenda: capitao e filhote (render) a 48 e 96 px no disco
	var hud_like: Array = [[&"captain", "res://ui/portraits/captain_neutra.png", Color("123A5E")],
		[&"pup", "res://ui/portraits/pup_neutra.png", Color("2A9D8F")], [&"vendor", "", Color("7A3E9D")],
		[&"radio", "", Color("FF5A4E")]]
	for i in hud_like.size():
		for j in 2:
			var px := 48.0 * (j + 1) + (24.0 if j == 1 else 0.0)
			var iv2 := IconView.new()
			iv2.kind = hud_like[i][0]
			iv2.color = hud_like[i][2]
			iv2.ring = 0.08
			if hud_like[i][1] != "":
				iv2.texture_override = load(hud_like[i][1]) as Texture2D
			iv2.size = Vector2(px, px)
			iv2.position = Vector2(1120 + i * 190 + j * 60 - (0 if j == 0 else 0), row + 60 + j * 70)
			bg.add_child(iv2)
	for i in 6:
		await process_frame
	await _shot("prancha_icones_48_96")
	layer.queue_free()
