class_name Ep01V3Main
extends Node3D
## Episodio 01 v3 (RB-R1 E1): o Ep01 jogavel na vila v2.1 (game/worlds/village_v3/village_world.tscn), com os herois v2,
## a camera baixa da vitrine e o barco v2 atracado no M6. O fluxo antigo (porto, rio, ilha, volta) segue em
## episodes/ep01/ep01_main.tscn, fora do fluxo do jogo (cenas e testes guardados).
##
## FLUXO PROVISORIO: as missoes M0-M8 vem de ep01_v3_missions.json no formato de game/systems/mission (Mission);
## por ora cada uma e so "chegar ao marcador" (evento `marker_reached`). PONTO DA E4: trocar os passos no JSON e
## informar os acontecimentos reais com `notify_mission(evento)`; `mission_started` e o gancho para montar cada missao.

signal mission_started(mission_id: StringName)
signal mission_completed(mission_id: StringName)
signal episode_completed

const WORLD_SCENE := "res://worlds/village_v3/village_world.tscn"
const MISSIONS_PATH := "res://episodes/ep01/v3/ep01_v3_missions.json"
const MENU_SCENE := "res://ui/main_menu.tscn"
const EPISODE_ID := &"ep01"
const HEROES: Array[StringName] = [&"tracker", &"climber", &"pilot"]
## Trio no M0: Rastro no marcador; Pico e Leme ao lado dele (o mundo tem um marcador so para o M0).
const TRIO_OFFSETS := {&"tracker": Vector3.ZERO, &"climber": Vector3(1.1, 0, 0.5), &"pilot": Vector3(-1.1, 0, 0.5)}
## Distancia vertical maxima para contar "chegou" (andares diferentes nao contam).
const REACH_DY := 1.5
const PORTRAIT_FILES := {&"tracker": "rastro", &"climber": "pico", &"pilot": "leme"}

## Teste/dev: missao inicial (vazio = M0) e caminho do salvamento (vazio = nao salva).
static var start_mission: StringName = &""
static var save_path: String = ""

var world: VillageWorld
var camera_rig: CameraRig
var boat: BoatActor
var hud: Hud
var audio: AudioDirector
var actors: Dictionary = {}
var controlled_node: Node3D
var active_member: StringName = &"tracker"
var missions: Array[Mission] = []
## Dados extras do JSON por id (radius, camera_yaw, bot_route, icon).
var mission_data: Dictionary = {}
var current: Mission
var complete: bool = false


func _ready() -> void:
	name = "Ep01V3Main"
	world = (load(WORLD_SCENE) as PackedScene).instantiate() as VillageWorld
	world.name = "World"
	add_child(world)
	for m: StringName in HEROES:
		var a := MemberActor.new()
		a.setup(m)
		world.add_child(a)
		a.footstep.connect(_on_footstep)
		actors[m] = a
	_place_trio()
	boat = BoatActor.new()
	world.add_child(boat)
	var berth := world.marker(&"M6_BoatStart")
	boat.place(berth.global_position, berth.global_rotation.y)
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	camera_rig.set_low_view(0.0)
	Options.apply_all()
	camera_rig.reduced_motion = Options.reduced_motion()
	hud = Hud.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	for member: StringName in PORTRAIT_FILES:
		var path := "res://ui/portraits/%s_neutra.png" % PORTRAIT_FILES[member]
		if ResourceLoader.exists(path):
			hud.set_portrait_texture(member, load(path) as Texture2D)
	hud.pause_requested.connect(_pause)
	hud.resume_requested.connect(_resume)
	hud.menu_requested.connect(_on_menu)
	hud.replay_requested.connect(_on_replay)
	audio = AudioDirector.new()
	audio.name = "AudioDirector"
	add_child(audio)
	audio.start_ambience()
	audio.set_ambience_zone(&"dock")
	_load_missions()
	set_controlled(actors[active_member])
	camera_rig.follow(controlled_node, true)
	var first := start_mission
	if save_path != "":
		var resumed := MissionSave.load_into(save_path, EPISODE_ID, missions)
		if resumed != &"" and first == &"":
			first = resumed
	_start_mission(_index_of(first) if first != &"" else 0)
	_apply_dev_args()
	if _has_flag("--ep01-demo") or _has_flag("--ep01-demo-human"):
		var bot := Ep01V3Bot.new()
		bot.main = self
		bot.finished.connect(func(ok: bool) -> void: get_tree().quit(0 if ok else 1))
		add_child(bot)


## Dev/captura: --ep01v3-at=<marcador> poe o trio junto do marcador; --ep01v3-yaw=<graus> gira a camera baixa.
func _apply_dev_args() -> void:
	var at := _user_arg("--ep01v3-at")
	if at != "" and world.marker(StringName(at)) != null:
		var p := world.marker(StringName(at)).global_position
		for m: StringName in HEROES:
			(actors[m] as MemberActor).teleport(p + (TRIO_OFFSETS[m] as Vector3) + Vector3(0, 0.05, 0))
	var yaw := _user_arg("--ep01v3-yaw")
	if yaw != "":
		camera_rig.set_low_view(deg_to_rad(float(yaw)))
		for m: StringName in HEROES:
			var a := actors[m] as MemberActor
			a.face_now(a.global_position + Basis(Vector3.UP, camera_rig.yaw) * Vector3(0, 0, 3))
	camera_rig.follow(controlled_node, true)


func _user_arg(flag: String) -> String:
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with(flag + "="):
			return arg.trim_prefix(flag + "=")
	return ""


func _has_flag(flag: String) -> bool:
	return OS.get_cmdline_user_args().has(flag) or OS.get_cmdline_args().has(flag)


func _place_trio() -> void:
	var start := world.marker(&"M0_RastroStart")
	for m: StringName in HEROES:
		var a := actors[m] as MemberActor
		a.teleport(start.global_position + (TRIO_OFFSETS[m] as Vector3) + Vector3(0, 0.05, 0))
		a.face_now(world.marker(&"M0_BoatDocked").global_position)


# ---------- missoes ----------

func _load_missions() -> void:
	missions = Mission.load_list(MISSIONS_PATH)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MISSIONS_PATH))
	for d: Variant in (parsed as Dictionary).get("missions", []):
		var dd := d as Dictionary
		mission_data[StringName(str(dd["id"]))] = dd
	for m in missions:
		m.completed.connect(_on_mission_completed)


func _index_of(id: StringName) -> int:
	for i in missions.size():
		if missions[i].id == id:
			return i
	return 0


func _start_mission(index: int) -> void:
	if index >= missions.size():
		_finish_episode()
		return
	current = missions[index]
	current.start(active_member)
	var data: Dictionary = mission_data.get(current.id, {})
	hud.set_objective(Loc.t(String(current.title_key)), StringName(str(data.get("icon", "notebook"))))
	if data.has("camera_yaw"):
		camera_rig.set_low_view(deg_to_rad(float(data["camera_yaw"])))
	print("[RB] v3 mission %s" % current.id)
	mission_started.emit(current.id)


## Marcador alvo do passo atual (null fora de missao).
func target_marker() -> Marker3D:
	if current == null or not current.is_active():
		return null
	return world.marker(StringName(current.current_step().get("target", &"")))


func target_radius() -> float:
	return float((mission_data.get(current.id, {}) as Dictionary).get("radius", 1.2)) if current != null else 0.0


## Ponto da E4: o jogo informa acontecimentos da missao atual (ex.: &"piece_freed").
func notify_mission(event: StringName) -> bool:
	if current == null:
		return false
	return current.notify(event, active_member)


func _on_mission_completed(id: StringName) -> void:
	print("[RB] v3 mission_done %s" % id)
	if save_path != "":
		MissionSave.save(save_path, EPISODE_ID, missions)
	mission_completed.emit(id)
	_start_mission.call_deferred(_index_of(id) + 1)


func _finish_episode() -> void:
	current = null
	complete = true
	world.set_festival(true)
	print("[RB] v3 complete")
	episode_completed.emit()
	hud.open_complete()


func _physics_process(_delta: float) -> void:
	var t := target_marker()
	if t == null or controlled_node == null:
		return
	var d := t.global_position - controlled_node.global_position
	if absf(d.y) <= REACH_DY and Vector2(d.x, d.z).length() <= target_radius():
		notify_mission(&"marker_reached")


func _process(_delta: float) -> void:
	for m: StringName in actors:
		(actors[m] as MemberActor).move_yaw = camera_rig.yaw


# ---------- controle ----------

func set_controlled(node: Node3D) -> void:
	controlled_node = node
	for m: StringName in actors:
		(actors[m] as MemberActor).controlled = (actors[m] == node)
	boat.controlled = (node == boat)
	hud.set_member(active_member if node != null else &"")
	if node != null:
		camera_rig.follow(node)


## Piso sob o heroi para o som do passo (PROVISORIO): madeira no cais, pedra no resto da vila.
static func surface_at(pos: Vector3) -> StringName:
	if absf(pos.x) <= 9.0 and pos.z >= -4.0 and pos.z <= 0.6:
		return &"wood"
	return &"stone"


func _on_footstep(speed: float, pos: Vector3) -> void:
	if audio != null:
		audio.play_footstep(speed, surface_at(pos), pos)


func _pause() -> void:
	get_tree().paused = true
	hud.open_pause()


func _resume() -> void:
	get_tree().paused = false
	hud.close_pause()


func _on_replay() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
