extends RefCounted
## RB-R1 G24a2 v2 (estrutura colide, peca pontilha): correndo rente a caixotes, carrinho, bancos e paredes da vila v3
## (desvio ligado, camera girada 0,6 rad contra a parede, entrada real pela Input Map), em modo normal e com movimento
## reduzido. Em todo passo de fisica (fora os 2 primeiros depois de cada teleporte do heroi) mede:
##  - salto da camera no quadro (<= STEP_MAX m);
##  - camera dentro da ESTRUTURA (esfera de 0,1 m na mascara/`exclude` do rig, que ja nao tem as pecas): nunca;
##  - camera dentro de PECA (esfera na camada 1 com so as paredes invisiveis fora, ou dentro de copa): so com a peca
##    pontilhada (`CameraOcclusion.piece_contains`), senao conta como vista tapada sem pontilhado;
##  - vista tapada: raio da camera ao centro do heroi na camada 1 INTEIRA (estrutura e pecas; so agua/limites/rampas
##    fora) ou cruzando copa. So vale se o ponto que tapa esta no pontilhado (`CameraRig.occlusion_covers`, mesma
##    conta do shader); nos OCCL_TIME s depois de tapar conta como entrada do fade;
##  - heroi no quadro (AABB visual, pior entre 16:9 e 4:3) >= FRAC_MIN;
##  - altura da camera acima do heroi <= RISE_LIM (nao sobe em telhado/toldo);
##  - trocas do pontilhado e custo da troca (malhas por quadro, us de CPU), so medidos.
## Roda tambem contra o rig da integracao (sem pontilhado): la toda vista tapada conta como sem pontilhado.
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
## Rig da integracao (5cef201), medido por este teste: [normal, reduzido]. Estrutura nao pode piorar (G24a3 decide).
const BASE_JUMP: Array[float] = [3.32, 3.73]
const BASE_INSIDE: Array[int] = [149, 146]
const BASE_FRAC: Array[float] = [0.081, 0.301]
## Vista tapada pela estrutura: integracao 0/1. No reduzido vale 16 medido + folga 4 (decisao do lead, G24a2): a mola
## suave no reduzido tira o salto de 3,32 m (reduzido sem salto vale mais que alguns quadros com a mureta
## `Structures/31` do M4 tapando a vista enquanto o braco volta). O caso fica para o G24a3.
const BASE_STRUCT_VIEW: Array[int] = [0, 20]
const RISE_LIM := 2.7  # pedido do G24a2: camera nunca mais de 2,7 m acima do heroi

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
var _mid_fade := 0
var _uncovered_struct := 0
var _uncovered_piece := 0
## Depuracao: RB_OCCL_TRACE=<prefixo do rotulo> imprime cada passo desse trecho.
var _trace := OS.get_environment("RB_OCCL_TRACE")
var _low_at: Array[String] = []
var _jump_at: Array[String] = []
var _inside_at: Array[String] = []
var _piece_inside := 0


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
		_mid_fade = 0
		_uncovered_struct = 0
		_uncovered_piece = 0
		_low_at.clear()
		_jump_at.clear()
		_inside_at.clear()
		_piece_inside = 0
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
		print("  medida oclusao custo (%s): %d trocas de material no percurso (max %d num quadro), max %d malhas pontilhadas ao mesmo tempo; CPU da atualizacao media %.0f us, p99 %d us, max %d us, pior quadro na etapa %s (GPU no celular nao medida)" % [
			"reduzido" if reduced else "normal", _swaps, _swap_max, _swapped_max, us_avg, us[int(us.size() * 0.99)] if us.size() > 0 else 0, us[-1] if us.size() > 0 else 0, main.camera_rig.occlusion.usec_max_stage if main.camera_rig.occlusion != null else "-"])
		print("  medida oclusao (%s): %d paredes, %d passos; salto max %.2f m/quadro, p99 %.3f; camera dentro da estrutura %d, dentro de peca pontilhada %d; vista tapada %d passos (%d entrando no fade, %d sem pontilhado: %d por peca, %d pela estrutura %s); heroi no quadro min %.1f%% (%d < %.0f%%); pontilhado liga/desliga %.2f/s" % [
			tag, walls, _ticks, top, p99, _inside, _piece_inside, _blocked, _fading, _uncovered.size(), _uncovered_piece, _uncovered_struct, _uncovered.slice(0, 3), _min_frac * 100.0, _low_frac, FRAC_MIN * 100.0, _toggles / secs])
		r.check(walls >= 4 and _ticks > 800, "oclusao %s: %d paredes e %d passos" % [tag, walls, _ticks])
		var mi := 1 if reduced else 0
		# PECAS (G24a2, rigido): nada tapa o heroi sem pontilhado.
		r.check(_uncovered_piece == 0, "oclusao %s: vista tapada por PECA so com pontilhado (%d passos sem %s)" % [tag, _uncovered_piece, _uncovered.slice(0, 6)])
		# ESTRUTURA (G24a3, sem regressao): nenhuma medida pior que no rig da integracao (5cef201, medido com este teste).
		r.check(top <= BASE_JUMP[mi] + 0.005, "oclusao %s: salto max %.2f m <= integracao %.2f (meta G24a3 %.2f) %s" % [tag, top, BASE_JUMP[mi], STEP_MAX, _jump_at])
		r.check(_inside <= BASE_INSIDE[mi], "oclusao %s: camera dentro da estrutura %d <= integracao %d (meta G24a3 0) %s" % [tag, _inside, BASE_INSIDE[mi], _inside_at])
		r.check(_min_frac >= BASE_FRAC[mi] - 0.002, "oclusao %s: heroi no quadro min %.1f%% >= integracao %.1f%% (meta G24a3 %.0f%%) %s" % [tag, _min_frac * 100.0, BASE_FRAC[mi] * 100.0, FRAC_MIN * 100.0, _low_at])
		r.check(_uncovered_struct <= BASE_STRUCT_VIEW[mi], "oclusao %s: vista tapada pela estrutura %d <= integracao %d" % [tag, _uncovered_struct, BASE_STRUCT_VIEW[mi]])
		var rise_lim := RISE_LIM
		var occ: Variant = main.camera_rig.get(&"occlusion")
		if occ != null:
			var consts: Dictionary = (occ.get_script() as Script).get_script_constant_map()
			r.check(is_equal_approx(float(consts["FADE_TIME"]), OCCL_TIME) and is_equal_approx(float(consts["CENTER_Y"]), OCCL_CENTER_Y),
				"oclusao %s: copias dos valores do pontilhado conferem" % tag)
			r.check(_toggles_on_reduced_ok(reduced), "oclusao %s: movimento reduzido sem fade animado (%d quadros no meio do fade)" % [tag, _mid_fade])
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
	var occ: Variant = rig.get(&"occlusion")
	_ticks += 1
	if _last_cam != Vector3.INF:
		_steps.append(cam.distance_to(_last_cam))
		if cam.distance_to(_last_cam) > STEP_MAX and _jump_at.size() < 6:
			_jump_at.append("%s %.2f" % [label, cam.distance_to(_last_cam)])
	_last_cam = cam
	var space := main.world.get_world_3d().direct_space_state
	# Estrutura: o que o rig desvia (mascara e exclude dele).
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _sphere
	q.transform = Transform3D(Basis(), cam)
	q.collision_mask = rig.collision_mask
	q.exclude = rig.exclude
	var struct_hit := space.intersect_shape(q, 1)
	if not struct_hit.is_empty():
		_inside += 1
		if _inside_at.size() < 4:
			_inside_at.append("%s %s/%d" % [label, (struct_hit[0]["collider"] as Node).name, int(struct_hit[0]["shape"])])
	# Tudo que e solido para a vista: camada 1 sem as paredes invisiveis (agua, limites, rampas).
	var solid: Array[RID] = _solid_exclude()
	q.collision_mask = 1
	q.exclude = solid
	var in_piece := struct_hit.is_empty() and not space.intersect_shape(q, 1).is_empty()
	for o in rig.occluders:
		if cam.distance_to(Vector3(o.x, o.y, o.z)) < o.w - CAM_RADIUS:
			in_piece = true
	var center := hero.global_position + Vector3(0, OCCL_CENTER_Y, 0)
	var ray := PhysicsRayQueryParameters3D.create(cam, center, 1, solid)
	var hit := space.intersect_ray(ray)
	var hit_pos: Variant = null if hit.is_empty() else hit["position"]
	var canopy: Variant = _canopy_entry(rig.occluders, cam, center)
	if canopy != null and (hit_pos == null or cam.distance_to(canopy as Vector3) < cam.distance_to(hit_pos as Vector3)):
		hit_pos = canopy
	var covered := false
	if in_piece:
		if occ != null and occ.piece_contains(cam):
			_piece_inside += 1
			covered = true
	var blocked := hit_pos != null or (in_piece and not covered)
	if blocked != _was:
		_toggles += 1
		_was = blocked
		_since_block = 0.0
	_since_block += 1.0 / Engine.physics_ticks_per_second
	if blocked:
		_blocked += 1
		var ok: bool = (not in_piece or covered) and (hit_pos == null or (rig.has_method(&"occlusion_covers") and rig.occlusion_covers(hit_pos as Vector3)))
		if not ok:
			if _since_block <= OCCL_TIME + 0.02 and not rig.reduced_motion:
				_fading += 1
			elif _since_block <= 2.5 / Engine.physics_ticks_per_second and rig.reduced_motion:
				_fading += 1  # reduzido: liga no quadro seguinte ao que tapou
			else:
				_uncovered.append(label + ("" if hit.is_empty() else " %s/%d" % [(hit["collider"] as Node).name, int(hit["shape"])])
					+ (" copa" if canopy != null and hit_pos == canopy else "") + (" dentro" if in_piece else "")
					+ ("" if occ == null else " em %s peca=%s trocadas=%d" % [hit_pos, occ.is_piece_point(hit_pos as Vector3) if hit_pos != null else false, occ.swapped_now]))
				var piece_view: bool = in_piece or (canopy != null and hit_pos == canopy) or (not hit.is_empty() and _is_piece_hit(hit))
				if piece_view:
					_uncovered_piece += 1
				else:
					_uncovered_struct += 1
	_rise_max = maxf(_rise_max, cam.y - hero.global_position.y)
	if occ != null:
		_swaps += occ.swaps_frame
		_swap_max = maxi(_swap_max, occ.swaps_frame)
		_swapped_max = maxi(_swapped_max, occ.swapped_now)
		_usec.append(occ.usec_frame)
		if rig.reduced_motion and occ.mid_fade() > 0:
			_mid_fade += 1
	var f := _hero_fraction(rig.camera, hero)
	if _trace != "" and label.begins_with(_trace):
		print("  trace %s cam %s heroi %s d %.2f quadro %.0f%% estrutura %d peca %s tapa %s pull %.2f trocadas %d" % [label, cam, hero.global_position,
			cam.distance_to(hero.global_position), f * 100.0, 1 if not struct_hit.is_empty() else 0, in_piece,
			"-" if hit.is_empty() else "%s/%d" % [(hit["collider"] as Node).name, int(hit["shape"])], rig.last_pull,
			occ.swapped_now if occ != null else -1])
		var pv: Vector3 = hero.global_position + rig.look_offset
		var hh := space.intersect_ray(PhysicsRayQueryParameters3D.create(pv, pv + (cam - pv).normalized() * 5.0, rig.collision_mask, rig.exclude))
		if not hh.is_empty():
			print("    braco bate em %s/%d a %.2f m, normal %s" % [(hh["collider"] as Node).name, int(hh["shape"]), pv.distance_to(hh["position"]), hh["normal"]])
	_min_frac = minf(_min_frac, f)
	if f < FRAC_MIN:
		_low_frac += 1
		if _low_at.size() < 6:
			_low_at.append("%s %.0f%% d%.2f" % [label, f * 100.0, cam.distance_to(hero.global_position)])


func _toggles_on_reduced_ok(reduced: bool) -> bool:
	return not reduced or _mid_fade == 0


func _solid_exclude() -> Array[RID]:
	var out: Array[RID] = []
	for path: String in ["Collision/WaterLimits", "Collision/MapBounds", "Collision/AccessRamps"]:
		var b := main.world.get_node_or_null(path) as CollisionObject3D
		if b != null:
			out.append(b.get_rid())
	return out


## Primeiro ponto do segmento a -> b dentro de alguma copa (esfera), ou null.
func _canopy_entry(spheres: Array, a: Vector3, b: Vector3) -> Variant:
	var best: Variant = null
	var ab := b - a
	var L := ab.length()
	if L < 0.001:
		return null
	var dir := ab / L
	for o: Vector4 in spheres:
		var c := Vector3(o.x, o.y, o.z)
		var oc := a - c
		var bb := oc.dot(dir)
		var disc := bb * bb - (oc.length_squared() - o.w * o.w)
		if disc < 0.0:
			continue
		if -bb + sqrt(disc) <= 0.0:
			continue  # copa toda atras da camera
		var t := maxf(-bb - sqrt(disc), 0.0)
		if t < L and (best == null or t < a.distance_to(best as Vector3)):
			best = a + dir * t
	return best


## Pancada numa peca: corpo `Props` (kit) ou banco G19. Toldo/banca do galpao, banco da arvore e canteiros voltaram a
## ser estrutura (revisao art3d; G24a3).


func _is_piece_hit(hit: Dictionary) -> bool:
	var body := hit["collider"] as CollisionObject3D
	if body == null:
		return false
	return String(body.name) == "Props" or body.is_in_group(&"g19_bench")


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


## Ponto de chao a 0,45 m de uma parede ou peca (camada 1) perto de `c`: [posicao, normal] (como test_camera_wall).
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
				q.exclude = _solid_exclude()  # pecas e estrutura (como o rig antes do G24a2)
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
