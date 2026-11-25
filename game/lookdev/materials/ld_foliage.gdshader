shader_type spatial;
render_mode diffuse_lambert_wrap;
// Rota Brava · lookdev (RB-R1 D11) · FOLHAGEM (copas, arbustos, juncos): tufos de folha em relevo
// (celulas 3D), cor que vai do verde-sombra frio ao verde-sol amarelado e luz atravessando (translucidez).

#include "res://lookdev/materials/ld_common.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.49, 0.80, 0.29, 1.0);
uniform bool use_vertex_color = true;
uniform vec4 shade_tint : source_color = vec4(0.62, 0.78, 0.80, 1.0);
uniform vec4 sun_tint : source_color = vec4(1.10, 1.05, 0.70, 1.0);
uniform float clump_scale = 5.0;
uniform float bump_strength : hint_range(0.0, 3.0) = 1.0;
uniform float translucency : hint_range(0.0, 1.0) = 0.35;
uniform float roughness : hint_range(0.0, 1.0) = 0.75;
uniform float desaturate : hint_range(0.0, 0.6) = 0.12;

varying vec3 v_wpos;
varying vec3 v_wnrm;

float clump_h(vec3 p) {
	vec3 c = ld_cells3(p * clump_scale);
	return (1.0 - c.x) * 0.8 + ld_noise3(p * clump_scale * 5.0) * 0.2;
}

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
	col = mix(col, vec3(dot(col, vec3(0.3, 0.55, 0.15))), desaturate);
	float h0 = clump_h(v_wpos);
	vec3 c = ld_cells3(v_wpos * clump_scale);
	float var = ld_fbm3(v_wpos * 0.9);
	col *= mix(shade_tint.rgb, sun_tint.rgb, clamp(var * 0.6 + c.z * 0.4, 0.0, 1.0));
	col *= mix(0.72, 1.0, smoothstep(0.1, 0.7, h0));
	ALBEDO = col;
	float dist = length(VERTEX);
	float fade = ld_detail_fade(dist, 10.0, 60.0);
	vec3 n = n0;
	if (fade > 0.0) {
		float e = 0.01;
		vec3 g = vec3(clump_h(v_wpos + vec3(e, 0, 0)) - h0, clump_h(v_wpos + vec3(0, e, 0)) - h0, clump_h(v_wpos + vec3(0, 0, e)) - h0) / e;
		n = ld_bump(n0, g, 0.06 * bump_strength * fade / max(clump_scale, 0.5));
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ROUGHNESS = roughness;
	SPECULAR = 0.3;
	BACKLIGHT = col * translucency;
}
