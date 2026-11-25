class_name MissionHelp
extends RefCounted
## Ajuda em 3 degraus por tempo parado sem progresso (RB-R1 E2). Sem relogio proprio: quem usa chama `tick(delta)`,
## entao os testes simulam o tempo sem esperar. Progresso da missao (ou passo novo) zera a contagem e o degrau.
## 1 (~10 s): gesto do heroi + brilho no alvo. 2 (~20 s): fala do Farol 7 no radio (chave). 3 (~35 s): seta + camera.
## Com movimento reduzido, o degrau 3 so mostra a seta (`move_camera` = false).

signal gesture_hint(target: StringName, gesture_key: StringName)
signal radio_hint(radio_key: StringName)
signal pointer_hint(target: StringName, move_camera: bool)
## A ajuda apagou (houve progresso depois de algum degrau).
signal cleared

var tier_times: PackedFloat32Array = PackedFloat32Array([10.0, 20.0, 35.0])
var reduced_motion: bool = false
var idle_time: float = 0.0
var tier: int = 0
var mission: Mission


## `times`: 3 tempos crescentes em segundos (opcional).
func _init(times: PackedFloat32Array = PackedFloat32Array()) -> void:
	if times.size() == 3 and times[0] < times[1] and times[1] < times[2]:
		tier_times = times


func attach(m: Mission) -> void:
	if mission != null:
		mission.progressed.disconnect(_on_progress)
		mission.step_started.disconnect(_on_step)
	mission = m
	m.progressed.connect(_on_progress)
	m.step_started.connect(_on_step)
	reset()


func reset() -> void:
	var had := tier > 0
	idle_time = 0.0
	tier = 0
	if had:
		cleared.emit()


func tick(delta: float) -> void:
	if mission == null or not mission.is_active():
		return
	idle_time += delta
	var s := mission.current_step()
	while tier < 3 and idle_time >= tier_times[tier]:
		tier += 1
		match tier:
			1:
				gesture_hint.emit(s["target"], s["hint_gesture_key"])
			2:
				radio_hint.emit(s["hint_spoken_key"])
			3:
				pointer_hint.emit(s["target"], not reduced_motion)


func _on_progress(_id: StringName) -> void:
	reset()


func _on_step(_id: StringName, _i: int, _s: StringName) -> void:
	reset()
