extends Node
## Captura G24a2 v2 (RB-R1): heroi atras de uma peca (caixotes, toldo, carrinho) vista pela camera do jogo.
## Uso: xvfb-run -a bash tools/godot.sh --path game --rendering-driver vulkan res://tests/capture_g24a2.tscn \
##        --write-movie <abs>/f.png --fixed-fps 10 --quit-after 40 -- --g24-shot=m5_crates [--g24-off] [--g24-warm=out|none]
## --g24-off: como antes do G24a2 (pecas na mascara da camera, copas desviadas, sem pontilhado).
## Imprime as compilacoes de pipeline (RenderingServer) na carga e depois do primeiro pontilhado. Quadro 39 = foto.

## nome -> [missao, marcador da peca, distancia do heroi a peca (m), altura do alvo]
const SHOTS := {
	"m5_crates": [&"M5", &"M5_Crates", 1.3],
	"m5_awning": [&"M5", &"M5_Awning", 1.4],
	"m4_cart": [&"M4", &"M4_Cart", 1.4],
	"m4_stall": [&"M4", &"M4_Stall_Lemon", 1.5],
}

var main: Ep01V3Main
var shot: Array = []
var frame := 0
var off := false
var _yaw := 0.0
var _at := Vector3.ZERO


func _arg(flag: String) -> String:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a == flag:
			return "1"
		if a.begins_with(flag + "="):
			return a.trim_prefix(flag + "=")
	return ""


func _pipelines() -> String:
	var out: Array[String] = []
	for n: String in ["RENDERING_INFO_PIPELINE_COMPILATIONS_MESH", "RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE",
			"RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW", "RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION"]:
		if ClassDB.class_has_integer_constant(&"RenderingServer", n):
			out.append("%s=%d" % [n.trim_prefix("RENDERING_INFO_PIPELINE_COMPILATIONS_").to_lower(),
				RenderingServer.get_rendering_info(ClassDB.class_get_integer_constant(&"RenderingServer", n))])
	return " ".join(out) if not out.is_empty() else "sem contador de pipeline nesta versao"


func _ready() -> void:
	shot = SHOTS.get(_arg("--g24-shot"), SHOTS["m5_crates"])
	off = _arg("--g24-off") != ""
	if _arg("--g24-warm") != "":
		CameraOcclusion.warm_mode = StringName(_arg("--g24-warm"))
	Ep01V3Main.start_mission = shot[0]
	Ep01V3Main.save_path = ""
	Ep01V3Cutscene.enabled = false
	main = (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main.hud.visible = false
	if off:
		main.camera_rig.occlusion.restore_all()
		main.camera_rig.occlusion = null
		main.camera_rig.exclude = main._solid_exclude.duplicate()
		main.camera_rig.avoid_canopies = true
	_pick_spot()


## Heroi a `dist` m da peca, num chao livre; camera do jogo do outro lado da peca (a peca entre os dois).
func _pick_spot() -> void:
	var c := main.world.marker(shot[1] as StringName).global_position
	var space := main.world.get_world_3d().direct_space_state
	var best := -1.0
	for k in 16:
		var d := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 16.0)
		var p := c + d * float(shot[2])
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 3, 0), p + Vector3(0, -3, 0), 1, main._solid_exclude))
		if hit.is_empty():
			continue
		var g: Vector3 = hit["position"]
		var cam := g + Basis(Vector3.UP, atan2(-d.x, -d.z)) * CameraRig.LOW_OFFSET
		# Camera do lado de la livre de estrutura (ate onde der) e peca no meio: prefere a vista mais longa.
		var q := PhysicsRayQueryParameters3D.create(g + Vector3(0, 1.0, 0), cam, 1, main.camera_rig.exclude)
		var free := space.intersect_ray(q)
		var reach := cam.distance_to(g) if free.is_empty() else (free["position"] as Vector3).distance_to(g)
		if absf(g.y - c.y) < 1.2 and reach > best:
			best = reach
			_at = g
			_yaw = atan2(-d.x, -d.z)
	print("[G24a2] tomada %s %s: heroi %s, giro %.0f graus, braco livre %.1f m" % [_arg("--g24-shot"), "antes" if off else "depois", _at, rad_to_deg(_yaw), best])


func _process(_delta: float) -> void:
	frame += 1
	if main == null:
		return
	if frame == 3:
		print("[G24a2] pipelines na carga (aquecimento %s): %s" % [CameraOcclusion.warm_mode, _pipelines()])
	if frame == 12:
		var lead := main.controlled_node as MemberActor
		lead.teleport(_at + Vector3(0, 0.05, 0))
		lead.face_now(_at + Basis(Vector3.UP, _yaw) * Vector3(0, 0, -3))
		main.camera_rig.set_low_view(_yaw)
		main.camera_rig.follow(lead, true)
	if frame == 13:
		print("[G24a2] pipelines antes do pontilhado: %s" % _pipelines())
	if frame == 20 or frame == 39:
		var occ := main.camera_rig.occlusion
		print("[G24a2] quadro %d: pipelines %s; pecas pontilhadas %d; camera %s, heroi a %.2f m" % [frame, _pipelines(),
			occ.swapped_now if occ != null else 0, main.camera_rig.camera.global_position,
			main.camera_rig.camera.global_position.distance_to(main.controlled_node.global_position)])
