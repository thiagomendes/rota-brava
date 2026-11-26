class_name Ep01V3Cutscene
extends Node
## Player de cutscenes na engine (RB-R1 D21). Le `ep01_v3_cutscenes.json` e executa uma cena: planos de camera por
## marcador do mundo + deslocamento (cut, dolly, pan, orbit, com suavizacao smoothstep), atores com clipes do proprio
## modelo (clipe ausente -> `fallback` da ficha ou `idle`, anotado em `fallbacks`), falas por `hud.say(chave)` (voz,
## legenda e retrato pelo HUD) e barras de cinema discretas.
##
## Regras para crianca: pulavel com `interact` so depois de ter sido vista uma vez (`user://cutscenes.seen.json`);
## movimento reduzido (Options) troca todo movimento por corte no enquadramento final do plano; a entrada fica bloqueada
## durante a cena (so `interact` para pular e `pause` passam); ao sair, quem chamou aponta a camera do jogo para
## `exit_look` (ver Ep01V3Main). A cena sempre termina (tempo da ficha + no maximo TAIL_MAX esperando a fala acabar),
## entao nunca trava o bot.
##
## Barras de cinema: sim, finas (7% da altura em cima e embaixo, azul-marinho do tema a 85%), porque dizem a crianca
## "agora e cena, nao e sua vez" sem texto; ficam abaixo do HUD (camada 9), entao a legenda e o retrato continuam por
## cima. Entram em 0,35 s (instantaneo com movimento reduzido).

signal finished(scene_id: StringName, skipped: bool)

const DATA_PATH := "res://episodes/ep01/v3/ep01_v3_cutscenes.json"
const DEFAULT_SEEN_PATH := "user://cutscenes.seen.json"
const SEEN_VERSION := 1
## Espera maxima depois do ultimo plano para a fala terminar (s).
const TAIL_MAX := 3.0
## Dolly sem `to`: aproxima ate esta fracao da distancia ao alvo.
const DOLLY_PUSH := 0.88
## Orbit: arco total do giro em volta do alvo (rad).
const ORBIT_ARC := 0.6
const BAR_FRACTION := 0.07
const BAR_IN := 0.35
const CAMERA_FOV := 50.0
## Efeitos de mundo por cena e plano (indice do plano -> efeito).
## Quem a ficha pede e o jogo nao passou em `actors`: figurante temporario (StoryFigure), removido ao fim da cena.
const STORY_MODELS := {&"vendor": "amora_model", &"captain": "captain_model", &"pup": "pup_model"}
const EFFECTS := {&"nightfall": {1: &"night"}, &"closing": {0: &"festival"}}

## Liga/desliga todas as cenas (a suite desliga por padrao; os testes de cena religam).
static var enabled: bool = true
## Teste/dev: termina cada cena no primeiro quadro (mede o episodio "pulando tudo").
static var auto_skip: bool = false
## Onde ficam as cenas ja vistas; "" = so em memoria (bots de demonstracao).
static var seen_path: String = DEFAULT_SEEN_PATH
static var _seen_cache: Dictionary = {}
static var _seen_loaded_from: String = "<nenhum>"
static var _data: Dictionary = {}

var world: VillageWorld
var hud: Hud
## who (tracker, climber, pilot, captain, pup) -> Node3D (MemberActor ou raiz de StoryFigure).
var actors: Dictionary = {}
var reduced_motion: bool = false
var camera: Camera3D
var playing: bool = false
var scene_id: StringName = &""
var skippable: bool = false
var shot_index: int = -1
var time: float = 0.0
## Clipes que caíram no fallback nesta instancia: "who:anim->usado".
var fallbacks: Array[String] = []
var lines_said: Array[String] = []
var shots_played: int = 0
## Chamado a cada quadro da cena (o jogo usa para manter a entrada bloqueada).
var on_step: Callable = Callable()
var _scene: Dictionary = {}
var _shots: Array = []
var _total: float = 0.0
var _starts: Array[float] = []
var _held: Dictionary = {}
var _moved: Dictionary = {}
var _bars: CanvasLayer
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _skip_label: Label


# ---------- ficha ----------

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed as Dictionary if parsed is Dictionary else {"scenes": []}
	return _data


static func scene_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for s: Variant in data().get("scenes", []):
		out.append(StringName(str((s as Dictionary)["id"])))
	return out


static func scene_data(id: StringName) -> Dictionary:
	for s: Variant in data().get("scenes", []):
		if StringName(str((s as Dictionary)["id"])) == id:
			return s
	return {}


## Cena cujo `when` e exatamente `when` (ex.: "M1.start", "M6.board.done", "episode_start"); &"" se nenhuma.
static func scene_for(when: String) -> StringName:
	for s: Variant in data().get("scenes", []):
		if str((s as Dictionary).get("when", "")) == when:
			return StringName(str((s as Dictionary)["id"]))
	return &""


static func scene_length(id: StringName) -> float:
	var total := 0.0
	for sh: Variant in scene_data(id).get("shots", []):
		total += float((sh as Dictionary).get("duration", 0.0))
	return total


# ---------- vistas ----------

static func _seen() -> Dictionary:
	if _seen_loaded_from != seen_path:
		_seen_loaded_from = seen_path
		_seen_cache = {}
		if seen_path != "" and FileAccess.file_exists(seen_path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(seen_path))
			if parsed is Dictionary and int((parsed as Dictionary).get("version", -1)) == SEEN_VERSION:
				for id: Variant in (parsed as Dictionary).get("seen", []):
					_seen_cache[StringName(str(id))] = true
	return _seen_cache


static func is_seen(id: StringName) -> bool:
	return _seen().has(id)


static func mark_seen(id: StringName) -> void:
	_seen()[id] = true
	if seen_path == "":
		return
	var list: Array = []
	for k: StringName in _seen().keys():
		list.append(String(k))
	list.sort()
	var tmp := seen_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"version": SEEN_VERSION, "seen": list}, "\t"))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(seen_path))


## Esquece as vistas (testes). Apaga o arquivo se houver caminho.
static func reset_seen() -> void:
	_seen_cache = {}
	_seen_loaded_from = seen_path
	if seen_path != "" and FileAccess.file_exists(seen_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(seen_path))


# ---------- montagem ----------

func setup(the_world: VillageWorld, the_hud: Hud, the_actors: Dictionary) -> void:
	world = the_world
	hud = the_hud
	actors = the_actors
	name = "Cutscene"
	camera = Camera3D.new()
	camera.name = "CutsceneCamera"
	camera.fov = CAMERA_FOV
	camera.current = false
	add_child(camera)
	_build_bars()


func _build_bars() -> void:
	_bars = CanvasLayer.new()
	_bars.name = "CinemaBars"
	_bars.layer = 9
	_bars.visible = false
	add_child(_bars)
	_bar_top = ColorRect.new()
	_bar_bottom = ColorRect.new()
	for b: ColorRect in [_bar_top, _bar_bottom]:
		b.color = Color(ThemeV2.NAVY_DEEP, 0.85)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bars.add_child(b)
	_skip_label = Label.new()
	_skip_label.name = "SkipHint"
	_skip_label.text = Loc.t("ui.cutscene.skip")
	_skip_label.add_theme_color_override("font_color", ThemeV2.PAPER)
	_skip_label.add_theme_font_size_override("font_size", 26)
	_skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bars.add_child(_skip_label)


func _layout_bars(fraction: float) -> void:
	var vp := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1920, 1080)
	var h := vp.y * BAR_FRACTION * clampf(fraction, 0.0, 1.0)
	_bar_top.position = Vector2.ZERO
	_bar_top.size = Vector2(vp.x, h)
	_bar_bottom.position = Vector2(0, vp.y - h)
	_bar_bottom.size = Vector2(vp.x, h)
	_skip_label.position = Vector2(vp.x - 520.0, maxf(4.0, h * 0.5 - 18.0))
	_skip_label.size = Vector2(500.0, 36.0)


## Altura atual de cada barra em pixels (testes/capturas).
func bar_height() -> float:
	return _bar_top.size.y if _bars.visible else 0.0


func skip_hint_visible() -> bool:
	return _bars.visible and _skip_label.visible


# ---------- tocar ----------

## Comeca a cena `id`. false se nao existe, esta desligado ou ja ha uma tocando (nada muda).
func play(id: StringName) -> bool:
	_scene = scene_data(id)
	if playing or _scene.is_empty() or not enabled:
		return false
	scene_id = id
	_shots = _scene.get("shots", [])
	_starts.clear()
	_total = 0.0
	for sh: Variant in _shots:
		_starts.append(_total)
		_total += float((sh as Dictionary).get("duration", 0.0))
	skippable = is_seen(id) and bool(_scene.get("skippable_after_first", true))
	time = 0.0
	shot_index = -1
	shots_played = 0
	lines_said.clear()
	_held.clear()
	playing = true
	if hud != null:
		hud.hide_prompt()
		hud.clear_speech()
	camera.current = true
	_bars.visible = true
	_skip_label.visible = skippable
	_layout_bars(1.0 if reduced_motion else 0.0)
	print("[RB] cutscene start %s skippable=%s" % [id, skippable])
	_step(0.0)
	if auto_skip:
		_finish.call_deferred(true)
	return true


func _process(delta: float) -> void:
	if not playing:
		return
	_step(delta)


func _step(delta: float) -> void:
	time += delta
	if on_step.is_valid():
		on_step.call()
	if not reduced_motion:
		_layout_bars(minf(time, BAR_IN) / BAR_IN)
	var idx := _shots.size() - 1
	for i in _starts.size():
		if time < _starts[i] + float((_shots[i] as Dictionary).get("duration", 0.0)):
			idx = i
			break
	if idx != shot_index and idx >= 0:
		shot_index = idx
		_enter_shot(idx)
	if shot_index >= 0:
		var sh: Dictionary = _shots[shot_index]
		var dur := maxf(float(sh.get("duration", 0.0)), 0.001)
		var u := clampf((time - _starts[shot_index]) / dur, 0.0, 1.0)
		var pose := shot_pose(sh, u)
		camera.global_position = pose[0]
		if (pose[0] as Vector3).distance_to(pose[1]) > 0.01:
			camera.look_at(pose[1], Vector3.UP)
	_hold_clips()
	if time >= _total:
		var speaking := hud != null and hud.is_speaking()
		if not speaking or time >= _total + TAIL_MAX:
			_finish(false)


## Posicao e alvo da camera no plano `sh` na fracao `u` (0..1). Com movimento reduzido, sempre o enquadramento final.
func shot_pose(sh: Dictionary, u: float) -> Array[Vector3]:
	var move := str(sh.get("move", "cut"))
	var e := 1.0 if reduced_motion else smoothstep(0.0, 1.0, u)
	var from := point_of(sh.get("from", {}))
	var look := point_of(sh.get("look", {}))
	var pos := from
	var tgt := look
	match move:
		"dolly":
			var to: Vector3 = point_of(sh["to"]) if sh.has("to") else look + (from - look) * DOLLY_PUSH
			pos = from.lerp(to, e)
		"pan":
			if sh.has("look_to"):
				tgt = look.lerp(point_of(sh["look_to"]), e)
		"orbit":
			pos = look + (from - look).rotated(Vector3.UP, ORBIT_ARC * e)
		_:
			pos = from
	if move == "dolly" and sh.has("look_to"):
		tgt = look.lerp(point_of(sh["look_to"]), e)
	return [pos, tgt]


## Marcador do mundo + deslocamento em metros (mundo). Marcador ausente: so o deslocamento.
func point_of(ref: Variant) -> Vector3:
	if not ref is Dictionary:
		return Vector3.ZERO
	var d := ref as Dictionary
	var off := Vector3.ZERO
	var o: Array = d.get("offset", [0, 0, 0])
	if o.size() >= 3:
		off = Vector3(float(o[0]), float(o[1]), float(o[2]))
	var m := world.marker(StringName(str(d.get("marker", "")))) if world != null else null
	return (m.global_position if m != null else Vector3.ZERO) + off


func _enter_shot(i: int) -> void:
	var sh: Dictionary = _shots[i]
	shots_played += 1
	var effects: Dictionary = EFFECTS.get(scene_id, {})
	if effects.has(i) and world != null:
		match effects[i]:
			&"night":
				world.set_night(true)
			&"festival":
				world.set_festival(true)
	var cam_from := shot_pose(sh, 0.0)[0]
	_held.clear()
	for a: Variant in sh.get("actors", []):
		_place_actor(a as Dictionary, cam_from, sh)
	var line: Dictionary = sh.get("line", {}) if sh.get("line") is Dictionary else {}
	var key := str(line.get("key", ""))
	if key != "" and Loc.has_key(key):
		lines_said.append(key)
		if hud != null:
			hud.say(key)


func _place_actor(a: Dictionary, cam_from: Vector3, sh: Dictionary) -> void:
	var who := StringName(str(a.get("who", "")))
	var node := actors.get(who) as Node3D
	if (node == null or not is_instance_valid(node)) and STORY_MODELS.has(who) and world != null \
			and ResourceLoader.exists(StoryFigure.DIR % STORY_MODELS[who]):
		node = StoryFigure.spawn(world, STORY_MODELS[who], "Cutscene_" + String(who))
		node.set_meta(&"cutscene_temp", true)
		actors[who] = node
	if node == null or not is_instance_valid(node):
		fallbacks.append("%s:%s->ausente" % [who, a.get("anim", "")])
		return
	var member := node as MemberActor
	# Quem esta embarcado (M6) fica no barco: so troca o clipe.
	if member == null or member.riding_on == null:
		if not _moved.has(who):
			_moved[who] = {"t": node.global_transform, "v": node.visible}
		var p := point_of(a)
		node.visible = true
		if member != null:
			member.velocity = Vector3.ZERO
			member.teleport(p + Vector3(0, 0.05, 0))
		else:
			node.global_position = p
	var face_to := cam_from
	if str(a.get("anim", "")) == "point" and sh.has("look_to"):
		face_to = point_of(sh["look_to"])
	if member != null:
		member.face_now(face_to)
	else:
		StoryFigure.face(node, face_to)
	var anim := resolve_anim(node, StringName(str(a.get("anim", "idle"))), StringName(str(a.get("fallback", "idle"))), who)
	_play_clip(node, anim)
	if CharacterVisual.LOOPING.has(anim) and anim != &"idle":
		_held[who] = anim


## Clipe pedido se o modelo tem; senao o fallback da ficha; senao `idle` (anotado em `fallbacks`).
func resolve_anim(node: Node3D, anim: StringName, fallback: StringName, who: StringName = &"") -> StringName:
	var cv := _visual(node)
	if cv == null or cv.has_animation(anim):
		return anim
	var use := fallback if cv.has_animation(fallback) else &"idle"
	fallbacks.append("%s:%s->%s" % [who, anim, use])
	return use


static func _visual(node: Node3D) -> CharacterVisual:
	if node is MemberActor:
		return (node as MemberActor).model
	return StoryFigure.visual(node)


func _play_clip(node: Node3D, anim: StringName) -> void:
	if node is MemberActor:
		var m := node as MemberActor
		if anim == &"idle":
			if m.model != null:
				m.model.play(&"idle")
		else:
			m.play_action(anim)
	elif anim == &"idle" or CharacterVisual.LOOPING.has(anim):
		StoryFigure.loop(node, anim)
	else:
		StoryFigure.once(node, anim)


## Clipes de laco (idle_wheel, wag) seguem tocando no MemberActor, que voltaria ao idle no fim da acao.
func _hold_clips() -> void:
	for who: StringName in _held:
		var m := actors.get(who) as MemberActor
		if m != null and m.model != null and m.model.current_animation() != _held[who]:
			m.play_action(_held[who])


## Pula a cena (so se pulavel). true se pulou.
func skip() -> bool:
	if not playing or not skippable:
		return false
	_finish(true)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not playing or event.is_echo():
		return
	if event.is_action_pressed(&"pause"):
		return
	if event.is_action_pressed(&"interact"):
		skip()
	# Durante a cena nada mais passa (pular e pausa sao as excecoes).
	if event is InputEventAction or event is InputEventKey or event is InputEventJoypadButton \
			or event is InputEventMouseButton or event is InputEventScreenTouch:
		get_viewport().set_input_as_handled()


func _finish(skipped: bool) -> void:
	if not playing:
		return
	playing = false
	var id := scene_id
	mark_seen(id)
	_restore_actors()
	if hud != null:
		hud.clear_speech()
	_bars.visible = false
	camera.current = false
	print("[RB] cutscene end %s skipped=%s t=%.2f" % [id, skipped, time])
	finished.emit(id, skipped)


func _restore_actors() -> void:
	for who: StringName in actors.keys():
		var n := actors[who] as Node3D
		if n != null and is_instance_valid(n) and n.get_meta(&"cutscene_temp", false):
			actors.erase(who)
			_moved.erase(who)
			n.queue_free()
	for who: StringName in _moved:
		var node := actors.get(who) as Node3D
		if node == null or not is_instance_valid(node):
			continue
		var saved: Dictionary = _moved[who]
		var tr: Transform3D = saved["t"]
		if node is MemberActor:
			(node as MemberActor).teleport(tr.origin)
		else:
			node.global_transform = tr
			StoryFigure.loop(node, &"idle")
		node.visible = bool(saved["v"])
	_moved.clear()
	_held.clear()


## Ponto para onde a camera do jogo deve olhar ao sair da cena atual/ultima.
func exit_point(id: StringName) -> Vector3:
	var s := scene_data(id)
	return point_of(s.get("exit_look", {}))
