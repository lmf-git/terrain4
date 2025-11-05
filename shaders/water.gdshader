shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Water properties
uniform vec4 water_color_deep : source_color = vec4(0.0, 0.1, 0.3, 0.95);
uniform vec4 water_color_shallow : source_color = vec4(0.0, 0.4, 0.6, 0.8);
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float roughness : hint_range(0.0, 1.0) = 0.1;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

// Wave properties
uniform float wave_speed = 0.5;
uniform float wave_scale = 1.0;
uniform float wave_height = 0.3;
uniform float time = 0.0;

// Fresnel
uniform float fresnel_power : hint_range(0.0, 5.0) = 2.0;

// Noise function for waves
vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)),
			 dot(p, vec3(269.5, 183.3, 246.1)),
			 dot(p, vec3(113.5, 271.9, 124.6)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);

	return mix(mix(mix(dot(hash3(i + vec3(0.0, 0.0, 0.0)), f - vec3(0.0, 0.0, 0.0)),
					   dot(hash3(i + vec3(1.0, 0.0, 0.0)), f - vec3(1.0, 0.0, 0.0)), u.x),
				   mix(dot(hash3(i + vec3(0.0, 1.0, 0.0)), f - vec3(0.0, 1.0, 0.0)),
					   dot(hash3(i + vec3(1.0, 1.0, 0.0)), f - vec3(1.0, 1.0, 0.0)), u.x), u.y),
			   mix(mix(dot(hash3(i + vec3(0.0, 0.0, 1.0)), f - vec3(0.0, 0.0, 1.0)),
					   dot(hash3(i + vec3(1.0, 0.0, 1.0)), f - vec3(1.0, 0.0, 1.0)), u.x),
				   mix(dot(hash3(i + vec3(0.0, 1.0, 1.0)), f - vec3(0.0, 1.0, 1.0)),
					   dot(hash3(i + vec3(1.0, 1.0, 1.0)), f - vec3(1.0, 1.0, 1.0)), u.x), u.y), u.z);
}

// Layered noise for ocean waves
float get_wave_height(vec3 world_pos) {
	float wave_time = time * wave_speed;

	float h = 0.0;
	h += noise(world_pos * 0.5 * wave_scale + vec3(wave_time, 0.0, wave_time)) * 0.5;
	h += noise(world_pos * 1.0 * wave_scale + vec3(wave_time * 1.3, 0.0, wave_time * 1.3)) * 0.25;
	h += noise(world_pos * 2.0 * wave_scale + vec3(wave_time * 1.7, 0.0, wave_time * 1.7)) * 0.125;

	return h * wave_height;
}

void vertex() {
	// Apply wave displacement
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 normal_dir = normalize(world_pos);

	float wave = get_wave_height(world_pos);
	VERTEX += NORMAL * wave;

	// Calculate wave-based normal offset for lighting
	float offset = 0.1;
	vec3 pos_x = world_pos + vec3(offset, 0.0, 0.0);
	vec3 pos_z = world_pos + vec3(0.0, 0.0, offset);

	float h_x = get_wave_height(pos_x);
	float h_z = get_wave_height(pos_z);

	vec3 tangent = normalize(vec3(offset, h_x - wave, 0.0));
	vec3 bitangent = normalize(vec3(0.0, h_z - wave, offset));
	vec3 wave_normal = cross(tangent, bitangent);

	NORMAL = normalize(mix(NORMAL, wave_normal, 0.5));
}

void fragment() {
	// Fresnel effect
	vec3 view_dir = normalize(VIEW);
	float fresnel = pow(1.0 - abs(dot(NORMAL, view_dir)), fresnel_power);

	// Mix shallow and deep water based on fresnel
	vec3 water_color = mix(water_color_deep.rgb, water_color_shallow.rgb, fresnel);

	// Add some foam on wave peaks
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wave = get_wave_height(world_pos);
	float foam = smoothstep(wave_height * 0.5, wave_height * 0.8, wave);
	water_color = mix(water_color, foam_color.rgb, foam * 0.3);

	ALBEDO = water_color;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	ALPHA = mix(water_color_deep.a, water_color_shallow.a, fresnel);

	// Add some subsurface scattering effect
	SPECULAR = 0.5;
}
