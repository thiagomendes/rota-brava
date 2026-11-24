extends RefCounted
## Integracao do lead no RB-R1: emotes dos dialogos nas legendas, sons de UI, ajuda (H),
## tripulacao no barco e Stylize. Cobre lacunas apontadas pela revisao do RB-04.

var r


func _press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await r.frames()
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await r.frames()


func run(runner) -> void:
	r = runner
	# Stylize: material comum vira o sombreador estilizado, preservando a cor; transparente fica como esta.
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	var std := StandardMaterial3D.new()
	std.albedo_color = Color(0.2, 0.4, 0.6)
	mi.material_override = std
	var holder := Node3D.new()
	holder.add_child(mi)
	Stylize.apply(holder)
	var out := mi.material_override as ShaderMaterial
	r.check(out != null and out.shader == Stylize.SHADER, "Stylize troca StandardMaterial3D pelo sombreador estilizado")
	r.check(out != null and (out.get_shader_parameter("albedo") as Color).is_equal_approx(std.albedo_color), "Stylize preserva a cor")
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = glass
	Stylize.apply(holder)
	r.check(mi.material_override == glass, "Stylize nao mexe em material transparente")
	holder.free()

	# Tripulacao: posicoes distintas sobre o convés do barco v2 (y ~ 0,40) e dentro da largura do casco.
	var seats: Array = BoatActor.CREW.values()
	var distinct := true
	for i in seats.size():
		for j in range(i + 1, seats.size()):
			distinct = distinct and (seats[i] as Vector3).distance_to(seats[j]) > 0.5
	r.check(BoatActor.CREW.size() == 3 and distinct, "tres lugares distintos (> 0,5 m) para a tripulacao")
	var on_deck := true
	for s: Vector3 in seats:
		on_deck = on_deck and absf(s.y - 0.40) < 0.05 and absf(s.x) < 1.0 and s.z > -2.5 and s.z < 2.0
	r.check(on_deck, "tripulacao sobre o convés e dentro do casco")

	# Dialogos: emotes vindos do ep01_dialogue.json aparecem na legenda sem o estagio informar.
	Ep01Main.carry_completed = []
	Ep01Main.start_state = &"dock_investigation"
	var main := (load("res://episodes/ep01/ep01_main.tscn") as PackedScene).instantiate() as Ep01Main
	r.tree.root.add_child(main)
	r.tree.current_scene = main
	await r.frames(3)
	var expected := Ep01Content.line_emotes("ep01.dock.tracker.small_print")
	r.check(expected.size() >= 1, "ep01_dialogue.json traz emotes para a fala da pata")
	var shown: Array = []
	main.hud.emotes_shown.connect(func(_who: StringName, e: Array[StringName]) -> void: shown.append(e))
	main.hud.clear_speech()
	await r.frames(2)
	main.hud.say("ep01.dock.tracker.small_print")
	await r.frames(2)
	r.check(not shown.is_empty() and shown[-1] == expected, "a legenda mostra os emotes do dialogo %s" % str(shown))
	r.check(Ep01Content.radio_key("ep01.dock.tracker.hint_gesture_bench") != "", "dica do Rastro tem fala de radio de Farol 7")

	# Sons de UI: todo nome emitido pelo HUD v2 tem efeito mapeado e existente no catalogo.
	var all_mapped := true
	for k: StringName in Ep01Main.UI_SOUNDS:
		all_mapped = all_mapped and main.audio.has_sound(String(Ep01Main.UI_SOUNDS[k]))
	r.check(all_mapped, "todo som de UI do HUD aponta para um efeito do catalogo")

	# Ajuda (H): 1a vez repete o objetivo; depois avanca as dicas; nao funciona com a pausa aberta.
	main.hud.clear_speech()
	await r.frames(2)
	var said: Array[String] = []
	main.hud.line_started.connect(func(key: String) -> void: said.append(key))
	await _press(&"help")
	await r.frames(2)
	r.check(said.size() >= 1 and said[0] == Ep01Content.objective_key(&"dock_investigation"), "H repete o objetivo primeiro %s" % str(said))
	r.check(main.help_level == 1, "nivel de ajuda avanca")
	main.hud.clear_speech()
	await r.frames(2)
	said.clear()
	await _press(&"help")
	await r.frames(2)
	var hint_keys: Array[String] = []
	for h: Dictionary in Ep01Content.hints(&"dock_investigation"):
		hint_keys.append(String(h["key"]))
	r.check(said.size() >= 1 and hint_keys.has(said[0]), "H de novo fala uma dica do estagio %s" % str(said))
	await _press(&"pause")
	var before := main.help_level
	await _press(&"help")
	r.check(main.help_level == before, "H nao age com a pausa aberta")
	await _press(&"pause")

	# Radio de Farol 7 repete a instrucao depois do balbucio do personagem (pre-leitores).
	main.hud.clear_speech()
	await r.frames(2)
	said.clear()
	var babble_key := "ep01.dock.tracker.hint_gesture_bench"
	var radio := Ep01Content.radio_key(babble_key)
	main.hud.say(babble_key)
	# Pula so quando a fala do Rastro estiver de fato em exibicao (pode haver uma fala anterior na fila).
	for i in 600:
		if said.has(babble_key) and main._line_key == babble_key:
			break
		if main.hud.is_speaking() and not said.has(babble_key):
			main.hud.skip_line()
		await r.tree.process_frame
	main.hud.skip_line()
	for i in 20:
		await r.tree.process_frame
	r.check(said.has(babble_key) and said.has(radio), "apos a fala do Rastro com instrucao, Farol 7 repete no radio %s" % str(said))
	r.check(main.hud.speaker_name_for(radio) == Loc.member_name(&"radio"), "fala de radio identifica Farol 7 como falante")
	main.hud.clear_speech()

	# Retratos renderizados no HUD para os 5 personagens.
	var missing_portraits: Array[String] = []
	for member: StringName in Ep01Main.PORTRAIT_FILES:
		if main.hud.portrait_texture(member) == null:
			missing_portraits.append(String(member))
	r.check(missing_portraits.is_empty(), "HUD tem retrato renderizado de todos os personagens %s" % str(missing_portraits))

	# Piso dos passos e zonas de som.
	r.check(Ep01Main.surface_at(Vector3(0, 0, 0)) == &"wood", "passo no cais e madeira")
	r.check(Ep01Main.surface_at(Vector3(0, 0, -16)) == &"stone", "passo na rua do porto e pedra")
	r.check(Ep01Main.surface_at(Vector3(200, 0, 0)) == &"sand", "passo na ilha e areia")
	r.check(Ep01Main.surface_at(Vector3(-5, 0, 10)) == &"grass", "passo na margem e grama")
	r.check(Ep01Main.ZONE_BY_STATE.size() == 7, "toda etapa tem zona de ambiente")

	r.tree.paused = false
	main.queue_free()
	await r.frames(2)
	r.tree.current_scene = null
	Ep01Main.start_state = &""
