class_name CameraOcclusion
extends RefCounted
## RB-R1 G24a2 v2: duas classes de obstaculo para a camera.
##  - ESTRUTURA (predios, terreno, cais, muros, e por ora toldo/banca do galpao, banco da arvore e canteiros, que estao
##    dentro das malhas de quarteirao): continua na mascara da camera (mola de braco do CameraRig, G6).
##  - PECA (instancias do kit: caixotes, carrinho, barracas, barris, vasos, bancos, arvores; e pecas de missao: carrinho
##    do M4, banco do varal do G19): sai da camera e, quando fica entre a camera e o heroi ou contem a camera, a PECA
##    INTEIRA fica pontilhada com um valor so de fade (FADE_TIME s; movimento reduzido so liga e desliga).
## Regra (art3d): so troca malha que tem UMA peca (instancia do kit vira MeshInstance3D proprio; peca de missao e um no
## proprio); nunca troca malha de quarteirao. Separacao data-driven, sem .blend nem GLB: tipos do `kit` do layout
## (PIECE_SKIP fora); o corpo `Collision/Props` (colisao gerada do kit) sai da camera.
## Mede: trocas no quadro, pecas trocadas, CPU da atualizacao (us) e a etapa do pior quadro.

const PIECE_SKIP: Array[String] = ["grass_tall", "grass_tuft", "flowers_a", "flowers_b"]
const FADE_TIME := 0.15
const CENTER_Y := 0.6        ## centro do heroi acima dos pes
const RAYS: Array[float] = [0.2, 0.6, 1.0]   ## pe, centro e cabeca do heroi
const GROW := 0.05           ## folga da caixa da peca no teste do segmento
const NEAR_BOX := 0.2        ## camera a menos disto da caixa da peca conta como "dentro" (a lente nao corta a peca)
const KEEP := 0.25           ## histerese: peca ja trocada fica ate sair desta folga
const CELL := 4.0
const HIDDEN_SCALE := 0.01   ## instancia do kit com escala menor que isto ja esta escondida (missao, grama)

## peca do kit: {box: AABB, mmi: MultiMeshInstance3D, i: int, xf: Transform3D}
var _pieces: Array[Dictionary] = []
var _grid: Dictionary = {}       ## Vector2i -> PackedInt32Array de indices de peca
var _stamp: PackedInt32Array = []
var _frame := 0
## indice de peca -> {amount: float, proxy: MeshInstance3D, xf: Transform3D}
var _active: Dictionary = {}
## Pecas de missao (no inteiro; caixa recalculada a cada quadro porque o carrinho anda). Sem tipo nos lacos: o no
## pode ter sido liberado pela missao (land.build) entre dois quadros.
var _dyn: Array = []
var _dyn_active: Dictionary = {}   ## instance_id -> {node, amount, orig: {mi_id: [mi, mats]}, box}
var swaps_frame := 0
var swapped_now := 0
var usec_frame := 0
var updates := 0                   ## atualizacoes completas (teste: o update nao aborta)
var warm_count := 0
## Pior quadro (us) e a etapa dele: grade, troca, dinamicas, parametros, devolucao.
var usec_max := 0
var usec_max_stage := ""


## Corpos de peca que saem da mascara da camera.
static func piece_bodies(world: Node) -> Array[RID]:
	var out: Array[RID] = []
	var props := world.get_node_or_null("Collision/Props") as CollisionObject3D
	if props != null:
		out.append(props.get_rid())
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
	# A caixa da peca do kit cobre tambem a colisao gerada dela (`Collision/Props/<tipo>_<i>[_<j>]`).
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


func piece_count() -> int:
	return _pieces.size()


## Aquecimento na carga: um quadrado minusculo por variante pontilhada e uma copia minuscula de cada malha do kit
## pontilhada, a `ahead` m na FRENTE da camera, por `seconds`. Medido na 4.7 (xvfb/llvmpipe): o pipeline base compila
## tambem fora da vista; dentro dela compilam ainda as especializacoes. Devolve quantas instancias.
## `warm_mode` (medida da captura G24a2): &"view" (padrao), &"out" (longe da vista), &"none".
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
	var stage_us: Dictionary = {}
	swaps_frame = 0
	_frame += 1
	var hits: Dictionary = {}
	if on:
		var lo := cam.min(hero_feet) - Vector3.ONE * 1.5
		var hi := cam.max(hero_feet) + Vector3.ONE * 1.5
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
	var t1 := Time.get_ticks_usec()
	stage_us["grade"] = t1 - t0
	for idx: int in hits:
		if not _active.has(idx) and _swap(idx):
			swaps_frame += 1
	var t2 := Time.get_ticks_usec()
	stage_us["troca"] = t2 - t1
	_update_dynamic(cam, hero_feet, delta, instant, on)
	var t3 := Time.get_ticks_usec()
	stage_us["dinamicas"] = t3 - t2
	var done: Array[int] = []
	for idx: int in _active:
		var a: Dictionary = _active[idx]
		var want := 1.0 if hits.has(idx) else 0.0
		var amt: float = want if instant or delta <= 0.0 else move_toward(float(a["amount"]), want, delta / FADE_TIME)
		a["amount"] = amt
		if amt <= 0.0 and want <= 0.0:
			done.append(idx)
			continue
		var proxy: Variant = a["proxy"]
		if is_instance_valid(proxy):
			(proxy as GeometryInstance3D).set_instance_shader_parameter(&"occl_cam", Vector4(cam.x, cam.y, cam.z, 0.0))
			(proxy as GeometryInstance3D).set_instance_shader_parameter(&"occl_amount", amt)
	var t4 := Time.get_ticks_usec()
	stage_us["parametros"] = t4 - t3
	for idx in done:
		_restore(idx)
	stage_us["devolucao"] = Time.get_ticks_usec() - t4
	swapped_now = _active.size() + _dyn_active.size()
	usec_frame = Time.get_ticks_usec() - t0
	if usec_frame > usec_max:
		usec_max = usec_frame
		var worst := ""
		var wu := -1
		for k: String in stage_us:
			if int(stage_us[k]) > wu:
				wu = int(stage_us[k])
				worst = k
		usec_max_stage = "%s %d us (trocas %d)" % [worst, wu, swaps_frame]
	updates += 1


## Caixa tapa algum dos raios camera -> heroi (pe, centro, cabeca) ou contem a camera.
func _blocks(box: AABB, cam: Vector3, feet: Vector3) -> bool:
	if box.grow(NEAR_BOX).has_point(cam):
		return true
	for h: float in RAYS:
		if box.intersects_segment(cam, feet + Vector3(0, h, 0)) != null:
			return true
	return false


func _swap(idx: int) -> bool:
	var p := _pieces[idx]
	var mmi := p["mmi"] as MultiMeshInstance3D
	if not is_instance_valid(mmi) or not mmi.is_visible_in_tree():
		return false
	var i: int = p["i"]
	var xf: Transform3D = p["xf"]
	# Instancia escondida pela missao (carrinho dirigivel: escala ~0) nao pontilha. Sem servidor de render (headless)
	# a leitura volta zerada: conta como visivel.
	if _hidden(mmi.multimesh.get_instance_transform(i)):
		return false
	var proxy := MeshInstance3D.new()
	proxy.name = "Occl_%s_%d" % [mmi.name, i]
	# Variantes com os parametros atuais das bases (noite, festa).
	proxy.mesh = WV2Materials.occl_mesh(mmi.multimesh.mesh, true)
	proxy.cast_shadow = mmi.cast_shadow
	proxy.visibility_range_end = mmi.visibility_range_end
	proxy.visibility_range_end_margin = mmi.visibility_range_end_margin
	proxy.visibility_range_fade_mode = mmi.visibility_range_fade_mode
	mmi.add_child(proxy)
	proxy.transform = xf
	mmi.multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), xf.origin))
	_active[idx] = {amount = 0.0, proxy = proxy, xf = xf}
	return true


func _hidden(live: Transform3D) -> bool:
	if live.origin == Vector3.ZERO and live.basis.x == Vector3.ZERO:
		return false
	return live.basis.get_scale().x < HIDDEN_SCALE


func _restore(idx: int) -> void:
	var a: Dictionary = _active[idx]
	var mmi: Variant = _pieces[idx]["mmi"]
	if is_instance_valid(mmi):
		(mmi as MultiMeshInstance3D).multimesh.set_instance_transform(int(_pieces[idx]["i"]), a["xf"] as Transform3D)
	var proxy: Variant = a["proxy"]
	if is_instance_valid(proxy):
		(proxy as Node).queue_free()
	_active.erase(idx)


## Pecas no meio do fade (0 < fade < 1) agora; com movimento reduzido deve ser sempre 0.
func mid_fade() -> int:
	var n := 0
	for idx: int in _active:
		var amt := float((_active[idx] as Dictionary)["amount"])
		if amt > 0.0 and amt < 1.0:
			n += 1
	for k: Variant in _dyn_active:
		var amt2 := float((_dyn_active[k] as Dictionary)["amount"])
		if amt2 > 0.0 and amt2 < 1.0:
			n += 1
	return n


## Tudo volta ao normal na hora (cena, troca de heroi, antes de `land.build`).
func restore_all() -> void:
	for idx: int in _active.keys():
		_restore(idx)
	for k: Variant in _dyn_active.keys():
		_dyn_restore(k)
	swapped_now = 0


## `point` esta numa peca pontilhada agora (fade >= 0,5)? A peca inteira pontilha. (testes)
func covers_point(point: Vector3, _cam: Vector3 = Vector3.ZERO, _hero_feet: Vector3 = Vector3.ZERO) -> bool:
	return piece_contains(point, GROW)


## Pecas de missao (nos com malhas); as que sairam da lista ou foram liberadas voltam ao normal.
func set_dynamic(nodes: Array) -> void:
	var keep: Array = []
	for n: Variant in nodes:
		if is_instance_valid(n) and (n as Node).is_inside_tree():
			keep.append(n)
	for k: Variant in _dyn_active.keys():
		var node: Variant = (_dyn_active[k] as Dictionary)["node"]
		if not is_instance_valid(node) or not keep.has(node):
			_dyn_restore(k)
	_dyn = keep
	for n: Variant in _dyn:
		for mi in _meshes_of(n as Node3D):
			for s in mi.mesh.get_surface_count():
				var m := mi.get_surface_override_material(s)
				var base := m if m != null else mi.mesh.surface_get_material(s)
				if base != null:
					WV2Materials.occl_variant(base)


## Pecas de missao validas agora (teste: nenhuma liberada fica na lista).
func dynamic_nodes() -> Array:
	return _dyn


func _meshes_of(n: Node3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n as MeshInstance3D)
	for c in n.find_children("*", "MeshInstance3D", true, false):
		if (c as MeshInstance3D).mesh != null:
			out.append(c as MeshInstance3D)
	return out


func _dyn_box(n: Node3D) -> Variant:
	var box: Variant = null
	for mi in _meshes_of(n):
		if not mi.is_visible_in_tree():
			continue
		var b := mi.global_transform * mi.get_aabb()
		box = b if box == null else (box as AABB).merge(b)
	return box


func _update_dynamic(cam: Vector3, feet: Vector3, delta: float, instant: bool, on: bool) -> void:
	# No liberado sai da lista e das trocas antes de qualquer uso.
	var alive: Array = []
	for n: Variant in _dyn:
		if is_instance_valid(n) and (n as Node).is_inside_tree():
			alive.append(n)
	_dyn = alive
	for k: Variant in _dyn_active.keys():
		if not is_instance_valid((_dyn_active[k] as Dictionary)["node"]):
			_dyn_restore(k)
	for n: Variant in _dyn:
		var node := n as Node3D
		var key := node.get_instance_id()
		var box: Variant = _dyn_box(node)
		var g := KEEP if _dyn_active.has(key) else GROW
		var hit: bool = on and box != null and _blocks((box as AABB).grow(g), cam, feet)
		if hit and not _dyn_active.has(key):
			var orig: Dictionary = {}
			for mi in _meshes_of(node):
				var arr: Array = []
				for s in mi.mesh.get_surface_count():
					var m := mi.get_surface_override_material(s)
					arr.append(m)
					var base := m if m != null else mi.mesh.surface_get_material(s)
					if base != null:
						mi.set_surface_override_material(s, WV2Materials.occl_variant(base, true))
				orig[mi.get_instance_id()] = [mi, arr]
			_dyn_active[key] = {node = node, amount = 0.0, orig = orig, box = box}
			swaps_frame += 1
		if not _dyn_active.has(key):
			continue
		var a: Dictionary = _dyn_active[key]
		if box != null:
			a["box"] = box
		var want := 1.0 if hit else 0.0
		var amt: float = want if instant or delta <= 0.0 else move_toward(float(a["amount"]), want, delta / FADE_TIME)
		a["amount"] = amt
		if amt <= 0.0 and want <= 0.0:
			_dyn_restore(key)
			continue
		for mk: Variant in (a["orig"] as Dictionary):
			var pair: Array = (a["orig"] as Dictionary)[mk]
			if is_instance_valid(pair[0]):
				(pair[0] as GeometryInstance3D).set_instance_shader_parameter(&"occl_cam", Vector4(cam.x, cam.y, cam.z, 0.0))
				(pair[0] as GeometryInstance3D).set_instance_shader_parameter(&"occl_amount", amt)


func _dyn_restore(key: Variant) -> void:
	var a: Dictionary = _dyn_active.get(key, {})
	var orig: Dictionary = a.get("orig", {})
	for mk: Variant in orig:
		var pair: Array = orig[mk]
		if is_instance_valid(pair[0]):
			var arr: Array = pair[1]
			for s in arr.size():
				(pair[0] as MeshInstance3D).set_surface_override_material(s, arr[s] as Material)
	_dyn_active.erase(key)


## Alguma peca pontilhada (fade >= 0,5) contem `point` (com a folga `grow`)? (testes)
func piece_contains(point: Vector3, grow: float = NEAR_BOX) -> bool:
	for k: Variant in _dyn_active:
		var a: Dictionary = _dyn_active[k]
		if float(a["amount"]) >= 0.5 and a["box"] != null and (a["box"] as AABB).grow(grow).has_point(point):
			return true
	for idx: int in _active:
		if float((_active[idx] as Dictionary)["amount"]) >= 0.5 and (_pieces[idx]["box"] as AABB).grow(grow).has_point(point):
			return true
	return false


## Alguma peca (trocada ou nao) contem `point`? (testes)
func is_piece_point(point: Vector3) -> bool:
	for n: Variant in _dyn:
		if is_instance_valid(n):
			var b: Variant = _dyn_box(n as Node3D)
			if b != null and (b as AABB).grow(GROW).has_point(point):
				return true
	var cell: Variant = _grid.get(Vector2i(floori(point.x / CELL), floori(point.z / CELL)))
	if cell == null:
		return false
	for idx: int in cell as PackedInt32Array:
		if (_pieces[idx]["box"] as AABB).grow(GROW).has_point(point):
			return true
	return false
