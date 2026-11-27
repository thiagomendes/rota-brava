// RB-R1 G24a2: o que fica entre a camera e o heroi some em pontilhado (dither 4x4), como nos jogos do Mario.
// So os fragmentos dentro de um cone estreito ao longo do segmento camera -> heroi (raio occl_hero.w no heroi, metade
// na camera) e antes do heroi; o resto do mundo nao muda. Parametros escritos por CameraRig via WV2Materials.
// Custo: alguns ALU e um discard por fragmento; occl_amount 0 sai na primeira linha.
uniform vec4 occl_hero = vec4(0.0);
uniform vec3 occl_cam = vec3(0.0);
uniform float occl_amount = 0.0;

void occl_discard(vec3 world, vec2 frag) {
	if (occl_amount <= 0.001 || occl_hero.w <= 0.0) {
		return;
	}
	vec3 seg = occl_hero.xyz - occl_cam;
	float len2 = max(dot(seg, seg), 1e-4);
	float t = dot(world - occl_cam, seg) / len2;
	if (t <= 0.0 || t >= 1.0) {
		return;
	}
	float r = occl_hero.w * mix(0.5, 1.0, t);
	float d = length(occl_cam + seg * t - world);
	if (d >= r) {
		return;
	}
	// Borda macia (pontilhado menos denso perto do raio) e no maximo 75% dos pixels somem: ainda se ve o objeto.
	float k = smoothstep(r, r * 0.55, d) * occl_amount * 0.75;
	int ix = int(mod(frag.x, 4.0));
	int iy = int(mod(frag.y, 4.0));
	float bayer[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	if (k * 16.0 > bayer[iy * 4 + ix] + 0.5) {
		discard;
	}
}
