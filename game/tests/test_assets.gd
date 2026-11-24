extends RefCounted
## Ativos 3D (RB-03-art): cenas proprias que instanciam os GLB gerados por source_art/scripts (Blender).
## Confere nos, escala em metros, origem, frente em -Z, materiais, shape keys, colisao fora do importado e proveniencia.
## Nao comprova gosto nem aparencia: so contrato tecnico.

const RASTRO_SCENE := "res://actors/rastro/rastro.tscn"   # herda actors/characters/rastro_model.tscn
const BOAT_SCENE := "res://actors/boat_model/boat_model.tscn"
const RASTRO_GLB := "res://assets/models/characters/rastro.glb"
const BOAT_GLB := "res://assets/models/boat.glb"

## RB-R1: Rastro refeito como crianca-heroi (hero_build.py).
const RASTRO_NODES := ["Rastro_Head", "Rastro_Face", "Rastro_Hat", "Rastro_HatBand", "Rastro_Hair", "Rastro_Jacket", "Rastro_Collar",
	"Rastro_Emblem", "Rastro_EmblemStar", "Rastro_Pants", "Rastro_BootL", "Rastro_BootR", "Rastro_SoleL", "Rastro_SoleR", "Rastro_HandL",
	"Rastro_HandR", "Rastro_Notebook", "Rastro_Bag", "Rastro_Belt", "Rastro_Buckle", "Rastro_Lupa", "Skeleton3D", "AnimationPlayer"]
const RASTRO_MATERIALS := ["mat_rastro_pele", "mat_rastro_cabelo", "mat_rastro_olhos", "mat_rastro_iris", "mat_rastro_escuro",
	"mat_rastro_boca", "mat_rastro_uniforme", "mat_rastro_creme", "mat_rastro_calca", "mat_rastro_chapeu", "mat_rastro_couro",
	"mat_rastro_botas", "mat_rastro_emblema", "mat_rastro_ouro", "mat_rastro_rubor", "mat_rastro_vidro"]
const BOAT_NODES := ["Boat_Hull", "Boat_Deck", "Boat_Cabin", "Boat_CabinRoof", "Boat_Bench", "Boat_Helm", "Boat_Windows",
	"DeckPoint", "BenchMark"]
const BOAT_MATERIALS := ["mat_boat_hull", "mat_boat_deck", "mat_boat_cabin", "mat_boat_bench", "mat_boat_wheel", "mat_boat_glass"]

var r


## AABB (no referencial de `root`) somando os MeshInstance3D descendentes.
static func mesh_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var n: Node = it[0]
		var t: Transform3D = it[1]
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var box: AABB = t * (n as MeshInstance3D).mesh.get_aabb()
			out = box if first else out.merge(box)
			first = false
		for c in n.get_children():
			if c is Node3D:
				stack.append([c, t * (c as Node3D).transform])
	return out


static func part_aabb(root: Node, node_name: String) -> AABB:
	var n := root.find_child(node_name, true, false) as MeshInstance3D
	if n == null:
		return AABB()
	var t := Transform3D.IDENTITY
	var p: Node = n
	while p != null and p != root:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t * n.mesh.get_aabb()


static func material_names(root: Node) -> Array:
	var names: Array = []
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m != null and not names.has(m.resource_name):
				names.append(m.resource_name)
	return names


static func read_glb_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var magic := f.get_32()
	f.get_32()
	f.get_32()
	var len := f.get_32()
	f.get_32()
	if magic != 0x46546C67:
		return {}
	var txt := f.get_buffer(len).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


func _missing(root: Node, names: Array) -> Array:
	var out: Array = []
	for n in names:
		if root.find_child(n, true, false) == null:
			out.append(n)
	return out


func _meshes_from_glb_only(scene_root: Node, glb: String) -> bool:
	for n in scene_root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.mesh.resource_path.begins_with(glb):
			printerr("  malha fora do GLB: ", n.name, " -> ", mi.mesh.resource_path)
			return false
	return true


func _scene_text_only_glb(path: String, glb: String) -> bool:
	var txt := FileAccess.get_file_as_string(path)
	if txt.contains("sub_resource type=\"ArrayMesh\"") or txt.contains("type=\"ArrayMesh\"") or txt.contains("type=\"BoxMesh\""):
		return false
	for line in txt.split("\n"):
		if line.begins_with("[ext_resource") and not line.contains("path=\"" + glb + "\""):
			return false
	return true


func _has_collision_outside(scene_root: Node) -> bool:
	var model := scene_root.find_child("Model", false, false)
	var shapes := scene_root.find_children("*", "CollisionShape3D", true, false)
	if shapes.is_empty() or model == null:
		return false
	for s in shapes:
		if model.is_ancestor_of(s):
			return false
		if (s as CollisionShape3D).shape == null:
			return false
	return true


func run(runner) -> void:
	r = runner
	_test_manifest()
	_test_rastro()
	_test_boat()
	_test_external_meshes()


func _test_rastro() -> void:
	# O Rastro organico (rig, animacoes, medicoes) e coberto por test_characters.gd; aqui fica o contrato do caminho antigo.
	var ps := load(RASTRO_SCENE) as PackedScene
	r.check(ps != null, "assets: rastro.tscn carrega")
	if ps == null:
		return
	var root := ps.instantiate() as Node3D
	r.check(root is CharacterBody3D and root.name == &"Rastro", "assets: raiz Rastro e CharacterBody3D")
	var missing := _missing(root, RASTRO_NODES)
	r.check(missing.is_empty(), "assets: nos estaveis do Rastro presentes %s" % [missing])
	var model := root.find_child("Model", false, false) as Node3D
	r.check(model != null and model.get_script() != null, "assets: Rastro tem Model com script CharacterVisual")
	var box := mesh_aabb(root)
	r.check(box.size.y >= 1.0 and box.size.y <= 1.2, "assets: altura do Rastro (crianca-heroi) entre 1,0 e 1,2 m (%.3f)" % box.size.y)
	r.check(absf(box.position.y) < 0.02, "assets: origem do Rastro nos pes (min Y = %.4f)" % box.position.y)
	var face := part_aabb(root, "Rastro_Face")
	var head := part_aabb(root, "Rastro_Head")
	r.check(face.get_center().z < head.get_center().z - 0.08, "assets: frente do Rastro em -Z (rosto z=%.3f, cabeca z=%.3f)" % [face.get_center().z, head.get_center().z])
	var mats := material_names(model)
	var miss_m: Array = []
	for m in RASTRO_MATERIALS:
		if not mats.has(m):
			miss_m.append(m)
	r.check(miss_m.is_empty(), "assets: materiais nomeados do Rastro presentes %s" % [miss_m])
	r.check(mats.size() == RASTRO_MATERIALS.size(), "assets: Rastro tem %d materiais (esperado %d)" % [mats.size(), RASTRO_MATERIALS.size()])
	var face_mi := model.find_child("Rastro_Face", true, false) as MeshInstance3D
	var shapes: Array = []
	if face_mi != null:
		for i in face_mi.mesh.get_blend_shape_count():
			shapes.append(String(face_mi.mesh.get_blend_shape_name(i)))
	r.check(shapes.has("atenta") and shapes.has("surpresa") and shapes.has("alegre") and shapes.has("blink"), "assets: shape keys do rosto importadas na Godot %s" % [shapes])
	var js := read_glb_json(RASTRO_GLB)
	var names_in_glb: Array = []
	for m in js.get("meshes", []):
		var ex: Variant = (m as Dictionary).get("extras", {})
		if ex is Dictionary and (ex as Dictionary).has("targetNames"):
			names_in_glb.append_array((ex as Dictionary)["targetNames"])
	r.check(names_in_glb.has("atenta") and names_in_glb.has("surpresa"), "assets: GLB do Rastro declara targetNames atenta/surpresa %s" % [names_in_glb])
	r.check(String((js.get("asset", {}) as Dictionary).get("generator", "")).contains("Blender"), "assets: GLB do Rastro gerado pelo Blender")
	r.check(not model.find_children("*", "Skeleton3D", true, false).is_empty() and not model.find_children("*", "AnimationPlayer", true, false).is_empty(), "assets: Rastro tem rig (Skeleton3D) e AnimationPlayer (RB-04)")
	r.check(_has_collision_outside(root), "assets: colisao do Rastro existe e fica fora da cena importada")
	var cap := (root.find_child("Collision", false, false) as CollisionShape3D).shape as CapsuleShape3D
	r.check(cap != null and cap.height >= 1.0 and cap.height <= 1.5, "assets: capsula do Rastro com altura compativel")
	r.check(root.has_meta("provisional"), "assets: Rastro marcado como provisorio")
	var imported := (load(RASTRO_GLB) as PackedScene).instantiate()
	r.check(imported.find_children("*", "CollisionObject3D", true, false).is_empty() and imported.find_children("*", "CollisionShape3D", true, false).is_empty(), "assets: GLB do Rastro nao traz colisao")
	imported.free()
	root.free()

func _test_boat() -> void:
	var ps := load(BOAT_SCENE) as PackedScene
	r.check(ps != null, "assets: boat_model.tscn carrega")
	if ps == null:
		return
	var root := ps.instantiate() as Node3D
	var missing := _missing(root, BOAT_NODES)
	r.check(missing.is_empty(), "assets: nos estaveis do barco presentes %s" % [missing])
	var model := root.find_child("Model", false, false) as Node3D
	var hull := part_aabb(root, "Boat_Hull")
	r.check(absf(hull.size.x - 2.2) < 0.05, "assets: boca do barco ~2,2 m (%.3f)" % hull.size.x)
	r.check(absf(hull.size.z - 5.0) < 0.05, "assets: comprimento do barco ~5,0 m (%.3f)" % hull.size.z)
	r.check(hull.position.z < -2.5 and hull.end.z > 1.5, "assets: proa em -Z (z de %.2f a %.2f)" % [hull.position.z, hull.end.z])
	var frac := hull.end.z / hull.size.z
	r.check(absf(frac - 0.4) < 0.02, "assets: pivo a 40%% do comprimento a partir da popa (%.3f)" % frac)
	r.check(absf((hull.position.x + hull.end.x) * 0.5) < 0.01, "assets: pivo sobre o eixo longitudinal")
	var mats := material_names(model)
	var miss_m: Array = []
	for m in BOAT_MATERIALS:
		if not mats.has(m):
			miss_m.append(m)
	r.check(miss_m.is_empty(), "assets: materiais nomeados do barco presentes %s" % [miss_m])
	var hull_mi := model.find_child("Boat_Hull", true, false) as MeshInstance3D
	var hull_mat := hull_mi.mesh.surface_get_material(0) as BaseMaterial3D
	var want := Color("f5c518")
	var got: Color = hull_mat.albedo_color if hull_mat != null else Color.BLACK
	r.check(absf(got.r - want.r) < 0.03 and absf(got.g - want.g) < 0.03 and absf(got.b - want.b) < 0.03, "assets: casco amarelo #F5C518 (lido: #%s)" % got.to_html(false))
	var deck := model.find_child("DeckPoint", true, false) as Node3D
	var bench := model.find_child("BenchMark", true, false) as Node3D
	r.check(deck != null and deck.position.y > 0.3 and deck.position.y < 0.6, "assets: DeckPoint sobre o conves")
	r.check(bench != null and bench.position.z < 0.0 and bench.position.y > deck.position.y, "assets: BenchMark no banco, a vante do pivo (-Z) e acima do conves")
	r.check(_has_collision_outside(root), "assets: colisao do barco existe e fica fora da cena importada")
	var cols := root.find_children("*", "CollisionShape3D", true, false)
	var shape: BoxShape3D = (cols[0] as CollisionShape3D).shape as BoxShape3D if not cols.is_empty() else null
	r.check(shape != null and absf(shape.size.x - 2.2) < 0.05 and absf(shape.size.z - 5.0) < 0.05, "assets: caixa de colisao do barco ~2,2 x 5,0 m")
	r.check(root.find_child("PivotMark", false, false) != null, "assets: PivotMark presente")
	r.check(root.has_meta("provisional"), "assets: barco marcado como provisorio")
	r.check(_scene_text_only_glb(BOAT_SCENE, BOAT_GLB), "assets: boat_model.tscn so referencia o GLB (sem malha propria)")
	var imported := (load(BOAT_GLB) as PackedScene).instantiate()
	r.check(imported.find_children("*", "CollisionObject3D", true, false).is_empty(), "assets: GLB do barco nao traz colisao")
	imported.free()
	root.free()


func _test_external_meshes() -> void:
	for pair in [[BOAT_SCENE, BOAT_GLB]]:
		var root := (load(pair[0]) as PackedScene).instantiate()
		r.check(_meshes_from_glb_only(root, pair[1]), "assets: toda malha de %s vem do GLB do projeto" % pair[0])
		var outside := 0
		var model := root.find_child("Model", false, false)
		for n in root.find_children("*", "MeshInstance3D", true, false):
			if not model.is_ancestor_of(n):
				outside += 1
		r.check(outside == 0, "assets: %s nao tem MeshInstance3D fora do Model" % pair[0])
		root.free()
	# so GLB do projeto na pasta de modelos
	var files := DirAccess.get_files_at("res://assets/models")
	var foreign: Array = []
	for f in files:
		if f.ends_with(".import") or f.ends_with(".uid"):
			continue
		if not (f in ["boat.glb"]):
			foreign.append(f)
	r.check(foreign.is_empty(), "assets: pasta de modelos so tem ativos do manifesto %s" % [foreign])


func _test_manifest() -> void:
	var path := ProjectSettings.globalize_path("res://").path_join("../source_art/manifest.json")
	var txt := FileAccess.get_file_as_string(path)
	var man: Variant = JSON.parse_string(txt)
	r.check(man is Dictionary and (man as Dictionary).has("ativos"), "assets: manifesto source_art/manifest.json legivel")
	if not (man is Dictionary):
		return
	for a in (man as Dictionary)["ativos"]:
		var d := a as Dictionary
		r.check(d.get("agente") == "art3d" and d.get("status") == "provisorio", "assets: manifesto %s com agente art3d e status provisorio" % d.get("id"))
		if not d.has("saida_glb"):
			# ativos sem GLB (RB-R1: retratos do HUD): cada arquivo listado existe e confere o sha256
			var bad: Array = []
			var files: Dictionary = d.get("arquivos_sha256", {})
			for fname in files:
				var fp := ProjectSettings.globalize_path("res://").path_join("../" + String(d.get("saida", "")) + "/" + String(fname))
				if FileAccess.get_sha256(fp) != String(files[fname]):
					bad.append(fname)
			r.check(files.size() > 0 and bad.is_empty(), "assets: arquivos do manifesto conferem (%s) %s" % [d.get("id"), bad])
			continue
		var glb: String = d.get("saida_glb", "")
		var abs_glb := ProjectSettings.globalize_path("res://").path_join("../" + glb)
		r.check(FileAccess.file_exists(abs_glb), "assets: GLB %s existe" % glb)
		r.check(FileAccess.get_sha256(abs_glb) == String(d.get("glb_sha256", "")), "assets: sha256 do GLB confere com o manifesto (%s)" % d.get("id"))
		var missing_src: Array = []
		for s in d.get("origem", []):
			if not FileAccess.file_exists(ProjectSettings.globalize_path("res://").path_join("../" + String(s))):
				missing_src.append(s)
		r.check(missing_src.is_empty(), "assets: arquivos de origem do manifesto existem (%s) %s" % [d.get("id"), missing_src])
		r.check(int(d.get("triangulos", 0)) > 0 and (d.get("materiais", []) as Array).size() > 0, "assets: manifesto registra triangulos e materiais (%s)" % d.get("id"))



