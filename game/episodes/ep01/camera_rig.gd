class_name CameraRig
extends Node3D
## Camera em terceira pessoa dirigida por area: segue `target` com deslocamento e giro definidos pelo estagio.
## Sensacao (RB-R1): leve atraso (suavizacao) e antecipacao na direcao do movimento do alvo; tremor curto opcional.
## Com `reduced_motion`: sem atraso, sem antecipacao e sem tremor.
## G24a (RB-R1): a antecipacao (`lead`) move so a MIRA, nunca a camera; o atraso do lerp e compensado pela velocidade
## suavizada e a distancia horizontal ao heroi nunca fica abaixo do braco pedido. Ao correr o braco abre RUN_ARM e o
## FOV abre RUN_FOV graus (sem variacao de FOV em `reduced_motion`), com transicao suave de ~RUN_TIME s.

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
## G24a2 v2: false = a camera nao desvia das copas (`occluders` viram peca, que fica pontilhada via `occlusion`).
var avoid_canopies: bool = true
## G24a2 v2: pecas (caixotes, toldos, barracas, arvores...) fora da mascara/`exclude` ficam pontilhadas quando tapam o
## heroi ou contem a camera (null = desligado). A mola de braco (G6) continua so para a estrutura.
var occlusion: CameraOcclusion
## Alguma peca pontilhada no ultimo quadro (testes/depuracao).
var occluded: bool = false
const PROBE_RADIUS := 0.2
const MIN_ARM := 0.9
const ARM_MARGIN := 0.08
## Braco (RB-R1): a mola (~ARM_IN_TIME s para encurtar, ~ARM_OUT_TIME s para voltar, histerese ARM_HYST) segue a zona
## macia (esfera de SOFT_RADIUS e copas com a mesma folga), que ve a parede antes; se ainda assim a parede corta o
## braco (esfera de PROBE_RADIUS), a camera encosta NA HORA, sem nunca ficar dentro ou atras dela.
const SOFT_RADIUS := 0.9
const ARM_IN_TIME := 0.25
const ARM_OUT_TIME := 1.2
const ARM_HYST := 0.04
## Encurtamento do ultimo quadro (m; 0 = livre), para testes e depuracao.
var last_pull: float = 0.0
var _probe: SphereShape3D
var _probe_soft: SphereShape3D
var _arm: float = -1.0
var _arm_vel: float = 0.0
var _follow_pos: Vector3 = Vector3.ZERO
var _written: Vector3 = Vector3(INF, INF, INF)
## Orbita (C1, RB-R1): alavanca direita (`cam_left/right/up/down`) e mouse capturado giram em volta do heroi; guinada livre,
## inclinacao limitada. `pitch` 0 = enquadramento baixo aprovado (positivo sobe a camera). Desligada por padrao (fluxo antigo).
var orbit_enabled: bool = false
var pitch: float = 0.0
const ORBIT_SPEED := 2.4
const PITCH_SPEED := 1.4
const PITCH_MIN := -0.22
const PITCH_MAX := 0.55
const MOUSE_SENS := 0.004

## G24a: abertura na corrida (0 = andando/parado, 1 = correndo), entre RUN_FROM e RUN_TO m/s de velocidade planar.
const RUN_FROM := 1.8
const RUN_TO := 3.0
const RUN_ARM := 0.10
const RUN_FOV := 4.0
const RUN_TIME := 0.6
var run_open: float = 0.0
var _vel: Vector3 = Vector3.ZERO
var _fov_base: float = -1.0
var _fov_written: float = -1.0

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
	_ready_priority()


## look_y: altura do ponto de mira acima do alvo (0,75 = peito de crianca de ~1,14 m).
func set_view(new_offset: Vector3, new_yaw: float = 0.0, look_y: float = LOOK_Y) -> void:
	offset = new_offset
	yaw = new_yaw
	framing_world = false
	look_offset = Vector3(0, look_y, 0)


## Camera baixa do jogo (vila v3) com giro `new_yaw` (inclinacao volta ao enquadramento aprovado).
func set_low_view(new_yaw: float = 0.0) -> void:
	set_view(LOW_OFFSET, new_yaw, LOW_LOOK_Y)
	pitch = 0.0
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
		_arm = -1.0
		_update(1.0, 0.0)


## Tremor curto (desligado em reduced_motion).
func shake(amplitude: float = 0.12, duration: float = 0.25) -> void:
	if reduced_motion:
		return
	_shake_amp = maxf(_shake_amp, amplitude)
	_shake_time = maxf(_shake_time, duration)


## RB-R1 (tremor na corrida): o heroi anda em _physics_process sem interpolacao; a camera seguia em _process e, com
## render != 60 Hz, ora avancava sem o heroi ter andado, ora o alcancava aos saltos (serrilhado). Agora a camera anda no
## MESMO passo de fisica, depois dos atores (prioridade alta), com suavizacao exponencial (independente do delta).
func _ready_priority() -> void:
	process_physics_priority = 100


func _physics_process(delta: float) -> void:
	if orbit_enabled:
		orbit_step(delta)
	_update(1.0 if reduced_motion else 1.0 - exp(-smooth * delta), delta)


func _update(weight: float, delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	_clock += delta
	var focus := target.global_position
	_update_lead(focus, delta)
	_update_run(delta)
	var rel := offset if framing_world else Basis(Vector3.UP, yaw) * (Basis(Vector3.RIGHT, -pitch) * offset)
	if not framing_world:
		rel *= 1.0 + RUN_ARM * run_open
	# Compensa o atraso do lerp (v / smooth em regime) com a velocidade suavizada: sem isso a camera fica para tras
	# (ou, correndo para ela, chega perto). Nada da antecipacao entra aqui.
	var lag := Vector3.ZERO if weight >= 1.0 else _vel / smooth
	var wanted := focus + rel + lag
	# Alguem moveu a camera por fora (captura, cena): parte de onde ela esta.
	if camera.global_position.distance_to(_written) > 0.0001:
		_follow_pos = camera.global_position
	_follow_pos = _follow_pos.lerp(wanted, weight)
	if not framing_world:
		_follow_pos = _keep_arm(focus, _follow_pos, Vector2(rel.x, rel.z).length())
	var pivot := focus + look_offset
	var look := pivot + (lead if not framing_world else Vector3.ZERO)
	var pos := _follow_pos
	if collision_mask != 0:
		var soft := avoid(pivot, _follow_pos, SOFT_RADIUS, SOFT_RADIUS - PROBE_RADIUS)
		pos = _smooth_arm(pivot, _follow_pos, avoid(pivot, _follow_pos), soft, delta)
	camera.global_position = pos
	_written = pos
	if _shake_time > 0.0 and not reduced_motion:
		_shake_time = maxf(0.0, _shake_time - delta)
		var a := _shake_amp * (_shake_time / maxf(_shake_time + delta, 0.001))
		look += Vector3(sin(_clock * 53.0), cos(_clock * 41.0), 0.0) * a
		if _shake_time <= 0.0:
			_shake_amp = 0.0
	if camera.global_position.distance_to(look) > 0.01:
		camera.look_at(look, Vector3.UP)
	_apply_fov()
	if occlusion != null:
		occlusion.update(pos, focus, delta, reduced_motion, not framing_world)
		occluded = occlusion.swapped_now > 0


## G24a2 v2: `point` esta numa peca pontilhada, na area que o shader faz sumir? (testes)
func occlusion_covers(point: Vector3) -> bool:
	if occlusion == null or target == null:
		return false
	return occlusion.covers_point(point, camera.global_position, target.global_position)


## G24a: o atraso nunca aproxima a camera do heroi (distancia horizontal >= `arm`); so a mola de obstaculo encurta.
func _keep_arm(focus: Vector3, pos: Vector3, arm: float) -> Vector3:
	var flat := Vector3(pos.x - focus.x, 0.0, pos.z - focus.z)
	var h := flat.length()
	if h >= arm or h < 0.001:
		return pos
	var out := focus + flat * (arm / h)
	out.y = pos.y
	return out


## G24a: abertura suave na corrida pela velocidade planar suavizada.
func _update_run(delta: float) -> void:
	var want := 0.0 if framing_world else smoothstep(RUN_FROM, RUN_TO, Vector2(_vel.x, _vel.z).length())
	if delta <= 0.0:
		run_open = want
		return
	run_open = lerpf(run_open, want, 1.0 - exp(-3.0 / RUN_TIME * delta))


## FOV base = o que o estagio pediu (set_low_view, cenas); a corrida soma ate RUN_FOV, exceto em `reduced_motion`.
func _apply_fov() -> void:
	if absf(camera.fov - _fov_written) > 0.001:
		_fov_base = camera.fov
	camera.fov = _fov_base + (0.0 if reduced_motion else RUN_FOV * run_open)
	_fov_written = camera.fov


## Braco suavizado: a mola encurta (ARM_IN_TIME) e volta devagar (ARM_OUT_TIME) rumo a zona macia, com histerese de
## ARM_HYST (a esfera/copa que liga e desliga a cada quadro nao faz o braco ir e voltar); acima do limite duro
## (`hard_pos`) encosta na hora e zera a velocidade.
func _smooth_arm(look: Vector3, free_pos: Vector3, hard_pos: Vector3, soft_pos: Vector3, delta: float) -> Vector3:
	var free_len := free_pos.distance_to(look)
	if free_len < 0.01:
		return free_pos
	var hard := hard_pos.distance_to(look)
	var want := minf(soft_pos.distance_to(look), hard)
	# G24a2 v2: tambem com movimento reduzido a mola e suave (reduzido nunca pode saltar mais que o normal).
	if _arm < 0.0 or delta <= 0.0:
		_arm = want
		_arm_vel = 0.0
	elif want < _arm:
		_arm = _damp(_arm, want, ARM_IN_TIME, delta)
	elif want > _arm + ARM_HYST:
		_arm = _damp(_arm, want, ARM_OUT_TIME, delta)
	else:
		_arm = _damp(_arm, _arm, ARM_OUT_TIME, delta)
	if _arm > hard:
		# Limite duro: a camera encosta na hora, nunca fica dentro ou atras do obstaculo.
		_arm = hard
		_arm_vel = 0.0
	if _arm > free_len:
		_arm_vel = minf(_arm_vel, 0.0)
	_arm = clampf(_arm, minf(MIN_ARM, free_len), free_len)
	last_pull = free_len - _arm
	return look + (free_pos - look) / free_len * _arm


## Mola criticamente amortecida (sem salto de velocidade): `smooth_time` ~ tempo para chegar ao alvo.
func _damp(cur: float, want: float, smooth_time: float, delta: float) -> float:
	var omega := 2.0 / smooth_time
	var x := omega * delta
	var e := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := cur - want
	var temp := (_arm_vel + omega * change) * delta
	_arm_vel = (_arm_vel - omega * temp) * e
	return want + (change + temp) * e


## Posicao da camera sem obstaculo entre `from` (ponto de mira) e `to` (camera desejada).
## `radius`/`grow`: esfera e folga nas copas maiores para a zona macia (a mola comeca a encurtar antes da parede).
func avoid(from: Vector3, to: Vector3, radius: float = PROBE_RADIUS, grow: float = 0.0) -> Vector3:
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
		_probe_soft = SphereShape3D.new()
		_probe_soft.radius = SOFT_RADIUS
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _probe if radius <= PROBE_RADIUS else _probe_soft
	q.transform = Transform3D(Basis(), from)
	q.motion = seg
	q.collision_mask = collision_mask
	q.exclude = exclude
	var res := get_world_3d().direct_space_state.cast_motion(q)
	# [1, 1] = livre; [0, 0] = a mira ja comeca dentro de algo (ignora: nao colar a camera no heroi).
	if res.size() == 2 and res[1] > 0.0 and res[0] < 1.0:
		allowed = minf(allowed, dist * res[0] - ARM_MARGIN)
	var canopy_list: Array[Vector4] = occluders if avoid_canopies else ([] as Array[Vector4])
	for s in canopy_list:
		var c := Vector3(s.x, s.y, s.z)
		var w := s.w + grow
		var oc := from - c
		if oc.length() <= w:
			continue
		var b := oc.dot(dir)
		var disc := b * b - (oc.length_squared() - w * w)
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


## Um passo de orbita pelas acoes da Input Map (publico para teste deterministico).
func orbit_step(delta: float) -> void:
	var h := Input.get_axis(&"cam_left", &"cam_right")
	var v := Input.get_axis(&"cam_down", &"cam_up")
	yaw = wrapf(yaw - h * ORBIT_SPEED * delta, -PI, PI)
	pitch = clampf(pitch - v * PITCH_SPEED * delta, PITCH_MIN, PITCH_MAX)


## Giro por arrasto (mouse preso ou dedo, RB-M1): `rel` em px; x gira em volta do heroi, y inclina (limitado).
func orbit_by(rel: Vector2, yaw_sens: float = MOUSE_SENS, pitch_sens: float = MOUSE_SENS) -> void:
	yaw = wrapf(yaw - rel.x * yaw_sens, -PI, PI)
	pitch = clampf(pitch + rel.y * pitch_sens, PITCH_MIN, PITCH_MAX)


func _unhandled_input(event: InputEvent) -> void:
	if not orbit_enabled:
		return
	# RB-M1: o mouse que a Godot emula do toque nao prende nem gira (o toque gira pela camada TouchControls).
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	# G5: o modo do mouse e do MouseLock; com painel clicavel aberto o pedido de prender fica guardado.
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and not MouseLock.captured() and not MouseLock.blocked() and not get_tree().paused:
		MouseLock.capture()
	elif event is InputEventMouseMotion and MouseLock.captured():
		orbit_by((event as InputEventMouseMotion).relative)
	elif event.is_action_pressed(&"ui_cancel") and not event.is_action_pressed(&"pause"):
		# Esc fora da pausa solta o mouse de vez; a pausa so bloqueia (ao fechar, volta a prender).
		release_mouse()


func release_mouse() -> void:
	MouseLock.release()


func _exit_tree() -> void:
	release_mouse()


func _update_lead(focus: Vector3, delta: float) -> void:
	if delta <= 0.0 or not _has_last:
		lead = Vector3.ZERO
		_vel = Vector3.ZERO
		_last_focus = focus
		_has_last = true
		return
	var v := (focus - _last_focus) / delta
	_last_focus = focus
	v.y = 0.0
	if v.length() > 40.0:
		v = Vector3.ZERO
		_vel = Vector3.ZERO
	_vel = _vel.lerp(v, 1.0 - exp(-8.0 * delta))
	if reduced_motion:
		lead = Vector3.ZERO
		return
	var want := v * lead_time
	if want.length() > LEAD_MAX:
		want = want.normalized() * LEAD_MAX
	# Teleporte (salto grande num quadro) nao conta como movimento.
	if v.length() > 40.0:
		want = Vector3.ZERO
	lead = lead.lerp(want, clampf(LEAD_SMOOTH * delta, 0.0, 1.0))
