@tool
extends EditorScenePostImport
## Pos-importacao dos GLB do ambiente (RB-04-env): a cor por vertice (COLOR_0, AO e variacao pintadas no Blender)
## precisa multiplicar o albedo. Ligado em cada *.glb.import por tools/export-environment.ps1 (import_script/path).


func _post_import(scene: Node) -> Object:
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var m := mesh.surface_get_material(s) as BaseMaterial3D
			if m != null:
				m.vertex_color_use_as_albedo = true
	return scene

