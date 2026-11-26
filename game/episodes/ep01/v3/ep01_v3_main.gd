class_name Ep01V3Main
extends Node3D
## Episodio 01 v3 (RB-R1 E1/E4): o Ep01 jogavel na vila v2.1 (game/worlds/village_v3/village_world.tscn), com os herois
## v2, a camera baixa da vitrine e o barco v2 atracado no M6. O fluxo antigo (porto, rio, ilha, volta) segue em
## episodes/ep01/ep01_main.tscn, fora do fluxo do jogo (cenas e testes guardados).
##
## Missoes M0-M8 em ep01_v3_missions.json no formato de game/systems/mission (Mission). M1-M4 (E4, Ep01V3Land) e M5-M8
## (E5, Ep01V3Late, que estende a Land) sao reais: montam os pontos de acao e informam `notify_mission`. M0 segue
## "chegar ao marcador" (cena de chegada).
## Aqui ficam: acao contextual (`interact`), troca de heroi contextual (cartao + pose de equipe), ajuda em 3 degraus
## (MissionHelp: gesto, Farol 7 no radio, seta), emblemas por missao, objetivo por icone do passo, salvamento em user://
## e o trio que acompanha o heroi em controle.

signal mission_started(mission_id: StringName)
signal mission_completed(mission_id: StringName)
signal episode_completed

const WORLD_SCENE := "res://worlds/village_v3/village_world.tscn"
const MISSIONS_PATH := "res://episodes/ep01/v3/ep01_v3_missions.json"
const MENU_SCENE := "res://ui/main_menu.tscn"
const EPISODE_ID := &"ep01"
const HEROES: Array[StringName] = [&"tracker", &"climber", &"pilot"]
## Trio no M0: Rastro no marcador; Pico e Leme ao lado dele (o mundo tem um marcador so para o M0).
const TRIO_OFFSETS := {&"tracker": Vector3.ZERO, &"climber": Vector3(1.1, 0, 0.5), &"pilot": Vector3(-1.1, 0, 0.5)}
## Distancia vertical maxima para contar "chegou" (andares diferentes nao contam).
const REACH_DY := 1.5
const PORTRAIT_FILES := {&"tracker": "rastro", &"climber": "pico", &"pilot": "leme"}
const TEAM_POSE_SECONDS := 1.2
const TEAM_POSE_ANIMS: Array[StringName] = [&"team_pose", &"celebrate", &"wave"]
const GESTURE_ANIMS: Array[StringName] = [&"point", &"wave"]
## Distancia vertical maxima para usar um ponto de acao (o topo do galpao nao serve a quem esta no chao).
const INTERACT_DY := 1.0
## Seguidores (F1): longe demais (preso atras de algo), reaparecem perto do lider fora da vista da camera. Desistido
## (`gave_up`) e fora da vista ha GAVE_UP_HIDDEN s, reaparece tambem mais perto que FOLLOW_FAR.
const FOLLOW_FAR := 9.0
const GAVE_UP_HIDDEN := 2.0
## C2: zonas de subida (pulo livre bloqueado; quem sobe e o Pico pela acao da missao). Marcador -> raio (m) do
## cilindro, cobrindo a estrutura e ~1,5 m de corrida antes da borda (pulo correndo avanca ~1,3 m). Tabela de degraus
## do ticket RB-R1: chafariz M3 (centro -22,8; 3,6, anel r 2,08), galpao M2, caixotes/toldo/telhado M5, farol M7.
const CLIMB_ZONES := {
	&"M3_UpperBasin": 3.9,
	&"M2_ShedStep_1": 2.2, &"M2_ShedStep_2": 2.2, &"M2_ShedTop": 2.6,
	&"M5_Crates": 2.2, &"M5_Awning": 2.4, &"M5_ShedRoof": 3.4,
	&"M7_StairStep": 2.2, &"M7_StairBase": 2.4, &"M7_Landing_1": 3.0, &"M7_Gallery": 3.6,
}

## Teste/dev: missao inicial (vazio = M0, ou a do salvo). Salvamento: o jogo real grava e le em user:// (MissionSave);
## vazio = nao salva nem le (testes). Os bots de demonstracao (--ep01-demo*) comecam do zero e nao gravam.
static var start_mission: StringName = &""
## F1: seguidores ligados (cenas desligam com `set_followers_enabled(false)`); tempo de cada um desistido fora da vista.
var followers_enabled: bool = true
var _hidden_stuck: Dictionary = {}
static var save_path: String = MissionSave.DEFAULT_PATH

var world: VillageWorld
var camera_rig: CameraRig
var boat: BoatActor
var hud: Hud
var audio: AudioDirector
var actors: Dictionary = {}
var controlled_node: Node3D
var active_member: StringName = &"tracker"
var missions: Array[Mission] = []
## Dados extras do JSON por id (radius, camera_yaw, icon).
var mission_data: Dictionary = {}
var current: Mission
var complete: bool = false
var land: Ep01V3Late
var help: MissionHelp
var posing: bool = false
var emblems_found: int = 0
var emblems_total: int = 0
var arrow: Node3D
var _save: String = ""
var _pending_switch: StringName = &""
var _current_target: Ep01Interactable
var _clock: float = 0.0


func _ready() -> void:
	name = "Ep01V3Main"
	world = (load(WORLD_SCENE) as PackedScene).instantiate() as VillageWorld
	world.name = "World"
	add_child(world)
	for m: StringName in HEROES:
		var a := MemberActor.new()
		a.setup(m)
		world.add_child(a)
		a.footstep.connect(_on_footstep)
		actors[m] = a
	_place_trio()
	_build_climb_zones()
	boat = BoatActor.new()
	world.add_child(boat)
	var berth := world.marker(&"M6_BoatStart")
	boat.place(berth.global_position, berth.global_rotation.y)
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	camera_rig.set_low_view(0.0)
	_setup_camera_avoidance()
	Options.apply_all()
	camera_rig.reduced_motion = Options.reduced_motion()
	hud = Hud.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	for member: StringName in PORTRAIT_FILES:
		var path := "res://ui/portraits/%s_neutra.png" % PORTRAIT_FILES[member]
		if ResourceLoader.exists(path):
			hud.set_portrait_texture(member, load(path) as Texture2D)
	hud.pause_requested.connect(_pause)
	hud.resume_requested.connect(_resume)
	hud.menu_requested.connect(_on_menu)
	hud.replay_requested.connect(_on_replay)
	audio = AudioDirector.new()
	audio.name = "AudioDirector"
	add_child(audio)
	audio.bind_episode_music(self)
	audio.start_ambience()
	audio.set_ambience_zone(&"dock")
	_setup_speech()
	hud.handoff_confirmed.connect(_on_handoff_confirmed)
	land = Ep01V3Late.new()
	add_child(land)
	land.setup(self)
	_build_arrow()
	help = MissionHelp.new()
	help.reduced_motion = Options.reduced_motion()
	help.gesture_hint.connect(_on_gesture_hint)
	help.radio_hint.connect(_on_radio_hint)
	help.pointer_hint.connect(_on_pointer_hint)
	help.cleared.connect(_hide_arrow)
	_load_missions()
	set_controlled(actors[active_member])
	camera_rig.follow(controlled_node, true)
	var demo := _has_flag("--ep01-demo") or _has_flag("--ep01-demo-human")
	_save = "" if demo else save_path
	var first := start_mission
	if _user_arg("--ep01v3-mission") != "":
		first = StringName(_user_arg("--ep01v3-mission"))
	if _save != "":
		var resumed := MissionSave.load_into(_save, EPISODE_ID, missions)
		if resumed != &"" and first == &"":
			first = resumed
	emblems_found = 0
	for m in missions:
		emblems_found += m.found_emblems.size()
	hud.set_collectibles(emblems_found, emblems_total, false)
	if first != &"" and first != &"M0":
		_place_trio_at(land.start_position(first))
	_start_mission(_index_of(first) if first != &"" else 0)
	_apply_dev_args()
	if demo:
		var bot := Ep01V3Bot.new()
		bot.main = self
		bot.finished.connect(func(ok: bool) -> void: get_tree().quit(0 if ok else 1))
		add_child(bot)


## Camera desvia de paredes, telhados e troncos (camada 1) e das copas das arvores; paredes invisiveis nao contam.
func _setup_camera_avoidance() -> void:
	camera_rig.orbit_enabled = true
	camera_rig.collision_mask = 1
	for path: String in ["Collision/WaterLimits", "Collision/MapBounds", "Collision/AccessRamps"]:
		var b := world.get_node_or_null(path) as CollisionObject3D
		if b != null:
			camera_rig.exclude.append(b.get_rid())
	camera_rig.occluders = tree_canopies()


## Copas das arvores do kit como esferas (centro, raio), da caixa da malha de cada tipo e do layout do mundo.
func tree_canopies() -> Array[Vector4]:
	var out: Array[Vector4] = []
	var kit: Dictionary = world.layout.get("kit", {})
	for kind: String in kit:
		if not kind.begins_with("tree_"):
			continue
		var mmi := world.get_node_or_null("Kit/" + kind) as MultiMeshInstance3D
		var box := AABB(Vector3(-1.2, 0, -1.2), Vector3(2.4, 4.0, 2.4))
		if mmi != null and mmi.multimesh != null and mmi.multimesh.mesh != null:
			box = mmi.multimesh.mesh.get_aabb()
		for row: Variant in kit[kind]:
			var r: Array = row
			var s := float(r[4])
			var radius := maxf(box.size.x, box.size.z) * 0.5 * s * 0.85
			var cy := float(r[1]) + (box.position.y + box.size.y * 0.68) * s
			out.append(Vector4(float(r[0]), cy, float(r[2]), radius))
	return out


## Dev/captura: --ep01v3-at=<marcador> poe o trio junto do marcador; --ep01v3-yaw=<graus> gira a camera baixa;
## --ep01v3-mission=<id> comeca na missao; --ep01v3-help=<1..3> forca o degrau de ajuda.
func _apply_dev_args() -> void:
	var at := _user_arg("--ep01v3-at")
	if at != "" and world.marker(StringName(at)) != null:
		var p := world.marker(StringName(at)).global_position
		for m: StringName in HEROES:
			(actors[m] as MemberActor).teleport(p + (TRIO_OFFSETS[m] as Vector3) + Vector3(0, 0.05, 0))
	var yaw := _user_arg("--ep01v3-yaw")
	if yaw != "":
		camera_rig.set_low_view(deg_to_rad(float(yaw)))
		for m: StringName in HEROES:
			var a := actors[m] as MemberActor
			a.face_now(a.global_position + Basis(Vector3.UP, camera_rig.yaw) * Vector3(0, 0, 3))
	camera_rig.follow(controlled_node, true)
	var hl := _user_arg("--ep01v3-help")
	if hl != "":
		for i in clampi(int(hl), 0, 3):
			help_now()


func _user_arg(flag: String) -> String:
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with(flag + "="):
			return arg.trim_prefix(flag + "=")
	return ""


func _has_flag(flag: String) -> bool:
	return OS.get_cmdline_user_args().has(flag) or OS.get_cmdline_args().has(flag)


func _place_trio() -> void:
	var start := world.marker(&"M0_RastroStart")
	for m: StringName in HEROES:
		var a := actors[m] as MemberActor
		a.teleport(start.global_position + (TRIO_OFFSETS[m] as Vector3) + Vector3(0, 0.05, 0))
		a.face_now(world.marker(&"M0_BoatDocked").global_position)


## Retomada: trio junto no ponto onde a missao anterior terminou.
func _place_trio_at(p: Vector3) -> void:
	if p == Vector3.INF:
		return
	for m: StringName in HEROES:
		(actors[m] as MemberActor).teleport(p + (TRIO_OFFSETS[m] as Vector3) + Vector3(0, 0.05, 0))


# ---------- missoes ----------

func _load_missions() -> void:
	missions = Mission.load_list(MISSIONS_PATH)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MISSIONS_PATH))
	for d: Variant in (parsed as Dictionary).get("missions", []):
		var dd := d as Dictionary
		mission_data[StringName(str(dd["id"]))] = dd
	emblems_total = 0
	for m in missions:
		m.completed.connect(_on_mission_completed)
		m.hero_switch_requested.connect(_on_switch_requested)
		m.emblem_found.connect(_on_emblem_found)
		m.step_started.connect(_on_step_started)
		m.step_done.connect(func(_i: StringName, _n: int, _s: StringName) -> void: _hide_arrow())
		emblems_total += m.emblems.size()


func _index_of(id: StringName) -> int:
	for i in missions.size():
		if missions[i].id == id:
			return i
	return 0


func _start_mission(index: int) -> void:
	if index >= missions.size():
		_finish_episode()
		return
	current = missions[index]
	land.build(current.id)
	var data: Dictionary = mission_data.get(current.id, {})
	hud.set_objective(Loc.t(String(current.title_key)), StringName(str(data.get("icon", "notebook"))))
	help.attach(current)
	current.start(active_member)
	land.refresh()
	if data.has("camera_yaw"):
		camera_rig.set_low_view(deg_to_rad(float(data["camera_yaw"])))
	for k in Ep01V3Dialogue.start_lines(current.id):
		say(k)
	print("[RB] v3 mission %s" % current.id)
	mission_started.emit(current.id)


## Marcador alvo do passo atual (null fora de missao).
func target_marker() -> Marker3D:
	if current == null or not current.is_active():
		return null
	return world.marker(StringName(current.current_step().get("target", &"")))


## O que avanca a missao agora: ponto de acao da Ep01V3Land (M1-M4) ou o marcador do passo (provisorias).
func help_target() -> Node3D:
	if current == null or not current.is_active():
		return null
	if land.handles(current.id):
		return land.help_target()
	return target_marker()


func target_radius() -> float:
	return float((mission_data.get(current.id, {}) as Dictionary).get("radius", 1.2)) if current != null else 0.0


## O jogo informa acontecimentos da missao atual (ex.: &"piece_freed").
func notify_mission(event: StringName) -> bool:
	if current == null:
		return false
	return current.notify(event, active_member)


func _on_mission_completed(id: StringName) -> void:
	print("[RB] v3 mission_done %s" % id)
	_hide_arrow()
	if controlled_node != null:
		FeedbackFx.sparkle(world, controlled_node.global_position + Vector3(0, 1.0, 0))
	if _save != "":
		MissionSave.save(_save, EPISODE_ID, missions)
	for k in Ep01V3Dialogue.done_lines(id):
		say(k)
	mission_completed.emit(id)
	_start_mission.call_deferred(_index_of(id) + 1)


func _finish_episode() -> void:
	land.build(&"")
	current = null
	complete = true
	world.set_festival(true)
	print("[RB] v3 complete")
	hud.set_complete_emblems(land.emblems_by_hero(missions))
	episode_completed.emit()
	hud.open_complete()


func _physics_process(_delta: float) -> void:
	_update_followers()
	if controlled_node == null or current == null:
		return
	if land.handles(current.id):
		# Pontos automaticos (pegadinhas): basta passar por cima.
		if not blocked():
			for k: StringName in land.spots.keys():
				var it := land.spots.get(k) as Ep01Interactable
				if it != null and it.get_meta(&"auto", false) and _usable(it) \
						and it.distance_to(controlled_node.global_position) <= it.radius:
					it.trigger(controlled_node)
		return
	var t := target_marker()
	if t == null:
		return
	var d := t.global_position - controlled_node.global_position
	if absf(d.y) <= REACH_DY and Vector2(d.x, d.z).length() <= target_radius():
		notify_mission(&"marker_reached")


func _process(delta: float) -> void:
	_clock += delta
	for m: StringName in actors:
		(actors[m] as MemberActor).move_yaw = camera_rig.yaw
	_update_prompt()
	if current != null and current.is_active() and not blocked():
		help.tick(delta)
	if arrow.visible:
		var t := help_target()
		if t == null:
			_hide_arrow()
		else:
			arrow.global_position = t.global_position + Vector3(0, 2.0 + 0.15 * sin(_clock * 4.0), 0)


# ---------- acao contextual ----------

func blocked() -> bool:
	return hud.handoff_open or hud.pause_open or hud.complete_open or posing or land.busy or controlled_node == null


func _usable(it: Ep01Interactable) -> bool:
	if it == null or not is_instance_valid(it) or it.is_queued_for_deletion() or not it.can_use(active_member):
		return false
	return absf(it.global_position.y - controlled_node.global_position.y) <= INTERACT_DY


## Ponto de acao ao alcance do heroi em controle (o mais perto); nunca os automaticos.
func best_interactable() -> Ep01Interactable:
	if controlled_node == null:
		return null
	var best: Ep01Interactable = null
	var best_d := INF
	for k: StringName in land.spots.keys():
		var it := land.spots.get(k) as Ep01Interactable
		if it == null or it.get_meta(&"auto", false) or not _usable(it):
			continue
		var d := it.distance_to(controlled_node.global_position)
		if d <= it.radius and d < best_d:
			best = it
			best_d = d
	return best


func _update_prompt() -> void:
	var target: Ep01Interactable = null if blocked() else best_interactable()
	if target == _current_target and (target == null) == (not hud.prompt_visible()):
		return
	_current_target = target
	if target == null:
		hud.hide_prompt()
	else:
		hud.show_prompt(Loc.t(target.label_key), target.icon)
		FeedbackFx.pulse(world, target.global_position)


func try_interact() -> bool:
	if blocked():
		return false
	var target := best_interactable()
	if target == null:
		return false
	help.reset()
	FeedbackFx.sparkle(world, target.global_position + Vector3(0, 0.3, 0))
	target.trigger(controlled_node)
	return true


func find_emblem(emblem_id: StringName) -> bool:
	return current != null and current.find_emblem(emblem_id)


func _on_emblem_found(_mission: StringName, emblem_id: StringName, _found: int, _total: int) -> void:
	emblems_found += 1
	print("[RB] v3 emblem %s %d/%d" % [emblem_id, emblems_found, emblems_total])
	hud.set_collectibles(emblems_found, emblems_total)
	audio.play_badge_sting()


## Objetivo por icone: o icone do cartao segue o passo atual (pata, corda, folha, leme...).
func _on_step_started(_mission: StringName, _index: int, _step: StringName) -> void:
	var s := current.current_step() if current != null else {}
	var icon: StringName = s.get("icon", &"")
	if icon != &"" and IconView.has_icon(icon):
		hud.set_objective(Loc.t(String(current.title_key)), icon)


func say(key: String) -> void:
	if Loc.has_key(key):
		hud.say(key)


# ---------- troca de heroi contextual ----------

func _on_switch_requested(_mission: StringName, hero: StringName, _icon: StringName) -> void:
	if hero == active_member or not actors.has(hero):
		return
	_pending_switch = hero
	_open_switch.call_deferred()


func _open_switch() -> void:
	if _pending_switch == &"" or hud.handoff_open:
		return
	var hero := _pending_switch
	var text := Loc.t("ui.swap.look", {"name": Loc.member_name(active_member), "other": Loc.member_name(hero)}) + "\n" \
		+ Loc.t("ui.swap.confirm", {"name": Loc.member_name(hero), "skill": Loc.member_skill(hero)})
	hud.hide_prompt()
	_current_target = null
	(actors[active_member] as MemberActor).face_point((actors[hero] as MemberActor).global_position)
	hud.open_handoff(text, hero)
	print("[RB] v3 handoff_open %s" % hero)


func _on_handoff_confirmed() -> void:
	var hero := _pending_switch
	_pending_switch = &""
	if hero == &"":
		return
	var a := actors[hero] as MemberActor
	var lead := controlled_node as MemberActor
	if lead != null and a.global_position.distance_to(lead.global_position) > 4.0 and lead.is_on_floor():
		a.teleport(lead.global_position + Basis(Vector3.UP, camera_rig.yaw) * Vector3(1.0, 0.05, 0.6))
	posing = true
	active_member = hero
	set_controlled(a)
	for anim: StringName in TEAM_POSE_ANIMS:
		if a.model != null and a.model.has_animation(anim):
			a.play_action(anim)
			break
	FeedbackFx.sparkle(world, a.global_position + Vector3(0, 1.0, 0))
	audio.play_hero_switch_sting()
	if current != null:
		say(Ep01V3Dialogue.switch_line(current.id, hero))
	print("[RB] v3 control %s" % hero)
	await get_tree().create_timer(TEAM_POSE_SECONDS).timeout
	if not is_inside_tree():
		return
	posing = false
	if current != null:
		current.set_active_hero(hero)
	land.refresh()


func _update_followers() -> void:
	var lead := controlled_node as MemberActor
	var dt := get_physics_process_delta_time()
	for m: StringName in actors:
		var a := actors[m] as MemberActor
		# F1: o ator e o dono unico do proprio movimento de seguidor (formacao, parada, desistencia); aqui so liga o modo
		# e decide o teleporte. Embarcados (M6) nao seguem nem sao seguidos: o barco leva quem esta nele.
		a.follow_on = followers_enabled and lead != null and a != lead and lead.riding_on == null
		if not a.follow_on or a.airborne or a.riding_on != null:
			_hidden_stuck[m] = 0.0
			continue
		var d := lead.global_position - a.global_position
		d.y = 0.0
		var hidden_for := 0.0
		if a.gave_up and not in_camera_view(a.global_position):
			hidden_for = float(_hidden_stuck.get(m, 0.0)) + dt
		_hidden_stuck[m] = hidden_for
		var far := d.length() > FOLLOW_FAR
		if (far or hidden_for >= GAVE_UP_HIDDEN) and lead.is_on_floor() and not lead.airborne:
			var to: Variant = follower_teleport_point(lead, a, m)
			if to != null:
				a.teleport(to as Vector3)
				_hidden_stuck[m] = 0.0


## Contrato para cenas (cutscenes): false desliga o modo seguidor e o teleporte dos seguidores ate voltar a true.
func set_followers_enabled(on: bool) -> void:
	followers_enabled = on
	for m: StringName in actors:
		var a := actors[m] as MemberActor
		if not on:
			a.follow_on = false
			a.velocity = Vector3.ZERO
		_hidden_stuck[m] = 0.0


## F1: algum ponto do corpo (pes, peito, cabeca, com a largura da capsula) dentro do enquadramento da camera?
func in_camera_view(feet: Vector3) -> bool:
	var cam := camera_rig.camera if camera_rig != null else null
	if cam == null or not cam.is_inside_tree():
		return false
	var right := cam.global_transform.basis.x
	right.y = 0.0
	right = right.normalized() * (MemberActor.CAPSULE_RADIUS + 0.15)
	for h: float in [0.05, 0.75, 1.5]:
		for off: Vector3 in [Vector3.ZERO, right, -right]:
			if cam.is_position_in_frustum(feet + off + Vector3(0, h, 0)):
				return true
	return false


## Destino do teleporte de um seguidor (F1): em aneis em volta do lider, so pontos FORA do frustum da camera, com chao
## livre e linha reta ate o lider sem parede (`slot_clear`); prefere o mais perto e o lado do seguidor. null: nenhum
## lugar fora da vista serve, e o seguidor espera (nunca aparece na frente do jogador).
func follower_teleport_point(lead: MemberActor, a: MemberActor, m: StringName) -> Variant:
	var cam_basis := Basis(Vector3.UP, camera_rig.yaw)
	var side := signf((TRIO_OFFSETS[m] as Vector3).x)
	for radius: float in [1.6, 2.4, 3.4, 4.6, 6.0]:
		for k: int in 16:
			# Comeca atras do lider na vista (-Z da camera) e abre para o lado do seguidor, alternando.
			var step := (k + 1) / 2
			var ang := PI + side * (1.0 if k % 2 == 1 else -1.0) * step * TAU / 16.0
			var p := lead.global_position + cam_basis * (Vector3(0, 0, radius).rotated(Vector3.UP, ang))
			if in_camera_view(p):
				continue
			if a.slot_clear(lead.global_position, p):
				return p + Vector3(0, 0.05, 0)
	return null


## Zonas de subida (camada MemberActor.CLIMB_ZONE_LAYER): Area3D com cilindro em volta das estruturas das missoes.
func _build_climb_zones() -> void:
	var root := Node3D.new()
	root.name = "ClimbZones"
	world.add_child(root)
	for mk: StringName in CLIMB_ZONES:
		var marker := world.marker(mk)
		if marker == null:
			continue
		var area := Area3D.new()
		area.name = "Zone_" + String(mk)
		area.collision_layer = MemberActor.CLIMB_ZONE_LAYER
		area.collision_mask = 0
		area.monitoring = false
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = float(CLIMB_ZONES[mk])
		cyl.height = 12.0
		shape.shape = cyl
		area.add_child(shape)
		root.add_child(area)
		area.global_position = Vector3(marker.global_position.x, marker.global_position.y, marker.global_position.z)


# ---------- ajuda em 3 degraus ----------

func _build_arrow() -> void:
	arrow = Ep01V3Pieces.help_arrow(self)
	arrow.visible = false


func _hide_arrow() -> void:
	if arrow != null:
		arrow.visible = false


func _on_gesture_hint(_target: StringName, _key: StringName) -> void:
	var t := help_target()
	var a := controlled_node as MemberActor
	if t == null or a == null:
		return
	print("[RB] v3 help gesture")
	a.face_point(t.global_position)
	for anim: StringName in GESTURE_ANIMS:
		if a.model != null and a.model.has_animation(anim):
			a.play_action(anim)
			break
	FeedbackFx.pulse(world, t.global_position)


func _on_radio_hint(key: StringName) -> void:
	print("[RB] v3 help radio %s" % key)
	if key != &"" and Loc.has_key(String(key)):
		hud.clear_speech(true)
		hud.say(String(key), {}, true)


func _on_pointer_hint(_target: StringName, move_camera: bool) -> void:
	var t := help_target()
	if t == null or controlled_node == null:
		return
	print("[RB] v3 help arrow")
	arrow.visible = true
	arrow.global_position = t.global_position + Vector3(0, 2.0, 0)
	if move_camera and not land.sailing:
		var d := t.global_position - controlled_node.global_position
		d.y = 0.0
		if d.length() > 0.5:
			camera_rig.set_low_view(atan2(d.x, d.z) + PI)


## Mostra o alvo ja (seta), sem esperar o tempo: entrega errada no mercado.
func flash_help_target() -> void:
	_on_pointer_hint(&"", false)


## Botao de ajuda (`help`): pula para o proximo degrau.
func help_now() -> void:
	if current == null or not current.is_active():
		return
	var next := mini(help.tier, 2)
	help.idle_time = maxf(help.idle_time, help.tier_times[next])
	help.tick(0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed(&"help"):
		get_viewport().set_input_as_handled()
		if not blocked():
			help_now()
	elif event.is_action_pressed(&"interact"):
		if try_interact():
			get_viewport().set_input_as_handled()


func _setup_speech() -> void:
	# E6: icones da legenda e take ja existente pela ficha ep01_v3_dialogue.json (balbucio do mesmo personagem);
	# chave sem take na ficha tenta a propria chave (radio/balbucio que ja existem) e senao fica so com a legenda.
	hud.emotes_hook = func(key: String) -> Array[StringName]: return Ep01V3Dialogue.emotes(key)
	hud.voice_hook = func(key: String) -> float:
		var id := Ep01V3Dialogue.take(key)
		return float(audio.play_line(id if id != "" else key).get("duration", 0.0))
	hud.voice_stop_hook = func() -> void:
		audio.stop_voice()


# ---------- controle ----------

func set_controlled(node: Node3D) -> void:
	controlled_node = node
	for m: StringName in actors:
		(actors[m] as MemberActor).controlled = (actors[m] == node)
	boat.controlled = (node == boat)
	hud.set_member(active_member if node != null else &"")
	if node != null:
		camera_rig.follow(node)


## Piso sob o heroi para o som do passo (PROVISORIO): madeira no cais, pedra no resto da vila.
static func surface_at(pos: Vector3) -> StringName:
	if absf(pos.x) <= 9.0 and pos.z >= -4.0 and pos.z <= 0.6:
		return &"wood"
	return &"stone"


func _on_footstep(speed: float, pos: Vector3) -> void:
	if audio != null:
		audio.play_footstep(speed, surface_at(pos), pos)


func _pause() -> void:
	camera_rig.release_mouse()
	get_tree().paused = true
	hud.open_pause()


func _resume() -> void:
	get_tree().paused = false
	hud.close_pause()


func _on_replay() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
