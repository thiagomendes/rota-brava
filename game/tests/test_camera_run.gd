extends RefCounted
## RB-R1 G24a (Thiago no iPhone: "ao correr a camera se aproxima demais e esconde o heroi, como primeira pessoa").
## CameraRig na camera baixa da vila v3 (sem obstaculo) seguindo um alvo com o volume do heroi (caixa 0,5 x 1,15 x 0,4 m)
## movido no passo de fisica a velocidade real (MemberActor.WALK_SPEED / RUN_SPEED, rampa ACCEL_TIME). Mede:
##  - distancia camera-heroi: nunca abaixo da parada; em regime de corrida ~+10% (1,05 a 1,15);
##  - FOV: abre 2 a 8 graus correndo, passo maximo por quadro pequeno (suave); com movimento reduzido, nao muda;
##  - os 8 cantos do AABB do heroi projetados dentro do quadro em 16:9 e 4:3, em reta, curva e re.
## Mede estado do rig; nao comprova o que se ve na tela.

const HERO_SIZE := Vector3(0.5, 1.15, 0.4)
const ASPECTS: Array[float] = [16.0 / 9.0, 4.0 / 3.0]

var r
var rig: CameraRig
var hero: Node3D
var _vel := Vector3.ZERO


func run(runner) -> void:
	r = runner
	await _case(false)
	await _case(true)


func _setup(reduced: bool) -> void:
	hero = Node3D.new()
	r.tree.root.add_child(hero)
	rig = CameraRig.new()
	r.tree.root.add_child(rig)
	rig.reduced_motion = reduced
	rig.set_low_view(0.0)
	_vel = Vector3.ZERO
	rig.follow(hero, true)
	await r.tree.physics_frame


func _case(reduced: bool) -> void:
	await _setup(reduced)
	var tag := "reduzido" if reduced else "normal"
	await _drive(func(_t: float) -> Vector3: return Vector3.ZERO, 1.0)
	var d0 := _dist()
	var fov0 := rig.camera.fov
	# Andando: nada abre.
	var walk := await _drive(func(_t: float) -> Vector3: return Vector3.FORWARD * MemberActor.WALK_SPEED, 2.0)
	# Corrida reta (para longe da camera), curva (raio 4 m) e re (na direcao da camera).
	var straight := await _drive(func(_t: float) -> Vector3: return Vector3.FORWARD * MemberActor.RUN_SPEED, 4.0)
	var curve := await _drive(func(t: float) -> Vector3:
		return Vector3.FORWARD.rotated(Vector3.UP, t * MemberActor.RUN_SPEED / 4.0) * MemberActor.RUN_SPEED, 4.0)
	await _drive(func(_t: float) -> Vector3: return Vector3.ZERO, 2.0)
	var back := await _drive(func(_t: float) -> Vector3: return Vector3.BACK * MemberActor.RUN_SPEED, 3.0)
	var settle := await _drive(func(_t: float) -> Vector3: return Vector3.ZERO, 3.0)
	print("  medida corrida (%s): parado dist %.2f m FOV %.1f; andando min %.2f; reta min %.2f fim %.2f (x%.3f) FOV %.1f; curva min %.2f; re min %.2f; parado de novo %.2f FOV %.1f; heroi no quadro reta %.0f%% curva %.0f%% re %.0f%% (pior canto %.2f do meio a borda); passo max FOV %.3f graus" % [
		tag, d0, fov0, walk.min, straight.min, straight.end, straight.end / d0, straight.fov, curve.min, back.min,
		settle.end, settle.fov, 100.0 * straight.inside, 100.0 * curve.inside, 100.0 * back.inside,
		maxf(straight.worst, maxf(curve.worst, back.worst)), maxf(straight.fov_step, maxf(curve.fov_step, back.fov_step))])
	var runs: Array = [["reta", straight], ["curva", curve], ["re", back]]
	for pair: Array in runs:
		var m: Dictionary = pair[1]
		r.check(m.min >= d0 - 0.01, "corrida %s: distancia camera-heroi na %s nunca menor que parado (%.2f >= %.2f)" % [tag, pair[0], m.min, d0])
		r.check(m.inside >= 1.0, "corrida %s: heroi inteiro no quadro na %s em 16:9 e 4:3 (%.0f%% dos quadros, pior %.2f)" % [tag, pair[0], 100.0 * m.inside, m.worst])
	r.check(walk.min >= d0 - 0.01 and walk.end < d0 * 1.02, "corrida %s: andando a distancia fica a de sempre (%.2f / %.2f)" % [tag, walk.end, d0])
	r.check(straight.end > d0 * 1.05 and straight.end < d0 * 1.15, "corrida %s: correndo o braco abre ~10%% (x%.3f)" % [tag, straight.end / d0])
	r.check(absf(settle.end - d0) < 0.03, "corrida %s: parado volta a distancia de sempre (%.2f / %.2f)" % [tag, settle.end, d0])
	if reduced:
		r.check(absf(straight.fov_max - fov0) < 0.001 and absf(straight.fov_min - fov0) < 0.001, "corrida %s: FOV nao muda (%.2f a %.2f, base %.2f)" % [tag, straight.fov_min, straight.fov_max, fov0])
	else:
		r.check(straight.fov - fov0 >= 2.0 and straight.fov - fov0 <= 8.0, "corrida %s: FOV abre alguns graus (%.1f -> %.1f)" % [tag, fov0, straight.fov])
		r.check(straight.fov_step < 0.3 and straight.dist_step < 0.05, "corrida %s: transicao suave (FOV %.3f graus/quadro, distancia %.3f m/quadro)" % [tag, straight.fov_step, straight.dist_step])
		r.check(absf(settle.fov - fov0) < 0.1, "corrida %s: FOV volta ao de sempre (%.2f / %.2f)" % [tag, settle.fov, fov0])
	rig.queue_free()
	hero.queue_free()
	await r.tree.physics_frame


## Move o alvo por `seconds` com velocidade pedida `want(t)` (rampa do MemberActor) e mede o enquadramento.
func _drive(want: Callable, seconds: float) -> Dictionary:
	var dt := 1.0 / Engine.physics_ticks_per_second
	var n := int(seconds / dt)
	var out := {"min": INF, "end": 0.0, "fov": 0.0, "fov_min": INF, "fov_max": -INF, "fov_step": 0.0, "dist_step": 0.0, "inside": 0.0, "worst": 0.0}
	var ok := 0
	var last_fov := rig.camera.fov
	var last_d := _dist()
	for i in n:
		var w: Vector3 = want.call(i * dt)
		_vel = _vel.move_toward(w, MemberActor.SPEED / MemberActor.ACCEL_TIME * dt)
		hero.global_position += _vel * dt
		await r.tree.physics_frame
		var d := _dist()
		out.min = minf(out.min, d)
		out.fov_min = minf(out.fov_min, rig.camera.fov)
		out.fov_max = maxf(out.fov_max, rig.camera.fov)
		out.fov_step = maxf(out.fov_step, absf(rig.camera.fov - last_fov))
		out.dist_step = maxf(out.dist_step, absf(d - last_d))
		last_fov = rig.camera.fov
		last_d = d
		var worst := _worst_corner()
		out.worst = maxf(out.worst, worst)
		if worst <= 1.0:
			ok += 1
	out.end = _dist()
	out.fov = rig.camera.fov
	out.inside = float(ok) / maxf(n, 1)
	return out


func _dist() -> float:
	return rig.camera.global_position.distance_to(hero.global_position + Vector3(0, HERO_SIZE.y * 0.5, 0))


## Maior coordenada normalizada (0 = meio, 1 = borda) dos cantos do AABB do heroi, no pior dos aspectos (Godot mantem a
## altura: FOV vertical fixo, horizontal cresce com o aspecto). > 1 = canto fora do quadro ou atras da camera.
func _worst_corner() -> float:
	var inv := rig.camera.global_transform.affine_inverse()
	var ty := tan(deg_to_rad(rig.camera.fov) * 0.5)
	var worst := 0.0
	for aspect in ASPECTS:
		for i in 8:
			var c := Vector3(HERO_SIZE.x * (0.5 if i & 1 else -0.5), HERO_SIZE.y * (1.0 if i & 2 else 0.0), HERO_SIZE.z * (0.5 if i & 4 else -0.5))
			var p := inv * (hero.global_position + c)
			if p.z > -0.05:
				return INF
			worst = maxf(worst, maxf(absf(p.x / -p.z) / (ty * aspect), absf(p.y / -p.z) / ty))
	return worst
