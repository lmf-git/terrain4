extends Node3D
class_name OrbitalCamera

## Orbital camera controller for spherical terrain
## Similar to Kerbal Space Program camera system

@export var target: Node3D  # The planet to orbit around
@export var distance: float = 350.0
@export var min_distance: float = 50.0
@export var max_distance: float = 2000.0

@export_group("Movement Settings")
@export var rotation_speed: float = 0.3
@export var zoom_speed: float = 20.0
@export var pan_speed: float = 0.5
@export var smooth_speed: float = 10.0

@export_group("Mouse Settings")
@export var mouse_sensitivity: float = 0.003
@export var zoom_sensitivity: float = 0.1

var camera: Camera3D
var rotation_x: float = 0.0  # Pitch
var rotation_y: float = 0.0  # Yaw
var target_distance: float
var target_rotation_x: float
var target_rotation_y: float

var is_rotating: bool = false
var is_panning: bool = false
var last_mouse_position: Vector2

func _ready() -> void:
	# Create camera
	camera = Camera3D.new()
	camera.fov = 75.0
	camera.near = 0.1
	camera.far = 10000.0
	camera.current = true  # Make this the active camera
	add_child(camera)

	# Set initial rotation (45 degree angle looking down at planet)
	rotation_x = -0.5  # Look down slightly
	rotation_y = 0.0  # Face forward

	# Initialize rotation
	target_distance = distance
	target_rotation_x = rotation_x
	target_rotation_y = rotation_y

	update_camera_position()

	# Capture mouse on click
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event: InputEvent) -> void:
	# Handle mouse rotation
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_rotating = event.pressed
			if event.pressed:
				last_mouse_position = event.position
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = event.pressed
			if event.pressed:
				last_mouse_position = event.position

		# Zoom with mouse wheel
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_distance = max(min_distance, target_distance - zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_distance = min(max_distance, target_distance + zoom_speed)

	if event is InputEventMouseMotion:
		if is_rotating:
			var delta = event.position - last_mouse_position
			target_rotation_y -= delta.x * mouse_sensitivity
			target_rotation_x -= delta.y * mouse_sensitivity
			target_rotation_x = clamp(target_rotation_x, -PI/2 + 0.01, PI/2 - 0.01)
			last_mouse_position = event.position

		if is_panning:
			var delta = event.position - last_mouse_position
			# Pan the target position
			var right = camera.global_transform.basis.x
			var up = camera.global_transform.basis.y
			if target:
				target.global_position -= right * delta.x * pan_speed * 0.1
				target.global_position += up * delta.y * pan_speed * 0.1
			last_mouse_position = event.position

func _process(delta: float) -> void:
	# Handle keyboard input
	if Input.is_action_pressed("ui_up"):
		target_rotation_x += rotation_speed * delta
	if Input.is_action_pressed("ui_down"):
		target_rotation_x -= rotation_speed * delta
	if Input.is_action_pressed("ui_left"):
		target_rotation_y += rotation_speed * delta
	if Input.is_action_pressed("ui_right"):
		target_rotation_y -= rotation_speed * delta

	# Clamp pitch
	target_rotation_x = clamp(target_rotation_x, -PI/2 + 0.01, PI/2 - 0.01)

	# Smooth interpolation
	rotation_x = lerp(rotation_x, target_rotation_x, smooth_speed * delta)
	rotation_y = lerp(rotation_y, target_rotation_y, smooth_speed * delta)
	distance = lerp(distance, target_distance, smooth_speed * delta)

	update_camera_position()

	# ESC to quit
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()

func update_camera_position() -> void:
	if not target:
		return

	# Calculate camera position based on orbital rotation
	var offset = Vector3.ZERO
	offset.z = distance

	# Apply rotations
	var rotation_transform = Transform3D()
	rotation_transform = rotation_transform.rotated(Vector3.RIGHT, rotation_x)
	rotation_transform = rotation_transform.rotated(Vector3.UP, rotation_y)

	offset = rotation_transform * offset

	# Position camera
	global_position = target.global_position + offset
	camera.look_at(target.global_position, Vector3.UP)
