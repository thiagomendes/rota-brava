extends RefCounted
## RB-R1 G24a2 (guarda da injecao, art3d): para cada shader wv2 da biblioteca, o codigo comeca com `shader_type`, tem
## exatamente um `void fragment() {`, a variante pontilhada contem `occl_discard` e compila (no servidor de render do
## modo headless a compilacao com erro devolve lista de uniformes vazia; a variante tem os mesmos uniformes da base).

const SHADERS: Array[String] = ["wv2_surface", "wv2_triplanar", "wv2_grass", "wv2_terrain", "wv2_paper", "wv2_beam"]


func run(r) -> void:
	for n in SHADERS:
		var sh := load("res://lookdev/world_v2/%s.gdshader" % n) as Shader
		r.check(sh != null and sh.code.begins_with("shader_type"), "shaders oclusao %s: comeca com shader_type" % n)
		r.check(sh.code.count("void fragment() {") == 1, "shaders oclusao %s: um so 'void fragment() {' (%d)" % [n, sh.code.count("void fragment() {")])
		var base := ShaderMaterial.new()
		base.shader = sh
		var v := WV2Materials.occl_variant(base) as ShaderMaterial
		r.check(v != null and v != base and v.shader.code.contains("occl_discard("), "shaders oclusao %s: variante injetada" % n)
		var nb := sh.get_shader_uniform_list().size()
		var nv := v.shader.get_shader_uniform_list().size() if v != null else -1
		r.check(nb > 0 and nv == nb, "shaders oclusao %s: variante compila (%d uniformes, base %d)" % [n, nv, nb])
