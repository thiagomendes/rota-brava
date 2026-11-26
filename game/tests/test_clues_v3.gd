extends RefCounted
## Pistas F2 do Ep01 v3 (RB-R1, art3d; docs/proposals/ep01_v3_roteiro_intuitivo.md, P1): bota do capitao, pena solta,
## anel de alvo alto (game/assets/models/props_v3/) e decalques grandes (game/worlds/village_v3/decals/).
## Confere: cena carrega, raiz na origem, metadados (piece_id, mission, provisional = false, tris), tris dentro do
## orcamento e iguais aos anotados, tamanho real, materiais com regra, animacoes; decalques >= 0,45 m no que aparece,
## textura com halo claro E aro escuro (contraste nos dois tipos de piso), emissao para a noite, antigos mantidos.
## Nao comprova leitura na tela: isso e visto nas capturas (captures/f2_arte/).

const DIR := "res://assets/models/props_v3/"
const DEC := "res://worlds/village_v3/decals/"
## id -> [animacoes, maior medida minima (m), maxima (m), mission]
const PIECES := {
	"captain_boot": [[], 0.65, 0.9, "M1"],
	"feather": [["flutter"], 0.45, 0.6, "M5"],
	"target_ring_tall": [["pulse"], 1.8, 2.3, ""],
}
## decalques novos -> missao
const DECALS := {
	"decal_paw_big": "M1", "decal_paw_wet_big": "M2", "decal_paw_dock": "M1", "decal_feather_big": "M5",
	"decal_boot_print_l": "M1", "decal_boot_print_r": "M1",
}
const OLD_DECALS := ["decal_paw", "decal_paw_wet", "decal_feather", "decal_scale"]

var r


func run(runner) -> void:
	r = runner
	var holder := Node3D.new()
	holder.name = "CluesV3Test"
	r.tree.root.add_child(holder)
	for id: String in PIECES:
		await _test_piece(holder, id)
	await _test_ring_tall(holder)
	for id: String in DECALS:
		_test_decal(id)
	for id: String in OLD_DECALS:
		r.check(ResourceLoader.exists(DEC + id + ".tscn"), "cv3 decalque antigo %s mantido" % id)
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
	r.check(ResourceLoader.exists(path), "cv3 %s: cena existe" % id)
	if not ResourceLoader.exists(path):
		return
	var p := (load(path) as PackedScene).instantiate() as PropsV3Piece
	r.check(p != null, "cv3 %s: raiz e PropsV3Piece" % id)
	if p == null:
		return
	var spec: Array = PIECES[id]
	r.check(p.transform == Transform3D.IDENTITY, "cv3 %s: raiz na origem, escala 1" % id)
	r.check(String(p.get_meta("piece_id", "")) == id and String(p.get_meta("mission", "?")) == String(spec[3]),
		"cv3 %s: piece_id e mission (%s)" % [id, spec[3]])
	r.check(p.has_meta("provisional") and not bool(p.get_meta("provisional")), "cv3 %s: provisional = false" % id)
	holder.add_child(p)
	await r.frames(2)
	var surfaces := 0
	var replaced := 0
	for c in p.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			surfaces += 1
			var src := mi.mesh.surface_get_material(i)
			if src != null and mi.get_surface_override_material(i) != null:
				replaced += 1
	r.check(surfaces > 0 and replaced == surfaces, "cv3 %s: %d/%d superficies com material da biblioteca" % [id, replaced, surfaces])
	var tris := p.triangle_count()
	var budget := int(p.get_meta("tris_budget", 0))
	r.check(tris > 0 and tris <= budget, "cv3 %s: %d tris <= orcamento %d" % [id, tris, budget])
	r.check(absi(tris - int(p.get_meta("tris", -1))) <= int(p.get_meta("tris", 0)) / 10 + 8,
		"cv3 %s: tris anotados (%d) batem com a malha (%d)" % [id, int(p.get_meta("tris", -1)), tris])
	var box := _aabb(p, p)
	var big := maxf(box.size.x, maxf(box.size.y, box.size.z))
	r.check(big >= float(spec[1]) and big <= float(spec[2]), "cv3 %s: maior medida %.2f m em [%.2f, %.2f]" % [id, big,
		float(spec[1]), float(spec[2])])
	r.check(box.position.y > -0.03 and box.position.y < 0.03, "cv3 %s: assenta no chao (base y %.3f)" % [id, box.position.y])
	var want: Array = spec[0]
	var ap := p.animation_player()
	if want.is_empty():
		r.check(ap == null, "cv3 %s: peca parada (sem animacao)" % id)
	else:
		var ok := ap != null
		for a: String in want:
			ok = ok and ap.has_animation(a) and ap.get_animation(a).loop_mode != Animation.LOOP_NONE and p.play(StringName(a))
			if ap != null:
				ap.advance(0.3)
		r.check(ok, "cv3 %s: animacoes em loop %s tocam" % [id, str(want)])
	p.queue_free()
	await r.frames(1)


func _test_ring_tall(holder: Node3D) -> void:
	var p := (load(DIR + "target_ring_tall.tscn") as PackedScene).instantiate() as PropsV3Piece
	holder.add_child(p)
	await r.frames(2)
	var beam := p.get_node_or_null(^"Beam/Model/pv3_target_beam") as MeshInstance3D
	r.check(beam != null, "cv3 anel alto: pilar de luz presente")
	if beam != null:
		var m := beam.get_surface_override_material(0) as StandardMaterial3D
		r.check(m != null and m.blend_mode == BaseMaterial3D.BLEND_MODE_ADD and m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,
			"cv3 anel alto: pilar aditivo e sem luz")
		r.check(beam.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "cv3 anel alto: pilar sem sombra")
		r.check(beam.get_aabb().size.y >= 1.5, "cv3 anel alto: pilar com %.2f m (passa da grama alta)" % beam.get_aabb().size.y)
	var hi := p.get_node_or_null(^"RingsHigh") as Node3D
	r.check(hi != null and hi.position.y >= 0.4, "cv3 anel alto: anel de cima acima do capim (>= 0,4 m)")
	p.queue_free()
	await r.frames(1)


func _test_decal(id: String) -> void:
	var path := DEC + id + ".tscn"
	r.check(ResourceLoader.exists(path), "cv3 %s: cena existe" % id)
	if not ResourceLoader.exists(path):
		return
	var d := (load(path) as PackedScene).instantiate() as Decal
	r.check(d != null, "cv3 %s: raiz e Decal" % id)
	if d == null:
		return
	r.check(d.transform == Transform3D.IDENTITY, "cv3 %s: raiz na origem" % id)
	r.check(String(d.get_meta("piece_id", "")) == id and String(d.get_meta("mission", "")) == String(DECALS[id]),
		"cv3 %s: piece_id e mission" % id)
	r.check(d.has_meta("provisional") and not bool(d.get_meta("provisional")) and int(d.get_meta("tris", -1)) == 0,
		"cv3 %s: provisional = false e tris = 0 (projetado)" % id)
	var vis: Array = d.get_meta("visible_m", [0.0, 0.0])
	r.check(maxf(float(vis[0]), float(vis[1])) >= 0.45, "cv3 %s: parte visivel %.2f m >= 0,45 m" % [id, maxf(float(vis[0]), float(vis[1]))])
	r.check(d.size.x >= float(vis[0]) and d.size.z >= float(vis[1]), "cv3 %s: caixa do Decal cobre o desenho" % id)
	var tex := d.texture_albedo
	r.check(tex != null and d.texture_emission != null and d.emission_energy > 0.0, "cv3 %s: albedo + emissao (noite)" % id)
	if tex == null:
		return
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	# contraste: dentro do que aparece ha pixel CLARO (halo) e pixel ESCURO (miolo ou aro), ambos opacos
	var light := 0
	var dark := 0
	var step := maxi(1, img.get_width() / 96)
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			var c := img.get_pixel(x, y)
			if c.a < 0.6:
				continue
			if c.get_luminance() > 0.8:
				light += 1
			elif c.get_luminance() < 0.25:
				dark += 1
	r.check(light > 30 and dark > 30, "cv3 %s: halo claro (%d) e contorno/miolo escuro (%d)" % [id, light, dark])
	d.free()
