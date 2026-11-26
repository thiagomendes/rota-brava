extends SceneTree
## Renderiza uma proposta de arte-chave (RB-R1 G8) em todos os formatos pedidos. Nao e teste: so produz imagens.
## Uso (Linux, Vulkan por software; tela do xvfb grande o bastante para 2400x1920):
##   xvfb-run -a -s "-screen 0 2560x2048x24" bash tools/godot.sh --path game --rendering-driver vulkan \
##     --script res://ui/title/keyart/keyart_capture.gd -- --proposal=a --out=/abs/captures/g8 [--only=wide,menu169]
## Saidas em <out>/<proposal>_*.png:
##   key_16x9 (1920x1080), cover_3x4 (1440x1920), capsule_460x215 (+ _x4 de 1840x860 de onde sai a reducao),
##   menu_16x9 / menu_20x9 / menu_4x3 (o menu atual por cima do fundo novo, so nesta captura: o menu do jogo nao muda),
##   bg_16x9 (fundo do menu sem logo e sem botoes).

const SHOTS := {
	"wide": [Vector2i(1920, 1080), &"wide", true, "key_16x9"],
	"portrait": [Vector2i(1440, 1920), &"portrait", true, "cover_3x4"],
	"capsule": [Vector2i(1840, 860), &"capsule", true, "capsule_460x215_x4"],
	"bg": [Vector2i(1920, 1080), &"menu", false, "bg_16x9"],
}
const MENU_SIZES := {"menu169": Vector2i(1920, 1080), "menu209": Vector2i(2400, 1080), "menu43": Vector2i(1440, 1080)}

var proposal: StringName = &"a"
var out_dir := ""
var only: PackedStringArray = []
var view: KeyArtView


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--proposal="):
			proposal = StringName(a.trim_prefix("--proposal="))
		elif a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _want(k: String) -> bool:
	return only.is_empty() or only.has(k)


func _size(s: Vector2i) -> void:
	DisplayServer.window_set_size(s)
	root.size = s
	await _frames(3)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(n: String) -> Image:
	# alguns quadros para AO/SSIL/brilho assentarem depois de mudar camera ou tamanho
	await create_timer(0.6).timeout
	await _frames(6)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out_dir.path_join("%s_%s.png" % [proposal, n]))
	if OS.get_cmdline_user_args().has("--debug-sub"):
		view.viewport.get_texture().get_image().save_png(out_dir.path_join("%s_%s_sub.png" % [proposal, n]))
		print("[RB] env bg=%d amb=%.2f exp=%.2f sun=%.2f" % [view.stage.world.env.background_mode, view.stage.world.env.ambient_light_energy, view.stage.world.env.tonemap_exposure, view.stage.world.sun.light_energy])
	print("[RB] keyart shot %s_%s %s t=%d ms" % [proposal, n, img.get_size(), Time.get_ticks_msec()])
	return img


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	await _size(Vector2i(1920, 1080))
	view = (load("res://ui/title/keyart/keyart_%s.tscn" % proposal) as PackedScene).instantiate() as KeyArtView
	view.animate = false   # quadro deterministico (sem respiracao da camera nem balanco do barco)
	view.msaa = Viewport.MSAA_DISABLED   # memoria: o llvmpipe divide a maquina com outros renders
	# arte-chave em pixels reais (sem a escala canvas_items do projeto); o menu de demonstracao volta a escala do jogo
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.add_child(view)
	while not view.stage.ready_to_shoot:
		await process_frame
	print("[RB] keyart stage ready %d ms" % (Time.get_ticks_msec() - t0))
	if OS.get_cmdline_user_args().has("--debug-env"):
		await _debug_env()
		quit(0)
		return
	for k: String in SHOTS:
		if not _want(k):
			continue
		var s: Array = SHOTS[k]
		await _size(s[0])
		view.show_logo = bool(s[2])
		view.set_framing(s[1])
		var img := await _shot(String(s[3]))
		if k == "capsule":
			img.resize(460, 215, Image.INTERPOLATE_LANCZOS)
			img.save_png(out_dir.path_join("%s_capsule_460x215.png" % proposal))
			print("[RB] keyart shot %s_capsule_460x215 (460, 215)" % proposal)
	var want_menu := false
	for k in MENU_SIZES:
		want_menu = want_menu or _want(k)
	if want_menu:
		await _size(MENU_SIZES["menu169"])
		view.show_logo = false
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_size = Vector2i(1920, 1080)
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		view.set_framing(&"menu")
		var menu := (load("res://ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
		root.add_child(menu)
		await _frames(2)
		# so nesta captura: some o ceu chapado e o palco antigo do menu; o logo antigo da lugar ao da proposta
		menu.background.visible = false
		menu.hero_stage.visible = false
		menu.logo.texture = KeyArtView.logo_texture(proposal, 1400)
		await create_timer(1.6).timeout   # animacoes de entrada dos botoes
		var fo := root.gui_get_focus_owner()
		print("[RB] keyart menu focus=%s" % (fo.name if fo != null else "<nenhum>"))
		for k: String in MENU_SIZES:
			if not _want(k):
				continue
			await _size(MENU_SIZES[k])
			view.set_framing(&"menu")
			await _shot("menu_" + k.trim_prefix("menu").insert(2 if k != "menu43" else 1, "x"))
	print("[RB] keyart done %d ms" % (Time.get_ticks_msec() - t0))
	quit(0)


func _debug_env() -> void:
	await _size(Vector2i(640, 360))
	var e := view.stage.world.env
	var sm := view.stage.world.sky_mat
	print("[RB] same_sky=", e.sky.sky_material == sm, " top=", sm.get_shader_parameter("top_color"), " fog=", e.fog_enabled,
		" fogc=", e.fog_light_color, " dens=", e.fog_density, " glow=", e.glow_enabled, " vol=", e.volumetric_fog_enabled)
	await _shot("dbg0")
	e.fog_enabled = false
	await _shot("dbg1_nofog")
	e.glow_enabled = false
	await _shot("dbg2_noglow")
	e.ssil_enabled = false
	e.ssao_enabled = false
	await _shot("dbg3_nossil")
	e.adjustment_enabled = false
	await _shot("dbg4_noadj")
