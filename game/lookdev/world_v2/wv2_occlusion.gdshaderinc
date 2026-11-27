// RB-R1 G24a2 v2: peca (caixote, toldo, barraca, arvore...) entre a camera e o heroi, ou que contem a camera, some em
// pontilhado (dither 4x4). So entra na VARIANTE pontilhada do material (WV2Materials.occl_variant), aplicada pela
// CameraOcclusion apenas a peca que tapa, enquanto o fade dura; os materiais normais nao tem discard (early-Z intacto).
// Parametros POR INSTANCIA (cada peca tem o seu fade), escritos por CameraOcclusion:
//   occl_cam (xyz camera, w raio da esfera em volta da camera), occl_hero (xyz centro do heroi, w raio do cone no heroi),
//   occl_amount (0..1, fade).
// So os fragmentos no cone camera -> heroi (raio w no heroi, metade na camera) ou perto da camera somem; no passe de
// sombra (projecao ortografica do sol) nao pontilha: a sombra da peca fica inteira.
instance uniform vec4 occl_cam = vec4(0.0);
instance uniform vec4 occl_hero = vec4(0.0);
instance uniform float occl_amount = 0.0;

void occl_discard(vec3 world, vec2 frag, mat4 proj) {
	if (occl_amount <= 0.001 || proj[3][3] == 1.0) {
		return;
	}
	float k = 0.0;
	vec3 seg = occl_hero.xyz - occl_cam.xyz;
	float len2 = max(dot(seg, seg), 1e-4);
	float t = dot(world - occl_cam.xyz, seg) / len2;
	if (occl_hero.w > 0.0 && t > 0.0 && t < 1.0) {
		float r = occl_hero.w * mix(0.5, 1.0, t);
		float d = length(occl_cam.xyz + seg * t - world);
		k = smoothstep(r, r * 0.55, d);
	}
	if (occl_cam.w > 0.0) {
		k = max(k, smoothstep(occl_cam.w, occl_cam.w * 0.6, length(world - occl_cam.xyz)));
	}
	// Borda macia e no maximo 75% dos pixels somem: a peca continua legivel.
	k *= occl_amount * 0.75;
	if (k <= 0.0) {
		return;
	}
	int ix = int(mod(frag.x, 4.0));
	int iy = int(mod(frag.y, 4.0));
	float bayer[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	if (k * 16.0 > bayer[iy * 4 + ix] + 0.5) {
		discard;
	}
}
