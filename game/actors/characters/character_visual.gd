class_name CharacterVisual
extends Node3D
## Visual de personagem com rig (RB-04-chars, PROVISORIO). Fica como no `Model` das cenas *_model.tscn e envolve o GLB importado
## (que nunca e editado). Expoe animacao com crossfade, expressao do rosto e medicao de contato dos pes.
## Origem nos pes, frente em -Z. Sem root motion: quem move e o ator; o visual so toca clipes.
##
## Uso pelo integrador: `visual.play(&"walk", visual.walk_speed_scale(velocity.length()))` quando velocity > 0.1,
## `visual.play(&"idle")` parado, `visual.set_expression(&"atenta")`.

const LOOPING: Array[StringName] = [&"idle", &"walk", &"run", &"idle_wheel", &"chat", &"wag", &"idle_seated"]
const EXPRESSIONS: Array[StringName] = [&"atenta", &"surpresa", &"alegre", &"triste", &"brava_leve", &"blink"]
## Visemas de boca (RB-R1): somados por cima da expressao para a boca acompanhar o balbucio.
const VISEMES: Array[StringName] = [&"mouth_A", &"mouth_E", &"mouth_O", &"mouth_M"]
## Olhar por shape keys (RB-R1): esquerda/direita do personagem e para cima.
const GAZE_KEYS: Array[StringName] = [&"look_left", &"look_right", &"look_up"]
## Velocidade (m/s) em que o clipe `walk` (ciclo de 1,0 s) nao desliza o pe no chao.
const WALK_SPEED_MPS := 0.586
const SOLE_BONES: Array[StringName] = [&"heel.L", &"heel.R", &"toe.L", &"toe.R", &"toe_tip.L", &"toe_tip.R"]

@export var blend_time: float = 0.18
## Velocidade (m/s) em que o `walk` deste modelo nao desliza (cada GLB tem a sua; o padrao e o do RB-04).
@export var walk_speed_mps: float = WALK_SPEED_MPS
## Velocidade (m/s) em que o `run` nao desliza (0 = modelo sem corrida).
@export var run_speed_mps: float = 0.0

var _player: AnimationPlayer
var _skeleton: Skeleton3D
var _face: MeshInstance3D
var _expression: StringName = &"neutra"
var _expression_weight: float = 1.0
var _visemes: Dictionary = {}
var _gaze: Vector2 = Vector2.ZERO
## Visemas/olhar so sobrescrevem o rosto depois de set_viseme/set_gaze (clipes podem animar a boca, ex.: latido do filhote).
var _extras_active: bool = false


func _ready() -> void:
	_bind()
	set_process(true)


func _bind() -> void:
	if _player != null:
		return
	_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	var skeletons := find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		_skeleton = skeletons[0] as Skeleton3D
	for n in find_children("*_Face", "MeshInstance3D", true, false):
		_face = n as MeshInstance3D
	if _player == null:
		return
	_player.playback_default_blend_time = blend_time
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for a_name in _player.get_animation_list():
		var anim := _player.get_animation(a_name)
		anim.loop_mode = Animation.LOOP_LINEAR if StringName(a_name) in LOOPING else Animation.LOOP_NONE


func _process(delta: float) -> void:
	if _player == null:
		return
	_player.advance(delta)
	_apply_expression()
	_apply_face_extras()


## Toca um clipe com crossfade curto. `speed` escala a velocidade; `blend` < 0 usa `blend_time`. Retorna false se nao existe.
func play(anim: StringName, speed: float = 1.0, blend: float = -1.0) -> bool:
	_bind()
	if _player == null or not _player.has_animation(anim):
		return false
	if _player.current_animation == String(anim) and _player.is_playing():
		_player.speed_scale = speed
		return true
	# Sem processamento (arvore pausada, fora da cena, process_mode desligado) o crossfade nunca avancaria e o corpo ficaria
	# congelado na ultima pose (ex.: passo da caminhada): nesse caso troca na hora para o primeiro quadro do novo clipe.
	var instant := not is_inside_tree() or not can_process()
	_player.play(anim, 0.0 if instant else (blend_time if blend < 0.0 else blend), speed)
	if instant:
		_player.seek(0.0, true)
		if _skeleton != null:
			_skeleton.force_update_all_bone_transforms()
	return true


func has_animation(anim_name: StringName) -> bool:
	_bind()
	return _player != null and _player.has_animation(anim_name)


func animation_names() -> PackedStringArray:
	_bind()
	return _player.get_animation_list() if _player != null else PackedStringArray()


func animation_length(anim_name: StringName) -> float:
	_bind()
	if _player == null or not _player.has_animation(anim_name):
		return 0.0
	return _player.get_animation(anim_name).length


func is_looping(anim_name: StringName) -> bool:
	_bind()
	if _player == null or not _player.has_animation(anim_name):
		return false
	return _player.get_animation(anim_name).loop_mode != Animation.LOOP_NONE


func current_animation() -> StringName:
	_bind()
	return StringName(_player.current_animation) if _player != null else &""


## Fator de velocidade do `walk` para um deslocamento de `mps` metros por segundo (sem deslizar).
func walk_speed_scale(mps: float) -> float:
	return clampf(mps / maxf(walk_speed_mps, 0.01), 0.3, 3.0)


## Fator de velocidade do `run` (sem deslizar ate o limite de 2,5x). 0 se o modelo nao corre.
func run_speed_scale(mps: float) -> float:
	if run_speed_mps <= 0.0:
		return 0.0
	return clampf(mps / run_speed_mps, 0.5, 2.5)


## Visema da boca (mouth_A, mouth_E, mouth_O, mouth_M) com peso 0..1; os outros visemas zeram. `&""` fecha a boca.
func set_viseme(viseme: StringName, weight: float = 1.0) -> void:
	_bind()
	_visemes.clear()
	if viseme in VISEMES:
		_visemes[viseme] = clampf(weight, 0.0, 1.0)
	_extras_active = true
	_apply_face_extras()


## Olhar: x < 0 para a esquerda do personagem, x > 0 para a direita, y > 0 para cima (cada eixo -1..1).
func set_gaze(dir: Vector2) -> void:
	_bind()
	_gaze = dir.clamp(Vector2(-1, -1), Vector2(1, 1))
	_extras_active = true
	_apply_face_extras()


## Olha para um ponto do mundo (so os olhos; a cabeca segue o clipe).
func look_at_point(point: Vector3) -> void:
	var local := global_transform.affine_inverse() * point
	var head := bone_position(&"head")
	var origin := global_transform.affine_inverse() * head if head != Vector3.INF else Vector3(0, 0.8, 0)
	var d := local - origin
	if d.length() < 0.01:
		set_gaze(Vector2.ZERO)
		return
	d = d.normalized()
	# frente = -Z; direita do personagem = +X
	set_gaze(Vector2(clampf(d.x * 1.6, -1, 1), clampf(d.y * 1.6, -1, 1)))


func _apply_face_extras() -> void:
	if _face == null or _face.mesh == null or not _extras_active:
		return
	for key in VISEMES:
		var idx := _face.find_blend_shape_by_name(String(key))
		if idx >= 0:
			_face.set_blend_shape_value(idx, float(_visemes.get(key, 0.0)))
	var g := {&"look_left": maxf(-_gaze.x, 0.0), &"look_right": maxf(_gaze.x, 0.0), &"look_up": maxf(_gaze.y, 0.0)}
	for key in GAZE_KEYS:
		var idx := _face.find_blend_shape_by_name(String(key))
		if idx >= 0:
			_face.set_blend_shape_value(idx, float(g[key]))


## Expressao do rosto: neutra, atenta, surpresa ou alegre. Soma-se (maximo) ao que o clipe anima (ex.: piscar).
func set_expression(expr: StringName, weight: float = 1.0) -> void:
	_bind()
	_expression = expr
	_expression_weight = clampf(weight, 0.0, 1.0)
	if _player != null and not _player.is_playing():
		_set_shapes(expr, _expression_weight, false)


func expression() -> StringName:
	return _expression


func _apply_expression() -> void:
	if _face == null:
		return
	_set_shapes(_expression, _expression_weight, true)


func _set_shapes(expr: StringName, weight: float, keep_max: bool) -> void:
	if _face == null or _face.mesh == null:
		return
	for key in EXPRESSIONS:
		var idx := _face.find_blend_shape_by_name(String(key))
		if idx < 0:
			continue
		var want := weight if key == expr else 0.0
		var cur := _face.get_blend_shape_value(idx) if keep_max else 0.0
		_face.set_blend_shape_value(idx, maxf(cur, want) if keep_max else want)


func face_mesh() -> MeshInstance3D:
	_bind()
	return _face


func skeleton() -> Skeleton3D:
	_bind()
	return _skeleton


func animation_player() -> AnimationPlayer:
	_bind()
	return _player


## Posicao no mundo da origem do osso (heel.L, hand.R, ...). Vector3.INF se nao existir.
func bone_position(bone: StringName) -> Vector3:
	_bind()
	if _skeleton == null:
		return Vector3.INF
	var idx := _skeleton.find_bone(String(bone))
	if idx < 0:
		return Vector3.INF
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(idx).origin


## Altura (m, sinal) do ponto mais baixo dos pes (calcanhares, bolas e pontas) em relacao ao chao do ator (origem do visual).
func lowest_foot_height() -> float:
	_bind()
	var lo := INF
	for b in SOLE_BONES:
		var p := bone_position(b)
		if p != Vector3.INF:
			lo = minf(lo, p.y)
	return lo - global_position.y if lo != INF else INF


## Distancia vertical (m, absoluta) do pe mais baixo ao chao do ator no quadro atual do clipe.
func foot_contact_error() -> float:
	var h := lowest_foot_height()
	return absf(h) if h != INF else INF


## Avanca o clipe atual ate o tempo `t` (s) de forma deterministica (testes e capturas).
func seek_clip(anim: StringName, t: float) -> bool:
	_bind()
	if _player == null or not _player.has_animation(anim):
		return false
	_player.play(anim, 0.0)
	_player.seek(t, true)
	_player.pause()
	if _skeleton != null:
		_skeleton.force_update_all_bone_transforms()
	return true




## Modelos PBR com verniz (herois v2, RB-R1 E1b) marcam `metadata/pbr = true` no no `Model`: quem monta nao aplica
## Stylize nem contorno neles.
func is_pbr() -> bool:
	return bool(get_meta(&"pbr", false))


## Aplica o estilo toon + contorno so em modelos antigos (nao PBR). `node` pode ser qualquer Node3D de personagem.
static func stylize_if_toon(node: Node, outline: float) -> void:
	if node == null or bool(node.get_meta(&"pbr", false)):
		return
	Stylize.apply(node)
	Stylize.add_outline(node, outline)


## Liga/desliga um acessorio do GLB pelo nome do no (ex.: `set_accessory(&"Acc_LifeVest", true)`). False se nao existe.
func set_accessory(acc_name: StringName, on: bool) -> bool:
	var n := find_child(String(acc_name), true, false) as Node3D
	if n == null:
		return false
	n.visible = on
	return true


func has_accessory(acc_name: StringName) -> bool:
	return find_child(String(acc_name), true, false) is Node3D


func accessory_visible(acc_name: StringName) -> bool:
	var n := find_child(String(acc_name), true, false) as Node3D
	return n != null and n.visible


## Nomes dos acessorios (`Acc_*`) que este modelo tem.
func accessory_names() -> PackedStringArray:
	var out := PackedStringArray()
	for n in find_children("Acc_*", "Node3D", true, false):
		out.append(String(n.name))
	return out
