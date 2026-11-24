class_name EnvMultiMesh
extends MultiMeshInstance3D
## MultiMesh do ambiente (RB-R1): as transformacoes ficam exportadas na cena e o buffer e montado em _ready.
## Motivo: no gerador headless o servidor de render e "dummy" e nao guarda o buffer do MultiMesh ao salvar a cena.

@export var source_mesh: Mesh
@export var xforms: Array[Transform3D] = []


func _ready() -> void:
	build()


func build() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = source_mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	multimesh = mm
