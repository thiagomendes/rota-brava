class_name HoldButton
extends Button
## G13: botao que so dispara se for SEGURADO por `hold_seconds` (apagar um espaco de jogo sem querer). Um anel na
## esquerda enche enquanto segura; soltar antes esvazia o anel e emite `released_early` (quem usa mostra a dica
## "Segure para apagar"). Funciona com mouse/toque (segurar o clique), teclado e controle (segurar `ui_accept` ou
## `interact` com o botao em foco). Nao emite `pressed`: o clique curto nunca apaga.

signal held
signal released_early
signal hold_started

const RING_COLOR := Color("0B2440")
const RING_BACK := Color(1, 1, 1, 0.7)
const RING_D := 84.0
const RING_W := 14.0

@export var hold_seconds: float = 1.5
## 0..1: quanto do tempo de segurar ja passou.
var progress: float = 0.0
## Fonte da pressao em curso: &"" (nenhuma), &"pointer" ou &"action".
var holding: StringName = &""
## Depois de disparar, precisa soltar antes de armar de novo.
var _spent: bool = false


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	mouse_exited.connect(func() -> void:
		if holding == &"pointer":
			_release())
	focus_exited.connect(func() -> void:
		if holding == &"action":
			_release())


func _ready() -> void:
	if icon == null:
		var img := Image.create(int(RING_D), int(RING_D), false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		icon = ImageTexture.create_from_image(img)
	expand_icon = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if event.is_pressed():
			_press(&"pointer")
		elif holding == &"pointer":
			_release()
		return
	if event is InputEventScreenTouch:
		accept_event()
		if event.is_pressed():
			_press(&"pointer")
		elif holding == &"pointer":
			_release()
		return
	if event is InputEventMouseMotion:
		return
	for a: StringName in [&"ui_accept", &"interact"]:
		if event.is_action(a):
			accept_event()
			if event.is_echo():
				return
			if event.is_pressed():
				_press(&"action")
			elif holding == &"action":
				_release()
			return


func _press(source: StringName) -> void:
	if disabled or holding != &"":
		return
	if not has_focus():
		grab_focus()
	holding = source
	_spent = false
	progress = 0.0
	hold_started.emit()
	queue_redraw()


func _release() -> void:
	var was := holding
	holding = &""
	if was != &"" and not _spent:
		released_early.emit()
	_spent = false
	progress = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


## Avanca o tempo de segurar (o _process chama com o delta real; os testes podem chamar direto).
func advance(delta: float) -> void:
	if holding == &"" or _spent:
		return
	# delta real mesmo com Engine.time_scale (a crianca segura em segundos de relogio)
	progress = minf(1.0, progress + delta / maxf(Engine.time_scale, 0.0001) / maxf(hold_seconds, 0.01))
	queue_redraw()
	if progress >= 1.0:
		_spent = true
		held.emit()


func _draw() -> void:
	# Anel no lugar do icone (um quadrado transparente de RING_D reserva o espaco antes do texto): fundo claro e arco
	# azul-noite que enche no sentido horario; cheio vira um disco.
	var r := RING_D * 0.5
	var sb := get_theme_stylebox(&"normal")
	var c := Vector2((sb.content_margin_left if sb != null else 24.0) + r, size.y * 0.5)
	var rr := r - RING_W * 0.5
	draw_arc(c, rr, 0.0, TAU, 64, RING_BACK, RING_W, true)
	draw_arc(c, r - 1.5, 0.0, TAU, 64, RING_COLOR, 3.0, true)
	if progress > 0.0:
		draw_arc(c, rr, -PI * 0.5, -PI * 0.5 + TAU * progress, 64, RING_COLOR, RING_W, true)
	if progress >= 1.0:
		draw_circle(c, r - RING_W - 4.0, RING_COLOR)
