shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;
// Contorno de casca invertida (bible secao 7): so personagens e itens interativos.
// Espessura em espaco de tela aproximado, para o traco nao engrossar de perto nem sumir de longe.

uniform vec4 outline_color : source_color = vec4(0.12, 0.10, 0.18, 1.0);
uniform float thickness = 0.012;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 offset = normalize((PROJECTION_MATRIX * vec4(n, 0.0)).xy);
	clip.xy += offset * thickness * clip.w * 0.5;
	POSITION = clip;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
