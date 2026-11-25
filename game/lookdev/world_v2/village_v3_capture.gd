extends Node3D
## Provas do mundo jogavel v3 (RB-R1 E3): instancia game/worlds/village_v3/village_world.tscn e poe uma camera.
## So para capturas e medicao (Movie Maker); NAO e jogo. PROVISORIO.
## Linha de comando (apos --):
##   --vc-view=<nome>               camera baixa do jogo (1,95 m, 12 graus, FOV 50) numa vista de VIEWS
##   --vc-pos=x,y,z --vc-look=x,y,z tomada livre
##   --vc-night  --vc-festa  --vc-lantern=<graus>  --vc-beam  --vc-perf  --vc-decals
##   --vc-only-collision (com --debug-collisions na linha da Godot: so as formas de colisao)
##   --vc-hero=<id>@<marcador>      poe um heroi v2 (rastro|pico|leme) em pe num marcador (escala)
##   --vc-hero-at=<id>@x,z          idem num ponto livre, em pe no chao da colisao (raycast para baixo)
## Imprime "VC PERF view=... draw_calls=... primitives=... objects=..." no quadro 12.

const WORLD := "res://worlds/village_v3/village_world.tscn"
const HERO_MODEL := "res://lookdev/%s_v2_model.tscn"
const LOW_PITCH := 12.0
const VIEWS := {
	"dock": [[-0.95, 1.95, 4.85], [-2.0, 1.95, 1.0]],
	"street": [[16.2, 1.95, -13.95], [6.0, 1.95, -16.9]],
	"plaza": [[-15.6, 1.95, 4.2], [-24.0, 1.95, -3.0]],
	"bank": [[-9.0, 1.95, 13.6], [-3.0, 1.95, 7.0]],
	"lighthouse": [[20.5, 1.95, -12.0], [31.0, 1.95, -24.0]],
	"fountain": [[-17.0, 1.95, 7.5], [-22.8, 1.95, 3.6]],
	"stalls": [[-19.5, 1.95, 2.2], [-26.0, 1.95, -6.0]],
	"bankshed": [[4.5, 1.95, 4.6], [11.0, 1.95, 9.0]],
	"basin": [[6.0, 1.95, 2.4], [20.0, 1.95, -9.0]],
}

var cam: Camera3D
var world: VillageWorld
var frame := 0
var perf := false
var view := ""


func _ready() -> void:
	world = (load(WORLD) as PackedScene).instantiate() as VillageWorld
	add_child(world)
	cam = Camera3D.new()
	cam.near = 0.05
	cam.far = 600.0
	cam.fov = 50.0
	add_child(cam)
	cam.current = true
	view = _arg("--vc-view", "dock")
	var args := OS.get_cmdline_user_args()
	perf = args.has("--vc-perf")
	var ps := _arg("--vc-pos", "")
	if ps != "":
		var a := ps.split_floats(",")
		var b := _arg("--vc-look", "0,0,0").split_floats(",")
		cam.global_position = Vector3(a[0], a[1], a[2])
		cam.look_at(Vector3(b[0], b[1], b[2]), Vector3.UP)
		view = "free"
	else:
		var v: Array = VIEWS.get(view, VIEWS["dock"])
		var pos := Vector3(v[0][0], v[0][1], v[0][2])
		var flat := (Vector3(v[1][0], 0.0, v[1][2]) - Vector3(pos.x, 0.0, pos.z)).normalized()
		var c := cos(deg_to_rad(LOW_PITCH))
		cam.global_position = pos
		cam.look_at(pos + Vector3(flat.x * c, -sin(deg_to_rad(LOW_PITCH)), flat.z * c), Vector3.UP)
	if args.has("--vc-night"):
		world.set_night(true)
	if args.has("--vc-festa"):
		world.set_festival(true)
	if args.has("--vc-beam"):
		world.set_beam(true)
	var ld := _arg("--vc-lantern", "")
	if ld != "" and world.lantern != null:
		world.lantern.rotation.y = deg_to_rad(float(ld))
	# so a colisao (rode com --debug-collisions): esconde o visual para as formas aparecerem
	if args.has("--vc-only-collision"):
		for nm in ["Static", "Kit", "Props", "Water"]:
			var n := world.get_node_or_null(nm) as Node3D
			if n != null:
				n.visible = false
	if args.has("--vc-decals"):
		_decals()
	for a2 in args:
		if a2.begins_with("--vc-hero="):
			var spec := a2.trim_prefix("--vc-hero=").split("@")
			_hero(spec[0], spec[1])
		elif a2.begins_with("--vc-hero-at="):
			var spec2 := a2.trim_prefix("--vc-hero-at=").split("@")
			_hero_at.call_deferred(spec2[0], spec2[1].split_floats(","))


## Heroi v2 em pe num ponto (x, z): a altura vem de um raycast na colisao do mundo (espera a fisica montar).
func _hero_at(id: String, xz: PackedFloat64Array) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var q := PhysicsRayQueryParameters3D.create(Vector3(xz[0], 30.0, xz[1]), Vector3(xz[0], -5.0, xz[1]), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var y := (hit.position as Vector3).y if not hit.is_empty() else 0.0
	var h := (load(HERO_MODEL % id) as PackedScene).instantiate() as Node3D
	add_child(h)
	h.global_position = Vector3(xz[0], y, xz[1])
	h.look_at(Vector3(cam.global_position.x, y, cam.global_position.z), Vector3.UP, true)
	var vis := h.get_node_or_null("Model") as CharacterVisual
	if vis != null:
		vis.play(&"idle")


func _hero(id: String, marker_name: String) -> void:
	var m := world.marker(StringName(marker_name))
	if m == null or not ResourceLoader.exists(HERO_MODEL % id):
		push_warning("VC: heroi/marcador ausente %s@%s" % [id, marker_name])
		return
	var h := (load(HERO_MODEL % id) as PackedScene).instantiate() as Node3D
	add_child(h)
	h.global_position = m.global_position
	h.look_at(Vector3(cam.global_position.x, h.global_position.y, cam.global_position.z), Vector3.UP, true)
	var vis := h.get_node_or_null("Model") as CharacterVisual
	if vis != null:
		vis.play(&"idle")


## Decalques de exemplo nos marcadores de trilha (M1 pegadinhas, M2 molhada, M5 penas e escamas).
func _decals() -> void:
	var plan := {"M1": "paw", "M5": "feather"}
	for mis: String in plan:
		var k := 0
		for m in world.markers_for(mis):
			if not (String(m.name).contains("Trail")):
				continue
			var kind: String = plan[mis] if (mis != "M5" or k % 2 == 0) else "scale"
			var d := (load("res://worlds/village_v3/decals/decal_%s.tscn" % kind) as PackedScene).instantiate() as Node3D
			add_child(d)
			d.global_position = m.global_position
			d.rotation.y = 0.6 * k
			k += 1
	var wet := world.marker(&"M2_ReedsPiece")
	if wet != null:
		var d2 := (load("res://worlds/village_v3/decals/decal_paw_wet.tscn") as PackedScene).instantiate() as Node3D
		add_child(d2)
		d2.global_position = wet.global_position + Vector3(-0.6, 0, 0.4)


func _arg(flag: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(flag + "="):
			return a.trim_prefix(flag + "=")
	return fallback


func _process(_dt: float) -> void:
	frame += 1
	if perf and frame == 12:
		print("VC PERF view=%s draw_calls=%d primitives=%d objects=%d" % [view,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
