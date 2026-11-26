class_name Ep01V3Guide
extends Node3D
## Padrao "Ver, ouvir, seguir" do Ep01 v3 (RB-R1 F2, docs/proposals/ep01_v3_roteiro_intuitivo.md):
## - P2 olhar dirigido: no inicio de cada passo e depois de cada troca de heroi a camera mostra o alvo por LOOK_SECONDS e
##   volta ao heroi. `interact` pula. Com movimento reduzido a CameraRig ja corta (peso 1) em vez de deslizar. Nunca
##   durante a pilotagem, o cartao de troca, a pose de equipe ou um salto encadeado.
## - P3 anel de alvo: `target_ring` (ou `target_ring_tall` na grama alta) sob o alvo ativo; um so; some sem alvo.
## - P4 rastro entre missoes: pegadinhas grandes (margem -> chafariz, cais -> lente) ou sequencia de aneis (telhado ->
##   barco), na rota andavel da grade do bot (pontos fixos abaixo); some quando o 1o passo da missao termina.
## - P5 falas que apontam: `step_start`, `travel` e `step_done` da ficha, com o gesto (anim ou fallback) para o alvo.
## O no nao le teclado: a Ep01V3Main repassa `interact` (skip_look) e os acontecimentos da missao.

signal look_started(target: Vector3)
signal look_finished(skipped: bool)

const LOOK_SECONDS := 1.5
## Distancia maxima do ponto de mira ao alvo durante o olhar (alvo longe: a camera vai ate perto dele).
const LOOK_REACH := 5.0
const RING := "target_ring"
const RING_TALL := "target_ring_tall"
## Passos com o alvo na grama alta (anel alto).
const TALL_STEPS: Array[String] = ["M2.find_third", "M7.lens"]
const TRAIL_GAP := 1.8
const RING_TRAIL_GAP := 4.0
## Rotas andaveis (grade Ep01V3Nav, celula 0,25 m, simplificada por linha de visada; medidas nesta tarefa) do fim da
## missao anterior ao 1o alvo. Chave: missao que comeca.
const TRAILS := {
	&"M3": {"decal": "decal_paw_big", "path": [Vector3(11.5, -0.01, 8.0), Vector3(12.5, -0.01, 8.75),
		Vector3(13.5, -0.01, 11.75), Vector3(11.25, -0.01, 14.0), Vector3(6.5, -0.01, 15.0), Vector3(-4.0, 0.01, 8.75),
		Vector3(-21.25, 0.0, 8.5), Vector3(-25.5, 0.0, 5.0), Vector3(-25.75, 0.0, 3.75), Vector3(-24.28, 0.0, 2.12)]},
	&"M6": {"decal": "", "path": [Vector3(-14.25, 0.0, -14.75), Vector3(-15.25, 0.0, -12.5), Vector3(-15.0, 0.0, 2.75),
		Vector3(-12.5, 0.0, 8.0), Vector3(-11.0, 0.0, 8.0), Vector3(-8.0, 0.01, 6.75), Vector3(-5.5, -0.05, 3.5),
		Vector3(-3.75, 0.0, 2.5), Vector3(0.0, 0.0, -2.5)]},
	&"M7": {"decal": "decal_paw_big", "path": [Vector3(0.5, 0.0, -0.5), Vector3(-6.25, 0.03, 4.0), Vector3(-8.75, 0.01, 7.25),
		Vector3(-11.75, 0.0, 8.0), Vector3(-12.75, 0.0, 7.75), Vector3(-15.0, 0.0, 2.0), Vector3(-15.25, 0.0, -13.0),
		Vector3(-13.25, 0.0, -14.5), Vector3(-9.75, 0.0, -14.75), Vector3(-7.25, 0.0, -15.25), Vector3(-4.0, 0.0, -15.0),
		Vector3(1.0, 0.0, -14.5), Vector3(8.25, 0.0, -16.0), Vector3(12.75, 0.0, -16.0), Vector3(14.0, 0.0, -16.0),
		Vector3(16.25, 0.0, -16.75), Vector3(20.0, 0.0, -17.0), Vector3(21.0, 0.53, -16.75), Vector3(22.5, 1.16, -16.75),
		Vector3(25.0, 2.1, -20.8)]},
}
const HEROES: Array[StringName] = [&"tracker", &"climber", &"pilot"]

var main: Ep01V3Main
var looking: bool = false
var look_target: Vector3 = Vector3.INF
var looks_done: int = 0
var look_elapsed: float = 0.0
var ring: Node3D
var ring_tall: Node3D
var trail_root: Node3D
var trail_mission: StringName = &""
var _pending_look: bool = false
var _focus: Node3D
var _look_actor: MemberActor
var _prev_mission: StringName = &""


func setup(m: Ep01V3Main) -> void:
	main = m
	name = "Guide"
	_focus = Node3D.new()
	_focus.name = "LookFocus"
	add_child(_focus)
	ring = _make_ring(RING)
	ring_tall = _make_ring(RING_TALL)
	trail_root = Node3D.new()
	trail_root.name = "Trail"
	add_child(trail_root)


func _make_ring(id: String) -> Node3D:
	var r := Ep01V3Pieces.final(self, id, id)
	if r == null:
		r = Blocks.cylinder(self, id, 0.6, 0.03, Vector3.ZERO, Color("ffd34d"), 0.6)
		r.set_meta(&"provisional", true)
	r.visible = false
	Ep01V3Pieces.play(r, &"pulse")
	return r


# ---------------------------------------------------------------- acontecimentos (chamados pela Ep01V3Main)

## Missao nova: fala de deslocamento (travel) e rastro ate o 1o alvo.
func on_mission_started(id: StringName) -> void:
	_clear_trail()
	if _prev_mission != &"":
		var k := Ep01V3Dialogue.travel_line(_prev_mission, id)
		if k != "":
			point_line(k)
	_prev_mission = id
	if TRAILS.has(id):
		_build_trail(id)
		_travel_music.call_deferred(true, id)


## Passo novo: fala que aponta (com gesto) e olhar dirigido. Diferido: as falas de abertura da missao vem antes.
func on_step_started(mission: StringName, step: StringName) -> void:
	var k := Ep01V3Dialogue.step_start_line(mission, step)
	if k != "":
		point_line(k)
	request_look()


func on_step_done(mission: StringName, index: int, step: StringName) -> void:
	var k := Ep01V3Dialogue.step_done_line(mission, step)
	if k != "":
		point_line(k)
	if index == 0 and trail_mission == mission:
		_clear_trail()
		_travel_music(false, mission)


func on_mission_completed(_id: StringName) -> void:
	_clear_trail()


## Musica (F2): no deslocamento longo (rastro ate o 1o alvo) toca a musica da vila; ao chegar (1o passo feito), a musica
## da missao. Diferido: a AudioDirector troca para a musica da missao no `mission_started`, que vem depois.
func _travel_music(on: bool, mission: StringName) -> void:
	var a := main.audio
	if a == null or not a.has_method(&"play_scene_music"):
		return
	a.play_scene_music(&"v3_village" if on else a.scene_music_for(mission))


## Diz a fala e faz o gesto do falante (heroi do trio) para o alvo da ficha; clipe que falta cai no fallback.
func point_line(key: String) -> void:
	main.say(key)
	var g := Ep01V3Dialogue.gesture(key)
	if g.is_empty():
		return
	var who := Ep01V3Dialogue.speaker(key)
	var a := main.actors.get(who) as MemberActor if who in HEROES else main.controlled_node as MemberActor
	if a == null or a.riding_on != null:
		return
	var target := StringName(str(g.get("target", "")))
	if target != &"" and main.world.marker(target) != null:
		a.face_point(main.land.clue_point(target))
	var anim := gesture_anim(a, g)
	if anim != &"":
		a.play_action(anim)


## Clipe do gesto que este heroi tem: `anim`, senao `fallback`, senao nenhum.
static func gesture_anim(a: MemberActor, g: Dictionary) -> StringName:
	for k: String in ["anim", "fallback"]:
		var n := StringName(str(g.get(k, "")))
		if n != &"" and a.model != null and a.model.has_animation(n):
			return n
	return &""


# ---------------------------------------------------------------- P2 olhar dirigido

func request_look() -> void:
	_pending_look = true


func can_look() -> bool:
	if main.current == null or not main.current.is_active() or main.land.sailing:
		return false
	# D21: nada de olhar durante a cena; logo depois dela, o exit_look ja mostrou o mesmo alvo.
	if main.cutscene_blocks_look():
		return false
	if main.hud.handoff_open or main.hud.pause_open or main.posing or main.land.busy or main._pending_switch != &"":
		return false
	return main.controlled_node is MemberActor and main.help_target() != null


func start_look() -> void:
	_pending_look = false
	var t := main.help_target()
	var a := main.controlled_node as MemberActor
	if t == null or a == null:
		return
	var p := t.global_position
	var d := p - a.global_position
	d.y = 0.0
	looking = true
	look_elapsed = 0.0
	look_target = p
	_look_actor = a
	a.controlled = false
	a.velocity = Vector3.ZERO
	var dist := d.length()
	var dir := d / dist if dist > 0.01 else -(Basis(Vector3.UP, main.camera_rig.yaw) * Vector3.BACK)
	var reach := clampf(dist * 0.5, 0.0, LOOK_REACH)
	_focus.global_position = Vector3(p.x, maxf(a.global_position.y, p.y - 0.6), p.z) - dir * reach
	main.camera_rig.set_low_view(atan2(dir.x, dir.z) + PI)
	main.camera_rig.follow(_focus)
	looks_done += 1
	print("[RB] v3 look %s" % main.current.current_step().get("id", &""))
	look_started.emit(p)


## Fim do olhar (tempo ou `interact`): a camera volta ao heroi com o rumo do alvo; controle devolvido.
func end_look(skipped: bool = false) -> void:
	if not looking:
		return
	looking = false
	if is_instance_valid(_look_actor) and _look_actor == main.controlled_node:
		_look_actor.controlled = true
	_look_actor = null
	if main.controlled_node != null:
		if look_target != Vector3.INF and not main.land.sailing:
			main.camera_rig.set_low_view(clear_yaw(main.controlled_node.global_position, look_target))
		main.camera_rig.follow(main.controlled_node, skipped)
	look_finished.emit(skipped)


## Rumo da camera baixa (de volta ao heroi) com o alvo a vista (F2/A5): o rumo direto heroi->alvo e, se a linha
## camera->alvo cruzar um seguidor ou uma parede/cabine (camada 1), desvios de 15 em 15 graus ate 60.
func clear_yaw(hero: Vector3, target: Vector3) -> float:
	var d := target - hero
	d.y = 0.0
	var base := atan2(d.x, d.z) + PI if d.length() > 0.01 else main.camera_rig.yaw
	for off: float in [0.0, 15.0, -15.0, 30.0, -30.0, 45.0, -45.0, 60.0, -60.0]:
		var yaw := base + deg_to_rad(off)
		if target_visible_from(hero + Basis(Vector3.UP, yaw) * CameraRig.LOW_OFFSET, target):
			return yaw
	return base


## Linha da camera ate o alvo livre de seguidores (a menos de 0,55 m), do barco atracado e de colisao da camada 1.
func target_visible_from(cam: Vector3, target: Vector3) -> bool:
	var aim := target + Vector3(0, 0.15, 0)
	for m: StringName in main.actors:
		var a := main.actors[m] as MemberActor
		if a == main.controlled_node:
			continue
		var c := a.global_position + Vector3(0, 0.6, 0)
		var seg := aim - cam
		var t := clampf((c - cam).dot(seg) / seg.length_squared(), 0.0, 1.0)
		if (cam + seg * t).distance_to(c) < 0.55:
			return false
	# O barco atracado nao tem colisao: cabine e casco contam pelas caixas das malhas.
	if main.boat != null and not main.land.sailing:
		for v: Node in main.boat.find_children("*", "VisualInstance3D", true, false):
			var vi := v as VisualInstance3D
			var box := vi.global_transform * vi.get_aabb()
			if vi.is_visible_in_tree() and not box.grow(0.1).has_point(aim) and box.intersects_segment(cam, aim):
				return false
	var q := PhysicsRayQueryParameters3D.create(cam, aim, 1)
	for path: String in ["Collision/WaterLimits", "Collision/MapBounds", "Collision/AccessRamps"]:
		var b := main.world.get_node_or_null(path) as CollisionObject3D
		if b != null:
			q.exclude = q.exclude + [b.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or (hit.position as Vector3).distance_to(aim) < 0.4


func skip_look() -> bool:
	if not looking:
		return false
	end_look(true)
	return true


func _process(delta: float) -> void:
	if main == null:
		return
	if looking:
		look_elapsed += delta
		if look_elapsed >= LOOK_SECONDS or main.controlled_node != _look_actor or main.land.sailing:
			end_look(false)
	elif _pending_look and can_look():
		start_look()
	_update_ring()


# ---------------------------------------------------------------- P3 anel

func ring_step_key() -> String:
	if main.current == null or not main.current.is_active():
		return ""
	return "%s.%s" % [main.current.id, main.current.current_step().get("id", &"")]


func active_ring() -> Node3D:
	if ring.visible:
		return ring
	return ring_tall if ring_tall.visible else null


func _update_ring() -> void:
	var t := main.help_target() if main.current != null and main.current.is_active() else null
	var tall := ring_step_key() in TALL_STEPS
	var show := t != null and not main.complete
	ring.visible = show and not tall
	ring_tall.visible = show and tall
	if show:
		var r := ring_tall if tall else ring
		var p := t.global_position
		if not main.land.sailing:
			p = _floor_below(p)
		r.global_position = p + Vector3(0, 0.02, 0)


func _floor_below(p: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.4, 0), p + Vector3(0, -2.0, 0), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else p


# ---------------------------------------------------------------- P4 rastro entre missoes

func _build_trail(id: StringName) -> void:
	var t: Dictionary = TRAILS[id]
	var path: Array[Vector3] = []
	for p: Vector3 in t["path"]:
		path.append(p)
	trail_mission = id
	var decal := str(t["decal"])
	if decal != "":
		main.land.trail_decals(trail_root, decal, path, TRAIL_GAP)
	else:
		for p in resample(path, RING_TRAIL_GAP):
			var r := Ep01V3Pieces.final(trail_root, RING, "TrailRing")
			if r == null:
				continue
			r.global_position = p
			r.scale = Vector3.ONE * 0.7
			r.add_to_group(&"ep01v3_clue")
			Ep01V3Pieces.play(r, &"pulse")
	print("[RB] v3 trail %s %d" % [id, trail_root.get_child_count()])


## Pontos a cada `gap` m ao longo da linha (inclui o primeiro).
static func resample(path: Array[Vector3], gap: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var carry := 0.0
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var length := Vector2(b.x - a.x, b.z - a.z).length()
		var t := carry
		while t <= length and length > 0.0:
			out.append(a.lerp(b, t / length))
			t += gap
		carry = t - length
	return out


func trail_count() -> int:
	return trail_root.get_child_count() if trail_root != null else 0


func _clear_trail() -> void:
	trail_mission = &""
	if trail_root == null:
		return
	for c in trail_root.get_children():
		c.queue_free()
