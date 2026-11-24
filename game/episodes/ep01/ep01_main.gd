class_name Ep01Main
extends Node3D
## Cena principal do Episodio 01: monta o mundo, os atores, a camera e o HUD, e liga o EpisodeDirector aos estagios.
## O diretor decide o progresso; os estagios apresentam e enviam eventos por `submit` (SPEC secao 7).

## Emblema opcional coletado (o HUD mostra; nunca bloqueia progresso).
signal collectible_found(count: int, total: int)
## Pose de equipe na troca de integrante: comeca ao confirmar o cartao; ao terminar, o controle passa ao heroi.
signal team_pose_started(member: StringName)
signal team_pose_finished(member: StringName)

const MENU_SCENE := "res://ui/main_menu.tscn"
const IDLE_HINT_SECONDS := 25.0
const TEAM_POSE_SECONDS := 1.2
const TEAM_POSE_ANIMS: Array[StringName] = [&"team_pose", &"celebrate", &"wave"]

## Execucao nova: registro de conclusao sobrevive a recarga da cena (a persistencia em disco e do RB-05).
static var carry_completed: Array[StringName] = []
## Teste/dev: inicia direto neste estado (apos fast_forward pela API do diretor). Vazio = comeco normal.
static var start_state: StringName = &""

## Arquivo do estagio por estado. `return_trip` usa a mesma instancia de `docking`.
const STAGE_DIR := {
	&"arrival": "arrival",
	&"dock_investigation": "dock",
	&"river_search": "river",
	&"island_crossing": "island",
	&"docking": "docking",
	&"return_trip": "docking",
}

var director := EpisodeDirector.new()
var hud: Hud
var audio: AudioDirector
var help_level: int = 0
var camera_rig: CameraRig
var boat: BoatActor
var actors: Dictionary = {}
var stages: Dictionary = {}
var current_stage: StageBase
var controlled_node: Node3D
var world: Node3D
var idle_seconds: float = 0.0
var hint_index: int = 0
var simulating: bool = false
var collectibles: Ep01Collectibles
## Em pose de equipe (controle ainda nao devolvido) e o clipe usado na ultima pose ("" = sem clipe).
var posing: bool = false
var last_pose_anim: StringName = &""

var _current_target: Ep01Interactable
var _pending: Array = []
var _transitioning: bool = false
var _silent: bool = false
var _last_member: StringName = &""


func _ready() -> void:
	name = "Ep01Main"
	director.completed_episodes = carry_completed.duplicate()
	_build_environment()
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	for m: StringName in [&"tracker", &"climber", &"pilot"]:
		var a := MemberActor.new()
		a.setup(m)
		# Nascem longe do mapa: cada estagio reposiciona quem usa (evita atores empilhados na origem).
		a.position = Vector3(500, 5, 500)
		world.add_child(a)
		a.footstep.connect(_on_footstep)
		actors[m] = a
	boat = BoatActor.new()
	world.add_child(boat)
	boat.place(Ep01Layout.BOAT_DOCKED_POS, Ep01Layout.BOAT_DOCKED_HEADING)
	BoatVfx.attach(boat)
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	# Opcoes do jogador valem no episodio mesmo sem passar pela tela-titulo, e mudam na hora (menu de pausa).
	Options.apply_all()
	camera_rig.reduced_motion = Options.reduced_motion()
	Options.signals().changed.connect(_on_option_changed)
	_load_stages()
	collectibles = Ep01Collectibles.new()
	world.add_child(collectibles)
	collectibles.setup(self)
	collectibles.found.connect(func(count: int, total: int) -> void: collectible_found.emit(count, total))
	hud = Hud.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	collectible_found.connect(func(count: int, total: int) -> void: hud.set_collectibles(count, total))
	hud.set_collectibles(Ep01Collectibles.count(), Ep01Collectibles.total(), false)
	_setup_audio()
	_setup_portraits()
	hud.help_requested.connect(_on_help)
	director.state_changed.connect(_on_state_changed)
	director.event_accepted.connect(_on_event_accepted)
	director.event_rejected.connect(func(e: StringName, r: StringName) -> void: print("[RB] rejected %s %s" % [e, r]))
	hud.replay_requested.connect(_on_replay)
	hud.menu_requested.connect(_on_menu)
	hud.resume_requested.connect(_resume)
	hud.pause_requested.connect(_pause)
	var start := String(start_state) if start_state != &"" else _user_arg("--ep01-start")
	if start.is_empty():
		_begin_normal()
	else:
		start_at(StringName(start))
	if _has_flag("--perf-probe"):
		add_child(PerfProbe.new())
	if _has_flag("--ep01-demo") or _has_flag("--ep01-demo-human"):
		var bot := Ep01DemoBot.new()
		bot.main = self
		bot.human = _has_flag("--ep01-demo-human")
		if bot.human:
			bot.timeout_seconds = 1800.0
		bot.finished.connect(func(ok: bool) -> void: get_tree().quit(0 if ok else 1))
		add_child(bot)


func _user_arg(flag: String) -> String:
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with(flag + "="):
			return arg.trim_prefix(flag + "=")
	return ""


func _has_flag(flag: String) -> bool:
	return OS.get_cmdline_user_args().has(flag) or OS.get_cmdline_args().has(flag)


func _build_environment() -> void:
	Atmosphere.build(self)
	add_child(WaterSurface.new())
	Atmosphere.add_vignette(self)


func _load_stages() -> void:
	var cache: Dictionary = {}
	for state: StringName in STAGE_DIR:
		var dir: String = STAGE_DIR[state]
		if cache.has(dir):
			stages[state] = cache[dir]
			continue
		var path := "res://episodes/ep01/stages/%s/%s_stage.gd" % [dir, dir]
		var stage: StageBase
		if ResourceLoader.exists(path):
			stage = (load(path) as GDScript).new() as StageBase
		else:
			stage = PlaceholderStage.new()
		stage.name = "Stage_" + dir
		stage.state_id = state
		world.add_child(stage)
		stage.setup(self)
		cache[dir] = stage
		stages[state] = stage


# ---------- eventos e progresso ----------

func submit(event: StringName, source: StringName, payload: Dictionary = {}) -> Dictionary:
	return director.submit(event, source, payload)


func say_lines(state: StringName, key: String) -> void:
	await hud.say_all(Ep01Content.lines(state, key))


func _on_event_accepted(event: StringName, payload: Dictionary) -> void:
	idle_seconds = 0.0
	hint_index = 0
	print("[RB] event %s %s" % [event, payload])
	help_level = 0
	_event_sound(event)
	_event_feedback(event)


## Retorno visual dos eventos aceitos (game/actors/feedback). Tremor so onde ha impacto; reduced_motion desliga.
func _event_feedback(event: StringName) -> void:
	match event:
		&"buoy_rounded":
			FeedbackFx.ring(world, Ep01Layout.BUOY_POS + Vector3(0, Ep01Layout.WATER_Y + 0.2, 0))
		&"cove_reached":
			FeedbackFx.ring(world, boat.global_position + Vector3(0, 0.2, 0), Color("7af0a0"))
		&"boat_docked":
			FeedbackFx.splash(world, boat.global_position + Vector3(0, Ep01Layout.WATER_Y, 0))
			camera_rig.shake(0.1, 0.3)
		&"departure_confirmed":
			FeedbackFx.splash(world, boat.global_position + Vector3(0, Ep01Layout.WATER_Y, 0))


func _on_state_changed(old: StringName, new: StringName) -> void:
	print("[RB] state %s -> %s" % [old, new])
	if _silent:
		return
	_pending.append([old, new])
	if not _transitioning:
		_run_transitions()


func _run_transitions() -> void:
	_transitioning = true
	while not _pending.is_empty():
		var t: Array = _pending.pop_front()
		await _transition(t[0] as StringName, t[1] as StringName)
	_transitioning = false


func _transition(old: StringName, new: StringName) -> void:
	var prev: StringName = director.ACTIVE_BY_STATE.get(old, &"")
	hud.clear_speech(true)
	set_controlled(null)
	_hide_prompt()
	if stages.has(old):
		(stages[old] as StageBase).exit()
	_enter_stage(new)
	if new == &"complete":
		await hud.wait_silent()
		await get_tree().create_timer(1.0).timeout
		hud.open_complete()
		return
	var next: StringName = director.ACTIVE_BY_STATE.get(new, &"")
	if next != &"":
		await _handoff(prev, next)


func _enter_stage(state: StringName) -> void:
	current_stage = stages.get(state)
	for s: StageBase in _unique_stages():
		s.refresh_world()
	hud.set_objective(Loc.t(Ep01Content.objective_key(state)), Ep01Content.objective_icon(state))
	_apply_audio_zone(state)
	hud.set_skip_hint(false)
	idle_seconds = 0.0
	hint_index = 0
	if current_stage:
		current_stage.enter()


func _unique_stages() -> Array[StageBase]:
	var out: Array[StageBase] = []
	for s: StageBase in stages.values():
		if not out.has(s):
			out.append(s)
	return out


# ---------- troca de integrante ----------

func _handoff(prev: StringName, next: StringName) -> void:
	var focus := current_stage.focus_node(next)
	if prev != &"" and actors.has(prev) and focus != null:
		(actors[prev] as MemberActor).face_point(focus.global_position)
	if focus != null:
		_apply_view()
		camera_rig.follow(focus)
	await get_tree().create_timer(0.9).timeout
	var next_name := Loc.member_name(next)
	var text := Loc.t("ui.swap.confirm", {"name": next_name, "skill": Loc.member_skill(next)})
	if prev != &"":
		text = Loc.t("ui.swap.look", {"name": Loc.member_name(prev), "other": next_name}) + "\n" + text
	hud.open_handoff(text, next)
	print("[RB] handoff_open %s" % next)
	await hud.handoff_confirmed
	await _team_pose(next)
	_give_control(next)


## O proximo heroi faz a pose de equipe (team_pose; senao celebrate/wave) com a camera de frente por ~1,2 s.
## O controle so volta depois; a pressao que confirmou o cartao nao vira uma segunda confirmacao/interacao.
func _team_pose(member: StringName) -> void:
	var a := actors.get(member) as MemberActor
	if a == null:
		return
	posing = true
	last_pose_anim = &""
	team_pose_started.emit(member)
	print("[RB] team_pose %s" % member)
	if a.model != null:
		for anim: StringName in TEAM_POSE_ANIMS:
			if a.model.has_animation(anim):
				last_pose_anim = anim
				a.play_action(anim)
				break
	camera_rig.frame_front(a, a.facing())
	FeedbackFx.sparkle(world, a.global_position + Vector3(0, 1.0, 0))
	await get_tree().create_timer(TEAM_POSE_SECONDS).timeout
	posing = false
	team_pose_finished.emit(member)


func _give_control(member: StringName) -> void:
	_last_member = member
	print("[RB] control %s" % member)
	set_controlled(current_stage.controlled_node(member))
	current_stage.control_started(member)


func set_controlled(node: Node3D) -> void:
	controlled_node = node
	for m: StringName in actors:
		(actors[m] as MemberActor).controlled = (actors[m] == node)
	boat.controlled = (node == boat)
	hud.set_member(director.active_member if node != null else &"")
	if node != null:
		_apply_view()
		camera_rig.follow(node)
	idle_seconds = 0.0


func _apply_view() -> void:
	if current_stage:
		var v := current_stage.camera_view()
		camera_rig.set_view(v.get("offset", camera_rig.offset), v.get("yaw", 0.0), v.get("look", CameraRig.LOOK_Y))


# ---------- inicio ----------

func _begin_normal() -> void:
	_enter_stage(director.state)
	camera_rig.follow(boat, true)


## Atalho de desenvolvimento/verificacao: avanca o diretor pela API publica ate `target` e entrega o controle.
func start_at(target: StringName) -> void:
	_silent = true
	fast_forward(target)
	_silent = false
	_enter_stage(director.state)
	var member: StringName = director.ACTIVE_BY_STATE.get(director.state, &"")
	if member != &"":
		_give_control(member)
	camera_rig.follow(controlled_node if controlled_node else boat, true)


func fast_forward(target: StringName) -> void:
	var script: Array = [
		[&"arrival", &"intro_finished", &"pilot", {}],
		[&"dock_investigation", &"clue_examined", &"tracker", {"clue_id": &"paw_print_bench"}],
		[&"dock_investigation", &"clue_examined", &"tracker", {"clue_id": &"boot_print_bank"}],
		[&"dock_investigation", &"destination_chosen", &"tracker", {"destination": &"bank"}],
		[&"river_search", &"buoy_rounded", &"pilot", {}],
		[&"river_search", &"cove_reached", &"pilot", {}],
		[&"island_crossing", &"foothold_reached", &"climber", {"index": 1}],
		[&"island_crossing", &"foothold_reached", &"climber", {"index": 2}],
		[&"island_crossing", &"foothold_reached", &"climber", {"index": 3}],
		[&"island_crossing", &"line_fixed", &"climber", {}],
		[&"docking", &"boat_docked", &"pilot", {"aligned": true}],
		[&"return_trip", &"departure_confirmed", &"pilot", {}],
	]
	for step: Array in script:
		if director.state == target:
			return
		if director.state == step[0]:
			director.submit(step[1] as StringName, step[2] as StringName, step[3] as Dictionary)


# ---------- interacao contextual ----------

func _process(delta: float) -> void:
	_update_lipsync()
	if audio != null:
		audio.set_engine_rpm(clampf(boat.speed / BoatActor.MAX_SPEED, 0.0, 1.0) if boat.controlled else -1.0)
	for m: StringName in actors:
		(actors[m] as MemberActor).move_yaw = camera_rig.yaw
	if current_stage:
		current_stage.process_stage(delta)
	_update_prompt()
	_update_idle(delta)


func best_interactable() -> Ep01Interactable:
	if controlled_node == null:
		return null
	var best: Ep01Interactable = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(Ep01Interactable.GROUP):
		var it := n as Ep01Interactable
		if it == null or not it.can_use(director.active_member):
			continue
		var d := it.distance_to(controlled_node.global_position)
		if d <= it.radius and d < best_d:
			best = it
			best_d = d
	return best


func _blocked() -> bool:
	return hud.handoff_open or hud.choice_open or hud.pause_open or hud.complete_open


func _update_prompt() -> void:
	var target: Ep01Interactable = null if _blocked() else best_interactable()
	if target == _current_target and (target == null) == (not hud.prompt_visible()):
		return
	_current_target = target
	if target == null:
		_hide_prompt()
	else:
		hud.show_prompt(Loc.t(target.label_key, target.label_params), target.icon)
		if target.action_id != &"jump":
			FeedbackFx.pulse(world, target.global_position)


func _hide_prompt() -> void:
	_current_target = null
	hud.hide_prompt()


func try_interact() -> bool:
	if _blocked() or controlled_node == null:
		return false
	var target := best_interactable()
	if target == null:
		return false
	idle_seconds = 0.0
	if target.action_id != &"jump":
		FeedbackFx.sparkle(world, target.global_position + Vector3(0, 0.3, 0))
	target.trigger(controlled_node)
	return true


func _update_idle(delta: float) -> void:
	if controlled_node == null or _blocked() or hud.is_speaking():
		return
	idle_seconds += delta
	if idle_seconds < IDLE_HINT_SECONDS:
		return
	idle_seconds = 0.0
	var hints := Ep01Content.hints(director.state)
	if hints.is_empty():
		return
	var h: Dictionary = hints[mini(hint_index, hints.size() - 1)]
	hint_index += 1
	hud.say(String(h["key"]), {}, true)
	if String(h.get("kind", "")) == "gesture" and current_stage:
		current_stage.gesture_hint(String(h["key"]))


# ---------- entrada, pausa e fim ----------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed(&"help"):
		get_viewport().set_input_as_handled()
		_on_help()
	elif event.is_action_pressed(&"interact"):
		if try_interact():
			get_viewport().set_input_as_handled()


# ---------- audio e ajuda ----------

func _setup_audio() -> void:
	audio = AudioDirector.new()
	audio.name = "AudioDirector"
	add_child(audio)
	audio.start_ambience()
	# Fala (RB-R1): balbucio dos personagens ou radio de Farol 7 (Piper), com boca sincronizada por visemas.
	hud.voice_hook = func(key: String) -> float:
		var info := audio.play_line(key)
		_speaker_actor = _actor_for_line(key)
		return float(info.get("duration", 0.0))
	hud.voice_stop_hook = func() -> void:
		audio.stop_voice()
		audio.duck_music(false)
	hud.line_started.connect(_on_line_started)
	hud.line_finished.connect(_on_line_finished)
	hud.handoff_confirmed.connect(func() -> void: audio.play_music("team_call", 0.1))
	hud.emotes_hook = func(key: String) -> Array[StringName]: return Ep01Content.line_emotes(key)
	hud.ui_sound.connect(_on_ui_sound)


## Sons da UI do HUD v2. Nomes do HUD -> efeitos do catalogo (os que faltarem sao ignorados pelo AudioDirector).
const UI_SOUNDS := {
	&"focus": "sfx_ui_move", &"confirm": "sfx_ui_confirm", &"pop": "sfx_ui_move",
	&"handoff": "sfx_ui_confirm", &"star": "sfx_clue_found", &"emote": "sfx_ui_move",
}


func _on_ui_sound(sound: StringName) -> void:
	if audio != null:
		audio.play_ui_named(sound)


## Retratos renderizados dos personagens (RB-R1) no HUD e na legenda.
const PORTRAIT_FILES := {
	&"tracker": "rastro", &"climber": "pico", &"pilot": "leme", &"captain": "captain", &"pup": "pup",
}


func _setup_portraits() -> void:
	for member: StringName in PORTRAIT_FILES:
		var path := "res://ui/portraits/%s_neutra.png" % PORTRAIT_FILES[member]
		if ResourceLoader.exists(path):
			hud.set_portrait_texture(member, load(path) as Texture2D)


func _on_footstep(speed: float, pos: Vector3) -> void:
	if audio != null:
		audio.play_footstep(speed, surface_at(pos), pos)


## Piso sob o heroi para o som do passo: madeira no cais e no barco, pedra na rua do porto, areia na ilha, grama no resto.
static func surface_at(pos: Vector3) -> StringName:
	if absf(pos.x) <= 8.2 and pos.z >= -3.2 and pos.z <= 3.2:
		return &"wood"
	if pos.z <= -12.5 and pos.x < 30.0:
		return &"stone"
	if pos.x >= 182.0:
		return &"sand"
	return &"grass"


## Ambiente e musica por trecho do mapa (RB-R1).
const ZONE_BY_STATE := {
	&"arrival": &"dock", &"dock_investigation": &"dock", &"river_search": &"river",
	&"island_crossing": &"island", &"docking": &"island", &"return_trip": &"river", &"complete": &"dock",
}
const MUSIC_BY_STATE := {
	&"river_search": "explore", &"island_crossing": "crossing", &"docking": "explore", &"return_trip": "return",
}


func _apply_audio_zone(state: StringName) -> void:
	if audio == null:
		return
	audio.set_ambience_zone(ZONE_BY_STATE.get(state, &"dock"))
	if MUSIC_BY_STATE.has(state):
		audio.play_music(String(MUSIC_BY_STATE[state]), 2.0)
	elif state == &"complete":
		audio.play_music("victory", 0.2)


# ---------- fala: boca e radio ----------

var _speaker_actor: MemberActor
var _line_key: String = ""


func _actor_for_line(key: String) -> MemberActor:
	var parts := key.split(".")
	if parts.size() >= 3 and actors.has(StringName(parts[2])):
		return actors[StringName(parts[2])] as MemberActor
	return null


func _on_line_started(key: String) -> void:
	_line_key = key


## Depois da fala (balbucio) de um personagem com instrucao, Farol 7 repete pelo radio para quem ainda nao le.
func _on_line_finished() -> void:
	if _speaker_actor != null and _speaker_actor.model != null:
		_speaker_actor.model.set_viseme(&"mouth_A", 0.0)
	_speaker_actor = null
	var radio := Ep01Content.radio_key(_line_key)
	_line_key = ""
	if radio != "" and Loc.has_key(radio):
		hud.say(radio, {}, false, [&"horn"])
	elif not hud.is_speaking() and audio != null:
		audio.duck_music(false)


func _update_lipsync() -> void:
	if audio == null or _speaker_actor == null or _speaker_actor.model == null:
		return
	_speaker_actor.model.set_viseme(&"mouth_A", clampf(audio.current_viseme(), 0.0, 1.0))


func _event_sound(event: StringName) -> void:
	if audio == null:
		return
	match event:
		&"intro_finished":
			audio.play_music("explore", 2.0)
		&"clue_examined":
			audio.play_sfx("sfx_notebook")
			audio.play_sfx("sfx_clue_found")
			if director.clues_found.size() >= 2:
				audio.play_music("discovery", 0.2)
		&"destination_chosen":
			audio.play_sfx("sfx_ui_confirm")
		&"line_fixed":
			audio.play_sfx("sfx_rope_tug")
			get_tree().create_timer(1.4).timeout.connect(func() -> void: audio.play_sfx("sfx_rope_tug"))
		&"boat_docked":
			audio.play_sfx("sfx_hull_bump", boat.global_position)
		&"departure_confirmed":
			pass  # a buzina final e do filhote (DockingStage.pup_on_horn, na fala ep01.return.pup.horn)


## Repetir instrucao (H, botao Y ou toque no botao): 1a vez repete o objetivo e mostra o gesto; depois avanca as dicas.
func _on_help() -> void:
	if controlled_node == null or _blocked():
		return
	idle_seconds = 0.0
	var state := director.state
	var hints := Ep01Content.hints(state)
	if help_level == 0 or hints.is_empty():
		hud.clear_speech(true)
		hud.say(Ep01Content.objective_key(state), {}, true)
		for h: Dictionary in hints:
			if String(h.get("kind", "")) == "gesture" and current_stage:
				current_stage.gesture_hint(String(h["key"]))
				break
	else:
		var h: Dictionary = hints[mini(help_level - 1, hints.size() - 1)]
		hud.say(String(h["key"]), {}, true)
		if String(h.get("kind", "")) == "gesture" and current_stage:
			current_stage.gesture_hint(String(h["key"]))
	help_level += 1
	print("[RB] help level=%d" % help_level)


func _pause() -> void:
	print("[RB] pause")
	get_tree().paused = true
	hud.open_pause()


func _resume() -> void:
	get_tree().paused = false
	hud.close_pause()


func _on_replay() -> void:
	carry_completed = director.completed_episodes.duplicate()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu() -> void:
	print("[RB] back_to_menu")
	carry_completed = director.completed_episodes.duplicate()
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_option_changed(_section: String, key: String, _value: Variant) -> void:
	if key == "reduced_motion" and is_instance_valid(camera_rig):
		camera_rig.reduced_motion = Options.reduced_motion()


func _exit_tree() -> void:
	if Options.signals().changed.is_connected(_on_option_changed):
		Options.signals().changed.disconnect(_on_option_changed)

