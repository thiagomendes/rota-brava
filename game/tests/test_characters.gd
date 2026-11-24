extends RefCounted
## Personagens organicos (RB-04-chars): cenas, escala, origem nos pes, frente -Z, materiais, ossos, animacoes (nomes, duracao,
## loop), shape keys, ausencia de malha externa e MEDICOES: contato dos pes no `walk`, deslizamento e alcance da mao em
## `inspect_touch`. Mede cinematica do rig (posicao dos ossos), nao aparencia: o julgamento visual esta nas imagens.

const DIR := "res://actors/characters/"
const BONES := ["root", "hips", "spine", "chest", "neck", "head", "shoulder.L", "shoulder.R", "upper_arm.L", "upper_arm.R",
	"forearm.L", "forearm.R", "hand.L", "hand.R", "thigh.L", "thigh.R", "shin.L", "shin.R", "foot.L", "foot.R", "toe.L", "toe.R"]
const SHAPES := ["neutra", "atenta", "surpresa", "alegre", "blink"]
const LOOPS := ["idle", "walk", "idle_wheel"]
## Alvo da marca no banco no referencial do ator (Godot): 0,10 m a direita, 0,35 m de altura, 0,45 m a frente (-Z).
const TOUCH_TARGET := Vector3(0.10, 0.35, -0.45)

const CHARS := {
	"rastro": {"scene": "rastro_model", "glb": "res://assets/models/characters/rastro.glb", "root": "Rastro", "prefix": "Rastro",
		"anims": ["idle", "walk", "crouch", "inspect_touch", "look_to_leme", "react_surprise"],
		"materials": ["mat_rastro_skin", "mat_rastro_hair", "mat_rastro_shirt", "mat_rastro_vest", "mat_rastro_pants",
			"mat_rastro_leather", "mat_rastro_hat", "mat_rastro_iris", "mat_rastro_eye"]},
	"leme": {"scene": "leme_model", "glb": "res://assets/models/characters/leme.glb", "root": "Leme", "prefix": "Leme",
		"anims": ["idle", "walk", "idle_wheel", "steer_left", "steer_right", "react_horn"],
		"materials": ["mat_leme_skin", "mat_leme_hair", "mat_leme_shirt", "mat_leme_vest", "mat_leme_pants", "mat_leme_leather",
			"mat_leme_hat", "mat_leme_band", "mat_leme_scarf", "mat_leme_iris", "mat_leme_eye"]},
	"extra_a": {"scene": "extra_a", "glb": "res://assets/models/characters/extra_a.glb", "root": "ExtraA", "prefix": "ExtraA",
		"anims": ["idle", "walk"], "materials": ["mat_extra_a_skin", "mat_extra_a_hat", "mat_extra_a_shirt"]},
	"extra_b": {"scene": "extra_b", "glb": "res://assets/models/characters/extra_b.glb", "root": "ExtraB", "prefix": "ExtraB",
		"anims": ["idle", "walk"], "materials": ["mat_extra_b_skin", "mat_extra_b_hat", "mat_extra_b_shirt"]},
	"extra_c": {"scene": "extra_c", "glb": "res://assets/models/characters/extra_c.glb", "root": "ExtraC", "prefix": "ExtraC",
		"anims": ["idle", "walk"], "materials": ["mat_extra_c_skin", "mat_extra_c_hat", "mat_extra_c_shirt"]},
}

var r


func run(runner) -> void:
	r = runner
	for id in CHARS:
		await _test_static(id)
	await _test_walk_contact("rastro")
	await _test_walk_contact("leme")
	await _test_walk_contact("extra_a")
	await _test_inspect_touch()
	await _test_leme_wheel()
	await _test_loops_close("rastro")
	await _test_loops_close("leme")
	await _test_visual_api()
	_test_rastro_compat_scene()
	_test_no_foreign_models()


func _spawn(id: String) -> Node3D:
	var ps := load(DIR + String(CHARS[id]["scene"]) + ".tscn") as PackedScene
	if ps == null:
		return null
	var root := ps.instantiate() as Node3D
	r.tree.root.add_child(root)
	await r.frames(2)
	return root


static func _aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var n: Node = it[0]
		var t: Transform3D = it[1]
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var b: AABB = t * (n as MeshInstance3D).mesh.get_aabb()
			out = b if first else out.merge(b)
			first = false
		for c in n.get_children():
			if c is Node3D:
				stack.append([c, t * (c as Node3D).transform])
	return out


static func _part(root: Node3D, node_name: String) -> AABB:
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


func _materials(root: Node) -> Array:
	var names: Array = []
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m != null and not names.has(m.resource_name):
				names.append(m.resource_name)
	return names


func _test_static(id: String) -> void:
	var d: Dictionary = CHARS[id]
	var root := await _spawn(id)
	r.check(root != null, "chars: %s carrega" % id)
	if root == null:
		return
	r.check(root is CharacterBody3D and root.name == StringName(d["root"]), "chars: raiz %s e CharacterBody3D" % id)
	var vis := root.find_child("Model", false, false) as CharacterVisual
	r.check(vis != null, "chars: %s tem Model com CharacterVisual" % id)
	if vis == null:
		root.queue_free()
		return
	var box := _aabb(root)
	r.check(box.size.y >= 1.2 and box.size.y <= 1.4, "chars: altura de %s entre 1,2 e 1,4 m (%.3f)" % [id, box.size.y])
	r.check(absf(box.position.y) < 0.02, "chars: origem de %s nos pes (min Y = %.4f)" % [id, box.position.y])
	r.check(box.size.x < 1.0 and box.size.z < 1.0, "chars: %s cabe em 1 m (x %.2f, z %.2f)" % [id, box.size.x, box.size.z])
	var face := _part(root, d["prefix"] + "_Face")
	var head := _part(root, d["prefix"] + "_Head")
	r.check(face.get_center().z < head.get_center().z - 0.08, "chars: frente de %s em -Z (rosto z=%.3f, cabeca z=%.3f)" % [id, face.get_center().z, head.get_center().z])
	var mats := _materials(root)
	var miss: Array = []
	for m in d["materials"]:
		if not mats.has(m):
			miss.append(m)
	r.check(miss.is_empty(), "chars: materiais nomeados de %s presentes %s" % [id, miss])
	for m in mats:
		r.check(String(m).begins_with("mat_" + id + "_"), "chars: material %s segue o prefixo mat_%s_" % [m, id])
	if id == "rastro":
		r.check(mats.size() >= 6 and mats.size() <= 9, "chars: Rastro tem 6 a 9 materiais mat_rastro_* (%d)" % mats.size())
	var sk := vis.skeleton()
	r.check(sk != null, "chars: %s tem Skeleton3D" % id)
	if sk != null:
		var miss_b: Array = []
		for b in BONES:
			if sk.find_bone(b) < 0:
				miss_b.append(b)
		r.check(miss_b.is_empty(), "chars: ossos estaveis de %s presentes %s" % [id, miss_b])
	var skinned := 0
	for n in root.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).skin != null:
			skinned += 1
	r.check(skinned >= 8, "chars: malhas de %s com skin (%d)" % [id, skinned])
	for a in d["anims"]:
		r.check(vis.has_animation(StringName(a)), "chars: %s tem a animacao %s" % [id, a])
		r.check(vis.animation_length(StringName(a)) > 0.0, "chars: %s/%s tem duracao > 0 (%.3f s)" % [id, a, vis.animation_length(StringName(a))])
		r.check(vis.is_looping(StringName(a)) == (a in LOOPS), "chars: %s/%s com loop correto (%s)" % [id, a, vis.is_looping(StringName(a))])
	if "walk" in d["anims"]:
		r.check(absf(vis.animation_length(&"walk") - 1.0) < 0.01, "chars: walk de %s tem ciclo de 1,0 s (%.3f)" % [id, vis.animation_length(&"walk")])
	var fm := vis.face_mesh()
	var shapes: Array = []
	if fm != null:
		for i in fm.mesh.get_blend_shape_count():
			shapes.append(String(fm.mesh.get_blend_shape_name(i)))
	var miss_s: Array = []
	for s in SHAPES:
		if not shapes.has(s):
			miss_s.append(s)
	r.check(miss_s.is_empty(), "chars: shape keys do rosto de %s %s" % [id, shapes])
	# nenhuma malha fora do GLB do projeto
	var foreign := 0
	for n in root.find_children("*", "MeshInstance3D", true, false):
		if not (n as MeshInstance3D).mesh.resource_path.begins_with(String(d["glb"])):
			foreign += 1
	r.check(foreign == 0, "chars: toda malha de %s vem do GLB do projeto" % id)
	var txt := FileAccess.get_file_as_string(DIR + String(d["scene"]) + ".tscn")
	r.check(not txt.contains("ArrayMesh") and not txt.contains("BoxMesh") and not txt.contains("SphereMesh"), "chars: cena de %s nao tem malha propria" % id)
	r.check(txt.contains(String(d["glb"])), "chars: cena de %s referencia o GLB" % id)
	var col := false
	for s in root.find_children("*", "CollisionShape3D", true, false):
		if not vis.is_ancestor_of(s) and (s as CollisionShape3D).shape != null:
			col = true
	r.check(col, "chars: %s tem colisao simples fora do modelo importado" % id)
	r.check(root.has_meta("provisional"), "chars: %s marcado provisorio" % id)
	var js := _glb_json(String(d["glb"]))
	var tn: Array = []
	for m in js.get("meshes", []):
		var ex: Variant = (m as Dictionary).get("extras", {})
		if ex is Dictionary and (ex as Dictionary).has("targetNames"):
			tn.append_array((ex as Dictionary)["targetNames"])
	r.check(tn.has("atenta") and tn.has("blink"), "chars: GLB de %s declara targetNames %s" % [id, tn])
	r.check(String((js.get("asset", {}) as Dictionary).get("generator", "")).contains("Blender"), "chars: GLB de %s gerado pelo Blender" % id)
	var tris := _tri_count(root)
	var limit := 25000 if id in ["rastro", "leme"] else 14000
	r.check(tris > 2000 and tris <= limit, "chars: %s com %d triangulos (orcamento <= %d)" % [id, tris, limit])
	root.queue_free()
	await r.frames(1)


static func _glb_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var magic := f.get_32()
	f.get_32()
	f.get_32()
	var n := f.get_32()
	f.get_32()
	if magic != 0x46546C67:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_buffer(n).get_string_from_utf8())
	return parsed if parsed is Dictionary else {}


static func _tri_count(root: Node) -> int:
	var tris := 0
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (n as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			tris += (idx as PackedInt32Array).size() / 3 if idx != null else 0
	return tris


## walk: o ponto mais baixo dos pes fica a +-2 cm do chao em >= 80% dos quadros; o pe de apoio anda para tras na velocidade
## nominal (sem deslizar); o pe livre levanta.
func _test_walk_contact(id: String) -> void:
	var root := await _spawn(id)
	var vis := root.find_child("Model", false, false) as CharacterVisual
	var len := vis.animation_length(&"walk")
	var n := 30
	var ok := 0
	var worst := 0.0
	var maxlift := 0.0
	var pts: Array = []
	for i in n:
		vis.seek_clip(&"walk", len * i / n)
		var h := vis.lowest_foot_height()
		if absf(h) <= 0.02:
			ok += 1
		worst = maxf(worst, absf(h))
		var frame := {}
		for b in CharacterVisual.SOLE_BONES:
			frame[b] = vis.bone_position(b)
		pts.append(frame)
		maxlift = maxf(maxlift, maxf((frame[&"toe_tip.L"] as Vector3).y, (frame[&"toe_tip.R"] as Vector3).y))
	var frac := float(ok) / n
	r.check(frac >= 0.8, "chars: walk de %s com pe a +-2 cm do chao em %d%% dos quadros (pior %.1f mm)" % [id, int(frac * 100), worst * 1000])
	r.check(maxlift > 0.04, "chars: walk de %s levanta o pe livre (%.1f cm)" % [id, maxlift * 100])
	var dt := len / n
	var errs: Array = []
	for i in n:
		var a: Dictionary = pts[i]
		var b: Dictionary = pts[(i + 1) % n]
		for bone in CharacterVisual.SOLE_BONES:
			var pa: Vector3 = a[bone]
			var pb: Vector3 = b[bone]
			if pa.y < 0.006 and pb.y < 0.006:
				errs.append(absf((pb.z - pa.z) / dt - CharacterVisual.WALK_SPEED_MPS))
	var mean_err := 0.0
	for e in errs:
		mean_err += e
	mean_err /= maxf(errs.size(), 1.0)
	r.check(errs.size() >= 20 and mean_err < 0.12, "chars: pe de apoio de %s sem deslizar (%d amostras, erro medio %.3f m/s vs %.2f)" % [id, errs.size(), mean_err, CharacterVisual.WALK_SPEED_MPS])
	print("  medida walk %s: pes no chao %d%% dos quadros, pior %.1f mm, pe livre ate %.1f cm, deslize medio %.3f m/s" % [id, int(frac * 100), worst * 1000, maxlift * 100, mean_err])
	root.queue_free()
	await r.frames(1)


## inspect_touch: a ponta da mao direita (osso hand_tip.R) chega a TouchTarget (erro < 8 cm) no pico do toque, nao fica
## abaixo do plano do banco e o clipe termina como comecou (agachada).
func _test_inspect_touch() -> void:
	var root := await _spawn("rastro")
	var vis := root.find_child("Model", false, false) as CharacterVisual
	var len := vis.animation_length(&"inspect_touch")
	var n := 90
	var best := INF
	var best_t := 0.0
	var best_wrist := INF
	var min_y_near := INF
	for i in n + 1:
		var t := len * i / n
		vis.seek_clip(&"inspect_touch", t)
		var tip := vis.bone_position(&"hand_tip.R")
		var d := tip.distance_to(TOUCH_TARGET)
		if d < best:
			best = d
			best_t = t
			best_wrist = vis.bone_position(&"hand.R").distance_to(TOUCH_TARGET)
		if tip.z < -0.2:
			min_y_near = minf(min_y_near, tip.y)
	r.check(best < 0.08, "chars: inspect_touch alcanca a marca com a ponta da mao (erro %.1f mm, punho a %.1f cm, no instante %.2f s)" % [best * 1000, best_wrist * 100, best_t])
	r.check(best_t > 0.8 and best_t < 2.2, "chars: pico do toque no meio do clipe (%.2f s)" % best_t)
	r.check(min_y_near >= TOUCH_TARGET.y - 0.015, "chars: mao nao atravessa o plano do banco (y minimo da ponta perto do banco %.1f cm; plano a %.0f cm)" % [min_y_near * 100, TOUCH_TARGET.y * 100])
	vis.seek_clip(&"inspect_touch", 0.0)
	var p0 := vis.bone_position(&"hand.R")
	vis.seek_clip(&"inspect_touch", len)
	var p1 := vis.bone_position(&"hand.R")
	r.check(p0.distance_to(p1) < 0.02, "chars: inspect_touch retorna a pose inicial (%.1f mm)" % [p0.distance_to(p1) * 1000])
	for t in [0.0, best_t, len]:
		vis.seek_clip(&"inspect_touch", t)
		r.check(vis.foot_contact_error() < 0.02, "chars: inspect_touch com pes no chao em %.2f s (%.1f mm)" % [t, vis.foot_contact_error() * 1000])
	print("  medida inspect_touch: ponta da mao a %.1f mm da marca (punho %.1f cm) em %.2f s" % [best * 1000, best_wrist * 100, best_t])
	root.queue_free()
	await r.frames(1)


func _test_leme_wheel() -> void:
	var root := await _spawn("leme")
	var vis := root.find_child("Model", false, false) as CharacterVisual
	vis.seek_clip(&"idle_wheel", 0.0)
	var r0 := vis.bone_position(&"hand_tip.R")
	var l0 := vis.bone_position(&"hand_tip.L")
	r.check(absf(r0.z) > 0.15 and r0.z < 0.0 and l0.z < 0.0, "chars: idle_wheel de Leme com as maos a frente (-Z): R z=%.2f L z=%.2f" % [r0.z, l0.z])
	vis.seek_clip(&"steer_left", 0.5)
	var rl := vis.bone_position(&"hand_tip.R")
	vis.seek_clip(&"steer_right", 0.5)
	var rr := vis.bone_position(&"hand_tip.R")
	r.check(rl.distance_to(rr) > 0.12, "chars: steer_left e steer_right movem a mao em sentidos opostos (%.1f cm)" % [rl.distance_to(rr) * 100])
	r.check(rl.y > r0.y + 0.03 and rr.y < r0.y - 0.03, "chars: volante para a esquerda sobe a mao direita, para a direita desce (%.1f / %.1f cm)" % [(rl.y - r0.y) * 100, (rr.y - r0.y) * 100])
	vis.seek_clip(&"react_horn", 0.45)
	var rh := vis.bone_position(&"hand_tip.R")
	r.check(rh.y > r0.y + 0.1, "chars: react_horn ergue a mao direita (%.1f cm acima)" % [(rh.y - r0.y) * 100])
	root.queue_free()
	await r.frames(1)


func _test_loops_close(id: String) -> void:
	var root := await _spawn(id)
	var vis := root.find_child("Model", false, false) as CharacterVisual
	for clip in CHARS[id]["anims"]:
		if not (clip in LOOPS):
			continue
		var len := vis.animation_length(StringName(clip))
		vis.seek_clip(StringName(clip), 0.0)
		var a := {}
		for b in [&"hand.R", &"hand.L", &"head", &"foot.R", &"foot.L", &"hips"]:
			a[b] = vis.bone_position(b)
		vis.seek_clip(StringName(clip), len)
		var worst := 0.0
		for b in a:
			worst = maxf(worst, (a[b] as Vector3).distance_to(vis.bone_position(b)))
		r.check(worst < 0.003, "chars: %s/%s fecha o loop (quadro final = inicial, desvio %.2f mm)" % [id, clip, worst * 1000])
	root.queue_free()
	await r.frames(1)


func _test_visual_api() -> void:
	var root := await _spawn("rastro")
	var vis := root.find_child("Model", false, false) as CharacterVisual
	r.check(vis.play(&"walk"), "chars: play(walk) aceito")
	r.check(not vis.play(&"nao_existe"), "chars: play de animacao inexistente retorna false")
	r.check(vis.current_animation() == &"walk", "chars: animacao atual e walk")
	await r.frames(3)
	r.check(vis.play(&"idle", 1.0, 0.2) and vis.current_animation() == &"idle", "chars: crossfade para idle")
	for i in 20:
		await r.frames(1)
	vis.set_expression(&"surpresa")
	await r.frames(2)
	var fm := vis.face_mesh()
	var idx := fm.find_blend_shape_by_name("surpresa")
	r.check(fm.get_blend_shape_value(idx) > 0.9, "chars: set_expression(surpresa) ativa o shape key (%.2f)" % fm.get_blend_shape_value(idx))
	vis.set_expression(&"neutra")
	await r.frames(2)
	r.check(fm.get_blend_shape_value(idx) < 0.05, "chars: set_expression(neutra) desliga a surpresa")
	r.check(is_equal_approx(vis.walk_speed_scale(CharacterVisual.WALK_SPEED_MPS), 1.0), "chars: walk_speed_scale(velocidade nominal) = 1")
	root.queue_free()
	await r.frames(1)


func _test_rastro_compat_scene() -> void:
	var ps := load("res://actors/rastro/rastro.tscn") as PackedScene
	r.check(ps != null, "chars: res://actors/rastro/rastro.tscn (caminho antigo) carrega")
	if ps == null:
		return
	var n := ps.instantiate()
	r.check(n is CharacterBody3D and n.find_child("Model", false, false) is CharacterVisual, "chars: rastro.tscn herda rastro_model.tscn")
	n.free()


func _test_no_foreign_models() -> void:
	var files := DirAccess.get_files_at("res://assets/models/characters")
	var foreign: Array = []
	for f in files:
		if f.ends_with(".import") or f.ends_with(".uid"):
			continue
		if not (f in ["rastro.glb", "leme.glb", "extra_a.glb", "extra_b.glb", "extra_c.glb"]):
			foreign.append(f)
	r.check(foreign.is_empty(), "chars: pasta de personagens so tem GLB do manifesto %s" % [foreign])
	var man: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../source_art/manifest.json")))
	var ids: Array = []
	if man is Dictionary:
		for a in (man as Dictionary)["ativos"]:
			ids.append((a as Dictionary)["id"])
			var d := a as Dictionary
			if String(d["id"]) in CHARS:
				r.check(int(d.get("quantidade_ossos", 0)) >= 22 and (d.get("animacoes_duracao_s", {}) as Dictionary).size() >= 2 and (d.get("shape_keys", []) as Array).has("blink"),
					"chars: manifesto de %s registra ossos, animacoes e shape keys" % d["id"])
	for id in CHARS:
		r.check(ids.has(id), "chars: manifesto lista %s" % id)

