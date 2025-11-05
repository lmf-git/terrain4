extends CharacterBody3D
class_name PlayerCharacter

## First-person player character for spherical terrain
## Uses gravity aligned to planet center

@export var planet_center: Vector3 = Vector3.ZERO
@export var planet_radius: float = 100.0
@export var spawn_height: float = 130.0  # Spawn well above terrain (max terrain ~120)

@export_group("Movement")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 10.0
@export var jump_velocity: float = 6.0
@export var gravity_strength: float = 15.0

@export_group("Mouse Look")
@export var mouse_sensitivity: float = 0.003
@export var vertical_look_limit: float = 89.0

var camera: Camera3D
var head: Node3D
var camera_rotation_x: float = 0.0
var gravity_direction: Vector3 = Vector3.DOWN

func _ready() -> void:
	# Create head node for camera rotation
	head = Node3D.new()
	add_child(head)
	head.position = Vector3(0, 1.6, 0)  # Eye height

	# Create camera
	camera = Camera3D.new()
	camera.fov = 90.0
	camera.near = 0.1
	camera.far = 10000.0
	camera.current = true
	head.add_child(camera)

	# Spawn above terrain
	position_on_planet_surface()

	# Capture mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Rotate body left/right
		rotate_object_local(Vector3.UP, -event.relative.x * mouse_sensitivity)

		# Rotate head up/down
		camera_rotation_x -= event.relative.y * mouse_sensitivity
		camera_rotation_x = clamp(camera_rotation_x,
			-deg_to_rad(vertical_look_limit),
			deg_to_rad(vertical_look_limit))
		head.rotation.x = camera_rotation_x

	# Toggle mouse capture
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			get_tree().quit()

func _physics_process(delta: float) -> void:
	# Calculate gravity direction (toward planet center)
	gravity_direction = (planet_center - global_position).normalized()

	# Align character to planet surface
	align_to_planet()

	# Apply gravity
	if not is_on_floor():
		velocity += gravity_direction * gravity_strength * delta

	# Handle jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity -= gravity_direction * jump_velocity

	# Get input direction relative to character orientation
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# Calculate movement direction
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Apply movement speed
	var current_speed = sprint_speed if Input.is_action_pressed("ui_shift") else walk_speed

	if direction != Vector3.ZERO:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()

func align_to_planet() -> void:
	# Get the up direction (away from planet center)
	var planet_up = -gravity_direction

	# Smoothly align the character to the planet surface
	var current_up = global_transform.basis.y
	var target_basis = global_transform.basis

	# Create rotation to align Y axis with up direction
	var rotation_axis = current_up.cross(planet_up)
	if rotation_axis.length() > 0.001:
		var rotation_angle = current_up.angle_to(planet_up)
		target_basis = target_basis.rotated(rotation_axis.normalized(), rotation_angle * 0.1)
		global_transform.basis = target_basis

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
