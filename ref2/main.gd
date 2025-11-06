extends Node3D

var planet: Node3D
var player: CharacterBody3D

func _ready():
	# Create planet - MUCH LARGER
	planet = load("res://planet.gd").new()
	planet.radius = 500.0  # 5x bigger
	planet.terrain_height = 50.0  # Taller mountains
	planet.detail = 128  # More detail (64-256 range)
	add_child(planet)

	# Create FPS player
	player = load("res://player.gd").new()
	player.position = Vector3(0, 520, 0)  # Start above planet
	player.set_planet(planet)
	add_child(player)

	# Add collision shape to player
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 2.0
	shape.shape = capsule
	player.add_child(shape)

	# Lighting
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 45, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

	# Environment
	var env = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.4, 0.6, 0.9)  # Sky blue
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.4, 0.4, 0.5)
	environment.ambient_light_energy = 0.8
	env.environment = environment
	add_child(env)

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		# Regenerate planet
		planet.queue_free()
		planet = load("res://planet.gd").new()
		planet.radius = 500.0
		planet.terrain_height = 50.0
		planet.detail = 128
		add_child(planet)
		player.set_planet(planet)
