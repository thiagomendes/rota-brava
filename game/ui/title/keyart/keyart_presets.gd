class_name KeyArtPresets
extends RefCounted
## Dados das 3 propostas de arte-chave (RB-R1 G8, PROPOSTA). Coordenadas da vila v3 (x leste, z sul, agua em y -0,4):
## doca em (0,0,0), bacia do porto x -14..37 z -13..0, fileira norte de casas z -15..-20 (fachadas para o sul),
## farol em (31, *, -24) no promontorio, mar aberto em x > 37.
## Herois: `on` = "boat" (pos local ao barco; frente do barco = -Z) ou "world" (x,z; y vem do chao + `lift`).
## `anim` + `t` = clipe existente e quadro segurado. `look` = "camera" ou ponto do mundo (so os olhos).
## Luz: `sun_az` em graus (0 = sol vindo de +Z/sul, 90 = de +X/leste), `sun_elev` em graus.

const LOGOS := {
	&"a": "res://ui/title/keyart/logos/logo_a.svg",
	&"b": "res://ui/title/keyart/logos/logo_b.svg",
	&"c": "res://ui/title/keyart/logos/logo_c.svg",
}

## Paletas (hex) de cada proposta, na ordem: dominante, apoio, acento, sombra, luz.
const PALETTES := {
	&"a": ["FF9A4D", "2E3A8C", "FFD23A", "14213D", "FFF1D6"],
	&"b": ["1A1440", "FFB347", "E8504A", "2A1745", "FFF4D6"],
	&"c": ["8FB8F0", "FFC3A0", "E2453A", "102A43", "FFFFFF"],
}

## Lugar do logo por enquadramento: [centro x, centro y, largura] em fracoes da tela (KeyArtView).
const LOGO_LAYOUT := {
	&"a": {&"wide": [0.3, 0.15, 0.5], &"portrait": [0.5, 0.11, 0.9], &"capsule": [0.3, 0.42, 0.52], &"menu": [0.3, 0.15, 0.44]},
	&"b": {&"wide": [0.5, 0.17, 0.36], &"portrait": [0.5, 0.13, 0.7], &"capsule": [0.2, 0.5, 0.34], &"menu": [0.3, 0.17, 0.34]},
	&"c": {&"wide": [0.72, 0.19, 0.36], &"portrait": [0.5, 0.12, 0.72], &"capsule": [0.74, 0.5, 0.42], &"menu": [0.3, 0.16, 0.34]},
}

const TITLES := {
	&"a": "Rumo ao pôr do sol",
	&"b": "Noite das lanternas",
	&"c": "Amanhecer no farol",
}


static func get_preset(id: StringName) -> Dictionary:
	match id:
		&"b":
			return _b()
		&"c":
			return _c()
	return _a()


## A · "Rumo ao por do sol": o barco amarelo sai do porto em direcao a crianca, sol baixo atras (contraluz dourada),
## Leme no leme, Rastro apontando da proa, Pico acenando em cima da cabine. Vila e farol no fundo.
static func _a() -> Dictionary:
	return {
		"light": {
			"sun_az": -120.0, "sun_elev": 6.0, "sun_color": "ffb36b", "sun_energy": 2.4,
			"fill_color": "ff9fb8", "fill_energy": 0.4,
			"top_color": "34408f", "horizon_color": "ffae66", "ground_color": "6b4f7a",
			"cloud_light": "ffd2a0", "cloud_shadow": "a8679a", "cloud_coverage": 0.48, "sun_size": 0.07, "sun_glow": 0.7,
			"ambient": 0.6, "fog_color": "f0a07c", "fog_density": 0.0014, "fog_sun_scatter": 0.25,
			"exposure": 1.0, "glow": 0.8, "glow_bloom": 0.06, "saturation": 1.2, "contrast": 1.1,
			"water_shallow_color": "3aa6a8", "water_deep_color": "263f73", "water_sky_color": "ffb58a",
		},
		"lights": [
			{"type": "spot", "pos": Vector3(55.5, 4.0, 1.5), "look": Vector3(49.2, 1.2, -5.7), "color": "ffd0aa",
				"energy": 6.0, "range": 16.0, "angle": 20.0},
			{"type": "omni", "pos": Vector3(45.6, 4.0, -8.8), "color": "ff9a4d", "energy": 3.0, "range": 7.0},
		],
		"boat": [Vector3(49.2, -0.4, -5.7), 182.0, 0.0, 3.0],
		"heroes": {
			&"leme": {"on": "boat", "pos": Vector3(0.0, 0.41, 0.15), "anim": "point", "t": 0.5, "yaw": 25.0,
				"look": "camera", "expr": "atenta", "expr_w": 0.4},
			&"rastro": {"on": "boat", "pos": Vector3(0.3, 0.47, -1.5), "anim": "point", "t": 0.45, "yaw": 15.0,
				"look": "camera", "expr": "surpresa", "expr_w": 0.25},
			&"pico": {"on": "boat", "pos": Vector3(0.0, 1.42, 1.45), "anim": "celebrate", "t": 0.78, "yaw": 40.0,
				"look": "camera", "expr": "surpresa", "expr_w": 0.3},
		},
		"cameras": {
			&"wide": {"pos": Vector3(56.6, 1.0, 0.5), "look": Vector3(47.7, 2.4, -6.4), "fov": 40.0, "roll": -2.0},
			&"portrait": {"pos": Vector3(55.6, 0.8, -0.2), "look": Vector3(48.6, 3.8, -6.2), "fov": 58.0, "roll": -2.0},
			&"capsule": {"pos": Vector3(56.0, 0.9, 0.0), "look": Vector3(47.2, 2.4, -6.6), "fov": 34.0, "subject_x": 0.66},
			&"menu": {"pos": Vector3(57.0, 1.0, 1.0), "look": Vector3(48.0, 2.6, -6.4), "fov": 42.0, "subject_x": 0.27},
		},
	}


## B · "Noite das lanternas": o trio na ponta oeste da doca, camera baixa (heroica), varais de lanternas,
## fachadas acesas e o feixe do farol girando atras; o barco amarelo atracado com as luzes acesas.
static func _b() -> Dictionary:
	return {
		"light": {
			"festival": true,
			"sun_az": 160.0, "sun_elev": 35.0, "sun_color": "8fa8ff", "sun_energy": 0.35,
			"fill_color": "7a6cff", "fill_energy": 0.15,
			"top_color": "0b1236", "horizon_color": "4a2f7a", "ground_color": "120c2a",
			"cloud_light": "4b4a8a", "cloud_shadow": "1f1a44", "cloud_coverage": 0.35, "sun_size": 0.01, "sun_glow": 0.0,
			"ambient": 0.3, "fog_color": "2a1d55", "fog_density": 0.005,
			"exposure": 1.25, "glow": 1.1, "glow_bloom": 0.12, "saturation": 1.2, "contrast": 1.06,
			"water_shallow_color": "1d3f66", "water_deep_color": "0a1430", "water_sky_color": "ff9f5a",
		},
		"lights": [
			{"type": "omni", "pos": Vector3(-2.4, 1.9, 0.0), "color": "ffb868", "energy": 2.2, "range": 5.0, "flicker": true},
			{"type": "spot", "pos": Vector3(-2.2, 4.5, -8.0), "look": Vector3(-2.4, 1.0, -2.4), "color": "9fb4ff",
				"energy": 5.0, "range": 11.0, "angle": 28.0},
			{"type": "omni", "pos": Vector3(-5.2, 1.3, -1.2), "color": "ff6f91", "energy": 1.2, "range": 3.5, "flicker": true},
			{"type": "omni", "pos": Vector3(1.6, 1.4, -3.4), "color": "ffcf7a", "energy": 2.4, "range": 4.5, "flicker": true},
		],
		"boat": [Vector3(2.6, -0.4, -5.4), 80.0, 0.0, 0.0],
		"heroes": {
			&"leme": {"on": "world", "pos": Vector3(-3.7, 0.0, -2.3), "anim": "point", "t": 0.54, "yaw": 150.0,
				"look": "camera", "expr": "atenta", "expr_w": 0.4},
			&"rastro": {"on": "world", "pos": Vector3(-2.45, 0.0, -2.0), "anim": "react_surprise", "t": 0.4, "yaw": 165.0,
				"look": "camera", "expr": "atenta", "expr_w": 0.4},
			&"pico": {"on": "world", "pos": Vector3(-1.2, 0.0, -2.45), "anim": "celebrate", "t": 0.78, "yaw": 185.0,
				"look": "camera", "expr": "surpresa", "expr_w": 0.3},
		},
		"cameras": {
			&"wide": {"pos": Vector3(-3.5, 0.42, 1.3), "look": Vector3(3.0, 2.7, -14.0), "fov": 48.0},
			&"portrait": {"pos": Vector3(-4.6, 0.45, 2.8), "look": Vector3(4.0, 3.8, -14.0), "fov": 64.0, "subject_x": 0.42},
			&"capsule": {"pos": Vector3(-3.6, 0.55, 1.8), "look": Vector3(2.0, 2.2, -14.0), "fov": 36.0, "subject_x": 0.7},
			&"menu": {"pos": Vector3(-3.2, 0.6, 2.8), "look": Vector3(3.0, 2.4, -14.0), "fov": 48.0, "subject_x": 0.27},
		},
	}


## C · "Amanhecer no farol": o trio na ponta do promontorio, rente ao mar; Pico comemora, Leme acena, Rastro aponta o
## sol nascendo; camera baixa sobre a agua; farol listrado e casa do faroleiro atras, barco amarelo encostado na
## pedra a direita; luz rosada e dourada vindo do leste.
static func _c() -> Dictionary:
	return {
		"light": {
			"sun_az": 70.0, "sun_elev": 9.0, "sun_color": "ffb89a", "sun_energy": 2.4,
			"fill_color": "a8b8ff", "fill_energy": 0.35,
			"top_color": "6e7fd0", "horizon_color": "ffc3a0", "ground_color": "7a8fb8",
			"cloud_light": "fff0e0", "cloud_shadow": "d49ab8", "cloud_coverage": 0.45, "sun_size": 0.05, "sun_glow": 0.5,
			"ambient": 0.7, "fog_color": "f6c6c0", "fog_density": 0.0022, "fog_sun_scatter": 0.3,
			"exposure": 1.05, "glow": 0.6, "glow_bloom": 0.05, "saturation": 1.15, "contrast": 1.06,
			"water_shallow_color": "56c8c0", "water_deep_color": "2d5f9a", "water_sky_color": "ffcdb5",
		},
		"lights": [
			{"type": "spot", "pos": Vector3(41.5, 4.5, -8.5), "look": Vector3(36.3, 1.0, -12.8), "color": "ffd8c0",
				"energy": 5.0, "range": 12.0, "angle": 24.0},
			{"type": "omni", "pos": Vector3(33.5, 2.6, -11.0), "color": "ff9fb8", "energy": 1.4, "range": 4.5},
			{"type": "omni", "pos": Vector3(40.5, 2.6, -8.5), "color": "ffd0a0", "energy": 1.6, "range": 5.0},
		],
		"boat": [Vector3(39.4, -0.45, -10.6), 35.0, 0.0, 1.5],
		"heroes": {
			&"leme": {"on": "world", "pos": Vector3(34.8, 0.0, -12.7), "anim": "wave", "t": 1.04,
				"yaw": 205.0, "look": "camera", "expr": "atenta", "expr_w": 0.4},
			&"pico": {"on": "world", "pos": Vector3(36.3, 0.0, -12.9), "anim": "celebrate", "t": 0.78,
				"yaw": 195.0, "look": "camera", "expr": "surpresa", "expr_w": 0.4},
			&"rastro": {"on": "world", "pos": Vector3(37.8, 0.0, -12.6), "anim": "point", "t": 0.54,
				"yaw": -100.0, "look": Vector3(70.0, 3.0, 5.0), "expr": "surpresa", "expr_w": 0.25},
		},
		"cameras": {
			&"wide": {"pos": Vector3(37.4, 0.55, -7.6), "look": Vector3(35.2, 5.0, -20.0), "fov": 54.0, "roll": 2.0},
			&"portrait": {"pos": Vector3(37.4, 0.5, -6.6), "look": Vector3(34.8, 6.8, -20.0), "fov": 64.0, "roll": 1.5},
			&"capsule": {"pos": Vector3(38.0, 0.6, -6.6), "look": Vector3(35.0, 4.0, -20.0), "fov": 40.0, "subject_x": 0.33},
			&"menu": {"pos": Vector3(38.2, 0.65, -5.6), "look": Vector3(34.4, 4.8, -20.0), "fov": 52.0, "subject_x": 0.27},
		},
	}
