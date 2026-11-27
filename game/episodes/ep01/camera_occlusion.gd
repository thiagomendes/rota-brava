class_name CameraOcclusion
extends RefCounted
## RB-R1 G24a2 v2: duas classes de obstaculo para a camera.
##  - ESTRUTURA (predios, terreno, cais, muros): continua na mascara da camera (mola de braco do CameraRig, G6).
##  - PECA (caixotes, carrinho, toldos, barracas, barris, vasos, bancos, arvores): sai da camera (`piece_bodies`) e,
##    quando fica entre a camera e o heroi ou contem a camera, fica pontilhada (variante por malha, fade FADE_TIME s;
##    com movimento reduzido so liga e desliga).
## Separacao data-driven, sem tocar em .blend nem GLB: os tipos do `kit` do layout (PIECE_SKIP fora) sao pecas, o corpo
## `Collision/Props` (colisao gerada do kit) sai da camera, e as formas de `Collision/Structures` em PIECE_SHAPES vao
## para um corpo proprio (`Collision/CameraPieces`, mesma camada) que tambem sai da camera.
## Troca: instancia do MultiMesh do kit some (escala ~0) e um MeshInstance3D com a malha pontilhada entra no lugar;
## peca dentro de malha estatica (toldo do galpao) troca os materiais dessa malha. Parametros do pontilhado por
## instancia. Mede: trocas no quadro, pecas trocadas agora e CPU da atualizacao (us).

const PIECE_SKIP: Array[String] = ["grass_tall", "grass_tuft", "flowers_a", "flowers_b"]
const PIECE_SHAPES: Array[String] = ["NetShedAwning", "NetShedFishTable", "TreeBench", "FlowerBedN", "FlowerBedS"]
const FADE_TIME := 0.15
const RADIUS := 0.7          ## raio do cone no heroi (metade na camera), como no shader
const CENTER_Y := 0.6        ## centro do heroi acima dos pes
const NEAR := 0.9            ## esfera em volta da camera: peca que contem a camera some em volta dela
const RAYS: Array[float] = [0.2, 0.6, 1.0]   ## pe, centro e cabeca do heroi
const GROW := 0.05           ## folga da caixa da peca no teste do segmento
const NEAR_BOX := 0.2        ## camera a menos disto da caixa da peca conta como "dentro" (a lente nao corta a peca)
const KEEP := 0.25           ## histerese: peca ja trocada fica ate sair desta folga
const CELL := 4.0
const HIDDEN_SCALE := 0.01   ## instancia do kit com escala menor que isto ja esta escondida (missao, grama)

## peca: {box: AABB, mmi: MultiMeshInstance3D, i: int} (kit) ou {box: AABB, mesh: GeometryInstance3D} (estatica)
var _pieces: Array[Dictionary] = []
var _grid: Dictionary = {}       ## Vector2i -> PackedInt32Array de indices de peca
var _stamp: PackedInt32Array = []
var _frame := 0
## indice de peca -> {amount: float, want: float, proxy: MeshInstance3D, xf: Transform3D, orig: Array}
var _active: Dictionary = {}
var swaps_frame := 0
var swapped_now := 0
var usec_frame := 0
var warm_count := 0


## Corpos de peca que saem da mascara da camera (cria `Collision/CameraPieces` com as formas de PIECE_SHAPES).
static func piece_bodies(world: Node) -> Array[RID]:
	var out: Array[RID] = []
	var props := world.get_node_or_null("Collision/Props") as CollisionObject3D
	if props != null:
		out.append(props.get_rid())
	var st := world.get_node_or_null("Collision/Structures") as StaticBody3D
	if st == null:
		return out
	var body := world.get_node_or_null("Collision/CameraPieces") as StaticBody3D
	if body == null:
		body = StaticBody3D.new()
		body.name = "CameraPieces"
		body.collision_layer = st.collision_layer
		body.collision_mask = st.collision_mask
		st.get_parent().add_child(body)
		body.global_transform = st.global_transform
		for n: String in PIECE_SHAPES:
			var cs := st.get_node_or_null(n) as CollisionShape3D
			if cs != null:
				cs.reparent(body, true)
	out.append(body.get_rid())
	return out


func _init(world: Node3D) -> void:
	# Transformacao de cada instancia pelo layout (a mesma conta do VillageWorld._build_kit): ler o MultiMesh de volta
	# depende do servidor de render (no modo headless volta identidade).
	var layout: Dictionary = world.get("layout") if world.get("layout") is Dictionary else {}
	var kit_rows: Dictionary = layout.get("kit", {})
	var kit := world.get_node_or_null("Kit")
	if kit != null:
		for n in kit.get_children():
			var mmi := n as MultiMeshInstance3D
			if mmi == null or String(mmi.name) in PIECE_SKIP or mmi.multimesh == null or mmi.multimesh.mesh == null:
				continue
			var mm := mmi.multimesh
			var local := mm.mesh.get_aabb()
			var rows: Array = kit_rows.get(String(mmi.name), [])
			WV2Materials.occl_mesh(mm.mesh)
			for i in mini(mm.instance_count, rows.size()):
				var r: Array = rows[i]
				var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(float(r[3]))).scaled(Vector3.ONE * float(r[4])),
					Vector3(float(r[0]), float(r[1]), float(r[2])))
				_pieces.append({box = mmi.global_transform * xf * local, mmi = mmi, i = i, xf = xf})
	# A caixa da peca do kit cobre tambem a colisao gerada dela (`Collision/Props/<tipo>_<i>[_<j>]`): o que a vista
	# bate na colisao fica dentro da caixa que pontilha.
	var by_name: Dictionary = {}
	for i in _pieces.size():
		by_name["%s_%d" % [(_pieces[i]["mmi"] as Node).name, int(_pieces[i]["i"])]] = i
	var props_body := world.get_node_or_null("Collision/Props")
	if props_body != null:
		for c in props_body.get_children():
			var cs := c as CollisionShape3D
			if cs == null or cs.shape == null:
				continue
			var key := String(cs.name)
			if not by_name.has(key):
				key = key.substr(0, key.rfind("_"))
			if not by_name.has(key):
				continue
			var idx: int = by_name[key]
			_pieces[idx]["box"] = (_pieces[idx]["box"] as AABB).merge(cs.global_transform * cs.shape.get_debug_mesh().get_aabb())
	var statics: Array[GeometryInstance3D] = []
	var st_root := world.get_node_or_null("Static")
	if st_root != null:
		for g in st_root.find_children("*", "GeometryInstance3D", true, false):
			statics.append(g as GeometryInstance3D)
	var body := world.get_node_or_null("Collision/CameraPieces")
	for n: String in PIECE_SHAPES:
		var cs: CollisionShape3D = null
		if body != null:
			cs = body.get_node_or_null(n) as CollisionShape3D
		if cs == null:
			cs = world.get_node_or_null("Collision/Structures/" + n) as CollisionShape3D
		if cs == null or cs.shape == null:
			continue
		var box := cs.global_transform * cs.shape.get_debug_mesh().get_aabb()
		var best: GeometryInstance3D = null
		var best_vol := INF
		for g in statics:
			var gb := g.global_transform * g.get_aabb()
			if gb.has_point(box.get_center()) and gb.get_volume() < best_vol:
				best = g
				best_vol = gb.get_volume()
		if best == null:
			continue
		_variants_of(best)
		_pieces.append({box = box, mesh = best})
	for i in _pieces.size():
		_index(i)
	_stamp.resize(_pieces.size())


func _index(idx: int) -> void:
	var b: AABB = _pieces[idx]["box"]
	for x in range(floori(b.position.x / CELL), floori(b.end.x / CELL) + 1):
		for z in range(floori(b.position.z / CELL), floori(b.end.z / CELL) + 1):
			var k := Vector2i(x, z)
			var cell: PackedInt32Array = _grid.get(k, PackedInt32Array())
			cell.append(idx)  # PackedInt32Array e copiado por valor: grava de volta
			_grid[k] = cell


func _variants_of(g: GeometryInstance3D) -> void:
	var mi := g as MeshInstance3D
	if mi == null or mi.mesh == null:
		return
	for s in mi.mesh.get_surface_count():
		var m := mi.get_surface_override_material(s)
		WV2Materials.occl_variant(m if m != null else mi.mesh.surface_get_material(s))


func piece_count() -> int:
	return _pieces.size()


## Aquecimento na carga: um quadrado minusculo por variante pontilhada e uma copia minuscula de cada malha do kit
## pontilhada, a `ahead` m na FRENTE da camera (dentro da vista: o desenho garante o pipeline montado, sem depender de
## a Godot compilar o que esta fora da vista), por `seconds`. Devolve quantas instancias.
## `warm_mode` (medida da captura G24a2): &"view" (padrao, na frente da camera), &"out" (longe da vista), &"none".
static var warm_mode: StringName = &"view"


func warm_up(cam: Camera3D, seconds: float = 0.5, ahead: float = 0.6) -> int:
	if warm_mode == &"none":
		return 0
	var root := Node3D.new()
	root.name = "OcclusionWarmUp"
	cam.add_child(root)
	root.position = Vector3(0, 0, -ahead) if warm_mode != &"out" else Vector3(0, -1000.0, 0)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.002, 0.002)
	var n := 0
	var meshes: Dictionary = {}
	for p: Dictionary in _pieces:
		if p.has("mmi"):
			meshes[(p["mmi"] as MultiMeshInstance3D).multimesh.mesh] = true
	for src: Mesh in meshes:
		var mi := MeshInstance3D.new()
		mi.mesh = WV2Materials.occl_mesh(src)
		mi.scale = Vector3.ONE * (0.002 / maxf(src.get_aabb().get_longest_axis_size(), 0.01))
		mi.set_instance_shader_parameter(&"occl_amount", 1.0)
		root.add_child(mi)
		n += 1
	for m: Material in WV2Materials.occl_variants():
		var q := MeshInstance3D.new()
		q.mesh = quad
		q.material_override = m
		q.set_instance_shader_parameter(&"occl_amount", 1.0)
		root.add_child(q)
		n += 1
	cam.get_tree().create_timer(seconds).timeout.connect(root.queue_free)
	warm_count = n
	return n


## Um quadro. `on` false (cena, enquadramento livre) devolve tudo. `instant` (movimento reduzido): sem fade.
func update(cam: Vector3, hero_feet: Vector3, delta: float, instant: bool, on: bool = true) -> void:
	var t0 := Time.get_ticks_usec()
	swaps_frame = 0
	_frame += 1
	var hits: Dictionary = {}
	if on:
		var lo := cam.min(hero_feet) - Vector3.ONE * (NEAR + 1.0)
		var hi := cam.max(hero_feet) + Vector3.ONE * (NEAR + 1.0)
		for x in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
			for z in range(floori(lo.z / CELL), floori(hi.z / CELL) + 1):
				var cell: Variant = _grid.get(Vector2i(x, z))
				if cell == null:
					continue
				for idx: int in cell as PackedInt32Array:
					if _stamp[idx] == _frame:
						continue
					_stamp[idx] = _frame
					var g := KEEP if _active.has(idx) else GROW
					if _blocks((_pieces[idx]["box"] as AABB).grow(g), cam, hero_feet):
						hits[idx] = true
	for idx: int in hits:
		if not _active.has(idx) and _swap(idx):
			swaps_frame += 1
	var center := hero_feet + Vector3(0, CENTER_Y, 0)
	var done: Array[int] = []
	for idx: int in _active:
		var a: Dictionary = _active[idx]
		var want := 1.0 if hits.has(idx) else 0.0
		var amt: float = want if instant or delta <= 0.0 else move_toward(float(a["amount"]), want, delta / FADE_TIME)
		a["amount"] = amt
		if amt <= 0.0 and want <= 0.0:
			done.append(idx)
			continue
		var gi := _target(idx, a)
		gi.set_instance_shader_parameter(&"occl_cam", Vector4(cam.x, cam.y, cam.z, NEAR))
		gi.set_instance_shader_parameter(&"occl_hero", Vector4(center.x, center.y, center.z, RADIUS))
		gi.set_instance_shader_parameter(&"occl_amount", amt)
	for idx in done:
		_restore(idx)
	swapped_now = _active.size()
	usec_frame = Time.get_ticks_usec() - t0


## Caixa tapa algum dos raios camera -> heroi (pe, centro, cabeca) ou contem a camera.
func _blocks(box: AABB, cam: Vector3, feet: Vector3) -> bool:
	if box.grow(NEAR_BOX).has_point(cam):
		return true
	for h: float in RAYS:
		if box.intersects_segment(cam, feet + Vector3(0, h, 0)) != null:
			return true
	return false


func _target(idx: int, a: Dictionary) -> GeometryInstance3D:
	if a.has("proxy"):
		return a["proxy"] as GeometryInstance3D
	return _pieces[idx]["mesh"] as GeometryInstance3D


func _swap(idx: int) -> bool:
	var p := _pieces[idx]
	var a := {amount = 0.0}
	if p.has("mmi"):
		var mmi := p["mmi"] as MultiMeshInstance3D
		if not is_instance_valid(mmi) or not mmi.is_visible_in_tree():
			return false
		var i: int = p["i"]
		var xf: Transform3D = p["xf"]
		# Instancia escondida pela missao (carrinho dirigivel: escala ~0 no mesmo lugar) nao pontilha. Sem servidor de
		# render (headless) a leitura volta zerada: conta como visivel.
		if _hidden(mmi.multimesh.get_instance_transform(i), xf):
			return false
		var proxy := MeshInstance3D.new()
		proxy.name = "Occl_%s_%d" % [mmi.name, i]
		proxy.mesh = WV2Materials.occl_mesh(mmi.multimesh.mesh)
		proxy.cast_shadow = mmi.cast_shadow
		proxy.visibility_range_end = mmi.visibility_range_end
		proxy.visibility_range_end_margin = mmi.visibility_range_end_margin
		proxy.visibility_range_fade_mode = mmi.visibility_range_fade_mode
		mmi.add_child(proxy)
		proxy.transform = xf
		mmi.multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), xf.origin))
		a["proxy"] = proxy
		a["xf"] = xf
	else:
		var mi := p["mesh"] as MeshInstance3D
		if mi == null or not is_instance_valid(mi) or not mi.is_visible_in_tree():
			return false
		var orig: Array = []
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s)
			orig.append(m)
			var base := m if m != null else mi.mesh.surface_get_material(s)
			if base != null:
				mi.set_surface_override_material(s, WV2Materials.occl_variant(base))
		a["orig"] = orig
	_active[idx] = a
	return true


func _hidden(live: Transform3D, xf: Transform3D) -> bool:
	if live.origin == Vector3.ZERO and live.basis.x == Vector3.ZERO:
		return false
	return live.basis.get_scale().x < HIDDEN_SCALE


func _restore(idx: int) -> void:
	var a: Dictionary = _active[idx]
	var p := _pieces[idx]
	if a.has("proxy"):
		var mmi := p["mmi"] as MultiMeshInstance3D
		if is_instance_valid(mmi):
			var i: int = p["i"]
			mmi.multimesh.set_instance_transform(i, a["xf"] as Transform3D)
		var proxy := a["proxy"] as Node
		if is_instance_valid(proxy):
			proxy.queue_free()
	else:
		var mi := p["mesh"] as MeshInstance3D
		if is_instance_valid(mi):
			var orig: Array = a["orig"]
			for s in orig.size():
				mi.set_surface_override_material(s, orig[s] as Material)
	_active.erase(idx)


## Pecas no meio do fade (0 < fade < 1) agora; com movimento reduzido deve ser sempre 0.
func mid_fade() -> int:
	var n := 0
	for idx: int in _active:
		var amt := float((_active[idx] as Dictionary)["amount"])
		if amt > 0.0 and amt < 1.0:
			n += 1
	return n


func restore_all() -> void:
	for idx: int in _active.keys():
		_restore(idx)
	swapped_now = 0


## `point` esta numa peca pontilhada agora (fade >= 0,5) e dentro da area que o shader faz sumir? (testes)
func covers_point(point: Vector3, cam: Vector3, hero_feet: Vector3) -> bool:
	var center := hero_feet + Vector3(0, CENTER_Y, 0)
	var seg := center - cam
	var t := (point - cam).dot(seg) / maxf(seg.length_squared(), 1e-4)
	var in_cone := t > 0.0 and t < 1.0 and (cam + seg * t).distance_to(point) < RADIUS * lerpf(0.5, 1.0, t)
	if not in_cone and point.distance_to(cam) >= NEAR * 0.6:
		return false
	for idx: int in _active:
		if float((_active[idx] as Dictionary)["amount"]) >= 0.5 and (_pieces[idx]["box"] as AABB).grow(GROW).has_point(point):
			return true
	return false


## Alguma peca pontilhada (fade >= 0,5) contem `point` (com a folga NEAR_BOX)? (testes: camera dentro de peca)
func piece_contains(point: Vector3) -> bool:
	for idx: int in _active:
		if float((_active[idx] as Dictionary)["amount"]) >= 0.5 and (_pieces[idx]["box"] as AABB).grow(NEAR_BOX).has_point(point):
			return true
	return false


## Alguma peca (trocada ou nao) contem `point`? (testes: separar estrutura de peca)
func is_piece_point(point: Vector3) -> bool:
	var cell: Variant = _grid.get(Vector2i(floori(point.x / CELL), floori(point.z / CELL)))
	if cell == null:
		return false
	for idx: int in cell as PackedInt32Array:
		if (_pieces[idx]["box"] as AABB).grow(GROW).has_point(point):
			return true
	return false
