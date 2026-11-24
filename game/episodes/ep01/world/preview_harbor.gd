extends Node3D
## PREVIEW do trecho do porto (RB-R1, so capturas; NAO e jogo nem esta ligado ao Ep01). PROVISORIO.
## Mesma luz/ceu/nevoa do jogo (Atmosphere.build) e mesma agua (WaterSurface). Camera FOV 55:
##   quadros 0..9  -> camera do cais: alvo Ep01Layout.BENCH_INTERACT_POS, offset (0, 4.6, 6.2), olhar +1 m;
##   quadros 10..  -> plano aberto (14, 21, 30) olhando (2, 4, -16).
## Imprime "PERF <vista> draw_calls=... primitives=... objects=..." (monitores de render da Godot) no quadro 8 e 18.
## Uso: ./tools/godot.ps1 --path game res://episodes/ep01/world/preview_harbor.tscn --write-movie <dir>/f.png --fixed-fps 10 --resolution 1280x720 --quit-after 20

const SLICE := "res://episodes/ep01/world/harbor_slice.tscn"
const BOAT := "res://actors/environment/boat_v2.tscn"
const CAM_OFFSET := Vector3(0, 4.6, 6.2)
const OPEN_EYE := Vector3(14, 21, 30)
const OPEN_LOOK := Vector3(2, 4, -16)

var cam: Camera3D
var frame := 0


func _ready() -> void:
	Atmosphere.build(self)
	add_child(WaterSurface.new())
	add_child((load(SLICE) as PackedScene).instantiate())
	var boat := (load(BOAT) as PackedScene).instantiate() as Node3D
	boat.name = "Boat"
	add_child(boat)
	boat.position = Ep01Layout.BOAT_DOCKED_POS
	boat.rotation.y = Ep01Layout.BOAT_DOCKED_HEADING
	_scale_kid(Ep01Layout.BENCH_INTERACT_POS + Vector3(-0.6, 0, 0.2), Color("ff8a1f"))
	_scale_kid(Vector3(1.6, 0, -1.0), Color("3dbe5a"))
	cam = Camera3D.new()
	cam.fov = 55.0
	cam.far = 1200.0
	add_child(cam)
	_view_cais()


## Personagem-escala 1,10 m (capsula; NAO e o heroi).
func _scale_kid(p: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.24
	cm.height = 1.10
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	mi.material_override = m
	mi.position = p + Vector3(0, 0.55, 0)
	mi.name = "ScaleKid"
	add_child(mi)


func _view_cais() -> void:
	var t := Ep01Layout.BENCH_INTERACT_POS
	cam.global_position = t + CAM_OFFSET
	cam.look_at(t + Vector3(0, 1.0, 0), Vector3.UP)


func _view_open() -> void:
	cam.global_position = OPEN_EYE
	cam.look_at(OPEN_LOOK, Vector3.UP)


func _process(_dt: float) -> void:
	frame += 1
	if frame == 10:
		_view_open()
	if frame == 8 or frame == 18:
		print("PERF %s draw_calls=%d primitives=%d objects=%d" % ["cais" if frame == 8 else "aberto",
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
