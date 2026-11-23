class_name IconView
extends Control
## Pictogramas desenhados em codigo, formas proprias (PROVISORIOS ate a aprovacao artistica):
## paw, boot, notebook, line, helm, boat, bank, harbor. Cada forma tem contorno escuro para ler sobre qualquer fundo.

@export var kind: StringName = &"notebook":
	set(value):
		kind = value
		queue_redraw()
@export var color: Color = Color("fff3c4"):
	set(value):
		color = value
		queue_redraw()
@export var back_color: Color = Color(0, 0, 0, 0.55)

const OUTLINE := Color(0.03, 0.07, 0.09, 0.95)

var _o: Vector2
var _u: float


func _init() -> void:
	custom_minimum_size = Vector2(64, 64)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _p(x: float, y: float) -> Vector2:
	return _o + Vector2(x, y) * _u


func _poly(pts: Array, fill: Color, outline: bool = true) -> void:
	var v := PackedVector2Array()
	for q: Vector2 in pts:
		v.append(_p(q.x, q.y))
	if outline:
		var closed := v.duplicate()
		closed.append(v[0])
		draw_polyline(closed, OUTLINE, 6.0 * _u, true)
	draw_colored_polygon(v, fill)


func _ellipse(c: Vector2, rx: float, ry: float, rot: float, fill: Color) -> void:
	var pts: Array = []
	for i in 20:
		var a := i * TAU / 20.0
		var q := Vector2(cos(a) * rx, sin(a) * ry).rotated(rot) + c
		pts.append(q)
	_poly(pts, fill)


func _stroke(pts: PackedVector2Array, width: float, fill: Color) -> void:
	draw_polyline(pts, OUTLINE, (width + 6.0) * _u, true)
	draw_polyline(pts, fill, width * _u, true)


func _draw() -> void:
	var s := minf(size.x, size.y)
	_o = (size - Vector2(s, s)) * 0.5
	_u = s / 100.0
	draw_circle(size * 0.5, s * 0.5, back_color)
	match kind:
		&"paw":
			# Almofada grande com tres lobos e quatro dedos ovais.
			_ellipse(Vector2(50, 66), 21, 15, 0.0, color)
			_ellipse(Vector2(36, 62), 11, 11, 0.0, color)
			_ellipse(Vector2(64, 62), 11, 11, 0.0, color)
			_ellipse(Vector2(22, 46), 7, 10, -0.5, color)
			_ellipse(Vector2(38, 28), 7.5, 11, -0.15, color)
			_ellipse(Vector2(62, 28), 7.5, 11, 0.15, color)
			_ellipse(Vector2(78, 46), 7, 10, 0.5, color)
		&"boot":
			# Cano, cabo, solado grosso e ponta redonda, com cadarcos.
			var sole := color.darkened(0.4)
			_poly([Vector2(34, 16), Vector2(60, 16), Vector2(60, 52), Vector2(82, 58), Vector2(86, 72),
				Vector2(28, 72), Vector2(28, 50), Vector2(34, 50)], color)
			_poly([Vector2(32, 16), Vector2(62, 16), Vector2(62, 27), Vector2(32, 27)], sole)
			_poly([Vector2(24, 72), Vector2(90, 72), Vector2(90, 84), Vector2(24, 84)], sole)
			for i in 3:
				var y := 36.0 + i * 8.0
				draw_line(_p(40, y), _p(54, y), OUTLINE, 3.0 * _u)
		&"notebook":
			# Capa com argolas a esquerda, linhas de texto e fita marcadora.
			_poly([Vector2(28, 14), Vector2(76, 14), Vector2(76, 86), Vector2(28, 86)], color)
			var ribbon := color.darkened(0.45)
			_poly([Vector2(62, 14), Vector2(70, 14), Vector2(70, 38), Vector2(66, 33), Vector2(62, 38)], ribbon, false)
			for i in 5:
				var cy := 24.0 + i * 13.0
				draw_circle(_p(28, cy), 5.5 * _u, OUTLINE)
				draw_circle(_p(28, cy), 3.0 * _u, color)
			for i in 3:
				draw_line(_p(38, 50 + i * 11), _p(66 - i * 6, 50 + i * 11), OUTLINE, 3.5 * _u)
		&"line":
			# Corda esticada em arco entre dois pinos, com trancado e no no topo.
			var pts := PackedVector2Array()
			for i in 25:
				var t := i / 24.0
				pts.append(_p(20 + 60 * t, 66 - 40 * sin(t * PI)))
			_stroke(pts, 9.0, color)
			for i in range(2, 23, 3):
				var a: Vector2 = pts[i]
				var d: Vector2 = (pts[i + 1] - pts[i - 1]).normalized()
				var n := Vector2(-d.y, d.x)
				draw_line(a - n * 4.5 * _u + d * 2.0 * _u, a + n * 4.5 * _u - d * 2.0 * _u, OUTLINE, 2.5 * _u)
			for x in [20.0, 80.0]:
				draw_circle(_p(x, 70), 11 * _u, OUTLINE)
				draw_circle(_p(x, 70), 8 * _u, color.darkened(0.35))
			draw_circle(_p(50, 26), 8 * _u, OUTLINE)
			draw_circle(_p(50, 26), 5 * _u, color)
		&"helm":
			# Roda de leme: aro duplo, cubo e oito punhos.
			for i in 8:
				var a := i * TAU / 8.0
				var d := Vector2(cos(a), sin(a))
				draw_line(_p(50 + d.x * 8, 50 + d.y * 8), _p(50 + d.x * 40, 50 + d.y * 40), OUTLINE, 11.0 * _u)
			for i in 8:
				var a := i * TAU / 8.0
				var d := Vector2(cos(a), sin(a))
				draw_line(_p(50 + d.x * 8, 50 + d.y * 8), _p(50 + d.x * 40, 50 + d.y * 40), color, 5.0 * _u)
				draw_circle(_p(50 + d.x * 41, 50 + d.y * 41), 5.5 * _u, OUTLINE)
				draw_circle(_p(50 + d.x * 41, 50 + d.y * 41), 3.5 * _u, color)
			draw_arc(_p(50, 50), 27 * _u, 0, TAU, 40, OUTLINE, 13.0 * _u, true)
			draw_arc(_p(50, 50), 27 * _u, 0, TAU, 40, color, 7.0 * _u, true)
			draw_circle(_p(50, 50), 12 * _u, OUTLINE)
			draw_circle(_p(50, 50), 8.5 * _u, color)
		&"boat":
			_poly([Vector2(16, 54), Vector2(84, 54), Vector2(70, 76), Vector2(30, 76)], color)
			_poly([Vector2(40, 34), Vector2(66, 34), Vector2(66, 54), Vector2(40, 54)], color)
		&"bank":
			_poly([Vector2(14, 78), Vector2(14, 52), Vector2(50, 42), Vector2(86, 52), Vector2(86, 78)], color)
			draw_line(_p(14, 36), _p(86, 36), Color("7fd0e0"), 5 * _u)
		&"harbor":
			draw_line(_p(50, 22), _p(50, 74), color, 6 * _u)
			draw_arc(_p(50, 60), 26 * _u, 0.2, PI - 0.2, 20, color, 6 * _u)
			draw_circle(_p(50, 24), 6 * _u, color)
		_:
			draw_circle(size * 0.5, s * 0.25, color)
