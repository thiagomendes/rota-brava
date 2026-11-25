shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Rota Brava · Mundo v2 (RB-R1 W1) · terreno: grama, terra do caminho, areia/lama molhada e pedra, projetados
// de cima (metros do mundo). Mascaras na cor de vertice (R caminho, G molhado, B pedra), com bordas quebradas
// por ruido para nao ficarem retas. PROVISORIO ate aprovacao de Thiago.

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_data : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_data : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_data : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float grass_m = 4.0;
uniform float dirt_m = 3.0;
uniform float rock_m = 2.0;
uniform vec3 grass_tint : source_color = vec3(1.0);
uniform vec3 wet_tint : source_color = vec3(0.62, 0.55, 0.45);
uniform float normal_depth = 1.0;

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

vec3 unpack(vec4 d) {
	vec2 xy = d.rg * 2.0 - 1.0;
	return vec3(xy, sqrt(max(0.0, 1.0 - dot(xy, xy))));
}

void fragment() {
	vec2 p = v_wpos.xz;
	float n = vnoise(v_wpos * 1.6) * 0.6 + vnoise(v_wpos * 5.0) * 0.4;
	float path = smoothstep(0.35, 0.65, COLOR.r + (n - 0.5) * 0.55);
	float wet = smoothstep(0.3, 0.7, COLOR.g + (n - 0.5) * 0.4);
	float rock = smoothstep(0.35, 0.65, COLOR.b + (n - 0.5) * 0.5);
	vec4 gd = texture(grass_data, p / grass_m);
	vec4 dd = texture(dirt_data, p / dirt_m);
	vec4 rd = texture(rock_data, p / rock_m);
	vec3 g = texture(grass_albedo, p / grass_m).rgb * grass_tint;
	float big = vnoise(v_wpos * 0.08);
	g *= 0.9 + 0.2 * big;
	vec3 dcol = texture(dirt_albedo, p / dirt_m).rgb;
	vec3 rcol = texture(rock_albedo, p / rock_m).rgb;
	vec3 col = mix(g, dcol, path);
	vec3 nt = mix(unpack(gd), unpack(dd), path);
	float rough = mix(gd.a, dd.a, path);
	col = mix(col, rcol, rock);
	nt = mix(nt, unpack(rd), rock);
	// molhado: terra escura e brilhante perto da agua
	vec3 wetc = dcol * wet_tint;
	col = mix(col, wetc, wet);
	rough = mix(rough, 0.35, wet);
	ALBEDO = col;
	float depth = normal_depth * (1.0 - 0.7 * smoothstep(12.0, 50.0, length(VERTEX)));
	// projecao de cima: tangente = +x, verde (acima na imagem) = -z; base inclinada pelo terreno
	vec3 base = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 t = normalize(vec3(1.0, 0.0, 0.0) - base * base.x);
	vec3 b = normalize(cross(base, t));
	vec3 wn = normalize(t * nt.x * depth + b * nt.y * depth + base * nt.z);
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	ROUGHNESS = rough;
	SPECULAR = 0.35;
}
