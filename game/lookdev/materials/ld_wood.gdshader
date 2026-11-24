shader_type spatial;
render_mode diffuse_lambert_wrap;
// Rota Brava · lookdev (RB-R1 D11) · MADEIRA desbotada com veio, variacao por tabua e relevo.
// Textura solida 3D no espaco do mundo (sem UV): aneis em torno do eixo do veio, deformados por ruido,
// mais fibras finas esticadas ao longo do veio. O veio de cada objeto segue `grain_axis` (instancia),
// que LookdevMaterials calcula pelo maior eixo horizontal da peca.

#include "res://lookdev/materials/ld_common.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.79, 0.65, 0.48, 1.0);
uniform bool use_vertex_color = true;
// Cor do veio (multiplica o albedo).
uniform vec4 grain_color : source_color = vec4(0.78, 0.68, 0.58, 1.0);
uniform float ring_scale = 30.0;
uniform float ring_warp = 0.7;
uniform float fiber_scale = 140.0;
uniform float patch_variation : hint_range(0.0, 0.5) = 0.22;
uniform float bump_strength : hint_range(0.0, 3.0) = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.82;
uniform float specular : hint_range(0.0, 1.0) = 0.35;
// Desbotado pelo sol: topo mais claro e acinzentado.
uniform float sun_bleach : hint_range(0.0, 0.5) = 0.12;
instance uniform vec3 grain_axis = vec3(1.0, 0.0, 0.0);

varying vec3 v_wpos;
varying vec3 v_wnrm;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Devolve altura (x) e mascara do veio (y).
vec2 wood(vec3 p, vec3 a) {
	float along = dot(p, a);
	vec3 perp = p - along * a;
	float warp = ld_fbm3(vec3(along * 0.25, 0.0, 0.0) + perp * 2.0) * ring_warp;
	float r = length(perp) * ring_scale + warp;
	float ring = fract(r);
	float line = smoothstep(0.0, 0.08, ring) * (1.0 - smoothstep(0.75, 1.0, ring));
	float fib = ld_noise3(vec3(along * 4.0, 0.0, 0.0) + perp * fiber_scale);
	float h = line * 0.7 + fib * 0.3;
	return vec2(h, (1.0 - line) * 0.8 + (1.0 - fib) * 0.25);
}

void fragment() {
	vec3 a = normalize(grain_axis + vec3(1e-4));
	vec3 n0 = normalize(v_wnrm);
	vec2 w0 = wood(v_wpos, a);
	vec3 col = albedo.rgb;
	if (use_vertex_color) {
		col *= COLOR.rgb;
	}
	// Variacao larga (tabuas mais claras/escuras) e veio.
	// Faixas ao longo do veio: cada tabua sai mais clara ou mais escura (baixa frequencia ao longo, alta atravessando).
	float along_w = dot(v_wpos, a);
	float patch = ld_fbm3((v_wpos - along_w * a) * 4.5 + a * along_w * 0.12);
	col *= 1.0 + (patch - 0.5) * 2.0 * patch_variation;
	col = mix(col, col * grain_color.rgb, clamp(w0.y, 0.0, 1.0));
	float up = clamp(n0.y, 0.0, 1.0);
	col = mix(col, mix(col, vec3(dot(col, vec3(0.333))) * 1.12, 0.5), sun_bleach * up);
	ALBEDO = col;

	float dist = length(VERTEX);
	float fade = ld_detail_fade(dist, 6.0, 30.0);
	vec3 n = n0;
	if (fade > 0.0) {
		float e = 0.004;
		float h0 = w0.x;
		vec3 g = vec3(wood(v_wpos + vec3(e, 0, 0), a).x - h0, wood(v_wpos + vec3(0, e, 0), a).x - h0, wood(v_wpos + vec3(0, 0, e), a).x - h0) / e;
		n = ld_bump(n0, g, 0.0012 * bump_strength * fade);
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ROUGHNESS = roughness;
	SPECULAR = specular;
}
