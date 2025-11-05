extends Node3D
class_name SphericalTerrainLOD

## Advanced spherical terrain with LOD, frustum culling, and chunk system
## Optimized for performance with large-scale terrain

@export_group("Planet Properties")
@export var planet_radius: float = 100.0
@export var terrain_height: float = 10.0
@export var subdivisions: int = 5

@export_group("Terrain Generation")
@export var noise_scale: float = 0.5
@export var noise_octaves: int = 6
@export var noise_persistence: float = 0.5
@export var noise_lacunarity: float = 2.0
@export var seed_value: int = 12345

@export_group("LOD Settings")
@export var enable_lod: bool = true
@export var lod_level_count: int = 4
@export var lod_distance_0: float = 150.0  # Highest detail
@export var lod_distance_1: float = 300.0  # Medium detail
@export var lod_distance_2: float = 600.0  # Low detail
# Beyond lod_distance_2 = Lowest detail

@export_group("Culling Settings")
@export var enable_frustum_culling: bool = true
@export var enable_distance_culling: bool = true
@export var max_view_distance: float = 2000.0
@export var update_frequency: float = 0.1  # Seconds between culling updates

var noise: FastNoiseLite
var terrain_material: StandardMaterial3D
var terrain_chunks: Array[TerrainChunk] = []
var camera: Camera3D
var update_timer: float = 0.0

# Chunk division - divide sphere into regions
@export var chunk_divisions: int = 6  # Number of chunks per axis

func _ready() -> void:
	setup_noise()
	setup_material()
	find_camera()
	generate_terrain_chunks()

func find_camera() -> void:
	# Find the active camera in the scene
	await get_tree().process_frame
	var viewport = get_viewport()
	if viewport:
		camera = viewport.get_camera_3d()

func setup_noise() -> void:
	noise = FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
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

func generate_terrain_chunks() -> void:
	# Generate base icosphere
	var vertices: PackedVector3Array = []
	var indices: PackedInt32Array = []

	create_icosahedron(vertices, indices)

	# Subdivide for detail
	for i in range(subdivisions):
		subdivide_mesh(vertices, indices)

	# Normalize and apply heightmap
	for i in range(vertices.size()):
		var vertex = vertices[i].normalized()
		var height = get_terrain_height(vertex)
		vertices[i] = vertex * (planet_radius + height)

	# Divide mesh into chunks
	divide_into_chunks(vertices, indices)

func divide_into_chunks(vertices: PackedVector3Array, indices: PackedInt32Array) -> void:
	# Simple chunking: divide triangles into spatial groups
	var triangles_per_chunk = max(1, indices.size() / (3 * chunk_divisions))

	for chunk_idx in range(chunk_divisions):
		var chunk_indices: PackedInt32Array = []
		var chunk_vertex_map: Dictionary = {}
		var chunk_vertices: PackedVector3Array = []

		var start_tri = chunk_idx * triangles_per_chunk * 3
		var end_tri = min((chunk_idx + 1) * triangles_per_chunk * 3, indices.size())

		# Collect triangles for this chunk
		for i in range(start_tri, end_tri, 3):
			if i + 2 >= indices.size():
				break

			for j in range(3):
				var vertex_idx = indices[i + j]
				var vertex = vertices[vertex_idx]

				# Add vertex to chunk if not already added
				if not chunk_vertex_map.has(vertex_idx):
					chunk_vertex_map[vertex_idx] = chunk_vertices.size()
					chunk_vertices.append(vertex)

				chunk_indices.append(chunk_vertex_map[vertex_idx])

		if chunk_vertices.size() > 0:
			# Calculate chunk center
			var center = Vector3.ZERO
			for v in chunk_vertices:
				center += v
			center /= chunk_vertices.size()

			# Create chunk
			var chunk = TerrainChunk.new(center)
			chunk.setup(chunk_vertices, chunk_indices, terrain_material, lod_level_count)
			add_child(chunk)
			terrain_chunks.append(chunk)

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

func get_terrain_height(normal: Vector3) -> float:
	var height = noise.get_noise_3d(normal.x * 10, normal.y * 10, normal.z * 10)
	height += noise.get_noise_3d(normal.x * 30, normal.y * 30, normal.z * 30) * 0.5
	height += noise.get_noise_3d(normal.x * 60, normal.y * 60, normal.z * 60) * 0.25
	return height * terrain_height

func _process(delta: float) -> void:
	if not enable_lod and not enable_frustum_culling:
		return

	# Update timer
	update_timer += delta
	if update_timer < update_frequency:
		return

	update_timer = 0.0

	# Find camera if not found
	if not camera:
		find_camera()
		return

	# Update all chunks
	var lod_distances: Array[float] = [lod_distance_0, lod_distance_1, lod_distance_2]

	for chunk in terrain_chunks:
		if enable_frustum_culling or enable_lod:
			chunk.update_visibility(camera, lod_distances)

		# Distance culling
		if enable_distance_culling:
			var dist = chunk.global_position.distance_to(camera.global_position)
			if chunk.chunk_mesh:
				chunk.chunk_mesh.visible = dist < max_view_distance
