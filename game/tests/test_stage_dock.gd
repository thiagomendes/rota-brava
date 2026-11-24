extends RefCounted
## Etapa 1 (Dock): pistas em ambas as ordens, destino, avisos de acao, marcas provisorias e chao.

var r
var _lines: Array[String] = []


func _spawn() -> Ep01Main:
	Ep01Main.start_state = &"dock_investigation"
	var m := (load("res://episodes/ep01/ep01_main.tscn") as PackedScene).instantiate() as Ep01Main
	r.tree.root.add_child(m)
	r.tree.current_scene = m
	await r.frames(3)
	return m


func _drop(m: Ep01Main) -> void:
	m.queue_free()
	await r.frames(2)
	r.tree.current_scene = null
	Ep01Main.start_state = &""


func _order(first: StringName, second: StringName, label: String) -> void:
	var m := await _spawn()
	var dock := m.stages[&"dock_investigation"] as DockStage
	r.check(m.director.state == &"dock_investigation", "%s: comeca em dock_investigation" % label)
	var early := dock.choose_destination(&"bank")
	r.check(not early.accepted and m.director.state == &"dock_investigation",
		"%s: margem sem pistas e rejeitada" % label)
	r.check(dock.examine_clue(first).accepted, "%s: primeira pista aceita" % label)
	var one := dock.choose_destination(&"bank")
	r.check(not one.accepted and m.director.state == &"dock_investigation",
		"%s: margem com so uma pista nao avanca" % label)
	dock.open_destination_choice()
	r.check(not m.hud.choice_open, "%s: com uma pista a escolha nao abre" % label)
	dock.examine_clue(second)
	r.check(m.director.clues_found.size() == 2, "%s: duas pistas guardadas" % label)
	var bad := dock.choose_destination(&"harbor")
	r.check(not bad.accepted and bad.reason == &"wrong_destination" and m.director.state == &"dock_investigation",
		"%s: harbor rejeitado, estado continua" % label)
	var ok := dock.choose_destination(&"bank")
	r.check(ok.accepted and m.director.state == &"river_search", "%s: bank leva a river_search" % label)
	await _drop(m)


func run(runner) -> void:
	r = runner
	await _order(&"paw_print_bench", &"boot_print_bank", "pata->bota")
	await _order(&"boot_print_bank", &"paw_print_bench", "bota->pata")

	var m := await _spawn()
	var dock := m.stages[&"dock_investigation"] as DockStage
	var tracker := m.actors[&"tracker"] as MemberActor

	# Duplicado
	m.hud.line_started.connect(func(k: String) -> void: _lines.append(k))
	dock.examine_clue(&"paw_print_bench")
	var dup := dock.examine_clue(&"paw_print_bench")
	r.check(not dup.accepted and m.director.clues_found.size() == 1, "exame repetido nao duplica a pista")
	await r.frames(3)
	var partial := String(Ep01Content.clue(&"paw_print_bench")["partial_key"])
	r.check(_lines.has(Ep01Content.clue(&"paw_print_bench")["observation_key"]), "a observacao da pata e falada")
	r.check(_lines.has(partial) or m.hud.is_speaking(), "pista parcial gera fala partial_key")
	m.hud.clear_speech()
	await r.frames(2)

	# Pistas marcadas: brilho some
	r.check(not (m.boat.get_node("PawMark/PawMarkGlow") as Node3D).visible, "pista examinada perde o brilho")
	r.check((m.boat.get_node("PawMark") as Node3D).get_child_count() > 0, "a marca da pata existe no barco")

	# Acao contextual
	tracker.teleport(Ep01Layout.BENCH_INTERACT_POS)
	await r.frames(2)
	var near := m.best_interactable()
	r.check(near != null and near.icon == &"paw", "perto do banco o alvo e a pata")
	r.check(m.hud.prompt_visible() and m.hud.prompt_text() == Loc.t("ui.action.examine"), "aviso 'Examinar' perto do banco")
	tracker.teleport(Ep01Layout.BENCH_INTERACT_POS + Vector3(30, 0, 0))
	await r.frames(2)
	r.check(not m.hud.prompt_visible(), "o aviso some ao afastar 30 m")
	tracker.teleport(Ep01Layout.BANK_PRINT_POS)
	await r.frames(2)
	var boot_it := m.best_interactable()
	r.check(boot_it != null and boot_it.icon == &"boot" and boot_it.icon != near.icon, "icones de pata e bota sao distintos")
	r.check(not (m.get_tree().get_nodes_in_group(Ep01Interactable.GROUP).any(
		func(n: Node) -> bool: return (n as Ep01Interactable).action_id == &"choose_destination" and (n as Ep01Interactable).enabled)),
		"'Escolher' fica inativo com uma pista")

	# Provisorios
	var total := 0
	var marked := 0
	for n in dock.find_children("*", "MeshInstance3D", true, false):
		total += 1
		# A marca pode estar na propria malha ou numa cena-mae (as cenas do ambiente marcam a raiz).
		var cursor: Node = n
		while cursor != null and cursor != dock.get_parent():
			if cursor.get_meta(Blocks.PROVISIONAL, false) == true:
				marked += 1
				break
			cursor = cursor.get_parent()
	r.check(total > 10 and marked == total, "todos os blocos do cais sao provisorios (%d/%d)" % [marked, total])

	# Chao
	tracker.teleport(Vector3(2, 0.5, 8))
	for i in 60:
		await r.tree.physics_frame
	r.check(tracker.global_position.y >= -0.5, "Rastro nao cai (y=%.2f)" % tracker.global_position.y)
	tracker.teleport(Vector3(-4, 0.5, 1))
	for i in 60:
		await r.tree.physics_frame
	r.check(tracker.global_position.y >= -0.5, "Rastro nao cai no cais (y=%.2f)" % tracker.global_position.y)
	await _drop(m)
