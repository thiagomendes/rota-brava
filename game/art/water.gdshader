shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;
// Agua estilizada: cor por profundidade, ondulacao animada, espuma na costa e junto ao casco
// (diferenca de profundidade), reflexo simplificado do ceu (fresnel) e brilho do sol.

uniform vec4 shallow_color : source_color = vec4(0.32, 0.80, 0.72, 1.0);
uniform vec4 deep_color : source_color = vec4(0.05, 0.40, 0.46, 1.0);
uniform vec4 foam_color : source_color = vec4(0.96, 1.0, 1.0, 1.0);
uniform vec4 sky_color : source_color = vec4(0.66, 0.88, 0.90, 1.0);
uniform float depth_range = 3.5;
uniform float foam_width = 1.0;
uniform float wave_height = 0.07;
uniform float wave_scale = 0.22;
uniform float wave_speed = 0.55;
uniform float normal_strength = 0.45;
uniform float alpha_shallow = 0.62;
uniform float alpha_deep = 0.94;
uniform float fresnel_strength = 0.35;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;

varying vec3 world_pos;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

float height_at(vec2 p, float t) {
	return fbm(p * wave_scale + vec2(t * 0.05, t * 0.03)) + 0.5 * fbm(p * wave_scale * 2.1 - vec2(t * 0.07, -t * 0.04));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = sin(world_pos.x * 0.45 + TIME * wave_speed) * 0.5 + sin(world_pos.z * 0.62 - TIME * wave_speed * 1.3) * 0.5;
	VERTEX.y += w * wave_height;
}

void fragment() {
	vec2 p = world_pos.xz;
	float h = height_at(p, TIME);
	float hx = height_at(p + vec2(0.08, 0.0), TIME);
	float hz = height_at(p + vec2(0.0, 0.08), TIME);
	vec3 n = normalize(vec3(-(hx - h) * normal_strength * 6.0, 1.0, -(hz - h) * normal_strength * 6.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	float d = texture(depth_tex, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, d);
	vec4 vw = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vw.xyz /= vw.w;
	float depth_diff = max(VERTEX.z - vw.z, 0.0);

	float dt = clamp(depth_diff / depth_range, 0.0, 1.0);
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, smoothstep(0.0, 1.0, dt));

	float edge = 1.0 - smoothstep(0.0, foam_width, depth_diff);
	float fn = fbm(world_pos.xz * 1.9 + vec2(TIME * 0.22, -TIME * 0.17));
	float foam = clamp(edge * smoothstep(0.30, 0.70, fn + edge * 0.45), 0.0, 1.0);
	float crest = smoothstep(0.86, 1.02, h * 0.9 + fn * 0.25) * 0.12;
	foam = clamp(foam + crest, 0.0, 1.0);
	col = mix(col, foam_color.rgb, foam);

	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	col = mix(col, sky_color.rgb, fres * fresnel_strength);

	ALBEDO = col;
	ROUGHNESS = mix(0.05, 0.9, foam);
	SPECULAR = 0.6;
	METALLIC = 0.0;
	ALPHA = clamp(mix(alpha_shallow, alpha_deep, dt) + foam * 0.6, 0.0, 1.0);
}
