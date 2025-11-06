extends CharacterBody3D

## Player with point gravity

@export var walk_speed: float = 50.0
@export var sprint_speed: float = 100.0
@export var jump_force: float = 250.0
@export var swim_speed: float = 30.0
@export var mouse_sensitivity: float = 0.002

var planet: Node3D
var camera: Camera3D
var camera_pivot: Node3D
var gravity_strength: float = 2.0

var pitch: float = 0.0
var yaw: float = 0.0

var ground_normal: Vector3 = Vector3.UP
var raycast: RayCast3D
var is_swimming: bool = false
var water_level: float = -8.0  # Same as planet water threshold

func _ready():
	# Camera pivot
	camera_pivot = Node3D.new()
	add_child(camera_pivot)

	camera = Camera3D.new()
	camera.position = Vector3(0, 2.5, 0)  # Higher for taller capsule
	camera.near = 0.01
	camera.far = 10000.0
	camera_pivot.add_child(camera)

	# Ground raycast
	raycast = RayCast3D.new()
	raycast.target_position = Vector3(0, -2.0, 0)
	raycast.enabled = true
	add_child(raycast)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, -PI/2, PI/2)

		# Allow yaw when airborne or swimming
		if not is_on_floor() or is_swimming:
			yaw -= event.relative.x * mouse_sensitivity

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float):
	if not planet:
		return

	# Point gravity toward raycast collision point (feet position)
	var feet_position = global_position
	var gravity_dir: Vector3
	var planet_up: Vector3

	# Update raycast to point down from player
	raycast.target_position = -transform.basis.y * 3.0

	# Get gravity direction from feet
	if raycast.is_colliding():
		var collision_point = raycast.get_collision_point()
		gravity_dir = (collision_point - feet_position).normalized()
		planet_up = -gravity_dir
		ground_normal = raycast.get_collision_normal()

		# Check if underwater (distance from planet center)
		var distance_from_center = collision_point.distance_to(planet.global_position)
		var terrain_height_at_point = distance_from_center - planet.radius
		is_swimming = terrain_height_at_point < water_level
	else:
		# Fallback to planet center
		var to_planet = planet.global_position - feet_position
		gravity_dir = to_planet.normalized()
		planet_up = -gravity_dir
		ground_normal = planet_up
		is_swimming = false

	# Apply gravity (reduced when swimming)
	if is_swimming:
		velocity += gravity_dir * gravity_strength * 0.2 * delta  # Buoyancy
	else:
		velocity += gravity_dir * gravity_strength * delta

	# Jump or swim up
	if Input.is_action_just_pressed("ui_accept"):
		if is_swimming:
			velocity += planet_up * swim_speed  # Swim up
		elif is_on_floor():
			velocity += planet_up * jump_force  # Jump

	if is_swimming:
		# Swimming mode - free 3D movement
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

		# Camera can rotate freely when swimming
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
		# Align to surface
		align_to_surface(ground_normal, delta)

		# Movement
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

		# Camera rotation - use player's local basis
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
		# Air control - very powerful for orbital movement
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

		camera_pivot.transform = Transform3D.IDENTITY
		camera_pivot.rotate_object_local(Vector3.UP, yaw)
		camera_pivot.rotate_object_local(Vector3.RIGHT, pitch)

		if input_dir.length() > 0:
			var cam_basis = camera_pivot.global_transform.basis
			var move_dir = (cam_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			# Very strong air control for orbiting planet
			velocity += move_dir * sprint_speed * 2.5 * delta

	move_and_slide()

func align_to_surface(up_dir: Vector3, delta: float):
	var current_up = transform.basis.y
	var new_up = current_up.slerp(up_dir, delta * 8.0)

	var forward = transform.basis.z
	var right = forward.cross(new_up)

	if right.length_squared() < 0.01:
		right = transform.basis.x

	right = right.normalized()
	forward = new_up.cross(right).normalized()

	transform.basis.x = right
	transform.basis.y = new_up
	transform.basis.z = forward

func set_planet(p: Node3D):
	planet = p
