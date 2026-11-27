shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
#include "res://lookdev/world_v2/wv2_occlusion.gdshaderinc"
// Rota Brava · Ep01 v3 (RB-R1 E3) · lanterna de papel da festa: cor de vertice (cor do papel), luz que atravessa o papel
// e brilho proprio controlado pela vila (apagada de dia, acesa na noite de festa). PROVISORIO.

uniform float glow : hint_range(0.0, 8.0) = 0.0;
uniform vec3 glow_tint : source_color = vec3(1.0, 0.82, 0.55);

void fragment() {
	occl_discard((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, FRAGCOORD.xy);
	vec3 c = COLOR.rgb;
	ALBEDO = c;
	ROUGHNESS = 0.75;
	SPECULAR = 0.2;
	BACKLIGHT = c * 0.6;
	// mais claro no meio do gomo (papel fino) que nas bordas
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	EMISSION = c * glow_tint * glow * (1.0 - 0.45 * rim);
}
