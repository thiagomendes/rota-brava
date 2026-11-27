extends SceneTree
## RB-M1: gera os icones do app (Android e iOS) a partir do logo C noite.
## Uso: bash tools/godot.sh --headless --path game --script "$PWD/tools/mobile_icons.gd"
## Saida: game/ui/brand/app_icon/*.png (registrados em source_art/manifest.json, id app_icon_m1).

const LOGO := "res://ui/title/keyart/logos/logo_c_noite.svg"
const OUT := "res://ui/brand/app_icon/"
const BG := Color("#24507A") # azul de noite, contrasta com o contorno #102A43 do logo


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var svg := FileAccess.get_file_as_string(LOGO)
	# [nome, lado, fracao da largura ocupada pelo logo, com fundo]
	var jobs: Array = [
		["icon_android_192.png", 192, 0.86, true],
		["adaptive_foreground_432.png", 432, 0.60, false], # zona segura adaptativa = 66% central
		["icon_ios_1024.png", 1024, 0.84, true],
	]
	for j: Array in jobs:
		if not _make(svg, String(j[0]), int(j[1]), float(j[2]), bool(j[3])):
			quit(1)
			return
	var bg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	bg.fill(BG)
	bg.save_png(OUT + "adaptive_background_432.png")
	print("icones gerados em ", OUT)
	quit(0)


func _make(svg: String, fname: String, side: int, frac: float, with_bg: bool) -> bool:
	var logo := Image.new()
	# o SVG tem 1424 px de largura; escala para caber em frac*side
	var err := logo.load_svg_from_string(svg, frac * side / 1424.0)
	if err != OK:
		push_error("falha ao rasterizar o logo: %d" % err)
		return false
	logo.convert(Image.FORMAT_RGBA8)
	var canvas := Image.create(side, side, false, Image.FORMAT_RGBA8)
	canvas.fill(BG if with_bg else Color(0, 0, 0, 0))
	var pos := Vector2i((side - logo.get_width()) / 2, (side - logo.get_height()) / 2)
	canvas.blend_rect(logo, Rect2i(Vector2i.ZERO, logo.get_size()), pos)
	if fname.begins_with("icon_ios"):
		canvas.convert(Image.FORMAT_RGB8) # App Store recusa icone com alfa
	return canvas.save_png(OUT + fname) == OK
