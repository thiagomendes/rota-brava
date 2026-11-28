extends RefCounted
## RB-R1 G24a2 v2 (revisao): ciclo de vida do pontilhado no Ep01 v3.
##  - M4 -> M5: o carrinho dirigivel pontilhado e liberado pelo land.build; nenhuma peca liberada fica nas listas e o
##    update roda inteiro a cada quadro (no 7ee3f0d o carrinho velho ficava na lista e o update abortava com
##    SCRIPT ERROR a cada quadro);
##  - antes do land.build, na troca de heroi e durante a cena: nada pontilhado.
## Mede estado (nao o log); o log da suite e conferido a parte (grep "SCRIPT ERROR").

var r
var main: Ep01V3Main


func run(runner) -> void:
	r = runner
	# 0) noite/festa: a variante nasce de dia e, na troca (`sync`), copia o brilho atual da base.
	var lit := WV2Materials.get_material("wv2_interior_lit") as ShaderMaterial
	var paper := WV2Materials.get_material("wv2_paper") as ShaderMaterial
	WV2Materials.set_night(false)
	WV2Materials.set_festival(false)
	var vl := WV2Materials.occl_variant(lit) as ShaderMaterial
	var vp := WV2Materials.occl_variant(paper) as ShaderMaterial
	WV2Materials.set_night(true)
	WV2Materials.set_festival(true)
	WV2Materials.occl_variant(lit, true)
	WV2Materials.occl_variant(paper, true)
	r.check(vl != lit and vl.get_shader_parameter("emission_energy") == lit.get_shader_parameter("emission_energy")
		and vp.get_shader_parameter("glow") == paper.get_shader_parameter("glow"),
		"vida: variante trocada a noite/festa tem o brilho da base (%s = %s)" % [vl.get_shader_parameter("emission_energy"), lit.get_shader_parameter("emission_energy")])
	WV2Materials.set_night(false)
	WV2Materials.set_festival(false)
	r.check(WV2Materials.occl_variant(WV2Materials.get_material("wv2_lamp")) == WV2Materials.get_material("wv2_lamp"),
		"vida: StandardMaterial3D (wv2_lamp) fica sem variante")
	Ep01V3Main.start_mission = &"M4"
	Ep01V3Main.save_path = ""
	Ep01V3Cutscene.seen_path = ""
	var was_enabled := Ep01V3Cutscene.enabled
	Ep01V3Cutscene.enabled = false
	main = (load("res://episodes/ep01/v3/ep01_v3_main.tscn") as PackedScene).instantiate() as Ep01V3Main
	r.tree.root.add_child(main)
	r.tree.current_scene = main
	await r.frames(3)
	var rig := main.camera_rig
	var occ: Variant = rig.occlusion
	r.check(occ != null, "vida: oclusao ligada")
	# 1) carrinho do M4 pontilhado (camera e heroi em volta dele)
	var cart: Node3D = main.land.cart
	r.check(cart != null and is_instance_valid(cart), "vida: carrinho do M4 montado")
	var c := cart.global_position
	occ.update(c + Vector3(0, 1.0, 3.0), c + Vector3(0, 0, -1.5), 0.0, true)
	var dyn_active: Dictionary = occ.get("_dyn_active")
	r.check(dyn_active.size() >= 1, "vida: carrinho do M4 pontilhado (%d)" % dyn_active.size())
	# 2) M4 -> M5: land.build libera o carrinho
	var u0: int = int(occ.get("updates")) if occ.get("updates") != null else 0
	main._start_mission(main._index_of(&"M5"))
	r.check(int(occ.get("swapped_now")) == 0 and (occ.get("_dyn_active") as Dictionary).is_empty(),
		"vida: antes do land.build tudo volta ao normal (%d trocadas)" % int(occ.get("swapped_now")))
	for i in 40:
		await r.tree.physics_frame
	var stale := 0
	for n: Variant in (occ.get("_dyn") as Array):
		if not is_instance_valid(n):
			stale += 1
	for k: Variant in (occ.get("_dyn_active") as Dictionary):
		if not is_instance_valid(((occ.get("_dyn_active") as Dictionary)[k] as Dictionary)["node"]):
			stale += 1
	r.check(stale == 0, "vida: M4 -> M5 sem peca liberada nas listas (%d)" % stale)
	var u1: int = int(occ.get("updates")) if occ.get("updates") != null else 0
	r.check(u1 - u0 >= 38, "vida: o update roda inteiro em todo quadro depois do M5 (%d de 40)" % (u1 - u0))
	# 3) troca de heroi: peca do kit pontilhada volta ao normal
	var crate := Vector3(-15.05, 0.3, -15.55)  # caixote do kit (layout `crate`), camera dentro dele
	occ.update(crate, crate + Vector3(0, -0.3, -2.0), 0.0, true)
	var before := int(occ.get("swapped_now"))
	var other: MemberActor = main.actors[&"climber"] if main.controlled_node != main.actors[&"climber"] else main.actors[&"pilot"]
	main.set_controlled(other)
	r.check(before > 0 and int(occ.get("swapped_now")) == 0, "vida: troca de heroi devolve as pecas (%d -> %d)" % [before, int(occ.get("swapped_now"))])
	# 4) cena: o rig nao pontilha enquanto a cena roda
	Ep01V3Cutscene.enabled = true
	occ.update(crate, crate + Vector3(0, -0.3, -2.0), 0.0, true)
	main.play_cutscene(&"m2_intro")
	var during := 0
	var max_swapped := 0
	for i in 30:
		await r.tree.physics_frame
		if main.cutscene.playing:
			during += 1
			max_swapped = maxi(max_swapped, int(occ.get("swapped_now")))
	r.check(during > 10 and max_swapped == 0, "vida: durante a cena nada pontilha (%d quadros de cena, max %d)" % [during, max_swapped])
	Ep01V3Cutscene.enabled = was_enabled
	main.queue_free()
	await r.frames(2)
	r.tree.current_scene = null
