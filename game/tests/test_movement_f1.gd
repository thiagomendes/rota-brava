extends RefCounted
## RB-R1 F1 - andar e seguidores no Ep01 v3 com entrada real (Input Map) e percurso real na vila (caixotes do M5,
## chafariz do M3, beira d'agua do M6/M0). Em TODO quadro de fisica, para os tres atores, mede a velocidade planar
## REAL (deslocamento / dt) e o clipe tocando:
##  - nenhum ator a pe com > 0,3 m/s em clipe que nao seja walk/run (pe parado com corpo andando);
##  - nenhum ator em walk/run com < 0,1 m/s por mais de 0,2 s (pe andando com corpo parado);
##  - escala do walk sempre >= 0,6 (sem camera lenta);
##  - seguidores com o lider parado: caminho percorrido < 2 cm em 2 s (sem tremor), perto de cada obstaculo;
##  - todo teleporte de seguidor cai fora do frustum da camera.
## Mede estado; nao comprova como fica na tela (para isso, o video em captures/f1/).

const MOVE_IDLE_MAX := 0.3
const STILL_SPEED := 0.1
const STILL_WALK_MAX_S := 0.2
const WALK_SCALE_MIN := 0.6
const JITTER_MAX := 0.02

var r
var main: Ep01V3Main
var _last := {}
var _still_walk := {}
var _bad_idle: Array[String] = []
var _bad_still: Array[String] = []
var _bad_scale: Array[String] = []
var _teleports := 0
var _bad_teleports: Array[String] = []
var _frames := 0
var _min_walk_scale := INF


func run(runner) -> void:
	r = runner
	Ep01V3Main.start_mission = &""
	Ep01V3Main.save_path = ""
	main = (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	r.tree.root.add_child(main)
	r.tree.current_scene = main
	await r.frames(3)
	main.current = null
	main.set_controlled(main.actors[&"tracker"] as MemberActor)
	var spots := {
		"caixotes M5": &"M5_Crates",
		"chafariz M3": &"M3_UpperBasin",
		"beira d'agua M6": &"M6_BoatStart",
		"cais M0": &"M0_BoatDocked",
	}
	for label: String in spots:
		await _obstacle_run(label, spots[label] as StringName)
	await _village_route()
	await _far_follower_teleport()
	await _nearest_teleport_ring()
	await _stuck_follower_returns()
	await _followers_disabled()
	_release()
	r.check(_frames > 3000, "f1: quadros medidos %d" % _frames)
	r.check(_bad_idle.is_empty(), "f1: nenhum ator a pe com > %.1f m/s fora de walk/run (%d casos %s)" % [MOVE_IDLE_MAX, _bad_idle.size(), _bad_idle.slice(0, 3)])
	r.check(_bad_still.is_empty(), "f1: nenhum ator em walk/run parado (< %.1f m/s) por > %.1f s (%d casos %s)" % [STILL_SPEED, STILL_WALK_MAX_S, _bad_still.size(), _bad_still.slice(0, 3)])
	r.check(_bad_scale.is_empty(), "f1: escala do walk sempre >= %.1f (min %.2f; %d casos %s)" % [WALK_SCALE_MIN, _min_walk_scale, _bad_scale.size(), _bad_scale.slice(0, 3)])
	r.check(_bad_teleports.is_empty(), "f1: %d teleportes de seguidor, nenhum dentro do frustum %s" % [_teleports, _bad_teleports.slice(0, 3)])
	print("  medida f1: %d quadros, escala minima do walk %.2f, %d teleportes" % [_frames, _min_walk_scale, _teleports])
	main.queue_free()
	await r.frames(2)
	r.tree.current_scene = null


func _release() -> void:
	for a: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"run", &"jump"]:
		Input.action_release(a)


## Entrada real: direcao no mundo convertida para as acoes relativas a camera, com inclinacao `tilt` (analogico parcial).
func _push(dir: Vector3, tilt: float = 1.0) -> void:
	var local := Basis(Vector3.UP, -main.camera_rig.yaw) * dir.normalized() * tilt
	for pair: Array in [[&"move_right", local.x], [&"move_left", -local.x], [&"move_down", local.z], [&"move_up", -local.z]]:
		if float(pair[1]) > 0.01:
			Input.action_press(pair[0] as StringName, float(pair[1]))
		else:
			Input.action_release(pair[0] as StringName)


func _floor(x: float, z: float, from_y: float = 6.0) -> Variant:
	var space := main.world.get_world_3d().direct_space_state
	var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, from_y - 9.0, z), 1))
	if h.is_empty():
		return null
	var pos: Vector3 = h["position"]
	return pos


## Um quadro de fisica com as medidas de todos os atores.
func _step() -> void:
	await r.tree.physics_frame
	_frames += 1
	var dt := 1.0 / Engine.physics_ticks_per_second
	var cam := main.camera_rig.camera
	for m: StringName in main.actors:
		var a := main.actors[m] as MemberActor
		var p := a.global_position
		var prev: Variant = _last.get(m)
		_last[m] = p
		if prev == null or a.model == null:
			continue
		var dp := p - (prev as Vector3)
		dp.y = 0.0
		if dp.length() > 0.5:
			if a != main.controlled_node and a.get_meta(&"f1_expected_tp", false) == false:
				_teleports += 1
				for h: float in [0.1, 0.9, 1.4]:
					if cam.is_position_in_frustum(p + Vector3(0, h, 0)):
						_bad_teleports.append("%s %s" % [m, p])
						break
			_still_walk[m] = 0.0
			continue
		if a.airborne or a.jumping or a.riding_on != null:
			_still_walk[m] = 0.0
			continue
		var v := dp.length() / dt
		var anim := a.model.current_animation()
		var loco := anim == &"walk" or anim == &"run"
		if v > MOVE_IDLE_MAX and not loco:
			_bad_idle.append("%s %.2fm/s %s q%d" % [m, v, anim, _frames])
		if loco and v < STILL_SPEED:
			_still_walk[m] = float(_still_walk.get(m, 0.0)) + dt
			if float(_still_walk[m]) > STILL_WALK_MAX_S:
				_bad_still.append("%s %.2fm/s %s q%d" % [m, v, anim, _frames])
				_still_walk[m] = -INF
		else:
			_still_walk[m] = 0.0
		if anim == &"walk":
			var sc := a.model.animation_player().speed_scale
			_min_walk_scale = minf(_min_walk_scale, sc)
			if sc < WALK_SCALE_MIN - 0.001:
				_bad_scale.append("%s x%.2f %.2fm/s q%d" % [m, sc, v, _frames])


func _steps(n: int) -> void:
	for i in n:
		await _step()


func _place(lead_pos: Vector3, toward: Vector3) -> void:
	var lead := main.actors[&"tracker"] as MemberActor
	var d := toward - lead_pos
	d.y = 0.0
	d = d.normalized()
	var side := d.cross(Vector3.UP)
	for m: StringName in main.actors:
		(main.actors[m] as MemberActor).set_meta(&"f1_expected_tp", true)
	lead.teleport(lead_pos + Vector3(0, 0.05, 0))
	(main.actors[&"climber"] as MemberActor).teleport(lead_pos - d * 1.2 + side + Vector3(0, 0.05, 0))
	(main.actors[&"pilot"] as MemberActor).teleport(lead_pos - d * 1.2 - side + Vector3(0, 0.05, 0))
	lead.face_now(lead_pos + d)
	main.camera_rig.follow(lead, true)
	await _steps(2)
	for m: StringName in main.actors:
		(main.actors[m] as MemberActor).set_meta(&"f1_expected_tp", false)


## Ponto de chao a ~`dist` m do obstaculo, na altura do chao em volta (nao em cima dele).
func _approach(center: Vector3, dist: float, max_dy: float = 0.3) -> Variant:
	for i in 16:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 16.0)
		var p := center + dir * dist
		var f: Variant = _floor(p.x, p.z, center.y + 4.0)
		if f == null or (f as Vector3).y > center.y + max_dy:
			continue
		var ok := true
		for k in 5:
			var q := (f as Vector3) - dir * (0.6 * k)
			var g: Variant = _floor(q.x, q.z, (f as Vector3).y + 1.0)
			if g == null or absf((g as Vector3).y - (f as Vector3).y) > 0.15:
				ok = false
		if ok:
			return f
	return null


## Seguidores parados: caminho percorrido por cada um em 2 s, depois de 1,5 s para assentar.
func _stopped_jitter(label: String) -> void:
	_release()
	await _steps(90)
	var acc := {}
	var prev := {}
	for i in 120:
		await _step()
		for m: StringName in [&"climber", &"pilot"]:
			var p := (main.actors[m] as Node3D).global_position
			if prev.has(m):
				acc[m] = float(acc.get(m, 0.0)) + p.distance_to(prev[m] as Vector3)
			prev[m] = p
	var worst := maxf(float(acc.get(&"climber", 0.0)), float(acc.get(&"pilot", 0.0)))
	r.check(worst < JITTER_MAX, "f1 %s: seguidores com o lider parado andaram %.3f m em 2 s (< %.2f)" % [label, worst, JITTER_MAX])


## Anda ate o obstaculo e raspa nele (inclinacao total, depois parcial), para e mede; repete com toques curtos.
func _obstacle_run(label: String, mk: StringName) -> void:
	var marker := main.world.marker(mk)
	if marker == null:
		r.check(false, "f1 %s: marcador %s" % [label, mk])
		return
	var c := marker.global_position
	var start: Variant = _approach(c, 5.0, 2.0 if c.y < 0.0 else 0.3)
	r.check(start != null, "f1 %s: ponto de partida no chao" % label)
	if start == null:
		return
	await _place(start as Vector3, c)
	main.camera_rig.yaw = 0.0
	var lead := main.actors[&"tracker"] as MemberActor
	# Anda direto contra o obstaculo (raspa) com inclinacao total, depois de lado com o analogico a 35%.
	for t in 150:
		var d := c - lead.global_position
		d.y = 0.0
		_push(d if d.length() > 0.1 else Vector3.FORWARD)
		await _step()
	var d2 := c - lead.global_position
	d2.y = 0.0
	var tangent := d2.normalized().cross(Vector3.UP)
	for t in 90:
		_push(tangent + d2.normalized() * 0.3, 0.35)
		await _step()
	await _stopped_jitter(label + " (raspando)")
	# Toques curtos: anda/para a cada 0,25 s (provoca o clipe de parada no meio do movimento).
	for k in 8:
		_push(-tangent if k % 2 == 0 else tangent, 1.0)
		await _steps(15)
		_release()
		await _steps(5 + (k % 3) * 5)
	await _stopped_jitter(label + " (depois de toques)")


## Percurso continuo pela vila com curvas, entre os obstaculos, correndo e andando.
func _village_route() -> void:
	var names: Array[StringName] = [&"M3_BallStop", &"M4_Cart", &"M5_Crates", &"M8_FestaPlaza", &"M1_BenchClue"]
	var pts: Array[Vector3] = []
	for n: StringName in names:
		var mm := main.world.marker(n)
		if mm != null:
			pts.append(mm.global_position)
	var start: Variant = _approach(pts[0], 2.5)
	if start == null:
		r.check(false, "f1 percurso: partida")
		return
	await _place(start as Vector3, pts[1])
	var lead := main.actors[&"tracker"] as MemberActor
	var arrived := 0
	for i in range(1, pts.size()):
		Input.action_press(&"run") if i % 2 == 0 else Input.action_release(&"run")
		var t := 0
		var detour := 0
		while t < 900:
			var d := pts[i] - lead.global_position
			d.y = 0.0
			if d.length() < 2.2:
				arrived += 1
				break
			# Desvio simples de piloto humano: preso contra algo, contorna por 0,5 s num angulo aberto.
			if detour > 0:
				d = d.rotated(Vector3.UP, 1.2 if (i % 2 == 0) else -1.2)
				detour -= 1
			elif t > 20 and lead.real_speed < 0.4:
				detour = 30
			_push(d)
			await _step()
			t += 1
		print("  medida f1 trecho %d: a %.1f m do alvo" % [i, Vector2(pts[i].x - lead.global_position.x, pts[i].z - lead.global_position.z).length()])
		_release()
		await _steps(40)
	print("  medida f1 percurso: %d/%d trechos alcancados" % [arrived, pts.size() - 1])
	await _stopped_jitter("percurso (fim)")


## Seguidor longe (preso) com o lider parado: so reaparece fora do enquadramento (o teste de frustum roda em _step).
func _far_follower_teleport() -> void:
	var lead := main.actors[&"tracker"] as MemberActor
	var climber := main.actors[&"climber"] as MemberActor
	var base := main.world.marker(&"M8_FestaPlaza").global_position
	await _place(base, base + Vector3(0, 0, -3))
	for yaw_deg: float in [0.0, 90.0, 180.0, 270.0]:
		main.camera_rig.set_low_view(deg_to_rad(yaw_deg))
		main.camera_rig.follow(lead, true)
		climber.teleport(lead.global_position + Vector3(14, 0, 0).rotated(Vector3.UP, deg_to_rad(yaw_deg)))
		_last[&"climber"] = climber.global_position
		var before := _teleports
		await _steps(120)
		var near := climber.global_position.distance_to(lead.global_position) < 4.0
		print("  medida f1 teleporte yaw %d: perto=%s teleportes=%d" % [int(yaw_deg), near, _teleports - before])


## Havendo lugar livre fora da vista no anel de 1,6 m, o teleporte escolhe esse anel (o mais perto do lider).
func _nearest_teleport_ring() -> void:
	var lead := main.actors[&"tracker"] as MemberActor
	var climber := main.actors[&"climber"] as MemberActor
	var base := main.world.marker(&"M8_FestaPlaza").global_position
	await _place(base, base + Vector3(0, 0, -3))
	var checked := 0
	for yaw_deg: float in [0.0, 90.0, 180.0, 270.0]:
		# G24a2: a camera nao encurta mais por objeto no meio (fica atras dele, em pontilhado), entao na praca o anel de
		# 1,6 m fica todo a vista com a camera baixa normal. O que esta checagem protege e a ESCOLHA do anel de 1,6 m quando
		# ha lugar livre fora da vista; para existir esse lugar, a camera fica perto (braco curto, como encostada numa
		# parede), com o mesmo giro e a mesma mira.
		main.camera_rig.set_view(Vector3(0, 1.2, 1.3), deg_to_rad(yaw_deg), CameraRig.LOW_LOOK_Y)
		main.camera_rig.follow(lead, true)
		await _steps(2)
		var free16 := false
		for k: int in 32:
			var p := lead.global_position + Vector3(0, 0, 1.6).rotated(Vector3.UP, TAU * k / 32.0)
			if not main.in_camera_view(p) and climber.slot_clear(lead.global_position, p):
				free16 = true
		if not free16:
			continue
		checked += 1
		var to: Variant = main.follower_teleport_point(lead, climber, &"climber")
		var dist := -1.0 if to == null else Vector2((to as Vector3).x - lead.global_position.x, (to as Vector3).z - lead.global_position.z).length()
		r.check(to != null and absf(dist - 1.6) < 0.05 and not main.in_camera_view(to as Vector3),
			"f1 teleporte yaw %d: com lugar livre a 1,6 m fora da vista, escolhe 1,6 m (%.2f m)" % [int(yaw_deg), dist])
	r.check(checked >= 1, "f1 teleporte: %d vistas com lugar livre a 1,6 m testadas" % checked)


## Lider parado a < 9 m, seguidor preso atras dos caixotes do M5 (fora da vista): volta em ate ~3 s, sem aparecer na vista.
func _stuck_follower_returns() -> void:
	var lead := main.actors[&"tracker"] as MemberActor
	var climber := main.actors[&"climber"] as MemberActor
	var c := main.world.marker(&"M5_Crates").global_position
	var placed := false
	for i in 16:
		var w := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 16.0)
		var a: Variant = _floor(c.x - w.x * 2.6, c.z - w.z * 2.6, c.y + 4.0)
		var b: Variant = _floor(c.x + w.x * 2.6, c.z + w.z * 2.6, c.y + 4.0)
		if a == null or b == null or (a as Vector3).y > c.y + 0.3 or absf((a as Vector3).y - (b as Vector3).y) > 0.15:
			continue
		var space := main.world.get_world_3d().direct_space_state
		var blocked := not space.intersect_ray(PhysicsRayQueryParameters3D.create((a as Vector3) + Vector3(0, 0.5, 0), (b as Vector3) + Vector3(0, 0.5, 0), 1)).is_empty()
		if not blocked:
			continue
		await _place(a as Vector3, (a as Vector3) - w)
		# Camera olhando para longe do seguidor (ele fica atras dela).
		main.camera_rig.set_low_view(atan2(w.x, w.z))
		main.camera_rig.follow(lead, true)
		climber.teleport((b as Vector3) + Vector3(0, 0.05, 0))
		_last[&"climber"] = climber.global_position
		placed = true
		break
	r.check(placed, "f1 preso: seguidor do outro lado dos caixotes, com obstaculo no meio")
	if not placed:
		return
	await _steps(3)
	r.check(not main.in_camera_view(climber.global_position) and climber.global_position.distance_to(lead.global_position) < 9.0,
		"f1 preso: comeca fora da vista e a menos de 9 m (%.1f m)" % climber.global_position.distance_to(lead.global_position))
	var bad0 := _bad_teleports.size()
	var back_at := -1.0
	for f in 210:
		await _step()
		if climber.global_position.distance_to(lead.global_position) < 2.5:
			back_at = (f + 1) / 60.0
			break
	r.check(back_at > 0.0 and back_at <= 3.5, "f1 preso: seguidor voltou para perto do lider em %.2f s (<= 3,5)" % back_at)
	r.check(_bad_teleports.size() == bad0, "f1 preso: voltou sem aparecer dentro da vista")


## Contrato das cenas: com seguidores desligados nao ha formacao nem teleporte; religados, voltam.
func _followers_disabled() -> void:
	var lead := main.actors[&"tracker"] as MemberActor
	var climber := main.actors[&"climber"] as MemberActor
	var base := main.world.marker(&"M8_FestaPlaza").global_position
	await _place(base, base + Vector3(0, 0, -3))
	main.set_followers_enabled(false)
	climber.teleport(lead.global_position + Vector3(12, 0, 0))
	_last[&"climber"] = climber.global_position
	var p0 := climber.global_position
	await _steps(90)
	var moved := Vector2(climber.global_position.x - p0.x, climber.global_position.z - p0.z).length()
	r.check(not climber.follow_on and moved < 0.05, "f1 cena: seguidores desligados nao andam nem teleportam (%.2f m no plano)" % moved)
	main.set_followers_enabled(true)
	await _steps(30)
	r.check(climber.follow_on and climber.global_position.distance_to(lead.global_position) < 7.0,
		"f1 cena: religados, o seguidor volta (%.1f m)" % climber.global_position.distance_to(lead.global_position))
