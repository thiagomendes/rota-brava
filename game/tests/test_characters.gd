extends RefCounted
## Personagens organicos (RB-04-chars): cenas, escala, origem nos pes, frente -Z, materiais, ossos, animacoes (nomes, duracao,
## loop), shape keys, ausencia de malha externa e MEDICOES: contato dos pes no `walk`, deslizamento e alcance da mao em
## `inspect_touch`. Mede cinematica do rig (posicao dos ossos), nao aparencia: o julgamento visual esta nas imagens.

const DIR := "res://actors/characters/"
const BONES := ["root", "hips", "spine", "chest", "neck", "head", "shoulder.L", "shoulder.R", "upper_arm.L", "upper_arm.R",
	"forearm.L", "forearm.R", "hand.L", "hand.R", "thigh.L", "thigh.R", "shin.L", "shin.R", "foot.L", "foot.R", "toe.L", "toe.R"]
const SHAPES := ["neutra", "atenta", "surpresa", "alegre", "blink"]
const LOOPS := ["idle", "walk", "run", "idle_wheel"]
## RB-R1: rosto do Rastro (expressoes + visemas da fala + olhar).
const RASTRO_SHAPES := ["neutra", "atenta", "surpresa", "alegre", "triste", "brava_leve", "blink", "mouth_A", "mouth_E", "mouth_O",
	"mouth_M", "look_left", "look_right", "look_up"]
const RASTRO_ANIMS := ["idle", "walk", "run", "stop", "crouch", "inspect_touch", "look_to_leme", "react_surprise", "point", "wave",
	"celebrate", "team_pose"]

const CHARS := {
	"rastro": {"scene": "rastro_model", "glb": "res://assets/models/characters/rastro.glb", "root": "Rastro", "prefix": "Rastro",
		"anims": RASTRO_ANIMS, "shapes": RASTRO_SHAPES, "height": [1.0, 1.2], "tris": [12000, 20000],
		"materials": ["mat_rastro_pele", "mat_rastro_cabelo", "mat_rastro_olhos", "mat_rastro_iris", "mat_rastro_uniforme",
			"mat_rastro_creme", "mat_rastro_chapeu", "mat_rastro_couro", "mat_rastro_botas", "mat_rastro_emblema", "mat_rastro_boca"]},
	"leme": {"scene": "leme_model", "glb": "res://assets/models/characters/leme.glb", "root": "Leme", "prefix": "Leme",
		"anims": ["idle", "walk", "idle_wheel", "steer_left", "steer_right", "react_horn"],
		"materials": ["mat_leme_skin", "mat_leme_hair", "mat_leme_shirt", "mat_leme_vest", "mat_leme_pants", "mat_leme_leather",
			"mat_leme_hat", "mat_leme_band", "mat_leme_scarf", "mat_leme_iris", "mat_leme_eye"]},
	"pico": {"scene": "pico_model", "glb": "res://assets/models/characters/pico.glb", "root": "Pico", "prefix": "Pico",
		"anims": ["idle", "walk", "react_surprise", "pull_rope", "look_up"],
		"materials": ["mat_pico_skin", "mat_pico_hair", "mat_pico_shirt", "mat_pico_vest", "mat_pico_pants", "mat_pico_leather", "mat_pico_hat",
			"mat_pico_rope", "mat_pico_metal", "mat_pico_iris", "mat_pico_eye"]},
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
	await _test_gait_contact("rastro", &"run")
	await _test_rastro_child()
	await _test_walk_contact("leme")
	await _test_walk_contact("extra_a")
	await _test_walk_contact("pico")
	for id in ["extra_a", "extra_b", "extra_c", "pico", "rastro", "leme"]:
		await _test_idle_upright(id)
	await _test_pico()
	await _test_member_actor_idle()
	await _test_inspect_real_pawmark()
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
	var hr: Array = d.get("height", [1.2, 1.4])
	r.check(box.size.y >= float(hr[0]) and box.size.y <= float(hr[1]), "chars: altura de %s entre %.1f e %.1f m (%.3f)" % [id, hr[0], hr[1], box.size.y])
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
		r.check(mats.size() >= 11 and mats.size() <= 18, "chars: Rastro tem 11 a 18 materiais mat_rastro_* (%d)" % mats.size())
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
	for s in d.get("shapes", SHAPES):
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
	var limit := 25000 if id in ["rastro", "leme", "pico"] else 14000
	r.check(tris > 2000 and tris <= limit, "chars: %s com %d triangulos (orcamento <= %d)" % [id, tris, limit])
	if d.has("tris"):
		var tb: Array = d["tris"]
		r.check(tris >= int(tb[0]) and tris <= int(tb[1]), "chars: %s na faixa de %d a %d triangulos (%d)" % [id, tb[0], tb[1], tris])
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
	await _test_gait_contact(id, &"walk")


## walk/run: pe a +-2 cm do chao em >= 80% dos quadros, pe livre levanta, pe de apoio na velocidade nominal do modelo.
func _test_gait_contact(id: String, clip: StringName) -> void:
	var root := await _spawn(id)
	var vis := root.find_child("Model", false, false) as CharacterVisual
	var nominal := vis.walk_speed_mps if clip == &"walk" else vis.run_speed_mps
	r.check(vis.has_animation(clip) and nominal > 0.0, "chars: %s tem %s com velocidade nominal (%.3f m/s)" % [id, clip, nominal])
	var len := vis.animation_length(clip)
	var n := 30
	var ok := 0
	var worst := 0.0
	var maxlift := 0.0
	var pts: Array = []
	for i in n:
		vis.seek_clip(clip, len * i / n)
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
	r.check(frac >= 0.8, "chars: %s de %s com pe a +-2 cm do chao em %d%% dos quadros (pior %.1f mm)" % [clip, id, int(frac * 100), worst * 1000])
	r.check(maxlift > 0.04, "chars: %s de %s levanta o pe livre (%.1f cm)" % [clip, id, maxlift * 100])
	var dt := len / n
	var errs: Array = []
	for i in n:
		var a: Dictionary = pts[i]
		var b: Dictionary = pts[(i + 1) % n]
		for bone in CharacterVisual.SOLE_BONES:
			var pa: Vector3 = a[bone]
			var pb: Vector3 = b[bone]
			if pa.y < 0.006 and pb.y < 0.006:
				errs.append(absf((pb.z - pa.z) / dt - nominal))
	var mean_err := 0.0
	for e in errs:
		mean_err += e
	mean_err /= maxf(errs.size(), 1.0)
	r.check(errs.size() >= 12 and mean_err < 0.12 * maxf(nominal / 0.586, 1.0), "chars: pe de apoio de %s no %s sem deslizar (%d amostras, erro medio %.3f m/s vs %.2f)" % [id, clip, errs.size(), mean_err, nominal])
	print("  medida %s %s: pes no chao %d%% dos quadros, pior %.1f mm, pe livre ate %.1f cm, deslize medio %.3f m/s" % [clip, id, int(frac * 100), worst * 1000, maxlift * 100, mean_err])
	root.queue_free()
	await r.frames(1)


## inspect_touch NA POSICAO REAL (RB-R1, defeito herdado): barco BoatActor (modelo boat_v2) atracado em BOAT_DOCKED_POS/HEADING,
## Rastro (MemberActor) embarcado em PAW_INSPECT_STAND_LOCAL olhando para +Z do barco, como faz o dock_stage.gd. A ponta da mao
## (hand_tip.R) chega ao centro da malha PawMark do GLB com erro < 6 cm, nunca desce abaixo do topo do banco e o clipe volta ao inicio.
func _test_inspect_real_pawmark() -> void:
	var boat := BoatActor.new()
	r.tree.root.add_child(boat)
	boat.place(Ep01Layout.BOAT_DOCKED_POS, Ep01Layout.BOAT_DOCKED_HEADING)
	await r.frames(2)
	var paw := boat.find_child("PawMark", true, false) as MeshInstance3D
	var bench := boat.find_child("Boat_Bench", true, false) as MeshInstance3D
	r.check(paw != null and bench != null, "chars: boat_v2 tem PawMark e Boat_Bench")
	if paw == null or bench == null:
		boat.queue_free()
		return
	var center := paw.global_transform * paw.mesh.get_aabb().get_center()
	var bench_box: AABB = bench.global_transform * bench.mesh.get_aabb()
	var bench_top := bench_box.end.y
	var a := MemberActor.new()
	r.tree.root.add_child(a)
	a.setup(&"tracker")
	a.ride_briefly(boat, Ep01Layout.PAW_INSPECT_STAND_LOCAL)
	a.face_now(boat.to_global(Ep01Layout.PAW_INSPECT_STAND_LOCAL + Vector3(0, 0, 1)))
	await r.frames(2)
	var vis := a.model
	var len := vis.animation_length(&"inspect_touch")
	var n := 90
	var best := INF
	var best_t := 0.0
	var min_over_bench := INF
	for i in n + 1:
		var t := len * i / n
		vis.seek_clip(&"inspect_touch", t)
		var tip := vis.bone_position(&"hand_tip.R")
		var d := tip.distance_to(center)
		if d < best:
			best = d
			best_t = t
		if tip.x > bench_box.position.x and tip.x < bench_box.end.x and tip.z > bench_box.position.z and tip.z < bench_box.end.z:
			min_over_bench = minf(min_over_bench, tip.y)
	r.check(best < 0.06, "chars: inspect_touch toca o centro REAL da PawMark (erro %.1f mm em %.2f s; centro %s)" % [best * 1000, best_t, center])
	r.check(best_t > 0.8 and best_t < 2.2, "chars: pico do toque no meio do clipe (%.2f s)" % best_t)
	r.check(min_over_bench >= bench_top - 0.005, "chars: ponta da mao nao atravessa o banco (minimo %.1f cm; topo do banco %.1f cm)" % [min_over_bench * 100, bench_top * 100])
	vis.seek_clip(&"inspect_touch", 0.0)
	var p0 := vis.bone_position(&"hand.R")
	vis.seek_clip(&"inspect_touch", len)
	r.check(p0.distance_to(vis.bone_position(&"hand.R")) < 0.02, "chars: inspect_touch retorna a pose inicial")
	var feet_ok := true
	for t in [0.0, best_t, len]:
		vis.seek_clip(&"inspect_touch", t)
		feet_ok = feet_ok and vis.foot_contact_error() < 0.02
	r.check(feet_ok, "chars: inspect_touch com pes no conves (inicio, toque, fim)")
	print("  medida inspect_touch REAL: ponta da mao a %.1f mm do centro da PawMark %s em %.2f s; ponta minima sobre o banco %.3f m (topo %.3f m)" % [best * 1000, center, best_t, min_over_bench, bench_top])
	a.queue_free()
	boat.queue_free()
	await r.frames(1)


## RB-R1: barra de crianca-heroi do Rastro: altura 1,0-1,2 m, cabeca 33-38% da altura, olhos (esclera, iris, pupila), visemas,
## olhar, 12 clipes nomeados com loop correto, corrida de ~0,6 s.
func _test_rastro_child() -> void:
	var root := await _spawn("rastro")
	var vis := root.find_child("Model", false, false) as CharacterVisual
	var box := _aabb(root)
	var head := _part(root, "Rastro_Head")
	var ratio := head.size.y / box.size.y
	r.check(ratio >= 0.33 and ratio <= 0.38, "chars: cabeca do Rastro com %.1f%% da altura (33 a 38%%; cabeca %.3f m, altura %.3f m)" % [ratio * 100, head.size.y, box.size.y])
	var fm := vis.face_mesh()
	var fmats: Array = []
	for s in fm.mesh.get_surface_count():
		fmats.append(fm.mesh.surface_get_material(s).resource_name)
	for m in ["mat_rastro_olhos", "mat_rastro_iris", "mat_rastro_escuro", "mat_rastro_boca"]:
		r.check(fmats.has(m), "chars: rosto do Rastro tem %s (olhos/iris/pupila/boca)" % m)
	for a in RASTRO_ANIMS:
		r.check(vis.has_animation(StringName(a)), "chars: Rastro tem o clipe %s" % a)
	r.check(absf(vis.animation_length(&"run") - 0.6) < 0.05, "chars: run do Rastro com ciclo de ~0,6 s (%.3f)" % vis.animation_length(&"run"))
	r.check(absf(vis.animation_length(&"team_pose") - 1.5) < 0.05, "chars: team_pose do Rastro dura 1,5 s (%.3f)" % vis.animation_length(&"team_pose"))
	vis.set_viseme(&"mouth_A", 1.0)
	var ia := fm.find_blend_shape_by_name("mouth_A")
	r.check(ia >= 0 and fm.get_blend_shape_value(ia) > 0.99, "chars: set_viseme(mouth_A) abre a boca")
	vis.set_viseme(&"mouth_O", 0.7)
	r.check(fm.get_blend_shape_value(ia) < 0.01 and fm.get_blend_shape_value(fm.find_blend_shape_by_name("mouth_O")) > 0.69, "chars: set_viseme troca de visema")
	vis.set_viseme(&"")
	vis.set_gaze(Vector2(-1, 0.5))
	r.check(fm.get_blend_shape_value(fm.find_blend_shape_by_name("look_left")) > 0.99 and fm.get_blend_shape_value(fm.find_blend_shape_by_name("look_up")) > 0.49, "chars: set_gaze move os olhos para a esquerda e para cima")
	vis.set_gaze(Vector2.ZERO)
	print("  medida Rastro: altura %.3f m, cabeca %.3f m (%.1f%%), %d triangulos" % [box.size.y, head.size.y, ratio * 100, _tri_count(root)])
	root.queue_free()
	await r.frames(1)

## idle: em pe. Tronco (quadril -> cabeca) com inclinacao < 8 graus no quadro 0 e ao longo do ciclo, pes no chao e juntos.
func _test_idle_upright(id: String) -> void:
	var root := await _spawn(id)
	var vis := root.find_child("Model", false, false) as CharacterVisual
	var worst_tilt := 0.0
	var worst_foot := 0.0
	var tilt0 := 0.0
	var gap := 0.0
	var len := vis.animation_length(&"idle")
	for i in 25:
		vis.seek_clip(&"idle", len * i / 24.0)
		var h := vis.bone_position(&"hips")
		var hd := vis.bone_position(&"head")
		var tilt := rad_to_deg(atan2(Vector2(hd.x - h.x, hd.z - h.z).length(), hd.y - h.y))
		if i == 0:
			tilt0 = tilt
		worst_tilt = maxf(worst_tilt, tilt)
		worst_foot = maxf(worst_foot, vis.foot_contact_error())
		gap = maxf(gap, absf(vis.bone_position(&"heel.R").x - vis.bone_position(&"heel.L").x))
	var limit := 8.0 if id != "rastro" else 12.0   # o Rastro observa inclinada de proposito
	r.check(tilt0 < limit, "chars: idle de %s em pe, tronco a %.1f graus no quadro 0 (limite %.0f)" % [id, tilt0, limit])
	r.check(worst_tilt < limit, "chars: idle de %s nunca passa de %.1f graus de inclinacao" % [id, worst_tilt])
	r.check(worst_foot < 0.01, "chars: idle de %s com pes no chao (pior %.1f mm)" % [id, worst_foot * 1000])
	r.check(gap < 0.30, "chars: idle de %s com pes juntos/levemente afastados (%.1f cm entre calcanhares)" % [id, gap * 100])
	print("  medida idle %s: tronco %.1f graus (quadro 0), pior %.1f graus, pe a %.1f mm do chao, calcanhares a %.1f cm" % [id, tilt0, worst_tilt, worst_foot * 1000, gap * 100])
	root.queue_free()
	await r.frames(1)


## Pico: pull_rope dura 1,6 s e tem exatamente dois puxoes (maos descem duas vezes); look_up levanta a cabeca; mochila/corda no modelo.
func _test_pico() -> void:
	var root := await _spawn("pico")
	var vis := root.find_child("Model", false, false) as CharacterVisual
	r.check(absf(vis.animation_length(&"pull_rope") - 1.6) < 0.05, "chars: pull_rope do Pico dura 1,6 s (%.3f)" % vis.animation_length(&"pull_rope"))
	var len := vis.animation_length(&"pull_rope")
	var ys: Array = []
	var zs: Array = []
	for i in 49:
		vis.seek_clip(&"pull_rope", len * i / 48.0)
		var tip := vis.bone_position(&"hand_tip.R")
		ys.append(tip.y)
		zs.append(tip.z)
	var ymax: float = ys.max()
	var ymin: float = ys.min()
	var pulls := 0
	for i in range(1, ys.size() - 1):
		var y: float = ys[i]
		if y < ys[i - 1] and y <= ys[i + 1] and y > 0.55 and y < 0.85 and (float(ys[maxi(i - 6, 0)]) - y) > 0.12:
			pulls += 1
	r.check(pulls == 2, "chars: pull_rope do Pico tem dois puxoes (%d; maos de %.0f a %.0f cm)" % [pulls, ymax * 100, ymin * 100])
	r.check(ymax - ymin > 0.25, "chars: puxoes com curso > 25 cm (%.1f cm)" % [(ymax - ymin) * 100])
	r.check(float(zs.min()) < -0.15, "chars: maos do Pico a frente do corpo no puxao (z %.2f)" % float(zs.min()))
	var worst := 0.0
	for i in 17:
		vis.seek_clip(&"pull_rope", len * i / 16.0)
		worst = maxf(worst, vis.foot_contact_error())
	r.check(worst < 0.01, "chars: pes do Pico plantados no pull_rope (%.1f mm)" % [worst * 1000])
	vis.seek_clip(&"look_up", 0.0)
	var h0 := vis.bone_position(&"head")
	var n0 := vis.bone_position(&"neck")
	var look0 := h0 - n0
	vis.seek_clip(&"look_up", 0.9)
	var look1 := vis.bone_position(&"head") - vis.bone_position(&"neck")
	r.check(look1.distance_to(look0) < 0.2, "chars: look_up mantem a cabeca no pescoco")
	var fm := vis.face_mesh()
	var aabb := fm.get_aabb()
	r.check(aabb.size.y > 0.0, "chars: rosto do Pico presente")
	for part in ["Pico_RopeCoil", "Pico_Carabiners", "Pico_Backpack", "Pico_RopeSash"]:
		r.check(root.find_child(part, true, false) != null, "chars: Pico tem %s" % part)
	var rope := _part(root, "Pico_RopeCoil")
	r.check(rope.get_center().z > 0.12 and rope.size.x > 0.18, "chars: corda do Pico nas costas (+Z), larga o bastante para ler a 48 px (z=%.2f, largura %.2f)" % [rope.get_center().z, rope.size.x])
	root.queue_free()
	await r.frames(1)


## Ator de verdade (MemberActor) parado no chao: toca idle, em pe, pes no chao (reproduz o caso do figurante/Pico tombado no jogo).
func _test_member_actor_idle() -> void:
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	cs.shape = box
	cs.position.y = -0.5
	floor_body.add_child(cs)
	floor_body.collision_layer = 1
	r.tree.root.add_child(floor_body)
	for who in [&"climber", &"tracker", &"pilot"]:
		var a := MemberActor.new()
		r.tree.root.add_child(a)
		a.setup(who)
		a.position = Vector3(0, 0.05, 0)
		await r.frames(90)
		var vis := a.model
		r.check(vis != null and vis.current_animation() == &"idle", "chars: MemberActor %s parado toca idle (%s)" % [who, vis.current_animation() if vis != null else "sem modelo"])
		if vis != null:
			var h := vis.bone_position(&"hips")
			var hd := vis.bone_position(&"head")
			var tilt := rad_to_deg(atan2(Vector2(hd.x - h.x, hd.z - h.z).length(), hd.y - h.y))
			r.check(tilt < 12.0, "chars: MemberActor %s parado em pe, tronco a %.1f graus" % [who, tilt])
			r.check(vis.foot_contact_error() < 0.02, "chars: MemberActor %s parado com pes no chao (%.1f mm)" % [who, vis.foot_contact_error() * 1000])
			print("  medida MemberActor %s: anim=%s tronco %.1f graus pe a %.1f mm" % [who, vis.current_animation(), tilt, vis.foot_contact_error() * 1000])
		a.queue_free()
	floor_body.queue_free()
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
	r.check(is_equal_approx(vis.walk_speed_scale(vis.walk_speed_mps), 1.0), "chars: walk_speed_scale(velocidade nominal) = 1")
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
		if not (f in ["rastro.glb", "leme.glb", "pico.glb", "extra_a.glb", "extra_b.glb", "extra_c.glb"]):
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




