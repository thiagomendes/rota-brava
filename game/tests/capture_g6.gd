extends Node
## Captura G6 (RB-R1): um ponto da vila com as pecas da missao montadas, visto de perto por uma camera de captura e
## depois pela camera do jogo (heroi ativo parado ao lado, `CameraRig.set_low_view`).
## Uso: xvfb-run ... godot.sh --path game res://tests/capture_g6.tscn --write-movie <abs>/f.png --fixed-fps 10 \
##        --quit-after 40 -- --g6-shot=cart
## Quadro 19 = perto; quadro 39 = camera do jogo.

## nome -> [missao, olho, alvo, posicao do heroi (perto do alvo), yaw da camera do jogo em graus]
const SHOTS := {
	"cart": [&"M4", Vector3(-17.2, 1.7, 2.6), Vector3(-18.7, 0.9, 0.6), Vector3(-17.3, 0.0, 2.2), 30.0],
	"plaza_crates": [&"M4", Vector3(-17.0, 1.5, 3.6), Vector3(-18.8, 0.6, 1.8), Vector3(-17.0, 0.0, 3.4), 30.0],
	"dock_west": [&"M1", Vector3(-4.6, 1.6, 4.0), Vector3(-5.8, 0.6, 1.9), Vector3(-4.8, 0.0, 3.6), 20.0],
	"dock_east": [&"M1", Vector3(3.6, 1.6, 1.6), Vector3(2.4, 0.6, -0.6), Vector3(3.4, 0.0, 1.2), 20.0],
	"lobster": [&"M1", Vector3(7.6, 1.5, 0.6), Vector3(6.2, 0.4, -1.3), Vector3(7.4, 0.0, 0.3), 30.0],
	"sacks": [&"M1", Vector3(6.6, 1.4, 1.6), Vector3(5.4, 0.3, 0.35), Vector3(6.4, 0.0, 1.4), 30.0],
	"planter_pot": [&"M5", Vector3(12.4, 1.5, -15.4), Vector3(12.8, 0.35, -17.3), Vector3(12.4, 0.0, -15.6), 180.0],
	"head_tree": [&"M7", Vector3(27.2, 3.6, -26.4), Vector3(24.9, 2.2, -28.6), Vector3(27.0, 0.0, -26.6), 240.0],
	"north_quay":[&"M5", Vector3(-15.0, 1.9, -13.6), Vector3(-16.6, 0.9, -16.0), Vector3(-15.0, 0.0, -13.8), 0.0],
}

var main: Ep01V3Main
var shot: Array = []
var cam: Camera3D
var frame := 0


func _arg(flag: String) -> String:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with(flag + "="):
			return a.trim_prefix(flag + "=")
	return ""


func _ready() -> void:
	shot = SHOTS.get(_arg("--g6-shot"), SHOTS["cart"])
	Ep01V3Main.start_mission = shot[0]
	Ep01V3Main.save_path = ""
	Ep01V3Cutscene.enabled = false
	main = (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main.hud.visible = false
	cam = Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.look_at_from_position(shot[1], shot[2])
	cam.current = true


func _process(_delta: float) -> void:
	frame += 1
	if main == null or cam == null:
		return
	if frame == 21:
		var lead := main.controlled_node as Node3D
		if lead is MemberActor:
			var at: Vector3 = shot[3]
			var hit := main.world.get_world_3d().direct_space_state.intersect_ray(
				PhysicsRayQueryParameters3D.create(at + Vector3(0, 10, 0), at + Vector3(0, -10, 0), 1))
			if not hit.is_empty():
				at = hit["position"]
			(lead as MemberActor).teleport(at + Vector3(0, 0.05, 0))
			(lead as MemberActor).face_now(shot[2])
		main.camera_rig.set_low_view(deg_to_rad(float(shot[4])))
		main.camera_rig.follow(lead, true)
		main.camera_rig.camera.current = true
	elif frame < 21:
		cam.current = true
