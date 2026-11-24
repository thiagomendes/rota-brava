shader_type sky;
// Ceu estilizado de Rota Brava (bible secao 5 e 6): gradiente quente no horizonte, nuvens fofas
// em camadas (topo branco, base lilas), disco de sol suave e chao do ceu azul-esverdeado.

uniform vec3 top_color : source_color = vec3(0.31, 0.65, 0.91);
uniform vec3 horizon_color : source_color = vec3(0.99, 0.91, 0.79);
uniform vec3 ground_color : source_color = vec3(0.40, 0.66, 0.72);
uniform vec3 cloud_light : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shadow : source_color = vec3(0.80, 0.78, 0.92);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.46;
uniform float cloud_softness : hint_range(0.01, 0.5) = 0.10;
uniform float cloud_speed = 0.004;
uniform float cloud_scale = 2.2;
uniform float sun_size = 0.035;
uniform float sun_glow = 0.25;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.07 + vec2(13.1, 7.7);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.55));
		// Projecao das nuvens num plano alto: mais densas perto do horizonte, achatadas.
		vec2 uv = d.xz / max(h + 0.12, 0.05) * 0.5 * cloud_scale + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.4);
		float n = fbm(uv);
		float n2 = fbm(uv + vec2(0.0, 0.18));
		float cov = 1.0 - cloud_coverage;
		float c = smoothstep(cov, cov + cloud_softness, n);
		float shade = smoothstep(cov, cov + 0.25, n2);
		vec3 cloud = mix(cloud_shadow, cloud_light, shade);
		float fade = smoothstep(0.0, 0.18, h);
		col = mix(col, cloud, c * fade);
	} else {
		col = mix(horizon_color, ground_color, clamp(-h * 3.0, 0.0, 1.0));
	}
	if (LIGHT0_ENABLED) {
		float sd = distance(d, LIGHT0_DIRECTION);
		col += LIGHT0_COLOR * (smoothstep(sun_size, sun_size * 0.6, sd) * 1.6 + exp(-sd * 6.0) * sun_glow);
	}
	COLOR = col;
}
