shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;
// Rota Brava · Mundo v2 (RB-R1 W1) · tufos de grama, flores e juncos (MultiMesh). Cor de vertice com base escura e
// ponta clara (assada no Blender), normal puxada para cima (o tufo acende como o gramado), luz que atravessa e vento.
// PROVISORIO ate aprovacao de Thiago.

uniform vec3 tint : source_color = vec3(1.0);
uniform float wind = 1.0;
uniform float up_normal : hint_range(0.0, 1.0) = 0.6;
uniform vec3 backlight_color : source_color = vec3(0.35, 0.45, 0.2);
uniform float roughness_value = 0.75;

varying float v_h;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = max(VERTEX.y, 0.0);
	vec3 sway = vec3(sin(TIME * 1.9 + w.x * 0.8 + w.z * 0.5), 0.0, cos(TIME * 1.6 + w.z * 0.7 + w.x * 0.3)) * wind * k * k * 0.12;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(sway, 0.0)).xyz;
	vec3 up = (inverse(MODEL_MATRIX) * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	NORMAL = normalize(mix(NORMAL, normalize(up), up_normal));
	v_h = k;
}

void fragment() {
	ALBEDO = COLOR.rgb * tint;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.3;
	BACKLIGHT = backlight_color;
}
