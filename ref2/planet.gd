extends Node3D

## Simple planet for space sim
## Just works - no complexity

@export var radius: float = 100.0
@export var terrain_height: float = 10.0
@export var detail: int = 64  # vertices per side (32-128)

var mesh_instance: MeshInstance3D
var noise: FastNoiseLite

func _ready():
	_setup_noise()
	_create_planet()

func _setup_noise():
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.015
	noise.fractal_octaves = 5

func _create_planet():
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = _generate_sphere_mesh()

	# Shader material with detail
	var shader_mat = ShaderMaterial.new()
	shader_mat.shader = _create_terrain_shader()
	mesh_instance.set_surface_override_material(0, shader_mat)

	add_child(mesh_instance)

	# Collision
	var body = StaticBody3D.new()
	var shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	body.add_child(shape)
	add_child(body)

func _generate_sphere_mesh() -> ArrayMesh:
	verts = PackedVector3Array()
	var normals = PackedVector3Array()
	var colors = PackedColorArray()
	var indices = PackedInt32Array()

	# Generate sphere with terrain
	for lat in range(detail + 1):
		for lon in range(detail + 1):
			var theta = PI * float(lat) / float(detail)
			var phi = 2.0 * PI * float(lon) / float(detail)

			# Sphere position
			var x = sin(theta) * cos(phi)
			var y = cos(theta)
			var z = sin(theta) * sin(phi)
			var normal = Vector3(x, y, z)

			# Terrain height from noise
			var height = noise.get_noise_3d(x * 100, y * 100, z * 100)
			height = height * terrain_height

			# Final position
			var pos = normal * (radius + height)

			verts.append(pos)
			normals.append(normal)

			# Pass height and latitude to shader
			var color = _get_color(height, y)
			colors.append(color)

	# Generate triangles
	for lat in range(detail):
		for lon in range(detail):
			var i0 = lat * (detail + 1) + lon
			var i1 = i0 + 1
			var i2 = i0 + detail + 1
			var i3 = i2 + 1

			indices.append(i0)
			indices.append(i2)
			indices.append(i1)

			indices.append(i1)
			indices.append(i2)
			indices.append(i3)

	# Create mesh
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _get_color(height: float, latitude: float) -> Color:
	# Height is already in world units (can be negative or positive)
	# Normalize to 0-1 range where 0.5 = sea level
	var norm_height = (height / terrain_height) * 0.5 + 0.5
	var norm_lat = (latitude + 1.0) * 0.5  # -1 to 1 -> 0 to 1

	# Clamp
	norm_height = clamp(norm_height, 0.0, 1.0)
	norm_lat = clamp(norm_lat, 0.0, 1.0)

	# Debug output
	if verts.size() == 0:
		print("First vertex - Height: ", height, " Normalized: ", norm_height, " Lat: ", latitude)

	return Color(norm_height, norm_lat, 0, 1)

var verts: PackedVector3Array  # For debug

func _create_terrain_shader() -> Shader:
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_back;

varying vec3 world_pos;
varying vec3 vertex_normal;

// Noise functions for procedural textures
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amplitude * noise(p);
		p *= 2.0;
		amplitude *= 0.5;
	}
	return value;
}

void vertex() {
	world_pos = VERTEX;
	vertex_normal = NORMAL;
}

void fragment() {
	// Decode height and latitude from vertex colors
	float height = COLOR.r;
	float latitude = COLOR.g * 2.0 - 1.0;

	// Simple color test - if this shows colors, vertex colors are working
	// ALBEDO = vec3(height, 0.0, 1.0 - height);  // Gradient from blue to red
	// ROUGHNESS = 0.8;
	// return;

	// Triplanar projection coordinates
	vec3 blend_weights = abs(vertex_normal);
	blend_weights = blend_weights / (blend_weights.x + blend_weights.y + blend_weights.z);

	vec2 uv_x = world_pos.zy * 0.1;
	vec2 uv_y = world_pos.xz * 0.1;
	vec2 uv_z = world_pos.xy * 0.1;

	// Biome colors
	vec3 water = vec3(0.1, 0.3, 0.6);
	vec3 sand = vec3(0.9, 0.8, 0.6);
	vec3 grass = vec3(0.2, 0.6, 0.2);
	vec3 rock = vec3(0.5, 0.45, 0.4);
	vec3 snow = vec3(0.95, 0.95, 1.0);

	vec3 base_color;
	float roughness_val;

	// Determine base biome (height: 0.5 = sea level)
	if (height < 0.45) {
		// WATER - Animated ripples
		float ripples = fbm(uv_y * 5.0 + TIME * 0.1);
		base_color = water + vec3(0.05) * ripples;
		roughness_val = 0.1;
	}
	else if (height < 0.52) {
		// SAND - Grainy texture
		float sand_noise_x = fbm(uv_x * 20.0);
		float sand_noise_y = fbm(uv_y * 20.0);
		float sand_noise_z = fbm(uv_z * 20.0);
		float sand_noise = sand_noise_x * blend_weights.x +
						   sand_noise_y * blend_weights.y +
						   sand_noise_z * blend_weights.z;

		base_color = sand * (0.85 + sand_noise * 0.3);
		roughness_val = 0.95;

		// Blend to grass
		float t = (height - 0.48) / 0.04;
		base_color = mix(base_color, grass, t);
	}
	else if (height < 0.70) {
		// GRASS - Patchy detail
		float grass_x = fbm(uv_x * 15.0);
		float grass_y = fbm(uv_y * 15.0);
		float grass_z = fbm(uv_z * 15.0);
		float grass_noise = grass_x * blend_weights.x +
							grass_y * blend_weights.y +
							grass_z * blend_weights.z;

		vec3 dark_grass = vec3(0.2, 0.4, 0.15);
		base_color = mix(dark_grass, grass, grass_noise);

		// Add dirt patches
		float dirt_pattern = noise(uv_y * 8.0);
		if (dirt_pattern > 0.7) {
			vec3 dirt = vec3(0.4, 0.3, 0.2);
			base_color = mix(base_color, dirt, (dirt_pattern - 0.7) * 2.0);
		}

		roughness_val = 0.9;
	}
	else if (height < 0.80) {
		// ROCK - Craggy texture
		float rock_x = fbm(uv_x * 8.0);
		float rock_y = fbm(uv_y * 8.0);
		float rock_z = fbm(uv_z * 8.0);
		float rock_noise = rock_x * blend_weights.x +
						   rock_y * blend_weights.y +
						   rock_z * blend_weights.z;

		vec3 dark_rock = vec3(0.25, 0.22, 0.2);
		base_color = mix(dark_rock, rock, rock_noise);

		// Add cracks
		float cracks = noise(uv_y * 30.0);
		if (cracks < 0.3) {
			base_color *= 0.6;
		}

		roughness_val = 0.85;
	}
	else {
		// SNOW - Sparkly white
		float snow_x = fbm(uv_x * 12.0);
		float snow_y = fbm(uv_y * 12.0);
		float snow_z = fbm(uv_z * 12.0);
		float snow_noise = snow_x * blend_weights.x +
						   snow_y * blend_weights.y +
						   snow_z * blend_weights.z;

		base_color = snow * (0.9 + snow_noise * 0.2);
		roughness_val = 0.7;
	}

	// Polar ice caps
	float polar = abs(latitude);
	if (polar > 0.75) {
		float ice_blend = (polar - 0.75) / 0.25;
		base_color = mix(base_color, snow, ice_blend);
	}

	ALBEDO = base_color;
	ROUGHNESS = roughness_val;
	METALLIC = 0.0;
}
"""
	return shader
