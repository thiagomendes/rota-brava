shader_type canvas_item;
// Fundo da tela-titulo (RB-R1): ceu em degrade (style-bible 5), nuvens fofas a deriva e mar com ondas e espuma.
// Proporcao: `aspect` = largura/altura do retangulo, para as nuvens nao esticarem em 20:9 ou 4:3.

uniform float aspect = 1.7778;
uniform float motion = 1.0; // 0 = movimento reduzido
uniform float horizon = 0.70;

float cloud(vec2 p, vec2 c, float s) {
	float d = length((p - c) / vec2(1.0, 0.8)) - s;
	d = min(d, length(p - c - vec2(s * 0.9, s * 0.2)) - s * 0.75);
	d = min(d, length(p - c + vec2(s * 0.9, -s * 0.25)) - s * 0.65);
	d = min(d, length((p - c - vec2(0.0, s * 0.35)) / vec2(2.2, 0.5)) - s * 0.8);
	return d;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * motion;
	vec3 top = vec3(0.31, 0.65, 0.91);
	vec3 hor = vec3(0.99, 0.91, 0.79);
	vec3 col = mix(top, hor, smoothstep(0.0, horizon, uv.y));
	vec2 p = vec2(uv.x * aspect, uv.y);
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float speed = 0.012 + fi * 0.004;
		float x = mod(fi * 0.83 * aspect + t * speed, aspect + 0.6) - 0.3;
		vec2 c = vec2(x, 0.10 + mod(fi * 0.137, 0.32));
		float s = 0.045 + mod(fi * 0.031, 0.04);
		float d = cloud(p, c, s);
		vec3 cc = mix(vec3(1.0), vec3(0.86, 0.84, 0.96), smoothstep(-s, s * 0.6, p.y - c.y));
		col = mix(col, cc, smoothstep(0.004, -0.004, d));
	}
	float w1 = horizon + 0.012 * sin(p.x * 9.0 + t * 1.2);
	float w2 = horizon + 0.09 + 0.014 * sin(p.x * 7.0 - t * 0.9 + 1.3);
	vec3 shallow = vec3(0.31, 0.82, 0.77);
	vec3 deep = vec3(0.10, 0.48, 0.55);
	if (uv.y > w1) {
		col = mix(shallow, deep, smoothstep(w1, 1.0, uv.y) * 0.6);
		col = mix(col, vec3(0.95, 1.0, 0.99), smoothstep(0.009, 0.0, abs(uv.y - w1 - 0.006)));
	}
	if (uv.y > w2) {
		col = mix(deep, deep * 0.85, smoothstep(w2, 1.0, uv.y));
		col = mix(col, vec3(0.6, 0.92, 0.9), smoothstep(0.006, 0.0, abs(uv.y - w2 - 0.004)) * 0.7);
	}
	COLOR = vec4(col, 1.0);
}
