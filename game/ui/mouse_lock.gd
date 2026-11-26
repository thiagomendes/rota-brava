class_name MouseLock
extends RefCounted
## RB-R1 G5: unico dono de `Input.mouse_mode` no jogo. A camera so *pede* para prender (`capture`) ou soltar
## (`release`); qualquer painel/botao clicavel na tela (cartao de troca, escolha, pausa, opcoes, conclusao, cena)
## *bloqueia* com um id (`block`) e desbloqueia ao fechar (`unblock`). Enquanto houver um bloqueio o mouse fica solto
## (MOUSE_MODE_VISIBLE); quando o ultimo sai, volta a ficar preso se a camera o tinha pedido.
## Estado so de IDs e um booleano. `captured()` e o estado pedido (em modo headless a Godot nao prende o cursor real).

static var _want_capture: bool = false
static var _blockers: Dictionary = {}
## G14: quadro de fisica em que o ultimo bloqueio saiu (o A que fecha um painel nao vira pulo nesse quadro).
static var _unblocked_physics_frame: int = -100


static func capture() -> void:
	_want_capture = true
	_apply()


static func release() -> void:
	_want_capture = false
	_apply()


static func block(id: StringName) -> void:
	_blockers[id] = true
	_apply()


static func unblock(id: StringName) -> void:
	if _blockers.erase(id) and _blockers.is_empty():
		_unblocked_physics_frame = Engine.get_physics_frames()
	_apply()


static func blocked() -> bool:
	return not _blockers.is_empty()


## G14: regra central do pulo. Enquanto algum painel com botoes bloqueia, o A (e o Espaco) so confirma; e no quadro
## em que o ultimo painel fecha (e no seguinte) o mesmo aperto tambem nao vira pulo.
static func jump_suppressed() -> bool:
	return blocked() or Engine.get_physics_frames() - _unblocked_physics_frame <= 1


## O mouse esta (ou deve estar) preso para a camera agora.
static func captured() -> bool:
	return _want_capture and _blockers.is_empty()


## Volta ao estado inicial (troca/recarga de cena, testes).
static func reset() -> void:
	_want_capture = false
	_blockers.clear()
	_unblocked_physics_frame = -100
	_apply()


static func _apply() -> void:
	var mode := Input.MOUSE_MODE_CAPTURED if captured() else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mode:
		Input.mouse_mode = mode
