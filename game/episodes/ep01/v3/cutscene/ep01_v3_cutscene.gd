class_name Ep01V3Cutscene
extends Node
## Player de cutscenes na engine (RB-R1 D21). Le `ep01_v3_cutscenes.json` e executa uma cena: planos de camera por
## marcador do mundo + deslocamento (cut, dolly, pan, orbit, com suavizacao smoothstep), atores com clipes do proprio
## modelo (clipe ausente -> `fallback` da ficha ou `idle`, anotado em `fallbacks`), falas por `hud.say(chave)` (voz,
## legenda e retrato pelo HUD) e barras de cinema discretas.
##
## Regras para crianca: pulavel com `interact` so depois de ter sido vista uma vez (por espaco de jogo, G13: `user://slot_<n>.cutscenes.seen.json`);
## movimento reduzido (Options) troca todo movimento por corte no enquadramento final do plano; a entrada fica bloqueada
## durante a cena (so `interact` para pular e `pause` passam); ao sair, quem chamou aponta a camera do jogo para
## `exit_look` (ver Ep01V3Main). A cena sempre termina (tempo da ficha + no maximo TAIL_MAX esperando a fala acabar),
## entao nunca trava o bot.
##
## Barras de cinema: sim, finas (7% da altura em cima e embaixo, azul-marinho do tema a 85%), porque dizem a crianca
## "agora e cena, nao e sua vez" sem texto; ficam abaixo do HUD (camada 9), entao a legenda e o retrato continuam por
## cima. Entram em 0,35 s (instantaneo com movimento reduzido).

signal finished(scene_id: StringName, skipped: bool)
## G21i: entrou no plano `index` (quem montou a cena reage a `stage`, `stage_event` e `hud` da ficha).
signal shot_entered(index: int, shot: Dictionary)

const DATA_PATH := "res://episodes/ep01/v3/ep01_v3_cutscenes.json"
const DEFAULT_SEEN_PATH := "user://slot_1.cutscenes.seen.json"
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
const STORY_MODELS := {&"vendor": "amora_model", &"captain": "captain_model", &"pup": "pup_model", &"radio": "lumi_model"}
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
## G21i: palco extra (Farol7Base) com marcadores proprios (`Base_*`), consultado antes do mundo; null = so o mundo.
var stage: Node3D
## who (tracker, climber, pilot, captain, pup) -> Node3D (MemberActor ou raiz de StoryFigure).
var actors: Dictionary = {}
var reduced_motion: bool = false
var camera: Camera3D
var playing: bool = false
var scene_id: StringName = &""
var skippable: bool = false
var shot_index: int = -1
var time: float = 0.0
## G17: tempo dentro do plano atual (s).
var shot_time: float = 0.0
## G17: a cena foi pedida com a tela de carregamento na frente; o relogio e as falas so comecam quando ela libera.
var waiting_screen: bool = false
## Clipes que caíram no fallback nesta instancia: "who:anim->usado".
var fallbacks: Array[String] = []
var lines_said: Array[String] = []
var shots_played: int = 0
## Chamado a cada quadro da cena (o jogo usa para manter a entrada bloqueada).
var on_step: Callable = Callable()
## Herois voltam ao lugar de antes da cena? Cenas no meio de uma missao (fim de passo) deixam onde o jogo os pos.
var restore_members: bool = true
var _scene: Dictionary = {}
var _shots: Array = []
var _total: float = 0.0
var _starts: Array[float] = []
## G17: duracao efetiva de cada plano (shot_length), calculada no play.
var _durs: Array[float] = []
var _held: Dictionary = {}
## G21i: figurante segurando o trecho que importa do clipe (`hold` da ficha): who -> {node, anim, a, b, until, then}.
var _holds: Dictionary = {}
var _moved: Dictionary = {}
var _bars: CanvasLayer
var _bar_top: ColorRect
var _bar_bottom: ColorRect
## G15: "pular a cena" com o desenho do botao de agir do aparelho em uso.
var _skip_label: GlyphText
## Oclusao (como no CameraRig): camadas do mundo, corpos ignorados e copas das arvores (centro xyz, raio w).
var collision_mask: int = 1
var exclude: Array[RID] = []
var occluders: Array[Vector4] = []
var _probe: SphereShape3D
const TARGET_SHELL := 2.5
## HUD de jogo escondido durante a cena (fica so a legenda e a dica de pular): no -> visivel antes.
const HUD_GAME_NODES: Array[String] = ["TopLeft", "MemberPanel", "PromptPanel", "GlyphBadge"]
## Expressao mantida nos herois durante a cena (G1, RB-R1): `neutra` (boca ja sorri de leve) deixa os olhos abertos e
## as piscadas e sorrisos dos clipes passam. Nao usar `alegre`: nos herois v2 e o sorriso de OLHOS FECHADOS, e como
## `set_expression` soma o peso (maximo) a todo quadro, os olhos ficavam fechados a cena inteira (so a sobrancelha).
const HERO_EXPRESSION := &"neutra"
const HERO_EXPRESSION_WEIGHT := 1.0
var _hud_hidden: Dictionary = {}


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
		total += shot_length(sh as Dictionary)
	return total


## G17: chave da fala do plano ("" sem fala ou fora do catalogo).
static func line_key(sh: Dictionary) -> String:
	var line: Dictionary = sh.get("line", {}) if sh.get("line") is Dictionary else {}
	var key := str(line.get("key", ""))
	return key if key != "" and Loc.has_key(key) else ""


## G17: duracao do audio real da fala (o mesmo take que o HUD toca), sem tocar; 0 se nao ha voz.
static func voice_seconds(key: String) -> float:
	var id := Ep01V3Dialogue.take(key)
	if id == "":
		id = key
	if VoiceCatalog.lookup(id, Loc.language).is_empty():
		return 0.0
	var s := VoiceCatalog.stream_for(id, Loc.language)
	return s.get_length() if s != null else 0.0


## G17: duracao efetiva do plano = max(duracao da ficha, tempo da fala no HUD). O tempo da fala no HUD e
## max(leitura da legenda, voz real + folga), entao o corte nunca chega antes de a voz (e a legenda) acabar e a fala
## do plano seguinte nunca espera na fila: comeca no corte.
static func shot_length(sh: Dictionary) -> float:
	var base := float(sh.get("duration", 0.0))
	var key := line_key(sh)
	if key == "":
		return base
	# Por chave (G20): numa fala de radio soma os cliques de abrir e fechar.
	return maxf(base, Hud.line_seconds(key, voice_seconds(key)))


## G17: quem esta em foco no plano (`focus` da ficha ou o primeiro ator); &"" se o plano nao tem ator.
static func shot_focus(sh: Dictionary) -> StringName:
	if sh.has("focus"):
		return StringName(str(sh["focus"]))
	var list: Array = sh.get("actors", [])
	return StringName(str((list[0] as Dictionary).get("who", ""))) if not list.is_empty() else &""


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


## G13: a proxima consulta rele o arquivo (trocou ou apagou o espaco de jogo).
static func forget_seen_cache() -> void:
	_seen_cache = {}
	_seen_loaded_from = "<nenhum>"


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
	_skip_label = GlyphText.new(26, ThemeV2.PAPER)
	_skip_label.name = "SkipHint"
	_skip_label.alignment = BoxContainer.ALIGNMENT_END
	_skip_label.set_text(Loc.t("ui.cutscene.skip"))
	_bars.add_child(_skip_label)


func _layout_bars(fraction: float) -> void:
	var vp := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1920, 1080)
	var h := vp.y * BAR_FRACTION * clampf(fraction, 0.0, 1.0)
	_bar_top.position = Vector2.ZERO
	_bar_top.size = Vector2(vp.x, h)
	_bar_bottom.position = Vector2(0, vp.y - h)
	_bar_bottom.size = Vector2(vp.x, h)
	_skip_label.position = Vector2(vp.x - 520.0, maxf(4.0, h * 0.5 - 22.0))
	_skip_label.size = Vector2(500.0, 44.0)


## Altura atual de cada barra em pixels (testes/capturas).
func bar_height() -> float:
	return _bar_top.size.y if _bars.visible else 0.0


func skip_hint_visible() -> bool:
	return _bars.visible and _skip_label.visible


func skip_hint() -> GlyphText:
	return _skip_label


# ---------- tocar ----------

## Comeca a cena `id`. false se nao existe, esta desligado ou ja ha uma tocando (nada muda).
func play(id: StringName) -> bool:
	_scene = scene_data(id)
	if playing or _scene.is_empty() or not enabled:
		return false
	scene_id = id
	_shots = _scene.get("shots", [])
	_starts.clear()
	_durs.clear()
	_total = 0.0
	for sh: Variant in _shots:
		_starts.append(_total)
		_durs.append(shot_length(sh as Dictionary))
		_total += _durs[-1]
	skippable = is_seen(id) and bool(_scene.get("skippable_after_first", true))
	time = 0.0
	shot_time = 0.0
	shot_index = -1
	shots_played = 0
	lines_said.clear()
	_held.clear()
	playing = true
	_hide_game_hud()
	if hud != null:
		hud.hide_prompt()
		hud.clear_speech()
	camera.current = true
	_bars.visible = true
	_skip_label.visible = skippable
	_layout_bars(1.0 if reduced_motion else 0.0)
	print("[RB] cutscene start %s skippable=%s" % [id, skippable])
	waiting_screen = not SceneLoaderService.instance().screen_released()
	if not waiting_screen:
		_step(0.0)
	if auto_skip:
		_finish.call_deferred(true)
	return true


func _process(delta: float) -> void:
	if not playing:
		return
	if waiting_screen:
		# G17: o celular segura a tela de carregamento por muito tempo; a cena nao conta tempo nem fala por baixo dela.
		if on_step.is_valid():
			on_step.call()
		_hide_game_hud()
		if not SceneLoaderService.instance().screen_released():
			return
		waiting_screen = false
		print("[RB] cutscene tela liberada %s" % scene_id)
		_step(0.0)
		return
	_step(delta)


func _step(delta: float) -> void:
	time += delta
	if on_step.is_valid():
		on_step.call()
	_hide_game_hud()
	if not reduced_motion:
		_layout_bars(minf(time, BAR_IN) / BAR_IN)
	# G17: relogio por plano, zerado no corte (o HUD conta a fala do mesmo quadro em diante, com os mesmos deltas):
	# o plano acaba no mesmo quadro em que a fala dele acaba, nunca antes.
	shot_time += delta
	if shot_index < 0 and not _shots.is_empty():
		shot_index = 0
		shot_time = 0.0
		_enter_shot(0)
	elif shot_index >= 0 and shot_index < _shots.size() - 1 and shot_time >= _durs[shot_index]:
		shot_index += 1
		shot_time = 0.0
		_enter_shot(shot_index)
	if shot_index >= 0:
		var sh: Dictionary = _shots[shot_index]
		var dur := maxf(_durs[shot_index], 0.001)
		var u := clampf(shot_time / dur, 0.0, 1.0)
		var pose := camera_pose(sh, u)
		camera.global_position = pose[0]
		if (pose[0] as Vector3).distance_to(pose[1]) > 0.01:
			camera.look_at(pose[1], Vector3.UP)
	_hold_clips()
	_hold_ranges()
	if _shots.is_empty() or (shot_index == _shots.size() - 1 and shot_time >= _durs[shot_index]):
		var speaking := hud != null and hud.is_speaking()
		if not speaking or shot_time >= (_durs[shot_index] if shot_index >= 0 else 0.0) + TAIL_MAX:
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
	var id := StringName(str(d.get("marker", "")))
	var m: Node3D = null
	if stage != null and stage.has_method(&"marker"):
		m = stage.call(&"marker", id) as Node3D
	if m == null and world != null:
		m = world.marker(id)
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
	# G21i: antes da pose e dos atores (quem montou a cena pode trazer o palco do plano)
	shot_entered.emit(i, sh)
	if hud != null:
		hud.spotlight_help(str(sh.get("hud", "")) == "help_pulse")
	var cam_from := shot_pose(sh, 0.0)[0]
	_held.clear()
	_holds.clear()
	for a: Variant in sh.get("actors", []):
		_place_actor(a as Dictionary, cam_from, sh)
	var key := line_key(sh)
	if key != "":
		lines_said.append(key)
		if hud != null:
			# G17: a fala do plano comeca no corte; o que restasse da anterior nao a empurra para a fila.
			hud.clear_speech()
			hud.say(key)


func _place_actor(a: Dictionary, cam_from: Vector3, sh: Dictionary) -> void:
	var who := StringName(str(a.get("who", "")))
	var node := actors.get(who) as Node3D
	if (node == null or not is_instance_valid(node)) and STORY_MODELS.has(who) and world != null \
			and ResourceLoader.exists(StoryFigure.DIR % STORY_MODELS[who]):
		var parent: Node = world
		if stage != null and stage.get_node_or_null(^"Actors") != null:
			parent = stage.get_node(^"Actors")
		node = StoryFigure.spawn(parent, STORY_MODELS[who], "Cutscene_" + String(who))
		node.set_meta(&"cutscene_temp", true)
		actors[who] = node
	if node == null or not is_instance_valid(node):
		fallbacks.append("%s:%s->ausente" % [who, a.get("anim", "")])
		return
	var member := node as MemberActor
	# G21i: `seat` = caminho de um no do palco (ex.: Chair/Seat); o figurante vira filho dele e gira junto.
	var seat := str(a.get("seat", ""))
	if member == null and stage != null and seat != "" and stage.get_node_or_null(seat) != null:
		var to := stage.get_node(seat)
		if node.get_parent() != to:
			node.reparent(to, false)
		node.transform = Transform3D.IDENTITY
		node.visible = true
		var seated := resolve_anim(node, StringName(str(a.get("anim", "idle"))), StringName(str(a.get("fallback", "idle"))), who)
		_play_clip(node, seated, StringName(str(a.get("then", "idle"))))
		return
	var stage_actors := stage.get_node_or_null(^"Actors") if stage != null else null
	if member == null and stage_actors != null and stage.is_ancestor_of(node) and node.get_parent() != stage_actors:
		node.reparent(stage_actors, false)  # levantou da cadeira
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
		member.set_expression(HERO_EXPRESSION, HERO_EXPRESSION_WEIGHT)
	else:
		StoryFigure.face(node, face_to)
	var anim := resolve_anim(node, StringName(str(a.get("anim", "idle"))), StringName(str(a.get("fallback", "idle"))), who)
	var hold: Array = a.get("hold", [])
	var cv := _visual(node)
	if member == null and hold.size() == 2 and cv != null and cv.has_animation(anim) and cv.animation_player() != null:
		# G21i: toca o clipe e segura o trecho [a, b] (a == b: congela a pose) ate `hold_until` do plano; depois
		# passa para `then` com blend (ex.: o point fica estendido durante a fala inteira).
		node.set_meta(StoryFigure.LOOP_META, &"")
		cv.play(anim, 1.0, 0.2)
		var then := StringName(str(a.get("then", "idle")))
		_holds[who] = {"node": node, "anim": anim, "a": float(hold[0]), "b": float(hold[1]),
			"until": float(a.get("hold_until", 0.85)), "then": then if cv.has_animation(then) else &"idle"}
		return
	_play_clip(node, anim, StringName(str(a.get("then", "idle"))))
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


## `then` (G21i): clipe de laco depois de um clipe unico no figurante (ex.: wave -> talk).
func _play_clip(node: Node3D, anim: StringName, then: StringName = &"idle") -> void:
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
		var cv := _visual(node)
		StoryFigure.once(node, anim, then if cv != null and cv.has_animation(then) else &"idle")


## Clipes de laco (idle_wheel, wag) seguem tocando no MemberActor, que voltaria ao idle no fim da acao.
func _hold_clips() -> void:
	for who: StringName in _held:
		var m := actors.get(who) as MemberActor
		if m != null and m.model != null and m.model.current_animation() != _held[who]:
			m.play_action(_held[who])


## G21i: mantem os figurantes no trecho `hold` do clipe e solta para `then` (blend 0,35 s) no fim do trecho.
func _hold_ranges() -> void:
	if shot_index < 0:
		return
	var dur := maxf(_durs[shot_index], 0.001)
	for who: StringName in _holds.keys():
		var h: Dictionary = _holds[who]
		var node := h["node"] as Node3D
		var cv := _visual(node) if node != null and is_instance_valid(node) else null
		var ap := cv.animation_player() if cv != null else null
		if ap == null:
			_holds.erase(who)
			continue
		if shot_time >= float(h["until"]) * dur:
			ap.play(String(h["then"]), 0.35)
			node.set_meta(StoryFigure.LOOP_META, h["then"])
			_holds.erase(who)
			continue
		var a := float(h["a"])
		var b := float(h["b"])
		if ap.current_animation == String(h["anim"]) and ap.current_animation_position >= b:
			if b - a < 0.01:
				# congela a pose sem pausar o player (pausado, o visual volta ao idle): volta ao instante a cada quadro
				ap.seek(a, true)
			else:
				ap.seek(a + fmod(ap.current_animation_position - b, b - a), true)


## Trecho segurado agora (testes): who -> clipe, ou vazio.
func holding(who: StringName) -> StringName:
	return StringName((_holds[who] as Dictionary)["anim"]) if _holds.has(who) else &""


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
	waiting_screen = false
	var id := scene_id
	mark_seen(id)
	_restore_actors()
	if hud != null:
		hud.spotlight_help(false)
	_restore_game_hud()
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
			if restore_members:
				(node as MemberActor).teleport(tr.origin)
			(node as MemberActor).set_expression(&"neutra", 1.0)
		else:
			node.global_transform = tr
			StoryFigure.loop(node, &"idle")
		node.visible = bool(saved["v"])
	_moved.clear()
	_held.clear()
	_holds.clear()


## Ponto para onde a camera do jogo deve olhar ao sair da cena atual/ultima.
func exit_point(id: StringName) -> Vector3:
	var s := scene_data(id)
	return point_of(s.get("exit_look", {}))


# ---------- HUD de jogo ----------

func _hide_game_hud() -> void:
	if hud == null:
		return
	for n: String in HUD_GAME_NODES:
		var c := hud.find_child(n, true, false) as CanvasItem
		if c == null:
			continue
		# G21i: no plano com o disco da ajuda em destaque o canto de cima fica (o Hud mostra so o disco nele).
		if n == "TopLeft" and hud.help_spotlit():
			continue
		if not _hud_hidden.has(n):
			_hud_hidden[n] = c.visible
		c.visible = false


func _restore_game_hud() -> void:
	if hud == null:
		return
	for n: String in _hud_hidden:
		var c := hud.find_child(n, true, false) as CanvasItem
		if c != null:
			c.visible = bool(_hud_hidden[n])
	_hud_hidden.clear()


## Algum elemento do HUD de jogo visivel? (testes)
func game_hud_visible() -> bool:
	if hud == null:
		return false
	for n: String in HUD_GAME_NODES:
		var c := hud.find_child(n, true, false) as CanvasItem
		if c != null and c.is_visible_in_tree():
			return true
	return false


# ---------- oclusao ----------

## Pose do plano com a camera trazida para perto do alvo quando parede, telhado ou copa ficam no caminho.
func camera_pose(sh: Dictionary, u: float) -> Array[Vector3]:
	var pose := shot_pose(sh, u)
	var p := avoid(pose[1], pose[0])
	# Puxar para perto nao pode por a camera dentro de algo que o enquadramento da ficha evitava.
	if p != pose[0] and inside_obstacle(p) and not inside_obstacle(pose[0]):
		p = pose[0]
	return [p, pose[1]]


func avoid(from: Vector3, to: Vector3) -> Vector3:
	var seg := to - from
	var dist := seg.length()
	if dist < 0.01 or world == null or not world.is_inside_tree():
		return to
	var dir := seg / dist
	var allowed := dist
	if collision_mask != 0:
		if _probe == null:
			_probe = SphereShape3D.new()
			_probe.radius = 0.2
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = _probe
		# O alvo pode estar dentro da propria estrutura (galeria do farol): ignora os primeiros TARGET_SHELL metros.
		var skip := minf(TARGET_SHELL, dist * 0.5)
		q.transform = Transform3D(Basis(), from + dir * skip)
		q.motion = dir * (dist - skip)
		q.collision_mask = collision_mask
		q.exclude = exclude
		var res := world.get_world_3d().direct_space_state.cast_motion(q)
		if res.size() == 2 and res[1] > 0.0 and res[0] < 1.0:
			allowed = minf(allowed, skip + (dist - skip) * res[0] - 0.08)
	for o in occluders:
		var c := Vector3(o.x, o.y, o.z)
		var oc := from - c
		if oc.length() <= o.w:
			continue
		var b := oc.dot(dir)
		var disc := b * b - (oc.length_squared() - o.w * o.w)
		if disc < 0.0:
			continue
		var t := -b - sqrt(disc)
		if t > 0.0 and t < allowed:
			allowed = t - 0.08
	if allowed >= dist:
		return to
	return from + dir * maxf(allowed, TARGET_SHELL)


## Camera dentro de colisao do mundo ou de uma copa? (testes)
func inside_obstacle(p: Vector3) -> bool:
	for o in occluders:
		if p.distance_to(Vector3(o.x, o.y, o.z)) < o.w:
			return true
	if world == null or not world.is_inside_tree():
		return false
	var q := PhysicsPointQueryParameters3D.new()
	q.position = p
	q.collision_mask = collision_mask
	q.exclude = exclude
	return not world.get_world_3d().direct_space_state.intersect_point(q, 1).is_empty()


## Copas das arvores do kit do mundo (mesma conta do Ep01V3Main.tree_canopies), para quem nao tem o jogo (abertura).
static func canopies_of(w: VillageWorld) -> Array[Vector4]:
	var out: Array[Vector4] = []
	var kit: Dictionary = w.layout.get("kit", {})
	for kind: String in kit:
		if not kind.begins_with("tree_"):
			continue
		var mmi := w.get_node_or_null("Kit/" + kind) as MultiMeshInstance3D
		var box := AABB(Vector3(-1.2, 0, -1.2), Vector3(2.4, 4.0, 2.4))
		if mmi != null and mmi.multimesh != null and mmi.multimesh.mesh != null:
			box = mmi.multimesh.mesh.get_aabb()
		for row: Variant in kit[kind]:
			var r: Array = row
			var sc := float(r[4])
			out.append(Vector4(float(r[0]), float(r[1]) + (box.position.y + box.size.y * 0.68) * sc, float(r[2]),
				maxf(box.size.x, box.size.z) * 0.5 * sc * 0.85))
	return out
