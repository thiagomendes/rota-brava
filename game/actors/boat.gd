class_name BoatActor
extends Node3D
## Barco amarelo (bloco PROVISORIO). Movimento arcade: motor, direcao, corrente e desaceleracao perto de obstaculos.
## Frente = -Z local; heading 0 aponta para o norte (-Z); heading positivo vira a proa para a esquerda (oeste).

signal soft_hit

const COLOR_HULL := Color("f5c518")
const MAX_SPEED := 7.0
const ACCEL := 4.0
const BRAKE := 6.0
const TURN_RATE := 1.5
const SLOW_RANGE := 6.0
const MIN_SLOW_FACTOR := 0.3

var controlled: bool = false
var input_locked: bool = false
var heading: float = 0.0
var speed: float = 0.0
## 0..1: estabiliza direcao e velocidade (assistencia de pilotagem).
var assist: float = 0.0
## Direcao a favorecer quando a assistencia esta ativa (rad); NAN = nao favorece.
var assist_heading: float = NAN
## (pos: Vector3) -> Vector3 : velocidade da corrente (m/s).
var current_func: Callable = Callable()
## (pos: Vector3) -> float : distancia (m) ao obstaculo/margem mais proximo; < 0.6 empurra de volta.
var clearance_func: Callable = Callable()
var max_speed: float = MAX_SPEED
var throttle: float = 0.0
var steer: float = 0.0
var last_slow_factor: float = 1.0
var wheel: Node3D
var deck_point: Marker3D
var _lean: float = 0.0


func _ready() -> void:
	name = "Boat"
	var hull := Node3D.new()
	hull.name = "Hull"
	add_child(hull)
	Blocks.box(hull, "HullBody", Vector3(2.2, 0.8, 5.0), Vector3(0, 0.1, 0), COLOR_HULL)
	Blocks.box(hull, "Bow", Vector3(1.4, 0.7, 1.2), Vector3(0, 0.15, -3.0), COLOR_HULL)
	Blocks.box(hull, "Deck", Vector3(2.0, 0.1, 4.6), Vector3(0, 0.52, 0), Color("c9a36a"))
	Blocks.box(hull, "Cabin", Vector3(1.6, 1.2, 1.4), Vector3(0, 1.15, 1.4), Color("fff3c4"))
	Blocks.box(hull, "Bench", Vector3(1.4, 0.35, 0.5), Ep01Layout.BENCH_LOCAL + Vector3(0, -0.1, 0), Color("a0714a"))
	wheel = Blocks.cylinder(hull, "Wheel", 0.3, 0.06, Vector3(0, 1.45, 0.5), Color("5a3a22"))
	wheel.rotation.x = deg_to_rad(70.0)
	deck_point = Marker3D.new()
	deck_point.name = "DeckPoint"
	deck_point.position = Vector3(0, 0.6, 0.2)
	add_child(deck_point)
	set_meta(Blocks.PROVISIONAL, true)


func place(pos: Vector3, new_heading: float) -> void:
	global_position = pos
	heading = new_heading
	speed = 0.0
	rotation.y = heading


func forward() -> Vector3:
	return Vector3(-sin(heading), 0.0, -cos(heading))


func _physics_process(delta: float) -> void:
	if controlled and not input_locked:
		throttle = Input.get_axis(&"move_down", &"move_up")
		steer = Input.get_axis(&"move_right", &"move_left")
	else:
		throttle = 0.0
		steer = 0.0
	step(delta)


## Passo de simulacao (publico para testes determinísticos).
func step(delta: float) -> void:
	var clearance := 1000.0
	if clearance_func.is_valid():
		clearance = float(clearance_func.call(global_position))
	last_slow_factor = 1.0
	if clearance < SLOW_RANGE:
		last_slow_factor = clampf(clearance / SLOW_RANGE, MIN_SLOW_FACTOR, 1.0)
	var limit := max_speed * last_slow_factor
	var target := limit * maxf(throttle, 0.0)
	if throttle < 0.0:
		target = 0.0
	var rate := ACCEL if target > speed else BRAKE
	if throttle == 0.0 and assist > 0.0:
		rate = BRAKE * (1.0 + assist)
	speed = move_toward(speed, target, rate * delta)
	speed = minf(speed, limit)
	var steer_eff := steer
	if assist > 0.0 and not is_nan(assist_heading):
		var err := wrapf(assist_heading - heading, -PI, PI)
		steer_eff = clampf(steer + err * 2.0 * assist, -1.0, 1.0) if absf(steer) < 0.1 else steer
	heading += steer_eff * TURN_RATE * clampf(speed / 2.0, 0.15, 1.0) * delta
	var vel := forward() * speed
	if current_func.is_valid():
		vel += current_func.call(global_position) as Vector3
	global_position += vel * delta
	if clearance_func.is_valid() and float(clearance_func.call(global_position)) < 0.6:
		global_position -= vel * delta * 1.2
		speed = maxf(speed - 2.0, 0.0)
		soft_hit.emit()
	rotation.y = heading
	_lean = lerpf(_lean, -steer_eff * 0.15 * clampf(speed / max_speed, 0.0, 1.0), clampf(4.0 * delta, 0.0, 1.0))
	rotation.z = _lean
