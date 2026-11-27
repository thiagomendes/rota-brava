extends RefCounted
## RB-R1 G24d: auditoria dinamica de interpenetracao (tests/motion_audit.gd) na partida completa do bot M0->M8 com
## entrada real. Imprime o inventario inteiro (quadro, missao, par, profundidade) e falha em corda ou barco atravessando
## geometria (G24b/G24c) e em qualquer par fora da lista KNOWN (pendencias com dono, no ticket). Geometrico: nao comprova
## render.

const TIME_SCALE := 8.0
const MAX_FRAMES := 40000
## Pendencias aceitas por enquanto: [missao ("*" = qualquer), prefixo do movente, prefixo do outro, dono sugerido].
## Cada uma esta no ticket (G24d, "o que sobrou") com a causa. Par fora desta lista falha o teste.
const KNOWN := [
	["*", "char:", "kit:pot_a", "art3d"],          # vaso sem colisao na camada 1: o heroi passa por dentro (praca, M1/M6/M7)
	["*", "char:", "kit:bucket", "art3d"],         # balde sem colisao na camada 1 (cais)
	["M1", "piece:CaptainBoot", "static", "gameplay"],   # bota pega do chao entra 14 cm no cais no pick_up
	["M2", "char:", "static", "gameplay"],         # escalada do galpao/arvore: o corpo encosta 5-20 cm na parede
	["M2", "char:", "mission:Cloth", "gameplay"],  # heroi passa pela roupa pendurada/no chao
	["M2", "char:", "mission:ClothesBench", "gameplay"],   # pulinho no banco
	["M2", "char:", "mission:Basket", "gameplay"],  # abaixar no cesto
	["M2", "piece:Cloth", "", "gameplay"],         # roupa na mao passa pelo banco, barril e galpao
	["M3", "char:", "mission:Leaves", "gameplay"],  # Pico agarra o bolo de folhas
	["M4", "piece:cart", "", "gameplay"],          # carrinho empurrado atravessa barracas e caixotes (sem colisao propria)
	["M4", "char:", "mission:Cart", "gameplay"],   # herois passam pelo carrinho parado (sem colisao)
	["M4", "piece:Box", "mission:Cart", "gameplay"],
	["M5", "char:Actor_climber", "mission:Gull", "gameplay"],   # gaivota pousada colada no telhado onde o Pico pisa
	["M5", "char:Actor_climber", "static", "gameplay"],         # escalada dos caixotes/toldo
	["M6", "char:Actor_pilot", "boat", "gameplay"],  # pulinho de embarque atravessa a borda do barco
	["M7", "piece:Lens", "static", "gameplay"],      # lente na mao durante a escalada da torre
	["M7", "char:Actor_climber", "static", "gameplay"],   # escalada dos patamares da torre
	["M7", "piece:HandCompass", "", "gameplay"],     # bussola na mao rente a moita
	["M7", "char:", "mission:HandCompass", "gameplay"],
]

var r


func run(runner) -> void:
	r = runner
	# RB_G24_FROM=M5 (so para depurar): comeca na missao dada; a suite roda sempre de M0.
	Ep01V3Main.start_mission = StringName(OS.get_environment("RB_G24_FROM"))
	Ep01V3Main.save_path = ""
	var main := (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	r.tree.root.add_child(main)
	r.tree.current_scene = main
	await r.frames(3)
	var audit := MotionAudit.new()
	audit.main = main
	main.add_child(audit)
	var bot := Ep01V3Bot.new()
	bot.main = main
	main.add_child(bot)
	Engine.time_scale = TIME_SCALE
	var frames := 0
	while not bot.done and frames < MAX_FRAMES:
		await r.tree.process_frame
		frames += 1
	Engine.time_scale = 1.0
	Ep01V3Bot.release_all()
	audit.enabled = false
	r.check(bot.done and bot.fail_reason == "", "G24d: bot terminou M0->M8 com a auditoria ligada (%s)" % bot.fail_reason)
	r.check(audit.frame > 1000, "G24d: auditoria amostrou %d quadros de fisica" % audit.frame)
	print("[RB] G24d custo (us): ", audit.cost)
	print("[RB] G24d inventario (%d pares):\n%s" % [audit.hits.size(), audit.report()])
	var ropes := audit.rows("rope")
	r.check(ropes.is_empty(), "G24b: nenhuma corda atravessa geometria (%d): %s" % [ropes.size(),
		"; ".join(ropes.map(func(h: Dictionary) -> String: return MotionAudit.line(h)))])
	var boats := audit.rows("boat")
	r.check(boats.is_empty(), "G24c: nenhum barco atravessa barco, cais ou pedra (%d): %s" % [boats.size(),
		"; ".join(boats.map(func(h: Dictionary) -> String: return MotionAudit.line(h)))])
	var other: Array[String] = []
	for h in audit.rows():
		if h["kind"] in ["rope", "boat"]:
			continue
		var known := false
		for k: Array in KNOWN:
			known = known or ((k[0] == "*" or k[0] == h["mission"]) and String(h["mover"]).begins_with(k[1])
				and String(h["other"]).begins_with(k[2]))
		if not known:
			other.append(MotionAudit.line(h))
	r.check(other.is_empty(), "G24d: nenhum par novo fora da lista de pendencias (%d): %s" % [other.size(), "; ".join(other)])
	Ep01V3Main.start_mission = &""
	audit.queue_free()
	main.queue_free()
	await r.frames(2)
	r.tree.current_scene = null
	r.tree.paused = false
