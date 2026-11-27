class_name GameIntroScene
extends Node3D
## Abertura do jogo (RB-R1 D21, cena `game_intro`): a Vila Maré, os tres herois, o Farol 7 no radio e a pose de
## equipe, antes do Ep01 na primeira vez que se aperta Jogar e pelo menu ("Ver abertura"). Na primeira vez nao pula;
## depois, `interact` pula. Ao terminar vai para `next_scene` (o Ep01 ou o menu).

signal done(skipped: bool)

const SCENE_ID := &"game_intro"
const WORLD_SCENE := "res://worlds/village_v3/village_world.tscn"
const EP01_SCENE := "res://episodes/ep01/v3/ep01_v3_main.tscn"
const MENU_SCENE := "res://ui/main_menu.tscn"
const SELF_SCENE := "res://episodes/ep01/v3/cutscene/game_intro.tscn"
const HEROES: Array[StringName] = [&"tracker", &"climber", &"pilot"]
## G21i: planos 9_out/9a/9b/9c na base Farol 7 (palco de cutscene, fora da vila), com o Lumi no radio.
const STAGE_SCENE := "res://worlds/farol7_base/farol7_base.tscn"
const STAGE_ID := "farol7_base"
## Longe da vila (no alto): sem colisao nem copas da vila no caminho da camera; a vila some nos planos da base.
const STAGE_OFFSET := Vector3(0, 200, 0)
## Cadeira de costas (para a mesa) ate o `turn_chair`, que a gira para a camera em TURN_S.
const CHAIR_BACK_DEG := 180.0
const TURN_S := 1.0

## Para onde ir ao terminar ("" = ficar; testes).
static var next_scene: String = EP01_SCENE

var world: VillageWorld
var hud: Hud
var audio: AudioDirector
var cutscene: Ep01V3Cutscene
var actors: Dictionary = {}
var stage: Farol7Base
## No da vila -> visivel antes do plano da base.
var _village_hidden: Dictionary = {}
var _chair_tween: Tween


## O que o menu chama em Jogar: abertura do jogo na primeira vez, senao direto o Ep01.
static func play_target() -> String:
	if Ep01V3Cutscene.enabled and not Ep01V3Cutscene.is_seen(SCENE_ID):
		next_scene = EP01_SCENE
		return SELF_SCENE
	return EP01_SCENE


func _ready() -> void:
	name = "GameIntro"
	world = (load(WORLD_SCENE) as PackedScene).instantiate() as VillageWorld
	world.name = "World"
	add_child(world)
	var start := world.marker(&"M0_RastroStart")
	for m: StringName in HEROES:
		var a := MemberActor.new()
		a.setup(m)
		world.add_child(a)
		a.teleport(start.global_position + Vector3(0, 0.05, 0))
		actors[m] = a
	Options.apply_all()
	hud = Hud.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	hud.set_member(&"")
	audio = AudioDirector.new()
	audio.name = "AudioDirector"
	add_child(audio)
	audio.ambience_hold = true
	audio.set_ambience_zone(&"dock")
	_start_ambience_when_released()
	hud.emotes_hook = func(key: String) -> Array[StringName]: return Ep01V3Dialogue.emotes(key)
	hud.voice_hook = func(key: String) -> float:
		var id := Ep01V3Dialogue.take(key)
		return float(audio.play_line(id if id != "" else key).get("duration", 0.0))
	hud.voice_stop_hook = func() -> void:
		audio.stop_voice()
	cutscene = Ep01V3Cutscene.new()
	cutscene.reduced_motion = Options.reduced_motion()
	add_child(cutscene)
	cutscene.setup(world, hud, actors)
	cutscene.occluders = Ep01V3Cutscene.canopies_of(world)
	for path: String in ["Collision/WaterLimits", "Collision/MapBounds", "Collision/AccessRamps"]:
		var b := world.get_node_or_null(path) as CollisionObject3D
		if b != null:
			cutscene.exclude.append(b.get_rid())
	cutscene.finished.connect(_on_finished)
	cutscene.shot_entered.connect(_on_shot)
	# G21i: o palco carrega em segundo plano (nao entra no tempo da tela de carregamento); o plano 9 so vem ~20 s depois.
	if _stage_needed():
		ResourceLoader.load_threaded_request(STAGE_SCENE)
	if not cutscene.play(SCENE_ID):
		_on_finished.call_deferred(SCENE_ID, true)


## G17: o som da vila so entra quando a tela de carregamento sai (no celular ela fica muito tempo na frente).
func _start_ambience_when_released() -> void:
	await SceneLoaderService.wait_released(self)
	if is_inside_tree():
		audio.ambience_hold = false
		audio.start_ambience()


func _stage_needed() -> bool:
	for sh: Variant in Ep01V3Cutscene.scene_data(SCENE_ID).get("shots", []):
		if str((sh as Dictionary).get("stage", "")) == STAGE_ID:
			return true
	return false


## Monta o palco da base (se ainda nao) e entrega ao player de cutscene. Espera a carga em segundo plano se preciso.
func ensure_stage() -> Farol7Base:
	if stage != null:
		return stage
	var ps: PackedScene = null
	if ResourceLoader.load_threaded_get_status(STAGE_SCENE) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ps = ResourceLoader.load_threaded_get(STAGE_SCENE) as PackedScene
	if ps == null:
		ps = load(STAGE_SCENE) as PackedScene
	stage = ps.instantiate() as Farol7Base
	stage.use_own_environment = false  # ceu e sol da vila (iguais aos do palco), um so WorldEnvironment
	stage.name = "Farol7Base"
	stage.visible = false
	add_child(stage)
	stage.global_position = STAGE_OFFSET
	stage.set_chair_yaw(CHAIR_BACK_DEG)
	cutscene.stage = stage
	return stage


func _on_shot(_i: int, sh: Dictionary) -> void:
	var at_base := str(sh.get("stage", "")) == STAGE_ID
	if at_base:
		ensure_stage()
	elif stage == null:
		return
	_show_base(at_base)
	if not at_base:
		return
	var line: Dictionary = sh.get("line", {}) if sh.get("line") is Dictionary else {}
	stage.set_on_air(str(line.get("speaker", "")) == "radio")
	if str(sh.get("stage_event", "")) == "chair_turn":
		if _chair_tween != null:
			_chair_tween.kill()
		stage.set_chair_yaw(CHAIR_BACK_DEG)
		_chair_tween = create_tween()
		_chair_tween.tween_method(stage.set_chair_yaw, CHAIR_BACK_DEG, 0.0, TURN_S).set_trans(Tween.TRANS_SINE)


## Nos planos da base a vila (e quem esta nela) some; o ceu, o sol e a luz de preenchimento ficam.
func _show_base(on: bool) -> void:
	stage.visible = on
	if on:
		for c in world.get_children():
			if c is Node3D and not c is Light3D and not _village_hidden.has(c):
				_village_hidden[c] = (c as Node3D).visible
				(c as Node3D).visible = false
	else:
		for c: Node in _village_hidden:
			if is_instance_valid(c):
				(c as Node3D).visible = bool(_village_hidden[c])
		_village_hidden.clear()
		stage.set_on_air(false)


func village_hidden() -> bool:
	return not _village_hidden.is_empty()


func _on_finished(_id: StringName, skipped: bool) -> void:
	if stage != null:
		_show_base(false)
	done.emit(skipped)
	# G12: a cena pode acabar com a tela de carregamento ainda saindo (cenas desligadas/puladas no primeiro quadro);
	# o SceneLoader ignora pedidos nessa hora, entao espera ele ficar livre (antes ficava parado na abertura).
	var loader := SceneLoaderService.instance()
	while is_inside_tree() and loader.is_busy():
		await get_tree().process_frame
	if next_scene != "" and is_inside_tree():
		SceneLoaderService.go(next_scene)
