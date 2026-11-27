extends Node
## Captura G21 (RB-R1): a base Farol 7 com o Lumi no radio, nos enquadramentos do plano da abertura. So prova visual.
##   --g21-shots=front,wide,mic,exterior   tomadas em sequencia (camera = marcador Base_Cam<Shot> da cena)
##   --g21-anim=talk  --g21-seek=1.6       clipe do Lumi e instante congelado (seek < 0 = toca em laco)
##   --g21-at=Base_LumiStand               marcador onde o Lumi fica (de frente para a camera da tomada front)
##   --g21-chair=0                         giro da cadeira (0 = assento para a camera)
##   --g21-out=/ABS/dir  --g21-name=g21    PNG por tomada (<name>_<shot>.png)
## Uso: xvfb-run -a -s "-screen 0 1600x900x24" bash tools/godot.sh --path game --rendering-driver vulkan \
##   --resolution 1600x900 res://tests/capture_g21.tscn -- --g21-out=$PWD/captures/g21 --g21-shots=front,wide,mic,exterior

const HOLD := 12
var base: Farol7Base
var cam: Camera3D
var lumi: Node3D
var shots: PackedStringArray = []
var frame := 0
var ready_done := false


static func _arg(key: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return def


func _ready() -> void:
	base = (load("res://worlds/farol7_base/farol7_base.tscn") as PackedScene).instantiate() as Farol7Base
	add_child(base)
	await get_tree().process_frame
	base.set_chair_yaw(float(_arg("--g21-chair", "0")))
	base.set_on_air(true)
	var at := base.marker(StringName(_arg("--g21-at", "Base_LumiStand")))
	lumi = StoryFigure.spawn(base.get_node("Actors"), "lumi_model", "Lumi")
	lumi.global_transform = at.global_transform
	var anim := StringName(_arg("--g21-anim", "talk"))
	var seek := float(_arg("--g21-seek", "1.6"))
	var cv := StoryFigure.visual(lumi)
	if seek >= 0.0:
		cv.play(anim, 0.0, 0.0)
		cv.seek_clip(anim, seek)
	else:
		StoryFigure.loop(lumi, anim)
	cam = Camera3D.new()
	cam.fov = float(_arg("--g21-fov", "50"))
	add_child(cam)
	shots = _arg("--g21-shots", "front").split(",", false)
	_set_shot(0)
	cam.current = true
	ready_done = true


func _set_shot(i: int) -> void:
	var s := shots[mini(i, shots.size() - 1)]
	var m := base.marker(StringName("Base_Cam" + s.capitalize()))
	if m != null:
		cam.global_transform = m.global_transform
	cam.fov = 70.0 if s == "wide" else (40.0 if s == "mic" else (45.0 if s == "exterior" else 56.0))


func _process(_delta: float) -> void:
	if not ready_done:
		return
	frame += 1
	if frame % HOLD == 0:
		var i := frame / HOLD - 1
		if i >= shots.size():
			get_tree().quit()
			return
		var out := _arg("--g21-out", "")
		if out != "":
			get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [out, _arg("--g21-name", "g21_base"), shots[i]])
		print("G21 SHOT %d %s %d" % [i, shots[i], frame])
		_set_shot(i + 1)
