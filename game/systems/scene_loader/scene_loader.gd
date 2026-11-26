class_name SceneLoaderService
extends CanvasLayer
## G10 (RB-R1): carregador unico de cenas (autoload `SceneLoader`). Toda troca de cena do jogo passa por aqui:
## a tela de carregamento (noite #1A1440/#2A1745 + estrela-guia de 4 pontas do logo C) entra no mesmo quadro do
## pedido, a cena carrega em segundo plano (`ResourceLoader.load_threaded_request`) enquanto a estrela gira, e a tela
## so sai depois que a cena nova ja desenhou dois quadros (instanciar, `_ready` e a compilacao de shader do primeiro
## quadro acontecem atras dela). Movimento reduzido: estrela parada, so fade.

signal scene_changed(path: String)

enum Phase { IDLE, LOADING, SWAPPING, SETTLING, FADING_OUT }

const BG_TOP := Color("#1A1440")
const BG_BOTTOM := Color("#2A1745")
## Tempo minimo da tela (ms, relogio real) para nao piscar numa troca rapida.
const MIN_SHOW_MS := 450
const FADE_IN := 0.12
const FADE_OUT := 0.3
## Quadros da cena nova atras da tela antes do fade (o primeiro costuma pagar shader e upload de malha).
const SETTLE_FRAMES := 3
## Recursos pesados que as cenas carregam no proprio `_ready` com `load()` (a .tscn em si e minuscula): vao junto em
## segundo plano e ficam presos aqui ate a cena nova assentar, para o `load()` dela sair do cache.
const VILLAGE_DEPS: Array[String] = ["res://worlds/village_v3/village_world.tscn",
	"res://assets/models/environment_v2/wv2_static.glb", "res://assets/models/environment_v2/wv2_kit.glb",
	"res://assets/models/environment_v2/wv3_props.glb", "res://art/sky.gdshader",
	"res://actors/characters/rastro_model.tscn", "res://actors/characters/pico_model.tscn",
	"res://actors/characters/leme_model.tscn"]
const MENU_DEPS: Array[String] = ["res://ui/title/sky_sea.gdshader", "res://ui/brand/logo_h.svg",
	"res://actors/characters/rastro_model.tscn", "res://actors/characters/pico_model.tscn",
	"res://actors/characters/leme_model.tscn"]
const WARM := {
	"res://ui/main_menu.tscn": MENU_DEPS,
	"res://episodes/ep01/v3/ep01_v3_main.tscn": VILLAGE_DEPS,
	"res://episodes/ep01/v3/cutscene/game_intro.tscn": VILLAGE_DEPS,
}

var phase: Phase = Phase.IDLE
var target_path: String = ""
var reduced_motion: bool = false
## Medidas da ultima troca (ms): pedido -> recurso pronto, troca (instanciar + _ready), total ate sumir a tela.
var last_timings: Dictionary = {}

var _root: Control
var _star: LoadingStar
var _started_ms: int = 0
var _loaded_ms: int = 0
var _swap_ms: int = 0
var _settle_left: int = 0
var _alpha: float = 0.0
var _pending: Array[String] = []
var _held: Array[Resource] = []


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "LoadingScreen"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.draw.connect(_draw_bg)
	add_child(_root)
	_star = LoadingStar.new()
	_star.name = "Star"
	_star.set_anchors_preset(Control.PRESET_FULL_RECT)
	_star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_star)
	_root.visible = false
	_set_alpha(0.0)


func is_busy() -> bool:
	return phase != Phase.IDLE


## A tela de carregamento esta na frente (visivel e bloqueando entrada).
func is_showing() -> bool:
	return _root.visible


## O carregador ativo: o autoload `SceneLoader`; se faltar (ex.: `--script` sem autoload), cria um na raiz.
static func instance() -> SceneLoaderService:
	var root := (Engine.get_main_loop() as SceneTree).root
	var n := root.get_node_or_null("SceneLoader") as SceneLoaderService
	if n == null:
		n = SceneLoaderService.new()
		n.name = "SceneLoader"
		root.add_child(n)
	return n


## Atalho usado pelas cenas do jogo no lugar de `change_scene_to_file`.
static func go(path: String) -> bool:
	return instance().change_scene(path)


func star_spin() -> float:
	return _star.spin


## Troca para a cena em `path`. false se ja ha uma troca em andamento ou o caminho nao existe (nada muda).
func change_scene(path: String) -> bool:
	if phase != Phase.IDLE or not ResourceLoader.exists(path):
		if not ResourceLoader.exists(path):
			push_error("SceneLoader: cena inexistente %s" % path)
		return false
	target_path = path
	last_timings = {}
	reduced_motion = Options.reduced_motion()
	_star.reduced_motion = reduced_motion
	_star.spin = 0.0
	_started_ms = Time.get_ticks_msec()
	_loaded_ms = 0
	phase = Phase.LOADING
	_root.visible = true
	_star.visible = true
	# A estrela aparece ja neste quadro; o fundo cobre a cena em FADE_IN (com movimento reduzido tambem, e so fade).
	_set_alpha(maxf(_alpha, 0.35))
	_held.clear()
	_pending.clear()
	for dep: String in WARM.get(path, []):
		if ResourceLoader.exists(dep) and ResourceLoader.load_threaded_request(dep, "", true) == OK:
			_pending.append(dep)
	var err := ResourceLoader.load_threaded_request(path, "PackedScene", true)
	if err != OK:
		push_error("SceneLoader: falha ao pedir %s (%d)" % [path, err])
	print("[RB] loader request %s" % path)
	return true


func _process(delta: float) -> void:
	if phase == Phase.IDLE:
		return
	var real := delta / maxf(Engine.time_scale, 0.0001)
	_star.advance(real)
	match phase:
		Phase.LOADING:
			_set_alpha(minf(1.0, _alpha + real / FADE_IN))
			_collect_deps()
			var status := ResourceLoader.load_threaded_get_status(target_path)
			if status == ResourceLoader.THREAD_LOAD_LOADED and _pending.is_empty() and _loaded_ms == 0:
				_loaded_ms = Time.get_ticks_msec()
			elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				push_error("SceneLoader: carregamento falhou %s" % target_path)
				phase = Phase.FADING_OUT
				return
			# So troca com a tela totalmente opaca e depois do tempo minimo.
			if _loaded_ms > 0 and _alpha >= 1.0 and Time.get_ticks_msec() - _started_ms >= MIN_SHOW_MS:
				phase = Phase.SWAPPING
				_swap.call_deferred()
		Phase.SETTLING:
			_settle_left -= 1
			if _settle_left <= 0:
				_held.clear()
				phase = Phase.FADING_OUT
		Phase.FADING_OUT:
			_set_alpha(_alpha - real / FADE_OUT)
			if _alpha <= 0.0:
				_root.visible = false
				_star.visible = false
				phase = Phase.IDLE
				last_timings["total_ms"] = Time.get_ticks_msec() - _started_ms
				print("[RB] loader done %s %s" % [target_path, last_timings])


## Recolhe as dependencias ja carregadas (falha numa delas nao trava: a cena carrega a sua no `_ready`).
func _collect_deps() -> void:
	for dep: String in _pending.duplicate():
		var st := ResourceLoader.load_threaded_get_status(dep)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			_held.append(ResourceLoader.load_threaded_get(dep))
			_pending.erase(dep)
		elif st != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_pending.erase(dep)


func _swap() -> void:
	var packed := ResourceLoader.load_threaded_get(target_path) as PackedScene
	var t0 := Time.get_ticks_msec()
	var err := get_tree().change_scene_to_packed(packed) if packed != null else ERR_CANT_OPEN
	if err != OK:
		push_error("SceneLoader: troca falhou %s (%d)" % [target_path, err])
	# change_scene_to_packed instancia aqui e troca no fim do quadro; o _ready da cena nova roda nesse fim de quadro.
	await get_tree().process_frame
	_swap_ms = Time.get_ticks_msec() - t0
	last_timings = {"load_ms": _loaded_ms - _started_ms, "swap_ms": _swap_ms}
	_settle_left = SETTLE_FRAMES
	phase = Phase.SETTLING
	scene_changed.emit(target_path)


func _set_alpha(a: float) -> void:
	_alpha = clampf(a, 0.0, 1.0)
	_root.modulate.a = _alpha
	# A estrela fica inteira enquanto o fundo entra (aparece no quadro do clique) e some junto no fade de saida.
	_star.modulate.a = _alpha if phase == Phase.FADING_OUT or phase == Phase.IDLE else 1.0
	_star.visible = _root.visible


func _input(event: InputEvent) -> void:
	# Durante a troca nada passa para a cena de tras (clique duplo nao dispara outra troca).
	if phase != Phase.IDLE and not (event is InputEventMouseMotion):
		get_viewport().set_input_as_handled()


func _draw_bg() -> void:
	var size := _root.size
	var bands := 24
	for i in bands:
		var c := BG_TOP.lerp(BG_BOTTOM, float(i) / float(bands - 1))
		_root.draw_rect(Rect2(0, size.y * i / bands, size.x, size.y / bands + 1.0), c)
