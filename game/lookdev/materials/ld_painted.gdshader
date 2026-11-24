shader_type spatial;
render_mode diffuse_lambert_wrap;
// Rota Brava · lookdev (RB-R1 D11) · PINTADO (reboco das casas, telhas, madeira pintada, casco).
// Cor viva da paleta com variacao larga suave (nada de chapado), grao fino de reboco/pintura em relevo leve
// e sujeira de base perto do chao (assenta o objeto, como sombra de contato pintada).

#include "res://lookdev/materials/ld_common.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0, 0.79, 0.64, 1.0);
uniform bool use_vertex_color = true;
uniform float variation_scale = 1.3;
uniform float variation : hint_range(0.0, 0.4) = 0.08;
uniform float grain_scale = 55.0;
uniform float bump_strength : hint_range(0.0, 3.0) = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.80;
uniform float specular : hint_range(0.0, 1.0) = 0.40;
uniform float clearcoat : hint_range(0.0, 1.0) = 0.0;
// Sujeira de base: escurece abaixo de grime_height (metros do mundo).
uniform float grime_height = 0.6;
uniform float grime : hint_range(0.0, 0.5) = 0.15;
uniform float rim : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_wpos;
varying vec3 v_wnrm;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n0 = normalize(v_wnrm);
	vec3 col = albedo.rgb;
	if (use_vertex_color) {
		col *= COLOR.rgb;
	}
	col *= 1.0 + (ld_fbm3(v_wpos * variation_scale) - 0.5) * 2.0 * variation;
	float g = smoothstep(grime_height, 0.0, v_wpos.y) * grime;
	g *= 0.6 + 0.4 * ld_noise3(v_wpos * 4.0);
	col *= 1.0 - g;
	ALBEDO = col;
	float dist = length(VERTEX);
	float fade = ld_detail_fade(dist, 5.0, 25.0);
	vec3 n = n0;
	if (fade > 0.0) {
		vec3 p = v_wpos * grain_scale;
		float e = 0.3;
		float h0 = ld_noise3(p);
		vec3 gr = vec3(ld_noise3(p + vec3(e, 0, 0)) - h0, ld_noise3(p + vec3(0, e, 0)) - h0, ld_noise3(p + vec3(0, 0, e)) - h0) / e;
		n = ld_bump(n0, gr, 0.05 * bump_strength * fade);
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ROUGHNESS = roughness;
	SPECULAR = specular;
	CLEARCOAT = clearcoat;
	CLEARCOAT_ROUGHNESS = 0.3;
	RIM = rim;
	RIM_TINT = 0.6;
}
