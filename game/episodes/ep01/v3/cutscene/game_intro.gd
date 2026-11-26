class_name GameIntroScene
extends Node3D
## Abertura do jogo (RB-R1 D21, cena `game_intro`): a Vila Farol 7, os tres herois, o Farol 7 no radio e a pose de
## equipe, antes do Ep01 na primeira vez que se aperta Jogar e pelo menu ("Ver abertura"). Na primeira vez nao pula;
## depois, `interact` pula. Ao terminar vai para `next_scene` (o Ep01 ou o menu).

signal done(skipped: bool)

const SCENE_ID := &"game_intro"
const WORLD_SCENE := "res://worlds/village_v3/village_world.tscn"
const EP01_SCENE := "res://episodes/ep01/v3/ep01_v3_main.tscn"
const MENU_SCENE := "res://ui/main_menu.tscn"
const SELF_SCENE := "res://episodes/ep01/v3/cutscene/game_intro.tscn"
const HEROES: Array[StringName] = [&"tracker", &"climber", &"pilot"]

## Para onde ir ao terminar ("" = ficar; testes).
static var next_scene: String = EP01_SCENE

var world: VillageWorld
var hud: Hud
var audio: AudioDirector
var cutscene: Ep01V3Cutscene
var actors: Dictionary = {}


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
	audio.start_ambience()
	audio.set_ambience_zone(&"dock")
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
	if not cutscene.play(SCENE_ID):
		_on_finished.call_deferred(SCENE_ID, true)


func _on_finished(_id: StringName, skipped: bool) -> void:
	done.emit(skipped)
	if next_scene != "" and is_inside_tree():
		get_tree().change_scene_to_file(next_scene)
