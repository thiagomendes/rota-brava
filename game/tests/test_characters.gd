extends RefCounted
## Personagens organicos (RB-04-chars): cenas, escala, origem nos pes, frente -Z, materiais, ossos, animacoes (nomes, duracao,
## loop), shape keys, ausencia de malha externa e MEDICOES: contato dos pes no `walk`, deslizamento e alcance da mao em
## `inspect_touch`. Mede cinematica do rig (posicao dos ossos), nao aparencia: o julgamento visual esta nas imagens.

const DIR := "res://actors/characters/"
const BONES := ["root", "hips", "spine", "chest", "neck", "head", "shoulder.L", "shoulder.R", "upper_arm.L", "upper_arm.R",
	"forearm.L", "forearm.R", "hand.L", "hand.R", "thigh.L", "thigh.R", "shin.L", "shin.R", "foot.L", "foot.R", "toe.L", "toe.R"]
const SHAPES := ["neutra", "atenta", "surpresa", "alegre", "blink"]
const LOOPS := ["idle", "walk", "run", "idle_wheel", "chat", "wag", "carry_idle", "carry_walk", "climb_wall", "lower_rope", "push_cart", "idle_seated"]
## RB-R1 G19: clipes de pegar, levar, pousar e examinar (os tres herois); escalar e corda (Pico); carrinho (Leme).
## Duracao esperada (s); laco conforme LOOPS. carry_walk tem o ciclo do walk.
const G19_COMMON := {"pick_up": 0.6, "carry_idle": 2.4, "carry_walk": 1.0, "place_high": 0.9, "place_low": 0.8, "inspect": 1.4}
const G19_PICO := {"climb_up_low": 1.0, "climb_up": 1.2, "climb_up_high": 1.333, "climb_wall": 1.2, "climb_top": 0.8,
	"climb_down": 1.0, "throw_rope": 1.2, "lower_rope": 1.0}
const G19_LEME := {"push_cart": 1.0}
## Degraus do climb_up* (altura em m); o climb_down desce 0,9 m.
const CLIMB_H := {"climb_up_low": 0.6, "climb_up": 0.9, "climb_up_high": 1.2}
## RB-R1: rosto completo (expressoes + visemas da fala + olhar) em todo o elenco novo.
const FULL_SHAPES := ["neutra", "atenta", "surpresa", "alegre", "triste", "brava_leve", "blink", "mouth_A", "mouth_E", "mouth_O",
	"mouth_M", "look_left", "look_right", "look_up"]
const RASTRO_SHAPES := FULL_SHAPES
const RASTRO_ANIMS := ["idle", "walk", "run", "stop", "crouch", "inspect_touch", "look_to_leme", "react_surprise", "point", "wave",
	"celebrate", "team_pose", "pick_up", "carry_idle", "carry_walk", "place_high", "place_low", "inspect"]
const PICO_ANIMS := ["idle", "walk", "run", "stop", "jump", "pull_rope", "look_up", "react_surprise", "celebrate", "wave", "team_pose",
	"point", "pick_up", "carry_idle", "carry_walk", "place_high", "place_low", "inspect", "climb_up_low", "climb_up", "climb_up_high",
	"climb_wall", "climb_top", "climb_down", "throw_rope", "lower_rope"]
const LEME_ANIMS := ["idle", "walk", "run", "stop", "idle_wheel", "steer_left", "steer_right", "react_horn", "celebrate", "wave", "point",
	"team_pose", "pick_up", "carry_idle", "carry_walk", "place_high", "place_low", "inspect", "push_cart"]
const PUP_BONES := ["root", "hips", "spine", "chest", "neck", "head", "tail1", "fl_paw.L", "fl_paw.R", "bl_paw.L", "bl_paw.R"]
const HEROES := ["rastro", "pico", "leme"]

const CHARS := {
	"rastro": {"scene": "rastro_model", "glb": "res://assets/models/characters/rastro_v2.glb", "v2": true, "head_part": "Rastro_Hair", "root": "Rastro", "prefix": "Rastro",
		"anims": RASTRO_ANIMS, "shapes": FULL_SHAPES, "height": [1.0, 1.2], "tris": [20000, 25000],
		"materials": ["mat_rastro_v2_face_eye", "mat_rastro_v2_face_iris", "mat_rastro_v2_face_dark", "mat_rastro_v2_face_skin", "mat_rastro_v2_face_mouth", "mat_rastro_v2_gear", "mat_rastro_v2_hair", "mat_rastro_v2_skin", "mat_rastro_v2_suit", "mat_rastro_v2_glass", "mat_rastro_v2_screen"]},
	"pico": {"scene": "pico_model", "glb": "res://assets/models/characters/pico_v2.glb", "v2": true, "head_part": "Pico_Hair", "root": "Pico", "prefix": "Pico",
		"anims": PICO_ANIMS, "shapes": FULL_SHAPES, "height": [1.0, 1.2], "tris": [20000, 25000],
		"materials": ["mat_pico_v2_face_eye", "mat_pico_v2_face_iris", "mat_pico_v2_face_dark", "mat_pico_v2_face_skin", "mat_pico_v2_face_mouth", "mat_pico_v2_gear", "mat_pico_v2_hair", "mat_pico_v2_skin", "mat_pico_v2_suit", "mat_pico_v2_lamp"]},
	"leme": {"scene": "leme_model", "glb": "res://assets/models/characters/leme_v2.glb", "v2": true, "head_part": "Leme_Hair", "root": "Leme", "prefix": "Leme",
		"anims": LEME_ANIMS, "shapes": FULL_SHAPES, "height": [1.0, 1.2], "tris": [20000, 25000],
		"materials": ["mat_leme_v2_face_eye", "mat_leme_v2_face_iris", "mat_leme_v2_face_dark", "mat_leme_v2_face_skin", "mat_leme_v2_face_mouth", "mat_leme_v2_gear", "mat_leme_v2_hair", "mat_leme_v2_skin", "mat_leme_v2_suit", "mat_leme_v2_glass", "mat_leme_v2_acc_lifevest"]},
	# RB-R1 G4: secundarios v2 (padrao do trio: malha por grupo de material, atlas assada, PBR com verniz)
	"captain": {"scene": "captain_model", "glb": "res://assets/models/characters/captain_v2.glb", "v2": true, "skinned": 5, "head_part": "Captain_Hair",
		"root": "Captain", "prefix": "Captain", "anims": ["idle", "walk", "wave", "thanks"], "shapes": FULL_SHAPES, "height": [1.55, 1.95],
		"tris": [15000, 25000],
		"materials": ["mat_captain_v2_face_eye", "mat_captain_v2_face_iris", "mat_captain_v2_face_dark", "mat_captain_v2_face_skin", "mat_captain_v2_face_mouth",
			"mat_captain_v2_cloth", "mat_captain_v2_skin", "mat_captain_v2_hair", "mat_captain_v2_gear"]},
	"pup": {"scene": "pup_model", "glb": "res://assets/models/characters/pup_v2.glb", "v2": true, "skinned": 4, "root": "Pup", "prefix": "Pup",
		"bones": PUP_BONES, "face_ahead": 0.04, "anims": ["idle", "wag", "jump_happy", "bark", "step_on_horn", "walk", "run"], "shapes": FULL_SHAPES,
		"height": [0.35, 0.65], "tris": [10000, 25000],
		"materials": ["mat_pup_v2_face_eye", "mat_pup_v2_face_iris", "mat_pup_v2_face_dark", "mat_pup_v2_face_skin", "mat_pup_v2_face_mouth",
			"mat_pup_v2_fur_body", "mat_pup_v2_fur_head", "mat_pup_v2_gear"]},
	"amora": {"scene": "amora_model", "glb": "res://assets/models/characters/amora_v2.glb", "v2": true, "skinned": 5, "head_part": "Amora_Hair",
		"root": "Amora", "prefix": "Amora", "anims": ["idle", "wave", "thanks", "point", "talk"], "shapes": FULL_SHAPES, "height": [1.45, 1.75],
		"tris": [12000, 23999],
		"materials": ["mat_amora_v2_face_eye", "mat_amora_v2_face_iris", "mat_amora_v2_face_dark", "mat_amora_v2_face_skin", "mat_amora_v2_face_mouth",
			"mat_amora_v2_cloth", "mat_amora_v2_skin", "mat_amora_v2_hair", "mat_amora_v2_gear"]},
	# RB-R1 G21: Lumi, o operador do radio do Farol 7 (adulto, padrao dos secundarios v2)
	"lumi": {"scene": "lumi_model", "glb": "res://assets/models/characters/lumi_v2.glb", "v2": true, "skinned": 5, "head_part": "Lumi_Hair",
		"root": "Lumi", "prefix": "Lumi", "anims": ["idle", "talk", "wave", "point", "idle_seated", "turn_chair"], "shapes": FULL_SHAPES, "height": [1.60, 1.85],
		"tris": [15000, 24999],
		"materials": ["mat_lumi_v2_face_eye", "mat_lumi_v2_face_iris", "mat_lumi_v2_face_dark", "mat_lumi_v2_face_skin", "mat_lumi_v2_face_mouth",
			"mat_lumi_v2_cloth", "mat_lumi_v2_skin", "mat_lumi_v2_hair", "mat_lumi_v2_gear"]},
	"villager_a": {"scene": "villager_a", "glb": "res://assets/models/characters/villager_a.glb", "root": "VillagerA", "prefix": "VillagerA",
		"anims": ["idle", "walk", "wave", "chat"], "shapes": FULL_SHAPES, "height": [1.45, 1.9],
		"materials": ["mat_villager_a_pele", "mat_villager_a_uniforme", "mat_villager_a_cabelo"]},
	"villager_b": {"scene": "villager_b", "glb": "res://assets/models/characters/villager_b.glb", "root": "VillagerB", "prefix": "VillagerB",
		"anims": ["idle", "walk", "wave", "chat"], "shapes": FULL_SHAPES, "height": [1.45, 1.9],
		"materials": ["mat_villager_b_pele", "mat_villager_b_uniforme", "mat_villager_b_cabelo"]},
	"villager_c": {"scene": "villager_c", "glb": "res://assets/models/characters/villager_c.glb", "root": "VillagerC", "prefix": "VillagerC",
		"anims": ["idle", "walk", "wave", "chat"], "shapes": FULL_SHAPES, "height": [0.8, 1.1],
		"materials": ["mat_villager_c_pele", "mat_villager_c_uniforme", "mat_villager_c_cabelo"]},
}
## Personagem cuja entrada no manifesto tem outro id (RB-R1 G21: o Lumi ja nasceu v2 e so existe como `lumi_v2`).
## Para estes, a entrada do manifesto tem de registrar ossos, shape keys e TODAS as animacoes de CHARS[id]["anims"].
const MANIFEST_IDS := {"lumi": "lumi_v2"}
const PORTRAIT_IDS := ["rastro", "pico", "leme", "captain", "pup", "lumi"]
const PORTRAIT_EXPRS := ["neutra", "alegre", "surpresa"]

var r


func run(runner) -> void:
	r = runner
	for id in CHARS:
		await _test_static(id)
	for id in ["rastro", "pico", "leme", "captain", "villager_a", "villager_b", "villager_c"]:
		await _test_walk_contact(id)
	for id in HEROES:
		await _test_gait_contact(id, &"run")
		await _test_gait_contact(id, &"carry_walk")
		await _test_g19(id)
		await _test_hero_child(id)
		await _test_loops_close(id)
		await _test_eyes_open_loops(id)
	for id in ["rastro", "pico", "leme", "captain", "lumi", "villager_a", "villager_b", "villager_c"]:
		await _test_idle_upright(id)
	await _test_pico()
	await _test_pico_climb()
	await _test_pup()
	await _test_pup_gaits()
	await _test_point_gestures()
	await _test_amora()
	await _test_lumi()
	await _test_member_actor_idle()
	await _test_inspect_real_pawmark()
	await _test_leme_wheel()
	await _test_visual_api()
	_test_rastro_compat_scene()
	_test_no_foreign_models()
	_test_portraits()
	await _test_pbr_and_accessories()

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
	# v2 (RB-R1 E1b): malhas por material (sem _Head); o cabelo fica atras do rosto
	var head := _part(root, String(d.get("head_part", d["prefix"] + "_Head")))
	r.check(face.get_center().z < head.get_center().z - float(d.get("face_ahead", 0.02 if d.get("v2", false) else 0.08)), "chars: frente de %s em -Z (rosto z=%.3f, cabeca z=%.3f)" % [id, face.get_center().z, head.get_center().z])
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
		for b in d.get("bones", BONES):
			if sk.find_bone(b) < 0:
				miss_b.append(b)
		r.check(miss_b.is_empty(), "chars: ossos estaveis de %s presentes %s" % [id, miss_b])
	var skinned := 0
	for n in root.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).skin != null:
			skinned += 1
	r.check(skinned >= int(d.get("skinned", 6 if d.get("v2", false) else 8)), "chars: malhas de %s com skin (%d)" % [id, skinned])
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
	var limit := 25000
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
	# carry_walk (G19) tem o mesmo passo do walk: mesma velocidade nominal
	var nominal := vis.run_speed_mps if clip == &"run" else vis.walk_speed_mps
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
	# Barco v2 do mundo (RB-R1 E1, boat_wv2): o banco faz parte do casco (sem malha Boat_Bench); o topo do banco e o
	# encaixe BenchMark (mesma altura do boat_v2) e a area do banco e a da PawMark, que fica sobre ele, com 15 cm de folga.
	var paw := boat.find_child("PawMark", true, false) as MeshInstance3D
	var bench_mark := boat.find_child("BenchMark", true, false) as Node3D
	r.check(paw != null and bench_mark != null, "chars: barco v2 tem PawMark e BenchMark")
	if paw == null or bench_mark == null:
		boat.queue_free()
		return
	var center := paw.global_transform * paw.mesh.get_aabb().get_center()
	var bench_box: AABB = (paw.global_transform * paw.mesh.get_aabb()).grow(0.15)
	var bench_top := bench_mark.global_position.y
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
func _test_hero_child(id: String) -> void:
	var pre := String(CHARS[id]["prefix"])
	var root := await _spawn(id)
	var vis := root.find_child("Model", false, false) as CharacterVisual
	var box := _aabb(root)
	var v2: bool = CHARS[id].get("v2", false)
	# v2: sem malha _Head; mede a cabeca do topo ao osso do pescoco
	var head := _part(root, pre + "_Head")
	if v2:
		var neck := vis.bone_position(&"neck")
		head = AABB(Vector3(0, neck.y, 0), Vector3(0, box.end.y - neck.y, 0))
	var ratio := head.size.y / box.size.y
	# v2 medido (pescoco ao topo, E1b 2026-11-25): Rastro 40,1%, Pico 41,8%, Leme 40,4% -> faixa unica 38-44% (+-2 pontos)
	var rlo := 0.38 if v2 else 0.33
	var rhi := 0.44 if v2 else 0.38
	r.check(ratio >= rlo and ratio <= rhi, "chars: cabeca de %s com %.1f%% da altura (%.0f a %.0f%%%s; cabeca %.3f m, altura %.3f m)" % [id, ratio * 100, rlo * 100, rhi * 100, ", pescoco ao topo" if v2 else "", head.size.y, box.size.y])
	var fm := vis.face_mesh()
	var fmats: Array = []
	for s in fm.mesh.get_surface_count():
		fmats.append(fm.mesh.surface_get_material(s).resource_name)
	for m in (["v2_face_eye", "v2_face_iris", "v2_face_dark", "v2_face_mouth"] if v2 else ["olhos", "iris", "escuro", "boca"]):
		r.check(fmats.has("mat_%s_%s" % [id, m]), "chars: rosto de %s tem mat_%s_%s (olhos/iris/pupila/boca)" % [id, id, m])
	for a in CHARS[id]["anims"]:
		r.check(vis.has_animation(StringName(a)), "chars: %s tem o clipe %s" % [id, a])
	r.check(absf(vis.animation_length(&"run") - 0.6) < 0.05, "chars: run de %s com ciclo de ~0,6 s (%.3f)" % [id, vis.animation_length(&"run")])
	r.check(absf(vis.animation_length(&"team_pose") - 1.5) < 0.05, "chars: team_pose de %s dura 1,5 s (%.3f)" % [id, vis.animation_length(&"team_pose")])
	vis.set_viseme(&"mouth_A", 1.0)
	var ia := fm.find_blend_shape_by_name("mouth_A")
	r.check(ia >= 0 and fm.get_blend_shape_value(ia) > 0.99, "chars: set_viseme(mouth_A) abre a boca")
	vis.set_viseme(&"mouth_O", 0.7)
	r.check(fm.get_blend_shape_value(ia) < 0.01 and fm.get_blend_shape_value(fm.find_blend_shape_by_name("mouth_O")) > 0.69, "chars: set_viseme troca de visema")
	vis.set_viseme(&"")
	vis.set_gaze(Vector2(-1, 0.5))
	r.check(fm.get_blend_shape_value(fm.find_blend_shape_by_name("look_left")) > 0.99 and fm.get_blend_shape_value(fm.find_blend_shape_by_name("look_up")) > 0.49, "chars: set_gaze move os olhos para a esquerda e para cima")
	vis.set_gaze(Vector2.ZERO)
	print("  medida %s: altura %.3f m, cabeca %.3f m (%.1f%%), %d triangulos" % [id, box.size.y, head.size.y, ratio * 100, _tri_count(root)])
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


## Pico: pull_rope dura 1,6 s com dois puxoes (maos descem duas vezes, a frente do corpo); jump existe, sai do chao (~0,45 s de voo)
## e volta ao chao no fim; look_up levanta a cabeca; rolo de corda nas costas sem tapar o emblema.
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
	var ymin: float = ys.min()
	var ymax: float = ys.max()
	var thr := ymin + 0.35 * (ymax - ymin)
	var pulls := 0
	var below := false
	for y in ys:
		if float(y) < thr and not below:
			pulls += 1
		below = float(y) < thr
	r.check(ymax - ymin > 0.12, "chars: puxoes do Pico com curso > 12 cm (%.1f cm)" % [(ymax - ymin) * 100])
	var want_pulls := 4 if CHARS["pico"].get("v2", false) else 2   # v2 medido: 4 puxoes em 1,6 s
	r.check(pulls == want_pulls, "chars: pull_rope do Pico tem %d puxoes (%d)" % [want_pulls, pulls])
	r.check(float(zs.min()) < -0.12, "chars: maos do Pico a frente do corpo no puxao (z %.2f)" % float(zs.min()))
	r.check(vis.has_animation(&"jump") and not vis.is_looping(&"jump"), "chars: Pico tem jump (sem loop)")
	var jl := vis.animation_length(&"jump")
	vis.seek_clip(&"jump", 0.0)
	var f0 := vis.foot_contact_error()
	vis.seek_clip(&"jump", jl)
	var f1 := vis.foot_contact_error()
	var top := 0.0
	var air := 0
	for i in 31:
		vis.seek_clip(&"jump", jl * i / 30.0)
		var h := vis.lowest_foot_height()
		top = maxf(top, h)
		if h > 0.03:
			air += 1
	var air_s := air * jl / 30.0
	r.check(f0 < 0.02 and f1 < 0.02, "chars: jump do Pico comeca e termina com os pes no chao (%.1f / %.1f mm)" % [f0 * 1000, f1 * 1000])
	r.check(top > 0.10 and air_s > 0.25 and air_s < 0.6, "chars: jump do Pico sai do chao (%.1f cm, ~%.2f s no ar)" % [top * 100, air_s])
	vis.seek_clip(&"look_up", 0.0)
	var l0 := vis.bone_position(&"head")
	vis.seek_clip(&"look_up", 0.9)
	r.check(vis.bone_position(&"head").distance_to(l0) < 0.2, "chars: look_up mantem a cabeca no pescoco")
	if CHARS["pico"].get("v2", false):
		# v2: corda e emblema estao na malha unica Pico_Gear com um so material (sem no/material proprio). Mede por regiao
		# de vertices na pose de repouso, faixa do tronco (y 0,45-0,80 m): costas = rolo de corda; frente central = emblema.
		var gear := root.find_child("Pico_Gear", true, false) as MeshInstance3D
		r.check(gear != null, "chars: Pico v2 tem Pico_Gear (corda + emblema)")
		if gear != null:
			var verts: PackedVector3Array = gear.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var back_z := -INF
			var chest := 0
			for p in verts:
				if p.y > 0.45 and p.y < 0.8:
					back_z = maxf(back_z, p.z)
					if absf(p.x) < 0.12 and p.z < -0.1:
						chest += 1
			r.check(back_z > 0.15, "chars: rolo de corda do Pico nas costas (+Z ate %.3f m)" % back_z)
			r.check(chest > 50, "chars: Pico tem emblema/peitoral na frente do peito (%d vertices)" % chest)
			print("  medida Pico v2: corda nas costas ate z %.3f m, %d vertices de equipamento na frente do peito" % [back_z, chest])
	else:
		var rope := _part(root, "Pico_RopeCoil")
		var emb := _part(root, "Pico_Emblem")
		r.check(rope.end.z > 0.15, "chars: rolo de corda do Pico nas costas (+Z ate %.2f m)" % rope.end.z)
		r.check(emb.size.x > 0.0, "chars: Pico tem emblema no peito")
	print("  medida jump Pico: pico dos pes %.1f cm, ~%.2f s no ar" % [top * 100, air_s])
	root.queue_free()
	await r.frames(1)


## Filhote: clipes, latido abre a boca (visema animado), pata dianteira sobe no step_on_horn.
func _test_pup() -> void:
	var root := await _spawn("pup")
	var vis := root.find_child("Model", false, false) as CharacterVisual
	vis.seek_clip(&"step_on_horn", 0.0)
	var p0 := vis.bone_position(&"fl_paw.R")
	vis.seek_clip(&"step_on_horn", 0.4)
	var p1 := vis.bone_position(&"fl_paw.R")
	r.check(p1.y - p0.y > 0.03, "chars: step_on_horn levanta a pata dianteira (%.1f cm)" % [(p1.y - p0.y) * 100])
	vis.seek_clip(&"jump_happy", 0.42)
	r.check(vis.bone_position(&"hips").y > 0.30, "chars: jump_happy tira o filhote do chao (quadril %.2f m)" % vis.bone_position(&"hips").y)
	r.check(vis.is_looping(&"wag") and vis.is_looping(&"idle"), "chars: wag e idle do filhote em loop")
	root.queue_free()
	await r.frames(1)

## RB-R1 arte das cenas: walk/run do filhote. Patas de apoio no chao (tornozelo a 3 cm), pata de balanco sobe, pata de apoio
## recua na velocidade nominal do .tscn (sem deslizar), run com fase aerea curta e mais rapido que o walk.
func _test_pup_gaits() -> void:
	var root := await _spawn("pup")
	var vis := root.find_child("Model", false, false) as CharacterVisual
	var paws := [&"fl_paw.L", &"fl_paw.R", &"bl_paw.L", &"bl_paw.R"]
	r.check(vis.run_speed_mps > vis.walk_speed_mps and vis.walk_speed_mps > 0.3, "chars: filhote com walk %.3f e run %.3f m/s" % [vis.walk_speed_mps, vis.run_speed_mps])
	r.check(absf(vis.animation_length(&"run") - 0.6) < 0.01 and vis.is_looping(&"run") and vis.is_looping(&"walk"), "chars: run do filhote 0,6 s, walk e run em loop")
	for clip: StringName in [&"walk", &"run"]:
		var nominal := vis.walk_speed_mps if clip == &"walk" else vis.run_speed_mps
		var len := vis.animation_length(clip)
		var n := 60
		var pts: Array = []
		var min_down := 9
		var lift := 0.0
		var airborne := 0
		for i in n + 1:
			vis.seek_clip(clip, minf(len * i / n, len - 0.0005))
			var fr := {}
			var down := 0
			for b in paws:
				var p := vis.bone_position(b)
				fr[b] = p
				if p.y < 0.036:
					down += 1
				lift = maxf(lift, p.y - 0.03)
			min_down = mini(min_down, down)
			if down == 0:
				airborne += 1
			pts.append(fr)
		var errs: Array = []
		for i in n:
			for b in paws:
				var pa: Vector3 = pts[i][b]
				var pb: Vector3 = pts[i + 1][b]
				if pa.y < 0.034 and pb.y < 0.034:
					errs.append(absf((pb.z - pa.z) / (len / n) - nominal))
		var mean := 0.0
		for e in errs:
			mean += e
		mean /= maxf(errs.size(), 1.0)
		r.check(lift > 0.025, "chars: %s do filhote levanta a pata (%.1f cm)" % [clip, lift * 100])
		r.check(errs.size() >= 40 and mean < 0.08 * maxf(nominal / 0.5, 1.0), "chars: pata de apoio do filhote no %s sem deslizar (%d amostras, erro %.3f m/s vs %.3f)" % [clip, errs.size(), mean, nominal])
		if clip == &"walk":
			r.check(min_down >= 2, "chars: walk do filhote sempre com 2+ patas no chao (min %d)" % min_down)
		else:
			r.check(airborne >= 1 and airborne <= n / 3, "chars: run do filhote tem fase aerea curta (%d de %d quadros)" % [airborne, n])
		vis.seek_clip(clip, 0.0)
		var p0 := vis.bone_position(&"hips")
		vis.seek_clip(clip, len - 0.0005)
		r.check(p0.distance_to(vis.bone_position(&"hips")) < 0.01, "chars: %s do filhote fecha o ciclo (quadril)" % clip)
		print("  medida pup %s: %.3f m/s, pata sobe %.1f cm, deslize %.3f m/s, patas no chao min %d, quadros no ar %d/%d" % [clip, nominal, lift * 100, mean, min_down, airborne, n])
	root.queue_free()
	await r.frames(1)


## RB-R1 arte das cenas: `point` de Pico (novo), Rastro e Leme (existentes): ~1,2 s, sem loop, a mao direita vai para a frente
## (-Z) e para fora na altura do peito e volta para perto da pose inicial.
func _test_point_gestures() -> void:
	for id in ["pico", "rastro", "leme", "amora", "lumi"]:
		var root := await _spawn(id)
		var vis := root.find_child("Model", false, false) as CharacterVisual
		var len := vis.animation_length(&"point")
		r.check(absf(len - 1.2) < 0.02 and not vis.is_looping(&"point"), "chars: point de %s com 1,2 s e sem loop (%.3f)" % [id, len])
		vis.seek_clip(&"point", 0.0)
		var h0 := vis.bone_position(&"hand.R")
		var hips := vis.bone_position(&"hips")
		var sh := vis.bone_position(&"upper_arm.R")
		vis.seek_clip(&"point", 0.7)
		var h1 := vis.bone_position(&"hand.R")
		vis.seek_clip(&"point", len - 0.001)
		var h2 := vis.bone_position(&"hand.R")
		r.check(h1.z - hips.z < -0.15 and h1.z < h0.z - 0.12, "chars: point de %s leva a mao direita para a frente (z %.2f -> %.2f)" % [id, h0.z - hips.z, h1.z - hips.z])
		r.check(absf(h1.y - sh.y) < 0.22, "chars: point de %s na altura do ombro (mao %.2f, ombro %.2f)" % [id, h1.y, sh.y])
		r.check(h2.distance_to(h0) < 0.08, "chars: point de %s volta perto do inicio (%.3f m)" % [id, h2.distance_to(h0)])
		root.queue_free()
		await r.frames(1)


## RB-R1 arte das cenas: Dona Amora. PBR (vinil), mais baixa que o orcamento dos herois, clipes, talk mexe a boca.
func _test_amora() -> void:
	var root := await _spawn("amora")
	var vis := root.find_child("Model", false, false) as CharacterVisual
	r.check(vis.is_pbr(), "chars: Dona Amora marcada PBR (acabamento vinil dos v2)")
	r.check(_tri_count(root) < 24000, "chars: Dona Amora abaixo do orcamento dos herois (%d < 24000)" % _tri_count(root))
	# verniz declarado no GLB (KHR_materials_clearcoat), como nos herois v2
	var coat := 0
	for m in _glb_json("res://assets/models/characters/amora_v2.glb").get("materials", []):
		if ((m as Dictionary).get("extensions", {}) as Dictionary).has("KHR_materials_clearcoat"):
			coat += 1
	r.check(coat >= 8, "chars: Dona Amora com verniz (clearcoat no GLB) em %d materiais" % coat)
	r.check(absf(vis.animation_length(&"talk") - 3.0) < 0.02 and absf(vis.animation_length(&"thanks") - 2.0) < 0.02
		and absf(vis.animation_length(&"wave") - 1.6) < 0.02, "chars: talk 3,0 s, thanks 2,0 s, wave 1,6 s")
	vis.seek_clip(&"wave", 0.0)
	var h0 := vis.bone_position(&"hand.R")
	vis.seek_clip(&"wave", 0.8)
	r.check(vis.bone_position(&"hand.R").y > vis.bone_position(&"head").y - 0.15, "chars: wave da Amora ergue a mao a altura da cabeca")
	vis.seek_clip(&"wave", 1.6 - 0.001)
	r.check(vis.bone_position(&"hand.R").distance_to(h0) < 0.06, "chars: wave da Amora volta a pose inicial")
	vis.seek_clip(&"thanks", 1.0)
	var hl := vis.bone_position(&"hand.L")
	var hr := vis.bone_position(&"hand.R")
	r.check(hl.distance_to(hr) < 0.16, "chars: thanks da Amora junta as maos (%.2f m)" % hl.distance_to(hr))
	# talk: a boca abre (shape key mouth_* animada no clipe)
	var player := vis.animation_player()
	var anim := player.get_animation(&"talk")
	var mouth_tracks := 0
	for i in anim.get_track_count():
		if anim.track_get_type(i) == Animation.TYPE_BLEND_SHAPE and String(anim.track_get_path(i)).contains("mouth_"):
			var mx := 0.0
			for k in anim.track_get_key_count(i):
				mx = maxf(mx, float(anim.track_get_key_value(i, k)))
			if mx > 0.3:
				mouth_tracks += 1
	r.check(mouth_tracks >= 2, "chars: talk da Amora abre a boca (visemas animados: %d)" % mouth_tracks)
	vis.seek_clip(&"talk", 0.0)
	var t0 := vis.bone_position(&"hand.R")
	vis.seek_clip(&"talk", 3.0 - 0.001)
	r.check(vis.bone_position(&"hand.R").distance_to(t0) < 0.02, "chars: talk da Amora termina na pose do inicio (pode repetir sem salto)")
	root.queue_free()
	await r.frames(1)


## RB-R1 G21: Lumi (operador do Farol 7). PBR com verniz, olhos abertos em todo clipe (G1), loop do idle fechado, aceno
## que ergue a mao, talk que abre a boca e volta a pose, altura entre a Dona Amora e o capitao, HeadAnchor na cabeca.
func _test_lumi() -> void:
	await _test_eyes_open_loops("lumi")
	await _test_loops_close("lumi")
	var root := await _spawn("lumi")
	var vis := root.find_child("Model", false, false) as CharacterVisual
	r.check(vis.is_pbr(), "chars: Lumi marcado PBR (acabamento dos v2)")
	var coat := 0
	for m in _glb_json("res://assets/models/characters/lumi_v2.glb").get("materials", []):
		if ((m as Dictionary).get("extensions", {}) as Dictionary).has("KHR_materials_clearcoat"):
			coat += 1
	r.check(coat >= 8, "chars: Lumi com verniz (clearcoat no GLB) em %d materiais" % coat)
	r.check(absf(vis.animation_length(&"talk") - 3.0) < 0.02 and absf(vis.animation_length(&"wave") - 1.6) < 0.02
		and absf(vis.animation_length(&"idle") - 3.6) < 0.02, "chars: Lumi talk 3,0 s, wave 1,6 s, idle 3,6 s")
	var h := _aabb(root).size.y
	r.check(h > 1.66 and h < 1.78, "chars: Lumi entre a Dona Amora (1,68) e o capitao (1,77): %.3f m" % h)
	var anchor := root.find_child("HeadAnchor", false, false) as Node3D
	var head := vis.bone_position(&"head")
	r.check(anchor != null and anchor.position.y > head.y and anchor.position.y < h, "chars: HeadAnchor do Lumi na cabeca (%.2f m; osso head %.2f, topo %.2f)"
		% [anchor.position.y if anchor != null else -1.0, head.y, h])
	vis.seek_clip(&"wave", 0.0)
	var h0 := vis.bone_position(&"hand.R")
	vis.seek_clip(&"wave", 0.8)
	r.check(vis.bone_position(&"hand.R").y > vis.bone_position(&"head").y - 0.15, "chars: wave do Lumi ergue a mao a altura da cabeca")
	vis.seek_clip(&"wave", 1.6 - 0.001)
	r.check(vis.bone_position(&"hand.R").distance_to(h0) < 0.06, "chars: wave do Lumi volta a pose inicial")
	var anim := vis.animation_player().get_animation(&"talk")
	var mouth_tracks := 0
	for i in anim.get_track_count():
		if anim.track_get_type(i) == Animation.TYPE_BLEND_SHAPE and String(anim.track_get_path(i)).contains("mouth_"):
			var mx := 0.0
			for k in anim.track_get_key_count(i):
				mx = maxf(mx, float(anim.track_get_key_value(i, k)))
			if mx > 0.3:
				mouth_tracks += 1
	r.check(mouth_tracks >= 2, "chars: talk do Lumi abre a boca (visemas animados: %d)" % mouth_tracks)
	vis.seek_clip(&"talk", 0.0)
	var t0 := vis.bone_position(&"hand.R")
	vis.seek_clip(&"talk", 3.0 - 0.001)
	r.check(vis.bone_position(&"hand.R").distance_to(t0) < 0.02, "chars: talk do Lumi termina na pose do inicio")
	# sentado (plano 9a): assento a 0,40 m, pes no chao, turn_chair de 1,0 s termina na pose do idle_seated
	r.check(vis.is_looping(&"idle_seated") and not vis.is_looping(&"turn_chair") and absf(vis.animation_length(&"turn_chair") - 1.0) < 0.02,
		"chars: Lumi idle_seated em laco e turn_chair de 1,0 s")
	vis.seek_clip(&"idle_seated", 0.0)
	var hs := vis.bone_position(&"hips")
	var ks := vis.bone_position(&"shin.R")
	r.check(hs.y > 0.46 and hs.y < 0.60, "chars: Lumi sentado com o quadril sobre o assento (%.2f m)" % hs.y)
	r.check(absf(ks.y - hs.y) < 0.12, "chars: Lumi sentado com a coxa quase horizontal (joelho %.2f, quadril %.2f)" % [ks.y, hs.y])
	r.check(absf(vis.lowest_foot_height()) < 0.03, "chars: Lumi sentado com os pes no chao (%.1f mm)" % (vis.lowest_foot_height() * 1000))
	var s0 := vis.bone_position(&"hand.R")
	vis.seek_clip(&"turn_chair", 1.0 - 0.001)
	r.check(vis.bone_position(&"hand.R").distance_to(s0) < 0.03 and vis.bone_position(&"hips").distance_to(hs) < 0.02,
		"chars: turn_chair termina na pose do idle_seated")
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
	## Leme embarcada em BoatActor.CREW[&"pilot"] olhando para a proa: ponto medio das duas pontas de mao no WheelPoint do boat_v2.
	var boat := BoatActor.new()
	r.tree.root.add_child(boat)
	boat.place(Ep01Layout.BOAT_DOCKED_POS, Ep01Layout.BOAT_DOCKED_HEADING)
	await r.frames(2)
	var wp := boat.find_child("WheelPoint", true, false) as Node3D
	r.check(wp != null, "chars: boat_v2 tem WheelPoint")
	var a := MemberActor.new()
	r.tree.root.add_child(a)
	a.setup(&"pilot")
	a.ride(boat, BoatActor.CREW[&"pilot"])
	a.global_position = boat.to_global(BoatActor.CREW[&"pilot"])
	a.face_now(a.global_position + boat.forward())
	await r.frames(2)
	var vis := a.model
	var best := INF
	for i in 25:
		vis.seek_clip(&"idle_wheel", vis.animation_length(&"idle_wheel") * i / 24.0)
		var mid := (vis.bone_position(&"hand_tip.R") + vis.bone_position(&"hand_tip.L")) * 0.5
		best = minf(best, mid.distance_to(wp.global_position))
	vis.seek_clip(&"idle_wheel", 0.0)
	var mid0 := (vis.bone_position(&"hand_tip.R") + vis.bone_position(&"hand_tip.L")) * 0.5
	var d0 := mid0.distance_to(wp.global_position)
	r.check(d0 < 0.05, "chars: maos da Leme no volante (ponto medio a %.1f mm do WheelPoint; melhor %.1f mm)" % [d0 * 1000, best * 1000])
	var r0 := vis.bone_position(&"hand_tip.R")
	vis.seek_clip(&"steer_left", 0.5)
	var rl := vis.bone_position(&"hand_tip.R")
	vis.seek_clip(&"steer_right", 0.5)
	var rr := vis.bone_position(&"hand_tip.R")
	r.check(rl.y > r0.y + 0.03 and rr.y < r0.y - 0.03, "chars: volante a esquerda sobe a mao direita, a direita desce (%.1f / %.1f cm)" % [(rl.y - r0.y) * 100, (rr.y - r0.y) * 100])
	vis.seek_clip(&"react_horn", 0.45)
	r.check(vis.bone_position(&"hand_tip.R").y > r0.y + 0.08, "chars: react_horn ergue a mao direita")
	var feet := true
	for t in [0.0, 1.2]:
		vis.seek_clip(&"idle_wheel", t)
		feet = feet and vis.foot_contact_error() < 0.02
	r.check(feet, "chars: Leme com os pes no conves no idle_wheel")
	print("  medida idle_wheel Leme: ponto medio das maos a %.1f mm do WheelPoint (melhor %.1f mm)" % [d0 * 1000, best * 1000])
	a.queue_free()
	boat.queue_free()
	await r.frames(1)


func _test_portraits() -> void:
	for id in PORTRAIT_IDS:
		for e in PORTRAIT_EXPRS:
			var p := "res://ui/portraits/%s_%s.png" % [id, e]
			var tex := load(p) as Texture2D
			r.check(tex != null and tex.get_width() == 512 and tex.get_height() == 512, "chars: retrato %s existe com 512x512" % p)
			if tex != null:
				var img := tex.get_image()
				r.check(img.detect_alpha() != Image.ALPHA_NONE and img.get_pixel(2, 2).a < 0.05, "chars: retrato %s com fundo transparente" % p)

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


## Olhos fechados num clipe (G1): fracao do tempo e maior trecho continuo com max(alegre, blink) >= 0,5, lidos das trilhas
## de shape key do proprio clipe (amostra a 60 Hz). `alegre` e o sorriso de olhos fechados nos herois v2.
static func eyes_closed_stats(anim: Animation) -> Vector2:
	var tracks: Array[int] = []
	for t in anim.get_track_count():
		if anim.track_get_type(t) == Animation.TYPE_BLEND_SHAPE:
			var key := str(anim.track_get_path(t)).get_slice(":", 1)
			if key == "alegre" or key == "blink":
				tracks.append(t)
	var n := 0
	var closed := 0
	var run := 0.0
	var longest := 0.0
	var t := 0.0
	while t <= anim.length:
		var v := 0.0
		for tr in tracks:
			v = maxf(v, anim.blend_shape_track_interpolate(tr, t))
		n += 1
		if v >= 0.5:
			closed += 1
			run += 1.0 / 60.0
			longest = maxf(longest, run)
		else:
			run = 0.0
		t += 1.0 / 60.0
	return Vector2(float(closed) / maxf(n, 1), longest)


## G1 (RB-R1): nos lacos que ficam na tela (idle, andar, correr, timao) os herois estao de olhos abertos quase sempre e
## piscam curto: no maximo 25% do ciclo e 0,6 s seguidos com o olho fechado (antes: idle da Leme 39% e 1,8 s).
func _test_eyes_open_loops(id: String) -> void:
	var root := await _spawn(id)
	var vis := root.find_child("Model", false, false) as CharacterVisual
	var player := vis.animation_player()
	for clip in CHARS[id]["anims"]:
		var st := eyes_closed_stats(player.get_animation(StringName(clip)))
		if clip in LOOPS:
			r.check(st.x <= 0.25 and st.y <= 0.6, "chars: %s/%s de olhos abertos (fechados %.0f%% do ciclo, maior trecho %.2f s)"
				% [id, clip, st.x * 100.0, st.y])
		else:
			# Gestos (aceno, comemoracao, pose de equipe...): sorriso de olhos fechados so num aperto curto (antes ate 1,22 s).
			r.check(st.y <= 0.65, "chars: %s/%s sorriso de olhos fechados curto (maior trecho %.2f s)" % [id, clip, st.y])
			# Clipe sem laco fica parado no ultimo quadro (ex.: `point` no close da abertura): ele nao pode terminar de olho fechado.
			var anim := player.get_animation(StringName(clip))
			var end := 0.0
			for t in anim.get_track_count():
				var key := str(anim.track_get_path(t)).get_slice(":", 1)
				if anim.track_get_type(t) == Animation.TYPE_BLEND_SHAPE and (key == "alegre" or key == "blink"):
					end = maxf(end, anim.blend_shape_track_interpolate(t, anim.length))
			r.check(end < 0.5, "chars: %s/%s termina de olhos abertos (olho fechado %.2f no ultimo quadro)" % [id, clip, end])
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
		if not (f in ["rastro.glb", "leme.glb", "pico.glb", "captain.glb", "pup.glb", "villager_a.glb", "villager_b.glb", "villager_c.glb", "rastro_v2.glb", "pico_v2.glb", "leme_v2.glb", "amora.glb",
				"captain_v2.glb", "pup_v2.glb", "amora_v2.glb", "lumi_v2.glb"]):
			foreign.append(f)
	r.check(foreign.is_empty(), "chars: pasta de personagens so tem GLB do manifesto %s" % [foreign])
	var man: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../source_art/manifest.json")))
	var ids: Array = []
	var checked: Array = []
	for id in CHARS:
		checked.append(String(MANIFEST_IDS.get(id, id)))
	if man is Dictionary:
		for a in (man as Dictionary)["ativos"]:
			ids.append((a as Dictionary)["id"])
			var d := a as Dictionary
			if String(d["id"]) in checked:
				var anims := d.get("animacoes_duracao_s", {}) as Dictionary
				r.check(int(d.get("quantidade_ossos", 0)) >= 22 and anims.size() >= 2 and (d.get("shape_keys", []) as Array).has("blink"),
					"chars: manifesto de %s registra ossos, animacoes e shape keys" % d["id"])
				if String(d["id"]) in MANIFEST_IDS.values():
					var cid: String = MANIFEST_IDS.find_key(String(d["id"]))
					var miss: Array = []
					for an in CHARS[cid]["anims"]:
						if not anims.has(an):
							miss.append(an)
					r.check(miss.is_empty(), "chars: manifesto de %s registra todas as animacoes do modelo (faltam %s)" % [d["id"], miss])
	for id in CHARS:
		var mid := String(MANIFEST_IDS.get(id, id))
		r.check(ids.has(mid), "chars: manifesto lista %s (id %s)" % [id, mid])






## RB-R1 E1b: herois v2 marcados PBR (sem Stylize/contorno ao montar), antigos seguem toon; acessorio do colete da Leme.
func _test_pbr_and_accessories() -> void:
	for id in HEROES:
		var root := await _spawn(id)
		var vis := root.find_child("Model", false, false) as CharacterVisual
		r.check(vis.is_pbr(), "chars: %s v2 marcado metadata/pbr no Model" % id)
		root.queue_free()
	# RB-R1 G4: capitao, filhote e Dona Amora v2 sao PBR (sem Stylize/contorno); os moradores antigos seguem toon
	for id in ["captain", "pup", "amora", "lumi"]:
		var sec := await _spawn(id)
		r.check((sec.find_child("Model", false, false) as CharacterVisual).is_pbr(), "chars: %s v2 marcado PBR" % id)
		sec.queue_free()
	for member: StringName in [&"tracker", &"pilot", &"climber"]:
		var a := MemberActor.new()
		a.setup(member)
		r.tree.root.add_child(a)
		await r.frames(1)
		r.check(a.model != null, "chars: %s montado pelo MemberActor tem modelo" % member)
		if a.model != null:
			var outlined := 0
			for n in a.model.find_children("*", "MeshInstance3D", true, false):
				var mi := n as MeshInstance3D
				for i in mi.mesh.get_surface_count():
					var ov := mi.get_surface_override_material(i)
					if ov != null and ov.next_pass != null:
						outlined += 1
			r.check(outlined == 0, "chars: %s v2 montado sem Stylize/contorno (%d superficies com next_pass)" % [member, outlined])
		a.queue_free()
	for id in ["captain_model", "pup_model", "amora_model", "lumi_model"]:
		var sf := StoryFigure.spawn(r.tree.root, id, "SecondaryProbe")
		var passes := 0
		for n in sf.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				var ov := mi.get_surface_override_material(i)
				if ov != null and ov.next_pass != null:
					passes += 1
		r.check(passes == 0, "chars: %s v2 via StoryFigure sem Stylize/contorno (%d superficies com next_pass)" % [id, passes])
		sf.queue_free()
	var fig := StoryFigure.spawn(r.tree.root, "villager_a", "VillagerProbe")
	var with_pass := 0
	for n in fig.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var ov := mi.get_surface_override_material(i)
			if ov != null and ov.next_pass != null:
				with_pass += 1
	r.check(with_pass > 0, "chars: morador antigo via StoryFigure recebe Stylize/contorno (%d superficies com next_pass)" % with_pass)
	fig.queue_free()
	var leme := await _spawn("leme")
	var lv := leme.find_child("Model", false, false) as CharacterVisual
	r.check(lv.has_accessory(&"Acc_LifeVest") and not lv.accessory_visible(&"Acc_LifeVest"), "chars: colete da Leme existe e comeca oculto")
	r.check(lv.set_accessory(&"Acc_LifeVest", true) and lv.accessory_visible(&"Acc_LifeVest"), "chars: set_accessory liga o colete")
	r.check(lv.set_accessory(&"Acc_LifeVest", false) and not lv.accessory_visible(&"Acc_LifeVest"), "chars: set_accessory desliga o colete")
	r.check(not lv.set_accessory(&"Acc_Nada", true), "chars: set_accessory de acessorio inexistente retorna false")
	leme.queue_free()
	await r.frames(1)


# ------------------------------------------------------------------ RB-R1 G19
## Clipes G19: existem, duracao e laco esperados, carry_walk com o ciclo do walk, olho fechado em ate 0,5 s seguidos,
## HoldPoint/HoldPoint_L filhos das maos, palmas juntas a frente do peito no carregar, pick_up termina no carry_idle,
## pes plantados nos clipes parados (ponta do pe nao sai do lugar), place_* e inspect voltam ao repouso de maos vazias.
func _test_g19(id: String) -> void:
	var root := await _spawn(id)
	var vis := root.find_child("Model", false, false) as CharacterVisual
	var sk := vis.skeleton()
	var o := root.global_position
	var want: Dictionary = G19_COMMON.duplicate()
	if id == "pico":
		want.merge(G19_PICO)
	if id == "leme":
		want.merge(G19_LEME)
	for c: String in want:
		var n := StringName(c)
		r.check(vis.has_animation(n), "chars: G19 %s tem %s" % [id, c])
		if not vis.has_animation(n):
			continue
		r.check(absf(vis.animation_length(n) - float(want[c])) < 0.02, "chars: G19 %s/%s dura %.2f s (%.3f)" % [id, c, want[c], vis.animation_length(n)])
		r.check(vis.is_looping(n) == (c in LOOPS), "chars: G19 %s/%s laco %s" % [id, c, c in LOOPS])
		var st := eyes_closed_stats(vis.animation_player().get_animation(n))
		r.check(st.y <= 0.5, "chars: G19 %s/%s olho fechado no maximo 0,5 s seguidos (%.2f s)" % [id, c, st.y])
	r.check(absf(vis.animation_length(&"carry_walk") - vis.animation_length(&"walk")) < 0.001, "chars: G19 carry_walk de %s com o ciclo do walk" % id)
	for pair in [["HoldPoint", "hand.R"], ["HoldPoint_L", "hand.L"]]:
		var bi := sk.find_bone(pair[0])
		r.check(bi >= 0 and sk.get_bone_parent(bi) == sk.find_bone(pair[1]), "chars: G19 %s tem o osso %s filho de %s" % [id, pair[0], pair[1]])
	# carregar: palmas a ~0,2 m, ponto medio a frente do corpo e na altura do peito
	for c: StringName in [&"carry_idle", &"carry_walk"]:
		var len := vis.animation_length(c)
		var worst_gap := 0.0
		var lo := INF
		var hi := -INF
		var front := INF
		for i in 12:
			vis.seek_clip(c, len * i / 12.0)
			var a := vis.bone_position(&"HoldPoint")
			var b := vis.bone_position(&"HoldPoint_L")
			worst_gap = maxf(worst_gap, absf(a.distance_to(b) - 0.20))
			var m := (a + b) * 0.5 - o
			lo = minf(lo, m.y)
			hi = maxf(hi, m.y)
			front = minf(front, -m.z)
		r.check(worst_gap < 0.02, "chars: G19 %s/%s palmas a 0,20 m (desvio max %.1f mm)" % [id, c, worst_gap * 1000])
		r.check(lo > 0.40 and hi < 0.62 and front > 0.18, "chars: G19 %s/%s objeto a frente do peito (altura %.2f-%.2f m, %.2f m a frente)" % [id, c, lo, hi, front])
	# pick_up termina na pose do carry_idle (troca sem salto)
	vis.seek_clip(&"pick_up", vis.animation_length(&"pick_up"))
	var p_end := [vis.bone_position(&"HoldPoint"), vis.bone_position(&"HoldPoint_L"), vis.bone_position(&"head")]
	vis.seek_clip(&"carry_idle", 0.0)
	var p_ci := [vis.bone_position(&"HoldPoint"), vis.bone_position(&"HoldPoint_L"), vis.bone_position(&"head")]
	var dj := 0.0
	for i in 3:
		dj = maxf(dj, (p_end[i] as Vector3).distance_to(p_ci[i]))
	r.check(dj < 0.015, "chars: G19 %s pick_up termina na pose do carry_idle (desvio %.1f mm)" % [id, dj * 1000])
	vis.seek_clip(&"pick_up", 0.27)
	var grab := (vis.bone_position(&"HoldPoint") + vis.bone_position(&"HoldPoint_L")) * 0.5 - o
	r.check(grab.y < 0.13 and -grab.z > 0.15, "chars: G19 %s pick_up pega no chao a frente dos pes (meio das palmas a %.3f m de altura, %.3f m a frente)" % [id, grab.y, -grab.z])
	# place_* e inspect: terminam de maos vazias na pose de repouso (mao a menos de 4 cm do idle)
	vis.seek_clip(&"idle", 0.0)
	var rest_r := vis.bone_position(&"hand.R")
	for c: StringName in [&"place_high", &"place_low", &"inspect"]:
		vis.seek_clip(c, vis.animation_length(c))
		var dr := vis.bone_position(&"hand.R").distance_to(rest_r)
		r.check(dr < 0.04, "chars: G19 %s/%s volta ao repouso (mao a %.1f cm do idle)" % [id, c, dr * 100])
	# pes plantados nos clipes parados: a bola de cada pe nao anda mais de 1,5 cm e fica no chao (+-2 cm)
	for c: StringName in [&"pick_up", &"carry_idle", &"place_high", &"place_low", &"inspect"]:
		var len := vis.animation_length(c)
		vis.seek_clip(c, 0.0)
		var t0 := [vis.bone_position(&"toe.R"), vis.bone_position(&"toe.L")]
		var drift := 0.0
		var high := 0.0
		for i in 13:
			vis.seek_clip(c, len * i / 12.0)
			for k in 2:
				var p := vis.bone_position(&"toe.R" if k == 0 else &"toe.L")
				var q: Vector3 = t0[k]
				drift = maxf(drift, Vector2(p.x, p.z).distance_to(Vector2(q.x, q.z)))
				high = maxf(high, absf(p.y - o.y))
		r.check(drift < 0.015 and high < 0.02, "chars: G19 %s/%s pes plantados (bola do pe anda %.1f mm, altura ate %.1f mm)" % [id, c, drift * 1000, high * 1000])
	print("  medida G19 %s: pega no chao a %.3f m de altura e %.3f m a frente; fim do pick_up a %.1f mm do carry_idle" % [id, grab.y, -grab.z, dj * 1000])
	root.queue_free()
	await r.frames(1)


## Pico (G19): escalada. climb_up*: nenhum osso do corpo entra no degrau mais de 1 cm, a palma apoia no topo (<= 4 cm), o
## clipe termina de pe EM CIMA, deslocado (0, H, -0,3028), com o calcanhar no topo. climb_down e o inverso (0,9 m, de
## costas). climb_wall: maos e pes do lado de fora da parede e o membro de apoio desce a 0,25 m/s (o ator sobe nessa
## velocidade). climb_top termina de pe em cima da borda.
func _test_pico_climb() -> void:
	var root := await _spawn("pico")
	var vis := root.find_child("Model", false, false) as CharacterVisual
	var o := root.global_position
	vis.seek_clip(&"idle", 0.0)
	var face_d := -(vis.bone_position(&"toe_tip.R") - o).z + 0.03       # face do degrau, a frente do ator (m)
	var heel0 := vis.bone_position(&"heel.R").y - o.y
	var body := [&"hand.R", &"hand.L", &"HoldPoint", &"HoldPoint_L", &"forearm.R", &"forearm.L", &"toe_tip.R", &"toe_tip.L",
		&"toe.R", &"toe.L", &"heel.R", &"heel.L", &"foot.R", &"foot.L", &"shin.R", &"shin.L", &"hips", &"chest", &"neck"]
	for c: String in ["climb_up_low", "climb_up", "climb_up_high", "climb_down"]:
		var n := StringName(c)
		var len := vis.animation_length(n)
		var down := c == "climb_down"
		var h := 0.9 if down else float(CLIMB_H[c])
		var d0 := face_d - (0.3028 if down else 0.0)      # volume do degrau: a frente de d0 e abaixo de `top`
		var top := 0.0 if down else h
		var worst := INF
		var worst_b := &""
		var best_palm := INF
		for i in 61:
			vis.seek_clip(n, len * i / 60.0)
			for b: StringName in body:
				var p := vis.bone_position(b) - o
				var clear := maxf(d0 - (-p.z), p.y - top)
				if clear < worst:
					worst = clear
					worst_b = b
			var pr := vis.bone_position(&"HoldPoint") - o
			if -pr.z > d0:
				best_palm = minf(best_palm, absf(pr.y - top))
		r.check(worst > -0.01, "chars: G19 pico/%s nada entra no degrau (pior %s a %.1f mm)" % [c, worst_b, worst * 1000])
		r.check(best_palm < 0.04, "chars: G19 pico/%s palma apoiada no topo do degrau (%.1f mm)" % [c, best_palm * 1000])
		vis.seek_clip(n, 0.0)
		var a := vis.bone_position(&"hips") - o
		vis.seek_clip(n, len)
		var e := vis.bone_position(&"hips") - o
		var want := Vector3(0, -h if down else h, 0.3028 if down else -0.3028)
		r.check((e - a).distance_to(want) < 0.01, "chars: G19 pico/%s desloca o corpo %s (medido %s)" % [c, want, e - a])
		var heel_err := (vis.bone_position(&"heel.R").y - o.y) - (heel0 + (0.0 if down else h) - (h if down else 0.0))
		r.check(absf(heel_err) < 0.02, "chars: G19 pico/%s termina com o pe no apoio (calcanhar a %.1f mm)" % [c, heel_err * 1000])
		print("  medida G19 pico %s: pior folga %.1f mm (%s), palma no topo %.1f mm, deslocamento %s" % [c, worst * 1000, worst_b, best_palm * 1000, e - a])
	# climb_wall: parede a 0,203 m a frente (barriga + 7,5 cm; info.json "g19/climb_wall")
	var wall := 0.203
	var len_w := vis.animation_length(&"climb_wall")
	var worst_w := INF
	var vs: Array = []
	var prev := {}
	for i in 49:
		vis.seek_clip(&"climb_wall", minf(len_w * i / 48.0, len_w - 0.0005))
		var cur := {}
		for b: StringName in body:
			var p := vis.bone_position(b) - o
			worst_w = minf(worst_w, wall - (-p.z))
			cur[b] = p
		for b: StringName in [&"toe.R", &"toe.L", &"HoldPoint", &"HoldPoint_L"]:
			if not prev.is_empty():
				var pa: Vector3 = prev[b]
				var pb: Vector3 = cur[b]
				var v := (pa.y - pb.y) / (len_w / 48.0)
				if absf(pb.z - pa.z) < 0.0005 and v > 0.05:
					vs.append(v)
		prev = cur
	var mean := 0.0
	for v in vs:
		mean += v
	mean /= maxf(vs.size(), 1.0)
	r.check(worst_w > -0.01, "chars: G19 pico/climb_wall maos e pes do lado de fora da parede (pior %.1f mm)" % (worst_w * 1000))
	r.check(vs.size() >= 20 and absf(mean - 0.25) < 0.03, "chars: G19 pico/climb_wall membro de apoio desce a 0,25 m/s (%.3f m/s, %d amostras)" % [mean, vs.size()])
	vis.seek_clip(&"idle", 0.0)
	var hips0 := vis.bone_position(&"hips") - o
	vis.seek_clip(&"climb_top", vis.animation_length(&"climb_top"))
	var ct1 := vis.bone_position(&"hips") - o
	r.check((ct1 - hips0).distance_to(Vector3(0, 0.7887, -0.303)) < 0.015, "chars: G19 pico/climb_top termina de pe em cima da borda (quadril %s do idle)" % [ct1 - hips0])
	print("  medida G19 pico climb_wall: pior folga %.1f mm, apoio desce %.3f m/s; climb_top quadril %s do idle" % [worst_w * 1000, mean, ct1 - hips0])
	root.queue_free()
	await r.frames(1)
