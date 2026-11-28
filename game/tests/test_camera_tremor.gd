extends RefCounted
## RB-R1 (Thiago: "correndo muito rapido a tela trepida"). Corre segurando `run` (entrada real) por um percurso na vila
## v3 passando por beira d'agua, caixotes, chafariz, carroca, praca e arvores, com render simulado a 144 Hz sobre a
## fisica a 60 Hz (2 ou 3 quadros de render por passo, como num monitor de 144 Hz). Em cada quadro de render mede:
##  - tremor do heroi na tela: velocidade da posicao heroi - camera entre quadros de render (m/s, RMS);
##  - 2a diferenca da posicao da camera (m/s^2, p99);
##  - inversoes de direcao do braco (distancia camera-mira) por segundo, contando variacoes > 0,5 mm.
## Camera: 2a diferenca amostrada por passo de fisica (o render so ve o que a fisica deixou).
## Mede estado; nao comprova o que se ve na tela.

const RENDER_HZ := 144.0
const CAM_ACC_P99_MAX := 80.0
const ARM_FLIPS_MAX := 2.0
const SAW_MAX := 3.0

var r
var main: Ep01V3Main
var _rel: Array[Vector3] = []
var _cam: Array[Vector3] = []
var _cam_tick: Array[Vector3] = []
var _arm: Array[float] = []
var _acc_time := 0.0
var _seconds := 0.0


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
	var rig := main.camera_rig
	rig.set_process(false)
	var names: Array[StringName] = [&"M3_BallStop", &"M5_Crates", &"M6_BoatStart", &"M3_UpperBasin", &"M4_Cart", &"M8_FestaPlaza", &"M1_BenchClue"]
	var pts: Array[Vector3] = []
	for n: StringName in names:
		var mm := main.world.marker(n)
		if mm != null:
			pts.append(mm.global_position)
	r.check(pts.size() == names.size(), "tremor: marcadores do percurso (%d/%d)" % [pts.size(), names.size()])
	var lead := main.actors[&"tracker"] as MemberActor
	var space := main.world.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(pts[0] + Vector3(0, 4, 0), pts[0] + Vector3(0, -5, 0), 1))
	r.check(not hit.is_empty(), "tremor: partida no chao")
	lead.teleport((hit.get("position", pts[0]) as Vector3) + Vector3(0, 0.05, 0))
	var low_y := INF
	rig.yaw = 0.0
	rig.follow(lead, true)
	await r.frames(2)
	Input.action_press(&"run")
	var top := 0.0
	var pulls := 0
	var struct_pulls := 0
	for i in range(1, pts.size()):
		var t := 0
		var detour := 0
		while t < 600:
			var d := pts[i] - lead.global_position
			d.y = 0.0
			if d.length() < 1.5:
				break
			if detour > 0:
				d = d.rotated(Vector3.UP, 1.2 if i % 2 == 0 else -1.2)
				detour -= 1
			elif t > 20 and lead.real_speed < 0.4:
				detour = 30
			_push(d)
			await _tick()
			top = maxf(top, lead.real_speed)
			low_y = minf(low_y, lead.global_position.y)
			if rig.last_pull > 0.05 or rig.occluded:  # G24a2 v2: estrutura encurta o braco; peca no meio fica pontilhada
				pulls += 1
			if rig.last_pull > 0.05:
				struct_pulls += 1  # G24a2: o percurso tem de passar tambem por estrutura
			t += 1
	_release()
	var rel_rms := _rms(_vel_list(_rel))
	var cam := _acc_list(_cam_tick, 60.0)
	cam.sort()
	var cam_p99: float = cam[int(cam.size() * 0.99)] if cam.size() > 0 else 0.0
	var flips := _flips() / maxf(_seconds, 0.001)
	var saw := _saw() / maxf(_seconds, 0.001)
	print("  medida tremor: %.1f s, %d quadros de render, vel. max %.2f m/s, %d passos com braco encurtado" % [_seconds, _cam.size(), top, pulls])
	print("  medida tremor: heroi na tela (vel. relativa a camera) RMS %.3f m/s; camera RMS %.2f p99 %.2f m/s2; braco %.2f inversoes/s; heroi na tela vai-e-volta %.1f vezes/s" % [rel_rms, _rms(cam), cam_p99, flips, saw])
	r.check(saw < SAW_MAX, "tremor: heroi nao vai e volta na tela (%.1f < %.0f inversoes/s)" % [saw, SAW_MAX])
	r.check(low_y > -3.0, "tremor: heroi ficou no mapa (y min %.1f)" % low_y)
	r.check(_seconds > 20.0 and top > 3.0, "tremor: correu %.1f s a ate %.2f m/s" % [_seconds, top])
	r.check(pulls > 30, "tremor: percurso passou por obstaculos que encurtam o braco ou ficam pontilhados (%d passos)" % pulls)
	r.check(struct_pulls > 30, "tremor: percurso passou por estrutura que encurta o braco (%d passos)" % struct_pulls)
	r.check(cam_p99 < CAM_ACC_P99_MAX, "tremor: camera sem saltos (p99 %.2f < %.0f m/s2)" % [cam_p99, CAM_ACC_P99_MAX])
	r.check(flips < ARM_FLIPS_MAX, "tremor: braco sem vai-e-vem (%.2f < %.1f inversoes/s)" % [flips, ARM_FLIPS_MAX])
	main.queue_free()
	await r.frames(2)
	r.tree.current_scene = null


func _release() -> void:
	for a: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"run"]:
		Input.action_release(a)


func _push(dir: Vector3) -> void:
	var local := Basis(Vector3.UP, -main.camera_rig.yaw) * dir.normalized()
	for pair: Array in [[&"move_right", local.x], [&"move_left", -local.x], [&"move_down", local.z], [&"move_up", -local.z]]:
		if float(pair[1]) > 0.01:
			Input.action_press(pair[0] as StringName, float(pair[1]))
		else:
			Input.action_release(pair[0] as StringName)


## Um passo de fisica e os quadros de render a 144 Hz que caem nele (o heroi aparece onde a fisica o deixou).
func _tick() -> void:
	await r.tree.physics_frame
	var dt_phys := 1.0 / Engine.physics_ticks_per_second
	_seconds += dt_phys
	_acc_time += dt_phys
	var rig := main.camera_rig
	var hero := main.controlled_node
	while _acc_time >= 1.0 / RENDER_HZ:
		_acc_time -= 1.0 / RENDER_HZ
		if rig.has_method(&"_process"):
			rig.call(&"_process", 1.0 / RENDER_HZ)
		var c := rig.camera.global_position
		_cam.append(c)
		_rel.append(hero.global_position - c)
		_arm.append(c.distance_to(hero.global_position + rig.look_offset))
	_cam_tick.append(rig.camera.global_position)


func _acc_list(p: Array[Vector3], hz: float = RENDER_HZ) -> Array[float]:
	var out: Array[float] = []
	var k := hz * hz
	for i in range(1, p.size() - 1):
		var a := (p[i + 1] - 2.0 * p[i] + p[i - 1]).length() * k
		if a < 2000.0:  # teleporte/troca de alvo nao e tremor
			out.append(a)
	return out


## Velocidade do heroi relativa a camera, por quadro de render (m/s; 0 = parado na tela).
func _vel_list(p: Array[Vector3]) -> Array[float]:
	var out: Array[float] = []
	for i in range(1, p.size()):
		var v := (p[i] - p[i - 1]).length() * RENDER_HZ
		if v < 20.0:
			out.append(v)
	return out


func _rms(v: Array[float]) -> float:
	if v.is_empty():
		return 0.0
	var s := 0.0
	for x in v:
		s += x * x
	return sqrt(s / v.size())


func _flips() -> int:
	var n := 0
	var last := 0
	for i in range(1, _arm.size()):
		var d := _arm[i] - _arm[i - 1]
		if absf(d) < 0.0005:
			continue
		var sg := 1 if d > 0.0 else -1
		if last != 0 and sg != last:
			n += 1
		last = sg
	return n


## Serrilhado: o heroi anda num sentido na tela e volta no quadro seguinte (deslocamentos > 0,5 mm com sentido oposto).
func _saw() -> int:
	var n := 0
	var last := Vector3.ZERO
	for i in range(1, _rel.size()):
		var d := _rel[i] - _rel[i - 1]
		if d.length() < 0.0005 or d.length() > 0.2:
			continue
		if last != Vector3.ZERO and d.dot(last) < 0.0:
			n += 1
		last = d
	return n
