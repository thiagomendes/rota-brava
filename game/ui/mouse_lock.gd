class_name MouseLock
extends RefCounted
## RB-R1 G5: unico dono de `Input.mouse_mode` no jogo. A camera so *pede* para prender (`capture`) ou soltar
## (`release`); qualquer painel/botao clicavel na tela (cartao de troca, escolha, pausa, opcoes, conclusao, cena)
## *bloqueia* com um id (`block`) e desbloqueia ao fechar (`unblock`). Enquanto houver um bloqueio o mouse fica solto
## (MOUSE_MODE_VISIBLE); quando o ultimo sai, volta a ficar preso se a camera o tinha pedido.
## Estado so de IDs e um booleano. `captured()` e o estado pedido (em modo headless a Godot nao prende o cursor real).

static var _want_capture: bool = false
static var _blockers: Dictionary = {}


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
	_blockers.erase(id)
	_apply()


static func blocked() -> bool:
	return not _blockers.is_empty()


## O mouse esta (ou deve estar) preso para a camera agora.
static func captured() -> bool:
	return _want_capture and _blockers.is_empty()


## Volta ao estado inicial (troca/recarga de cena, testes).
static func reset() -> void:
	_want_capture = false
	_blockers.clear()
	_apply()


static func _apply() -> void:
	var mode := Input.MOUSE_MODE_CAPTURED if captured() else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mode:
		Input.mouse_mode = mode
