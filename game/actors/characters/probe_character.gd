extends SceneTree
## Sonda de importacao dos personagens (RB-04-chars): imprime ossos, animacoes, loops e blend shapes. Nao e teste.
## ./tools/godot.ps1 --headless --path game --script res://actors/characters/probe_character.gd


func _init() -> void:
	for id in ["rastro_model", "extra_a"]:
		var root := (load("res://actors/characters/%s.tscn" % id) as PackedScene).instantiate()
		get_root().add_child(root)
		var vis := root.find_child("Model", false, false) as CharacterVisual
		var sk := vis.skeleton()
		var bones: Array = []
		for i in sk.get_bone_count():
			bones.append(sk.get_bone_name(i))
		print("PROBE ", id, " ossos=", sk.get_bone_count(), " ", bones)
		for a in vis.animation_names():
			print("PROBE anim ", a, " len=", vis.animation_length(StringName(a)), " loop=", vis.is_looping(StringName(a)))
		var face := vis.face_mesh()
		var shapes: Array = []
		for i in face.mesh.get_blend_shape_count():
			shapes.append(face.mesh.get_blend_shape_name(i))
		print("PROBE shapes=", shapes)
		var tree_names: Array = []
		for n in root.find_children("*", "", true, false):
			tree_names.append(n.name)
		print("PROBE nos=", tree_names)
		vis.seek_clip(&"walk", 0.0)
		print("PROBE lowest_foot_height walk@0=", vis.lowest_foot_height())
		root.queue_free()
	quit()
