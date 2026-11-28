// RB-R1 G24a2 v2: peca (caixote, barraca, carrinho, arvore...) entre a camera e o heroi, ou que contem a camera, fica
// pontilhada INTEIRA (dither 4x4 com um valor so de fade). So entra na VARIANTE pontilhada do material
// (WV2Materials.occl_variant), aplicada pela CameraOcclusion apenas a peca que tapa, enquanto o fade dura; os materiais
// normais nao tem discard (early-Z intacto). Parametros POR INSTANCIA, escritos por CameraOcclusion:
//   occl_cam (xyz camera do jogo; w = 1 quando a camera esta dentro da peca), occl_amount (0..1, fade).
// Sombra nao pontilha: passe com projecao ortografica (sol) ou camera longe da camera do jogo (> 0,5 m).
instance uniform vec4 occl_cam = vec4(0.0);
instance uniform float occl_amount = 0.0;

void occl_discard(vec3 cam_world, vec2 frag, mat4 proj) {
	if (occl_amount <= 0.001 || proj[3][3] == 1.0 || length(cam_world - occl_cam.xyz) > 0.5) {
		return;
	}
	// Teto de 50% (xadrez do Bayer 4x4, art3d): a peca continua legivel. Camera DENTRO da peca: 62,5%, para a peca
	// grande colada na lente nao tapar o heroi.
	float k = occl_amount * (occl_cam.w > 0.5 ? 0.625 : 0.5);
	// Bayer 4x4 por conta (sem tabela indexada): b2(x, y) = 2 * (x ^ y) + y.
	int x = int(mod(frag.x, 4.0));
	int y = int(mod(frag.y, 4.0));
	int lo = 2 * ((x & 1) ^ (y & 1)) + (y & 1);
	int hi = 2 * (((x >> 1) & 1) ^ ((y >> 1) & 1)) + ((y >> 1) & 1);
	float threshold = (float(4 * lo + hi) + 0.5) / 16.0;
	if (k > threshold) {
		discard;
	}
}
