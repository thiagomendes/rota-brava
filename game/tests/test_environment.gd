extends RefCounted
## Ambiente do primeiro minuto (RB-04-env): cais modular, adercos, vegetacao e barco v2.
## Contrato tecnico (nos, escala em metros, topo do deck em y = 0, cobertura da area do Ep01Layout, colisao fora do GLB,
## materiais mat_env_*, PawMark legivel, empties, cabine nao cobre o banco na camera de jogo, so malha do projeto).
## Nao comprova gosto nem aparencia: isso e visto nas capturas.

const TA := preload("res://tests/test_assets.gd")
const ENV := "res://actors/environment/"
const GLB_DIR := "res://assets/models/environment/"
const MANIFEST := "../source_art/manifest_environment.json"
const CAM_OFFSET := Vector3(0, 7.5, 9.5)   # CameraRig.offset do Ep01 (fov 55)

var r


func run(runner) -> void:
	r = runner
	var ids := _test_manifest()
	_test_scenes(ids)
	_test_deck()
	_test_assembly()
	_test_boat()
	_test_cabin_view()
	_test_paw()
	_test_glb_folder(ids)
	_test_harbor()
	await _test_world()


# ------------------------------------------------------------------ RB-R1: rio, ilha, horizonte e margem sul
const WORLD_DIR := "res://episodes/ep01/world/"
## Coordenadas adotadas pelo lead (LAYOUT_PROPOSTO.md): apoios da travessia +90 m em x.
const W_FOOTHOLDS := [Vector3(183.5, 0.3, 6.5), Vector3(186.0, 0.5, 5.0), Vector3(188.5, 0.3, 4.2)]
const W_BRIDGE_X := 62.0
const W_MIN_CLEARANCE := 3.4          # vao livre sobre a agua (y -0,4) no corredor do barco |z| <= 10
const W_MIN_PER_20M := 8              # pecas de margem (vegetacao/rochas) por 20 m de cada margem
const VEG := ["tree_round", "tree_round_dark", "tree_tall", "bush_round", "bush_flower", "reeds", "rock_a", "rock_b",
	"rock_c", "grass_tuft", "flower_clump", "palm_tree", "boulder"]


static func _world_verts(root: Node3D, pattern: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	for mi in root.find_children(pattern, "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var t := Transform3D.IDENTITY
		var p: Node = m
		while p != null and p != root:
			t = (p as Node3D).transform * t
			p = p.get_parent()
		for s in m.mesh.get_surface_count():
			for v in (m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				out.append(t * v)
	return out


static func _range_y(vs: PackedVector3Array, x0: float, x1: float, z0: float, z1: float) -> Vector2:
	var lo := 1e9
	var hi := -1e9
	for v in vs:
		if v.x >= x0 and v.x <= x1 and v.z >= z0 and v.z <= z1:
			lo = minf(lo, v.y)
			hi = maxf(hi, v.y)
	return Vector2(lo, hi)


static func world_bridge_clearance(river: Node3D) -> float:
	var br := river.find_child("arch_bridge_*", true, false) as Node3D
	if br == null:
		return -1.0
	var lo := 1e9
	for v in _world_verts(river, "Arch_Bridge_*"):
		if absf(v.z) <= 10.0 and absf(v.x - W_BRIDGE_X) <= 1.5:
			lo = minf(lo, v.y)
	return lo - Ep01Layout.WATER_Y


static func world_foothold_errors(island: Node3D) -> Array:
	var errs: Array = []
	for i in W_FOOTHOLDS.size():
		var n := island.find_child("SafeRock%d" % i, true, false) as Node3D
		if n == null:
			errs.append("SafeRock%d ausente" % i)
			continue
		var top := (n.transform * TA.mesh_aabb(n)).end.y
		var f: Vector3 = W_FOOTHOLDS[i]
		if absf(top - f.y) > 0.02 or Vector2(n.position.x - f.x, n.position.z - f.z).length() > 0.05:
			errs.append("SafeRock%d topo %.3f em %s" % [i, top, n.position])
	return errs


static func world_bank_density(river: Node3D) -> Array:
	## [minimo, trecho] de pecas por 20 m em cada margem (x 40..180).
	var counts := {}
	for mm in river.find_children("MM_*", "MultiMeshInstance3D", true, false):
		var id := String(mm.name).trim_prefix("MM_")
		var ok := false
		for v in VEG:
			if id.begins_with(v + "_") or id == v:
				ok = true
		if not ok:
			continue
		for xf in (mm as EnvMultiMesh).xforms:
			var o := (xf as Transform3D).origin
			if o.x < 40.0 or o.x >= 180.0 or absf(o.z) > 40.0:
				continue
			var key := "%s%d" % ["N" if o.z < 0 else "S", int((o.x - 40.0) / 20.0)]
			counts[key] = int(counts.get(key, 0)) + 1
	var worst := 1 << 30
	var where := ""
	for side in ["N", "S"]:
		for k in 7:
			var c := int(counts.get("%s%d" % [side, k], 0))
			if c < worst:
				worst = c
				where = "%s x %d..%d" % [side, 40 + 20 * k, 60 + 20 * k]
	return [worst, where]


func _path_hits(space: PhysicsDirectSpaceState3D) -> int:
	var a := Ep01Layout.RASTRO_START
	var b := Ep01Layout.BANK_PRINT_POS
	var sph := SphereShape3D.new()
	sph.radius = 0.3
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sph
	q.collide_with_areas = false
	var hits := 0
	var n := int(a.distance_to(b) / 0.25)
	for i in n + 1:
		var p := a.lerp(b, float(i) / n) + Vector3(0, 0.65, 0)
		q.transform = Transform3D(Basis(), p)
		hits += space.intersect_shape(q, 4).size()
	return hits


func _test_world() -> void:
	var scenes := {}
	for nm in ["river_world", "island_world", "horizon"]:
		var ps := load(WORLD_DIR + nm + ".tscn") as PackedScene
		r.check(ps != null, "world: %s.tscn carrega" % nm)
		if ps == null:
			return
		var n := ps.instantiate() as Node3D
		r.check(n.get_meta("provisional", false) == true, "world: %s marcado como provisorio" % nm)
		scenes[nm] = n
	var river: Node3D = scenes["river_world"]
	var island: Node3D = scenes["island_world"]
	var horizon: Node3D = scenes["horizon"]
	r.check(river.name == "RiverWorld" and island.name == "IslandWorld" and horizon.name == "Horizon", "world: nomes dos nos raiz")
	# topos onde se anda
	var iv := _world_verts(island, "Island_Ground_*")
	var camp := _range_y(iv, 193.5, 200.0, -2.0, 8.0)
	r.check(absf(camp.x) <= 0.01 and absf(camp.y) <= 0.01, "world: chao da ilha (acampamento) em y = 0 +-1 cm (%.4f..%.4f)" % [camp.x, camp.y])
	var rv := _world_verts(river, "River_Bank_South_*")
	var land := _range_y(rv, 177.0, 181.0, 3.0, 16.0)
	r.check(absf(land.x) <= 0.01 and absf(land.y) <= 0.01, "world: pouso de Pico (margem oeste do braco) em y = 0 +-1 cm (%.4f..%.4f)" % [land.x, land.y])
	var errs := world_foothold_errors(island)
	r.check(errs.is_empty(), "world: 3 apoios seguros no topo e posicao previstos %s" % [errs])
	var decoys := 0
	for c in island.find_children("DecoyRock*", "Node3D", true, false):
		decoys += 1
		var top := ((c as Node3D).transform * TA.mesh_aabb(c as Node3D)).end.y
		r.check(top < 0.2 and TA.material_names(c).has("mat_env_rock_wet"), "world: %s escura/molhada e baixa (topo %.2f)" % [c.name, top])
	r.check(decoys >= 3 and decoys <= 4, "world: 3 a 4 iscas na travessia (%d)" % decoys)
	var safe_mat := TA.material_names(island.find_child("SafeRock0", true, false))
	r.check(safe_mat.has("mat_env_rock_safe"), "world: apoio seguro usa mat_env_rock_safe (claro)")
	for need in ["CampTent", "CampFire", "CampCrate", "CampFlag", "IslandPier"]:
		r.check(island.find_child(need, true, false) != null, "world: acampamento/atracadouro tem %s" % need)
	var pier := island.find_child("IslandPier", true, false) as Node3D
	var ptop := (pier.transform * TA.mesh_aabb(pier)).end.y if pier != null else 9.0
	r.check(ptop >= -0.01 and ptop <= 0.3, "world: atracadouro da ilha com topo em y ~ 0 (%.3f)" % ptop)
	# ponte
	var clr := world_bridge_clearance(river)
	r.check(clr >= W_MIN_CLEARANCE, "world: vao livre da ponte >= 3,4 m sobre a agua no corredor do barco (%.2f m)" % clr)
	# densidade das margens
	var dens := world_bank_density(river)
	r.check(int(dens[0]) >= W_MIN_PER_20M, "world: densidade minima de %d pecas por 20 m de margem (pior: %d em %s)" % [W_MIN_PER_20M, dens[0], dens[1]])
	# horizonte em todo o perimetro
	var hills := 0
	var quad := {}
	for mm in horizon.find_children("MM_hills_*", "MultiMeshInstance3D", true, false):
		for xf in (mm as EnvMultiMesh).xforms:
			hills += 1
			var o := (xf as Transform3D).origin - Vector3(85, 0, -10)
			quad[int(posmod(int(rad_to_deg(atan2(o.z, o.x)) + 360.0), 360) / 90)] = true
	r.check(hills >= 20 and quad.size() == 4, "world: morros de horizonte nos 4 quadrantes (%d)" % hills)
	# malhas do projeto
	var ext: Array = []
	for root in [river, island, horizon]:
		for mi in (root as Node).find_children("*", "MeshInstance3D", true, false):
			var rp := (mi as MeshInstance3D).mesh.resource_path
			if not rp.begins_with("res://assets/models/environment/"):
				ext.append(rp)
		for mm in (root as Node).find_children("MM_*", "MultiMeshInstance3D", true, false):
			if not (mm as EnvMultiMesh).source_mesh.resource_path.begins_with("res://episodes/ep01/world/meshes/"):
				ext.append((mm as EnvMultiMesh).source_mesh.resource_path)
	r.check(ext.is_empty(), "world: nenhuma malha externa ao projeto %s" % [ext.slice(0, 3)])
	# mutacoes
	var sr := island.find_child("SafeRock0", true, false) as Node3D
	sr.position.y += 0.3
	var m1 := world_foothold_errors(island).is_empty()
	sr.position.y -= 0.3
	r.check(not m1 and world_foothold_errors(island).is_empty(), "world: mutacao (apoio +30 cm) reprova e restaura")
	var br := river.find_child("arch_bridge_*", true, false) as Node3D
	br.position.y -= 1.0
	var m2 := world_bridge_clearance(river) >= W_MIN_CLEARANCE
	br.position.y += 1.0
	r.check(not m2 and world_bridge_clearance(river) >= W_MIN_CLEARANCE, "world: mutacao (ponte 1 m mais baixa) reprova e restaura")
	for n in scenes.values():
		(n as Node).free()
	# caminho livre na margem sul (fisica real do trecho do porto)
	var harbor := (load(HARBOR) as PackedScene).instantiate() as Node3D
	r.tree.root.add_child(harbor)
	await r.frames(3)
	var space := harbor.get_world_3d().direct_space_state
	var hits := _path_hits(space)
	r.check(hits == 0, "margem: caminho livre de RASTRO_START ate BANK_PRINT_POS (%d contatos)" % hits)
	var block := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(1, 1, 1)
	cs.shape = bx
	block.add_child(cs)
	harbor.add_child(block)
	block.global_position = Ep01Layout.RASTRO_START.lerp(Ep01Layout.BANK_PRINT_POS, 0.5) + Vector3(0, 0.5, 0)
	await r.frames(3)
	var hits2 := _path_hits(space)
	block.queue_free()
	await r.frames(3)
	r.check(hits2 > 0 and _path_hits(space) == 0, "margem: mutacao (caixa no caminho) reprova e restaura (%d)" % hits2)
	var bp := harbor.find_child("BootPrint", true, false) as Node3D
	r.check(bp != null and Vector2(bp.global_position.x - Ep01Layout.BANK_PRINT_POS.x, bp.global_position.z - Ep01Layout.BANK_PRINT_POS.z).length() < 0.05, "margem: BootPrint em BANK_PRINT_POS")
	harbor.queue_free()
	await r.frames(1)


# ------------------------------------------------------------------ RB-R1: trecho do porto/vila Farol 7
const HARBOR := "res://episodes/ep01/world/harbor_slice.tscn"
const HARBOR_CAM_OFFSET := Vector3(0, 4.6, 6.2)   # camera do cais pedida no RB-R1 (fov 55, olhar +1 m)
## Densidade minima na camera do cais (16:9, ate 60 m): 40 pecas. Justificativa: o quadro cobre ~40 m de fachada
## no cais norte + o deck; a style-bible (sec. 8) pede "nenhum plano vazio" com densidade nas bordas e no fundo,
## o que da ~1 peca por metro de borda visivel. O cais do RB-04 sozinho ficava em ~20 nessa mesma camera.
const HARBOR_MIN_VISIBLE := 40
const HARBOR_MIN_LIGHTHOUSE_H := 12.0


static func harbor_lighthouse_height(root: Node3D) -> float:
	for c in root.find_children("lighthouse_*", "Node3D", true, false):
		var n := c as Node3D
		var box := n.transform * TA.mesh_aabb(n)
		return box.size.y * 1.0
	return 0.0


static func harbor_dock_top(root: Node3D) -> float:
	var dock := root.get_node_or_null("Dock") as Node3D
	if dock == null:
		return 999.0
	var top := -999.0
	for c in dock.find_children("Deck*", "Node3D", true, false):
		var n := c as Node3D
		var t := Transform3D.IDENTITY
		var p: Node = n
		while p != null and p != root:
			t = (p as Node3D).transform * t
			p = p.get_parent()
		top = maxf(top, (t * TA.mesh_aabb(n)).end.y)
	return top


static func harbor_mm_top(root: Node3D, id: String) -> float:
	var mm := root.find_child("MM_" + id, true, false) as EnvMultiMesh
	if mm == null or mm.source_mesh == null or mm.xforms.is_empty():
		return 999.0
	var top := -999.0
	for xf in mm.xforms:
		if absf((xf as Transform3D).origin.y) < 0.001:
			top = maxf(top, (xf as Transform3D).origin.y + _walk_top(mm.source_mesh))
	return top


## Topo da superficie caminhavel (material mat_env_cobble/mat_env_grass) da malha mesclada; o meio-fio do cais
## (capeamento de 18 cm na borda da agua) nao conta como piso.
static func _walk_top(m: Mesh) -> float:
	var top := -999.0
	for s in m.get_surface_count():
		var mat := m.surface_get_material(s)
		if mat == null or not (mat.resource_name in ["mat_env_cobble", "mat_env_grass"]):
			continue
		for v in (m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			top = maxf(top, v.y)
	return top


static func harbor_visible_count(root: Node3D) -> int:
	var tgt := Ep01Layout.BENCH_INTERACT_POS
	var eye := tgt + HARBOR_CAM_OFFSET
	var basis := Basis.looking_at(tgt + Vector3(0, 1, 0) - eye, Vector3.UP)
	var tv := tan(deg_to_rad(27.5))
	var th := tv * 16.0 / 9.0
	var pts: Array = []
	var village := root.get_node_or_null("Village")
	if village != null:
		for c in village.get_children():
			pts.append((c as Node3D).position)
	var dock := root.get_node_or_null("Dock")
	if dock != null:
		for g in dock.get_children():
			for c in g.get_children():
				if c is Node3D:
					pts.append((dock as Node3D).transform * ((g as Node3D).transform * (c as Node3D).position))
	for mm in root.find_children("MM_*", "Node3D", true, false):
		for xf in (mm as EnvMultiMesh).xforms:
			pts.append((xf as Transform3D).origin)
	var n := 0
	for p in pts:
		var l: Vector3 = basis.inverse() * ((p as Vector3) + Vector3(0, 0.3, 0) - eye)
		var depth := -l.z
		if depth > 0.5 and depth < 60.0 and absf(l.y / depth) <= tv and absf(l.x / depth) <= th:
			n += 1
	return n


func _test_harbor() -> void:
	var ps := load(HARBOR) as PackedScene
	r.check(ps != null, "harbor: harbor_slice.tscn carrega")
	if ps == null:
		return
	var root := ps.instantiate() as Node3D
	r.tree.root.add_child(root)
	r.check(root.get_meta("provisional", false) == true, "harbor: trecho marcado como provisorio")
	var top := harbor_dock_top(root)
	r.check(absf(top) <= 0.01, "harbor: topo do deck do cais em y = 0 +-1 cm (%.4f)" % top)
	var qtop := harbor_mm_top(root, "quay_block")
	r.check(absf(qtop) <= 0.01, "harbor: topo do cais de pedra (praca do mercado) em y = 0 +-1 cm (%.4f)" % qtop)
	var ptop := harbor_mm_top(root, "plaza_tile")
	r.check(absf(ptop) <= 0.01, "harbor: topo da praca em y = 0 +-1 cm (%.4f)" % ptop)
	var lh := harbor_lighthouse_height(root)
	r.check(lh > HARBOR_MIN_LIGHTHOUSE_H, "harbor: farol existe e mede > 12 m (%.2f m)" % lh)
	# casas instanciadas: varias instancias compartilham a mesma malha do GLB
	var houses := 0
	var wall_meshes := {}
	for c in root.find_children("house_*", "Node3D", true, false):
		houses += 1
		for mi in (c as Node).find_children("*_Wall", "MeshInstance3D", true, false):
			var m := (mi as MeshInstance3D).mesh
			wall_meshes[m.get_instance_id()] = int(wall_meshes.get(m.get_instance_id(), 0)) + 1
	var shared := 0
	for k in wall_meshes:
		if int(wall_meshes[k]) >= 2:
			shared += 1
	r.check(houses >= 8 and houses <= 24, "harbor: 8+ casas instanciadas (%d)" % houses)
	r.check(wall_meshes.size() <= 4 and shared >= 3, "harbor: casas repetidas reutilizam a mesma malha (%d malhas para %d casas)" % [wall_meshes.size(), houses])
	var mm_total := 0
	for mm in root.find_children("MM_*", "MultiMeshInstance3D", true, false):
		mm_total += (mm as EnvMultiMesh).xforms.size()
		r.check((mm as MultiMeshInstance3D).multimesh != null and (mm as MultiMeshInstance3D).multimesh.instance_count == (mm as EnvMultiMesh).xforms.size(), "harbor: %s montado em MultiMesh (%d)" % [mm.name, (mm as EnvMultiMesh).xforms.size()])
	r.check(mm_total >= 60, "harbor: chao e flores por MultiMesh (%d instancias)" % mm_total)
	# colisao simples, fora dos GLB
	var in_model := 0
	var shapes := 0
	for cs in root.find_children("*", "CollisionShape3D", true, false):
		shapes += 1
		var p: Node = cs.get_parent()
		while p != null and p != root:
			if p.name == "Model":
				in_model += 1
				break
			p = p.get_parent()
		var sh := (cs as CollisionShape3D).shape
		if not (sh is BoxShape3D or sh is CylinderShape3D):
			in_model += 1
	r.check(shapes > 50 and in_model == 0, "harbor: %d colisoes simples (caixa/cilindro) fora dos GLB" % shapes)
	r.check(root.get_node_or_null("Limits") != null, "harbor: limites de agua presentes")
	# materiais mat_env_* (inclui sobreposicoes por instancia)
	var bad: Array = []
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		for s in m3.mesh.get_surface_count():
			var mat: Material = m3.get_surface_override_material(s)
			if mat == null:
				mat = m3.mesh.surface_get_material(s)
			if mat != null and not mat.resource_name.begins_with("mat_env_") and not bad.has(mat.resource_name):
				bad.append(mat.resource_name)
	r.check(bad.is_empty(), "harbor: todos os materiais sao mat_env_* %s" % [bad])
	# densidade na camera do cais
	var vis := harbor_visible_count(root)
	r.check(vis >= HARBOR_MIN_VISIBLE, "harbor: %d pecas na area visivel da camera do cais (minimo %d)" % [vis, HARBOR_MIN_VISIBLE])
	# so malha do projeto
	var ext: Array = []
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var rp := (mi as MeshInstance3D).mesh.resource_path
		if not (rp.begins_with("res://assets/models/environment/") or rp.begins_with("res://episodes/ep01/world/meshes/")):
			ext.append(rp)
	for mm in root.find_children("MM_*", "MultiMeshInstance3D", true, false):
		var rp2 := (mm as EnvMultiMesh).source_mesh.resource_path
		if not rp2.begins_with("res://episodes/ep01/world/meshes/"):
			ext.append(rp2)
	r.check(ext.is_empty(), "harbor: nenhuma malha externa ao projeto %s" % [ext.slice(0, 3)])
	# mutacoes: devem reprovar e, restauradas, voltar a passar
	var dock := root.get_node("Dock") as Node3D
	dock.position.y += 0.2
	var mut1 := absf(harbor_dock_top(root)) <= 0.01
	dock.position.y -= 0.2
	r.check(not mut1 and absf(harbor_dock_top(root)) <= 0.01, "harbor: mutacao (topo do cais +20 cm) reprova e restaura")
	var lhn := root.find_children("lighthouse_*", "Node3D", true, false)[0] as Node3D
	var old := lhn.scale
	lhn.scale = Vector3(1, 0.5, 1)
	var mut2 := harbor_lighthouse_height(root) > HARBOR_MIN_LIGHTHOUSE_H
	lhn.scale = old
	r.check(not mut2 and harbor_lighthouse_height(root) > HARBOR_MIN_LIGHTHOUSE_H, "harbor: mutacao (farol a 50%) reprova e restaura")
	root.queue_free()


func _load_scene(id: String) -> Node3D:
	var ps := load(ENV + id + ".tscn") as PackedScene
	return ps.instantiate() as Node3D if ps != null else null


func _glb_path(id: String) -> String:
	return GLB_DIR + id + ".glb"


func _test_manifest() -> Array:
	var txt := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join(MANIFEST))
	var man: Variant = JSON.parse_string(txt)
	r.check(man is Dictionary and (man as Dictionary).has("ativos"), "env: manifesto source_art/manifest_environment.json legivel")
	var ids: Array = []
	if not (man is Dictionary):
		return ids
	for a in (man as Dictionary)["ativos"]:
		var d := a as Dictionary
		var id: String = d.get("id", "")
		ids.append(id)
		r.check(d.get("agente") == "art3d" and d.get("status") == "provisorio", "env: manifesto %s com agente art3d e status provisorio" % id)
		var abs_glb := ProjectSettings.globalize_path("res://").path_join("../" + String(d.get("saida_glb", "")))
		r.check(FileAccess.file_exists(abs_glb) and FileAccess.get_sha256(abs_glb) == String(d.get("glb_sha256", "")), "env: GLB de %s existe e sha256 confere" % id)
		var missing: Array = []
		for s in d.get("origem", []):
			if not FileAccess.file_exists(ProjectSettings.globalize_path("res://").path_join("../" + String(s))):
				missing.append(s)
		r.check(missing.is_empty(), "env: origem de %s existe %s" % [id, missing])
		var all_env := true
		for m in d.get("materiais", []):
			if not String(m).begins_with("mat_env_"):
				all_env = false
		r.check(int(d.get("triangulos", 0)) > 0 and all_env and (d.get("materiais", []) as Array).size() > 0, "env: %s registra triangulos e so materiais mat_env_*" % id)
	r.check(ids.size() >= 30, "env: manifesto cobre >= 30 ativos (%d)" % ids.size())
	return ids


func _test_scenes(ids: Array) -> void:
	var solid := ["dock_deck_2m", "dock_deck_4m", "crate_l", "crate_s", "crate_peach", "barrel", "boat_hut", "boat_v2",
		"ground_tile_a", "ground_tile_b", "ground_tile_path", "lantern_post", "dock_post", "tree_a", "tree_b", "tree_c", "rock_a", "rock_c"]
	for id in ids:
		var root := _load_scene(id)
		r.check(root != null, "env: cena %s carrega" % id)
		if root == null:
			continue
		var model := root.find_child("Model", false, false)
		r.check(model != null and root.has_meta("provisional"), "env: %s tem no Model e marca provisoria" % id)
		var outside := 0
		var foreign := 0
		for n in root.find_children("*", "MeshInstance3D", true, false):
			if model == null or not model.is_ancestor_of(n):
				outside += 1
			elif not (n as MeshInstance3D).mesh.resource_path.begins_with(_glb_path(id)):
				foreign += 1
		r.check(outside == 0 and foreign == 0, "env: %s so tem malha do proprio GLB (fora do Model: %d, estranhas: %d)" % [id, outside, foreign])
		var txt := FileAccess.get_file_as_string(ENV + id + ".tscn")
		r.check(not txt.contains("ArrayMesh") and not txt.contains("BoxMesh"), "env: %s.tscn sem malha propria" % id)
		var names := TA.material_names(model)
		var bad: Array = []
		for m in names:
			if not String(m).begins_with("mat_env_"):
				bad.append(m)
		r.check(not names.is_empty() and bad.is_empty(), "env: materiais de %s sao mat_env_* %s" % [id, bad])
		var vc_off: Array = []
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			for si in (mi as MeshInstance3D).mesh.get_surface_count():
				var bmat := (mi as MeshInstance3D).mesh.surface_get_material(si) as BaseMaterial3D
				if bmat != null and not bmat.vertex_color_use_as_albedo:
					vc_off.append(bmat.resource_name)
		r.check(vc_off.is_empty(), "env: %s importa a cor por vertice como albedo (pos-importacao) %s" % [id, vc_off])
		var imp := (load(_glb_path(id)) as PackedScene).instantiate()
		r.check(imp.find_children("*", "CollisionObject3D", true, false).is_empty(), "env: GLB de %s nao traz colisao" % id)
		imp.free()
		if id in solid:
			var shapes := root.find_children("*", "CollisionShape3D", true, false)
			var ok := not shapes.is_empty()
			for s in shapes:
				if model.is_ancestor_of(s) or (s as CollisionShape3D).shape == null:
					ok = false
			r.check(ok, "env: %s tem colisao simples fora do GLB" % id)
		root.free()


func _test_deck() -> void:
	for pair in [["dock_deck_2m", 2.0], ["dock_deck_4m", 4.0]]:
		var root := _load_scene(pair[0])
		if root == null:
			r.check(false, "env: %s ausente" % pair[0])
			continue
		var box := TA.mesh_aabb(root)
		r.check(absf(box.size.x - float(pair[1])) < 0.03 and absf(box.size.z - 6.0) < 0.03, "env: %s mede %.2f x 6,00 m (%.3f x %.3f)" % [pair[0], pair[1], box.size.x, box.size.z])
		r.check(absf(box.end.y) < 0.01, "env: topo de %s em y = 0 +-1 cm (%.4f)" % [pair[0], box.end.y])
		r.check(absf(box.get_center().x) < 0.02 and absf(box.get_center().z) < 0.02, "env: origem de %s no centro do modulo" % pair[0])
		var planks := root.find_child("Dock_Deck_%dm_Planks" % int(pair[1]), true, false) as MeshInstance3D
		r.check(planks != null and planks.mesh.get_faces().size() / 3 > 1000, "env: tabuas de %s sao geometria individual (>1000 tri)" % pair[0])
		var body := root.find_child("Collision", true, false) as CollisionShape3D
		var top := body.position.y + (body.shape as BoxShape3D).size.y * 0.5
		r.check(absf(top) < 0.01, "env: colisao de %s com topo em y = 0 (%.4f)" % [pair[0], top])
		root.free()


func _test_assembly() -> void:
	var root := _load_scene("dock_assembled")
	r.check(root != null, "env: dock_assembled.tscn carrega")
	if root == null:
		return
	r.tree.root.add_child(root)
	var box := TA.mesh_aabb(root)
	r.check(box.position.x <= -9.95 and box.end.x >= 9.95, "env: montagem cobre x -10..10 (%.2f .. %.2f)" % [box.position.x, box.end.x])
	r.check(box.position.z <= -2.99 and box.end.z >= 15.95, "env: montagem cobre z -3..16 (%.2f .. %.2f)" % [box.position.z, box.end.z])
	var deck_box := AABB()
	var first := true
	for n in root.find_child("Dock", false, false).get_children():
		if String(n.name).begins_with("Deck"):
			var b := TA.mesh_aabb(n as Node3D)
			b.position += (n as Node3D).position
			deck_box = b if first else deck_box.merge(b)
			first = false
	r.check(deck_box.position.x <= -7.99 and deck_box.end.x >= 7.99 and deck_box.position.z <= -2.99 and deck_box.end.z >= 2.99,
		"env: deck cobre x -8..8 e z -3..3 (%s)" % [deck_box])
	r.check(absf(deck_box.end.y) < 0.01, "env: topo da montagem do deck em y = 0 +-1 cm (%.4f)" % deck_box.end.y)
	# margem: topo plano em y = 0 (relevo so desce ate 3 cm)
	var tiles := root.find_child("Ground", false, false).get_children()
	var worst_top := -1.0
	var worst_low := 1.0
	var covered_x := 0.0
	for t in tiles:
		var tb := TA.mesh_aabb(t as Node3D)
		worst_top = maxf(worst_top, tb.end.y)
		worst_low = minf(worst_low, tb.end.y)
		covered_x += tb.size.x
		r.check(tb.size.z >= 12.99, "env: ladrilho %s cobre 13 m em z" % t.name)
	r.check(tiles.size() == 3 and absf(covered_x - 20.0) < 0.1, "env: 3 ladrilhos (8+4+8 m) cobrem 20 m em x (%.2f)" % covered_x)
	# RB-R1: a grama tem morrinhos (ate ~22 cm) longe do caminho; o caminho de terra (parte *_Path) fica em y = 0 +-1 cm
	r.check(worst_top < 0.3 and worst_top > 0.08, "env: margem com relevo leve na grama (topo %.3f m)" % worst_top)
	var path_lo := 1.0
	var path_hi := -1.0
	var path_parts := 0
	for t in [root.find_child("BankPath", true, false)]:
		if t == null:
			continue
		for mi in (t as Node).find_children("Bank_Path_*", "MeshInstance3D", true, false):
			path_parts += 1
			for v in (mi as MeshInstance3D).mesh.get_faces():
				path_lo = minf(path_lo, v.y)
				path_hi = maxf(path_hi, v.y)
	r.check(path_parts >= 2 and absf(path_lo) <= 0.01 and absf(path_hi) <= 0.01, "env: caminho de terra da margem em y = 0 +-1 cm (%d partes, %.4f..%.4f)" % [path_parts, path_lo, path_hi])
	# colisao do chao da margem e do deck existe
	var floors := 0
	for n in root.find_children("Collision", "CollisionShape3D", true, false):
		var cs := n as CollisionShape3D
		if cs.shape is BoxShape3D and absf(cs.global_position.y + (cs.shape as BoxShape3D).size.y * 0.5 * cs.global_transform.basis.y.y) < 0.01 and (cs.shape as BoxShape3D).size.x >= 1.9:
			floors += 1
	r.check(floors == 7, "env: montagem tem pisos solidos com topo em y = 0 (%d)" % floors)
	# adercos principais presentes
	var need := ["CrateL", "CratePeach", "BarrelA", "RopeCoil", "LanternW", "Net", "Sign", "BucketA", "OarA", "BuoyA", "Hut", "BootPrint"]
	var miss: Array = []
	for n in need:
		if root.find_child(n, true, false) == null:
			miss.append(n)
	r.check(miss.is_empty(), "env: adercos do cais presentes %s" % [miss])
	for n in ["PostWest", "CleatA", "Fender0", "Ladder", "Edge0", "Pile0"]:
		r.check(root.find_child(n, true, false) != null, "env: peca modular %s presente" % n)
	var trees := 0
	var rocks := 0
	for n in root.find_child("Nature", false, false).get_children():
		if String(n.name).begins_with("Tree"):
			trees += 1
		if String(n.name).begins_with("Rock"):
			rocks += 1
	r.check(trees >= 3 and rocks >= 3, "env: vegetacao e rochas instanciadas (%d arvores, %d rochas)" % [trees, rocks])
	# a pegada de bota fica na posicao do Ep01Layout
	var bp := root.find_child("BootPrint", true, false) as Node3D
	r.check(bp != null and Vector2(bp.position.x, bp.position.z).distance_to(Vector2(Ep01Layout.BANK_PRINT_POS.x, Ep01Layout.BANK_PRINT_POS.z)) < 0.05, "env: BootPrint em BANK_PRINT_POS")
	# orcamento medido (informativo, limite folgado)
	var tris := 0
	for n in root.find_children("*", "MeshInstance3D", true, false):
		tris += (n as MeshInstance3D).mesh.get_faces().size() / 3
	print("  env: triangulos da montagem (conta cada instancia): %d" % tris)
	r.check(tris > 20000 and tris < 600000, "env: triangulos da montagem em faixa sensata (%d)" % tris)
	root.get_parent().remove_child(root)
	root.free()


func _test_boat() -> void:
	var root := _load_scene("boat_v2")
	r.check(root != null, "env: boat_v2.tscn carrega")
	if root == null:
		return
	for n in ["Boat_Hull", "Boat_Deck", "Boat_Cabin", "Boat_CabinRoof", "Boat_Bench", "Boat_Helm", "Boat_Windows", "Boat_Motor",
		"Boat_Flag", "Boat_Lantern", "Boat_Rope", "Boat_Name", "PawMark", "DeckPoint", "BenchMark", "WheelPoint", "HornPoint", "PivotMark"]:
		r.check(root.find_child(n, true, false) != null, "env: no %s do barco v2 presente" % n)
	var hull := TA.part_aabb(root, "Boat_Hull")
	r.check(absf(hull.size.x - 2.2) < 0.06 and absf(hull.size.z - 5.0) < 0.06, "env: casco ~2,2 x 5,0 m (%.3f x %.3f)" % [hull.size.x, hull.size.z])
	r.check(hull.position.z < -2.9 and hull.end.z > 1.9, "env: proa em -Z (z de %.2f a %.2f)" % [hull.position.z, hull.end.z])
	r.check(absf(hull.end.z / hull.size.z - 0.4) < 0.02, "env: pivo a 40%% da popa (%.3f)" % (hull.end.z / hull.size.z))
	r.check(absf(hull.get_center().x) < 0.02, "env: pivo no eixo longitudinal")
	var hm := (root.find_child("Boat_Hull", true, false) as MeshInstance3D).mesh.surface_get_material(0) as BaseMaterial3D
	r.check(hm != null and hm.resource_name == "mat_env_boat_hull" and absf(hm.albedo_color.r - 0.96) < 0.03 and absf(hm.albedo_color.g - 0.77) < 0.03 and hm.albedo_color.b < 0.15,
		"env: casco amarelo #F5C518")
	var bench := root.find_child("BenchMark", true, false) as Node3D
	var want: Vector3 = Ep01Layout.BENCH_LOCAL
	r.check(bench != null and absf(bench.position.x - want.x) < 0.05 and absf(bench.position.z - want.z) < 0.05 and absf(bench.position.y - want.y) < 0.05,
		"env: BenchMark em BENCH_LOCAL do Ep01Layout (%s)" % [bench.position if bench != null else "?"])
	var deckp := root.find_child("DeckPoint", true, false) as Node3D
	r.check(deckp != null and deckp.position.y > 0.3 and deckp.position.y < 0.6, "env: DeckPoint sobre o conves")
	var bench_mesh := TA.part_aabb(root, "Boat_Bench")
	r.check(absf(bench_mesh.end.y - want.y) < 0.03, "env: topo do banco em y ~ %.2f (%.3f)" % [want.y, bench_mesh.end.y])
	var cabin := TA.part_aabb(root, "Boat_Cabin")
	r.check(cabin.position.z > bench_mesh.end.z - 0.02, "env: cabine na popa, depois do banco (cabine z0 %.2f, banco z1 %.2f)" % [cabin.position.z, bench_mesh.end.z])
	r.check(cabin.end.z <= hull.end.z + 0.02, "env: cabine dentro do casco (z ate %.2f)" % cabin.end.z)
	var helm := TA.part_aabb(root, "Boat_Helm")
	r.check(helm.size.y > 0.25 and helm.position.z < bench_mesh.position.z, "env: volante visivel, a vante do banco (diametro %.2f)" % helm.size.y)
	var cols := root.find_children("*", "CollisionShape3D", true, false)
	r.check(not cols.is_empty() and not (root.find_child("Model", false, false) as Node).is_ancestor_of(cols[0]), "env: colisao do barco fora do GLB")
	root.free()


## Raio de cada camera de jogo ate BenchMark: nao pode atravessar a malha da cabine (triangulos reais).
func _ray_hits_cabin(boat: Node3D, cam: Vector3, target: Vector3) -> bool:
	for nm in ["Boat_Cabin", "Boat_CabinRoof", "Boat_Windows", "Boat_WindowFrames", "Boat_Motor", "Boat_Flag", "Boat_FlagPole"]:
		var mi := boat.find_child(nm, true, false) as MeshInstance3D
		if mi == null:
			continue
		var tm: TriangleMesh = mi.mesh.generate_triangle_mesh()
		if tm == null:
			continue
		var inv := mi.global_transform.affine_inverse()
		var hit := tm.intersect_segment(inv * cam, inv * target)
		if not hit.is_empty():
			return true
	return false


func _test_cabin_view() -> void:
	var boat := _load_scene("boat_v2")
	if boat == null:
		r.check(false, "env: barco ausente para teste de camera")
		return
	r.tree.root.add_child(boat)
	boat.global_position = Ep01Layout.BOAT_DOCKED_POS
	boat.rotation.y = Ep01Layout.BOAT_DOCKED_HEADING
	var bench := boat.find_child("BenchMark", true, false) as Node3D
	var target := bench.global_position
	var foci := [Ep01Layout.BENCH_INTERACT_POS, Ep01Layout.RASTRO_START, Vector3(-2, 0, -2.4), Vector3(3, 0, -2.4), Vector3(0, 0, 0)]
	var clear := 0
	for f in foci:
		var cam: Vector3 = f + CAM_OFFSET
		if not _ray_hits_cabin(boat, cam, target):
			clear += 1
		else:
			printerr("  raio da camera de ", f, " bate na cabine")
	r.check(clear == foci.size(), "env: cabine nao cobre o banco em %d/%d posicoes da camera de jogo" % [clear, foci.size()])
	# controle positivo: o mesmo teste DEVE acusar se a cabine for posta entre a camera e o banco
	var cabin := boat.find_child("Boat_Cabin", true, false) as MeshInstance3D
	var saved := cabin.global_position
	var cam0: Vector3 = Ep01Layout.BENCH_INTERACT_POS + CAM_OFFSET
	var cabin_center: Vector3 = cabin.global_transform * cabin.mesh.get_aabb().get_center()
	cabin.global_position += (cam0 + target) * 0.5 - cabin_center
	r.check(_ray_hits_cabin(boat, cam0, target), "env: controle do teste de raio detecta cabine bloqueando o banco")
	cabin.global_position = saved
	r.check(not _ray_hits_cabin(boat, cam0, target), "env: controle restaurado, caminho livre")
	boat.get_parent().remove_child(boat)
	boat.free()


func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


func _test_paw() -> void:
	var root := _load_scene("boat_v2")
	if root == null:
		return
	var paw := root.find_child("PawMark", true, false) as MeshInstance3D
	r.check(paw != null, "env: PawMark existe como objeto proprio")
	if paw == null:
		root.free()
		return
	var bb := TA.part_aabb(root, "PawMark")
	r.check(bb.size.x * bb.size.z >= 0.05 and bb.size.x >= 0.25 and bb.size.z >= 0.25, "env: PawMark com area minima (%.2f x %.2f m)" % [bb.size.x, bb.size.z])
	var bench_aabb := TA.part_aabb(root, "Boat_Bench")
	r.check(bb.position.x >= bench_aabb.position.x and bb.end.x <= bench_aabb.end.x and bb.position.z >= bench_aabb.position.z and bb.end.z <= bench_aabb.end.z and bb.position.y >= bench_aabb.end.y - 0.02 and bb.end.y <= bench_aabb.end.y + 0.05,
		"env: PawMark sobre o topo do banco (%s vs %s)" % [bb, bench_aabb])
	var pm := paw.mesh.surface_get_material(0) as BaseMaterial3D
	var bm := (root.find_child("Boat_Bench", true, false) as MeshInstance3D).mesh.surface_get_material(0) as BaseMaterial3D
	r.check(pm != null and pm.resource_name == "mat_env_paw", "env: PawMark usa mat_env_paw")
	var dl := absf(_lum(bm.albedo_color) - _lum(pm.albedo_color))
	r.check(dl >= 0.25, "env: contraste de luminancia marca x banco >= 0,25 (%.3f)" % dl)
	# pegada de bota no chao
	var bp := _load_scene("boot_print")
	var bpb := TA.mesh_aabb(bp)
	r.check(bpb.size.z >= 0.3 and bpb.size.x >= 0.12 and bpb.position.y >= -0.001 and bpb.end.y < 0.03, "env: BootPrint 0,3+ m, relevo raso (%s)" % [bpb.size])
	var bmat := TA.material_names(bp)
	r.check(bmat.has("mat_env_bootprint"), "env: BootPrint usa mat_env_bootprint")
	bp.free()
	root.free()


func _test_glb_folder(ids: Array) -> void:
	var extra: Array = []
	for f in DirAccess.get_files_at(GLB_DIR):
		if f.ends_with(".import") or f.ends_with(".uid") or f == "vertex_color_postimport.gd":
			continue
		if not f.ends_with(".glb") or not (f.trim_suffix(".glb") in ids):
			extra.append(f)
	r.check(extra.is_empty(), "env: pasta de modelos do ambiente so tem ativos do manifesto %s" % [extra])
	var js := TA.read_glb_json(_glb_path("boat_v2"))
	r.check(String((js.get("asset", {}) as Dictionary).get("generator", "")).contains("Blender"), "env: GLB do barco v2 gerado pelo Blender")
	var has_color := false
	for m in js.get("meshes", []):
		for p in (m as Dictionary).get("primitives", []):
			if ((p as Dictionary).get("attributes", {}) as Dictionary).has("COLOR_0"):
				has_color = true
	r.check(has_color, "env: GLB do barco v2 traz cor por vertice (COLOR_0)")
