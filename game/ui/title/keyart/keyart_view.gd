class_name KeyArtView
extends Control
## Moldura 2D da arte-chave (RB-R1 G8, PROPOSTA): palco 3D (KeyArtStage) num SubViewport que acompanha o tamanho
## da tela, logotipo SVG rasterizado na hora no tamanho exato (sem serrilhado) e, no modo menu, um veu suave do lado
## dos botoes para garantir leitura. Nao recebe mouse nem foco: pode ficar atras de qualquer menu.
## Uso como fundo do menu (quando Thiago escolher): instanciar keyart_<x>.tscn como primeiro filho do menu com
## framing = &"menu" e show_logo = false (o menu mantem o proprio logo) ou true (logo da proposta no canto).

@export var proposal: StringName = &"a"
@export var framing: StringName = &"wide"
@export var show_logo := true
@export var animate := true
## Antisserrilhado 3D (no menu do jogo pode subir; nas capturas por software fica desligado por memoria).
@export var msaa: Viewport.MSAA = Viewport.MSAA_2X

var stage: KeyArtStage
var viewport: SubViewport
var logo: TextureRect
var scrim: TextureRect
var _logo_svg := ""
var _logo_px := Vector2i.ZERO


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	var box := SubViewportContainer.new()
	box.name = "Stage"
	box.stretch = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(box)
	viewport = SubViewport.new()
	viewport.name = "StageViewport"
	viewport.own_world_3d = true
	viewport.msaa_3d = msaa
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	viewport.positional_shadow_atlas_size = 1024
	box.add_child(viewport)
	stage = KeyArtStage.new()
	stage.proposal = proposal
	stage.framing = framing
	stage.animate = animate
	viewport.add_child(stage)
	scrim = TextureRect.new()
	scrim.name = "MenuScrim"
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.texture = _scrim_texture()
	add_child(scrim)
	logo = TextureRect.new()
	logo.name = "KeyLogo"
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(logo)
	_logo_svg = String(KeyArtPresets.LOGOS[proposal])
	resized.connect(_layout)
	set_framing(framing)


func set_framing(f: StringName) -> void:
	framing = f
	if stage != null:
		stage.framing = f
	if stage != null and stage.ready_to_shoot:
		stage.set_framing(f)
	_layout()


## Veu do lado direito (onde ficam os botoes): da transparencia a 45% da cor de sombra da paleta.
func _scrim_texture() -> Texture2D:
	var shadow := Color(String(KeyArtPresets.PALETTES[proposal][3]))
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 0.62, 1.0])
	g.colors = PackedColorArray([Color(shadow, 0.0), Color(shadow, 0.0), Color(shadow, 0.28), Color(shadow, 0.45)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 4
	return t


## Lugar do logo por enquadramento: [centro x, centro y, largura] em fracoes da tela.
func _logo_rect() -> Array:
	var per: Dictionary = KeyArtPresets.LOGO_LAYOUT.get(proposal, {})
	var d := {&"wide": [0.5, 0.16, 0.46], &"portrait": [0.5, 0.12, 0.84], &"capsule": [0.5, 0.5, 0.6], &"menu": [0.25, 0.14, 0.4]}
	return per.get(framing, d.get(framing, d[&"wide"]))


func _layout() -> void:
	if logo == null:
		return
	scrim.visible = framing == &"menu"
	logo.visible = show_logo
	if not show_logo or size.x < 2.0:
		return
	var r := _logo_rect()
	var w := size.x * float(r[2])
	var tex := _raster_logo(int(w))
	if tex == null:
		return
	var h := w * float(tex.get_height()) / float(tex.get_width())
	logo.texture = tex
	logo.size = Vector2(w, h)
	logo.position = Vector2(size.x * float(r[0]) - w * 0.5, size.y * float(r[1]) - h * 0.5)


## Rasteriza o SVG do logo na largura pedida (ThorVG da Godot). Cai para a textura importada se o SVG nao abrir.
func _raster_logo(px_w: int) -> Texture2D:
	if logo.texture != null and absi(_logo_px.x - px_w) < 4:
		return logo.texture
	var src := FileAccess.get_file_as_string(_logo_svg)
	if src.is_empty():
		return load(_logo_svg) as Texture2D
	var rx := RegEx.create_from_string("<svg[^>]*\\swidth=\"([0-9.]+)\"")
	var m := rx.search(src)
	var svg_w := float(m.get_string(1)) if m != null else 1000.0
	var img := Image.new()
	if img.load_svg_from_string(src, float(px_w) / svg_w) != OK:
		return load(_logo_svg) as Texture2D
	_logo_px = img.get_size()
	return ImageTexture.create_from_image(img)


## Textura do logo em `px_w` pixels de largura (para o menu de demonstracao trocar o logo antigo).
static func logo_texture(id: StringName, px_w: int) -> Texture2D:
	var path := String(KeyArtPresets.LOGOS[id])
	var src := FileAccess.get_file_as_string(path)
	var m := RegEx.create_from_string("<svg[^>]*\\swidth=\"([0-9.]+)\"").search(src)
	var img := Image.new()
	if m == null or img.load_svg_from_string(src, float(px_w) / float(m.get_string(1))) != OK:
		return load(path) as Texture2D
	return ImageTexture.create_from_image(img)
