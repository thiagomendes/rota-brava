shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://lookdev/world_v2/wv2_occlusion.gdshaderinc"
// Rota Brava · Mundo v2 (RB-R1 W1) · superficie com textura de verdade (UV em metros do Blender).
// albedo_tex = cor (sRGB); data_tex = R,G normal (OpenGL) · B mascara de tingimento · A rugosidade.
// A cor de vertice (tinta da parede, cor da veneziana...) so tinge onde a mascara manda (lascas mostram madeira).
// Mipmaps + filtro anisotropico na amostragem e relevo que esmaece com a distancia: nada cintila.
// PROVISORIO ate aprovacao de Thiago.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D data_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tex_meters = 1.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float normal_depth = 1.0;
uniform float rough_mul = 1.0;
uniform float rough_add = 0.0;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.5;
uniform float metallic_amount : hint_range(0.0, 1.0) = 0.0;
uniform float clearcoat_amount : hint_range(0.0, 1.0) = 0.0;
// Variacao larga no mundo (quebra a repeticao) e sujeira de base perto do chao.
uniform float macro_amount : hint_range(0.0, 0.5) = 0.08;
uniform float grime_amount : hint_range(0.0, 1.0) = 0.0;
uniform float grime_height = 0.6;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
// Interior aceso: emite a propria cor do albedo (parede iluminada por dentro); o brilho muda de dia/noite.
uniform float emission_albedo = 0.0;

varying vec3 v_wpos;

float h13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h13(i), h13(i + vec3(1, 0, 0)), f.x), mix(h13(i + vec3(0, 1, 0)), h13(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h13(i + vec3(0, 0, 1)), h13(i + vec3(1, 0, 1)), f.x), mix(h13(i + vec3(0, 1, 1)), h13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	occl_discard((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, FRAGCOORD.xy);
	vec2 uv = UV / tex_meters;
	vec3 a = texture(albedo_tex, uv).rgb;
	vec4 d = texture(data_tex, uv);
	vec3 col = a * mix(vec3(1.0), COLOR.rgb, d.b) * tint;
	float m = vnoise(v_wpos * 0.45) * 0.65 + vnoise(v_wpos * 1.7) * 0.35;
	col *= 1.0 + (m - 0.5) * 2.0 * macro_amount;
	float g = smoothstep(grime_height, 0.0, v_wpos.y) * grime_amount * (0.6 + 0.4 * vnoise(v_wpos * 3.0));
	col *= 1.0 - g * 0.5;
	ALBEDO = col;
	float dist = length(VERTEX);
	NORMAL_MAP = vec3(d.rg, 1.0);
	NORMAL_MAP_DEPTH = normal_depth * (1.0 - 0.7 * smoothstep(12.0, 45.0, dist));
	ROUGHNESS = clamp(d.a * rough_mul + rough_add + g * 0.1, 0.04, 1.0);
	SPECULAR = specular_amount;
	METALLIC = metallic_amount;
	CLEARCOAT = clearcoat_amount;
	CLEARCOAT_ROUGHNESS = 0.25;
	RIM = rim_amount;
	RIM_TINT = 0.5;
	EMISSION = (emission_color + col * emission_albedo) * emission_energy;
}
