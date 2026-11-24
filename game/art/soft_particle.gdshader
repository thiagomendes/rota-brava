shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
// Particula macia (espuma, respingo, poeira): disco com borda suave, sempre de frente para a camera.

uniform vec4 color : source_color = vec4(1.0);
uniform float softness = 1.6;

void vertex() {
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	mat4 mat_world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	float rot = INSTANCE_CUSTOM.x;
	mat_world = mat_world * mat4(vec4(cos(rot), -sin(rot), 0.0, 0.0), vec4(sin(rot), cos(rot), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat_world;
	VERTEX *= vec3(sx, sy, 1.0);
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float a = pow(clamp(1.0 - d, 0.0, 1.0), softness);
	ALBEDO = color.rgb * COLOR.rgb;
	ALPHA = a * color.a * COLOR.a;
}
