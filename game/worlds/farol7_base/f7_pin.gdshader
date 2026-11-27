shader_type spatial;
// Pino do mapa da base Farol 7 (RB-R1 G21, art3d, PROVISORIO): retrato do HUD do heroi sobre a cor do heroi.
// A UV do GLB vem em metros a partir do centro do disco (raio 0,09 m; o glTF inverte o V); aqui vira 0..1.
uniform sampler2D portrait : source_color, filter_linear_mipmap;
uniform vec3 bg : source_color = vec3(1.0);
uniform float radius_m = 0.09;

void fragment() {
	vec2 uv = vec2(UV.x / (2.0 * radius_m) + 0.5, (UV.y - 1.0) / (2.0 * radius_m) + 0.5);
	vec4 p = texture(portrait, clamp(uv, vec2(0.0), vec2(1.0)));
	ALBEDO = mix(bg, p.rgb, p.a);
	ROUGHNESS = 0.35;
	SPECULAR = 0.5;
	CLEARCOAT = 0.4;
}
