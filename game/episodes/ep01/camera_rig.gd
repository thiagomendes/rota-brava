class_name CameraRig
extends Node3D
## Camera em terceira pessoa dirigida por area: segue `target` com deslocamento e giro definidos pelo estagio.
## Sensacao (RB-R1): leve atraso (suavizacao) e antecipacao na direcao do movimento do alvo; tremor curto opcional.
## Com `reduced_motion`: sem atraso, sem antecipacao e sem tremor.

var camera: Camera3D
var target: Node3D
var offset: Vector3 = Vector3(0, 7.5, 9.5)
const LOOK_Y := 0.75
## Camera baixa aprovada na vitrine do mundo v2 (lookdev, D14): ~1,95 m do chao, ~12 graus para baixo, FOV 50; a 4,1 m atras do
## heroi (~1,1 m) ele ocupa ~28% da altura da tela. Usada pelo Ep01 v3 (vila); o fluxo antigo mantem a camera alta.
const LOW_OFFSET := Vector3(0, 1.95, 4.1)
const LOW_LOOK_Y := 1.08
const LOW_FOV := 50.0
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
## Desvio de obstaculos (RB-R1 E5): com mascara != 0, uma esfera de PROBE_RADIUS vai do ponto de mira ate a camera e a
## camera para antes do primeiro obstaculo (como um spring arm), nunca a menos de MIN_ARM do ponto de mira. Encurta na
## hora e volta suave (o proprio atraso da camera). `exclude` tira corpos invisiveis (paredes da agua, limites do mapa).
## `occluders` = esferas (xyz centro, w raio) sem colisao que tapam o heroi (copas das arvores). Mascara 0 = desligado.
var collision_mask: int = 0
var exclude: Array[RID] = []
var occluders: Array[Vector4] = []
const PROBE_RADIUS := 0.2
const MIN_ARM := 0.9
const ARM_MARGIN := 0.08
## Encurtamento do ultimo quadro (m; 0 = livre), para testes e depuracao.
var last_pull: float = 0.0
var _probe: SphereShape3D

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


## Camera baixa do jogo (vila v3) com giro `new_yaw`.
func set_low_view(new_yaw: float = 0.0) -> void:
	set_view(LOW_OFFSET, new_yaw, LOW_LOOK_Y)
	if camera != null:
		camera.fov = LOW_FOV


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
	if collision_mask != 0:
		camera.global_position = avoid(look, camera.global_position)
	if _shake_time > 0.0 and not reduced_motion:
		_shake_time = maxf(0.0, _shake_time - delta)
		var a := _shake_amp * (_shake_time / maxf(_shake_time + delta, 0.001))
		look += Vector3(sin(_clock * 53.0), cos(_clock * 41.0), 0.0) * a
		if _shake_time <= 0.0:
			_shake_amp = 0.0
	if camera.global_position.distance_to(look) > 0.01:
		camera.look_at(look, Vector3.UP)


## Posicao da camera sem obstaculo entre `from` (ponto de mira) e `to` (camera desejada).
func avoid(from: Vector3, to: Vector3) -> Vector3:
	last_pull = 0.0
	var seg := to - from
	var dist := seg.length()
	if dist < 0.01 or not is_inside_tree():
		return to
	var dir := seg / dist
	var allowed := dist
	if _probe == null:
		_probe = SphereShape3D.new()
		_probe.radius = PROBE_RADIUS
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _probe
	q.transform = Transform3D(Basis(), from)
	q.motion = seg
	q.collision_mask = collision_mask
	q.exclude = exclude
	var res := get_world_3d().direct_space_state.cast_motion(q)
	# [1, 1] = livre; [0, 0] = a mira ja comeca dentro de algo (ignora: nao colar a camera no heroi).
	if res.size() == 2 and res[1] > 0.0 and res[0] < 1.0:
		allowed = minf(allowed, dist * res[0] - ARM_MARGIN)
	for s in occluders:
		var c := Vector3(s.x, s.y, s.z)
		var oc := from - c
		if oc.length() <= s.w:
			continue
		var b := oc.dot(dir)
		var disc := b * b - (oc.length_squared() - s.w * s.w)
		if disc < 0.0:
			continue
		var t := -b - sqrt(disc)
		if t > 0.0 and t < allowed:
			allowed = t - ARM_MARGIN
	if allowed >= dist:
		return to
	allowed = maxf(allowed, MIN_ARM)
	last_pull = dist - allowed
	return from + dir * allowed


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
