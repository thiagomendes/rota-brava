extends RefCounted
## RB-R1 G23: perna e sapato continuos nos adultos v2 (capitao, Dona Amora, Lumi), em TODOS os quadros de TODOS os clipes.
##
## Mede no GLB importado, com o esqueleto posado pelo AnimationPlayer e a pele calculada na CPU (mesma conta de
## source_art/characters/secondary_v2/measure_feet_g23.py): em cada perna, eixo da canela (joelho -> tornozelo); a perna e
## a malha `*_Cloth` com peso dominante na canela/pe ate 20 cm acima do tornozelo; o sapato e a malha `*_Gear` com peso
## dominante no pe/canela, entre 3 cm abaixo do tornozelo e 30 cm do chao. Cada triangulo vira 7 pontos (vertices, meio das
## arestas, centro). Em 24 setores em volta do eixo, so pontos a 30 mm ou mais do eixo (a borda da silhueta):
## vao = ponto mais baixo da perna - ponto mais alto do sapato. O pior setor, perna e quadro tem de dar <= 0 mm.
## Mutacao embutida: o mesmo modelo com o sapato baixado 60 mm ao longo da canela TEM de dar vao > 0 (a medida enxerga um
## vao); o modelo antigo (antes do G23) dava +35,5 a +39,0 mm (ver o ticket).

const ADULTS := {"captain": "res://actors/characters/captain_model.tscn", "amora": "res://actors/characters/amora_model.tscn",
	"lumi": "res://actors/characters/lumi_model.tscn"}
const FPS := 30.0
const SECTORS := 24
const RMIN := 0.030
const LEG_BAND := 0.20
const SHOE_BAND := -0.03
const SHOE_MAX_H := 0.30
const MUTATION_DROP := 0.060
const LEG_BONES := ["shin", "foot", "toe", "heel"]
const SHOE_BONES := ["shin", "foot", "toe", "toe_tip", "heel"]
const BARY := [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(0.5, 0.5, 0), Vector3(0, 0.5, 0.5),
	Vector3(0.5, 0, 0.5), Vector3(1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0)]

var r


func run(runner) -> void:
	r = runner
	for id in ADULTS:
		await _test_adult(id)


## Malha com pele pronta para calcular na CPU: vertices de repouso, ate 8 ossos por vertice e os triangulos escolhidos.
class Skinned:
	var mi: MeshInstance3D
	var verts := PackedVector3Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var bpv := 4
	var tris := {}          # lado ("R"/"L") -> PackedInt32Array (trios de indices)
	var bind_bone := PackedInt32Array()


func _load_skinned(mi: MeshInstance3D, skel: Skeleton3D, wanted: Array, lo: float, hi: float) -> Skinned:
	var s := Skinned.new()
	s.mi = mi
	var skin := mi.skin
	for b in skin.get_bind_count():
		var bone := skin.get_bind_bone(b)
		if bone < 0:
			bone = skel.find_bone(String(skin.get_bind_name(b)))
		s.bind_bone.append(bone)
	var mesh := mi.mesh
	for side in ["R", "L"]:
		s.tris[side] = PackedInt32Array()
	for si in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bo: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var we: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		if bo.is_empty():
			continue
		s.bpv = bo.size() / v.size()
		var base := s.verts.size()
		s.verts.append_array(v)
		s.bones.append_array(bo)
		s.weights.append_array(we)
		# osso dominante e altura de repouso de cada vertice
		var side_of := PackedStringArray()
		side_of.resize(v.size())
		for i in v.size():
			var best := -1
			var bw := 0.0
			for k in s.bpv:
				if we[i * s.bpv + k] > bw:
					bw = we[i * s.bpv + k]
					best = bo[i * s.bpv + k]
			side_of[i] = ""
			if best < 0 or v[i].y < lo or v[i].y > hi:
				continue
			var bname := skel.get_bone_name(s.bind_bone[best])
			var parts := bname.split(".")
			if parts.size() == 2 and parts[0] in wanted:
				side_of[i] = parts[1]
		# PackedInt32Array e valor (copia): junta numa local e grava de volta no dicionario
		var acc := {"R": s.tris["R"] as PackedInt32Array, "L": s.tris["L"] as PackedInt32Array}
		for t in range(0, idx.size(), 3):
			var sd := side_of[idx[t]]
			if sd != "" and side_of[idx[t + 1]] == sd and side_of[idx[t + 2]] == sd:
				var arr_sd: PackedInt32Array = acc[sd]
				arr_sd.append_array(PackedInt32Array([base + idx[t], base + idx[t + 1], base + idx[t + 2]]))
				acc[sd] = arr_sd
		s.tris = acc
	return s


## Pontos posados (espaco do esqueleto) dos triangulos de um lado; `drop` desloca tudo ao longo de `axis` (mutacao).
func _posed_points(s: Skinned, skel: Skeleton3D, side: String, drop: Vector3) -> PackedVector3Array:
	var mats: Array[Transform3D] = []
	for b in s.bind_bone.size():
		mats.append(skel.get_bone_global_pose(s.bind_bone[b]) * s.mi.skin.get_bind_pose(b))
	var tri: PackedInt32Array = s.tris[side]
	var cache := {}
	var out := PackedVector3Array()
	for t in range(0, tri.size(), 3):
		var p: Array[Vector3] = []
		for c in 3:
			var vi := tri[t + c]
			if not cache.has(vi):
				var acc := Vector3.ZERO
				for k in s.bpv:
					var w := s.weights[vi * s.bpv + k]
					if w > 0.0:
						acc += (mats[s.bones[vi * s.bpv + k]] * s.verts[vi]) * w
				cache[vi] = acc + drop
			p.append(cache[vi])
		for bc in BARY:
			out.append(p[0] * bc.x + p[1] * bc.y + p[2] * bc.z)
	return out


## Vao (m) no pior setor: ponto mais baixo da perna - ponto mais alto do sapato ao longo da canela (<= 0 = sobreposicao).
static func sector_gap(leg: PackedVector3Array, shoe: PackedVector3Array, knee: Vector3, ankle: Vector3) -> float:
	var a := (knee - ankle).normalized()
	var e1 := (Vector3.RIGHT - a * a.x).normalized()
	var e2 := a.cross(e1)
	var low := PackedFloat32Array()
	var high := PackedFloat32Array()
	low.resize(SECTORS)
	high.resize(SECTORS)
	low.fill(INF)
	high.fill(-INF)
	for p in leg:
		var d := p - ankle
		var u := d.dot(a)
		var rv := d - a * u
		if rv.length() < RMIN:
			continue
		var k := int((atan2(rv.dot(e2), rv.dot(e1)) + PI) / TAU * SECTORS) % SECTORS
		low[k] = minf(low[k], u)
	for p in shoe:
		var d := p - ankle
		var u := d.dot(a)
		var rv := d - a * u
		if rv.length() < RMIN:
			continue
		var k := int((atan2(rv.dot(e2), rv.dot(e1)) + PI) / TAU * SECTORS) % SECTORS
		high[k] = maxf(high[k], u)
	var worst := -INF
	for k in SECTORS:
		if low[k] < INF and high[k] > -INF:
			worst = maxf(worst, low[k] - high[k])
	return worst


func _test_adult(id: String) -> void:
	var root := (load(ADULTS[id]) as PackedScene).instantiate() as Node3D
	r.tree.root.add_child(root)
	await r.frames(2)
	var vis := root.find_child("Model", false, false) as CharacterVisual
	var skel := vis.skeleton()
	var cloth := root.find_child("*_Cloth", true, false) as MeshInstance3D
	var gear := root.find_child("*_Gear", true, false) as MeshInstance3D
	r.check(skel != null and cloth != null and gear != null and cloth.skin != null and gear.skin != null,
		"pes: %s tem esqueleto e malhas *_Cloth/*_Gear com pele" % id)
	if skel == null or cloth == null or gear == null:
		root.queue_free()
		return
	var ankle_h := skel.get_bone_global_rest(skel.find_bone("foot.R")).origin.y
	var leg := _load_skinned(cloth, skel, LEG_BONES, -INF, ankle_h + LEG_BAND)
	var shoe := _load_skinned(gear, skel, SHOE_BONES, ankle_h + SHOE_BAND, SHOE_MAX_H)
	for side in ["R", "L"]:
		r.check((leg.tris[side] as PackedInt32Array).size() >= 30 and (shoe.tris[side] as PackedInt32Array).size() >= 30,
			"pes: %s tem perna e sapato %s na faixa do tornozelo (%d/%d triangulos)" % [id, side,
			(leg.tris[side] as PackedInt32Array).size() / 3, (shoe.tris[side] as PackedInt32Array).size() / 3])
	var t0 := Time.get_ticks_msec()
	var report := []
	var mutated := -INF
	for clip in vis.animation_names():
		var n := int(round(vis.animation_length(clip) * FPS))
		var worst := -INF
		var wf := ""
		for f in n + 1:
			vis.seek_clip(clip, minf(f / FPS, vis.animation_length(clip)))
			for side in ["R", "L"]:
				var knee := skel.get_bone_global_pose(skel.find_bone("shin." + side)).origin
				var ankle := skel.get_bone_global_pose(skel.find_bone("foot." + side)).origin
				var g := sector_gap(_posed_points(leg, skel, side, Vector3.ZERO), _posed_points(shoe, skel, side, Vector3.ZERO), knee, ankle)
				if g > worst:
					worst = g
					wf = "%d%s" % [f, side]
				if f == 0 and clip == vis.animation_names()[0]:
					var drop := (ankle - knee).normalized() * MUTATION_DROP
					mutated = maxf(mutated, sector_gap(_posed_points(leg, skel, side, Vector3.ZERO), _posed_points(shoe, skel, side, drop), knee, ankle))
		r.check(worst <= 0.0, "pes: %s em %s: perna sobre o sapato em todos os %d quadros (pior vao %.1f mm, quadro %s)" % [id, clip, n + 1, worst * 1000.0, wf])
		report.append("%s %.1f mm" % [clip, worst * 1000.0])
	r.check(mutated > 0.0, "pes: mutacao (sapato de %s baixado %d mm) abre vao e a medida acusa (%.1f mm)" % [id, int(MUTATION_DROP * 1000), mutated * 1000.0])
	print("  medida pes %s: %s; mutacao %.1f mm; %d ms" % [id, ", ".join(report), mutated * 1000.0, Time.get_ticks_msec() - t0])
	root.queue_free()
	await r.frames(1)
