shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Rota Brava · Ep01 v3 (RB-R1 E3) · feixe da lanterna do farol: cone aditivo que some ao longe e nas bordas. PROVISORIO.

uniform vec3 beam_color : source_color = vec3(1.0, 0.9, 0.62);
uniform float strength = 0.55;
uniform float length_m = 16.0;

varying float v_dist;

void vertex() {
	v_dist = length(VERTEX);
}

void fragment() {
	float along = clamp(v_dist / length_m, 0.0, 1.0);
	float edge = pow(abs(dot(NORMAL, VIEW)), 1.6);
	ALBEDO = beam_color * strength * edge * (1.0 - along) * (1.0 - along);
}
