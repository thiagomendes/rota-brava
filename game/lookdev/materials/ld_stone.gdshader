shader_type spatial;
render_mode diffuse_lambert_wrap;
// Rota Brava · lookdev (RB-R1 D11) · PEDRA: blocos/seixos arredondados com junta, variacao por pedra,
// manchas e musgo nas faces voltadas para cima. Celulas 3D no espaco do mundo (sem UV), relevo pelo gradiente.
// cell_scale baixo (1,5 a 3 por metro) = blocos de cais e rochas rachadas; alto (5 a 8) = calcamento de seixos.

#include "res://lookdev/materials/ld_common.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.66, 0.64, 0.72, 1.0);
uniform bool use_vertex_color = true;
uniform float cell_scale = 2.6;
uniform float joint_width : hint_range(0.01, 0.5) = 0.10;
uniform float joint_dark : hint_range(0.0, 1.0) = 0.55;
uniform float stone_variation : hint_range(0.0, 0.5) = 0.18;
uniform float mottle_scale = 7.0;
uniform float mottle : hint_range(0.0, 0.5) = 0.14;
uniform vec4 moss_color : source_color = vec4(0.42, 0.55, 0.26, 1.0);
uniform float moss_amount : hint_range(0.0, 1.0) = 0.25;
uniform float bump_strength : hint_range(0.0, 3.0) = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.88;
uniform float specular : hint_range(0.0, 1.0) = 0.32;

varying vec3 v_wpos;
varying vec3 v_wnrm;

float stone_h(vec3 p) {
	vec3 c = ld_cells3(p * cell_scale);
	float edge = smoothstep(0.0, joint_width, c.y);
	float dome = 1.0 - c.x * 0.35;
	float grit = ld_noise3(p * mottle_scale * 4.0) * 0.18;
	return edge * dome + grit;
}

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n0 = normalize(v_wnrm);
	vec3 c = ld_cells3(v_wpos * cell_scale);
	float edge = smoothstep(0.0, joint_width, c.y);
	vec3 col = albedo.rgb;
	if (use_vertex_color) {
		col *= COLOR.rgb;
	}
	// Cada pedra com tom proprio (um pouco mais quente ou mais fria).
	float v = (c.z - 0.5) * 2.0 * stone_variation;
	col *= 1.0 + v;
	col = mix(col, col * vec3(1.04, 1.0, 0.94), clamp(c.z * 1.5 - 0.5, 0.0, 1.0) * 0.5);
	float m = ld_fbm3(v_wpos * mottle_scale);
	col *= 1.0 + (m - 0.5) * 2.0 * mottle;
	col *= mix(joint_dark, 1.0, edge);
	float up = smoothstep(0.35, 0.9, n0.y);
	float moss = smoothstep(0.55, 0.75, ld_fbm3(v_wpos * 2.3 + 11.0)) * up * moss_amount * (0.4 + 0.6 * (1.0 - edge));
	col = mix(col, moss_color.rgb * (0.85 + 0.3 * m), clamp(moss, 0.0, 1.0));
	ALBEDO = col;

	float dist = length(VERTEX);
	float fade = ld_detail_fade(dist, 8.0, 40.0);
	vec3 n = n0;
	if (fade > 0.0) {
		float e = 0.01;
		float h0 = stone_h(v_wpos);
		vec3 g = vec3(stone_h(v_wpos + vec3(e, 0, 0)) - h0, stone_h(v_wpos + vec3(0, e, 0)) - h0, stone_h(v_wpos + vec3(0, 0, e)) - h0) / e;
		n = ld_bump(n0, g, 0.02 * bump_strength * fade / max(cell_scale, 0.5));
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ROUGHNESS = mix(roughness, 0.95, moss);
	SPECULAR = specular;
}
