class_name Options
extends RefCounted
## Opcoes do jogador salvas em user://options.cfg (RB-R1). Volume por bus, tamanho de legenda (3 niveis),
## movimento reduzido e assistencia de pilotagem (so o valor e o sinal; o jogo le depois).

const PATH := "user://options.cfg"
const BUSES: Array[String] = ["Master", "Voz", "Musica", "Efeitos", "Ambiente"]
## Escala da legenda por nivel (0 pequeno, 1 normal, 2 grande).
const SUBTITLE_SCALES: Array[float] = [0.85, 1.0, 1.25]
const DEFAULTS := {
	"audio": {"Master": 0.9, "Voz": 1.0, "Musica": 0.7, "Efeitos": 0.9, "Ambiente": 0.8},
	"access": {"subtitle_size": 1, "reduced_motion": false, "steering_assist": true},
}

## Testes e capturas podem forcar movimento reduzido sem tocar no arquivo (-1 = usa o salvo).
static var motion_override: int = -1
static var _cfg: ConfigFile


## Sinais: Options.signals().changed(section, key, value) e .steering_assist_changed(on).
static func signals() -> Emitter:
	return _emitter()


class Emitter:
	extends RefCounted
	signal changed(section: String, key: String, value: Variant)
	signal steering_assist_changed(on: bool)

static var _em: Emitter


static func _emitter() -> Emitter:
	if _em == null:
		_em = Emitter.new()
	return _em


static func cfg() -> ConfigFile:
	if _cfg == null:
		load_file()
	return _cfg


static func load_file(path: String = PATH) -> void:
	_cfg = ConfigFile.new()
	_cfg.load(path)


static func save_file(path: String = PATH) -> int:
	return cfg().save(path)


static func get_value(section: String, key: String) -> Variant:
	return cfg().get_value(section, key, DEFAULTS[section][key])


static func set_value(section: String, key: String, value: Variant, save: bool = true) -> void:
	cfg().set_value(section, key, value)
	if section == "audio":
		apply_bus(key, float(value))
	if save:
		save_file()
	_emitter().changed.emit(section, key, value)
	if key == "steering_assist":
		_emitter().steering_assist_changed.emit(bool(value))


## Bus da musica sob ducking (fala tocando): o AudioDirector registra aqui para o volume novo respeitar o -6 dB.
static var music_duck_db: Callable = Callable()


static func apply_bus(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		var extra := 0.0
		if bus == "Musica" and music_duck_db.is_valid():
			extra = float(music_duck_db.call())
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)) + extra)
		AudioServer.set_bus_mute(idx, linear <= 0.001)


static func apply_all() -> void:
	for b in BUSES:
		apply_bus(b, float(get_value("audio", b)))


static func reduced_motion() -> bool:
	if motion_override >= 0:
		return motion_override == 1
	return bool(get_value("access", "reduced_motion"))


static func subtitle_scale() -> float:
	return SUBTITLE_SCALES[clampi(int(get_value("access", "subtitle_size")), 0, 2)]
