extends Node3D

## Manages switching between orbital camera and player views

@onready var orbital_camera = $OrbitalCamera
@onready var player = $Player

enum ViewMode { ORBITAL, PLAYER }
var current_view: ViewMode = ViewMode.PLAYER

func _ready() -> void:
	# Start in player view
	set_view(ViewMode.PLAYER)

func _input(event: InputEvent) -> void:
	# Toggle view with V key
	if event is InputEventKey and event.pressed and event.keycode == KEY_V:
		if current_view == ViewMode.ORBITAL:
			set_view(ViewMode.PLAYER)
		else:
			set_view(ViewMode.ORBITAL)

	# Quit with ESC (when not in player mode)
	if event.is_action_pressed("ui_cancel") and current_view == ViewMode.ORBITAL:
		get_tree().quit()

func set_view(view: ViewMode) -> void:
	current_view = view

	if view == ViewMode.ORBITAL:
		# Enable orbital camera
		orbital_camera.set_process(true)
		orbital_camera.set_process_input(true)

		# Disable player
		player.set_process(false)
		player.set_physics_process(false)
		player.set_process_input(false)

		# Release mouse
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

		print("Switched to ORBITAL view")

	elif view == ViewMode.PLAYER:
		# Disable orbital camera
		orbital_camera.set_process(false)
		orbital_camera.set_process_input(false)

		# Enable player
		player.set_process(true)
		player.set_physics_process(true)
		player.set_process_input(true)

		# Capture mouse for player
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

		print("Switched to PLAYER view")
