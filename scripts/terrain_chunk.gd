extends Node3D
class_name TerrainChunk

## Individual terrain chunk for LOD system
## Each chunk represents a section of the spherical terrain

var chunk_mesh: MeshInstance3D
var aabb: AABB
var lod_level: int = 0
var chunk_visible: bool = false
var distance_from_camera: float = 0.0

# Chunk properties
var center_position: Vector3
var vertices: PackedVector3Array
var indices: PackedInt32Array
var material: Material

# LOD meshes (different detail levels)
var lod_meshes: Array[ArrayMesh] = []

func _init(pos: Vector3) -> void:
	center_position = pos

func setup(verts: PackedVector3Array, idx: PackedInt32Array, mat: Material, lod_count: int = 3) -> void:
	vertices = verts
	indices = idx
	material = mat

	# Generate LOD levels
	generate_lod_meshes(lod_count)

	# Create mesh instance
	chunk_mesh = MeshInstance3D.new()
	chunk_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(chunk_mesh)

	# Set initial LOD
	set_lod(0)

	# Add collision (use highest detail mesh)
	if lod_meshes.size() > 0:
		chunk_mesh.create_trimesh_collision()

	# Calculate AABB
	calculate_aabb()

func generate_lod_meshes(lod_count: int) -> void:
	# Generate multiple LOD levels with progressively fewer triangles
	for lod in range(lod_count):
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)

		# For LOD > 0, simplify the mesh by skipping vertices
		var lod_factor = pow(2, lod)  # 1, 2, 4, 8...
		var simplified_indices: PackedInt32Array = []

		if lod == 0:
			# Highest detail - use all triangles
			simplified_indices = indices
		else:
			# Lower detail - skip some triangles
			for i in range(0, indices.size(), 3 * lod_factor):
				if i + 2 < indices.size():
					simplified_indices.append(indices[i])
					simplified_indices.append(indices[i + 1])
					simplified_indices.append(indices[i + 2])

		# Calculate normals
		var normals: PackedVector3Array = []
		normals.resize(vertices.size())

		for i in range(0, simplified_indices.size(), 3):
			var i0 = simplified_indices[i]
			var i1 = simplified_indices[i + 1]
			var i2 = simplified_indices[i + 2]

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
		arrays[Mesh.ARRAY_INDEX] = simplified_indices

		# Create mesh
		var mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

		lod_meshes.append(mesh)

func set_lod(level: int) -> void:
	lod_level = clamp(level, 0, lod_meshes.size() - 1)

	if chunk_mesh and lod_meshes.size() > lod_level:
		chunk_mesh.mesh = lod_meshes[lod_level]
		chunk_mesh.material_override = material

func calculate_aabb() -> void:
	if vertices.size() == 0:
		return

	var min_pos = vertices[0]
	var max_pos = vertices[0]

	for vertex in vertices:
		min_pos.x = min(min_pos.x, vertex.x)
		min_pos.y = min(min_pos.y, vertex.y)
		min_pos.z = min(min_pos.z, vertex.z)

		max_pos.x = max(max_pos.x, vertex.x)
		max_pos.y = max(max_pos.y, vertex.y)
		max_pos.z = max(max_pos.z, vertex.z)

	aabb = AABB(min_pos, max_pos - min_pos)

func update_visibility(camera: Camera3D, lod_distances: Array[float]) -> void:
	if not chunk_mesh or not camera:
		return

	# Calculate distance from camera
	distance_from_camera = global_position.distance_to(camera.global_position)

	# Frustum culling - check if chunk is in camera view
	var frustum_visible = is_in_frustum(camera)

	# Update visibility
	var should_be_visible = frustum_visible
	if should_be_visible != chunk_visible:
		chunk_mesh.visible = should_be_visible
		chunk_visible = should_be_visible

	# Update LOD level based on distance
	if chunk_visible:
		var new_lod = calculate_lod_level(lod_distances)
		if new_lod != lod_level:
			set_lod(new_lod)

func is_in_frustum(camera: Camera3D) -> bool:
	# Get camera frustum planes
	var frustum_planes = camera.get_frustum()

	# Check if chunk AABB intersects with frustum
	var global_aabb = AABB(
		global_transform * aabb.position,
		aabb.size
	)

	# Test against each frustum plane
	for plane in frustum_planes:
		# Get the positive vertex (farthest point in plane normal direction)
		var positive_vertex = global_aabb.position
		if plane.normal.x >= 0:
			positive_vertex.x += global_aabb.size.x
		if plane.normal.y >= 0:
			positive_vertex.y += global_aabb.size.y
		if plane.normal.z >= 0:
			positive_vertex.z += global_aabb.size.z

		# If positive vertex is outside plane, AABB is completely outside
		if plane.distance_to(positive_vertex) < 0:
			return false

	return true

func calculate_lod_level(lod_distances: Array[float]) -> int:
	# Determine LOD level based on distance
	for i in range(lod_distances.size()):
		if distance_from_camera < lod_distances[i]:
			return i

	return lod_distances.size()  # Lowest detail for farthest distance
