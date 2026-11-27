shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx;
#include "res://lookdev/world_v2/wv2_occlusion.gdshaderinc"
// Rota Brava · Mundo v2 (RB-R1 W1) · triplanar no mundo para massas organicas sem UV (copas, arbustos, rochas).
// Folhas: textura de folhas com relevo por folha, cor de vertice (sombra interna da copa assada no Blender),
// luz que atravessa (BACKLIGHT) e balanco de vento leve. PROVISORIO ate aprovacao de Thiago.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D data_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tex_meters = 1.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float normal_depth = 1.0;
uniform float rough_mul = 1.0;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.35;
uniform vec3 backlight_color : source_color = vec3(0.0);
uniform float wind = 0.0;
uniform float macro_amount : hint_range(0.0, 0.5) = 0.1;

varying vec3 v_wpos;
varying vec3 v_wnrm;

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
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (wind > 0.0) {
		float k = max(VERTEX.y, 0.0);
		vec3 sway = vec3(sin(TIME * 1.3 + w.x * 0.35 + w.z * 0.2), 0.0, cos(TIME * 1.1 + w.z * 0.3)) * wind * k * 0.02;
		VERTEX += (inverse(MODEL_MATRIX) * vec4(sway, 0.0)).xyz;
		w += sway;
	}
	v_wpos = w;
	v_wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 unpack(vec4 d) {
	vec2 xy = d.rg * 2.0 - 1.0;
	return vec3(xy, sqrt(max(0.0, 1.0 - dot(xy, xy))));
}

void fragment() {
	occl_discard((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, FRAGCOORD.xy);
	vec3 n = normalize(v_wnrm);
	vec3 bw = pow(abs(n), vec3(4.0));
	bw /= bw.x + bw.y + bw.z;
	vec3 p = v_wpos / tex_meters;
	vec2 ux = p.zy;
	vec2 uy = p.xz;
	vec2 uz = p.xy;
	vec3 col = texture(albedo_tex, ux).rgb * bw.x + texture(albedo_tex, uy).rgb * bw.y + texture(albedo_tex, uz).rgb * bw.z;
	vec4 dx = texture(data_tex, ux);
	vec4 dy = texture(data_tex, uy);
	vec4 dz = texture(data_tex, uz);
	vec3 tx = unpack(dx);
	vec3 ty = unpack(dy);
	vec3 tz = unpack(dz);
	float depth = normal_depth * (1.0 - 0.7 * smoothstep(12.0, 50.0, length(VERTEX)));
	// mistura UDN: o relevo de cada projecao entorta a normal do mundo
	// (verde = acima na imagem = eixo decrescente da UV da Godot)
	vec3 nw = normalize(n + depth * (vec3(0.0, -tx.y, tx.x) * bw.x + vec3(ty.x, 0.0, -ty.y) * bw.y +
		vec3(tz.x, -tz.y, 0.0) * bw.z));
	col *= COLOR.rgb * tint;
	float m = vnoise(v_wpos * 0.35) * 0.6 + vnoise(v_wpos * 1.3) * 0.4;
	col *= 1.0 + (m - 0.5) * 2.0 * macro_amount;
	ALBEDO = col;
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	ROUGHNESS = clamp((dx.a * bw.x + dy.a * bw.y + dz.a * bw.z) * rough_mul, 0.05, 1.0);
	SPECULAR = specular_amount;
	BACKLIGHT = backlight_color * COLOR.rgb;
}
