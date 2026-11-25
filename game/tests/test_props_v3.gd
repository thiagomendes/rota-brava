extends RefCounted
## Pecas das missoes do Ep01 v3 (RB-R1, art3d): cada cena em game/assets/models/props_v3/ carrega, tem a raiz na
## origem com escala 1, tamanho de objeto real, metadados de jogo, materiais com regra, tris dentro do orcamento e as
## animacoes com os nomes combinados (que tocam). Gaivota: esqueleto, 5 acoes, loops e peixe no bico. Corda: comprimento.
## Nao comprova gosto nem luz: isso e visto nas capturas (captures/props_v3/).

const DIR := "res://assets/models/props_v3/"
## id -> [animacoes, tamanho minimo (m), tamanho maximo (m) da maior medida da caixa no repouso]
const PIECES := {
	"cloth_tshirt": [["sway", "shake"], 0.45, 0.7],
	"cloth_scarf": [["sway", "shake"], 0.35, 0.6],
	"cloth_sock": [["sway", "shake"], 0.2, 0.45],
	"basket": [[], 0.55, 0.9],
	"fountain_leaves": [["rustle", "pull_out", "reset"], 0.4, 0.75],
	"ball": [["roll", "bounce"], 0.3, 0.36],
	"crate_apple": [[], 0.4, 0.5],
	"crate_lemon": [[], 0.4, 0.5],
	"crate_grapes": [[], 0.4, 0.5],
	"fish": [["flop"], 0.3, 0.45],
	"gull": [["perch_idle", "fly", "glide", "land", "flee"], 1.0, 1.6],
	"tow_rope": [[], 2.9, 3.3],
	"help_arrow": [["point", "appear"], 0.5, 0.8],
	"target_ring": [["pulse"], 0.9, 1.1],
	"emblem_paw": [["spin", "collect"], 0.5, 1.1],
	"emblem_carabiner": [["spin", "collect"], 0.5, 1.1],
	"emblem_helm": [["spin", "collect"], 0.5, 1.1],
	"emblem_compass": [["spin", "collect"], 0.5, 1.1],
	"emblem_star": [["spin", "collect"], 0.5, 1.1],
}
const LOOPS := ["sway", "rustle", "roll", "flop", "perch_idle", "fly", "glide", "point", "pulse", "spin"]
const META_KEYS := ["piece_id", "mission", "interactive", "interaction", "member", "tris", "tris_budget", "pivot"]

var r


func run(runner) -> void:
	r = runner
	var holder := Node3D.new()
	holder.name = "PropsV3Test"
	r.tree.root.add_child(holder)
	for id: String in PIECES:
		await _test_piece(holder, id)
	await _test_gull(holder)
	await _test_rope(holder)
	_test_files()
	holder.queue_free()
	await r.frames(1)


func _aabb(n: Node, root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if not mi.is_visible_in_tree():
			continue
		var b: AABB = root.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _test_piece(holder: Node3D, id: String) -> void:
	var path := DIR + id + ".tscn"
	r.check(ResourceLoader.exists(path), "pv3 %s: cena existe" % id)
	if not ResourceLoader.exists(path):
		return
	var p := (load(path) as PackedScene).instantiate() as PropsV3Piece
	r.check(p != null, "pv3 %s: raiz e PropsV3Piece" % id)
	if p == null:
		return
	r.check(p.transform == Transform3D.IDENTITY, "pv3 %s: raiz na origem, escala 1" % id)
	var ok_meta := true
	for k: String in META_KEYS:
		ok_meta = ok_meta and p.has_meta(k)
	r.check(ok_meta and String(p.get_meta("piece_id")) == id, "pv3 %s: metadados (missao, interativo, verbo, heroi, tris)" % id)
	r.check(not bool(p.get_meta("provisional", true)), "pv3 %s: nao e bloco provisorio" % id)
	holder.add_child(p)
	await r.frames(2)
	# materiais: toda superficie com regra (wv2_* da vila ou pv3_* proprio) e trocada
	var surfaces := 0
	var replaced := 0
	for c in p.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			surfaces += 1
			var src := mi.mesh.surface_get_material(i)
			var ov := mi.get_surface_override_material(i)
			if src != null and ov != null and (src.resource_name.begins_with("wv2_") or src.resource_name.begins_with("pv3_")):
				replaced += 1
	r.check(surfaces > 0 and replaced == surfaces, "pv3 %s: %d/%d superficies com material da biblioteca" % [id, replaced, surfaces])
	var tris := p.triangle_count()
	var budget := int(p.get_meta("tris_budget"))
	r.check(tris > 0 and tris <= budget, "pv3 %s: %d tris <= orcamento %d" % [id, tris, budget])
	r.check(absi(tris - int(p.get_meta("tris"))) <= int(p.get_meta("tris")) / 10 + 8,
		"pv3 %s: tris anotados (%d) batem com a malha (%d)" % [id, int(p.get_meta("tris")), tris])
	# tamanho real, antes de tocar animacoes (gaivota: medida no proprio teste dela; emblema inclui a altura da moeda)
	var spec: Array = PIECES[id]
	if id != "gull":
		var box := _aabb(p, p)
		var big := maxf(box.size.x, maxf(box.size.y, box.size.z))
		r.check(big >= float(spec[1]) and big <= float(spec[2]),
			"pv3 %s: maior medida %.2f m em [%.2f, %.2f]" % [id, big, float(spec[1]), float(spec[2])])
	# animacoes com os nomes combinados, loops certos e que tocam
	var want: Array = spec[0]
	var ap := p.animation_player()
	if want.is_empty():
		r.check(ap == null, "pv3 %s: sem animacao (peca parada)" % id)
	else:
		var names := p.animation_names()
		var has_all := ap != null
		var loops_ok := ap != null
		for a: String in want:
			has_all = has_all and names.has(a)
			if ap != null and ap.has_animation(a):
				var looped := ap.get_animation(a).loop_mode != Animation.LOOP_NONE
				loops_ok = loops_ok and (looped == (a in LOOPS))
		r.check(has_all, "pv3 %s: animacoes %s (tem %s)" % [id, str(want), str(names)])
		r.check(loops_ok, "pv3 %s: loop so nas animacoes continuas" % id)
		var played := true
		for a: String in want:
			played = played and p.play(StringName(a))
			ap.advance(0.1)
		r.check(played, "pv3 %s: todas as animacoes tocam" % id)
		ap.stop()
		if p.autoplay_anim != &"":
			p.play(p.autoplay_anim)
	p.queue_free()
	await r.frames(1)


func _test_gull(holder: Node3D) -> void:
	var g := (load(DIR + "gull.tscn") as PackedScene).instantiate() as PropsV3Gull
	r.check(g != null, "pv3 gaivota: script PropsV3Gull")
	if g == null:
		return
	holder.add_child(g)
	await r.frames(2)
	var sk := g.get_node_or_null(^"Model/gull_rig/Skeleton3D") as Skeleton3D
	r.check(sk != null and sk.get_bone_count() == 10, "pv3 gaivota: esqueleto com 10 ossos")
	if sk != null:
		var ok := true
		for b: String in ["root", "body", "head", "tail", "wing_in_L", "wing_out_L", "wing_in_R", "wing_out_R", "leg_L", "leg_R"]:
			ok = ok and sk.find_bone(b) >= 0
		r.check(ok, "pv3 gaivota: ossos com nomes claros")
		# envergadura no repouso (asas abertas): 1,1 a 1,4 m; altura em pe 0,4 a 0,6 m
		var box := AABB()
		var mi := g.get_node_or_null(^"Model/gull_rig/Skeleton3D/pv3_gull") as MeshInstance3D
		if mi != null:
			box = mi.mesh.get_aabb()
		r.check(box.size.x > 1.1 and box.size.x < 1.4 and box.size.y > 0.4 and box.size.y < 0.6,
			"pv3 gaivota: envergadura %.2f m, altura %.2f m" % [box.size.x, box.size.y])
	var ap := g.animation_player()
	r.check(ap != null and ap.current_animation == "perch_idle", "pv3 gaivota: comeca pousada (perch_idle)")
	var hold := g.get_node_or_null(^"Model/gull_rig/Skeleton3D/BeakSocket/FishHold") as Node3D
	var fish := g.get_node_or_null(^"Model/gull_rig/Skeleton3D/BeakSocket/FishHold/Fish") as Node3D
	r.check(hold != null and fish != null and fish.visible, "pv3 gaivota: peixe no bico (BeakSocket/FishHold/Fish)")
	if fish != null and sk != null:
		var beak: Vector3 = g.global_transform.affine_inverse() * fish.global_position
		r.check(beak.distance_to(PropsV3Gull.BEAK_HOLD) < 0.12, "pv3 gaivota: peixe junto ao bico (%s)" % str(beak))
		# o encaixe segue a cabeca: em `flee` a cabeca sobe com o corpo
		ap.play(&"flee")
		ap.seek(0.9, true)
		await r.frames(2)
		var up: Vector3 = g.global_transform.affine_inverse() * fish.global_position
		r.check(up.y > beak.y + 0.6, "pv3 gaivota: em flee o peixe sobe com a cabeca (%.2f -> %.2f m)" % [beak.y, up.y])
		ap.play(&"land")
		ap.seek(1.2, true)
		await r.frames(2)
		var down: Vector3 = g.global_transform.affine_inverse() * fish.global_position
		r.check(absf(down.y - beak.y) < 0.12, "pv3 gaivota: land termina no chao (bico a %.2f m)" % down.y)
	g.carrying_fish = false
	r.check(fish != null and not fish.visible, "pv3 gaivota: carrying_fish = false esconde o peixe")
	var lens := {}
	if ap != null:
		for a in ["land", "flee", "fly"]:
			lens[a] = ap.get_animation(a).length
	r.check(lens.size() == 3 and absf(float(lens["land"]) - 1.2) < 0.05 and absf(float(lens["flee"]) - 1.0) < 0.05 and
		absf(float(lens["fly"]) - 0.8) < 0.05, "pv3 gaivota: duracoes land 1,2 s, flee 1,0 s, fly 0,8 s (%s)" % str(lens))
	g.queue_free()
	await r.frames(1)


func _test_rope(holder: Node3D) -> void:
	var rope := (load(DIR + "tow_rope.tscn") as PackedScene).instantiate() as PropsV3TowRope
	r.check(rope != null, "pv3 corda: script PropsV3TowRope")
	if rope == null:
		return
	holder.add_child(rope)
	await r.frames(1)
	rope.length = 6.5
	var end := rope.get_node_or_null(^"End") as Node3D
	var eye := rope.get_node_or_null(^"Model/pv3_rope_eye_end") as Node3D
	r.check(end != null and is_equal_approx(end.position.z, 6.5), "pv3 corda: marcador End na ponta (6,5 m)")
	r.check(eye != null and is_equal_approx(eye.position.z, 6.5) and is_equal_approx(eye.scale.z, 1.0),
		"pv3 corda: alca do fim acompanha sem esticar")
	var box := _aabb(rope, rope)
	r.check(box.size.z > 6.5 and box.size.z < 6.8, "pv3 corda: comprimento visivel %.2f m" % box.size.z)
	rope.coiled = true
	var coil := rope.get_node_or_null(^"Model/pv3_rope_coil") as Node3D
	var span := rope.get_node_or_null(^"Model/pv3_rope_span") as Node3D
	r.check(coil != null and coil.visible and span != null and not span.visible, "pv3 corda: modo rolo (coiled)")
	rope.queue_free()
	await r.frames(1)


func _test_files() -> void:
	var man_path := ProjectSettings.globalize_path("res://").path_join("../source_art/manifest.json")
	var man: Variant = JSON.parse_string(FileAccess.get_file_as_string(man_path))
	r.check(man is Dictionary, "pv3 manifesto: source_art/manifest.json legivel")
	var count := 0
	if man is Dictionary:
		for a: Dictionary in (man as Dictionary).get("ativos", []):
			if String(a.get("id", "")).begins_with("props_v3_") and a.has("glb_sha256"):
				count += 1
				var path := "res://" + String(a["saida_glb"]).trim_prefix("game/")
				var bytes := FileAccess.get_file_as_bytes(path)
				var ok := bytes.size() == int(a["glb_bytes"])
				var ctx := HashingContext.new()
				ctx.start(HashingContext.HASH_SHA256)
				ctx.update(bytes)
				ok = ok and ctx.finish().hex_encode() == String(a["glb_sha256"])
				r.check(ok, "pv3 manifesto: %s sha256 e bytes conferem" % String(a["id"]))
	r.check(count == PIECES.size(), "pv3 manifesto: %d pecas listadas (esperado %d)" % [count, PIECES.size()])
