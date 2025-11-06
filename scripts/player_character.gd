extends CharacterBody3D
class_name PlayerCharacter

## First-person player character for spherical terrain
## Uses gravity aligned to planet center

@export var planet_center: Vector3 = Vector3.ZERO
@export var planet_radius: float = 500.0
@export var spawn_height: float = 650.0  # Spawn well above terrain

@export_group("Movement")
@export var walk_speed: float = 100.0
@export var sprint_speed: float = 200.0
@export var jump_velocity: float = 80.0
@export var swim_speed: float = 60.0
@export var gravity_strength: float = 20.0
@export var air_control: float = 2.5

@export_group("Mouse Look")
@export var mouse_sensitivity: float = 0.002
@export var vertical_look_limit: float = 89.0

@export_group("Water")
@export var water_level: float = -1.0  # Height relative to base terrain

var camera: Camera3D
var camera_pivot: Node3D
var player_mesh: MeshInstance3D
var raycast: RayCast3D

var pitch: float = 0.0  # Camera up/down
var yaw: float = 0.0    # Player/camera left/right when airborne/swimming

var is_first_person: bool = true
var third_person_distance: float = 10.0
var is_swimming: bool = false

var ground_normal: Vector3 = Vector3.UP
var gravity_direction: Vector3 = Vector3.DOWN

func _ready() -> void:
	# Create player mesh (visible capsule in third person)
	player_mesh = MeshInstance3D.new()
	var capsule_mesh = CapsuleMesh.new()
	capsule_mesh.radius = 0.5
	capsule_mesh.height = 2.0
	player_mesh.mesh = capsule_mesh

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.0, 1.0)  # Bright magenta
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.0, 1.0)
	mat.emission_energy_multiplier = 0.5
	player_mesh.set_surface_override_material(0, mat)
	player_mesh.visible = false  # Hidden in first person
	add_child(player_mesh)

	# Camera pivot for independent rotation
	camera_pivot = Node3D.new()
	add_child(camera_pivot)

	# Create camera
	camera = Camera3D.new()
	camera.position = Vector3(0, 2.5, 0)  # Eye height
	camera.fov = 90.0
	camera.near = 0.01
	camera.far = 10000.0
	camera.current = true
	camera_pivot.add_child(camera)

	# Ground detection raycast
	raycast = RayCast3D.new()
	raycast.target_position = Vector3(0, -3.0, 0)
	raycast.enabled = true
	add_child(raycast)

	# Spawn above terrain
	position_on_planet_surface()

	# Capture mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Pitch (up/down)
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, -PI/2, PI/2)

		# Yaw (left/right) - always allow turning
		yaw -= event.relative.x * mouse_sensitivity

	# Toggle mouse capture
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				get_tree().quit()
		elif event.keycode == KEY_O:
			# Toggle first/third person camera
			is_first_person = !is_first_person
			if is_first_person:
				camera.position = Vector3(0, 2.5, 0)
				player_mesh.visible = false
			else:
				camera.position = Vector3(0, 2.0, -third_person_distance)
				player_mesh.visible = true

func _physics_process(delta: float) -> void:
	# Calculate gravity direction (toward planet center)
	var feet_position = global_position
	gravity_direction = (planet_center - feet_position).normalized()
	var planet_up = -gravity_direction

	# Update raycast direction to point down from player
	raycast.target_position = -transform.basis.y * 3.0

	# Check ground normal from raycast
	if raycast.is_colliding():
		ground_normal = raycast.get_collision_normal()
		var collision_point = raycast.get_collision_point()

		# Check if underwater
		var distance_from_center = collision_point.distance_to(planet_center)
		var terrain_height = distance_from_center - planet_radius
		is_swimming = terrain_height < water_level
	else:
		ground_normal = planet_up
		is_swimming = false

	# Apply gravity (reduced when swimming for buoyancy)
	if is_swimming:
		velocity += gravity_direction * gravity_strength * 0.2 * delta
	else:
		velocity += gravity_direction * gravity_strength * delta

	# Jump or swim up
	if Input.is_action_just_pressed("ui_accept"):
		if is_swimming:
			velocity += planet_up * swim_speed  # Swim up
		elif is_on_floor():
			velocity += planet_up * jump_velocity  # Jump

	# Get input direction
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	if is_swimming:
		# Swimming mode - free 3D movement
		camera_pivot.transform = Transform3D.IDENTITY
		camera_pivot.rotate_object_local(Vector3.UP, yaw)
		camera_pivot.rotate_object_local(Vector3.RIGHT, pitch)

		if input_dir.length() > 0:
			var cam_basis = camera_pivot.global_transform.basis
			var move_dir = (cam_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			velocity += move_dir * swim_speed * delta * 5.0

		# Water drag
		velocity = velocity.lerp(Vector3.ZERO, delta * 2.0)

	elif is_on_floor():
		# Grounded - align to surface
		align_to_surface(ground_normal, delta)

		# Camera rotation
		camera_pivot.transform = Transform3D.IDENTITY
		camera_pivot.rotate_object_local(Vector3.UP, yaw)
		camera_pivot.rotate_object_local(Vector3.RIGHT, pitch)

		var cam_forward = -camera_pivot.global_transform.basis.z
		var cam_right = camera_pivot.global_transform.basis.x

		var move_dir = (cam_right * input_dir.x + cam_forward * input_dir.y).normalized()

		# Project onto surface
		if move_dir.length_squared() > 0.01:
			move_dir = move_dir - ground_normal * move_dir.dot(ground_normal)
			move_dir = move_dir.normalized()

		var speed = sprint_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed

		if input_dir.length() > 0:
			var target_velocity = move_dir * speed
			velocity = velocity.lerp(target_velocity, delta * 10.0)
		else:
			velocity = velocity.lerp(Vector3.ZERO, delta * 5.0)

	else:
		# Air control - powerful for orbital movement
		camera_pivot.transform = Transform3D.IDENTITY
		camera_pivot.rotate_object_local(Vector3.UP, yaw)
		camera_pivot.rotate_object_local(Vector3.RIGHT, pitch)

		if input_dir.length() > 0:
			var cam_basis = camera_pivot.global_transform.basis
			var move_dir = (cam_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			velocity += move_dir * sprint_speed * air_control * delta

	move_and_slide()

func align_to_surface(up_dir: Vector3, delta: float) -> void:
	# Quickly align Y-axis to surface normal for responsive feel
	var current_up = transform.basis.y
	var new_up = current_up.slerp(up_dir, delta * 15.0)  # Faster alignment

	# Preserve forward direction as much as possible
	var forward = transform.basis.z
	var right = forward.cross(new_up)

	# If forward is too aligned with up, use right as reference
	if right.length_squared() < 0.01:
		right = transform.basis.x

	right = right.normalized()
	forward = new_up.cross(right).normalized()

	# Reconstruct basis - ensure orthogonal
	transform.basis.x = right
	transform.basis.y = new_up
	transform.basis.z = forward

	# Orthonormalize to prevent drift
	transform.basis = transform.basis.orthonormalized()

func position_on_planet_surface() -> void:
	# Position character at spawn height above planet center
	# Add slight offset to avoid colinear vectors in look_at
	var spawn_position = Vector3(0.1, spawn_height, 0.1)
	global_position = planet_center + spawn_position

	# Orient toward planet surface (stand upright on sphere)
	var to_center = (planet_center - global_position).normalized()
	var right = Vector3.RIGHT.cross(to_center).normalized()
	if right.length() < 0.001:  # If colinear, use different axis
		right = Vector3.FORWARD.cross(to_center).normalized()
	var up_vec = to_center.cross(right).normalized()

	# Set basis to align character upright on sphere
	global_transform.basis = Basis(right, -to_center, up_vec)
