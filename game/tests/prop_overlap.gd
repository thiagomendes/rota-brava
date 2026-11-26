class_name PropOverlap
extends RefCounted
## RB-R1 G6: auditoria de interpenetracao e de props flutuando na vila v3 COM as pecas das missoes montadas.
## Usado por `tests/prop_overlap_report.gd` (relatorio, `bash tools/prop-overlap.sh`) e por `tests/test_prop_overlap.gd`.
##
## O que entra (cada "prop" e um objeto inteiro; partes do mesmo objeto nunca sao comparadas entre si):
##   - cada instancia do kit do mundo (MultiMesh; transformacao lida do layout, porque a MultiMesh volta vazia no headless);
##   - cada peca solta do mundo (`VillageWorld.props`, wv3_*), o barco do jogador;
##   - cada peca de missao montada pela Land/Late (filhos do `Mission_*` e do `Keep`; um objeto = o no instanciado mais
##     alto abaixo da raiz da missao, ou o filho direto dela). Personagens (StoryFigure/MemberActor), decalques e sprites
##     ficam de fora. So entra o que esta visivel.
##   - O cenario fixo (wv2_static.glb: chao, cais, ruas, casas) NAO e prop: e superficie de apoio, e so as pecas pequenas
##     dele (ate STRUCT_MAX m) entram no teste de interpenetracao; chao, rua e encosta inteiros nao (chao sob objetos).
##
## Interpenetracao (par A-B):
##   1. AABB dos dois se sobrepoe em mais que TOL_PEN em cada eixo;
##   2. teste fino por pecas conexas (`_pair_depth`): menor translacao que separa cada par de pecas (SAT nas normais das
##      faces), confirmada na malha por pontos de uma grade de 1 cm dentro da outra peca (numero de voltas); cesto,
##      carrinho e caixote abertos sao ocos (o que esta dentro deles nao toca as paredes). O par conta se passa de TOL_PEN.
##   O mesmo contra as pecas pequenas do cenario fixo (`structure_hits`: tabua, degrau, meio-fio, toldo).
##   Ignorados de proposito: vegetacao rasteira (IGNORE_KINDS: grama, flores, juncos); copas e arbustos entre si e
##   arbustos contra qualquer coisa (folhagem macia que cobre objetos, ex. lente do M7 meio tapada); rochas entre si;
##   pares montados de proposito (INTENTIONAL_PAIRS: guarda-sol na mesa, cordao de lanternas no poste, defensa no barco).
##
## Flutuando (so props "apoiados"): de cada ponto da faixa de baixo da malha (ate 20% da altura acima do menor y, entre
## 2 e 10 cm) um raio vertical desce contra o cenario fixo e os outros props (corpos de malha exata numa camada de fisica
## propria, PROBE_LAYER); folga = ponto - superficie (negativa se o ponto esta enterrado). O prop flutua se NENHUM ponto
## da faixa tem folga <= TOL_FLOAT (pedra encaixada na encosta com a ponta para fora do barranco nao conta).
## Nao sao apoiados: o que fica na agua (barcos, boias), o que pendura (defensas, roupas no varal, placa da barraca,
## corda) e o que voa de proposito (emblemas girando, seta de ajuda, gaivota em voo).
## Testes nao comprovam render: a lista e geometrica.

const TOL_PEN := 0.02
const TOL_FLOAT := 0.03
## Pecas do cenario fixo maiores que isto (chao, rua, encosta, parede inteira) nao entram em `structure_hits`.
const STRUCT_MAX := 4.0
## Kits que entram no cenario de proposito: cabeco de amarracao e poste chumbados no chao (o cordao de bandeirolas do
## cenario e amarrado no topo do poste); barraca da praca com o mastro da placa redonda encaixado no topo do telhado.
const STRUCT_SKIP_KINDS := ["bollard", "lamp_post", "stall_red", "stall_yellow", "stall_blue"]
## Camada de fisica 32 so para os corpos de sondagem (nada do jogo usa).
const PROBE_LAYER := 1 << 31
const IGNORE_KINDS := ["grass_tuft", "grass_tall", "flowers_a", "flowers_b", "reeds"]
const FOLIAGE := ["bush_a", "bush_b", "bush_c", "tree_a", "tree_b", "tree_c"]
const BUSHES := ["bush_a", "bush_b", "bush_c"]
const ROCKS := ["rock_a", "rock_b"]
## guarda-sol no furo da mesa; cordao das lanternas da festa amarrado no topo do poste; defensa do cais encostada no barco
## atracado (e para isso que ela existe).
const INTENTIONAL_PAIRS := [["cafe_set", "parasol"], ["lamp_post", "wv3_festa_lanterns"], ["fender", "Boat"]]
## Kits que nao estao apoiados no chao (agua, pendurados).
const NOT_RESTING_KINDS := ["rowboat_a", "rowboat_b", "fender", "float_buoy", "life_ring"]
## Pecas soltas do mundo/missao que nao estao apoiadas (prefixo do nome).
const NOT_RESTING_PREFIX := ["wv3_buoy", "wv3_festa", "wv3_lantern", "wv3_lens", "wv3_dinghy", "Boat", "Coin", "HelpArrow",
	"Cloth", "Rope", "Sign_", "Fish"]

var props: Array[Dictionary] = []
## Pecas do cenario fixo (cada peca conexa com AABB ate STRUCT_MAX m: tabua, toldo, mureta, degrau), no mundo.
var structure: Array[Dictionary] = []
static var _structure_cache: Array[Dictionary] = []
var _bodies: Array[RID] = []
var _space: RID
var _kit_cache: Dictionary = {}
## Partes soltas por tipo de kit (a malha do tipo nao muda entre missoes).
static var _loose_cache: Dictionary = {}


## Monta a lista de props da cena `main` (Ep01V3Main ja pronta). Cria os corpos de sondagem no espaco do mundo; chame
## `free_probes()` no fim. Depois de chamar, espere 2 quadros de fisica antes de `floating()`.
func collect(main: Node) -> void:
	props.clear()
	var world: VillageWorld = main.get("world")
	var land: Node = main.get("land")
	_space = world.get_world_3d().space
	var hidden_cart := -1
	if land != null and is_instance_valid(land.get("cart")) and (land.get("cart") as Node3D).is_inside_tree():
		hidden_cart = Ep01V3Land.CART_KIT_INDEX
	# Kit (MultiMesh): transformacao do layout, malha da MultiMesh.
	var kit: Dictionary = world.layout.get("kit", {})
	for kind: String in kit:
		if kind in IGNORE_KINDS:
			continue
		var mmi := world.get_node_or_null("Kit/" + kind) as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null or mmi.multimesh.mesh == null or not mmi.is_visible_in_tree():
			continue
		var geo := _kit_geo(kind, mmi.multimesh.mesh)
		var rows: Array = kit[kind]
		for i in rows.size():
			if kind == "cart" and i == hidden_cart:
				continue
			var r: Array = rows[i]
			var b := Basis(Vector3.UP, deg_to_rad(float(r[3]))).scaled(Vector3.ONE * float(r[4]))
			_add("kit:%s#%d" % [kind, i], kind, Transform3D(b, Vector3(float(r[0]), float(r[1]), float(r[2]))), geo,
				not kind in NOT_RESTING_KINDS)
	# Pecas soltas do mundo.
	for k: String in world.props:
		var n := world.props[k] as Node3D
		if n == null or not n.is_visible_in_tree() or _has_prop_ancestor(n, world.props):
			continue
		_add_node("world:" + k, k, n)
	if main.get("boat") is Node3D and (main.get("boat") as Node3D).is_visible_in_tree():
		_add_node("boat", "Boat", main.get("boat") as Node3D)
	# Pecas das missoes.
	if land != null:
		for holder: Node in [land.get("_root"), land.get("_keep")]:
			if holder == null or not is_instance_valid(holder):
				continue
			# Cada malha vai para UM objeto (o caixote dentro do carrinho e outro objeto, nao parte do carrinho).
			var groups: Dictionary = {}
			for mi: Node in (holder as Node).find_children("*", "MeshInstance3D", true, false):
				if not (mi as MeshInstance3D).is_visible_in_tree() or (mi as MeshInstance3D).mesh == null or _is_actor(mi, holder):
					continue
				var top := _piece_root(mi, holder)
				if not groups.has(top):
					groups[top] = []
				(groups[top] as Array).append(mi)
			for top: Node3D in groups:
				_add_node("mission:" + String(holder.get_path_to(top)), String(top.name), top, groups[top])
	# Cenario fixo: superficie de apoio (corpo de sondagem) e pecas pequenas fechadas para `structure_hits`.
	var st := world.get_node_or_null("Static")
	if st != null:
		var build_parts := _structure_cache.is_empty()
		for mi: Node in st.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.mesh == null or not m.is_visible_in_tree():
				continue
			var faces := m.mesh.get_faces()
			_body(faces, m.global_transform)
			if build_parts:
				_static_parts(String(m.name), faces, m.global_transform)
	structure = _structure_cache


func _static_parts(mesh_name: String, faces: PackedVector3Array, xf: Transform3D) -> void:
	var wf := PackedVector3Array()
	wf.resize(faces.size())
	for i in faces.size():
		wf[i] = xf * faces[i]
	var cs := _components(wf)
	var parts: Array[PackedVector3Array] = cs["parts"]
	var boxes: Array[AABB] = cs["boxes"]
	for k in parts.size():
		var b: AABB = boxes[k]
		if maxf(b.size.x, maxf(b.size.y, b.size.z)) > STRUCT_MAX:
			continue
		var pk: Array[PackedVector3Array] = [parts[k]]
		var bk: Array[AABB] = [b]
		_structure_cache.append({"id": "static:%s#%d" % [mesh_name, k], "kind": "static", "xf": Transform3D.IDENTITY,
			"inv": Transform3D.IDENTITY, "aabb": b, "geo": {"faces": parts[k], "aabb": b, "comps": {"parts": pk, "boxes": bk}}})


## Props que atravessam pecas do cenario fixo (tabua, toldo, mureta...) alem de TOL_PEN: [{a, b, depth, points, at}].
## Fora: folhagem, rochas e o que nao esta apoiado (barco, defensa, boias: encostam no cais de proposito).
func structure_hits(only_ids: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a in props:
		if (not only_ids.is_empty() and not a["id"] in only_ids) or not a["rests"] or a["kind"] in FOLIAGE or a["kind"] in ROCKS \
				or a["kind"] in STRUCT_SKIP_KINDS:
			continue
		for b in structure:
			if not _aabb_overlap(a["aabb"], b["aabb"]):
				continue
			var pd := _pair_depth(a, b)
			if pd["depth"] > TOL_PEN:
				out.append({"a": a["id"], "b": b["id"], "depth": pd["depth"], "points": pd["count"], "at": pd["at"]})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["depth"] > y["depth"])
	return out


func free_probes() -> void:
	for b in _bodies:
		PhysicsServer3D.free_rid(b)
	_bodies.clear()


# ---------------------------------------------------------------- coleta

func _kit_geo(kind: String, mesh: Mesh) -> Dictionary:
	if not _kit_cache.has(kind):
		_kit_cache[kind] = _geo_from_faces(mesh.get_faces())
	return _kit_cache[kind]


func _has_prop_ancestor(n: Node, all: Dictionary) -> bool:
	var p := n.get_parent()
	while p != null:
		if all.has(String(p.name)) and all[String(p.name)] == p:
			return true
		p = p.get_parent()
	return false


func _is_actor(n: Node, stop: Node) -> bool:
	var p := n
	while p != null and p != stop:
		if p is MemberActor or p is CharacterVisual:
			return true
		p = p.get_parent()
	return false


## No instanciado mais alto abaixo de `holder` (um caixote com modelo dentro = o caixote); senao o filho direto de holder.
func _piece_root(n: Node, holder: Node) -> Node3D:
	var best: Node3D = null
	var p := n
	var direct: Node3D = null
	while p != null and p != holder:
		if p.scene_file_path != "" and p is Node3D:
			best = p as Node3D
		if p.get_parent() == holder:
			direct = p as Node3D
		p = p.get_parent()
	return best if best != null else direct


## Prop a partir de uma arvore de nos: malhas visiveis juntadas no espaco local da raiz.
func _add_node(id: String, kind: String, n: Node3D, only: Array = []) -> void:
	var faces := PackedVector3Array()
	var inv := n.global_transform.affine_inverse()
	var meshes: Array = only
	if meshes.is_empty():
		meshes = n.find_children("*", "MeshInstance3D", true, false)
		if n is MeshInstance3D:
			meshes.append(n)
	for mi: MeshInstance3D in meshes:
		if mi.mesh == null or not mi.is_visible_in_tree() or _is_actor(mi, n):
			continue
		var xf := inv * mi.global_transform
		var f := mi.mesh.get_faces()
		for i in f.size():
			faces.append(xf * f[i])
	if faces.is_empty():
		return
	var rests := true
	for pre: String in NOT_RESTING_PREFIX:
		if kind.begins_with(pre):
			rests = false
	_add(id, kind, n.global_transform, _geo_from_faces(faces), rests)


func _geo_from_faces(faces: PackedVector3Array) -> Dictionary:
	var pts := {}
	for v in faces:
		pts[v.snapped(Vector3.ONE * 0.001)] = true
	for i in range(0, faces.size(), 3):
		pts[((faces[i] + faces[i + 1] + faces[i + 2]) / 3.0).snapped(Vector3.ONE * 0.001)] = true
	var aabb := AABB(faces[0], Vector3.ZERO)
	for v in faces:
		aabb = aabb.expand(v)
	return {"faces": faces, "points": PackedVector3Array(pts.keys()), "aabb": aabb}


func _add(id: String, kind: String, xf: Transform3D, geo: Dictionary, rests: bool) -> void:
	var waabb: AABB = xf * (geo["aabb"] as AABB)
	var body := _body(geo["faces"], xf)
	props.append({"id": id, "kind": kind, "xf": xf, "inv": xf.affine_inverse(), "geo": geo, "aabb": waabb,
		"rests": rests, "body": body})


func _body(faces: PackedVector3Array, xf: Transform3D) -> RID:
	var shape := PhysicsServer3D.concave_polygon_shape_create()
	PhysicsServer3D.shape_set_data(shape, {"faces": faces, "backface_collision": false})
	var body := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_add_shape(body, shape)
	PhysicsServer3D.body_set_collision_layer(body, PROBE_LAYER)
	PhysicsServer3D.body_set_collision_mask(body, 0)
	PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
	PhysicsServer3D.body_set_space(body, _space)
	_bodies.append(body)
	_bodies.append(shape)
	return body


# ---------------------------------------------------------------- interpenetracao

func _skip_pair(a: Dictionary, b: Dictionary) -> bool:
	var ka: String = a["kind"]
	var kb: String = b["kind"]
	if ka in BUSHES or kb in BUSHES:
		return true
	if ka in FOLIAGE and kb in FOLIAGE:
		return true
	if ka in ROCKS and kb in ROCKS:
		return true
	for pair: Array in INTENTIONAL_PAIRS:
		if (ka == pair[0] and kb == pair[1]) or (ka == pair[1] and kb == pair[0]):
			return true
	return false


## Pares que se interpenetram alem de TOL_PEN: [{a, b, depth, points, at}] ordenado por profundidade.
## `skip_kit_pairs`: nao refaz kit x kit (igual em todas as missoes; o relatorio faz so na primeira).
func overlaps(only_ids: Array = [], skip_kit_pairs: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var n := props.size()
	for i in n:
		var a := props[i]
		for j in range(i + 1, n):
			var b := props[j]
			if not only_ids.is_empty() and not (a["id"] in only_ids or b["id"] in only_ids):
				continue
			if skip_kit_pairs and (a["id"] as String).begins_with("kit:") and (b["id"] as String).begins_with("kit:"):
				continue
			if not _aabb_overlap(a["aabb"], b["aabb"]) or _skip_pair(a, b):
				continue
			var pd := _pair_depth(a, b)
			if pd["depth"] > TOL_PEN:
				out.append({"a": a["id"], "b": b["id"], "depth": pd["depth"], "points": pd["count"], "at": pd["at"]})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["depth"] > y["depth"])
	return out


func _aabb_overlap(a: AABB, b: AABB) -> bool:
	var lo := a.position.max(b.position)
	var hi := a.end.min(b.end)
	return hi.x - lo.x > TOL_PEN and hi.y - lo.y > TOL_PEN and hi.z - lo.z > TOL_PEN


## Profundidade do par A-B: para cada par de pecas conexas (uma de A, uma de B) com AABB sobreposto, a menor translacao
## que as separa (eixos separadores: normais das faces das duas pecas + X, Y, Z; projecao dos vertices = casco convexo da
## peca). So conta se a interpenetracao e real na malha: algum ponto de uma grade de 1 cm sobre uma peca, dentro da regiao
## comum, cai dentro da outra (numero de voltas). Assim duas tabuas finas que se cruzam (parede de caixote atravessando
## outra) dao a sobreposicao inteira, e um caixote apoiado 3 mm afundado da 3 mm.
func _pair_depth(a: Dictionary, b: Dictionary) -> Dictionary:
	var sa := _sat(a["geo"])
	var sb := _sat(b["geo"])
	var to_a: Transform3D = (a["inv"] as Transform3D) * (b["xf"] as Transform3D)
	var sc := (a["xf"] as Transform3D).basis.get_scale().x
	var tol := TOL_PEN / sc
	var box_a: AABB = a["geo"]["aabb"]
	var best := 0.0
	var count := 0
	var at := Vector3.ZERO
	var a_boxes: Array[AABB] = sa["boxes"]
	for j in (sb["boxes"] as Array).size():
		var bb: AABB = to_a * (sb["boxes"][j] as AABB)
		if not _aabb_overlap_tol(bb, box_a, tol):
			continue
		var vb := PackedVector3Array()
		for v in (sb["verts"][j] as PackedVector3Array):
			vb.append(to_a * v)
		var nb := PackedVector3Array()
		for nrm in (sb["normals"][j] as PackedVector3Array):
			nb.append((to_a.basis * nrm).normalized())
		var fb := PackedVector3Array()
		for i in a_boxes.size():
			if not _aabb_overlap_tol(a_boxes[i], bb, tol):
				continue
			var mtd := _sat_mtd(sa["verts"][i], sa["normals"][i], vb, nb)
			if mtd <= tol:
				continue
			if fb.is_empty():
				for v in (sb["faces"][j] as PackedVector3Array):
					fb.append(to_a * v)
			var region := a_boxes[i].intersection(bb)
			if not (_any_inside(sa["faces"][i], region, fb) or _any_inside(fb, region, sa["faces"][i])):
				continue
			count += 1
			if mtd * sc > best:
				best = mtd * sc
				at = (a["xf"] as Transform3D) * region.get_center()
	return {"depth": best, "count": count, "at": at}


func _aabb_overlap_tol(a: AABB, b: AABB, tol: float) -> bool:
	var lo := a.position.max(b.position)
	var hi := a.end.min(b.end)
	return hi.x - lo.x > tol and hi.y - lo.y > tol and hi.z - lo.z > tol


## Pecas conexas com vertices, normais (ate 24 direcoes) e faces, em espaco local; guardado na geometria.
func _sat(geo: Dictionary) -> Dictionary:
	if geo.has("sat"):
		return geo["sat"]
	if not geo.has("comps"):
		geo["comps"] = _components(geo["faces"])
	var verts: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	var faces: Array[PackedVector3Array] = geo["comps"]["parts"]
	for f in faces:
		var vs := {}
		var ns := {}
		for i in range(0, f.size(), 3):
			vs[f[i].snapped(Vector3.ONE * 0.0005)] = true
			vs[f[i + 1].snapped(Vector3.ONE * 0.0005)] = true
			vs[f[i + 2].snapped(Vector3.ONE * 0.0005)] = true
			var nrm := (f[i + 1] - f[i]).cross(f[i + 2] - f[i])
			if nrm.length_squared() < 1e-12:
				continue
			nrm = nrm.normalized()
			if nrm.x < -1e-6 or (absf(nrm.x) <= 1e-6 and (nrm.y < -1e-6 or (absf(nrm.y) <= 1e-6 and nrm.z < 0.0))):
				nrm = -nrm
			ns[nrm.snapped(Vector3.ONE * 0.02)] = nrm
		var nl: Array = ns.values()
		var keep := PackedVector3Array()
		var step := maxf(1.0, nl.size() / 24.0)
		var k := 0.0
		while int(k) < nl.size():
			keep.append(nl[int(k)])
			k += step
		verts.append(PackedVector3Array(vs.keys()))
		normals.append(keep)
	geo["sat"] = {"verts": verts, "normals": normals, "faces": faces, "boxes": geo["comps"]["boxes"]}
	return geo["sat"]


static func _sat_mtd(va: PackedVector3Array, na: PackedVector3Array, vb: PackedVector3Array, nb: PackedVector3Array) -> float:
	var best := INF
	for axes: PackedVector3Array in [na, nb, PackedVector3Array([Vector3.RIGHT, Vector3.UP, Vector3.BACK])]:
		for ax in axes:
			var amin := INF
			var amax := -INF
			for v in va:
				var d := v.dot(ax)
				amin = minf(amin, d)
				amax = maxf(amax, d)
			var bmin := INF
			var bmax := -INF
			for v in vb:
				var d := v.dot(ax)
				bmin = minf(bmin, d)
				bmax = maxf(bmax, d)
			var ov := minf(amax - bmin, bmax - amin)
			if ov <= 0.0:
				return 0.0
			best = minf(best, ov)
	return best


## Algum ponto (grade de ~1 cm) dos triangulos `f` dentro de `region` cai dentro da malha `g`?
static func _any_inside(f: PackedVector3Array, region: AABB, g: PackedVector3Array) -> bool:
	for i in range(0, f.size(), 3):
		var p0 := f[i]
		var p1 := f[i + 1]
		var p2 := f[i + 2]
		if not AABB(p0, Vector3.ZERO).expand(p1).expand(p2).intersects(region):
			continue
		var steps := clampi(int(ceil(maxf(p0.distance_to(p1), maxf(p1.distance_to(p2), p2.distance_to(p0))) / 0.01)), 1, 40)
		for s in steps + 1:
			for t in steps + 1 - s:
				var v := p0 + (p1 - p0) * (float(s) / steps) + (p2 - p0) * (float(t) / steps)
				if region.has_point(v) and _winding(v, g) >= 0.5:
					return true
	return false


## Pecas conexas da malha (triangulos que dividem vertice) com o AABB de cada uma.
static func _components(faces: PackedVector3Array) -> Dictionary:
	var nt := faces.size() / 3
	var parent := PackedInt32Array()
	parent.resize(nt)
	for t in nt:
		parent[t] = t
	var owner := {}
	for t in nt:
		for k in 3:
			var key := faces[t * 3 + k].snapped(Vector3.ONE * 0.0001)
			if owner.has(key):
				_union(parent, t, owner[key])
			else:
				owner[key] = t
	var comps := {}
	for t in nt:
		var r := _find(parent, t)
		if not comps.has(r):
			comps[r] = PackedVector3Array()
		var arr: PackedVector3Array = comps[r]
		arr.append(faces[t * 3])
		arr.append(faces[t * 3 + 1])
		arr.append(faces[t * 3 + 2])
		comps[r] = arr
	var parts: Array[PackedVector3Array] = []
	var boxes: Array[AABB] = []
	for r: int in comps:
		var f: PackedVector3Array = comps[r]
		parts.append(f)
		var b := AABB(f[0], Vector3.ZERO)
		for v in f:
			b = b.expand(v)
		boxes.append(b)
	return {"parts": parts, "boxes": boxes}


static func _winding(p: Vector3, f: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(0, f.size(), 3):
		var a := f[i] - p
		var b := f[i + 1] - p
		var c := f[i + 2] - p
		var la := a.length()
		var lb := b.length()
		var lc := c.length()
		var num := a.dot(b.cross(c))
		var den := la * lb * lc + a.dot(b) * lc + a.dot(c) * lb + b.dot(c) * la
		total += 2.0 * atan2(num, den)
	return absf(total) / (4.0 * PI)


static func _dist2_to_mesh(p: Vector3, f: PackedVector3Array) -> float:
	var best := INF
	for i in range(0, f.size(), 3):
		var d := p.distance_squared_to(_closest_on_tri(p, f[i], f[i + 1], f[i + 2]))
		if d < best:
			best = d
	return best


## Ponto mais proximo de p no triangulo abc (Ericson, Real-Time Collision Detection 5.1.5).
static func _closest_on_tri(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var denom := 1.0 / (va + vb + vc)
	return a + ab * (vb * denom) + ac * (vc * denom)


# ---------------------------------------------------------------- flutuando

## Props apoiados cuja base fica mais de TOL_FLOAT acima da superficie de baixo: [{id, gap, at}].
func floating(space_state: PhysicsDirectSpaceState3D, only_ids: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in props:
		if not p["rests"] or (not only_ids.is_empty() and not p["id"] in only_ids):
			continue
		var xf: Transform3D = p["xf"]
		var base := INF
		var world_pts: Array[Vector3] = []
		for v in (p["geo"]["points"] as PackedVector3Array):
			var w := xf * v
			world_pts.append(w)
			base = minf(base, w.y)
		var band := clampf((p["aabb"] as AABB).size.y * 0.2, 0.02, 0.10)
		var best := INF
		var best_at := Vector3.ZERO
		for w in world_pts:
			if w.y > base + band:
				continue
			var q := PhysicsRayQueryParameters3D.create(w + Vector3(0, 0.25, 0), w + Vector3(0, -1.5, 0), PROBE_LAYER, [p["body"]])
			var hit := space_state.intersect_ray(q)
			var gap := 1.5 if hit.is_empty() else w.y - (hit["position"] as Vector3).y
			if gap < best:
				best = gap
				best_at = w
		if best > TOL_FLOAT:
			out.append({"id": p["id"], "gap": best, "at": best_at})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["gap"] > y["gap"])
	return out


# ---------------------------------------------------------------- partes soltas dentro de um modelo

## Partes soltas DENTRO de um mesmo modelo (ex.: fruta no ar sobre o fundo do carrinho): o modelo e partido em pecas
## conexas (triangulos que dividem vertice); pecas que se tocam (vertice a <= TOL_TOUCH da outra ou dentro dela) ficam
## ligadas; o que nao se liga, por nenhuma cadeia, a uma peca da base do modelo (ate TOL_FLOAT do menor y) esta solto.
## So conta a parte cuja folga ate a peca de baixo do proprio modelo passa de TOL_FLOAT (ou sem nada embaixo). Folhagem e
## rochas ficam de fora. Uma vez por tipo de kit e por peca de missao/mundo apoiada. Devolve [{id, parts, at (mundo), gap}].
const TOL_TOUCH := 0.01


func loose_parts(only_ids: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var done_kinds := {}
	for p in props:
		if not p["rests"] or (not only_ids.is_empty() and not p["id"] in only_ids) or p["kind"] in FOLIAGE or p["kind"] in ROCKS:
			continue
		var is_kit := (p["id"] as String).begins_with("kit:")
		var key: String = p["kind"] if is_kit else p["id"]
		if done_kinds.has(key):
			continue
		done_kinds[key] = true
		var loose: Array[Dictionary] = []
		if is_kit and not _loose_cache.has(key):
			_loose_cache[key] = _loose_in(p["geo"]["faces"])
		for l: Dictionary in (_loose_cache[key] if is_kit else _loose_in(p["geo"]["faces"])):
			if l["gap"] > TOL_FLOAT:
				loose.append(l)
		if loose.is_empty():
			continue
		var worst: Dictionary = loose[0]
		for l: Dictionary in loose:
			if l["gap"] > worst["gap"]:
				worst = l
		out.append({"id": ("kit-tipo:" + key) if is_kit else key, "parts": loose.size(), "gap": worst["gap"],
			"at": (p["xf"] as Transform3D) * (worst["center"] as Vector3)})
	return out


static func _loose_in(faces: PackedVector3Array) -> Array[Dictionary]:
	var cs := _components(faces)
	var parts: Array[PackedVector3Array] = cs["parts"]
	var boxes: Array[AABB] = cs["boxes"]
	var base := INF
	for b in boxes:
		base = minf(base, b.position.y)
	var n := parts.size()
	if n < 2:
		return []
	var linked: Array[Array] = []
	for i in n:
		linked.append([])
	for i in n:
		for j in range(i + 1, n):
			if not boxes[i].grow(TOL_TOUCH).intersects(boxes[j]):
				continue
			if _touch(parts[i], boxes[j], parts[j]) or _touch(parts[j], boxes[i], parts[i]):
				linked[i].append(j)
				linked[j].append(i)
	var reached := {}
	var queue: Array[int] = []
	for i in n:
		if boxes[i].position.y <= base + TOL_FLOAT:
			reached[i] = true
			queue.append(i)
	while not queue.is_empty():
		var c: int = queue.pop_back()
		for j: int in linked[c]:
			if not reached.has(j):
				reached[j] = true
				queue.append(j)
	var out: Array[Dictionary] = []
	for i in n:
		if reached.has(i):
			continue
		# folga: do ponto mais baixo da parte ate a peca de baixo (raio vertical nas outras partes do modelo)
		var low := boxes[i].position
		var center := boxes[i].get_center()
		var gap := _drop(Vector3(center.x, low.y, center.z), parts, i)
		out.append({"center": center, "gap": gap})
	return out


## A toca B? Pontos de A (vertices e uma grade de ~2 cm sobre cada triangulo que entra no AABB de B, para pegar contato
## face com face, como assento sobre a perna do banco) a <= TOL_TOUCH da malha de B ou dentro dela.
static func _touch(a: PackedVector3Array, bbox: AABB, b: PackedVector3Array) -> bool:
	var g := bbox.grow(TOL_TOUCH)
	for i in range(0, a.size(), 3):
		var p0 := a[i]
		var p1 := a[i + 1]
		var p2 := a[i + 2]
		var tb := AABB(p0, Vector3.ZERO).expand(p1).expand(p2)
		if not tb.intersects(g):
			continue
		var steps := clampi(int(ceil(maxf(p0.distance_to(p1), maxf(p1.distance_to(p2), p2.distance_to(p0))) / 0.02)), 1, 24)
		for s in steps + 1:
			for t in steps + 1 - s:
				var v := p0 + (p1 - p0) * (float(s) / steps) + (p2 - p0) * (float(t) / steps)
				if not g.has_point(v):
					continue
				if _dist2_to_mesh(v, b) <= TOL_TOUCH * TOL_TOUCH or _winding(v, b) >= 0.5:
					return true
	return false


## Distancia vertical de p ate o triangulo mais alto abaixo dele nas outras partes (INF se nada).
static func _drop(p: Vector3, parts: Array[PackedVector3Array], skip: int) -> float:
	var best := INF
	for k in parts.size():
		if k == skip:
			continue
		var f := parts[k]
		for i in range(0, f.size(), 3):
			var hit: Variant = Geometry3D.ray_intersects_triangle(p + Vector3(0, 0.001, 0), Vector3.DOWN, f[i], f[i + 1], f[i + 2])
			if hit != null:
				best = minf(best, p.y - (hit as Vector3).y)
	return best


static func _find(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


static func _union(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra := _find(parent, a)
	var rb := _find(parent, b)
	if ra != rb:
		parent[ra] = rb


func ids_with_prefix(prefix: String) -> Array:
	var out := []
	for p in props:
		if (p["id"] as String).begins_with(prefix):
			out.append(p["id"])
	return out
