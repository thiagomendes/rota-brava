class_name Ep01V3Nav
extends RefCounted
## Grade de chao andavel da vila v3 para o bot de teste (RB-R1 E1): raycast para baixo + capsula livre na colisao da
## camada 1, A* (AStarGrid2D) e corte de cantos por linha de visada. So o bot usa; o jogador nunca e guiado por isto.

const X0 := -45.0
const X1 := 45.0
const Z0 := -32.0
const Z1 := 22.0
const CELL := 0.25
## Abaixo disto e agua.
const MIN_FLOOR := -0.25
## Desnivel maximo entre celulas vizinhas (m): o corpo do heroi sobe rampa, nao degrau (sem step-up).
const MAX_STEP := 0.15
const CAPSULE_RADIUS := 0.34
const CAPSULE_HEIGHT := 1.4

var grid := AStarGrid2D.new()
var heights: Dictionary = {}


func build(space: PhysicsDirectSpaceState3D) -> void:
	var nx := int((X1 - X0) / CELL)
	var nz := int((Z1 - Z0) / CELL)
	grid.region = Rect2i(0, 0, nx, nz)
	grid.cell_size = Vector2(CELL, CELL)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var cap := CapsuleShape3D.new()
	cap.radius = CAPSULE_RADIUS
	cap.height = CAPSULE_HEIGHT
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = 1
	for ix in nx:
		for iz in nz:
			var c := Vector2i(ix, iz)
			var p := to_world(c)
			# Piso mais baixo com folga (o chao debaixo de toldos e beirais conta; telhados nao).
			var ok := false
			var exclude: Array[RID] = []
			for layer in 4:
				var rq := PhysicsRayQueryParameters3D.create(p + Vector3(0, 12, 0), p + Vector3(0, -3, 0), 1, exclude)
				var hit := space.intersect_ray(rq)
				if hit.is_empty() or float(hit.position.y) <= MIN_FLOOR:
					break
				var h := float(hit.position.y)
				q.transform = Transform3D(Basis(), Vector3(p.x, h + 0.25 + CAPSULE_HEIGHT * 0.5, p.z))
				if space.intersect_shape(q, 1).is_empty():
					ok = true
					heights[c] = h
				exclude.append(hit.rid)
			grid.set_point_solid(c, not ok)
	for c: Vector2i in heights.keys():
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if heights.has(c + d) and absf(float(heights[c + d]) - float(heights[c])) > MAX_STEP:
				grid.set_point_solid(c, true)
	# Custo maior perto de obstaculos: o caminho passa pelo meio das passagens (o corpo real tem inercia).
	for c: Vector2i in heights.keys():
		if not walkable(c):
			continue
		var near := 0
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				if not walkable(c + Vector2i(dx, dz)):
					near = maxi(near, 3 - maxi(absi(dx), absi(dz)))
		if near > 0:
			grid.set_point_weight_scale(c, 1.0 + near * 3.0)


## Marca como bloqueado um disco em volta de `p` (o bot ficou preso ali: o corpo real nao passa onde a grade passou).
func block(p: Vector3, radius: float) -> void:
	var c := to_cell(p)
	var r := int(ceil(radius / CELL))
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var n := c + Vector2i(dx, dz)
			if grid.is_in_boundsv(n) and Vector2(dx, dz).length() * CELL <= radius:
				grid.set_point_solid(n, true)


func to_cell(p: Vector3) -> Vector2i:
	return Vector2i(roundi((p.x - X0) / CELL), roundi((p.z - Z0) / CELL))


func to_world(c: Vector2i) -> Vector3:
	return Vector3(X0 + c.x * CELL, 0.0, Z0 + c.y * CELL)


func walkable(c: Vector2i) -> bool:
	return grid.is_in_boundsv(c) and not grid.is_point_solid(c)


## Celulas livres em volta de `c` ate `max_r` celulas, da mais perto para a mais longe.
func free_around(c: Vector2i, max_r: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dx in range(-max_r, max_r + 1):
		for dz in range(-max_r, max_r + 1):
			var n := c + Vector2i(dx, dz)
			if walkable(n):
				out.append(n)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - c).length_squared() < (b - c).length_squared())
	return out


## Caminho completo de `from` ate uma celula livre a ate `radius` m de `to` (e com altura perto de `to`);
## vazio se nao houver. Pontos ja simplificados (linha de visada).
func route(from: Vector3, to: Vector3, radius: float) -> Array[Vector3]:
	var starts := free_around(to_cell(from), 6)
	if starts.is_empty():
		return []
	var a := starts[0]
	var r_cells := maxi(1, int(radius / CELL))
	for b in free_around(to_cell(to), r_cells):
		if to_world(b).distance_to(Vector3(to.x, 0, to.z)) > radius or absf(float(heights[b]) - to.y) > 1.2:
			continue
		var path := grid.get_id_path(a, b)
		if path.is_empty():
			continue
		return _simplify(path)
	return []


func _los(a: Vector2i, b: Vector2i) -> bool:
	var pa := Vector2(a)
	var pb := Vector2(b)
	var n := int(pa.distance_to(pb) * 3.0) + 1
	for i in n + 1:
		var p := pa.lerp(pb, float(i) / n)
		for o: Vector2 in [Vector2.ZERO, Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2), Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1)]:
			if not walkable(Vector2i(roundi(p.x + o.x), roundi(p.y + o.y))):
				return false
	return true


func _simplify(path: Array[Vector2i]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var i := 0
	while i < path.size() - 1:
		var j := path.size() - 1
		while j > i + 1 and not _los(path[i], path[j]):
			j -= 1
		out.append(to_world(path[j]))
		i = j
	if path.size() == 1:
		out.append(to_world(path[0]))
	return out
