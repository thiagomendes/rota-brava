@tool
extends EditorScenePostImport
## Pos-importacao dos GLB PBR dos herois v2 (RB-R1 D11/D13, PROPOSTA PROVISORIA; hoje so o rastro_v2.glb usa).
## A Godot 4.7 importa base color, normal, ORM (oclusao/rugosidade/metalico) e alpha do glTF, mas:
##  1) texturas EMBUTIDAS no GLB chegam sem mipmap (cintilam a distancia) -> aqui geramos os mipmaps;
##  2) ignora KHR_materials_clearcoat -> aqui lemos o verniz do proprio GLB e ligamos clearcoat no StandardMaterial3D.
## Assim o heroi abre igual na Godot e num visualizador web (que ja le essas duas coisas do glTF).
## Ligado pelo .import do GLB: import_script/path="res://lookdev/gltf_pbr_import.gd" e gltf/embedded_image_handling=3.


func _post_import(scene: Node) -> Object:
	var coats := read_clearcoat(get_source_file())
	var done := {}
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i) as StandardMaterial3D
			if m == null or done.has(m):
				continue
			done[m] = true
			finish_material(m, coats)
	return scene


## Gera mipmaps nas texturas do material e aplica o verniz lido do glTF (pelo nome do material).
static func finish_material(m: StandardMaterial3D, coats: Dictionary) -> void:
	var cache := {}
	for prop in ["albedo_texture", "normal_texture", "roughness_texture", "metallic_texture", "ao_texture", "emission_texture"]:
		var t := m.get(prop) as Texture2D
		if t == null:
			continue
		if not cache.has(t):
			cache[t] = with_mipmaps(t)
		m.set(prop, cache[t])
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if coats.has(m.resource_name):
		var c: Array = coats[m.resource_name]
		m.clearcoat_enabled = float(c[0]) > 0.0
		m.clearcoat = float(c[0])
		m.clearcoat_roughness = float(c[1])


static func with_mipmaps(t: Texture2D) -> Texture2D:
	var img := t.get_image()
	if img == null or img.has_mipmaps():
		return t
	img = img.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.generate_mipmaps()
	var out := ImageTexture.create_from_image(img)
	out.resource_name = t.resource_name
	return out


## Le o bloco JSON do GLB e devolve {nome_do_material: [clearcoatFactor, clearcoatRoughnessFactor]}.
static func read_clearcoat(path: String) -> Dictionary:
	var out := {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	if f.get_32() != 0x46546C67:   # "glTF"
		return out
	f.get_32()
	f.get_32()
	var json_len := f.get_32()
	f.get_32()   # tipo do bloco (JSON)
	var data: Variant = JSON.parse_string(f.get_buffer(json_len).get_string_from_utf8())
	if not (data is Dictionary):
		return out
	for mat: Dictionary in (data as Dictionary).get("materials", []):
		var ext: Dictionary = mat.get("extensions", {})
		if ext.has("KHR_materials_clearcoat"):
			var cc: Dictionary = ext["KHR_materials_clearcoat"]
			out[String(mat.get("name", ""))] = [float(cc.get("clearcoatFactor", 0.0)), float(cc.get("clearcoatRoughnessFactor", 0.0))]
	return out
