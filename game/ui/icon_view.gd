class_name IconView
extends Control
## Pictogramas desenhados em codigo (PROVISORIOS ate a aprovacao artistica): paw, boot, notebook, line, helm, boat, bank, harbor.

@export var kind: StringName = &"notebook":
	set(value):
		kind = value
		queue_redraw()
@export var color: Color = Color("fff3c4"):
	set(value):
		color = value
		queue_redraw()
@export var back_color: Color = Color(0, 0, 0, 0.55)


func _init() -> void:
	custom_minimum_size = Vector2(64, 64)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) * 0.5
	draw_circle(size * 0.5, s * 0.5, back_color)
	var u := s / 100.0
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * u
	match kind:
		&"paw":
			draw_circle(p.call(50, 62), 15 * u, color)
			for pos: Vector2 in [Vector2(28, 40), Vector2(42, 28), Vector2(58, 28), Vector2(72, 40)]:
				draw_circle(p.call(pos.x, pos.y), 8 * u, color)
		&"boot":
			var pts := PackedVector2Array([p.call(36, 22), p.call(56, 22), p.call(56, 52), p.call(78, 60),
				p.call(78, 78), p.call(30, 78), p.call(30, 52), p.call(36, 52)])
			draw_colored_polygon(pts, color)
			draw_line(p.call(30, 82), p.call(80, 82), color, 5 * u)
		&"notebook":
			draw_rect(Rect2(p.call(30, 22), Vector2(42, 56) * u), color)
			for i in 4:
				draw_circle(p.call(30, 32 + i * 13), 3.5 * u, back_color)
			for i in 3:
				draw_line(p.call(40, 36 + i * 13), p.call(64, 36 + i * 13), back_color, 2.5 * u)
		&"line":
			draw_circle(p.call(24, 62), 8 * u, color)
			draw_circle(p.call(76, 62), 8 * u, color)
			var prev: Vector2 = p.call(24, 62)
			for i in range(1, 13):
				var t := i / 12.0
				var cur: Vector2 = p.call(24 + 52 * t, 62 - 28 * sin(t * PI))
				draw_line(prev, cur, color, 5 * u)
				prev = cur
		&"helm":
			draw_arc(p.call(50, 50), 26 * u, 0, TAU, 32, color, 6 * u)
			draw_circle(p.call(50, 50), 7 * u, color)
			for i in 8:
				var a := i * TAU / 8.0
				draw_line(p.call(50 + cos(a) * 7, 50 + sin(a) * 7), p.call(50 + cos(a) * 36, 50 + sin(a) * 36), color, 5 * u)
		&"boat":
			draw_colored_polygon(PackedVector2Array([p.call(18, 56), p.call(82, 56), p.call(70, 76), p.call(30, 76)]), color)
			draw_rect(Rect2(p.call(42, 36), Vector2(24, 20) * u), color)
		&"bank":
			draw_colored_polygon(PackedVector2Array([p.call(14, 78), p.call(14, 52), p.call(50, 42), p.call(86, 52), p.call(86, 78)]), color)
			draw_line(p.call(14, 36), p.call(86, 36), Color("7fd0e0"), 5 * u)
		&"harbor":
			draw_line(p.call(50, 22), p.call(50, 74), color, 6 * u)
			draw_arc(p.call(50, 60), 26 * u, 0.2, PI - 0.2, 20, color, 6 * u)
			draw_circle(p.call(50, 24), 6 * u, color)
		_:
			draw_circle(size * 0.5, s * 0.25, color)
