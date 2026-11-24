shader_type spatial;
render_mode diffuse_lambert_wrap;
// Rota Brava · lookdev (RB-R1 D11) · CHAO com textura: manchas de grama viva/seca, fio de grama fino,
// terra aparecendo e FOLHAS caidas espalhadas (celulas 2D no plano x,z do mundo; cada celula pode ter
// uma folha oval girada, com nervura e cor da paleta de outono suave). Base de cor = albedo x cor do vertice.

#include "res://lookdev/materials/ld_common.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_vertex_color = true;
uniform vec4 dry_color : source_color = vec4(0.78, 0.74, 0.42, 1.0);
uniform vec4 soil_color : source_color = vec4(0.55, 0.42, 0.30, 1.0);
uniform float patch_scale = 0.45;
uniform float dry_amount : hint_range(0.0, 1.0) = 0.35;
uniform float soil_amount : hint_range(0.0, 1.0) = 0.18;
uniform float blade_scale = 90.0;
uniform float blade_contrast : hint_range(0.0, 0.6) = 0.22;
// Folhas: celulas por metro e chance de folha por celula.
uniform float leaf_density = 3.2;
uniform float leaf_chance : hint_range(0.0, 1.0) = 0.30;
uniform float leaf_size : hint_range(0.1, 0.5) = 0.30;
uniform vec4 leaf_a : source_color = vec4(0.95, 0.72, 0.25, 1.0);
uniform vec4 leaf_b : source_color = vec4(0.86, 0.45, 0.22, 1.0);
uniform vec4 leaf_c : source_color = vec4(0.45, 0.62, 0.28, 1.0);
uniform float bump_strength : hint_range(0.0, 3.0) = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.92;

varying vec3 v_wpos;
varying vec3 v_wnrm;

// x = altura, y = mascara de folha, z = id da folha.
vec3 ground(vec2 p) {
	float blades = ld_noise2(vec2(p.x * blade_scale, p.y * blade_scale * 0.35));
	blades = blades * 0.6 + ld_noise2(p * blade_scale * 0.5 + 5.0) * 0.4;
	vec2 c;
	vec4 cell = ld_cells2(p * leaf_density, c);
	float has = step(cell.z, leaf_chance);
	float ang = cell.w;
	vec2 r = vec2(cos(ang) * c.x - sin(ang) * c.y, sin(ang) * c.x + cos(ang) * c.y);
	vec2 q = r / vec2(leaf_size, leaf_size * 0.5);
	float shape = 1.0 - dot(q, q);
	float leaf = smoothstep(0.0, 0.15, shape) * has;
	float rib = 1.0 - smoothstep(0.0, 0.08, abs(q.y)) * 0.5;
	float h = mix(blades * 0.35, 0.55 + shape * 0.25 * rib, leaf);
	return vec3(h, leaf, fract(cell.z * 13.7));
}

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n0 = normalize(v_wnrm);
	vec2 p = v_wpos.xz;
	vec3 base = albedo.rgb;
	if (use_vertex_color) {
		base *= COLOR.rgb;
	}
	float dist = length(VERTEX);
	float fade = ld_detail_fade(dist, 6.0, 35.0);
	float patches = ld_fbm2(p * patch_scale);
	float patches2 = ld_fbm2(p * patch_scale * 2.7 + 9.0);
	// Grama seca mantem o brilho da base mas puxa para o amarelo-palha.
	float dry = smoothstep(0.5, 0.75, patches) * dry_amount;
	vec3 col = mix(base, base * 0.5 + dry_color.rgb * 0.5, dry);
	float soil = smoothstep(0.62, 0.8, patches2) * soil_amount;
	col = mix(col, soil_color.rgb * (0.6 + 0.4 * dot(base, vec3(0.333))), soil);
	col *= 1.0 + (ld_fbm2(p * 3.1) - 0.5) * 0.18;
	vec3 g0 = ground(p);
	col *= mix(1.0, 1.0 - blade_contrast + g0.x * blade_contrast * 2.0, fade);
	vec3 lc = g0.z < 0.4 ? leaf_a.rgb : (g0.z < 0.75 ? leaf_b.rgb : leaf_c.rgb);
	lc *= 0.85 + 0.3 * fract(g0.z * 7.3);
	float leaf = g0.y * smoothstep(0.3, 0.8, n0.y) * mix(0.5, 1.0, fade);
	col = mix(col, lc, leaf);
	ALBEDO = col;

	vec3 n = n0;
	if (fade > 0.0) {
		float e = 0.006;
		vec2 gr = vec2(ground(p + vec2(e, 0)).x - g0.x, ground(p + vec2(0, e)).x - g0.x) / e;
		n = ld_bump(n0, vec3(gr.x, 0.0, gr.y), 0.004 * bump_strength * fade);
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ROUGHNESS = mix(roughness, 0.7, leaf);
	SPECULAR = 0.3;
}
