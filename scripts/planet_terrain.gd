extends Node3D
class_name PlanetTerrain

## Unified spherical terrain system with all features
## Combines simple noise, tectonic plates, cities, caves, and advanced shaders

@export_group("Planet Properties")
@export var planet_radius: float = 100.0
@export var terrain_height: float = 15.0
@export var subdivisions: int = 6  # Mesh detail level

@export_group("Feature Toggles")
@export var enable_tectonic_plates: bool = true
@export var enable_cities: bool = true
@export var enable_caves: bool = true
@export var enable_advanced_shader: bool = true

@export_group("Tectonic Plates")
@export var num_plates: int = 8
@export var plate_seed: int = 12345
@export var mountain_height: float = 1.5  # Mountains at plate boundaries
@export var ocean_depth: float = 0.02  # Oceanic vs continental plates

@export_group("Polar Regions")
@export var polar_flatness: float = 0.7  # How flat poles are (0-1)
@export var polar_extent: float = 0.3  # How far from poles (0-1)

@export_group("Terrain Variation")
@export var continental_roughness: float = 0.3  # Less bumpy
@export var oceanic_smoothness: float = 0.9  # Very smooth oceans
@export var erosion_amount: float = 0.5  # Smoothing factor

@export_group("Cities and Caves")
@export var num_cities: int = 5
@export var num_caves: int = 10
@export var city_flatten_radius: float = 15.0
@export var city_flatten_strength: float = 0.9

var noise: FastNoiseLite
var plate_noise: FastNoiseLite
var terrain_material: Material
var terrain_meshes: Array[MeshInstance3D] = []

# Tectonic plate data
var plate_centers: Array[Vector3] = []
var plate_types: Array[float] = []  # 0 = oceanic, 1 = continental

# City and cave data
var city_locations: Array[Vector3] = []
var city_heights: Array[float] = []
var cave_locations: Array[Vector3] = []

func _ready() -> void:
	setup_noise()
	if enable_tectonic_plates:
		setup_plates()
	if enable_cities or enable_caves:
		generate_city_and_cave_locations()
	setup_material()
	generate_terrain()
	if enable_cities or enable_caves:
		generate_cities_and_caves()

func setup_noise() -> void:
	# Main terrain noise - smooth
	noise = FastNoiseLite.new()
	noise.seed = plate_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.fractal_octaves = 3  # Reduced for smoother terrain
	noise.fractal_gain = 0.4
	noise.fractal_lacunarity = 2.5
	noise.frequency = 0.3  # Larger features

	# Plate boundary noise
	plate_noise = FastNoiseLite.new()
	plate_noise.seed = plate_seed + 1000
	plate_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	plate_noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	plate_noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	plate_noise.frequency = 0.8

func setup_plates() -> void:
	# Generate random tectonic plate centers on sphere
	var rng = RandomNumberGenerator.new()
	rng.seed = plate_seed

	for i in range(num_plates):
		# Generate random point on sphere
		var theta = rng.randf_range(0, TAU)
		var phi = rng.randf_range(-PI/2, PI/2)

		var x = cos(phi) * cos(theta)
		var y = sin(phi)
		var z = cos(phi) * sin(theta)

		plate_centers.append(Vector3(x, y, z).normalized())

		# Random plate type (oceanic or continental)
		plate_types.append(rng.randf())

func generate_city_and_cave_locations() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = plate_seed + 5000

	# Generate city locations on continental plates (above water)
	for i in range(num_cities):
		var theta = rng.randf_range(0, TAU)
		var phi = rng.randf_range(-PI/2, PI/2)

		var x = cos(phi) * cos(theta)
		var y = sin(phi)
		var z = cos(phi) * sin(theta)

		var city_normal = Vector3(x, y, z).normalized()

		# Calculate base terrain height at this location
		var base_height = get_base_terrain_height(city_normal)

		# Only place cities on land (continental plates above water)
		if base_height > 0.0:
			city_locations.append(city_normal)
			city_heights.append(base_height)

	# Generate cave locations
	for i in range(num_caves):
		var theta = rng.randf_range(0, TAU)
		var phi = rng.randf_range(-PI/2, PI/2)

		var x = cos(phi) * cos(theta)
		var y = sin(phi)
		var z = cos(phi) * sin(theta)

		var cave_normal = Vector3(x, y, z).normalized()
		cave_locations.append(cave_normal)

func get_base_terrain_height(normal: Vector3) -> float:
	# Quick version of get_terrain_height for city placement
	var nearest_plate_dist = 999999.0
	var plate_type = 0.5

	for i in range(plate_centers.size()):
		var dist = normal.distance_to(plate_centers[i])
		if dist < nearest_plate_dist:
			nearest_plate_dist = dist
			plate_type = plate_types[i]

	# Continental vs oceanic
	if plate_type > 0.5:
		return 0.2 * terrain_height  # Continental
	else:
		return -ocean_depth * terrain_height  # Oceanic

func setup_material() -> void:
	if enable_advanced_shader:
		# Use advanced triplanar shader with procedural textures
		var shader = load("res://shaders/terrain_triplanar.gdshader")
		if shader:
			terrain_material = ShaderMaterial.new()
			terrain_material.shader = shader
			# Set biome levels to match terrain generation
			# Oceanic floor: -0.3, Continental base: 3.75, Mountains: up to ~14
			terrain_material.set_shader_parameter("water_level", -ocean_depth * terrain_height)
			terrain_material.set_shader_parameter("sand_level", 0.5)
			terrain_material.set_shader_parameter("grass_level", 3.0)
			terrain_material.set_shader_parameter("rock_level", 7.0)
			terrain_material.set_shader_parameter("snow_level", 11.0)
		else:
			# Fallback to simple material
			terrain_material = StandardMaterial3D.new()
			terrain_material.albedo_color = Color(0.45, 0.4, 0.3)
			terrain_material.roughness = 0.9
			terrain_material.metallic = 0.0
			terrain_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	else:
		# Simple material
		terrain_material = StandardMaterial3D.new()
		terrain_material.albedo_color = Color(0.45, 0.4, 0.3)
		terrain_material.roughness = 0.9
		terrain_material.metallic = 0.0
		terrain_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

func generate_terrain() -> void:
	var vertices: PackedVector3Array = []
	var indices: PackedInt32Array = []

	create_icosahedron(vertices, indices)

	# More subdivisions for smoother terrain
	for i in range(subdivisions):
		subdivide_mesh(vertices, indices)

	# Apply tectonic-based heightmap
	for i in range(vertices.size()):
		var vertex = vertices[i].normalized()
		var height = get_terrain_height(vertex)
		vertices[i] = vertex * (planet_radius + height)

	create_mesh_from_data(vertices, indices)

func get_terrain_height(normal: Vector3) -> float:
	var total_height: float

	if enable_tectonic_plates and plate_centers.size() > 0:
		# Tectonic plate mode
		total_height = get_tectonic_height(normal)
	else:
		# Simple noise mode
		total_height = get_simple_height(normal)

	# City flattening (if enabled)
	if enable_cities:
		total_height = apply_city_flattening(normal, total_height)

	return total_height

func get_simple_height(normal: Vector3) -> float:
	# Simple noise-based terrain
	var height = noise.get_noise_3d(normal.x * 5, normal.y * 5, normal.z * 5)
	return height * terrain_height

func get_tectonic_height(normal: Vector3) -> float:
	# Calculate latitude (-1 to 1, -1 = south pole, 1 = north pole)
	var latitude = normal.y

	# Find nearest plate and distance to plate boundaries
	var nearest_plate_dist = 999999.0
	var second_nearest_dist = 999999.0
	var plate_type = 0.5

	for i in range(plate_centers.size()):
		var dist = normal.distance_to(plate_centers[i])
		if dist < nearest_plate_dist:
			second_nearest_dist = nearest_plate_dist
			nearest_plate_dist = dist
			plate_type = plate_types[i]
		elif dist < second_nearest_dist:
			second_nearest_dist = dist

	# Plate boundary detection (where two plates meet)
	var boundary_strength = abs(nearest_plate_dist - second_nearest_dist)
	boundary_strength = 1.0 - clamp(boundary_strength * 10.0, 0.0, 1.0)

	# Base height from plate type
	var base_height = 0.0
	if plate_type > 0.5:
		# Continental plate - above sea level
		base_height = 0.25
	else:
		# Oceanic plate - below sea level
		base_height = -ocean_depth

	# Mountains at plate boundaries - barely visible, just subtle ridges
	var boundary_mountain = boundary_strength * mountain_height * 0.05

	# Add proper mountain ranges across continents using multi-octave noise
	var mountain_noise = 0.0
	if plate_type > 0.5:  # Only on continental plates
		# Large-scale mountain ranges - MUCH STRONGER
		var mountain_base = noise.get_noise_3d(normal.x * 2, normal.y * 2, normal.z * 2)
		mountain_base = abs(mountain_base)  # Ridge-like mountains
		mountain_base = pow(mountain_base, 1.8)  # Sharper, taller peaks

		# Medium-scale hills
		var hills = noise.get_noise_3d(normal.x * 4, normal.y * 4, normal.z * 4) * 0.6

		# Additional large mountain features
		var large_mountains = noise.get_noise_3d(normal.x * 1.5, normal.y * 1.5, normal.z * 1.5)
		large_mountains = abs(large_mountains) * 0.8

		# Small-scale detail
		var detail = noise.get_noise_3d(normal.x * 8, normal.y * 8, normal.z * 8) * 0.3

		mountain_noise = (mountain_base + hills + large_mountains + detail) * mountain_height * 2.5

	# Add smooth terrain variation
	var terrain_detail = noise.get_noise_3d(normal.x * 5, normal.y * 5, normal.z * 5)

	# Apply different roughness based on plate type
	if plate_type > 0.5:
		# Continental - some roughness
		terrain_detail *= continental_roughness * 0.5
	else:
		# Oceanic - very smooth
		terrain_detail *= (1.0 - oceanic_smoothness) * 0.2

	# Polar flattening
	var polar_factor = abs(latitude)
	if polar_factor > (1.0 - polar_extent):
		var polar_blend = (polar_factor - (1.0 - polar_extent)) / polar_extent
		polar_blend = smoothstep(0.0, 1.0, polar_blend)

		# Flatten terrain at poles
		base_height = lerp(base_height, 0.0, polar_blend * polar_flatness)
		boundary_mountain *= (1.0 - polar_blend * 0.7)
		mountain_noise *= (1.0 - polar_blend * 0.8)
		terrain_detail *= (1.0 - polar_blend * 0.8)

	# Combine all height factors
	var total_height = (base_height + boundary_mountain + mountain_noise + terrain_detail) * terrain_height

	# Apply erosion (smoothing)
	total_height *= (1.0 - erosion_amount * 0.3)

	return total_height

func apply_city_flattening(normal: Vector3, current_height: float) -> float:
	var total_height = current_height

	# City flattening - flatten terrain around cities
	for i in range(city_locations.size()):
		var city_center = city_locations[i]
		var city_height = city_heights[i]

		# Calculate distance on sphere surface
		var arc_distance = acos(clamp(normal.dot(city_center), -1.0, 1.0))
		var linear_distance = arc_distance * planet_radius

		if linear_distance < city_flatten_radius:
			# Smooth falloff from city center
			var flatten_amount = 1.0 - (linear_distance / city_flatten_radius)
			flatten_amount = smoothstep(0.0, 1.0, flatten_amount)
			flatten_amount *= city_flatten_strength

			# Blend toward flat city platform
			total_height = lerp(total_height, city_height, flatten_amount)

	return total_height

func create_icosahedron(vertices: PackedVector3Array, indices: PackedInt32Array) -> void:
	var t: float = (1.0 + sqrt(5.0)) / 2.0

	var verts: Array = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)
	]

	for v in verts:
		vertices.append(v.normalized())

	# Reversed winding for outward-facing normals
	var faces: Array = [
		[0, 5, 11], [0, 1, 5], [0, 7, 1], [0, 10, 7], [0, 11, 10],
		[1, 9, 5], [5, 4, 11], [11, 2, 10], [10, 6, 7], [7, 8, 1],
		[3, 4, 9], [3, 2, 4], [3, 6, 2], [3, 8, 6], [3, 9, 8],
		[4, 5, 9], [2, 11, 4], [6, 10, 2], [8, 7, 6], [9, 1, 8]
	]

	for face in faces:
		indices.append(face[0])
		indices.append(face[1])
		indices.append(face[2])

func subdivide_mesh(vertices: PackedVector3Array, indices: PackedInt32Array) -> void:
	var new_indices: PackedInt32Array = []
	var midpoint_cache: Dictionary = {}

	for i in range(0, indices.size(), 3):
		var v0 = indices[i]
		var v1 = indices[i + 1]
		var v2 = indices[i + 2]

		var m0 = get_midpoint(v0, v1, vertices, midpoint_cache)
		var m1 = get_midpoint(v1, v2, vertices, midpoint_cache)
		var m2 = get_midpoint(v2, v0, vertices, midpoint_cache)

		new_indices.append_array([v0, m0, m2])
		new_indices.append_array([v1, m1, m0])
		new_indices.append_array([v2, m2, m1])
		new_indices.append_array([m0, m1, m2])

	indices.clear()
	indices.append_array(new_indices)

func get_midpoint(v1: int, v2: int, vertices: PackedVector3Array, cache: Dictionary) -> int:
	var key = str(min(v1, v2)) + "_" + str(max(v1, v2))
	if cache.has(key):
		return cache[key]

	var midpoint = ((vertices[v1] + vertices[v2]) / 2.0).normalized()
	var index = vertices.size()
	vertices.append(midpoint)
	cache[key] = index
	return index

func create_mesh_from_data(vertices: PackedVector3Array, indices: PackedInt32Array) -> void:
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)

	# Calculate smooth normals
	var normals: PackedVector3Array = []
	normals.resize(vertices.size())

	for i in range(0, indices.size(), 3):
		var i0 = indices[i]
		var i1 = indices[i + 1]
		var i2 = indices[i + 2]

		var v0 = vertices[i0]
		var v1 = vertices[i1]
		var v2 = vertices[i2]

		var normal = (v1 - v0).cross(v2 - v0).normalized()

		normals[i0] += normal
		normals[i1] += normal
		normals[i2] += normal

	for i in range(normals.size()):
		normals[i] = normals[i].normalized()

	# Create UVs
	var uvs: PackedVector2Array = []
	for vertex in vertices:
		var normal = vertex.normalized()
		var u = 0.5 + atan2(normal.z, normal.x) / (2 * PI)
		var v = 0.5 - asin(normal.y) / PI
		uvs.append(Vector2(u, v))

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = terrain_material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	add_child(mesh_instance)
	terrain_meshes.append(mesh_instance)

	# Add collision immediately after adding to scene tree
	mesh_instance.create_trimesh_collision()

func generate_cities_and_caves() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = plate_seed + 6000

	# Generate cities with buildings
	if enable_cities:
		for i in range(city_locations.size()):
			var city_center = city_locations[i]
			var city_height = city_heights[i]
			var city_pos = city_center * (planet_radius + city_height)

			var city_node = Node3D.new()
			city_node.name = "City_" + str(i)
			add_child(city_node)
			city_node.global_position = city_pos

			# Generate 5-15 buildings per city
			var num_buildings = rng.randi_range(5, 15)
			for j in range(num_buildings):
				create_building(city_node, city_center, city_pos, city_height, rng)

	# Generate cave entrance markers
	if enable_caves:
		for i in range(cave_locations.size()):
			var cave_normal = cave_locations[i]
			var cave_height = get_terrain_height(cave_normal)
			var cave_pos = cave_normal * (planet_radius + cave_height)

			# Create cave entrance marker (small dark cube)
			var cave_mesh = MeshInstance3D.new()
			var box_mesh = BoxMesh.new()
			box_mesh.size = Vector3(2.0, 2.0, 2.0)
			cave_mesh.mesh = box_mesh

			var cave_mat = StandardMaterial3D.new()
			cave_mat.albedo_color = Color(0.1, 0.05, 0.0)  # Dark brown
			cave_mesh.material_override = cave_mat

			cave_mesh.name = "Cave_" + str(i)

			# Add to tree first
			add_child(cave_mesh)

			# Then set position and orientation
			cave_mesh.global_position = cave_pos

			# Orient cave - construct basis manually to avoid colinear warning
			var forward = (global_position - cave_pos).normalized()
			# Get a perpendicular vector for "up" direction
			var right = Vector3.UP.cross(forward)
			if right.length_squared() < 0.01:
				# If forward is too close to UP, use RIGHT instead
				right = Vector3.RIGHT.cross(forward)
			right = right.normalized()
			var up = forward.cross(right).normalized()

			# Set the transform
			cave_mesh.global_transform.basis = Basis(right, up, -forward)

func create_building(city_node: Node3D, city_normal: Vector3, city_center: Vector3, city_height: float, rng: RandomNumberGenerator) -> void:
	# Random building size
	var width = rng.randf_range(4.0, 12.0)
	var depth = rng.randf_range(4.0, 12.0)
	var height = rng.randf_range(10.0, 40.0)

	# Random offset from city center (within city platform)
	var offset_distance = rng.randf_range(0.0, city_flatten_radius * 0.7)
	var offset_angle = rng.randf_range(0, TAU)

	# Calculate tangent space for city
	var up = city_normal
	var right = Vector3.UP.cross(up)
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT.cross(up)
	right = right.normalized()
	var forward = up.cross(right).normalized()

	# Position building with offset
	var offset = (right * cos(offset_angle) + forward * sin(offset_angle)) * offset_distance
	var building_pos = city_center * (planet_radius + city_height + height / 2.0) + offset

	# Create building mesh
	var building = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(width, height, depth)
	building.mesh = box_mesh

	# Random building color (grayish)
	var building_mat = StandardMaterial3D.new()
	var color_variation = rng.randf_range(0.3, 0.6)
	building_mat.albedo_color = Color(color_variation, color_variation, color_variation)
	building_mat.metallic = 0.2
	building_mat.roughness = 0.7
	building.material_override = building_mat

	# Add to tree first
	city_node.add_child(building)

	# Then set position and orientation
	building.global_position = building_pos

	# Orient building to point up from planet surface
	var building_transform = building.global_transform
	building_transform.basis.y = city_normal
	building_transform.basis.x = right
	building_transform.basis.z = forward
	building.global_transform = building_transform

	# Add collision to building
	building.create_trimesh_collision()
