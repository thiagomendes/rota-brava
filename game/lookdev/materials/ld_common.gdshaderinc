// Rota Brava · lookdev (RB-R1 D11). Funcoes comuns dos materiais novos: ruido, celulas, triplanar e relevo.
// Tudo procedural (sem textura importada): o relevo vem do gradiente de uma funcao de altura avaliada no
// espaco do objeto ou do mundo, por diferencas finitas, e entorta a normal (funciona sem UV nem tangente).

float ld_hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 ld_hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float ld_hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 ld_hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float ld_noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(ld_hash13(i), ld_hash13(i + vec3(1, 0, 0)), f.x);
	float b = mix(ld_hash13(i + vec3(0, 1, 0)), ld_hash13(i + vec3(1, 1, 0)), f.x);
	float c = mix(ld_hash13(i + vec3(0, 0, 1)), ld_hash13(i + vec3(1, 0, 1)), f.x);
	float d = mix(ld_hash13(i + vec3(0, 1, 1)), ld_hash13(i + vec3(1, 1, 1)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

float ld_noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(ld_hash12(i), ld_hash12(i + vec2(1, 0)), f.x),
		mix(ld_hash12(i + vec2(0, 1)), ld_hash12(i + vec2(1, 1)), f.x), f.y);
}

// fbm de 3 oitavas (0..1).
float ld_fbm3(vec3 p) {
	float s = ld_noise3(p) * 0.57;
	s += ld_noise3(p * 2.03 + 17.1) * 0.29;
	s += ld_noise3(p * 4.11 + 41.7) * 0.14;
	return s;
}

float ld_fbm2(vec2 p) {
	float s = ld_noise2(p) * 0.57;
	s += ld_noise2(p * 2.03 + 17.1) * 0.29;
	s += ld_noise2(p * 4.11 + 41.7) * 0.14;
	return s;
}

// Celulas 3D (Voronoi): x = distancia ao centro mais proximo, y = F2 - F1 (borda), z = id aleatorio 0..1.
vec3 ld_cells3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = ld_hash33(i + g) * 0.8 + 0.1;
				float d = length(g + o - f);
				if (d < d1) {
					d2 = d1;
					d1 = d;
					id = ld_hash13(i + g + 7.7);
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return vec3(d1, d2 - d1, id);
}

// Celulas 2D: x = F1, y = F2 - F1, z = id; w = angulo aleatorio (0..2pi). `c` devolve o centro da celula.
vec4 ld_cells2(vec2 p, out vec2 c) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	c = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = ld_hash22(i + g) * 0.8 + 0.1;
			vec2 r = g + o - f;
			float d = length(r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = ld_hash12(i + g + 3.3);
				c = r;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec4(d1, d2 - d1, id, id * 6.2832);
}

// Pesos triplanares a partir da normal (espaco do objeto ou do mundo).
vec3 ld_tri_weights(vec3 n, float sharpness) {
	vec3 w = pow(abs(n), vec3(sharpness));
	return w / max(w.x + w.y + w.z, 1e-4);
}

// Entorta a normal `n` (unitaria, mesmo espaco de `grad`) pelo gradiente de altura `grad` (altura em metros).
vec3 ld_bump(vec3 n, vec3 grad, float strength) {
	vec3 g = grad - dot(grad, n) * n;
	return normalize(n - g * strength);
}

// Atenua detalhe fino com a distancia para evitar cintilacao: 1 perto, ~0 a `far` metros.
float ld_detail_fade(float dist, float near, float far) {
	return 1.0 - smoothstep(near, far, dist);
}
