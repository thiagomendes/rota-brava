class_name MotionAudit
extends Node
## RB-R1 G24d: auditoria DINAMICA de interpenetracao. Presa a uma partida (Ep01V3Main) em andamento, a cada quadro de
## fisica amostra os corpos que se movem contra o mundo e as pecas e anota quem atravessa quem, com quadro, missao, par e
## profundidade. Nao substitui o PropOverlap (estatico): usa os corpos de sondagem dele (malha exata de cada prop, das
## pecas das missoes e do cenario fixo, camada PropOverlap.PROBE_LAYER) mais a camada 1 do jogo.
##
## Corpos que se movem (moventes):
##   - personagens: cada CharacterVisual visivel (herois, seguidores, capitao, filhote, NPCs): capsula de CHAR_RADIUS, de
##     CHAR_FOOT acima dos pes ate CHAR_TOP (os pes no chao ficam de fora de proposito);
##   - objeto na mao (`land.carried`), carrinho (`land.cart`), bote (`wv3_dinghy`): casco convexo das malhas;
##   - casco do barco do jogador: a forma Body/Collision do barco v2;
##   - cordas (no `Rope*` das missoes, esticado): segmento entre as pontas, sem ROPE_END_TOL em cada ponta (onde ela esta
##     amarrada ou na mao). Profundidade da corda = trecho do segmento dentro da geometria (entrada ate a saida).
## Contra: camada 1 (colisao do mundo, sem as paredes invisiveis da agua e as rampas: INVISIBLE_PREFIX) e os corpos de
## sondagem do PropOverlap. As sondagens das pecas soltas e das pecas de missao seguem o no a cada quadro (a peca que se
## move nao deixa um fantasma no lugar antigo). As sondagens sao refeitas no inicio de cada missao.
##
## Excecoes (EXCEPTIONS): pares que se tocam de proposito, com a justificativa ao lado. Tudo o mais acima da tolerancia
## do par (TOL) entra no relatorio. Geometrico: nao comprova render.

const CHAR_RADIUS := 0.16
const CHAR_FOOT := 0.15
const CHAR_TOP := 1.0
const ROPE_END_TOL := 0.15
## So os corpos de sondagem (malha exata do que se ve). A camada 1 do jogo repete a mesma geometria (chao, casas, kit)
## e ainda tem paredes invisiveis; contar as duas dava o mesmo par duas vezes.
const MASK := PropOverlap.PROBE_LAYER
## Linha d'agua da baia (m): casco abaixo disto contra o fundo nao aparece.
const WATER_Y := -0.25
## Folhagem macia: personagem e peca entram um pouco na moita ao passar rente (PropOverlap usa a mesma ideia, BUSH_TOL).
const SOFT := ["bush_a", "bush_b", "bush_c", "tree_a", "tree_b", "tree_c"]
const SOFT_TOL := 0.25
## Tolerancia por tipo de movente (m): encostar de leve nao conta.
const TOL := {"char": 0.05, "piece": 0.03, "boat": 0.05, "rope": 0.02}
## Colisores da camada 1 que nao tem malha visivel (o barco encosta nas paredes de agua; rampas de acesso desligadas).
const INVISIBLE_PREFIX := ["WaterLimits", "AccessRamps", "ClimbZone", "Limit", "Bounds"]
## [movente (prefixo), outro (prefixo), justificativa]
const EXCEPTIONS := [
	["char:", "wv3_dinghy", "o capitao sentado no bote"],
	["boat", "fender", "defensa do cais existe para encostar no barco atracado"],
	["boat", "kit:fender", "defensa do cais existe para encostar no barco atracado"],
	["piece:", "char:", "objeto na mao encosta na mao (nao ha sondagem de personagem)"],
	["", "mission:Spot_", "emblema girando no ar e coleta: quem passa por ele o pega"],
]

var main: Ep01V3Main
var po: PropOverlap
var frame: int = 0
## "mission|movente|outro" -> {mission, mover, other, kind, depth, frame, first, frames, at}
var hits: Dictionary = {}
var enabled: bool = true
var _probe_node: Dictionary = {}   # RID do corpo de sondagem -> instance id do no que ele segue
var _probe_name: Dictionary = {}   # RID -> id do PropOverlap
var _probe_xf: Dictionary = {}
var _probe_local: Dictionary = {}  # RID -> transformacao do corpo no espaco do no
var _hulls: Dictionary = {}        # no -> [ConvexPolygonShape3D, Transform3D local]
var _space: PhysicsDirectSpaceState3D
var _pending: bool = true
var _chars: Array[Node] = []
var _last_xf: Dictionary = {}
## Nenhuma sondagem de peca mudou de lugar neste quadro.
var _probes_still: bool = false
var _chars_at: int = 0
## Tempo gasto (us) por parte, para manter a auditoria barata na suite.
var cost: Dictionary = {"collect": 0, "sample": 0}


func _ready() -> void:
	main.mission_started.connect(func(id: StringName) -> void:
		_pending = true
		print("[RB] G24d %s quadro %d pares %d" % [id, frame, hits.size()]))
	process_physics_priority = 1000


func _exit_tree() -> void:
	if po != null:
		po.free_probes()


func _physics_process(_delta: float) -> void:
	if not enabled or main == null or not is_instance_valid(main) or main.world == null:
		return
	frame += 1
	if _pending:
		_pending = false
		var t0 := Time.get_ticks_usec()
		_collect()
		cost["collect"] = int(cost["collect"]) + Time.get_ticks_usec() - t0
		return
	var t1 := Time.get_ticks_usec()
	_sample_all()
	cost["sample"] = int(cost["sample"]) + Time.get_ticks_usec() - t1


func _sample_all() -> void:
	var tf := Time.get_ticks_usec()
	_follow_probes()
	cost["follow"] = int(cost.get("follow", 0)) + Time.get_ticks_usec() - tf
	_space = main.world.get_world_3d().direct_space_state
	var mission := String(main.current.id) if main.current != null else "-"
	if _chars_at <= frame:
		_chars_at = frame + 30
		_chars = main.find_children("*", "CharacterVisual", true, false)
	for v: Object in _chars:
		if not is_instance_valid(v):
			continue
		var cv := v as Node3D
		if cv.is_visible_in_tree():
			_sample_char(mission, cv)
	var land := main.land
	if land != null:
		if is_instance_valid(land.carried) and land.carried.is_visible_in_tree():
			_sample_hull(mission, "piece:" + String(land.carried.name), land.carried, "piece")
		if is_instance_valid(land.cart) and land.cart.is_inside_tree() and land.cart.is_visible_in_tree():
			_sample_hull(mission, "piece:cart", land.cart, "piece")
		var d := main.world.props.get("wv3_dinghy") as Node3D
		if d != null and d.is_visible_in_tree():
			_sample_hull(mission, "boat:dinghy", d, "boat")
		for holder: Node in [land.get("_root"), land.get("_keep")]:
			if holder == null or not is_instance_valid(holder):
				continue
			for n: Node in (holder as Node).get_children():
				if String(n.name).begins_with("Rope") and n is Node3D and (n as Node3D).is_visible_in_tree():
					_sample_rope(mission, n as Node3D)
	if main.boat != null and main.boat.is_visible_in_tree():
		_sample_boat(mission)


# ---------------------------------------------------------------- sondagens

func _collect() -> void:
	if po != null:
		po.free_probes()
	po = PropOverlap.new()
	po.collect(main)
	_probe_node.clear()
	_probe_name.clear()
	_probe_local.clear()
	_probe_xf.clear()
	_last_xf.clear()
	var land := main.land
	for p: Dictionary in po.props:
		var id: String = p["id"]
		var rid: RID = p["body"]
		_probe_name[rid] = id
		var n: Node3D = null
		if id == "boat":
			n = main.boat
		elif id.begins_with("world:"):
			n = main.world.props.get(id.trim_prefix("world:")) as Node3D
		elif id.begins_with("mission:") and land != null:
			var path := NodePath(id.trim_prefix("mission:"))
			for holder: Node in [land.get("_root"), land.get("_keep"), land.get("_after")]:
				if holder != null and is_instance_valid(holder) and (holder as Node).has_node(path):
					n = (holder as Node).get_node(path) as Node3D
					break
		if n != null:
			_probe_node[rid] = n.get_instance_id()
			_probe_local[rid] = n.global_transform.affine_inverse() * (p["xf"] as Transform3D)


func _follow_probes() -> void:
	_probes_still = true
	for rid: RID in _probe_node:
		var n := instance_from_id(_probe_node[rid]) as Node3D
		if n == null or not n.is_inside_tree():
			continue
		var xf := n.global_transform * (_probe_local[rid] as Transform3D)
		if not n.is_visible_in_tree():
			xf.origin.y -= 1000.0
		if _probe_xf.has(rid) and (_probe_xf[rid] as Transform3D).is_equal_approx(xf):
			continue
		_probe_xf[rid] = xf
		_probes_still = false
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, xf)


## Sondagens que pertencem ao proprio movente (o no, um pai ou um filho dele).
func _own(n: Node) -> Array[RID]:
	var out: Array[RID] = []
	for rid: RID in _probe_node:
		var p := instance_from_id(_probe_node[rid]) as Node
		if p == null:
			continue
		if p == n or n.is_ancestor_of(p) or p.is_ancestor_of(n):
			out.append(rid)
	return out


func _name_of(info: Dictionary) -> String:
	var rid: RID = info.get("rid", RID())
	if _probe_name.has(rid):
		return _probe_name[rid]
	var o: Object = info.get("collider")
	if o is Node:
		var n := o as Node
		var s := String(n.name)
		var p := n.get_parent()
		while p != null and p != main.world and p != main:
			s = String(p.name) + "/" + s
			p = p.get_parent()
		return "col:" + s
	return "static"


func _invisible(other: String) -> bool:
	for pre: String in INVISIBLE_PREFIX:
		if other.begins_with("col:" + pre) or other.contains("/" + pre):
			return true
	return false


func _excepted(mover: String, other: String) -> bool:
	for e: Array in EXCEPTIONS:
		var mo: String = e[0]
		var ot: String = e[1]
		var other_kind := other.get_slice(":", 1) if other.begins_with("kit:") or other.begins_with("world:") else other
		if mover.begins_with(mo) and (other.begins_with(ot) or other_kind.begins_with(ot) or other.contains(":" + ot)
				or other.contains("/" + ot)):
			return true
	return false


# ---------------------------------------------------------------- amostras

func _query(shape: Shape3D, xf: Transform3D, exclude: Array[RID]) -> PhysicsShapeQueryParameters3D:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = xf
	q.collision_mask = MASK
	q.exclude = exclude
	return q


## Profundidade contra cada colisor tocado (ate 8), cada um isolado dos outros.
func _shape_hits(mission: String, mover: String, kind: String, shape: Shape3D, xf: Transform3D, exclude: Array[RID]) -> void:
	# parado desde a ultima amostra (e as sondagens nao mudaram): mesma resposta, nao refaz a consulta
	var key := mover
	var last: Variant = _last_xf.get(key)
	if last != null and (last as Transform3D).is_equal_approx(xf) and _probes_still:
		return
	_last_xf[key] = xf
	var t0 := Time.get_ticks_usec()
	_shape_hits_(mission, mover, kind, shape, xf, exclude)
	cost[kind] = int(cost.get(kind, 0)) + Time.get_ticks_usec() - t0


func _shape_hits_(mission: String, mover: String, kind: String, shape: Shape3D, xf: Transform3D, exclude: Array[RID]) -> void:
	var touched := _space.intersect_shape(_query(shape, xf, exclude), 8)
	for t: Dictionary in touched:
		var other := _name_of(t)
		if _invisible(other) or _excepted(mover, other):
			continue
		var ex := exclude.duplicate()
		for u: Dictionary in touched:
			if u["rid"] != t["rid"]:
				ex.append(u["rid"])
		var pts := _space.collide_shape(_query(shape, xf, ex), 16)
		var depth := 0.0
		var at := xf.origin
		for i in range(0, pts.size() - 1, 2):
			var dd := pts[i].distance_to(pts[i + 1])
			if dd > depth:
				depth = dd
				at = pts[i]
		_note(mission, mover, other, kind, depth, at)


func _sample_char(mission: String, cv: Node3D) -> void:
	var root := cv.get_parent() as Node3D
	var up: Node = cv
	while up != null and not (up is MemberActor):
		up = up.get_parent()
	if up != null:
		root = up as Node3D
	if root == null:
		root = cv
	var foot := cv.global_position
	var cap := CapsuleShape3D.new()
	cap.radius = CHAR_RADIUS
	cap.height = CHAR_TOP - CHAR_FOOT
	var xf := Transform3D(Basis(), foot + Vector3(0, CHAR_FOOT + cap.height * 0.5, 0))
	var ex := _own(root)
	if root is MemberActor and (root as MemberActor).collision_layer == 0:
		ex.append_array(_own(main.boat))   # a bordo (ride)
	var nm := String(root.name)
	_shape_hits(mission, "char:" + nm, "char", cap, xf, ex)


func _hull(n: Node3D) -> Array:
	if _hulls.has(n):
		return _hulls[n]
	var pts := PackedVector3Array()
	var base := Transform3D(n.global_basis.orthonormalized(), n.global_position).affine_inverse()
	var meshes: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		meshes.append(n)
	for mi: MeshInstance3D in meshes:
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var xf := base * mi.global_transform
		var f := mi.mesh.get_faces()
		for i in range(0, f.size(), maxi(1, f.size() / 600)):
			pts.append(xf * f[i])
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	var out := [shape, pts.size() >= 4]
	_hulls[n] = out
	return out


func _sample_hull(mission: String, mover: String, n: Node3D, kind: String) -> void:
	var h := _hull(n)
	if not h[1]:
		return
	var xf := Transform3D(n.global_basis.orthonormalized(), n.global_position)
	var ex := _own(n)
	if kind == "boat":
		ex.append_array(_own(main.boat))   # o bote encosta no barco na atracacao e no reboque
	_shape_hits(mission, mover, kind, h[0] as Shape3D, xf, ex)


func _sample_boat(mission: String) -> void:
	# casco = a caixa Body/Collision do barco v2 (a mesma que o jogo usa para a folga)
	var col := main.boat.find_child("Collision", true, false) as CollisionShape3D
	if col == null or col.shape == null:
		return
	var ex := _own(main.boat)
	var d := main.world.props.get("wv3_dinghy") as Node3D
	if d != null:
		ex.append_array(_own(d))
	var n0 := hits.size()
	_shape_hits(mission, "boat", "boat", col.shape, col.global_transform.orthonormalized(), ex)
	if OS.get_environment("RB_G24_TRACE") != "":
		for k: String in hits:
			var h: Dictionary = hits[k]
			if h["kind"] == "boat" and int(h["frame"]) == frame:
				print("[G24TRACE] q%d %s %.2f boat %s h %.2f spd %.2f gap %.2f clr %.2f locked %s" % [frame, h["other"], h["depth"],
					main.boat.global_position, main.boat.heading, main.boat.speed, main.land.boat_gap(main.boat.global_position,
					main.boat.heading), main.land.boat_clearance(main.boat.global_position), main.boat.input_locked])


## Pontas da corda: PropsV3TowRope (origem + `length` em +Z) ou o cilindro provisorio (centro, escala z = comprimento).
static func rope_ends(r: Node3D) -> PackedVector3Array:
	if r.get_meta(&"final_rope", false):
		if r.get("coiled") == true or r.has_meta(&"in_hand"):
			return PackedVector3Array()
		var length := float(r.get("length"))
		return PackedVector3Array([r.global_position, r.global_position + r.global_basis.z.normalized() * length])
	var half := r.global_basis.z.length() * 0.5
	var dir := -r.global_basis.z.normalized()
	return PackedVector3Array([r.global_position - dir * half, r.global_position + dir * half])


## Trecho do segmento a-b (sem as pontas) dentro da geometria: [profundidade, ponto, outro] ou [] se livre.
static func segment_hit(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, mask: int, exclude: Array[RID],
		end_tol: float = ROPE_END_TOL) -> Array:
	var L := a.distance_to(b)
	if L <= end_tol * 2.0 + 0.01:
		return []
	var dir := (b - a) / L
	var p := a + dir * end_tol
	var q := b - dir * end_tol
	var fwd := PhysicsRayQueryParameters3D.create(p, q, mask, exclude)
	var h1 := space.intersect_ray(fwd)
	if h1.is_empty():
		var back := PhysicsRayQueryParameters3D.create(q, p, mask, exclude)
		var h0 := space.intersect_ray(back)
		if h0.is_empty():
			return []
		return [0.05, h0["position"], h0]
	var bk := PhysicsRayQueryParameters3D.create(q, p, mask, exclude)
	var h2 := space.intersect_ray(bk)
	var t1 := a.distance_to(h1["position"] as Vector3)
	var t2 := a.distance_to(h2["position"] as Vector3) if not h2.is_empty() else t1
	return [maxf(t2 - t1, 0.05), h1["position"], h1]


func _sample_rope(mission: String, r: Node3D) -> void:
	var e := rope_ends(r)
	if e.size() < 2:
		return
	var ex := _own(r)
	var h := segment_hit(_space, e[0], e[1], MASK, ex)
	if h.is_empty():
		return
	var other := _name_of(h[2] as Dictionary)
	if _invisible(other):
		# o raio parou numa parede invisivel: tenta de novo sem ela
		var ex2 := ex.duplicate()
		ex2.append((h[2] as Dictionary)["rid"])
		h = segment_hit(_space, e[0], e[1], MASK, ex2)
		if h.is_empty():
			return
		other = _name_of(h[2] as Dictionary)
	_note(mission, "rope:" + String(r.name), other, "rope", float(h[0]), h[1] as Vector3)


func _note(mission: String, mover: String, other: String, kind: String, depth: float, at: Vector3) -> void:
	var tol := float(TOL[kind])
	for k: String in SOFT:
		if other.begins_with("kit:" + k + "#"):
			tol = maxf(tol, SOFT_TOL)
	if depth <= tol:
		return
	# casco contra o fundo da baia, abaixo da linha d'agua (o bote encalhado do M6 e a historia)
	if kind == "boat" and other == "static" and at.y < WATER_Y:
		return
	var key := "%s|%s|%s" % [mission, mover, other]
	var h: Dictionary = hits.get(key, {})
	if h.is_empty():
		h = {"mission": mission, "mover": mover, "other": other, "kind": kind, "depth": 0.0, "frame": frame,
			"first": frame, "frames": 0, "at": at}
		hits[key] = h
	h["frames"] = int(h["frames"]) + 1
	if depth > float(h["depth"]):
		h["depth"] = depth
		h["frame"] = frame
		h["at"] = at


# ---------------------------------------------------------------- relatorio

func rows(kind: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k: String in hits:
		var h: Dictionary = hits[k]
		if kind == "" or h["kind"] == kind:
			out.append(h)
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return x["mission"] < y["mission"] if x["mission"] != y["mission"] else float(x["depth"]) > float(y["depth"]))
	return out


static func line(h: Dictionary) -> String:
	var at: Vector3 = h["at"]
	return "%s q%d (1o q%d, %d q) %s x %s %.0f cm em (%.1f, %.1f, %.1f)" % [h["mission"], h["frame"], h["first"],
		h["frames"], h["mover"], h["other"], float(h["depth"]) * 100.0, at.x, at.y, at.z]


func report() -> String:
	var lines: PackedStringArray = []
	for h in rows():
		lines.append(line(h))
	return "\n".join(lines)
