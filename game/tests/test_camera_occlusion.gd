extends RefCounted
## RB-R1 G24a2 (transparencia): correndo rente a caixotes, carroca, bancos e paredes da vila v3 (desvio de obstaculo
## ligado, camera girada 0,6 rad contra a parede, entrada real pela Input Map), em modo normal e com movimento reduzido.
## Em todo passo de fisica (fora os 2 primeiros depois de cada teleporte do heroi) mede:
##  - salto da camera no quadro (<= STEP_MAX m);
##  - camera dentro de algo: esfera de 0,1 m na camada da camera ou dentro de copa (nunca);
##  - vista tapada (raio da camera ao centro do heroi bate em algo): so vale se o ponto que tapa esta no pontilhado
##    (`CameraRig.occlusion_covers`, mesma conta do shader); nos OCCL_TIME s depois de tapar, conta como entrada do fade;
##  - heroi no quadro (AABB visual, pior entre 16:9 e 4:3; oclusor em pontilhado nao conta como oclusao) >= FRAC_MIN;
##  - altura da camera acima do heroi <= braco livre + CAM_RISE_MAX (nao sobe em telhado/toldo);
##  - trocas do pontilhado e custo da troca de material (malhas por quadro, us de CPU), so medidos.
## Mede estado e a conta do shader; nao comprova o que se ve na tela (ver capturas no ticket).

const MARKERS: Array[StringName] = [&"M5_Crates", &"M4_Cart", &"M1_BenchClue", &"M8_FestaPlaza", &"M3_BallStop"]
const ASPECTS: Array[float] = [16.0 / 9.0, 4.0 / 3.0]
const RUN_TICKS := 90
const STEP_MAX := 0.25
const FRAC_MIN := 0.9
const CAM_RADIUS := 0.1
## Copias dos valores do rig (o teste tambem roda contra o rig da integracao, que nao os tem; checado abaixo).
const OCCL_TIME := 0.15
const OCCL_CENTER_Y := 0.6
const RISE_LIM := 2.7  # LOW_OFFSET.y 1,95 x (1 + RUN_ARM 0,10) + CAM_RISE_MAX 0,5 + 0,05

var r
var main: Ep01V3Main
var _sphere := SphereShape3D.new()
var _steps: Array[float] = []
var _ticks := 0
var _inside := 0
var _uncovered: Array[String] = []
var _blocked := 0
var _fading := 0
var _low_frac := 0
var _min_frac := 1.0
var _toggles := 0
var _since_block := 0.0
var _was := false
var _last_cam := Vector3.INF
var _swaps := 0
var _rise_max := 0.0
var _swap_max := 0
var _swapped_max := 0
var _usec: Array[int] = []


func run(runner) -> void:
	r = runner
	_sphere.radius = CAM_RADIUS
	for reduced: bool in [false, true]:
		Ep01V3Main.start_mission = &""
		Ep01V3Main.save_path = ""
		main = (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
		r.tree.root.add_child(main)
		r.tree.current_scene = main
		await r.frames(3)
		main.current = null
		main.set_controlled(main.actors[&"tracker"] as MemberActor)
		main.camera_rig.reduced_motion = reduced
		_steps.clear()
		_ticks = 0
		_inside = 0
		_uncovered.clear()
		_blocked = 0
		_fading = 0
		_low_frac = 0
		_min_frac = 1.0
		_toggles = 0
		_swaps = 0
		_rise_max = 0.0
		_swap_max = 0
		_swapped_max = 0
		_usec.clear()
		var walls := 0
		for mk in MARKERS:
			var m := main.world.marker(mk)
			if m == null:
				continue
			var spot: Variant = _wall_spot(m.global_position)
			if spot == null:
				continue
			walls += 1
			await _along(String(mk), spot[0] as Vector3, spot[1] as Vector3)
		_release()
		var tag := "reduzido" if reduced else "normal"
		var sorted := _steps.duplicate()
		sorted.sort()
		var top: float = sorted[-1] if sorted.size() > 0 else 0.0
		var p99: float = sorted[int(sorted.size() * 0.99)] if sorted.size() > 0 else 0.0
		var secs := maxf(_ticks / float(Engine.physics_ticks_per_second), 0.001)
		var us := _usec.duplicate()
		us.sort()
		var us_avg := 0.0
		for u: int in us:
			us_avg += u
		us_avg /= maxf(us.size(), 1.0)
		print("  medida oclusao custo (%s): %d trocas de material no percurso (max %d num quadro), max %d malhas pontilhadas ao mesmo tempo; CPU da atualizacao media %.0f us, p99 %d us, max %d us (GPU no celular nao medida)" % [
			"reduzido" if reduced else "normal", _swaps, _swap_max, _swapped_max, us_avg, us[int(us.size() * 0.99)] if us.size() > 0 else 0, us[-1] if us.size() > 0 else 0])
		print("  medida oclusao (%s): %d paredes, %d passos; salto max %.2f m/quadro, p99 %.3f; camera dentro %d; vista tapada %d passos (%d entrando no fade, %d sem pontilhado %s); heroi no quadro min %.0f%% (%d < %.0f%%); pontilhado liga/desliga %.2f/s" % [
			tag, walls, _ticks, top, p99, _inside, _blocked, _fading, _uncovered.size(), _uncovered.slice(0, 3), _min_frac * 100.0, _low_frac, FRAC_MIN * 100.0, _toggles / secs])
		r.check(walls >= 4 and _ticks > 800, "oclusao %s: %d paredes e %d passos" % [tag, walls, _ticks])
		r.check(top <= STEP_MAX, "oclusao %s: camera nunca salta mais de %.2f m num quadro (max %.2f)" % [tag, STEP_MAX, top])
		r.check(_inside == 0, "oclusao %s: camera nunca dentro de obstaculo ou copa (%d passos)" % [tag, _inside])
		r.check(_uncovered.is_empty(), "oclusao %s: vista tapada so com o oclusor em pontilhado (%d passos sem)" % [tag, _uncovered.size()])
		r.check(_low_frac == 0, "oclusao %s: heroi >= %.0f%% no quadro (min %.0f%%)" % [tag, FRAC_MIN * 100.0, _min_frac * 100.0])
		var rise_lim := RISE_LIM
		var consts: Dictionary = (CameraRig as Script).get_script_constant_map()
		if consts.has("OCCL_TIME"):
			r.check(is_equal_approx(float(consts["OCCL_TIME"]), OCCL_TIME) and is_equal_approx(float(consts["OCCL_CENTER_Y"]), OCCL_CENTER_Y)
				and absf(CameraRig.LOW_OFFSET.y * (1.0 + float(consts["RUN_ARM"])) + float(consts["CAM_RISE_MAX"]) + 0.05 - RISE_LIM) < 0.01,
				"oclusao %s: copias dos valores do rig conferem" % tag)
		print("  medida oclusao altura (%s): camera ate %.2f m acima do heroi (limite %.2f)" % [tag, _rise_max, rise_lim])
		r.check(_rise_max <= rise_lim, "oclusao %s: camera nao sobe em telhado/toldo (%.2f <= %.2f m acima do heroi)" % [tag, _rise_max, rise_lim])
		r.check(_blocked > 20, "oclusao %s: percurso teve vista tapada para testar o pontilhado (%d passos)" % [tag, _blocked])
		main.queue_free()
		await r.frames(2)
		r.tree.current_scene = null


func _along(label: String, stand: Vector3, normal: Vector3) -> void:
	var hero := main.actors[&"tracker"] as MemberActor
	var rig := main.camera_rig
	var along := normal.cross(Vector3.UP)
	Input.action_press(&"run")
	for s: float in [1.0, -1.0]:
		hero.teleport(stand)
		rig.set_low_view(atan2(along.x * s, along.z * s) + PI + 0.6 * s)
		rig.follow(hero, true)
		_last_cam = Vector3.INF
		_since_block = 0.0
		_was = false
		for t in RUN_TICKS:
			_push(along * s - normal * 0.4)
			await r.tree.physics_frame
			if t >= 2:
				_measure("%s %+d t%d" % [label, int(s), t])
			else:
				_last_cam = rig.camera.global_position
	Input.action_release(&"run")
	_release()


func _measure(label: String) -> void:
	var rig: Variant = main.camera_rig  # sem tipo: roda tambem contra o rig da integracao
	var cam: Vector3 = rig.camera.global_position
	var hero := main.controlled_node
	_ticks += 1
	if _last_cam != Vector3.INF:
		_steps.append(cam.distance_to(_last_cam))
	_last_cam = cam
	var space := main.world.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _sphere
	q.transform = Transform3D(Basis(), cam)
	q.collision_mask = rig.collision_mask
	q.exclude = rig.exclude
	var inside := not space.intersect_shape(q, 1).is_empty()
	for o in rig.occluders:
		if cam.distance_to(Vector3(o.x, o.y, o.z)) < o.w - CAM_RADIUS:
			inside = true
	if inside:
		_inside += 1
	var center := hero.global_position + Vector3(0, OCCL_CENTER_Y, 0)
	var ray := PhysicsRayQueryParameters3D.create(cam, center, rig.collision_mask, rig.exclude)
	var hit := space.intersect_ray(ray)
	var blocked := not hit.is_empty()
	if blocked != _was:
		_toggles += 1
		_was = blocked
		_since_block = 0.0
	_since_block += 1.0 / Engine.physics_ticks_per_second
	if blocked:
		_blocked += 1
		# Rig sem pontilhado (integracao antiga): toda vista tapada conta como sem pontilhado.
		if not (rig.has_method(&"occlusion_covers") and rig.occlusion_covers(hit["position"] as Vector3)):
			if _since_block <= OCCL_TIME + 0.02:
				_fading += 1
			else:
				_uncovered.append(label)
	_rise_max = maxf(_rise_max, cam.y - hero.global_position.y)
	if rig.get(&"occlusion") != null:
		_swaps += rig.occlusion.swaps_frame
		_swap_max = maxi(_swap_max, rig.occlusion.swaps_frame)
		_swapped_max = maxi(_swapped_max, rig.occlusion.swapped_now)
		_usec.append(rig.occlusion.usec_frame)
	var f := _hero_fraction(rig.camera, hero)
	_min_frac = minf(_min_frac, f)
	if f < FRAC_MIN:
		_low_frac += 1


## Fracao (area) do retangulo projetado do AABB visual do heroi que cai dentro do quadro, no pior aspecto.
func _hero_fraction(cam: Camera3D, hero: Node3D) -> float:
	var box := AABB()
	var first := true
	for n in hero.find_children("*", "VisualInstance3D", true, false):
		var vi := n as VisualInstance3D
		if not vi.is_visible_in_tree():
			continue
		var b := vi.global_transform * vi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		return 0.0
	var inv := cam.global_transform.affine_inverse()
	var ty := tan(deg_to_rad(cam.fov) * 0.5)
	var worst := 1.0
	for aspect in ASPECTS:
		var mn := Vector2(INF, INF)
		var mx := Vector2(-INF, -INF)
		for i in 8:
			var p := inv * box.get_endpoint(i)
			if p.z > -0.05:
				return 0.0
			var q := Vector2(p.x / -p.z / (ty * aspect), p.y / -p.z / ty)
			mn = mn.min(q)
			mx = mx.max(q)
		var area := (mx.x - mn.x) * (mx.y - mn.y)
		var vis := (clampf(mx.x, -1, 1) - clampf(mn.x, -1, 1)) * (clampf(mx.y, -1, 1) - clampf(mn.y, -1, 1))
		worst = minf(worst, vis / maxf(area, 0.0001))
	return worst


## Ponto de chao a 0,45 m de uma parede (camada 1) perto de `c`: [posicao, normal da parede] (como test_camera_wall).
func _wall_spot(c: Vector3) -> Variant:
	var space := main.world.get_world_3d().direct_space_state
	for ring: float in [2.0, 3.5, 5.0]:
		for i in 12:
			var p := c + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 12.0) * ring
			var f := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 3, 0), p + Vector3(0, -3, 0), 1))
			if f.is_empty() or absf((f["position"] as Vector3).y - c.y) > 0.5:
				continue
			var g: Vector3 = f["position"]
			for k in 8:
				var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 8.0)
				var q := PhysicsRayQueryParameters3D.create(g + Vector3(0, 1.0, 0), g + Vector3(0, 1.0, 0) + dir * 1.5, 1)
				q.exclude = main.camera_rig.exclude
				var h := space.intersect_ray(q)
				if h.is_empty():
					continue
				var n: Vector3 = h["normal"]
				if absf(n.y) > 0.3:
					continue
				var hp: Vector3 = h["position"]
				var stand := Vector3(hp.x, g.y, hp.z) + Vector3(n.x, 0, n.z).normalized() * 0.45
				return [stand + Vector3(0, 0.05, 0), Vector3(n.x, 0, n.z).normalized()]
	return null


func _push(dir: Vector3) -> void:
	var local := Basis(Vector3.UP, -main.camera_rig.yaw) * dir.normalized()
	for pair: Array in [[&"move_right", local.x], [&"move_left", -local.x], [&"move_down", local.z], [&"move_up", -local.z]]:
		if float(pair[1]) > 0.01:
			Input.action_press(pair[0] as StringName, float(pair[1]))
		else:
			Input.action_release(pair[0] as StringName)


func _release() -> void:
	for a: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"run"]:
		Input.action_release(a)
