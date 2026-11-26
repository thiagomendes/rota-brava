extends Node3D
## Provas de legibilidade das pistas F2 (RB-R1, art3d): poe as pistas novas (bota do capitao, pegadas grandes, pena,
## anel alto) na vila v3 nos lugares propostos pela auditoria (docs/proposals/ep01_v3_roteiro_intuitivo.md) e uma
## camera na altura da camera baixa do jogo (1,95 m sobre o chao, 12 graus para baixo, FOV 50).
## So para capturas (Movie Maker); NAO e jogo e nada aqui e usado pelo episodio.
## Linha de comando (apos --):
##   --cv3-view=<boot8|boot4|bench|floor_dirt|floor_grass|floor_stone|floor_wood|feather|ring_grass>
##   --cv3-view=top --cv3-at=x,z  planta vista de cima com anel em cada marcador do M1 (escolher lugar)
##   --cv3-night                  noite (VillageWorld.set_night)
##   --cv3-at=x,z --cv3-yaw=<graus>   (floor_*) troca o lugar e o rumo da fileira de pegadas

const WORLD := "res://worlds/village_v3/village_world.tscn"
const PIECE := "res://assets/models/props_v3/%s.tscn"
const DECAL := "res://worlds/village_v3/decals/%s.tscn"
const HERO := "res://lookdev/%s_v2_model.tscn"
const CAM_H := 1.95
## rumo da bota na vila (graus): a boca do cano com a dobra branca e a sola clara viradas para quem vem do banco
const BOOT_YAW := 300.0
const LOW_PITCH := 12.0
## lugar das fileiras de pegadas por piso: [x, z, rumo da camera para a fileira em graus (0 = -Z), espaco entre pegadas]
const FLOORS := {
	"floor_dirt": [-5.0, 9.2, 90.0, 0.5],
	"floor_grass": [-2.0, 12.6, 160.0, 0.75],
	"floor_stone": [-10.5, -15.2, 90.0, 0.55],
	"floor_wood": [-3.2, 0.8, 90.0, 0.6],
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
	await get_tree().physics_frame
	await get_tree().physics_frame
	var view := _arg("--cv3-view", "boot8")
	if OS.get_cmdline_user_args().has("--cv3-night"):
		world.set_night(true)
	match view:
		"boot8":
			_boot(8.0)
		"boot4":
			_boot(4.0)
		"bench":
			_bench()
		"feather":
			_feather()
		"ring_grass":
			_ring_grass()
		"top":
			# planta de cima (so para escolher lugares): --cv3-at=x,z
			var a := _arg("--cv3-at", "-5,-2").split_floats(",")
			cam.global_position = Vector3(a[0], 14.0, a[1])
			cam.look_at(Vector3(a[0], 0.0, a[1]), Vector3.FORWARD)
			for mk in world.markers_for("M1"):
				var tr := (load(PIECE % "target_ring") as PackedScene).instantiate() as Node3D
				add_child(tr)
				tr.global_position = mk.global_position
		_:
			if FLOORS.has(view):
				_floor(view)
	print("[CV3] vista ", view)


## Ground: raio de cima para baixo na camada de colisao 1 (chao, cais, rua).
func _ground(x: float, z: float, from_y: float = 3.0) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, -4.0, z), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return (hit.position as Vector3).y if not hit.is_empty() else 0.0


func _on_ground(x: float, z: float) -> Vector3:
	return Vector3(x, _ground(x, z, 0.9), z)   # 0,9 m: chao, nao copa de arvore nem teto de cabine


## Camera baixa do jogo: 1,95 m acima do chao em `pos`, olhando no plano para `target`, 12 graus para baixo.
func _camera(pos: Vector3, target: Vector3) -> void:
	# raio de 0,9 m: o chao do cais/rua, nao o teto da cabine do barco atracado
	var p := Vector3(pos.x, _ground(pos.x, pos.z, 0.9) + CAM_H, pos.z)
	var flat := (Vector3(target.x, 0.0, target.z) - Vector3(p.x, 0.0, p.z)).normalized()
	var c := cos(deg_to_rad(LOW_PITCH))
	cam.global_position = p
	cam.look_at(p + Vector3(flat.x * c, -sin(deg_to_rad(LOW_PITCH)), flat.z * c), Vector3.UP)


func _piece(id: String, pos: Vector3, yaw_deg: float = 0.0) -> PropsV3Piece:
	var p := (load(PIECE % id) as PackedScene).instantiate() as PropsV3Piece
	add_child(p)
	p.global_position = pos
	p.rotation.y = deg_to_rad(yaw_deg)
	return p


## Decalque com a frente (-Z: dedos, ponta, bico) apontando para `toward`.
func _decal(id: String, pos: Vector3, toward: Vector3) -> Decal:
	var d := (load(DECAL % id) as PackedScene).instantiate() as Decal
	add_child(d)
	d.global_position = pos
	var dir := Vector3(toward.x - pos.x, 0.0, toward.z - pos.z)
	if dir.length() > 0.01:
		d.rotation.y = atan2(-dir.x, -dir.z)
	return d


func _hero(id: String, pos: Vector3, face: Vector3) -> void:
	var h := (load(HERO % id) as PackedScene).instantiate() as Node3D
	add_child(h)
	h.global_position = pos
	h.look_at(Vector3(face.x, pos.y, face.z), Vector3.UP, true)
	var vis := h.get_node_or_null("Model") as CharacterVisual
	if vis != null:
		vis.play(&"idle")


func _mk(n: String) -> Vector3:
	var m := world.marker(StringName(n))
	return m.global_position if m != null else Vector3.ZERO


## M1 proposto (auditoria 2.1): pata de lama na tabua junto ao barco (M1_BenchClue), 3 pegadas de bota para o
## oeste e a bota caida junto a amarra vazia (M1_EmptyMooring), a ~7 m. Camera a `dist` da bota, do lado do banco.
func _boot(dist: float) -> void:
	var bench := _mk("M1_BenchClue")
	var moor := _mk("M1_EmptyMooring")
	# junto a amarra vazia, a ~2,7 m do poste, na tabua livre ao leste dos caixotes (fora da frente dos postes) (planta --cv3-view=top)
	var boot := _on_ground(moor.x + 2.3, moor.z + 1.4)
	var east := Vector3(bench.x - boot.x, 0.0, bench.z - boot.z).normalized()
	_piece("captain_boot", boot, float(_arg("--cv3-boot-yaw", str(BOOT_YAW))))
	_decal("decal_paw_dock", _on_ground(bench.x, bench.z + 0.3), bench + Vector3(-1, 0, 2))
	for i in 3:
		var t := 1.0 + 1.6 * i
		var side := Vector3(-east.z, 0, east.x) * (0.18 if i % 2 == 0 else -0.18)
		var p := boot + east * t + side
		_decal("decal_boot_print_%s" % ("l" if i % 2 == 0 else "r"), _on_ground(p.x, p.z), boot)
	var cam_at := boot + east * dist
	_camera(cam_at, boot)
	if dist <= 4.5:
		_hero("rastro", _on_ground(cam_at.x - east.x * 2.2 - east.z * 1.3, cam_at.z - east.z * 2.2 + east.x * 1.3), boot)


## M1.bench: a pata de lama na tabua vista do inicio do M1 (camera a ~5 m, como em captures/f2/m1_a_inicio.png).
func _bench() -> void:
	var bench := _mk("M1_BenchClue")
	var p := _on_ground(bench.x, bench.z + 0.3)
	_decal("decal_paw_dock", p, bench + Vector3(-1, 0, 2))
	_camera(Vector3(bench.x - 0.9, 0, bench.z + 5.2), p)
	_hero("rastro", _on_ground(bench.x - 2.2, bench.z + 2.6), p)


## Fileira lado a lado: antigos (0,24 m) e novos (>= 0,45 m), camera a 4,5 m.
func _floor(view: String) -> void:
	var f: Array = FLOORS[view]
	var at := _arg("--cv3-at", "")
	var x: float = f[0]
	var z: float = f[1]
	if at != "":
		var a := at.split_floats(",")
		x = a[0]
		z = a[1]
	var yaw := deg_to_rad(float(_arg("--cv3-yaw", str(f[2]))))
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))     # da camera para a fileira
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var center := Vector3(x, 0.0, z)
	var ids := ["decal_paw", "decal_paw_big", "decal_paw_wet", "decal_paw_wet_big", "decal_feather", "decal_feather_big",
		"decal_boot_print_r"]
	var gap: float = f[3]
	for i in ids.size():
		var p := center + right * gap * (i - 3)
		_decal(ids[i], _on_ground(p.x, p.z), p + fwd)
	_camera(center - fwd * 4.5, center)


## M5: pena em decalque (nova e antiga) e a pena 3D na pedra da rua, camera a 4 m (de dia e com --cv3-night).
func _feather() -> void:
	var a := _mk("M5_FeatherTrail_2")
	var fwd := Vector3(-1, 0, 0)
	var right := Vector3(0, 0, -1)
	# penas de lado para a camera (como ficam numa trilha que cruza a vista)
	_decal("decal_feather", _on_ground(a.x - right.x * 1.0, a.z - right.z * 1.0), a - right * 3.0 + fwd)
	_decal("decal_feather_big", _on_ground(a.x, a.z), a - right * 3.0 + fwd)
	var f := _piece("feather", _on_ground(a.x - fwd.x * 0.6 + right.x * 1.1, a.z - fwd.z * 0.6 + right.z * 1.1), 70.0)
	f.animation_player().seek(0.4, true)
	_camera(a - fwd * 4.0, a)


## Anel de alvo na grama alta da margem (juncos do M2): o anel atual e o alto, lado a lado, camera a ~5,5 m.
func _ring_grass() -> void:
	var reeds := _mk("M2_ReedsPiece")
	var a := Vector3(reeds.x - 0.3, _ground(reeds.x - 0.3, reeds.z + 1.3, 0.9), reeds.z + 1.3)
	var b := Vector3(reeds.x + 0.3, _ground(reeds.x + 0.3, reeds.z - 0.9, 0.9), reeds.z - 0.9)
	_piece("target_ring", a).animation_player().seek(0.45, true)
	_piece("target_ring_tall", b).animation_player().seek(0.45, true)
	_camera(Vector3(reeds.x - 5.0, 0, reeds.z + 2.6), reeds)   # do lado do cesto (o varal fica atras)


func _arg(flag: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(flag + "="):
			return a.trim_prefix(flag + "=")
	return fallback
