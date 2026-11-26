extends RefCounted
## RB-R1 G9: no fim da conversa da ponte (antes da cena seguinte) nenhuma seguidora fica no alto. Repete o relato do
## bot: a Leme no telhado do M5 (y ~2,9) com a Rastro no chao da rua; a ponte M5>M6 termina. Confere que antes da cena
## toda seguidora esta a <= 0,6 m da altura do lider e alcanca o lider pela navegacao do bot. Nao comprova imagem.

const ROOF := Vector3(-19.36, 2.95, -19.50)  # posicao medida da Leme presa (log da falha "sem caminho em M6")
const STREET := Vector3(-14.16, 0.05, -15.25)

var r


func run(runner) -> void:
	r = runner
	Ep01V3Cutscene.enabled = false
	var main := (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	r.tree.root.add_child(main)
	r.tree.current_scene = main
	await r.frames(3)
	main.set_followers_enabled(false)
	var lead := main.controlled_node as MemberActor
	var leme := main.actors[&"pilot"] as MemberActor
	lead.teleport(STREET)
	leme.teleport(ROOF)
	(main.actors[&"climber"] as MemberActor).teleport(STREET + Vector3(1.1, 0, 0.5))
	await r.frames(20)
	r.check(leme.global_position.y > 2.5 and lead.is_on_floor(),
		"G9 ponte: a Leme comeca no telhado do M5 (y %.2f), lider no chao" % leme.global_position.y)
	main.hud.clear_speech()
	main.set_followers_enabled(true)
	# Fim da ponte M5>M6: o mesmo caminho do jogo (espera da conversa -> reagrupar -> cenas -> missao seguinte).
	var heights: Dictionary = {}
	main.mission_started.connect(func(_id: StringName) -> void:
		for m: StringName in main.actors:
			heights[m] = (main.actors[m] as Node3D).global_position, CONNECT_ONE_SHOT)
	var queue: Array[StringName] = []
	await main._cutscene_run(queue, main._index_of(&"M6"))
	var nav := Ep01V3Nav.new()
	nav.build(main.world.get_world_3d().direct_space_state)
	var lead_p := lead.global_position
	var bad: Array[String] = []
	for m: StringName in main.actors:
		var a := main.actors[m] as MemberActor
		if a == lead:
			continue
		var p: Vector3 = heights.get(m, a.global_position)
		if absf(p.y - lead_p.y) > 0.6:
			bad.append("%s alto (y %.2f, lider %.2f)" % [m, p.y, lead_p.y])
		elif nav.route(p, lead_p, 0.5).is_empty():
			bad.append("%s sem caminho ate o lider de %s" % [m, p])
	r.check(heights.size() == main.actors.size() and bad.is_empty(),
		"G9 ponte: antes da missao seguinte toda seguidora no chao e alcancavel %s" % str(bad))
	Ep01V3Cutscene.enabled = true
	r.tree.current_scene = null
	main.queue_free()
	await r.frames(3)
