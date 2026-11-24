class_name IconView
extends Control
## Pictograma da marca (SVG em res://ui/brand/icons/<kind>.svg) sobre um disco com anel colorido.
## Mantem a API antiga (`kind`, `color`, `back_color`). `color` pinta o anel (cor-assinatura do heroi ou acao).
## `texture_override` troca o pictograma por outra textura (ex.: retrato renderizado do heroi).

const ICON_DIR := "res://ui/brand/icons/"
## Nomes antigos do desenho procedural -> pictograma novo.
const ALIASES := {&"line": &"rope", &"compass": &"star"}
const OUTLINE := Color("123A5E")

@export var kind: StringName = &"notebook":
	set(value):
		kind = value
		_tex = null
		queue_redraw()
@export var color: Color = Color("FFD23F"):
	set(value):
		color = value
		queue_redraw()
@export var back_color: Color = Color("F7FBFF")
## Largura do anel em fracao do diametro (0 = sem anel).
@export var ring: float = 0.07:
	set(value):
		ring = value
		queue_redraw()
var texture_override: Texture2D:
	set(value):
		texture_override = value
		queue_redraw()

var _tex: Texture2D
static var _cache: Dictionary = {}


func _init() -> void:
	custom_minimum_size = Vector2(64, 64)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func icon_path(k: StringName) -> String:
	return ICON_DIR + String(ALIASES.get(k, k)) + ".svg"


static func has_icon(k: StringName) -> bool:
	return ResourceLoader.exists(icon_path(k))


static func texture_for(k: StringName) -> Texture2D:
	var p := icon_path(k)
	if not _cache.has(p):
		_cache[p] = load(p) as Texture2D if ResourceLoader.exists(p) else null
	return _cache[p]


func current_texture() -> Texture2D:
	if texture_override != null:
		return texture_override
	if _tex == null:
		_tex = texture_for(kind)
	return _tex


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var r := s * 0.5
	if back_color.a > 0.0:
		if ring > 0.0:
			draw_circle(c + Vector2(0, s * 0.03), r, Color(OUTLINE, 0.25))
			draw_circle(c, r, color)
			draw_circle(c, r * (1.0 - ring * 2.0), back_color)
		else:
			draw_circle(c, r, back_color)
	var t := current_texture()
	if t == null:
		draw_circle(c, r * 0.3, OUTLINE)
		return
	var inner := s * (0.66 if back_color.a > 0.0 else 0.95)
	draw_texture_rect(t, Rect2(c - Vector2(inner, inner) * 0.5, Vector2(inner, inner)), false)
