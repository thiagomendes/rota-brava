extends SceneTree
## Mapa de caminhabilidade (vista de cima) da colisao da vila v3, para conferir passagens e subidas (RB-R1 E3b).
## Uso: bash tools/godot.sh --headless --path game --script res://../tools/probe_walkmap.gd -- x0 x1 z0 z1 saida.png [passo]
## Cores: chao em tons de cinza pela altura; vermelho = inclinacao > 45 graus (o heroi nao sobe); laranja = degrau
## > 0,08 m para a celula vizinha; azul = obstaculo na altura do corpo (0,1 a 1,4 m acima do chao); verde = topo de
## estrutura/adereco (fora do Ground). Linhas a cada 1 m (mais fortes a cada 5 m). So colisao (camada 1), nao o visual.

const SCENE := "res://worlds/village_v3/village_collision.tscn"


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 5:
		push_error("uso: -- x0 x1 z0 z1 saida.png [passo]")
		quit(1)
		return
	var x0 := float(a[0])
	var x1 := float(a[1])
	var z0 := float(a[2])
	var z1 := float(a[3])
	var out := a[4]
	var step := float(a[5]) if a.size() > 5 else 0.05
	var w := (load(SCENE) as PackedScene).instantiate()
	root.add_child(w)
	await physics_frame
	await physics_frame
	var space := (w as Node3D).get_world_3d().direct_space_state
	var nx := int((x1 - x0) / step)
	var nz := int((z1 - z0) / step)
	var hs := PackedFloat32Array()
	hs.resize(nx * nz)
	var img := Image.create(nx, nz, false, Image.FORMAT_RGB8)
	var cyl := CylinderShape3D.new()
	cyl.radius = step * 0.5
	cyl.height = 1.3
	var qs := PhysicsShapeQueryParameters3D.new()
	qs.shape = cyl
	qs.collision_mask = 1
	for j in nz:
		for i in nx:
			var x := x0 + (i + 0.5) * step
			var z := z0 + (j + 0.5) * step
			var q := PhysicsRayQueryParameters3D.create(Vector3(x, 30, z), Vector3(x, -5, z), 1)
			var h := space.intersect_ray(q)
			var c := Color(0.2, 0.5, 0.8)
			var y := -5.0
			if not h.is_empty():
				y = (h.position as Vector3).y
				var n := h.normal as Vector3
				var g := clampf(0.35 + y * 0.12, 0.1, 0.95)
				c = Color(g, g, g)
				if String((h.collider as Node).name) != "Ground":
					c = Color(0.35, 0.7 + g * 0.2, 0.35)
				if n.y < cos(deg_to_rad(45.0)):
					c = Color(0.9, 0.15, 0.1)
				qs.transform = Transform3D(Basis(), Vector3(x, y + 0.1 + 0.65, z))
				if not space.intersect_shape(qs, 1).is_empty():
					c = Color(0.1, 0.2, 0.9)
			hs[j * nx + i] = y
			img.set_pixel(i, j, c)
	for j in range(1, nz):
		for i in range(1, nx):
			var y := hs[j * nx + i]
			var d := maxf(absf(y - hs[j * nx + i - 1]), absf(y - hs[(j - 1) * nx + i]))
			if d > 0.08 and d < 0.6 and img.get_pixel(i, j).b < 0.8:
				img.set_pixel(i, j, Color(1.0, 0.6, 0.0))
	var gx := int(ceil(x0))
	while gx <= int(x1):
		var px := int((gx - x0) / step)
		for j in nz:
			if px >= 0 and px < nx:
				img.set_pixel(px, j, img.get_pixel(px, j).darkened(0.5 if gx % 5 == 0 else 0.2))
		gx += 1
	var gz := int(ceil(z0))
	while gz <= int(z1):
		var pz := int((gz - z0) / step)
		for i in nx:
			if pz >= 0 and pz < nz:
				img.set_pixel(i, pz, img.get_pixel(i, pz).darkened(0.5 if gz % 5 == 0 else 0.2))
		gz += 1
	img.save_png(out)
	print("walkmap %s (%dx%d)" % [out, nx, nz])
	quit(0)
