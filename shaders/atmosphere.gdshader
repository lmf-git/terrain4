shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_front, unshaded;

uniform float planet_radius = 100.0;
uniform float atmosphere_radius = 110.0;
uniform vec4 atmosphere_color : source_color = vec4(0.5, 0.7, 1.0, 1.0);
uniform float density = 0.3;

void vertex() {
	// No vertex modifications needed
}

void fragment() {
	// Get view direction
	vec3 view_dir = normalize(VIEW);

	// Calculate distance from center
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist_from_center = length(world_pos);

	// Smoother rim lighting effect
	float rim = 1.0 - abs(dot(NORMAL, view_dir));
	rim = pow(rim, 2.5);  // Less harsh falloff
	rim = smoothstep(0.0, 1.0, rim);  // Smooth the transition

	// Gradual density falloff from planet surface
	float density_factor = (dist_from_center - planet_radius) / (atmosphere_radius - planet_radius);
	density_factor = 1.0 - density_factor;
	density_factor = smoothstep(0.0, 1.0, density_factor);  // Smooth transition

	// Combine effects with gradual falloff
	float atmosphere_strength = rim * density_factor * density;
	atmosphere_strength = clamp(atmosphere_strength, 0.0, 0.5);  // Cap maximum intensity

	ALBEDO = atmosphere_color.rgb;
	ALPHA = atmosphere_strength;
}
