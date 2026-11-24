extends SceneTree
## Gera res://episodes/ep01/world/harbor_slice.tscn (RB-R1, PROVISORIO) a partir de harbor_layout.json
## (exportado de source_art/environment/village_layout.py pela tools/export-environment.ps1).
## - Cais: instancia res://actors/environment/dock_assembled.tscn (topo do deck em y = 0).
## - Casas e mobiliario: instancias das cenas proprias (a malha do GLB e compartilhada entre as instancias);
##   cor da parede/telhado por instancia via material de superficie compartilhado (mat_env_wall_*, mat_env_roof_*).
## - Chao repetido (cais de pedra, praca, gramado) e tufos de flores: MultiMeshInstance3D com malha unica mesclada.
## - Colisao simples FORA dos GLB: caixas por peca de chao + limites de agua.
## Uso (apos --import e gen_env_scenes): ./tools/godot.ps1 --headless --path game --script res://episodes/ep01/world/gen_harbor_slice.gd

const ENV := "res://actors/environment/"
const WORLD := "res://episodes/ep01/world/"
const MATS := "res://actors/environment/materials/"
const LAYOUT := "res://episodes/ep01/world/harbor_layout.json"
const MULTI := ["quay_block", "plaza_tile", "lawn_block", "flower_clump"]
const WALLS := {"peach": "ffc9a3", "mint": "bdebd3", "sky": "bfe3ff", "lemon": "fff0a8", "rose": "ffc6d3"}
const ROOFS := {"terracotta": "d8693f", "blue": "3a7bd5"}
const COLLIDE_MULTI := {"quay_block": [Vector3(8, 1.6, 6), Vector3(0, -0.8, 0)], "plaza_tile": [Vector3(8, 0.7, 8), Vector3(0, -0.35, 0)],
	"lawn_block": [Vector3(8, 1.6, 6), Vector3(0, -0.8, 0)]}

var _fail := false
var _mat_cache := {}


func _initialize() -> void:
	_run.call_deferred()


func _own(n: Node, owner_node: Node) -> void:
	for c in n.get_children():
		c.owner = owner_node
		if c.scene_file_path.is_empty():
			_own(c, owner_node)


func _xform(d: Dictionary) -> Transform3D:
	var p: Array = d["pos"]
	var s: Array = d.get("s", [1, 1, 1])
	var b := Basis(Vector3.UP, deg_to_rad(float(d.get("ry", 0.0)))).scaled_local(Vector3(s[0], s[1], s[2]))
	return Transform3D(b, Vector3(p[0], p[1], p[2]))


## Material de superficie compartilhado (salvo em .tres) derivado do material importado.
func _variant(base: Material, mname: String, hexcol: String) -> Material:
	if _mat_cache.has(mname):
		return _mat_cache[mname]
	var path := MATS + mname + ".tres"
	var m := (base as BaseMaterial3D).duplicate() as BaseMaterial3D
	m.resource_name = mname
	m.albedo_color = Color(hexcol)
	m.vertex_color_use_as_albedo = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MATS))
	ResourceSaver.save(m, path)
	var loaded := load(path) as Material
	_mat_cache[mname] = loaded
	return loaded


func _paint_house(n: Node3D, wall: String, roof: String) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var nm := String(m.name)
		if wall != "" and nm.ends_with("_Wall"):
			m.set_surface_override_material(0, _variant(m.mesh.surface_get_material(0), "mat_env_wall_" + wall, WALLS[wall]))
		elif roof != "" and (nm.ends_with("_Roof") or nm.ends_with("_RoofTiles")):
			m.set_surface_override_material(0, _variant(m.mesh.surface_get_material(0), "mat_env_roof_" + roof, ROOFS[roof]))


## Malha unica (varias superficies) mesclando todas as MeshInstance3D do GLB, com as transformacoes aplicadas.
func _merged(id: String) -> ArrayMesh:
	var path := WORLD + "meshes/" + id + "_merged.res"
	var ps := load("res://assets/models/environment/" + id + ".glb") as PackedScene
	var root := ps.instantiate() as Node3D
	var am := ArrayMesh.new()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var xf := _global(m, root)
		for s in m.mesh.get_surface_count():
			var st := SurfaceTool.new()
			st.append_from(m.mesh, s, xf)
			st.set_material(m.mesh.surface_get_material(s))
			var before := am.get_surface_count()
			st.commit(am)
			if am.get_surface_count() > before:
				am.surface_set_material(before, m.mesh.surface_get_material(s))
	root.free()
	am.resource_name = id + "_merged"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORLD + "meshes/"))
	ResourceSaver.save(am, path)
	return load(path) as ArrayMesh


func _global(n: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


func _group(parent: Node, gname: String) -> Node3D:
	var g := Node3D.new()
	g.name = gname
	parent.add_child(g)
	return g


func _box(body: StaticBody3D, nm: String, size: Vector3, xf: Transform3D) -> void:
	var cs := CollisionShape3D.new()
	cs.name = nm
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.transform = xf
	body.add_child(cs)


func _extra_ground() -> Array:
	## Chao complementar do trecho (composicao B): faixa atras do cais norte, terraco y=1.2, oeste, conector, promontorio.
	var L: Array = []
	for x in [-18, -10, -2, 6, 14, 22]:
		L.append({"id": "lawn_block", "pos": [x, 0, -21.0], "ry": 0, "s": [1, 1, 0.67]})
		for z in [-26, -32, -38, -44]:
			L.append({"id": "lawn_block", "pos": [x, 1.2, z], "ry": 0, "s": [1, 1, 1]})
	for x in [-42, -50]:
		for z in [-14, -8, -2, 4, 10]:
			L.append({"id": "lawn_block", "pos": [x, 0, z], "ry": 0, "s": [1, 1, 1]})
	for x in [-26, -34]:
		L.append({"id": "lawn_block", "pos": [x, 0, -19.0], "ry": 0, "s": [1, 1, 0.5]})
	for z in [-12, -4, 4]:
		L.append({"id": "plaza_tile", "pos": [-21, 0, z], "ry": 0, "s": [0.25, 1, 1]})
	L.append({"id": "lawn_block", "pos": [-12, 0, 7], "ry": 0, "s": [0.5, 1, 1.34]})
	for x in [29, 35]:
		L.append({"id": "lawn_block", "pos": [x, 2.4, -24], "ry": 0, "s": [1, 2.5, 1.3]})
	# tufos de flores ao longo das fachadas e da praca (MultiMesh)
	var rng := RandomNumberGenerator.new()
	rng.seed = 707
	for i in 46:
		var p := Vector3(rng.randf_range(-15, 20), 0.0, rng.randf_range(-16.4, -15.8)) if i < 28 else Vector3(rng.randf_range(-25.6, -24.6), 0.0, rng.randf_range(-14, 6))
		var k := rng.randf_range(0.8, 1.3)
		L.append({"id": "flower_clump", "pos": [p.x, p.y, p.z], "ry": rng.randf_range(0, 360), "s": [k, k, k]})
	return L


func _run() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	if not (data is Dictionary):
		printerr("layout ilegivel: ", LAYOUT)
		quit(1)
		return
	var root := Node3D.new()
	root.name = "HarborSlice"
	root.set_meta("provisional", true)
	root.set_meta("composition", String((data as Dictionary).get("comp", "")))
	var dock := (load(ENV + "dock_assembled.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	dock.name = "Dock"
	root.add_child(dock)
	var village := _group(root, "Village")
	var ground := _group(root, "Ground")
	var back := _group(root, "Backdrop")
	var multi := {}
	var pieces: Array = (data as Dictionary)["pieces"]
	pieces = pieces + _extra_ground()
	var count := 0
	for pd in pieces:
		var d := pd as Dictionary
		var id := String(d["id"])
		if id in MULTI:
			if not multi.has(id):
				multi[id] = []
			(multi[id] as Array).append(_xform(d))
			continue
		var ps := load(ENV + id + ".tscn") as PackedScene
		if ps == null:
			printerr("cena ausente: ", id)
			_fail = true
			continue
		var n := ps.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
		var parent: Node3D = back if id in ["hills_near", "hills_far", "cloud", "seagull"] else village
		n.name = "%s_%d" % [id, count]
		parent.add_child(n)
		n.transform = _xform(d)
		if id.begins_with("house_"):
			_paint_house(n, String(d.get("wall", "")), String(d.get("roof", "")))
		count += 1
	# chao e flores em MultiMesh (uma malha por tipo) + colisao em caixas
	var body := StaticBody3D.new()
	body.name = "GroundBody"
	body.collision_mask = 0
	ground.add_child(body)
	for id in multi:
		var xfs: Array = multi[id]
		var mmi := EnvMultiMesh.new()
		mmi.name = "MM_" + id
		mmi.source_mesh = _merged(id)
		var arr: Array[Transform3D] = []
		for x in xfs:
			arr.append(x)
		mmi.xforms = arr
		if id == "flower_clump":
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ground.add_child(mmi)
		if COLLIDE_MULTI.has(id):
			for i in xfs.size():
				var xf: Transform3D = xfs[i]
				var c: Array = COLLIDE_MULTI[id]
				var sc := xf.basis.get_scale()
				var size: Vector3 = c[0] * sc
				_box(body, "%s_%d" % [id, i], size, Transform3D(Basis(Vector3.UP, xf.basis.get_euler().y), xf * (c[1] as Vector3)))
	# limites de agua (paredes invisiveis baixas): borda do cais norte, borda leste do cais oeste, ponta leste
	var limits := StaticBody3D.new()
	limits.name = "Limits"
	limits.collision_mask = 0
	root.add_child(limits)
	_box(limits, "NorthQuayEdge", Vector3(48, 1.4, 0.3), Transform3D(Basis(), Vector3(2, 0.7, -12.85)))
	_box(limits, "WestQuayEdge", Vector3(0.3, 1.4, 16), Transform3D(Basis(), Vector3(-13.85, 0.7, -5)))
	_box(limits, "EastEnd", Vector3(0.3, 3.0, 8), Transform3D(Basis(), Vector3(26.2, 1.5, -16)))
	_own(root, root)
	var ps2 := PackedScene.new()
	var err := ps2.pack(root)
	if err == OK:
		err = ResourceSaver.save(ps2, WORLD + "harbor_slice.tscn")
	print("CENA ", WORLD, "harbor_slice.tscn pecas=", count, " multimesh=", multi.keys(), " err=", err)
	root.free()
	quit(1 if (_fail or err != OK) else 0)
