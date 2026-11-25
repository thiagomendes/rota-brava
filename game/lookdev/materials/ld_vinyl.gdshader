shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx;
// Rota Brava · lookdev (RB-R1 D11) · VINIL MACIO para pele, cabelo de brinquedo, botas, plastico e olhos.
// Difuso com "wrap" (a luz contorna a forma, sombra macia), brilho especular largo e baixo (rugosidade media),
// camada de verniz fraca (clearcoat) que da o brilho de brinquedo, borda de luz leve (rim) e um gradiente suave
// de cima para baixo no espaco do objeto (o topo recebe mais ceu). Sem contorno, sem faixas de toon.
// Textura "casca de laranja" quase invisivel quebra o reflexo para nao parecer plastico duro.

#include "res://lookdev/materials/ld_common.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.79, 0.55, 0.38, 1.0);
uniform bool use_vertex_color = false;
uniform float roughness : hint_range(0.0, 1.0) = 0.48;
uniform float specular : hint_range(0.0, 1.0) = 0.42;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float clearcoat : hint_range(0.0, 1.0) = 0.22;
uniform float clearcoat_roughness : hint_range(0.0, 1.0) = 0.38;
uniform float rim : hint_range(0.0, 1.0) = 0.22;
uniform float rim_tint : hint_range(0.0, 1.0) = 0.55;
// Calor sob a pele (so cor): sombra puxa para `warm_shadow` em vez de cinza.
uniform vec4 warm_shadow : source_color = vec4(0.85, 0.42, 0.36, 1.0);
uniform float warm_amount : hint_range(0.0, 1.0) = 0.0;
// Gradiente vertical no espaco do objeto (metros a partir da origem nos pes).
uniform float grad_bottom = 0.0;
uniform float grad_top = 1.2;
uniform float grad_strength : hint_range(0.0, 0.5) = 0.10;
// Casca de laranja (micro-relevo) e variacao de cor muito leve.
uniform float micro_scale = 140.0;
uniform float micro_bump : hint_range(0.0, 0.02) = 0.0025;
uniform float tint_variation : hint_range(0.0, 0.2) = 0.03;
uniform float emission_energy = 0.0;

varying vec3 v_opos;
varying vec3 v_onrm;

void vertex() {
	v_opos = VERTEX;
	v_onrm = NORMAL;
}

void fragment() {
	vec3 col = albedo.rgb;
	if (use_vertex_color) {
		col *= COLOR.rgb;
	}
	float t = smoothstep(grad_bottom, grad_top, v_opos.y);
	col *= mix(1.0 - grad_strength, 1.0 + grad_strength * 0.4, t);
	col *= 1.0 + (ld_noise3(v_opos * 9.0) - 0.5) * 2.0 * tint_variation;
	// Sombra quente: perto da borda (normal de lado para a camera) a cor fica mais saturada e quente.
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	col = mix(col, col * warm_shadow.rgb * 1.25, warm_amount * (1.0 - facing) * 0.6);
	ALBEDO = col;

	float dist = length(VERTEX);
	float fade = ld_detail_fade(dist, 2.0, 9.0);
	if (micro_bump > 0.0 && fade > 0.0) {
		vec3 p = v_opos * micro_scale;
		float e = 0.35;
		float h0 = ld_noise3(p);
		vec3 g = vec3(ld_noise3(p + vec3(e, 0, 0)) - h0, ld_noise3(p + vec3(0, e, 0)) - h0, ld_noise3(p + vec3(0, 0, e)) - h0) / e;
		vec3 n_obj = normalize(v_onrm);
		vec3 nb = ld_bump(n_obj, g * micro_scale, micro_bump * fade);
		vec3 n_view = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(nb, 0.0)).xyz);
		NORMAL = n_view;
	}

	ROUGHNESS = roughness;
	SPECULAR = specular;
	METALLIC = metallic;
	CLEARCOAT = clearcoat;
	CLEARCOAT_ROUGHNESS = clearcoat_roughness;
	RIM = rim;
	RIM_TINT = rim_tint;
	EMISSION = col * emission_energy;
}
