shader_type canvas_item;
// Vinheta sutil de tela cheia, bem fria nas bordas (sem preto chapado).

uniform float strength : hint_range(0.0, 1.0) = 0.38;
uniform vec4 tint : source_color = vec4(0.03, 0.08, 0.14, 1.0);

void fragment() {
	float d = distance(UV, vec2(0.5));
	float v = smoothstep(0.50, 0.98, d);
	COLOR = vec4(tint.rgb, v * strength);
}
