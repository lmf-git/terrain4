extends Node3D
class_name TectonicTerrain

## Realistic spherical terrain with tectonic plates and polar regions
## Based on plate tectonics simulation for realistic terrain

@export_group("Planet Properties")
@export var planet_radius: float = 100.0
@export var terrain_height: float = 15.0
@export var subdivisions: int = 6  # Increased for smoother terrain

@export_group("Tectonic Plates")
@export var num_plates: int = 8
@export var plate_seed: int = 12345
@export var mountain_height: float = 1.0  # Mountains at plate boundaries
@export var ocean_depth: float = 0.3  # Oceanic vs continental plates

@export_group("Polar Regions")
@export var polar_flatness: float = 0.7  # How flat poles are (0-1)
@export var polar_extent: float = 0.3  # How far from poles (0-1)

@export_group("Terrain Variation")
@export var continental_roughness: float = 0.3  # Less bumpy
@export var oceanic_smoothness: float = 0.9  # Very smooth oceans
@export var erosion_amount: float = 0.5  # Smoothing factor

var noise: FastNoiseLite
var plate_noise: FastNoiseLite
var terrain_material: StandardMaterial3D
var terrain_meshes: Array[MeshInstance3D] = []

# Tectonic plate data
var plate_centers: Array[Vector3] = []
var plate_types: Array[float] = []  # 0 = oceanic, 1 = continental

func _ready() -> void:
	setup_noise()
	setup_plates()
	setup_material()
	generate_terrain()

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

func setup_material() -> void:
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
		base_height = 0.2
	else:
		# Oceanic plate - below sea level
		base_height = -ocean_depth

	# Mountains at plate boundaries
	var mountain = boundary_strength * mountain_height

	# Add smooth terrain variation
	var terrain_detail = noise.get_noise_3d(normal.x * 5, normal.y * 5, normal.z * 5)

	# Apply different roughness based on plate type
	if plate_type > 0.5:
		# Continental - some roughness
		terrain_detail *= continental_roughness
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
		mountain *= (1.0 - polar_blend * 0.7)
		terrain_detail *= (1.0 - polar_blend * 0.8)

	# Combine all height factors
	var total_height = (base_height + mountain + terrain_detail) * terrain_height

	# Apply erosion (smoothing)
	total_height *= (1.0 - erosion_amount * 0.3)

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

	var faces: Array = [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]
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

	# Add collision after adding to scene tree
	call_deferred("add_collision_to_mesh", mesh_instance)

func add_collision_to_mesh(mesh_instance: MeshInstance3D) -> void:
	# Create collision shape from mesh
	mesh_instance.create_trimesh_collision()
