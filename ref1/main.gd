extends Node3D

var planet: Node3D
var player: CharacterBody3D

func _ready():
	# Create planet
	planet = load("res://planet.gd").new()
	planet.radius = 1000.0  # Very large planet
	planet.terrain_height = 60.0  # Taller terrain for more water areas
	planet.detail = 256  # Very high detail/subdivision
	planet.cliff_steepness = 0.15  # Smoother terrain
	planet.num_cities = 5  # More cities
	planet.city_flatten_radius = 80.0  # Larger flat city areas
	planet.city_min_buildings = 15
	planet.city_max_buildings = 40
	add_child(planet)

	# Create player
	player = load("res://player.gd").new()
	player.position = Vector3(0, 1070, 0)
	player.set_planet(planet)
	add_child(player)

	# Player collision shape - smaller for better scale
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 1.0
	capsule.height = 3.0
	shape.shape = capsule
	player.add_child(shape)

	# Lighting - sun pointing toward planet
	var sun = DirectionalLight3D.new()
	sun.light_energy = 1.5
	sun.light_color = Color(1.0, 0.95, 0.9)  # Warm sunlight
	sun.shadow_enabled = true
	sun.shadow_bias = 0.1
	sun.directional_shadow_max_distance = 4000.0
	add_child(sun)
	# Position and point at planet after adding to tree
	sun.position = Vector3(1000, 500, 500)
	sun.look_at(planet.global_position, Vector3.UP)

	# Environment
	var env = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.5, 0.7, 1.0)
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
		planet.radius = 1000.0
		planet.terrain_height = 60.0
		planet.detail = 256
		planet.cliff_steepness = 0.15
		planet.num_cities = 5
		planet.city_flatten_radius = 80.0
		planet.city_min_buildings = 15
		planet.city_max_buildings = 40
		add_child(planet)
		player.set_planet(planet)
