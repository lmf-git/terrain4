extends CharacterBody3D

## FPS player that walks on spherical planets

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 10.0
@export var jump_force: float = 10.0
@export var mouse_sensitivity: float = 0.002
@export var air_control: float = 0.3  # Movement control while airborne

var planet: Node3D
var camera: Camera3D
var camera_pivot: Node3D  # For independent camera rotation
var player_mesh: MeshInstance3D  # Visual representation
var gravity_strength: float = 20.0
var is_first_person: bool = true
var third_person_distance: float = 10.0

# Rotation
var pitch: float = 0.0  # Camera up/down
var yaw: float = 0.0    # Player/camera left/right when grounded, camera only when airborne

# Ground detection
var ground_normal: Vector3 = Vector3.UP
var raycast: RayCast3D

func _ready():
	# Create player mesh (capsule)
	player_mesh = MeshInstance3D.new()
	var capsule_mesh = CapsuleMesh.new()
	capsule_mesh.radius = 0.5
	capsule_mesh.height = 2.0
	player_mesh.mesh = capsule_mesh

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.0, 1.0)  # Bright magenta for visibility
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.0, 1.0)
	mat.emission_energy_multiplier = 0.5
	player_mesh.set_surface_override_material(0, mat)
	player_mesh.visible = false  # Hidden in first person by default
	add_child(player_mesh)

	# Camera pivot for independent rotation when airborne
	camera_pivot = Node3D.new()
	add_child(camera_pivot)

	camera = Camera3D.new()
	camera.position = Vector3(0, 1.6, 0)  # Eye height (first person)
	camera.near = 0.05  # Prevent clipping through floor
	camera_pivot.add_child(camera)

	# Ground detection raycast
	raycast = RayCast3D.new()
	raycast.target_position = Vector3(0, -2.0, 0)  # Cast down 2 units
	raycast.enabled = true
	add_child(raycast)

	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Update pitch (camera up/down)
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, -PI/2, PI/2)

		# Update yaw (left/right)
		yaw -= event.relative.x * mouse_sensitivity

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_O:
			# Toggle camera mode
			is_first_person = !is_first_person
			if is_first_person:
				camera.position = Vector3(0, 1.6, 0)
				player_mesh.visible = false
			else:
				camera.position = Vector3(0, 2.0, -third_person_distance)
				player_mesh.visible = true

func _physics_process(delta: float):
	if not planet:
		return

	# Get gravity direction (towards planet center)
	var to_planet = planet.global_position - global_position
	var gravity_dir = to_planet.normalized()
	var planet_up = -gravity_dir

	# Update raycast direction to point toward planet
	raycast.target_position = gravity_dir * 2.0

	# Check ground normal from raycast
	if raycast.is_colliding():
		ground_normal = raycast.get_collision_normal()
	else:
		ground_normal = planet_up

	# Apply gravity
	velocity += gravity_dir * gravity_strength * delta

	# Jump (needs to be before move_and_slide)
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity += planet_up * jump_force

	if is_on_floor():
		# GROUNDED: Align to detected ground normal
		align_capsule_to_surface(ground_normal, delta)

		# Movement projected along ground surface
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

		# Get movement direction based on camera yaw
		camera_pivot.rotation = Vector3.ZERO
		camera_pivot.rotate_y(yaw)
		camera_pivot.rotate_x(pitch)

		var cam_forward = -camera_pivot.global_transform.basis.z
		var cam_right = camera_pivot.global_transform.basis.x

		# Build movement in camera direction
		var move_dir = (cam_right * input_dir.x + cam_forward * input_dir.y).normalized()

		# Project movement onto ground plane (remove component along normal)
		if move_dir.length_squared() > 0.01:
			move_dir = move_dir - ground_normal * move_dir.dot(ground_normal)
			move_dir = move_dir.normalized()

		var speed = sprint_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed

		if input_dir.length() > 0:
			# Apply movement along surface
			var target_velocity = move_dir * speed
			velocity = velocity.lerp(target_velocity, delta * 10.0)
		else:
			velocity = velocity.lerp(Vector3.ZERO, delta * 5.0)

	else:
		# AIRBORNE: Free quaternion aim, no capsule realignment
		# Movement with reduced control
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

		# Camera pivot rotates independently (quaternion aim)
		camera_pivot.rotation = Vector3.ZERO
		camera_pivot.rotate_y(yaw)
		camera_pivot.rotate_x(pitch)

		# Move in direction camera is facing, but with air control
		if input_dir.length() > 0:
			var cam_basis = camera_pivot.global_transform.basis
			var move_dir = (cam_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			velocity += move_dir * walk_speed * air_control * delta

	move_and_slide()

func align_capsule_to_surface(up_dir: Vector3, delta: float):
	# Smoothly align Y-axis to surface normal
	var current_up = transform.basis.y
	var new_up = current_up.slerp(up_dir, delta * 8.0)

	# Preserve forward direction as much as possible
	var forward = transform.basis.z
	var right = forward.cross(new_up)

	# If forward is too aligned with up, use right as reference
	if right.length_squared() < 0.01:
		right = transform.basis.x

	right = right.normalized()
	forward = new_up.cross(right).normalized()

	# Reconstruct basis
	transform.basis.x = right
	transform.basis.y = new_up
	transform.basis.z = forward

func set_planet(p: Node3D):
	planet = p
