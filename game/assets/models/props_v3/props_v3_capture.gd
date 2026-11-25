extends Node3D
## Provas das pecas v3 (RB-R1, art3d): poe as pecas na vila v3 (game/worlds/village_v3/village_world.tscn) nos
## marcadores das missoes e uma camera na altura da camera baixa do jogo (1,95 m, 12 graus, FOV 50).
## So para capturas (Movie Maker); NAO e jogo e nada aqui e usado pelo episodio.
## Linha de comando (apos --):
##   --pv3-view=<m2|m3|m4|m5|m6|m7|gerais>   vista com as pecas da missao (m7: so a lente da E3, para avaliar)
##   --pv3-gull=<anim>@<segundos>          vista da gaivota parada num quadro da animacao (fly, land, flee, perch_idle...)

const WORLD := "res://worlds/village_v3/village_world.tscn"
const DIR := "res://assets/models/props_v3/%s.tscn"
const HERO := "res://lookdev/%s_v2_model.tscn"
const LOW_PITCH := 12.0
## vista: [posicao da camera, ponto para onde olha no plano (a inclinacao e sempre 12 graus)]
const VIEWS := {
	"m2": [Vector3(10.9, 1.95, 4.6), Vector3(12.6, 0.0, 7.9)],
	"m3": [Vector3(-28.3, 1.95, 5.6), Vector3(-24.4, 0.0, 1.4)],
	"m4": [Vector3(-19.3, 1.95, 2.3), Vector3(-23.6, 0.0, -4.0)],
	"m5": [Vector3(-12.2, 1.95, -12.0), Vector3(-16.4, 0.0, -16.0)],
	"m6": [Vector3(-3.4, 1.95, 3.6), Vector3(-0.4, 0.0, 0.0)],
	"gerais": [Vector3(-17.6, 1.95, 7.4), Vector3(-21.0, 0.0, 3.4)],
	"m7": [Vector3(27.9, 4.2, -18.9), Vector3(25.8, 0.0, -21.8)],
	"gull": [Vector3(-12.9, 1.95, -12.5), Vector3(-15.6, 0.0, -15.4)],
}

var world: VillageWorld
var cam: Camera3D


func _ready() -> void:
	world = (load(WORLD) as PackedScene).instantiate() as VillageWorld
	add_child(world)
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.05
	cam.far = 600.0
	add_child(cam)
	cam.current = true
	var view := _arg("--pv3-view", "m2")
	var gull := _arg("--pv3-gull", "")
	if gull != "":
		view = "gull"
	_camera(VIEWS.get(view, VIEWS["m2"]))
	match view:
		"m2":
			_m2()
		"m3":
			_m3()
		"m4":
			_m4()
		"m5":
			_m5()
		"m6":
			_m6()
		"gerais":
			_gerais()
		"m7":
			pass   # so a lente da E3 (wv3_lens), que ja esta no mundo
		"gull":
			_gull(gull)
	print("[PV3] vista ", view, " ", gull)


func _camera(v: Array) -> void:
	var pos: Vector3 = v[0]
	var flat := (Vector3(v[1].x, 0.0, v[1].z) - Vector3(pos.x, 0.0, pos.z)).normalized()
	var c := cos(deg_to_rad(LOW_PITCH))
	cam.global_position = pos
	cam.look_at(pos + Vector3(flat.x * c, -sin(deg_to_rad(LOW_PITCH)), flat.z * c), Vector3.UP)


func _mk(n: String) -> Vector3:
	var m := world.marker(StringName(n))
	return m.global_position if m != null else Vector3.ZERO


func _put(id: String, pos: Vector3, ry_deg: float = 0.0) -> PropsV3Piece:
	var p := (load(DIR % id) as PackedScene).instantiate() as PropsV3Piece
	add_child(p)
	p.global_position = pos
	p.rotation.y = deg_to_rad(ry_deg)
	return p


func _face_cam(n: Node3D) -> void:
	var t := Vector3(cam.global_position.x, n.global_position.y, cam.global_position.z)
	n.look_at(t, Vector3.UP, true)


func _hero(id: String, pos: Vector3) -> void:
	var h := (load(HERO % id) as PackedScene).instantiate() as Node3D
	add_child(h)
	h.global_position = pos
	_face_cam(h)
	var vis := h.get_node_or_null("Model") as CharacterVisual
	if vis != null:
		vis.play(&"idle")


## Varal: as 3 pecas na corda do proprio mundo (build_world_v2.py: da mao-francesa do galpao (9,75; 9,0) ao tronco
## (15,32; 6,62), 2,0 m acima do chao com 0,25 m de barriga), entre as roupas que ja estao la; e o cesto.
func _m2() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var a := Vector3(9.75, _ground(9.75, 9.0) + 2.0, 9.0)
	var b := Vector3(15.32, _ground(15.32, 6.62) + 2.0, 6.62)
	var ang := atan2(-(b.z - a.z), b.x - a.x)
	var ids := ["cloth_tshirt", "cloth_scarf", "cloth_sock"]
	var ts := [0.41, 0.585, 0.74]
	for i in 3:
		var t: float = ts[i]
		var p := a.lerp(b, t) - Vector3(0, 0.25 * sin(PI * t), 0)
		var c := _put(ids[i], p, rad_to_deg(ang))
		c.rotation.y = ang
	var line := _mk("M2_Clothesline")
	_put("basket", line + Vector3(-0.5, _ground(line.x - 0.5, line.z - 1.0), -1.0), 20.0)
	_hero("pico", line + Vector3(1.7, _ground(line.x + 1.7, line.z - 0.7), -0.7))


func _ground(x: float, z: float) -> float:
	# raio curto (de 1,4 m): sem acertar telhado do galpao nem copa de arvore
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 1.4, z), Vector3(x, -3.0, z), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return (hit.position as Vector3).y if not hit.is_empty() else 0.0


func _m3() -> void:
	_put("fountain_leaves", _mk("M3_UpperBasin") + Vector3(0, -0.06, 0), 30.0)
	_put("ball", _mk("M3_Grate") + Vector3(-0.1, 0.0, 0.75))
	_hero("rastro", _mk("M3_Grate") + Vector3(-1.2, 0, 2.2))


func _m4() -> void:
	var stalls := {"crate_apple": "M4_Stall_Apple", "crate_lemon": "M4_Stall_Lemon", "crate_grapes": "M4_Stall_Grapes"}
	var k := 0
	for id: String in stalls:
		var p := _put(id, _mk(stalls[id]) + Vector3(0.9, 0, 0.6), 0.0)
		_face_cam(p)
		k += 1
	var ring := _put("target_ring", _mk("M4_Stall_Lemon") + Vector3(0.9, 0, 0.6))
	ring.animation_player().seek(0.5, true)
	_hero("leme", Vector3(-22.6, 0, -1.6))


## Gaivota pousada no toldo com o peixe; peixe solto nos caixotes do Pico.
func _m5() -> void:
	var g := _put("gull", _mk("M5_Awning") + Vector3(0.4, 0.0, 0.35), 0.0)
	_face_cam(g)
	var f := _put("fish", _mk("M5_Crates") + Vector3(0.0, 0.05, 0.0), 0.0)
	f.rotation = Vector3(PI / 2.0, 0.6, 0.0)
	_hero("pico", _mk("M5_Crates") + Vector3(1.6, -0.6, 1.4))


## Corda: rolo no cais e um trecho esticado de 4 m no chao do cais.
func _m6() -> void:
	var rope := _put("tow_rope", Vector3(-1.2, 0.02, 0.6), 35.0) as PropsV3TowRope
	rope.length = 4.0
	var coil := _put("tow_rope", Vector3(0.8, 0.0, 1.6), 0.0) as PropsV3TowRope
	coil.coiled = true
	_hero("pico", Vector3(0.0, 0.0, 1.0))


## Os 5 emblemas em fila, a seta de ajuda e o pulso no chao, na praca.
func _gerais() -> void:
	var base := Vector3(-20.6, 0, 4.2)
	var ids := ["emblem_paw", "emblem_carabiner", "emblem_helm", "emblem_compass", "emblem_star"]
	var right := cam.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	for i in 5:
		var e := _put(ids[i], base + right * (-1.6 + 0.8 * i))
		_face_cam(e)
		e.animation_player().seek(0.0, true)
		e.animation_player().pause()
	var target := base + Vector3(1.2, 0, -1.4)
	var ring := _put("target_ring", target)
	ring.animation_player().seek(0.45, true)
	var arrow := _put("help_arrow", target + Vector3(0, 1.4, 0))
	_face_cam(arrow)
	arrow.animation_player().seek(0.0, true)
	arrow.animation_player().pause()


func _gull(spec: String) -> void:
	var parts := spec.split("@")
	var anim := StringName(parts[0])
	var t := float(parts[1]) if parts.size() > 1 else 0.3
	var g := _put("gull", _mk("M5_Crates") + Vector3(0.3, 0.0, 0.5), 0.0) as PropsV3Gull
	g.look_at(Vector3(cam.global_position.x, g.global_position.y, cam.global_position.z) + Vector3(2.5, 0, -1.0), Vector3.UP, true)
	var ap := g.animation_player()
	ap.play(anim)
	ap.seek(t, true)
	ap.pause()


func _arg(flag: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(flag + "="):
			return a.trim_prefix(flag + "=")
	return fallback
