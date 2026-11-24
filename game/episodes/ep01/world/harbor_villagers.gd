class_name HarborVillagers
extends Node3D
## Moradores animados da vila Farol 7 (RB-R1). Rotinas baratas: conversa em dupla (`chat`), passeio num laco curto
## entre dois pontos (`walk` com velocidade casada) e espectadores que viram para o barco quando ele se aproxima.
## Sem colisao (camada/mascara 0): nunca bloqueiam o caminho jogavel. Fora da tela a animacao para (VisibleOnScreenNotifier3D).

const SCENES: Array[String] = [
	"res://actors/characters/villager_a.tscn",
	"res://actors/characters/villager_b.tscn",
	"res://actors/characters/villager_c.tscn",
]
const WALK_MPS := 0.75
const WATCH_RANGE := 45.0
const WATCH_TURN := 2.5          # rad/s
const VISIBILITY_END := 70.0     # m: alem disso a malha some

## Cada entrada: tipo, modelo (0..2), pontos (x, z) e rumo inicial (graus; 0 = frente para -Z/norte, 180 = sul/camera).
## Coordenadas conferidas contra harbor_layout.json (barracas, bancos, postes, canteiros) e longe do caminho do cais/margem.
const ROUTINES: Array[Dictionary] = [
	# Rua do mercado (cais de pedra norte, y 0)
	{"kind": &"chat", "model": 0, "a": Vector2(-1.1, -15.7), "b": Vector2(0.1, -15.7)},
	{"kind": &"chat", "model": 1, "a": Vector2(0.1, -15.7), "b": Vector2(-1.1, -15.7)},
	{"kind": &"chat", "model": 2, "a": Vector2(8.8, -15.9), "b": Vector2(9.8, -16.4)},
	{"kind": &"chat", "model": 0, "a": Vector2(9.8, -16.4), "b": Vector2(8.8, -15.9)},
	{"kind": &"walk", "model": 1, "a": Vector2(-14.0, -16.3), "b": Vector2(-5.5, -16.3)},
	{"kind": &"walk", "model": 0, "a": Vector2(6.8, -16.6), "b": Vector2(13.5, -16.6)},
	{"kind": &"watch", "model": 2, "a": Vector2(-7.8, -13.9), "yaw": 180.0},
	{"kind": &"watch", "model": 1, "a": Vector2(-1.0, -13.8), "yaw": 170.0},
	{"kind": &"watch", "model": 0, "a": Vector2(7.6, -13.9), "yaw": 190.0},
	{"kind": &"watch", "model": 1, "a": Vector2(18.6, -14.2), "yaw": 200.0},
	{"kind": &"watch", "model": 2, "a": Vector2(22.4, -14.0), "yaw": 210.0},
	# Cais de pedra oeste e praca
	{"kind": &"chat", "model": 1, "a": Vector2(-18.6, -10.4), "b": Vector2(-18.6, -11.6)},
	{"kind": &"chat", "model": 2, "a": Vector2(-18.6, -11.6), "b": Vector2(-18.6, -10.4)},
	{"kind": &"walk", "model": 0, "a": Vector2(-18.8, -7.5), "b": Vector2(-18.8, 4.0)},
	{"kind": &"watch", "model": 0, "a": Vector2(-14.6, 7.2), "yaw": -120.0},
	{"kind": &"watch", "model": 2, "a": Vector2(-15.4, 9.0), "yaw": -105.0},
	{"kind": &"chat", "model": 1, "a": Vector2(-12.6, 5.6), "b": Vector2(-12.0, 6.8)},
]

## Alvo para os espectadores (o barco). Pode ficar nulo.
var watch_target: Node3D
var _items: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7071
	var packs: Array[PackedScene] = []
	for p in SCENES:
		packs.append(load(p) as PackedScene)
	for i in ROUTINES.size():
		_spawn(i, ROUTINES[i], packs)


func _spawn(i: int, spec: Dictionary, packs: Array[PackedScene]) -> void:
	var body := packs[int(spec["model"])].instantiate() as CharacterBody3D
	body.name = "Villager%02d" % i
	body.collision_layer = 0
	body.collision_mask = 0
	var shape := body.get_node_or_null("Collision") as CollisionShape3D
	if shape != null:
		shape.disabled = true
	body.process_mode = Node.PROCESS_MODE_DISABLED   # o corpo nao se move por fisica; so o visual anima
	var a: Vector2 = spec["a"]
	body.position = Vector3(a.x, 0.0, a.y)
	var s := _rng.randf_range(0.94, 1.06)
	body.scale = Vector3(s, s, s)
	add_child(body)
	var visual := body.get_node("Model") as CharacterVisual
	visual.process_mode = Node.PROCESS_MODE_PAUSABLE
	for mi in visual.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visibility_range_end = VISIBILITY_END
	var item := {"body": body, "visual": visual, "kind": spec["kind"], "a": a, "b": spec.get("b", a), "dir": 1}
	match spec["kind"]:
		&"chat":
			_face(body, item["b"])
			visual.play(&"chat", _rng.randf_range(0.85, 1.15), 0.0)
		&"walk":
			_face(body, item["b"])
			visual.play(&"walk", visual.walk_speed_scale(WALK_MPS), 0.0)
		_:
			body.rotation.y = deg_to_rad(float(spec.get("yaw", 180.0)))
			visual.play(&"idle", _rng.randf_range(0.85, 1.1), 0.0)
	_desync(visual)
	# Fora da tela, nao avanca o esqueleto (custo de CPU dos distantes/escondidos).
	var notifier := VisibleOnScreenNotifier3D.new()
	notifier.name = "OnScreen"
	notifier.aabb = AABB(Vector3(-0.5, 0, -0.5), Vector3(1, 2, 1))
	body.add_child(notifier)
	notifier.screen_entered.connect(func() -> void: visual.set_process(true))
	notifier.screen_exited.connect(func() -> void: visual.set_process(false))
	_items.append(item)


func _desync(visual: CharacterVisual) -> void:
	var player := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null and player.current_animation != "":
		var length := player.current_animation_length
		player.seek(_rng.randf_range(0.0, maxf(length, 0.01)), true)


func _face(body: Node3D, target: Vector2) -> void:
	var d := Vector2(target.x - body.position.x, target.y - body.position.z)
	if d.length() > 0.01:
		body.rotation.y = atan2(-d.x, -d.y)   # frente em -Z


func _process(delta: float) -> void:
	for item in _items:
		match item["kind"]:
			&"walk":
				_step_walk(item, delta)
			&"watch":
				_step_watch(item, delta)


func _step_walk(item: Dictionary, delta: float) -> void:
	var body := item["body"] as Node3D
	var target: Vector2 = item["b"] if int(item["dir"]) > 0 else item["a"]
	var pos := Vector2(body.position.x, body.position.z)
	var to := target - pos
	var step := WALK_MPS * delta
	if to.length() <= step:
		pos = target
		item["dir"] = -int(item["dir"])
		_face(body, item["a"] if int(item["dir"]) < 0 else item["b"])
	else:
		pos += to.normalized() * step
	body.position = Vector3(pos.x, body.position.y, pos.y)


func _step_watch(item: Dictionary, delta: float) -> void:
	if watch_target == null or not is_instance_valid(watch_target):
		return
	var body := item["body"] as Node3D
	var tp := watch_target.global_position
	if body.global_position.distance_to(tp) > WATCH_RANGE:
		return
	var d := Vector2(tp.x - body.global_position.x, tp.z - body.global_position.z)
	var want := atan2(-d.x, -d.y)
	var diff := wrapf(want - body.rotation.y, -PI, PI)
	body.rotation.y += clampf(diff, -WATCH_TURN * delta, WATCH_TURN * delta)
	(item["visual"] as CharacterVisual).look_at_point(tp + Vector3(0, 1.0, 0))


## Leitura para testes/sondas.
func villagers() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for item in _items:
		out.append(item["body"])
	return out


func routine_of(body: Node3D) -> StringName:
	for item in _items:
		if item["body"] == body:
			return item["kind"]
	return &""
