class_name CameraRig
extends Node3D
## Camera em terceira pessoa dirigida por area: segue `target` com deslocamento e giro definidos pelo estagio.
## Sensacao (RB-R1): leve atraso (suavizacao) e antecipacao na direcao do movimento do alvo; tremor curto opcional.
## Com `reduced_motion`: sem atraso, sem antecipacao e sem tremor.

var camera: Camera3D
var target: Node3D
var offset: Vector3 = Vector3(0, 7.5, 9.5)
const LOOK_Y := 0.75
var look_offset: Vector3 = Vector3(0, LOOK_Y, 0)
## Giro em Y do conjunto; a entrada de movimento usa este valor.
var yaw: float = 0.0
var smooth: float = 4.0
var reduced_motion: bool = false
## Antecipacao: segundos de movimento a frente (limitado a LEAD_MAX metros), suavizado.
var lead_time: float = 0.35
const LEAD_MAX := 1.4
const LEAD_SMOOTH := 2.5
## Enquadramento livre (pose de equipe): offset em coordenadas do mundo, ignora `yaw`.
var framing_world: bool = false

var lead: Vector3 = Vector3.ZERO
var _last_focus: Vector3 = Vector3.ZERO
var _has_last: bool = false
var _shake_time: float = 0.0
var _shake_amp: float = 0.0
var _clock: float = 0.0


func _ready() -> void:
	name = "CameraRig"
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 55.0
	camera.current = true
	add_child(camera)


## look_y: altura do ponto de mira acima do alvo (0,75 = peito de crianca de ~1,14 m).
func set_view(new_offset: Vector3, new_yaw: float = 0.0, look_y: float = LOOK_Y) -> void:
	offset = new_offset
	yaw = new_yaw
	framing_world = false
	look_offset = Vector3(0, look_y, 0)


## Enquadra `node` de frente: camera em `node + front * distance + altura`, olhando para o peito.
func frame_front(node: Node3D, front: Vector3, distance: float = 3.0, height: float = 1.2) -> void:
	front.y = 0.0
	if front.length() < 0.01:
		front = Vector3.BACK
	offset = front.normalized() * distance + Vector3(0, height, 0)
	look_offset = Vector3(0, 0.9, 0)
	framing_world = true
	follow(node)


func follow(node: Node3D, snap: bool = false) -> void:
	if node != target:
		_has_last = false
		lead = Vector3.ZERO
	target = node
	if snap:
		_update(1.0, 0.0)


## Tremor curto (desligado em reduced_motion).
func shake(amplitude: float = 0.12, duration: float = 0.25) -> void:
	if reduced_motion:
		return
	_shake_amp = maxf(_shake_amp, amplitude)
	_shake_time = maxf(_shake_time, duration)


func _process(delta: float) -> void:
	_update(1.0 if reduced_motion else clampf(smooth * delta, 0.0, 1.0), delta)


func _update(weight: float, delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	_clock += delta
	var focus := target.global_position
	_update_lead(focus, delta)
	var base := focus + (lead if not framing_world else Vector3.ZERO)
	var rel := offset if framing_world else Basis(Vector3.UP, yaw) * offset
	var wanted := base + rel
	camera.global_position = camera.global_position.lerp(wanted, weight)
	var look := base + look_offset
	if _shake_time > 0.0 and not reduced_motion:
		_shake_time = maxf(0.0, _shake_time - delta)
		var a := _shake_amp * (_shake_time / maxf(_shake_time + delta, 0.001))
		look += Vector3(sin(_clock * 53.0), cos(_clock * 41.0), 0.0) * a
		if _shake_time <= 0.0:
			_shake_amp = 0.0
	if camera.global_position.distance_to(look) > 0.01:
		camera.look_at(look, Vector3.UP)


func _update_lead(focus: Vector3, delta: float) -> void:
	if reduced_motion or delta <= 0.0:
		lead = Vector3.ZERO
		_last_focus = focus
		_has_last = true
		return
	if not _has_last:
		_last_focus = focus
		_has_last = true
		return
	var v := (focus - _last_focus) / delta
	_last_focus = focus
	v.y = 0.0
	var want := v * lead_time
	if want.length() > LEAD_MAX:
		want = want.normalized() * LEAD_MAX
	# Teleporte (salto grande num quadro) nao conta como movimento.
	if v.length() > 40.0:
		want = Vector3.ZERO
	lead = lead.lerp(want, clampf(LEAD_SMOOTH * delta, 0.0, 1.0))
