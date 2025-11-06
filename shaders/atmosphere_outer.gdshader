shader_type spatial;
render_mode blend_add, depth_draw_always, cull_back, unshaded;

uniform float planet_radius = 100.0;
uniform float atmosphere_radius = 110.0;
uniform vec4 atmosphere_color : source_color = vec4(0.4, 0.65, 1.0, 1.0);
uniform float density = 0.12;

void vertex() {
	// No vertex modifications needed
}

void fragment() {
	// Get view direction and camera position
	vec3 view_dir = normalize(VIEW);
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 camera_pos = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;

	float dist_from_center = length(world_pos);
	float camera_dist_from_center = length(camera_pos);

	// Strong rim lighting effect for outer glow
	float rim = 1.0 - abs(dot(NORMAL, view_dir));
	rim = pow(rim, 1.5);  // Strong edge glow
	rim = smoothstep(0.0, 1.0, rim);

	// Density falloff from planet surface
	float density_factor = (dist_from_center - planet_radius) / (atmosphere_radius - planet_radius);
	density_factor = 1.0 - density_factor;
	density_factor = smoothstep(0.0, 1.0, density_factor);

	// Enhanced glow when viewing from outside
	float glow_factor = 1.0;
	if (camera_dist_from_center > atmosphere_radius) {
		// Camera is outside - enhance the limb glow
		glow_factor = 1.5;
	}

	// Combine effects for strong outer atmosphere glow
	float atmosphere_strength = rim * density_factor * glow_factor * density;
	atmosphere_strength = clamp(atmosphere_strength, 0.0, 0.4);

	ALBEDO = atmosphere_color.rgb;
	ALPHA = atmosphere_strength;
}
