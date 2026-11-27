class_name CameraOcclusion
extends RefCounted
## RB-R1 G24a2: troca, so nas malhas que estao entre a camera e o heroi, o material pela variante pontilhada
## (WV2Materials.occl_variant) e devolve o original quando o fade termina. Os materiais normais ficam sem discard.
## Candidatas: GeometryInstance3D do mundo cuja caixa (AABB global, crescida pelo raio do cone) cruza o segmento
## camera -> heroi. MeshInstance3D troca por superficie; MultiMeshInstance3D troca a malha (cache por malha).
## Mede: malhas trocadas no quadro, total trocado agora e tempo de CPU da atualizacao (us).

var _items: Array[GeometryInstance3D] = []
var _boxes: Array[AABB] = []
## instancia -> materiais originais por superficie (MeshInstance3D) ou malha original (MultiMeshInstance3D)
var _swapped: Dictionary = {}
var _mm_cache: Dictionary = {}
var swaps_frame: int = 0
var swapped_now: int = 0
var usec_frame: int = 0


func _init(world: Node) -> void:
	for n in world.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if g is MeshInstance3D and (g as MeshInstance3D).mesh != null:
			_items.append(g)
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null \
				and (g as MultiMeshInstance3D).multimesh.mesh != null:
			_items.append(g)
	for g in _items:
		_boxes.append(g.global_transform * g.get_aabb())
		# Variantes criadas ja na carga (a troca no jogo e so atribuicao). A compilacao na GPU ainda acontece no
		# primeiro desenho de cada variante.
		if g is MeshInstance3D:
			var mi := g as MeshInstance3D
			for k in mi.mesh.get_surface_count():
				var m := mi.get_surface_override_material(k)
				var base := m if m != null else mi.mesh.surface_get_material(k)
				if base != null:
					WV2Materials.occl_variant(base)
		else:
			var src := (g as MultiMeshInstance3D).multimesh.mesh
			if not _mm_cache.has(src):
				_mm_cache[src] = WV2Materials.occl_mesh(src)


## Aquecimento: um quadrado minusculo por variante pontilhada (e por malha de MultiMesh trocada), longe da vista
## (y -1000), por `seconds`, para a Godot montar o pipeline de cada variante na carga e nao no primeiro tapar.
func warm_up(parent: Node3D, seconds: float = 0.5) -> int:
	var root := Node3D.new()
	root.name = "OcclusionWarmUp"
	parent.add_child(root)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.01, 0.01)
	var n := 0
	for m: Material in WV2Materials.occl_variants():
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		mi.global_position = Vector3(0, -1000.0, 0)
		n += 1
	for src: Mesh in _mm_cache:
		var mi2 := MeshInstance3D.new()
		mi2.mesh = _mm_cache[src]
		root.add_child(mi2)
		mi2.global_position = Vector3(0, -1000.0, 0)
		mi2.scale = Vector3.ONE * 0.001
		n += 1
	parent.get_tree().create_timer(seconds).timeout.connect(root.queue_free)
	return n


## Um quadro: `amount` > 0 troca as malhas no cone; 0 devolve todas. Parametros do shader nas variantes.
func update(cam: Vector3, hero: Vector3, radius: float, amount: float) -> void:
	var t0 := Time.get_ticks_usec()
	swaps_frame = 0
	if amount <= 0.0:
		restore_all()
	else:
		for i in _items.size():
			var g := _items[i]
			if _swapped.has(g) or not is_instance_valid(g) or not g.is_visible_in_tree():
				continue
			if _boxes[i].grow(radius).intersects_segment(cam, hero) or _boxes[i].grow(radius).has_point(cam):
				_swap(g)
				swaps_frame += 1
		WV2Materials.set_occlusion(cam, hero, radius, amount)
	swapped_now = _swapped.size()
	usec_frame = Time.get_ticks_usec() - t0


func _swap(g: GeometryInstance3D) -> void:
	if g is MeshInstance3D:
		var mi := g as MeshInstance3D
		var orig: Array = []
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s)
			orig.append(m)
			var base := m if m != null else mi.mesh.surface_get_material(s)
			if base != null:
				mi.set_surface_override_material(s, WV2Materials.occl_variant(base))
		_swapped[g] = orig
	else:
		var mm := (g as MultiMeshInstance3D).multimesh
		var src := mm.mesh
		if not _mm_cache.has(src):
			_mm_cache[src] = WV2Materials.occl_mesh(src)
		_swapped[g] = src
		mm.mesh = _mm_cache[src]


func restore_all() -> void:
	for g: GeometryInstance3D in _swapped:
		if not is_instance_valid(g):
			continue
		if g is MeshInstance3D:
			var orig: Array = _swapped[g]
			for s in orig.size():
				(g as MeshInstance3D).set_surface_override_material(s, orig[s] as Material)
		else:
			(g as MultiMeshInstance3D).multimesh.mesh = _swapped[g] as Mesh
	_swapped.clear()


## Algum objeto trocado para o pontilhado cobre `p` (caixa crescida 5 cm)? (testes)
func covers_point(p: Vector3) -> bool:
	for i in _items.size():
		if _swapped.has(_items[i]) and _boxes[i].grow(0.05).has_point(p):
			return true
	return false


## Esta malha usa agora a variante pontilhada? (testes)
func is_swapped(g: GeometryInstance3D) -> bool:
	return _swapped.has(g)
