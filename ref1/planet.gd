extends Node3D

## Simplified planet with cliffs and water

@export var radius: float = 100.0
@export var terrain_height: float = 15.0
@export var detail: int = 64
@export var cliff_steepness: float = 0.15  # Higher = more cliffs (0.15 = smoother)

@export_group("Color Palette")
@export var water_color: Color = Color(0.1, 0.3, 0.7)
@export var sand_color: Color = Color(0.9, 0.8, 0.6)
@export var grass_color: Color = Color(0.3, 0.6, 0.2)
@export var rock_color: Color = Color(0.5, 0.45, 0.4)
@export var snow_color: Color = Color(0.95, 0.95, 1.0)

@export_group("Atmosphere")
@export var atmosphere_enabled: bool = true
@export var atmosphere_color: Color = Color(0.4, 0.6, 1.0, 0.3)
@export var atmosphere_thickness: float = 10.0

@export_group("Cities")
@export var num_cities: int = 3
@export var city_min_buildings: int = 5
@export var city_max_buildings: int = 15
@export var city_flatten_radius: float = 20.0

@export_group("Caves")
@export var num_caves: int = 8
@export var cave_marker_size: float = 5.0

var mesh_instance: MeshInstance3D
var atmosphere_mesh: MeshInstance3D
var noise: FastNoiseLite
var city_locations: Array = []  # Store city center positions
var cave_locations: Array = []  # Store cave entrance positions

func _ready():
	_setup_noise()
	_generate_city_locations()
	_generate_cave_locations()
	_create_planet()
	if atmosphere_enabled:
		_create_atmosphere()
	# Defer city and cave creation until after node is in tree
	call_deferred("_create_cities")
	call_deferred("_create_caves")

func _setup_noise():
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.015  # Lower = smoother
	noise.fractal_octaves = 4  # Reduced for smoothness
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5

func _generate_city_locations():
	# Generate random city positions on sphere
	city_locations.clear()
	for i in range(num_cities):
		var theta = randf() * PI
		var phi = randf() * 2.0 * PI
		var x = sin(theta) * cos(phi)
		var y = cos(theta)
		var z = sin(theta) * sin(phi)
		var normal = Vector3(x, y, z)
		city_locations.append(normal)

func _generate_cave_locations():
	# Generate random cave entrance positions
	cave_locations.clear()
	for i in range(num_caves):
		var theta = randf() * PI
		var phi = randf() * 2.0 * PI
		var x = sin(theta) * cos(phi)
		var y = cos(theta)
		var z = sin(theta) * sin(phi)
		var normal = Vector3(x, y, z)
		cave_locations.append(normal)

func _create_planet():
	# Create static body first
	var body = StaticBody3D.new()
	add_child(body)

	# Create mesh
	mesh_instance = MeshInstance3D.new()
	var terrain_mesh = _generate_sphere_mesh()
	mesh_instance.mesh = terrain_mesh

	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mesh_instance.set_surface_override_material(0, mat)

	body.add_child(mesh_instance)

	# Create collision from terrain mesh
	var shape = CollisionShape3D.new()
	shape.shape = terrain_mesh.create_trimesh_shape()
	body.add_child(shape)

func _generate_sphere_mesh() -> ArrayMesh:
	var verts = PackedVector3Array()
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

			# Multi-octave terrain with enhanced features
			var base_height = noise.get_noise_3d(x * 100, y * 100, z * 100)
			var height = base_height

			# Add secondary noise for detail (subtle)
			var detail_noise = noise.get_noise_3d(x * 300, y * 300, z * 300)
			height += detail_noise * 0.08

			# Create occasional cliffs (reduced intensity)
			var cliff_mask = abs(height)
			if cliff_mask > 0.5:  # Only on steeper areas
				var cliff_modifier = pow(cliff_mask, 2.0)
				height = height * cliff_modifier * 1.2

			# Add subtle ridges
			var ridge_noise = abs(noise.get_noise_3d(x * 120, y * 120, z * 120))
			ridge_noise = 1.0 - ridge_noise
			ridge_noise = pow(ridge_noise, 2.5)
			height += ridge_noise * 0.15

			# Add occasional canyons (less frequent)
			var canyon_noise = noise.get_noise_3d(x * 60, y * 60, z * 60)
			if canyon_noise < -0.7:  # Rarer canyons
				var canyon_depth = (canyon_noise + 0.7) * 1.5
				height += canyon_depth

			height = height * terrain_height

			# Flatten terrain near cities AFTER features
			for i in range(city_locations.size()):
				var city_normal = city_locations[i]
				var angular_distance = acos(clamp(normal.dot(city_normal), -1.0, 1.0))
				var linear_distance = angular_distance * radius

				if linear_distance < city_flatten_radius:
					# Calculate base height at city center
					var city_base_height = noise.get_noise_3d(
						city_normal.x * 100,
						city_normal.y * 100,
						city_normal.z * 100
					) * terrain_height

					var flatten_amount = 1.0 - (linear_distance / city_flatten_radius)
					flatten_amount = smoothstep(0.0, 1.0, flatten_amount)
					height = lerp(height, city_base_height, flatten_amount)
					break

			# Final position
			var pos = normal * (radius + height)

			verts.append(pos)
			normals.append(normal)

			# Color based on height
			var color = _get_terrain_color(height, normal.y)
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

	# Recalculate normals based on actual geometry
	var recalc_normals = PackedVector3Array()
	recalc_normals.resize(verts.size())

	# Initialize to zero
	for i in range(verts.size()):
		recalc_normals[i] = Vector3.ZERO

	# Calculate face normals and accumulate
	for i in range(0, indices.size(), 3):
		var i0 = indices[i]
		var i1 = indices[i + 1]
		var i2 = indices[i + 2]

		var v0 = verts[i0]
		var v1 = verts[i1]
		var v2 = verts[i2]

		var edge1 = v1 - v0
		var edge2 = v2 - v0
		var face_normal = edge1.cross(edge2).normalized()

		recalc_normals[i0] += face_normal
		recalc_normals[i1] += face_normal
		recalc_normals[i2] += face_normal

	# Normalize
	for i in range(recalc_normals.size()):
		recalc_normals[i] = recalc_normals[i].normalized()

	# Create mesh
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = recalc_normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _get_terrain_color(height: float, latitude: float) -> Color:
	var color: Color

	# Check if in city zone - make flat areas brown/gray
	for city_normal in city_locations:
		var current_normal = Vector3(0, 1, 0)  # Will be set properly during generation
		var angular_distance = acos(clamp(current_normal.dot(city_normal), -1.0, 1.0))
		var linear_distance = angular_distance * radius
		if linear_distance < city_flatten_radius:
			color = Color(0.4, 0.35, 0.3)  # Brown city platform
			return color

	# Enhanced terrain colors based on height
	if height < -8.0:
		# Deep water
		color = water_color
	elif height < -2.0:
		# Sand/shore
		var t = (height + 8.0) / 6.0
		color = water_color.lerp(sand_color, t)
	elif height < 0.0:
		# Beach/lowlands
		color = sand_color
	elif height < 8.0:
		# Grass/plains
		color = grass_color
	elif height < 20.0:
		# Rocky hills
		var t = (height - 8.0) / 12.0
		color = grass_color.lerp(rock_color, t)
	elif height < 35.0:
		# Mountain rock
		color = rock_color
	elif height < 45.0:
		# High peaks transition to snow
		var t = (height - 35.0) / 10.0
		color = rock_color.lerp(snow_color, t)
	else:
		# Snow peaks and cliffs
		color = snow_color

	# Polar caps
	var polar = abs(latitude)
	if polar > 0.7:
		var ice_blend = (polar - 0.7) / 0.3
		color = color.lerp(snow_color, ice_blend)

	return color

func _create_atmosphere():
	# Create slightly larger sphere for atmosphere
	atmosphere_mesh = MeshInstance3D.new()
	var atmo_sphere = SphereMesh.new()
	atmo_sphere.radius = radius + atmosphere_thickness
	atmo_sphere.height = (radius + atmosphere_thickness) * 2.0
	atmo_sphere.radial_segments = 32
	atmo_sphere.rings = 16
	atmosphere_mesh.mesh = atmo_sphere

	# Atmosphere shader material
	var atmo_mat = ShaderMaterial.new()
	atmo_mat.shader = _create_atmosphere_shader()
	atmo_mat.set_shader_parameter("atmosphere_color", atmosphere_color)
	atmosphere_mesh.set_surface_override_material(0, atmo_mat)

	add_child(atmosphere_mesh)

func _create_atmosphere_shader() -> Shader:
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_front, unshaded;

uniform vec4 atmosphere_color: source_color = vec4(0.4, 0.6, 1.0, 0.3);

void fragment() {
	// Fresnel effect - glow at edges
	vec3 normal = normalize(NORMAL);
	vec3 view = normalize(VIEW);
	float fresnel = pow(1.0 - abs(dot(normal, view)), 3.0);

	ALBEDO = atmosphere_color.rgb;
	ALPHA = fresnel * atmosphere_color.a;
}
"""
	return shader

func _create_cities():
	print("Creating ", city_locations.size(), " cities...")
	for city_normal in city_locations:
		_generate_city(city_normal)
	print("Cities created!")

func _generate_city(city_center_normal: Vector3):
	# Calculate city position using EXACT same calculation as terrain
	var city_base_height = noise.get_noise_3d(
		city_center_normal.x * 100,
		city_center_normal.y * 100,
		city_center_normal.z * 100
	)  # Don't multiply by terrain_height yet - matches terrain calculation

	# Apply terrain_height multiplier (matches line 176 in terrain generation)
	city_base_height = city_base_height * terrain_height

	var city_pos = city_center_normal * (radius + city_base_height)
	print("  City height: ", city_base_height, " at position: ", city_pos)

	# Create city container
	var city_node = Node3D.new()
	city_node.name = "City"
	add_child(city_node)
	# Set position after adding to tree
	city_node.global_position = city_pos

	# Create random buildings
	var num_buildings = randi_range(city_min_buildings, city_max_buildings)
	print("  Generating city at ", city_pos, " with ", num_buildings, " buildings")

	for i in range(num_buildings):
		_create_building(city_node, city_center_normal, city_pos)

func _create_building(city_node: Node3D, city_normal: Vector3, city_center: Vector3):
	# Random building dimensions - much larger for visibility on big planet
	var width = randf_range(8.0, 20.0)
	var depth = randf_range(8.0, 20.0)
	var height = randf_range(15.0, 60.0)

	# Random position within city radius
	var angle = randf() * TAU
	var distance = randf() * (city_flatten_radius * 0.8)

	# Create tangent space for city (up = city_normal)
	var up = city_normal
	var right = Vector3.UP.cross(up)
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT.cross(up)
	right = right.normalized()
	var forward = up.cross(right).normalized()

	# Position building on the flat platform
	var offset = right * cos(angle) * distance + forward * sin(angle) * distance
	var building_base = city_center + offset

	# Create building mesh
	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(width, height, depth)
	mesh_inst.mesh = box_mesh

	# Varied building colors - cities have different color schemes
	var building_colors = [
		Color(0.9, 0.9, 0.9),   # White/concrete
		Color(0.3, 0.3, 0.35),  # Dark gray
		Color(0.6, 0.5, 0.4),   # Brown/brick
		Color(0.7, 0.8, 0.9),   # Light blue/glass
		Color(0.5, 0.6, 0.5),   # Green tinted
		Color(0.8, 0.7, 0.6),   # Tan/sandstone
		Color(0.4, 0.4, 0.5),   # Blue-gray
		Color(0.85, 0.75, 0.65), # Beige
	]
	var mat = StandardMaterial3D.new()
	mat.albedo_color = building_colors[randi() % building_colors.size()]
	mat.roughness = randf_range(0.6, 0.95)
	mat.metallic = randf_range(0.0, 0.3)
	mesh_inst.set_surface_override_material(0, mat)

	# Add mesh to city first
	city_node.add_child(mesh_inst)

	# Position and orient building after adding to tree
	mesh_inst.global_position = building_base + up * (height * 0.5)

	# Align building to planet normal
	var building_transform = Transform3D()
	building_transform.basis.x = right
	building_transform.basis.y = up
	building_transform.basis.z = forward
	building_transform.origin = building_base + up * (height * 0.5)
	mesh_inst.global_transform = building_transform

	# Add collision
	var static_body = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(width, height, depth)
	collision_shape.shape = box_shape
	static_body.add_child(collision_shape)
	mesh_inst.add_child(static_body)

func _create_caves():
	print("Creating ", cave_locations.size(), " cave entrances...")
	for cave_normal in cave_locations:
		_create_cave_entrance(cave_normal)
	print("Cave entrances created!")

func _create_cave_entrance(cave_normal: Vector3):
	# Calculate cave position on terrain
	var cave_height = noise.get_noise_3d(
		cave_normal.x * 100,
		cave_normal.y * 100,
		cave_normal.z * 100
	) * terrain_height

	# Only place caves on land (not underwater or in cities)
	if cave_height < -2.0:
		return

	# Check if too close to city
	for city_normal in city_locations:
		var distance = cave_normal.distance_to(city_normal)
		if distance < 0.3:  # Too close to city
			return

	var cave_pos = cave_normal * (radius + cave_height)

	# Create cave entrance marker (dark opening)
	var cave_marker = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = cave_marker_size
	sphere.height = cave_marker_size * 2.0
	cave_marker.mesh = sphere

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.05, 0.0)  # Dark brown/black
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.1, 0.0)  # Slight glow
	mat.emission_energy_multiplier = 0.3
	cave_marker.set_surface_override_material(0, mat)

	add_child(cave_marker)
	cave_marker.global_position = cave_pos
