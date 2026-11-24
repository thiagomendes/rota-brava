extends Node3D
## PREVIEW do mundo inteiro do Ep01 (RB-R1, so capturas; NAO e jogo). PROVISORIO.
## Porto + rio + ilha + horizonte com a luz/ceu/agua do jogo (Atmosphere, WaterSurface). FOV 55.
## Cada vista dura 4 quadros; o quadro 4k+3 e o capturado e imprime "PERF <vista> draw_calls=... primitives=...".
## Uso: ./tools/godot.ps1 --path game res://episodes/ep01/world/preview_world.tscn --write-movie <dir>/f.png --fixed-fps 10 --resolution 1280x720 --quit-after 36

const SCENES := ["res://episodes/ep01/world/harbor_slice.tscn", "res://episodes/ep01/world/river_world.tscn",
	"res://episodes/ep01/world/island_world.tscn", "res://episodes/ep01/world/horizon.tscn"]
const GAME_OFF := Vector3(0, 4.6, 6.2)
# nome, olho, alvo
var views := [
	["cais", Vector3(-3, 0, 1.5) + GAME_OFF, Vector3(-3, 1, 1.5)],
	["margem_sul", Vector3(-3, 0, 6) + GAME_OFF, Vector3(-3, 1, 6)],
	["farol", Vector3(12, 7, -3), Vector3(31, 5, -24)],
	["rio_ponte", Vector3(36, 6.5, 6), Vector3(62, 2.2, -1)],
	["rio_banco", Vector3(100, 7, 9), Vector3(119, 0, 4)],
	["enseada", Vector3(148, 7.5, 3), Vector3(166, 0.5, 19)],
	["ilha_travessia", Vector3(180.0, 5.2, 12.5), Vector3(188.5, 0.6, 3.5)],
	["ilha_acampamento", Vector3(188, 5.5, 13), Vector3(197, 0.8, 3)],
	["mapa_aereo", Vector3(95, 175, 150), Vector3(95, 0, -8)],
]
var cam: Camera3D
var frame := -1


func _ready() -> void:
	Atmosphere.build(self)
	add_child(WaterSurface.new())
	for s in SCENES:
		add_child((load(s) as PackedScene).instantiate())
	var boat := (load("res://actors/environment/boat_v2.tscn") as PackedScene).instantiate() as Node3D
	add_child(boat)
	boat.position = Ep01Layout.BOAT_DOCKED_POS
	boat.rotation.y = Ep01Layout.BOAT_DOCKED_HEADING
	var boat2 := (load("res://actors/environment/boat_v2.tscn") as PackedScene).instantiate() as Node3D
	add_child(boat2)
	boat2.position = Vector3(56, 0, 1)
	boat2.rotation.y = -PI / 2
	_kid(Vector3(-3, 0, 1.5), Color("ff8a1f"))
	_kid(Vector3(-4.6, 0, 7.0), Color("3dbe5a"))
	_kid(Vector3(180.5, 0, 9.0), Color("3dbe5a"))
	_kid(Vector3(195, 0, 3), Color("2f8cff"))
	cam = Camera3D.new()
	cam.fov = 55.0
	cam.far = 1500.0
	add_child(cam)


func _kid(p: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.24
	cm.height = 1.10
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	mi.material_override = m
	mi.position = p + Vector3(0, 0.55, 0)
	add_child(mi)


func _process(_dt: float) -> void:
	frame += 1
	var k := frame / 4
	if k >= views.size():
		return
	if frame % 4 == 0:
		cam.global_position = views[k][1]
		cam.look_at(views[k][2], Vector3.UP)
	if frame % 4 == 3:
		print("PERF %s frame=%d draw_calls=%d primitives=%d objects=%d" % [views[k][0], frame,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
