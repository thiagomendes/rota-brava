extends SceneTree
## Folha de marca: renderiza os SVG importados (emblema, logo, pictogramas e estudos de tela) e salva PNG.
## Uso (com janela, nao headless): ./tools/godot.ps1 --path game --script res://ui/brand/brand_sheet.gd -- --out=<png> [--screens]

const ICON_DIR := "res://ui/brand/icons/"


func _initialize() -> void:
	_run.call_deferred()


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with(prefix):
			return a.trim_prefix(prefix)
	return fallback


func _tex(path: String, pos: Vector2, size: Vector2, parent: Control) -> void:
	var t := TextureRect.new()
	t.texture = load(path) as Texture2D
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.position = pos
	t.size = size
	parent.add_child(t)


func _run() -> void:
	var out := _arg("--out=", "user://brand_sheet.png")
	var screens := _arg("--screens", "") != "" or (OS.get_cmdline_user_args() + OS.get_cmdline_args()).has("--screens")
	root.size = Vector2i(1920, 1080)
	var bg := ColorRect.new()
	bg.color = Color("4FA6E8")
	bg.size = Vector2(1920, 1080)
	root.add_child(bg)
	if screens:
		var names := ["title", "hud", "handoff", "complete"]
		for i in names.size():
			_tex("res://ui/brand/screens/%s.svg" % names[i], Vector2(20 + (i % 2) * 950, 20 + (i / 2) * 530), Vector2(930, 523), bg)
	else:
		_tex("res://ui/brand/emblem_full.svg", Vector2(30, 30), Vector2(260, 290), bg)
		_tex("res://ui/brand/emblem_simple.svg", Vector2(300, 60), Vector2(110, 120), bg)
		_tex("res://ui/brand/emblem_simple.svg", Vector2(300, 200), Vector2(48, 53), bg)
		var mono_bg := ColorRect.new()
		mono_bg.color = Color("123A5E")
		mono_bg.position = Vector2(420, 60)
		mono_bg.size = Vector2(130, 140)
		bg.add_child(mono_bg)
		_tex("res://ui/brand/emblem_mono.svg", Vector2(430, 70), Vector2(110, 120), bg)
		_tex("res://ui/brand/logo_h.svg", Vector2(580, 30), Vector2(1300, 285), bg)
		_tex("res://ui/brand/logo_stack.svg", Vector2(30, 340), Vector2(520, 370), bg)
		var files: Array[String] = []
		for f in DirAccess.get_files_at(ICON_DIR):
			if f.ends_with(".svg"):
				files.append(f)
		files.sort()
		for i in files.size():
			var col := i % 10
			var row := i / 10
			var p := Vector2(600 + col * 128, 360 + row * 150)
			var disc := Panel.new()
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color("F7FBFF")
			sb.set_corner_radius_all(56)
			sb.set_border_width_all(5)
			sb.border_color = Color("123A5E")
			disc.add_theme_stylebox_override("panel", sb)
			disc.position = p
			disc.size = Vector2(112, 112)
			bg.add_child(disc)
			_tex(ICON_DIR + files[i], p + Vector2(12, 12), Vector2(88, 88), bg)
			var l := Label.new()
			l.text = files[i].get_basename()
			l.position = p + Vector2(0, 112)
			l.add_theme_font_size_override("font_size", 18)
			bg.add_child(l)
			# leitura a 48 px
			_tex(ICON_DIR + files[i], Vector2(40 + (i % 14) * 56, 900 + (i / 14) * 60), Vector2(48, 48), bg)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	print("[RB] brand_sheet save=%s err=%d" % [out, img.save_png(out)])
	quit(0)
