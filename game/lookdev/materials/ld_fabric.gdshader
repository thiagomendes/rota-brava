shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx;
// Rota Brava · lookdev (RB-R1 D11) · TECIDO com trama procedural e relevo.
// pattern 0 = sarja/tela (jaqueta, calca, toldo), 1 = malha canelada (gola, punho), 2 = tricô em "V" (meia, gorro).
// Projecao triplanar no espaco do objeto (personagens) ou do mundo (toldos, bandeiras): nao depende de UV.
// O relevo vem do gradiente da altura do fio; a cor escurece nos vaos e ganha "fiapo" (fuzz) na borda.
// Costura opcional: pesponto tracejado ao longo de um plano do objeto (ex.: centro da frente, x = 0).

#include "res://lookdev/materials/ld_common.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0, 0.54, 0.12, 1.0);
uniform bool use_vertex_color = false;
uniform bool world_space = false;
uniform int pattern : hint_range(0, 2) = 0;
// Repeticoes por metro (fio grosso de brinquedo: 60 a 160).
uniform float scale = 110.0;
uniform float bump_strength : hint_range(0.0, 4.0) = 1.2;
// Cor no fundo do vao (multiplica o albedo).
uniform float groove_dark : hint_range(0.0, 1.0) = 0.62;
uniform float roughness : hint_range(0.0, 1.0) = 0.86;
uniform float specular : hint_range(0.0, 1.0) = 0.30;
// Brilho de tecido (fiapo na borda, contra a luz).
uniform float sheen : hint_range(0.0, 1.0) = 0.40;
uniform float sheen_tint : hint_range(0.0, 1.0) = 0.70;
uniform float mottle : hint_range(0.0, 0.3) = 0.06;
uniform float tri_sharpness = 4.0;
// Costura: plano (normal xyz, distancia w) no espaco do objeto; largura e cor do pesponto.
uniform bool seam_enabled = false;
uniform vec4 seam_plane = vec4(1.0, 0.0, 0.0, 0.0);
uniform float seam_width = 0.006;
uniform float seam_dash = 70.0;
uniform vec4 seam_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float seam_ridge = 0.008;

varying vec3 v_pos;
varying vec3 v_nrm;
varying vec3 v_opos;

float thread(float t) {
	// Perfil arredondado do fio entre 0 e 1 (0 nas bordas).
	return sqrt(clamp(sin(t * PI), 0.0, 1.0));
}

// Altura do tecido (0..1) num plano 2D; `uv` ja em unidades de repeticao.
float cloth_h(vec2 uv) {
	if (pattern == 0) {
		vec2 c = floor(uv);
		vec2 f = fract(uv);
		float over = mod(c.x + c.y, 2.0);
		float warp = thread(f.x) * (0.55 + 0.45 * thread(f.y));
		float weft = thread(f.y) * (0.55 + 0.45 * thread(f.x));
		return mix(warp, weft, over);
	} else if (pattern == 1) {
		// Canelado: colunas verticais grossas com leve ondulacao de laco.
		float col = thread(fract(uv.x * 0.5));
		float loops = 0.75 + 0.25 * thread(fract(uv.y * 0.8));
		return col * loops;
	}
	// Tricô em V: cada coluna tem dois lacos inclinados (chevron).
	vec2 g = vec2(uv.x * 0.5, uv.y * 0.7);
	float cx = fract(g.x);
	float half_x = fract(cx * 2.0);
	float lean = (cx < 0.5 ? (0.5 - cx) : (cx - 0.5)) * 1.2;
	float row = fract(g.y + lean);
	return thread(half_x) * thread(row) * 0.85 + thread(cx) * 0.15;
}

float tri_h(vec3 p, vec3 w) {
	// Eixo vertical do tecido = y nos planos laterais (colunas do tricô descem pelo corpo).
	float h = 0.0;
	if (w.x > 0.01) h += w.x * cloth_h(p.zy);
	if (w.z > 0.01) h += w.z * cloth_h(p.xy);
	if (w.y > 0.01) h += w.y * cloth_h(p.xz);
	return h;
}

void vertex() {
	v_opos = VERTEX;
	if (world_space) {
		v_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		v_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	} else {
		v_pos = VERTEX;
		v_nrm = NORMAL;
	}
}

void fragment() {
	vec3 n0 = normalize(v_nrm);
	vec3 w = ld_tri_weights(n0, tri_sharpness);
	vec3 p = v_pos * scale;
	float dist = length(VERTEX);
	// Abaixo de ~2 px por fio a trama vira media: some o relevo, fica a cor media.
	float fade = ld_detail_fade(dist * scale / 110.0, 1.5, 7.0);
	float h0 = tri_h(p, w);
	float h = mix(0.55, h0, fade);
	vec3 col = albedo.rgb;
	if (use_vertex_color) {
		col *= COLOR.rgb;
	}
	col *= 1.0 + (ld_fbm3(v_pos * 6.0) - 0.5) * 2.0 * mottle;
	col *= mix(groove_dark, 1.0, smoothstep(0.0, 0.9, h));

	vec3 n = n0;
	if (fade > 0.0) {
		float e = 0.12;
		vec3 g = vec3(tri_h(p + vec3(e, 0, 0), w) - h0, tri_h(p + vec3(0, e, 0), w) - h0, tri_h(p + vec3(0, 0, e), w) - h0) / e;
		// Altura do fio ~ 1/scale metros: gradiente em unidades de repeticao ja e "por fio".
		n = ld_bump(n0, g, 0.18 * bump_strength * fade);
	}
	if (seam_enabled) {
		float d = dot(v_opos, seam_plane.xyz) - seam_plane.w;
		float along = dot(v_opos, vec3(0.0, 1.0, 0.0)) + dot(v_opos, cross(seam_plane.xyz, vec3(0.0, 1.0, 0.0)));
		float dash = step(0.35, fract(along * seam_dash));
		float on = (1.0 - smoothstep(seam_width * 0.5, seam_width, abs(d))) * dash;
		col = mix(col, seam_color.rgb, on * 0.9);
		// Sulco da costura dos dois lados do pesponto.
		float groove = 1.0 - smoothstep(seam_width, seam_width * 2.5, abs(d));
		col *= 1.0 - groove * (1.0 - on) * 0.25;
	}
	ALBEDO = col;
	vec3 n_world = world_space ? n : normalize((MODEL_MATRIX * vec4(n, 0.0)).xyz);
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	ROUGHNESS = roughness;
	SPECULAR = specular;
	RIM = sheen;
	RIM_TINT = sheen_tint;
}
