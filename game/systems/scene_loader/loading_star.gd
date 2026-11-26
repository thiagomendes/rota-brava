class_name LoadingStar
extends Control
## Estrela-guia de 4 pontas do logo C (mesma proporcao: ponta 52, cintura 15,6), desenhada por codigo, com tres
## pontinhos do trio (cores de Rastro, Pico e Leme) que acendem em sequencia. Gira e pulsa; com movimento reduzido
## fica parada (so o fade da tela).

const FILL_TOP := Color("#FFF6C2")
const FILL_BOTTOM := Color("#FFC233")
const OUTLINE := Color("#102A43")
const TRIO: Array[Color] = [Color("#E8833A"), Color("#4FA3E0"), Color("#5CC27A")]  # provisorio: cores do trio
const RADIUS := 70.0

var reduced_motion: bool = false
var spin: float = 0.0


func advance(dt: float) -> void:
	if reduced_motion:
		return
	spin += dt
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var rot := spin * 1.6
	var pulse := 1.0 + 0.08 * sin(spin * 5.0)
	if reduced_motion:
		rot = 0.0
		pulse = 1.0
	var outline := _star(c, RADIUS * pulse + 7.0, rot)
	draw_colored_polygon(outline, OUTLINE)
	var pts := _star(c, RADIUS * pulse, rot)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(FILL_TOP.lerp(FILL_BOTTOM, clampf((p.y - c.y + RADIUS) / (2.0 * RADIUS), 0.0, 1.0)))
	draw_polygon(pts, cols)
	for i in TRIO.size():
		var on := reduced_motion or int(spin * 3.0) % 3 == i
		var col := TRIO[i] if on else TRIO[i].darkened(0.55)
		draw_circle(c + Vector2((i - 1) * 34.0, RADIUS + 52.0), 9.0, col)


static func _star(c: Vector2, r: float, rot: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 8:
		var rad := r if i % 2 == 0 else r * 0.3
		var a := rot + i * PI / 4.0 - PI / 2.0
		out.append(c + Vector2(cos(a), sin(a)) * rad)
	return out
