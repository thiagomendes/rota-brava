extends Node
## Captura G4 (RB-R1): secundarios lado a lado com o trio no Ep01 v3 (vila de dia, luz do jogo). So prova visual.
## Fila: Rastro, Pico, Leme e os secundarios pedidos, virados para a camera (cais em M0_RastroStart por padrao).
##   --g4-who=captain,amora,pup      secundarios na fila (ids de actors/characters/<id>_model.tscn ou villager_x.tscn)
##   --g4-shots=game,close:pup,...   tomadas em sequencia, HOLD quadros cada (imprime "G4 SHOT <i> <nome> <quadro>"):
##                                   game = parametros da camera baixa do jogo (CameraRig.LOW_OFFSET, LOW_LOOK_Y, LOW_FOV)
##                                   apontada para o centro da fila; close:<id> = ~1,5 m do personagem, com o vizinho do trio
##   <id>_old = modelo da geracao anterior (cena copiada em res://tests/g4_old/, nao versionada) para o "antes"
##   feet:<id> = pes do personagem de perto, de 3/4 (G23)
##   --g4-anim=idle  --g4-yaw=0  --g4-at=M0_RastroStart  --g4-dx=0 --g4-dz=0  --g4-dist=1.5
## Uso: xvfb-run -a -s "-screen 0 1600x900x24" bash tools/godot.sh --path game --rendering-driver vulkan \
##   res://tests/capture_g4.tscn --write-movie /ABS/f.png --fixed-fps 10 --quit-after 40 -- --g4-shots=game,close:pup

const SPACING := 0.95
const HOLD := 8
var cam: Camera3D
var figures: Dictionary = {}
var shots: PackedStringArray = []
var center := Vector3.ZERO
var view_dir := Vector3.BACK
var side := Vector3.RIGHT
var frame := 0
var ready_done := false


static func _arg(key: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return def


func _ready() -> void:
	Ep01V3Main.start_mission = &""
	Ep01V3Main.save_path = ""
	Ep01V3Cutscene.enabled = false
	var main := (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main.current = null
	for n in main.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var who := _arg("--g4-who", "captain,amora,pup").split(",", false)
	var anim := StringName(_arg("--g4-anim", "idle"))
	center = main.world.marker(StringName(_arg("--g4-at", "M0_RastroStart"))).global_position
	center += Vector3(float(_arg("--g4-dx", "0")), 0.0, float(_arg("--g4-dz", "0")))
	view_dir = Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, deg_to_rad(float(_arg("--g4-yaw", "0"))))
	side = Vector3.UP.cross(view_dir).normalized()
	var ids: Array[String] = ["tracker", "climber", "pilot"]
	ids.append_array(who)
	var space := main.world.get_world_3d().direct_space_state
	for i in ids.size():
		var p := center + side * (float(i) - (ids.size() - 1) * 0.5) * SPACING
		var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 3, 0), p + Vector3(0, -3, 0), 1))
		if not h.is_empty():
			p = h["position"] as Vector3
		var id := ids[i]
		var node: Node3D
		if main.actors.has(StringName(id)):
			var a := main.actors[StringName(id)] as MemberActor
			a.teleport(p + Vector3(0, 0.02, 0))
			a.face_now(p + view_dir)
			a.set_physics_process(false)
			node = a
			if a.model != null:
				a.model.play(anim)
		elif id.ends_with("_old"):
			node = _spawn_old(id)
			node.global_position = p
			StoryFigure.face(node, p + view_dir)
			StoryFigure.loop(node, anim)
		else:
			var scene := id if id.begins_with("villager") else id + "_model"
			node = StoryFigure.spawn(self, scene, "G4_" + id)
			node.global_position = p
			StoryFigure.face(node, p + view_dir)
			StoryFigure.loop(node, anim)
		figures[id] = node
	for c in main.find_children("*", "Camera3D", true, false):
		(c as Camera3D).current = false
	cam = Camera3D.new()
	add_child(cam)
	shots = _arg("--g4-shots", "game").split(",", false)
	_set_shot(0)
	cam.current = true
	ready_done = true


## Modelo da geracao anterior para o "antes": cena copiada (fora do Git) em res://tests/g4_old/<id>.tscn, montada como o
## StoryFigure monta (so o no Model, com Stylize/contorno quando nao e PBR).
func _spawn_old(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "G4_" + id
	add_child(root)
	var inst := (load("res://tests/g4_old/%s.tscn" % id) as PackedScene).instantiate()
	var m := inst.get_node("Model")
	inst.remove_child(m)
	m.owner = null
	inst.free()
	root.add_child(m)
	CharacterVisual.stylize_if_toon(m, 0.008)
	(m as CharacterVisual).play(&"idle")
	return root


func _set_shot(i: int) -> void:
	var s := shots[mini(i, shots.size() - 1)]
	if s == "game":
		var off := CameraRig.LOW_OFFSET
		cam.fov = CameraRig.LOW_FOV
		cam.global_position = center + view_dir * off.z + Vector3(0, off.y, 0)
		cam.look_at(center + Vector3(0, CameraRig.LOW_LOOK_Y, 0))
		return
	var face_shot := s.begins_with("face:")
	var focus := s.trim_prefix("close:").trim_prefix("face:").trim_prefix("feet:").trim_suffix("_old")
	if not figures.has(focus) and figures.has(focus + "_old"):
		figures[focus] = figures[focus + "_old"]
	var f := figures.get(focus, figures["tracker"]) as Node3D
	const TOPS := {"pup": 0.42, "captain": 1.55, "amora": 1.45, "lumi": 1.50, "villager_a": 1.45, "villager_b": 1.45}
	var top: float = TOPS.get(focus, 0.95)
	cam.fov = 40.0
	if s.begins_with("feet:"):
		# G23: pes de perto, de 3/4 e um pouco de cima, na luz do jogo
		var dir := (view_dir * 0.8 + side * 0.6).normalized()
		cam.global_position = f.global_position + dir * 1.1 + Vector3(0, 0.45, 0)
		cam.look_at(f.global_position + Vector3(0, 0.14, 0))
		return
	if face_shot:
		# rosto de perto (TOPS ~ centro da cabeca dos secundarios)
		var hz_head := top
		var fd := 0.45 if focus == "pup" else 0.7
		cam.global_position = f.global_position + view_dir * fd + Vector3(0, hz_head, 0)
		cam.look_at(f.global_position + Vector3(0, hz_head - 0.02, 0))
		return
	var d := float(_arg("--g4-dist", "1.5")) * (0.75 if focus == "pup" else (1.25 if top > 1.2 else 1.0))
	# o vizinho do trio (Leme) fica a esquerda da tela: a camera mira entre os dois, mais perto do secundario
	cam.global_position = f.global_position + view_dir * d - side * 0.2 + Vector3(0, top * 0.95, 0)
	cam.look_at(f.global_position + Vector3(0, top * 0.72, 0) - side * 0.3)


func _process(_delta: float) -> void:
	if not ready_done:
		return
	frame += 1
	if frame % HOLD == 0:
		var i := frame / HOLD - 1
		if i >= shots.size():
			get_tree().quit()
			return
		var out := _arg("--g4-out", "")
		var shot := shots[i].replace(":", "_")
		if out != "":
			get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [out, _arg("--g4-name", "g4"), shot])
		print("G4 SHOT %d %s %d" % [i, shot, frame])
		_set_shot(i + 1)
