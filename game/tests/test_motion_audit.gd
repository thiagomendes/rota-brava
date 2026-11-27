extends RefCounted
## RB-R1 G24d: auditoria dinamica de interpenetracao (tests/motion_audit.gd) na partida completa do bot M0->M8 com
## entrada real. Imprime o inventario inteiro (quadro, missao, par, profundidade) e falha em corda ou barco atravessando
## geometria (G24b/G24c) e em qualquer par fora da lista KNOWN (pendencias com dono, no ticket). Geometrico: nao comprova
## render.

const TIME_SCALE := 8.0
const MAX_FRAMES := 40000
## Pendencias aceitas por enquanto: [missao ("*" = qualquer), prefixo do movente, prefixo do outro, teto (cm), dono].
## Teto = a maior profundidade medida nas rodadas do G24 + 5 cm: passar dele falha. Cada uma esta no ticket (G24d, "o que
## sobrou") com a causa. Par fora da lista falha; entrada que nao casou com nada e avisada (para a lista nao apodrecer).
const KNOWN := [
	["*", "char:", "kit:pot_a#0", 23, "art3d"],          # vaso sem colisao na camada 1 (praca)
	["*", "char:", "kit:bucket#", 21, "art3d"],          # balde sem colisao na camada 1 (cais)
	["M1", "piece:CaptainBoot", "static", 19, "gameplay"],  # pick_up da bota afunda no cais
	["M2", "char:", "static", 25, "gameplay"],           # escalada do galpao/arvore encosta na parede
	["M2", "char:", "mission:Cloth", 22, "gameplay"],    # heroi passa pela roupa pendurada/no chao
	["M2", "char:", "mission:ClothesBench", 20, "gameplay"],   # pulinho no banco
	["M2", "char:", "mission:Basket", 18, "gameplay"],   # abaixar no cesto
	["M2", "piece:Cloth", "mission:ClothesBench", 29, "gameplay"],   # roupa na mao passa pelo banco
	["M2", "piece:Cloth", "kit:barrel#4", 12, "gameplay"],
	["M2", "piece:Cloth", "kit:bush_", 12, "gameplay"],
	["M2", "piece:Cloth", "static", 21, "gameplay"],     # roupa na mao rente ao galpao
	["M3", "char:Actor_climber", "mission:Leaves", 20, "gameplay"],   # agarrar o bolo de folhas
	["M4", "piece:cart", "kit:stall_", 64, "gameplay"],  # carrinho sem colisao propria atravessa barracas
	["M4", "piece:cart", "kit:crate", 33, "gameplay"],   # ... e caixotes
	["M4", "piece:cart", "mission:Cart/Cargo/", 36, "gameplay"],   # carrinho x caixinhas pousadas
	["M4", "char:", "mission:Cart", 46, "gameplay"],     # herois passam pelo carrinho parado e a carga
	["M4", "piece:Box", "mission:Cart", 9, "gameplay"],
	["M5", "char:Actor_climber", "mission:Gull", 23, "gameplay"],   # gaivota pousada colada no telhado
	["M5", "char:Actor_climber", "static", 20, "gameplay"],         # escalada dos caixotes/toldo
	["M6", "char:Actor_pilot", "boat", 40, "gameplay"],  # pulinho de embarque atravessa a borda
	["M7", "piece:Lens", "static", 27, "gameplay"],      # lente na mao na escalada da torre
	["M7", "char:Actor_climber", "static", 25, "gameplay"],   # escalada dos patamares
	["M7", "piece:HandCompass", "kit:bush_", 31, "gameplay"],  # bussola na mao rente a moita
	["M7", "char:", "mission:HandCompass", 22, "gameplay"],
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
	var over: Array[String] = []
	var used: Array[int] = []
	used.resize(KNOWN.size())
	for h in audit.rows():
		if h["kind"] in ["rope", "boat"]:
			continue
		var hit := -1
		for i in KNOWN.size():
			var k: Array = KNOWN[i]
			if (k[0] == "*" or k[0] == h["mission"]) and String(h["mover"]).begins_with(k[1]) \
					and String(h["other"]).begins_with(k[2]):
				hit = i
				break
		if hit < 0:
			other.append(MotionAudit.line(h))
			continue
		used[hit] += 1
		if float(h["depth"]) * 100.0 > float(KNOWN[hit][3]):
			over.append("%s (teto %d cm)" % [MotionAudit.line(h), KNOWN[hit][3]])
	for i in KNOWN.size():
		if used[i] == 0:
			print("[RB] G24d AVISO: pendencia conhecida nao apareceu nesta rodada (tirar da lista se sumiu de vez): ", KNOWN[i])
	r.check(over.is_empty(), "G24d: pendencias conhecidas dentro do teto (%d acima): %s" % [over.size(), "; ".join(over)])
	r.check(other.is_empty(), "G24d: nenhum par novo fora da lista de pendencias (%d): %s" % [other.size(), "; ".join(other)])
	Ep01V3Main.start_mission = &""
	audit.queue_free()
	main.queue_free()
	await r.frames(2)
	r.tree.current_scene = null
	r.tree.paused = false
