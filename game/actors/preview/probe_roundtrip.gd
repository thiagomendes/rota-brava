extends SceneTree
## Sonda da ida e volta (RB-03-art): imprime medidas do Rastro importado e o hash da cena propria.
## ./tools/godot.ps1 --headless --path game --script res://actors/preview/probe_roundtrip.gd

func _initialize() -> void:
	var t := load("res://tests/test_assets.gd")
	var rs := (load("res://actors/rastro/rastro.tscn") as PackedScene).instantiate() as Node3D
	var model := rs.find_child("Model", false, false) as Node3D
	var box: AABB = t.mesh_aabb(model)
	var hat: AABB = t.part_aabb(model, "Rastro_Hat")
	var bt := (load("res://actors/boat_model/boat_model.tscn") as PackedScene).instantiate() as Node3D
	var hull := bt.find_child("Boat_Hull", true, false) as MeshInstance3D
	var c := (hull.mesh.surface_get_material(0) as BaseMaterial3D).albedo_color
	print("PROBE rastro_altura_m=%.4f chapeu_topo_y=%.4f chapeu_altura_m=%.4f casco_cor=#%s" % [box.size.y, hat.end.y, hat.size.y, c.to_html(false)])
	print("PROBE rastro.tscn sha256=", FileAccess.get_sha256("res://actors/rastro/rastro.tscn"))
	print("PROBE boat_model.tscn sha256=", FileAccess.get_sha256("res://actors/boat_model/boat_model.tscn"))
	print("PROBE rastro.glb sha256=", FileAccess.get_sha256("res://assets/models/rastro.glb"))
	quit()
