extends Node3D
class_name PlanetTerrainLOD

## Advanced chunk-based LOD terrain system for spherical planets
## Uses cubesphere with quadtree subdivision for distance-based detail

const TERRAIN_SHADER_PATH := "res://shaders/terrain_triplanar.gdshader"

# Planet properties
@export var planet_radius: float = 500.0
@export var terrain_height: float = 40.0
@export var max_lod_level: int = 6  # Maximum subdivision depth

# LOD distances (distance from camera to chunk center)
@export var lod_distances: Array[float] = [150.0, 300.0, 600.0, 1200.0, 2400.0, 4800.0]

# Tectonic system
@export var enable_tectonic_plates: bool = true
@export var num_plates: int = 12
@export var plate_seed: int = 12345
@export var mountain_height: float = 2.0
@export var ocean_depth: float = 0.015
@export var polar_flatness: float = 0.7
@export var polar_extent: float = 0.3
@export var continental_roughness: float = 0.3
@export var oceanic_smoothness: float = 0.9
@export var erosion_amount: float = 0.5

# Cities and features
@export var enable_cities: bool = true
@export var enable_caves: bool = true
@export var num_cities: int = 5
@export var num_caves: int = 10
@export var city_flatten_radius: float = 15.0
@export var city_flatten_strength: float = 0.9

# Advanced shader
@export var enable_advanced_shader: bool = true

# Internal data
var noise: FastNoiseLite
var plate_noise: FastNoiseLite
var tectonic_plates: Array = []
var city_positions: Array = []
var cave_positions: Array = []
var terrain_material: ShaderMaterial

# Chunk management
var root_chunks: Array[TerrainChunk] = []  # 6 root chunks (cube faces)
var active_chunks: Dictionary = {}  # Currently visible chunks
var camera: Camera3D

# Cubesphere face directions
const FACE_NORMALS: Array[Vector3] = [
	Vector3(0, 1, 0),   # Top
	Vector3(0, -1, 0),  # Bottom
	Vector3(1, 0, 0),   # Right
	Vector3(-1, 0, 0),  # Left
	Vector3(0, 0, 1),   # Front
	Vector3(0, 0, -1)   # Back
]

const FACE_TANGENTS: Array[Vector3] = [
	Vector3(1, 0, 0),   # Top tangent
	Vector3(1, 0, 0),   # Bottom tangent
	Vector3(0, 0, -1),  # Right tangent
	Vector3(0, 0, 1),   # Left tangent
	Vector3(1, 0, 0),   # Front tangent
	Vector3(-1, 0, 0)   # Back tangent
]

const FACE_BITANGENTS: Array[Vector3] = [
	Vector3(0, 0, 1),   # Top bitangent
	Vector3(0, 0, -1),  # Bottom bitangent
	Vector3(0, 1, 0),   # Right bitangent
	Vector3(0, 1, 0),   # Left bitangent
	Vector3(0, 1, 0),   # Front bitangent
	Vector3(0, 1, 0)    # Back bitangent
]

## Terrain chunk class - represents one node in the quadtree
class TerrainChunk:
	var parent: TerrainChunk
	var children: Array[TerrainChunk] = []
	var mesh_instance: MeshInstance3D
	var face_index: int  # Which cube face (0-5)
	var lod_level: int  # 0 = root, higher = more detail
	var bounds_center: Vector3  # World space center
	var bounds_radius: float  # Radius for culling

	# UV coordinates on the cube face (0-1 range)
	var uv_min: Vector2
	var uv_max: Vector2

	var is_leaf: bool = true  # True if no children
	var is_visible: bool = false

	func _init(p_parent: TerrainChunk, p_face_index: int, p_lod_level: int, p_uv_min: Vector2, p_uv_max: Vector2):
		parent = p_parent
		face_index = p_face_index
		lod_level = p_lod_level
		uv_min = p_uv_min
		uv_max = p_uv_max

func _ready() -> void:
	setup_noise()
	if enable_tectonic_plates:
		generate_tectonic_plates()
	if enable_cities:
		place_cities()
	if enable_caves:
		place_caves()
	setup_material()
	create_root_chunks()

func _process(_delta: float) -> void:
	# Find active camera
	if not camera:
		var viewport := get_viewport()
		if viewport:
			camera = viewport.get_camera_3d()

	if camera:
		update_lod()

func setup_noise() -> void:
	noise = FastNoiseLite.new()
	noise.seed = plate_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.005
	noise.fractal_octaves = 3

func generate_tectonic_plates() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = plate_seed

	tectonic_plates.clear()
	for i in range(num_plates):
		var plate := {}

		# Random point on sphere
		var theta := rng.randf_range(0.0, TAU)
		var phi := rng.randf_range(-PI/2, PI/2)
		var cos_phi := cos(phi)
		plate.center = Vector3(
			cos_phi * cos(theta),
			sin(phi),
			cos_phi * sin(theta)
		).normalized()

		# Plate type: continental (true) or oceanic (false)
		plate.is_continental = rng.randf() > 0.4

		# Variable continental elevation
		plate.elevation = rng.randf_range(0.18, 0.32) if plate.is_continental else -ocean_depth

		# Movement direction
		plate.movement = Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0)
		).normalized()

		tectonic_plates.append(plate)

func place_cities() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = plate_seed + 1000

	city_positions.clear()
	for i in range(num_cities):
		# Random point on sphere
		var theta := rng.randf_range(0.0, TAU)
		var phi := rng.randf_range(-PI/2, PI/2)
		var cos_phi := cos(phi)
		var pos := Vector3(
			cos_phi * cos(theta),
			sin(phi),
			cos_phi * sin(theta)
		).normalized()

		city_positions.append(pos)

func place_caves() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = plate_seed + 2000

	cave_positions.clear()
	for i in range(num_caves):
		var theta := rng.randf_range(0.0, TAU)
		var phi := rng.randf_range(-PI/2, PI/2)
		var cos_phi := cos(phi)
		var pos := Vector3(
			cos_phi * cos(theta),
			sin(phi),
			cos_phi * sin(theta)
		).normalized()

		cave_positions.append(pos)

func setup_material() -> void:
	if enable_advanced_shader:
		var shader := load(TERRAIN_SHADER_PATH) as Shader
		if shader:
			terrain_material = ShaderMaterial.new()
			terrain_material.shader = shader
			terrain_material.set_shader_parameter("water_level", -ocean_depth * terrain_height)
			terrain_material.set_shader_parameter("sand_level", 0.5)
			terrain_material.set_shader_parameter("grass_level", 3.0)
			terrain_material.set_shader_parameter("rock_level", 7.0)
			terrain_material.set_shader_parameter("snow_level", 11.0)
		else:
			push_error("Failed to load terrain shader: " + TERRAIN_SHADER_PATH)
			terrain_material = _create_fallback_material()
	else:
		terrain_material = _create_fallback_material()

func _create_fallback_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.6, 0.3)
	mat.roughness = 0.9
	mat.metallic = 0.0
	return mat

func create_root_chunks() -> void:
	# Create 6 root chunks for the cube faces
	for i in range(6):
		var chunk := TerrainChunk.new(null, i, 0, Vector2(0, 0), Vector2(1, 1))
		chunk.bounds_center = FACE_NORMALS[i] * planet_radius
		chunk.bounds_radius = planet_radius * 0.7  # Approximate
		root_chunks.append(chunk)

func update_lod() -> void:
	if not camera:
		return

	var camera_pos := camera.global_position
	var frustum := camera.get_frustum()

	# Update each root chunk
	for chunk in root_chunks:
		update_chunk_lod(chunk, camera_pos, frustum)

func update_chunk_lod(chunk: TerrainChunk, camera_pos: Vector3, frustum: Array) -> void:
	# Calculate distance from camera to chunk center
	var dist := camera_pos.distance_to(chunk.bounds_center)

	# Frustum culling
	if not is_chunk_in_frustum(chunk, frustum):
		hide_chunk(chunk)
		return

	# Determine required LOD level based on distance
	var required_lod := get_required_lod(dist)

	# Should we subdivide?
	if chunk.lod_level < required_lod and chunk.lod_level < max_lod_level:
		subdivide_chunk(chunk)
		# Recursively update children
		for child in chunk.children:
			update_chunk_lod(child, camera_pos, frustum)
	# Should we merge back up?
	elif chunk.lod_level > required_lod and not chunk.is_leaf:
		merge_chunk(chunk)
		show_chunk(chunk)
	# Just right - show this chunk
	else:
		if chunk.is_leaf:
			show_chunk(chunk)
		else:
			# Has children, recurse
			hide_chunk(chunk)
			for child in chunk.children:
				update_chunk_lod(child, camera_pos, frustum)

func get_required_lod(distance: float) -> int:
	for i in range(lod_distances.size()):
		if distance < lod_distances[i]:
			return i + 1
	return 0  # Furthest LOD

func is_chunk_in_frustum(chunk: TerrainChunk, frustum: Array) -> bool:
	# Frustum culling using sphere-plane tests
	# Frustum has 6 planes: near, far, left, right, top, bottom

	for plane in frustum:
		# Distance from plane to sphere center
		var distance := plane.distance_to(chunk.bounds_center)

		# If sphere is completely behind any plane, it's outside frustum
		if distance < -chunk.bounds_radius:
			return false

	return true

func subdivide_chunk(chunk: TerrainChunk) -> void:
	if not chunk.is_leaf:
		return  # Already subdivided

	chunk.is_leaf = false
	chunk.children.clear()

	# Create 4 child chunks (quadtree subdivision)
	var uv_mid := (chunk.uv_min + chunk.uv_max) * 0.5

	var child_uvs: Array[Array] = [
		[chunk.uv_min, uv_mid],  # Bottom-left
		[Vector2(uv_mid.x, chunk.uv_min.y), Vector2(chunk.uv_max.x, uv_mid.y)],  # Bottom-right
		[Vector2(chunk.uv_min.x, uv_mid.y), Vector2(uv_mid.x, chunk.uv_max.y)],  # Top-left
		[uv_mid, chunk.uv_max]  # Top-right
	]

	for i in range(4):
		var child := TerrainChunk.new(
			chunk,
			chunk.face_index,
			chunk.lod_level + 1,
			child_uvs[i][0],
			child_uvs[i][1]
		)

		# Calculate child bounds
		var child_center_uv := (child.uv_min + child.uv_max) * 0.5
		child.bounds_center = cube_to_sphere(chunk.face_index, child_center_uv) * planet_radius
		child.bounds_radius = chunk.bounds_radius * 0.5

		chunk.children.append(child)

func merge_chunk(chunk: TerrainChunk) -> void:
	if chunk.is_leaf:
		return  # Nothing to merge

	# Remove all children
	for child in chunk.children:
		hide_chunk(child)
		if child.mesh_instance:
			child.mesh_instance.queue_free()
			child.mesh_instance = null

	chunk.children.clear()
	chunk.is_leaf = true

func show_chunk(chunk: TerrainChunk) -> void:
	if chunk.is_visible:
		return

	# Create mesh if doesn't exist
	if not chunk.mesh_instance:
		generate_chunk_mesh(chunk)

	chunk.is_visible = true
	if chunk.mesh_instance:
		chunk.mesh_instance.visible = true

func hide_chunk(chunk: TerrainChunk) -> void:
	if not chunk.is_visible:
		return

	chunk.is_visible = false
	if chunk.mesh_instance:
		chunk.mesh_instance.visible = false

func add_chunk_features(chunk: TerrainChunk) -> void:
	# Add cities, airports, and roads to this chunk if they fall within it
	if not enable_cities and not enable_caves:
		return

	# Only add features to high-detail chunks (LOD 4+)
	if chunk.lod_level < 4:
		return

	var chunk_center_uv := (chunk.uv_min + chunk.uv_max) * 0.5
	var chunk_normal := cube_to_sphere(chunk.face_index, chunk_center_uv)

	# Check each city
	if enable_cities:
		for i in range(city_positions.size()):
			var city_normal: Vector3 = city_positions[i]

			# Is this city in this chunk?
			var city_uv := sphere_to_cube(city_normal, chunk.face_index)
			if city_uv.x >= chunk.uv_min.x and city_uv.x <= chunk.uv_max.x and \
			   city_uv.y >= chunk.uv_min.y and city_uv.y <= chunk.uv_max.y:
				# City is in this chunk - add it
				create_city_in_chunk(chunk, city_normal, i)

	# Check each cave
	if enable_caves:
		for i in range(cave_positions.size()):
			var cave_normal: Vector3 = cave_positions[i]

			var cave_uv := sphere_to_cube(cave_normal, chunk.face_index)
			if cave_uv.x >= chunk.uv_min.x and cave_uv.x <= chunk.uv_max.x and \
			   cave_uv.y >= chunk.uv_min.y and cave_uv.y <= chunk.uv_max.y:
				# Cave is in this chunk - add marker
				create_cave_marker_in_chunk(chunk, cave_normal)

func sphere_to_cube(normal: Vector3, face_index: int) -> Vector2:
	# Convert sphere normal to UV coordinates on a specific cube face
	# This is the inverse of cube_to_sphere

	var face_normal := FACE_NORMALS[face_index]
	var tangent := FACE_TANGENTS[face_index]
	var bitangent := FACE_BITANGENTS[face_index]

	# Project normal onto face plane
	var u := normal.dot(tangent)
	var v := normal.dot(bitangent)

	# Normalize by distance to face
	var dist := normal.dot(face_normal)
	if abs(dist) > 0.001:
		u /= dist
		v /= dist

	# Convert from -1..1 to 0..1
	u = (u + 1.0) * 0.5
	v = (v + 1.0) * 0.5

	return Vector2(u, v)

func create_city_in_chunk(chunk: TerrainChunk, city_normal: Vector3, city_index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = plate_seed + 1000 + city_index

	var city_height := get_terrain_height(city_normal)
	var city_pos := city_normal * (planet_radius + city_height)

	# Only place cities on land
	if city_height < 0.0:
		return

	var city_node := Node3D.new()
	city_node.name = "City_" + str(city_index)
	city_node.global_position = city_pos

	# Calculate local coordinate system
	var up := city_normal
	var right := Vector3(0, 1, 0).cross(up)
	if right.length() < 0.1:
		right = Vector3(1, 0, 0).cross(up)
	right = right.normalized()
	var forward := up.cross(right).normalized()

	# City buildings (10-25)
	var num_buildings := rng.randi_range(10, 25)
	for j in range(num_buildings):
		create_building(city_node, city_normal, city_pos, city_height, right, forward, up, rng)

	# 50% chance of airport
	if rng.randf() < 0.5:
		create_airport(city_node, city_normal, city_pos, city_height, right, forward, up, rng)

	# City roads (4x4 grid)
	create_city_roads(city_node, city_normal, city_pos, city_height, right, forward, up)

	chunk.mesh_instance.add_child(city_node)

func create_building(city_node: Node3D, city_normal: Vector3, city_pos: Vector3, city_height: float, right: Vector3, forward: Vector3, up: Vector3, rng: RandomNumberGenerator) -> void:
	var building := MeshInstance3D.new()
	var building_type := rng.randi_range(0, 2)

	var width: float
	var height: float
	var depth: float
	var color: Color

	match building_type:
		0:  # Commercial building
			width = rng.randf_range(4.0, 8.0)
			depth = rng.randf_range(4.0, 8.0)
			height = rng.randf_range(4.0, 10.0)
			color = Color(rng.randf_range(0.7, 0.9), rng.randf_range(0.7, 0.9), rng.randf_range(0.7, 0.9))
		1:  # Office building
			width = rng.randf_range(6.0, 12.0)
			depth = rng.randf_range(6.0, 12.0)
			height = rng.randf_range(12.0, 25.0)
			color = Color(rng.randf_range(0.5, 0.7), rng.randf_range(0.5, 0.7), rng.randf_range(0.6, 0.8))
		_:  # Skyscraper
			width = rng.randf_range(8.0, 15.0)
			depth = rng.randf_range(8.0, 15.0)
			height = rng.randf_range(30.0, 60.0)
			color = Color(rng.randf_range(0.3, 0.6), rng.randf_range(0.3, 0.6), rng.randf_range(0.5, 0.7))

	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, height, depth)
	building.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.3
	mat.roughness = 0.7
	building.material_override = mat

	# Random position within city
	var offset_x := rng.randf_range(-20.0, 20.0)
	var offset_z := rng.randf_range(-20.0, 20.0)

	building.global_position = city_pos + right * offset_x + forward * offset_z + up * (height * 0.5)
	building.global_transform.basis = Basis(right, up, forward)

	city_node.add_child(building)
	building.call_deferred("create_trimesh_collision")

func create_airport(city_node: Node3D, city_normal: Vector3, city_pos: Vector3, city_height: float, right: Vector3, forward: Vector3, up: Vector3, rng: RandomNumberGenerator) -> void:
	# Runway
	var runway := MeshInstance3D.new()
	var runway_mesh := BoxMesh.new()
	runway_mesh.size = Vector3(40.0, 0.5, 10.0)
	runway.mesh = runway_mesh

	var runway_mat := StandardMaterial3D.new()
	runway_mat.albedo_color = Color(0.3, 0.3, 0.35)
	runway.material_override = runway_mat

	var runway_offset := rng.randf_range(25.0, 35.0)
	runway.global_position = city_pos + forward * runway_offset + up * 0.25
	runway.global_transform.basis = Basis(right, up, forward)

	city_node.add_child(runway)
	runway.call_deferred("create_trimesh_collision")

	# Terminal
	var terminal := MeshInstance3D.new()
	var terminal_mesh := BoxMesh.new()
	terminal_mesh.size = Vector3(15.0, 5.0, 8.0)
	terminal.mesh = terminal_mesh

	var terminal_mat := StandardMaterial3D.new()
	terminal_mat.albedo_color = Color(0.8, 0.8, 0.85)
	terminal_mat.metallic = 0.2
	terminal_mat.roughness = 0.6
	terminal.material_override = terminal_mat

	terminal.global_position = city_pos + forward * (runway_offset - 25.0) + right * 12.0 + up * 2.5
	terminal.global_transform.basis = Basis(right, up, forward)

	city_node.add_child(terminal)
	terminal.call_deferred("create_trimesh_collision")

func create_city_roads(city_node: Node3D, city_normal: Vector3, city_pos: Vector3, city_height: float, right: Vector3, forward: Vector3, up: Vector3) -> void:
	# Create simple 4x4 grid of roads
	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.25, 0.25, 0.25)

	for i in range(5):
		# Horizontal roads
		var road_h := MeshInstance3D.new()
		var mesh_h := BoxMesh.new()
		mesh_h.size = Vector3(40.0, 0.2, 2.0)
		road_h.mesh = mesh_h
		road_h.material_override = road_mat

		var offset := (i - 2) * 10.0
		road_h.global_position = city_pos + forward * offset + up * 0.1
		road_h.global_transform.basis = Basis(right, up, forward)
		city_node.add_child(road_h)

		# Vertical roads
		var road_v := MeshInstance3D.new()
		var mesh_v := BoxMesh.new()
		mesh_v.size = Vector3(2.0, 0.2, 40.0)
		road_v.mesh = mesh_v
		road_v.material_override = road_mat

		road_v.global_position = city_pos + right * offset + up * 0.1
		road_v.global_transform.basis = Basis(right, up, forward)
		city_node.add_child(road_v)

func create_cave_marker_in_chunk(chunk: TerrainChunk, cave_normal: Vector3) -> void:
	var cave_height := get_terrain_height(cave_normal)
	if cave_height < 0.0:
		return  # No underwater caves

	var cave_pos := cave_normal * (planet_radius + cave_height + 2.0)

	var marker := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.5
	sphere.height = 3.0
	marker.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.4, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.2)
	mat.emission_energy_multiplier = 2.0
	marker.material_override = mat

	marker.global_position = cave_pos
	chunk.mesh_instance.add_child(marker)

func generate_chunk_mesh(chunk: TerrainChunk) -> void:
	# Determine resolution based on LOD level
	# Higher LOD = more vertices
	var resolution := 16 * (1 << (max_lod_level - chunk.lod_level))  # 16, 32, 64, etc.
	resolution = clamp(resolution, 8, 128)

	# Determine which edges need stitching (neighbor has lower detail)
	var stitch_edges := get_stitch_edges(chunk)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Generate grid of vertices
	var step := 1.0 / float(resolution)

	for y in range(resolution + 1):
		for x in range(resolution + 1):
			var u := chunk.uv_min.x + (chunk.uv_max.x - chunk.uv_min.x) * x * step
			var v := chunk.uv_min.y + (chunk.uv_max.y - chunk.uv_min.y) * y * step

			# Check if this vertex is on an edge that needs stitching
			var on_stitch_edge := false

			# Bottom edge (y == 0)
			if y == 0 and stitch_edges.bottom and x % 2 == 1:
				on_stitch_edge = true
			# Top edge (y == resolution)
			elif y == resolution and stitch_edges.top and x % 2 == 1:
				on_stitch_edge = true
			# Left edge (x == 0)
			elif x == 0 and stitch_edges.left and y % 2 == 1:
				on_stitch_edge = true
			# Right edge (x == resolution)
			elif x == resolution and stitch_edges.right and y % 2 == 1:
				on_stitch_edge = true

			# Skip vertices on stitched edges (will be handled by averaged positions)
			if on_stitch_edge:
				# Add zero vertex as placeholder (won't be used in indices)
				st.set_uv(Vector2(u, v))
				st.add_vertex(Vector3.ZERO)
			else:
				# Convert cube UV to sphere position
				var pos := cube_to_sphere(chunk.face_index, Vector2(u, v))

				# Apply height
				var height := get_terrain_height(pos)
				var final_pos := pos * (planet_radius + height)

				st.set_uv(Vector2(u, v))
				st.add_vertex(final_pos)

	# Generate indices with stitching awareness
	for y in range(resolution):
		for x in range(resolution):
			var skip_quad := false

			# Skip quads that involve stitched vertices
			if (y == 0 and stitch_edges.bottom and x % 2 == 1) or \
			   (y == resolution - 1 and stitch_edges.top and (x % 2 == 1 or y % 2 == 1)) or \
			   (x == 0 and stitch_edges.left and y % 2 == 1) or \
			   (x == resolution - 1 and stitch_edges.right and (x % 2 == 1 or y % 2 == 1)):
				skip_quad = true

			if not skip_quad:
				var i := y * (resolution + 1) + x
				var i_right := i + 1
				var i_up := i + (resolution + 1)
				var i_up_right := i_up + 1

				# Two triangles per quad
				st.add_index(i)
				st.add_index(i_up)
				st.add_index(i_right)

				st.add_index(i_right)
				st.add_index(i_up)
				st.add_index(i_up_right)

	st.generate_normals()
	st.generate_tangents()

	var mesh := st.commit()

	chunk.mesh_instance = MeshInstance3D.new()
	chunk.mesh_instance.mesh = mesh
	chunk.mesh_instance.material_override = terrain_material
	chunk.mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(chunk.mesh_instance)

	# Add collision (deferred for performance)
	chunk.mesh_instance.call_deferred("create_trimesh_collision")

	# Add cities, airports, roads, and caves to this chunk
	add_chunk_features(chunk)

func get_stitch_edges(chunk: TerrainChunk) -> Dictionary:
	# Determine which edges need stitching based on neighbors
	# Returns dict with: {left: bool, right: bool, top: bool, bottom: bool}
	var edges := {
		"left": false,
		"right": false,
		"top": false,
		"bottom": false
	}

	# For now, assume no stitching needed
	# TODO: Implement proper neighbor checking when chunk tracking is added
	# This would require maintaining a spatial data structure of active chunks

	return edges

func cube_to_sphere(face_index: int, uv: Vector2) -> Vector3:
	# Convert UV (0-1) to cube space (-1 to 1)
	var u := uv.x * 2.0 - 1.0
	var v := uv.y * 2.0 - 1.0

	# Get face basis vectors
	var normal := FACE_NORMALS[face_index]
	var tangent := FACE_TANGENTS[face_index]
	var bitangent := FACE_BITANGENTS[face_index]

	# Position on cube face
	var cube_pos := normal + tangent * u + bitangent * v

	# Project to sphere
	return cube_pos.normalized()

func get_terrain_height(normal: Vector3) -> float:
	if enable_tectonic_plates:
		return get_tectonic_height(normal)
	else:
		return get_basic_height(normal)

func get_basic_height(normal: Vector3) -> float:
	var world_pos := normal * planet_radius
	return noise.get_noise_3dv(world_pos) * terrain_height

func get_tectonic_height(normal: Vector3) -> float:
	# Find 3 nearest plates for better boundary detection
	var nearest_plate_idx := 0
	var nearest_plate_dist := 999999.0
	var second_nearest_idx := 0
	var second_nearest_dist := 999999.0
	var third_nearest_idx := 0
	var third_nearest_dist := 999999.0

	for i in range(tectonic_plates.size()):
		var plate: Dictionary = tectonic_plates[i]
		var dist := normal.distance_to(plate.center)

		if dist < nearest_plate_dist:
			third_nearest_idx = second_nearest_idx
			third_nearest_dist = second_nearest_dist
			second_nearest_idx = nearest_plate_idx
			second_nearest_dist = nearest_plate_dist
			nearest_plate_idx = i
			nearest_plate_dist = dist
		elif dist < second_nearest_dist:
			third_nearest_idx = second_nearest_idx
			third_nearest_dist = second_nearest_dist
			second_nearest_idx = i
			second_nearest_dist = dist
		elif dist < third_nearest_dist:
			third_nearest_idx = i
			third_nearest_dist = dist

	var nearest_plate: Dictionary = tectonic_plates[nearest_plate_idx]
	var second_plate: Dictionary = tectonic_plates[second_nearest_idx]

	# Base height from plate elevation
	var base_height := nearest_plate.elevation * terrain_height

	# Distance from plate center for plateau effect
	var plate_center_dist := normal.distance_to(nearest_plate.center)

	# Smoother boundaries with smoothstep
	var boundary_strength := abs(nearest_plate_dist - second_nearest_dist)
	boundary_strength = 1.0 - smoothstep(0.0, 0.15, boundary_strength)

	# Plateau formation at plate centers
	var plateau_factor := 1.0 - smoothstep(0.3, 0.8, plate_center_dist)
	if nearest_plate.is_continental:
		base_height += plateau_factor * 0.15 * terrain_height

	# Polar flattening
	var latitude := abs(asin(normal.y))
	var polar_factor := smoothstep(PI/2 * (1.0 - polar_extent), PI/2, latitude)
	base_height = lerp(base_height, 0.0, polar_factor * polar_flatness)

	# 5-layer noise system for realistic terrain
	var world_pos := normal * planet_radius

	# Layer 1: Large mountain ranges (ridged)
	var mountain_base := abs(noise.get_noise_3d(world_pos.x * 0.3, world_pos.y * 0.3, world_pos.z * 0.3))
	mountain_base = pow(mountain_base, 2.0) * 1.2

	# Layer 2: Medium mountain chains
	var mountain_chains := abs(noise.get_noise_3d(world_pos.x * 0.8, world_pos.y * 0.8, world_pos.z * 0.8))
	mountain_chains = pow(mountain_chains, 1.6) * 0.8

	# Layer 3: Rolling hills
	var hills := (noise.get_noise_3d(world_pos.x * 1.5, world_pos.y * 1.5, world_pos.z * 1.5) + 1.0) * 0.5
	hills = pow(hills, 1.2) * 0.5

	# Layer 4: Valleys (inverted ridges)
	var valleys := abs(noise.get_noise_3d(world_pos.x * 2.0, world_pos.y * 2.0, world_pos.z * 2.0))
	valleys = (1.0 - valleys) * 0.3

	# Layer 5: Fine detail
	var detail := noise.get_noise_3d(world_pos.x * 4.0, world_pos.y * 4.0, world_pos.z * 4.0) * 0.25

	var mountain_noise := (mountain_base + mountain_chains + hills - valleys + detail) * mountain_height * 2.8

	# Apply mountains based on plate type and boundary
	if nearest_plate.is_continental:
		# Continental plates get distributed mountains
		base_height += mountain_noise * (1.0 - oceanic_smoothness)

		# Gentle boundaries between continental plates
		if second_plate.is_continental:
			base_height += boundary_strength * mountain_noise * 0.05
	else:
		# Oceanic plates are very smooth
		base_height += mountain_noise * (1.0 - oceanic_smoothness) * 0.1

	# City flattening
	for city_pos in city_positions:
		var city_dist := normal.distance_to(city_pos)
		if city_dist < city_flatten_radius / planet_radius:
			var flatten_factor := 1.0 - smoothstep(0.0, city_flatten_radius / planet_radius, city_dist)
			flatten_factor = pow(flatten_factor, 2.0)
			base_height = lerp(base_height, 0.0, flatten_factor * city_flatten_strength)

	# Overall erosion/smoothing
	base_height = lerp(base_height, base_height * 0.7, erosion_amount * 0.3)

	return base_height
