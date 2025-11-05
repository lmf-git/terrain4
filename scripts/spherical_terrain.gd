extends Node3D
class_name SphericalTerrain

## Spherical terrain generator with LOD system
## Similar to ARMA 3 / Kerbal Space Program terrain

@export_group("Planet Properties")
@export var planet_radius: float = 100.0
@export var terrain_height: float = 8.0
@export var subdivisions: int = 6  # Number of icosphere subdivisions

@export_group("Terrain Generation")
@export var noise_scale: float = 0.3
@export var noise_octaves: int = 3
@export var noise_persistence: float = 0.4
@export var noise_lacunarity: float = 2.5
@export var seed_value: int = 12345

@export_group("LOD Settings")
@export var lod_levels: int = 4
@export var lod_distances: PackedFloat32Array = [50.0, 100.0, 200.0, 400.0]

var noise: FastNoiseLite
var terrain_meshes: Array[MeshInstance3D] = []
var terrain_material: StandardMaterial3D

func _ready() -> void:
	setup_noise()
	setup_material()
	generate_terrain()

func setup_noise() -> void:
	noise = FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_PERLIN  # Smoother than simplex
	noise.fractal_octaves = noise_octaves
	noise.fractal_gain = noise_persistence
	noise.fractal_lacunarity = noise_lacunarity
	noise.frequency = noise_scale

func setup_material() -> void:
	terrain_material = StandardMaterial3D.new()
	terrain_material.albedo_color = Color(0.4, 0.35, 0.25)
	terrain_material.roughness = 0.9
	terrain_material.metallic = 0.0
	terrain_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

func generate_terrain() -> void:
	# Generate base icosphere
	var vertices: PackedVector3Array = []
	var indices: PackedInt32Array = []

	# Create initial icosahedron
	create_icosahedron(vertices, indices)

	# Subdivide for higher detail
	for i in range(subdivisions):
		subdivide_mesh(vertices, indices)

	# Normalize vertices to sphere and apply heightmap
	for i in range(vertices.size()):
		var vertex = vertices[i]
		vertex = vertex.normalized()

		# Apply noise-based height
		var height = get_terrain_height(vertex)
		vertices[i] = vertex * (planet_radius + height)

	# Create mesh
	create_mesh_from_data(vertices, indices)

func create_icosahedron(vertices: PackedVector3Array, indices: PackedInt32Array) -> void:
	# Golden ratio
	var t: float = (1.0 + sqrt(5.0)) / 2.0

	# 12 vertices of icosahedron
	var verts: Array = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)
	]

	# Normalize
	for v in verts:
		vertices.append(v.normalized())

	# 20 faces of icosahedron
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

	# Process each triangle
	for i in range(0, indices.size(), 3):
		var v0 = indices[i]
		var v1 = indices[i + 1]
		var v2 = indices[i + 2]

		# Get midpoints
		var m0 = get_midpoint(v0, v1, vertices, midpoint_cache)
		var m1 = get_midpoint(v1, v2, vertices, midpoint_cache)
		var m2 = get_midpoint(v2, v0, vertices, midpoint_cache)

		# Create 4 new triangles
		new_indices.append_array([v0, m0, m2])
		new_indices.append_array([v1, m1, m0])
		new_indices.append_array([v2, m2, m1])
		new_indices.append_array([m0, m1, m2])

	indices.clear()
	indices.append_array(new_indices)

func get_midpoint(v1: int, v2: int, vertices: PackedVector3Array, cache: Dictionary) -> int:
	# Create unique key for edge
	var key = str(min(v1, v2)) + "_" + str(max(v1, v2))

	if cache.has(key):
		return cache[key]

	# Calculate midpoint
	var point1 = vertices[v1]
	var point2 = vertices[v2]
	var midpoint = ((point1 + point2) / 2.0).normalized()

	# Add to vertices
	var index = vertices.size()
	vertices.append(midpoint)
	cache[key] = index

	return index

func get_terrain_height(normal: Vector3) -> float:
	# Sample noise at different scales for varied terrain
	var x = normal.x
	var y = normal.y
	var z = normal.z

	# Use 3D noise for seamless spherical terrain (smoother with fewer layers)
	var height = noise.get_noise_3d(x * 5, y * 5, z * 5)

	# Add one subtle detail layer
	height += noise.get_noise_3d(x * 15, y * 15, z * 15) * 0.3

	return height * terrain_height

func create_mesh_from_data(vertices: PackedVector3Array, indices: PackedInt32Array) -> void:
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)

	# Calculate normals
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

	# Normalize normals
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

	# Create mesh
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# Create mesh instance
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = terrain_material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	add_child(mesh_instance)
	terrain_meshes.append(mesh_instance)

	# Add collision immediately after adding to scene tree
	mesh_instance.create_trimesh_collision()

func _process(_delta: float) -> void:
	# LOD system can be implemented here based on camera distance
	pass
