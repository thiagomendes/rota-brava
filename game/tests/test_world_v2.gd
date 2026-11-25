extends RefCounted
## Vitrine "vila e cais v2" (RB-R1 W1): a cena carrega e monta sem erro, o layout gerado pelo Blender bate com o kit,
## todo material tem regra, as texturas tem mipmaps e o jogo nao referencia a vitrine.
## Nao comprova gosto, luz nem desempenho: isso e visto nas capturas (captures/mundo_v2/).

const SCENE := "res://lookdev/world_v2/world_v2.tscn"
const LAYOUT := "res://lookdev/world_v2/world_v2_layout.json"
const STATIC_GLB := "res://assets/models/environment_v2/wv2_static.glb"
const KIT_GLB := "res://assets/models/environment_v2/wv2_kit.glb"

var r


func run(runner) -> void:
	r = runner
	var layout := _test_layout()
	_test_kit(layout)
	_test_materials()
	_test_textures()
	_test_game_untouched()
	await _test_scene(layout)


func _test_layout() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	r.check(parsed is Dictionary, "wv2: layout legivel")
	if not (parsed is Dictionary):
		return {}
	var d := parsed as Dictionary
	r.check(bool(d.get("provisorio", false)), "wv2: layout marcado provisorio")
	var views: Dictionary = d.get("vistas", {})
	r.check(views.has("dock") and views.has("street") and views.has("plaza") and views.has("bank"), "wv2: 4 vistas baixas (cais, rua, praca, margem)")
	var ok_h := true
	for v: String in views:
		ok_h = ok_h and absf(float(((views[v] as Dictionary)["pos"] as Array)[1]) - 1.95) < 0.01
	r.check(ok_h, "wv2: vistas na altura da camera baixa (1,95 m)")
	r.check((d.get("trio", []) as Array).size() == 3, "wv2: trio v2 no cais")
	var path: Array = d.get("percurso", [])
	var dur := float((path[path.size() - 1] as Array)[0]) if not path.is_empty() else 0.0
	r.check(dur >= 20.0 and dur <= 30.0, "wv2: percurso fixo de 20 a 30 s (%.1f s)" % dur)
	r.check((d.get("luzes", []) as Array).size() >= 20, "wv2: luzes quentes locais no layout (%d)" % (d.get("luzes", []) as Array).size())
	return d


func _kit_meshes() -> Dictionary:
	var out: Dictionary = {}
	var s := (load(KIT_GLB) as PackedScene).instantiate()
	for n in s.find_children("kit_*", "MeshInstance3D", true, false):
		out[String(n.name).trim_prefix("kit_")] = (n as MeshInstance3D).mesh
	s.free()
	return out


func _test_kit(layout: Dictionary) -> void:
	var meshes := _kit_meshes()
	var kit: Dictionary = layout.get("kit", {})
	var missing: Array = []
	var total := 0
	for k: String in kit:
		total += (kit[k] as Array).size()
		if not meshes.has(k) or (meshes[k] as Mesh).get_surface_count() == 0:
			missing.append(k)
	r.check(missing.is_empty(), "wv2: toda peca do layout tem malha no kit %s" % [missing])
	r.check(total >= 1000, "wv2: densidade de aderecos/vegetacao instanciados (%d)" % total)
	for k in ["crate", "barrel_lid", "net_pile", "lamp_post", "bench", "stall_red", "tree_a", "bush_b", "grass_tuft", "flowers_a",
			"rope_coil", "life_ring", "cart", "pot_a"]:
		r.check(kit.has(k), "wv2: layout usa %s" % k)


func _test_materials() -> void:
	WV2Materials.unknown.clear()
	var names: Dictionary = {}
	for path in [STATIC_GLB, KIT_GLB]:
		var s := (load(path) as PackedScene).instantiate()
		for n in s.find_children("*", "MeshInstance3D", true, false):
			var m := (n as MeshInstance3D).mesh
			for i in m.get_surface_count():
				var mat := m.surface_get_material(i)
				if mat != null:
					names[mat.resource_name] = true
					WV2Materials.get_material(mat.resource_name)
		s.free()
	r.check(names.size() >= 15, "wv2: materiais do mundo v2 (%d)" % names.size())
	r.check(WV2Materials.unknown.is_empty(), "wv2: todo material wv2_* tem regra %s" % [WV2Materials.unknown.keys()])


func _test_textures() -> void:
	var no_mip: Array = []
	var count := 0
	for f in DirAccess.get_files_at("res://assets/textures/environment_v2"):
		if f.ends_with(".import") or f.ends_with(".uid"):
			continue
		count += 1
		var t := load("res://assets/textures/environment_v2/" + f) as Texture2D
		if t == null or not t.get_image().has_mipmaps():
			no_mip.append(f)
	r.check(count >= 30, "wv2: texturas cor + dados (%d)" % count)
	r.check(no_mip.is_empty(), "wv2: texturas com mipmaps (sem cintilar a distancia) %s" % [no_mip])


func _test_game_untouched() -> void:
	var hits: Array = []
	for dir in ["res://episodes/ep01", "res://episodes/ep01/world", "res://actors/environment"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd") or f.ends_with(".tscn"):
				if FileAccess.get_file_as_string(dir + "/" + f).contains("world_v2"):
					hits.append(f)
	r.check(hits.is_empty(), "wv2: o jogo nao referencia a vitrine %s" % [hits])


func _test_scene(layout: Dictionary) -> void:
	var packed := load(SCENE) as PackedScene
	r.check(packed != null, "wv2: cena da vitrine carrega")
	if packed == null:
		return
	var root := packed.instantiate() as Node3D
	r.tree.root.add_child(root)
	await r.frames(3)
	var st := root.get_node_or_null("Static")
	r.check(st != null and st.find_children("*", "MeshInstance3D", true, false).size() >= 5, "wv2: cenario fixo montado")
	var kit := root.get_node_or_null("Kit")
	r.check(kit != null and kit.get_child_count() == (layout.get("kit", {}) as Dictionary).size(), "wv2: um MultiMesh por peca do kit")
	var cam := root.get_node_or_null("Camera") as Camera3D
	r.check(cam != null and absf(cam.global_position.y - 1.95) < 0.01, "wv2: camera baixa do jogo na vista inicial")
	var lights := root.find_children("*", "OmniLight3D", true, false).size()
	r.check(lights >= 30, "wv2: luzes quentes locais criadas (%d)" % lights)
	var heroes := 0
	for n in root.get_children():
		if n.has_node("Model") and n.get_node("Model") is CharacterVisual:
			heroes += 1
	r.check(heroes == 3, "wv2: trio v2 em cena (%d)" % heroes)
	var env := root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	r.check(env != null and env.environment.ssao_enabled and env.environment.fog_enabled and env.environment.background_mode == Environment.BG_SKY,
		"wv2: ceu, SSAO e nevoa ligados")
	root.queue_free()
	await r.frames(2)
