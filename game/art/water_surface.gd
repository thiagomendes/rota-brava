class_name WaterSurface
extends MeshInstance3D
## Superficie de agua estilizada (ver art/water.gdshader): grande, subdividida para as ondas, na altura Ep01Layout.WATER_Y.

const SHADER := preload("res://art/water.gdshader")


func _init() -> void:
	name = "Water"
	var pm := PlaneMesh.new()
	pm.size = Vector2(340, 160)
	pm.subdivide_width = 170
	pm.subdivide_depth = 80
	mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position = Vector3(55, Ep01Layout.WATER_Y, 0)
	set_meta(Blocks.PROVISIONAL, true)
