shader_type spatial;
render_mode blend_add, depth_draw_always, cull_front, unshaded;

uniform float planet_radius = 500.0;
uniform float atmosphere_radius = 550.0;
uniform vec4 atmosphere_color : source_color = vec4(0.35, 0.6, 1.0, 1.0);
uniform float density = 0.2;

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

	// Distance from camera to this point
	float dist_to_camera = length(world_pos - camera_pos);

	// Rim lighting effect - works from all angles
	float rim = 1.0 - abs(dot(NORMAL, view_dir));
	rim = pow(rim, 2.0);
	rim = smoothstep(0.0, 1.0, rim);

	// Density falloff from planet surface
	float density_factor = (dist_from_center - planet_radius) / (atmosphere_radius - planet_radius);
	density_factor = 1.0 - density_factor;
	density_factor = smoothstep(0.0, 1.0, density_factor);

	// Distance fade - atmosphere fades when far from camera (for orbital view)
	float distance_fade = 1.0;
	if (camera_dist_from_center > atmosphere_radius) {
		// Camera is outside atmosphere - fade based on distance
		distance_fade = 1.0 - smoothstep(0.0, atmosphere_radius * 2.0, dist_to_camera);
	}

	// Viewing angle - fade when looking straight down from above
	float view_angle_factor = 1.0;
	if (camera_dist_from_center > atmosphere_radius) {
		// When outside, reduce intensity when looking directly at planet
		vec3 to_camera = normalize(camera_pos - world_pos);
		vec3 surface_normal = normalize(world_pos);
		float angle_to_surface = abs(dot(to_camera, surface_normal));
		view_angle_factor = 1.0 - pow(angle_to_surface, 4.0);
	}

	// Combine all effects
	float atmosphere_strength = rim * density_factor * distance_fade * view_angle_factor * density;
	atmosphere_strength = clamp(atmosphere_strength, 0.0, 0.3);

	ALBEDO = atmosphere_color.rgb;
	ALPHA = atmosphere_strength;
}
