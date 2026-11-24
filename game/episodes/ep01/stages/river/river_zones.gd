class_name RiverZones
extends RefCounted
## Dados e funcoes puras do rio (Etapa 2): correnteza por ZONAS e distancia a margem/obstaculos.
## Ajuste `STRENGTH` (multiplicador de Ep01Layout.RIVER_CURRENT por zona) sem tocar no resto.

const ZONE_CHANNEL := &"channel"
const ZONE_BANK := &"bank"
const ZONE_HARBOR := &"harbor"
const ZONE_COVE := &"cove"
## Rota opcional ao sul do banco de areia: canal raso de tras, corrente mais suave (SPEC 3, profundidade opcional).
const ZONE_BACK_CHANNEL := &"back_channel"

## Canal central: |z| <= CHANNEL_HALF_WIDTH dentro do corredor do rio.
const CHANNEL_HALF_WIDTH := 6.0
const COVE_ZONE_RADIUS := 8.0
const BUOY_OBSTACLE_RADIUS := 1.0
const GUIDE_RANGE := 4.0
const GUIDE_PUSH := 1.0

## Multiplicador da correnteza base por zona (direcao = a de RIVER_CURRENT).
static var STRENGTH := {
	ZONE_CHANNEL: 1.0,
	ZONE_BANK: 0.4,
	ZONE_HARBOR: 0.3,
	ZONE_COVE: 0.1,
	ZONE_BACK_CHANNEL: 0.15,
}

## Regioes de agua permitidas (Rect2 em x,z): porto + rio, e a baia da enseada.
const WATER_RECTS := [
	Rect2(-20.0, -14.0, 202.0, 28.0),   # x -20..182, z -14..14
	Rect2(157.0, 3.0, 17.0, 25.0),      # enseada: x 157..174, z 3..28
]
## Obstaculos retangulares (x,z): cais e margem de terra ao sul do porto.
const BOX_OBSTACLES := [
	Rect2(-8.0, -3.0, 16.0, 6.0),
	Rect2(-10.0, 3.0, 20.0, 13.0),
	Ep01Layout.SANDBAR_RECT,            # banco de areia: desacelera e desvia o barco
	Rect2(175.5, 1.5, 6.5, 16.5),       # lingua de terra do pouso de Pico
]


static func zone_at(pos: Vector3) -> StringName:
	var p := Vector2(pos.x, pos.z)
	if p.distance_to(Vector2(Ep01Layout.ENSEADA_POS.x, Ep01Layout.ENSEADA_POS.z)) <= COVE_ZONE_RADIUS:
		return ZONE_COVE
	if in_back_channel(pos):
		return ZONE_BACK_CHANNEL
	if pos.x < Ep01Layout.RIVER_X_MIN:
		return ZONE_HARBOR
	if absf(pos.z) <= CHANNEL_HALF_WIDTH:
		return ZONE_CHANNEL
	return ZONE_BANK


## Faixa entre o banco de areia e a margem sul (e um pouco antes/depois dele).
static func in_back_channel(pos: Vector3) -> bool:
	var s := Ep01Layout.SANDBAR_RECT
	return pos.x >= s.position.x - 3.0 and pos.x <= s.end.x + 3.0 and pos.z >= s.end.y - 0.5 and pos.z <= Ep01Layout.RIVER_Z_HALF


static func zone_current(pos: Vector3) -> Vector3:
	return Ep01Layout.RIVER_CURRENT * float(STRENGTH[zone_at(pos)])


static func _rect_inner(r: Rect2, p: Vector2) -> float:
	return minf(minf(p.x - r.position.x, r.end.x - p.x), minf(p.y - r.position.y, r.end.y - p.y))


static func _rect_outer(r: Rect2, p: Vector2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	if dx == 0.0 and dy == 0.0:
		return -_rect_inner(r, p)
	return sqrt(dx * dx + dy * dy)


## Distancia (m) ao obstaculo mais proximo; negativa fora da agua permitida.
static func clearance(pos: Vector3) -> float:
	var p := Vector2(pos.x, pos.z)
	var water := -INF
	for r: Rect2 in WATER_RECTS:
		water = maxf(water, _rect_inner(r, p))
	var c := water
	for b: Rect2 in BOX_OBSTACLES:
		c = minf(c, _rect_outer(b, p))
	var buoy := Vector2(Ep01Layout.BUOY_POS.x, Ep01Layout.BUOY_POS.z)
	c = minf(c, p.distance_to(buoy) - BUOY_OBSTACLE_RADIUS)
	return c


## Empurrao suave de volta para a agua aberta (margens guiam para a rota).
static func guide_push(pos: Vector3) -> Vector3:
	var c := clearance(pos)
	if c >= GUIDE_RANGE:
		return Vector3.ZERO
	var e := 0.5
	var g := Vector3(
		clearance(pos + Vector3(e, 0, 0)) - clearance(pos - Vector3(e, 0, 0)), 0.0,
		clearance(pos + Vector3(0, 0, e)) - clearance(pos - Vector3(0, 0, e)))
	if g.length() < 0.001:
		return Vector3.ZERO
	return g.normalized() * GUIDE_PUSH * clampf((GUIDE_RANGE - c) / GUIDE_RANGE, 0.0, 1.0)


static func current_at(pos: Vector3) -> Vector3:
	return zone_current(pos) + guide_push(pos)
