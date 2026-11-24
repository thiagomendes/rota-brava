class_name StoryFigure
extends RefCounted
## Figurantes de historia (piloto, filhote) a partir dos modelos finais em `actors/characters/<id>.tscn`.
## Sem corpo fisico: sao cenografia viva e nunca devem travar o barco ou o jogador. `loop` repete um clipe que no GLB
## nao e de laco (ex.: `wave`), ate outro clipe ser pedido.

const DIR := "res://actors/characters/%s.tscn"
const LOOP_META := &"story_loop"


static func spawn(parent: Node, id: String, node_name: String) -> Node3D:
	# Mesmo caminho do MemberActor: so o no `Model` (CharacterVisual) vai para o mundo, com o estilo e o contorno
	# dos personagens; o corpo fisico da cena e descartado.
	var root := Node3D.new()
	root.name = node_name
	parent.add_child(root)
	var inst := (load(DIR % id) as PackedScene).instantiate()
	var m := inst.get_node_or_null("Model")
	if m == null:
		inst.free()
		return root
	inst.remove_child(m)
	m.owner = null
	inst.free()
	root.add_child(m)
	Stylize.apply(m)
	Stylize.add_outline(m, 0.008)
	var cv := visual(root)
	if cv != null:
		cv.play(&"idle")
		if cv.animation_player() != null:
			cv.animation_player().animation_finished.connect(func(anim: StringName) -> void:
				var want: StringName = root.get_meta(LOOP_META, &"")
				if want != &"" and anim == want:
					cv.play(want, 1.0, 0.0))
	return root


## Vira o figurante para olhar `point` (os modelos olham para -Z, como no MemberActor).
static func face(root: Node3D, point: Vector3) -> void:
	var d := point - root.global_position if root.is_inside_tree() else point - root.position
	root.rotation.y = atan2(-d.x, -d.z)


static func visual(root: Node) -> CharacterVisual:
	if root is CharacterVisual:
		return root as CharacterVisual
	for c in root.get_children():
		if c is CharacterVisual:
			return c as CharacterVisual
	return null


## Toca `anim` em laco (mesmo que o clipe nao seja de laco no GLB).
static func loop(root: Node3D, anim: StringName) -> void:
	root.set_meta(LOOP_META, anim)
	var cv := visual(root)
	if cv != null:
		cv.play(anim)


## Toca `anim` uma vez e depois volta ao laco `then` (idle por padrao). Devolve a duracao do clipe (0 se nao existe).
static func once(root: Node3D, anim: StringName, then: StringName = &"idle") -> float:
	var cv := visual(root)
	if cv == null or not cv.has_animation(anim):
		return 0.0
	root.set_meta(LOOP_META, &"")
	cv.play(anim, 1.0, 0.1)
	var player := cv.animation_player()
	var length := cv.animation_length(anim)
	player.animation_finished.connect(func(_a: StringName) -> void:
		if is_instance_valid(root):
			loop(root, then), CONNECT_ONE_SHOT)
	return length


static func current(root: Node3D) -> StringName:
	var cv := visual(root)
	return cv.current_animation() if cv != null else &""
