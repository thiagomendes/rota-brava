class_name RiverBuoyTracker
extends RefCounted
## Logica pura de "contornou a boia": acumula o angulo (com sinal) percorrido ao redor do centro dentro de `radius`.
## Ao somar |angulo| >= `target` (padrao PI) fica `done`. Ir e voltar se cancela.

var center: Vector3
var radius: float = 9.0
var target: float = PI
var accumulated: float = 0.0
var done: bool = false
var _last: float = NAN


func _init(c: Vector3 = Vector3.ZERO, r: float = 9.0, t: float = PI) -> void:
	center = c
	radius = r
	target = t


## Alimenta com a posicao do barco; devolve true APENAS na amostra que completa a volta.
func feed(pos: Vector3) -> bool:
	var d := Vector2(pos.x - center.x, pos.z - center.z)
	if d.length() > radius or d.length() < 0.01:
		_last = NAN
		return false
	var a := d.angle()
	if not is_nan(_last):
		accumulated += wrapf(a - _last, -PI, PI)
	_last = a
	if not done and absf(accumulated) >= target:
		done = true
		return true
	return false


func reset() -> void:
	accumulated = 0.0
	done = false
	_last = NAN
