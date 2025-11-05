shader_type spatial;
render_mode blend_add, depth_draw_never, cull_front, unshaded;

uniform float planet_radius = 100.0;
uniform float atmosphere_radius = 110.0;
uniform vec4 atmosphere_color : source_color = vec4(0.4, 0.6, 1.0, 1.0);
uniform float density = 0.5;

void vertex() {
	// No vertex modifications needed
}

void fragment() {
	// Get view direction
	vec3 view_dir = normalize(VERTEX - VIEW);

	// Calculate distance from center
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist_from_center = length(world_pos);

	// Calculate atmosphere effect based on angle
	float rim = 1.0 - abs(dot(NORMAL, view_dir));
	rim = pow(rim, 3.0);

	// Calculate density falloff
	float density_factor = (dist_from_center - planet_radius) / (atmosphere_radius - planet_radius);
	density_factor = 1.0 - density_factor;

	// Combine effects
	float atmosphere_strength = rim * density_factor * density;

	ALBEDO = atmosphere_color.rgb;
	ALPHA = atmosphere_strength;
}
