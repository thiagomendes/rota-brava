shader_type spatial;
// Sombreador estilizado de Rota Brava ("diorama de brinquedo luminoso").
// Rampa de luz suave em 3 tons, sombra que herda a cor fria do ambiente, luz de contorno (rim)
// e escurecimento por altura (AO barato). Serve a personagens, adereços e cenario para formarem uma familia.

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_tex = false;
uniform bool use_vertex_color = true;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;

uniform float ramp_low : hint_range(0.0, 1.0) = 0.30;
uniform float ramp_high : hint_range(0.0, 1.0) = 0.70;
uniform float ramp_softness : hint_range(0.01, 0.5) = 0.14;
uniform float light_boost = 0.95;

uniform vec4 rim_color : source_color = vec4(1.0, 0.94, 0.80, 1.0);
uniform float rim_power = 3.0;
uniform float rim_strength = 0.28;

uniform float ao_base = -0.6;
uniform float ao_range = 1.4;
uniform float ao_strength = 0.30;

uniform float roughness_value : hint_range(0.0, 1.0) = 0.85;

varying float v_world_y;

void vertex() {
	v_world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	vec3 col = albedo.rgb;
	if (use_tex) {
		col *= texture(albedo_tex, UV).rgb;
	}
	if (use_vertex_color) {
		col *= COLOR.rgb;
	}
	float t = smoothstep(ao_base, ao_base + ao_range, v_world_y);
	col *= mix(1.0 - ao_strength, 1.0, t);
	ALBEDO = col;
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	EMISSION = emission_color.rgb * emission_energy + rim_color.rgb * rim * rim_strength * col;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = clamp(ndl * 0.5 + 0.5, 0.0, 1.0);
	float band = smoothstep(ramp_low - ramp_softness, ramp_low + ramp_softness, lit) * 0.5
		+ smoothstep(ramp_high - ramp_softness, ramp_high + ramp_softness, lit) * 0.5;
	band *= ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR * band * light_boost / PI;
}
