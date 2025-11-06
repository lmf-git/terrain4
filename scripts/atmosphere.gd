extends MeshInstance3D
class_name Atmosphere

## Atmospheric scattering effect for planet
## Creates atmospheric halo around planet

@export var planet_radius: float = 100.0
@export var atmosphere_radius: float = 110.0
@export var atmosphere_color: Color = Color(0.4, 0.65, 1.0, 1.0)
@export var atmosphere_density: float = 0.15

func _ready() -> void:
	create_atmosphere()

func create_atmosphere() -> void:
	# Create sphere mesh for atmosphere
	var sphere = SphereMesh.new()
	sphere.radius = atmosphere_radius
	sphere.height = atmosphere_radius * 2.0
	sphere.radial_segments = 64
	sphere.rings = 32

	mesh = sphere

	# Create atmosphere shader material
	var shader_material = ShaderMaterial.new()
	var shader = load("res://shaders/atmosphere.gdshader")
	shader_material.shader = shader

	shader_material.set_shader_parameter("planet_radius", planet_radius)
	shader_material.set_shader_parameter("atmosphere_radius", atmosphere_radius)
	shader_material.set_shader_parameter("atmosphere_color", atmosphere_color)
	shader_material.set_shader_parameter("density", atmosphere_density)

	material_override = shader_material

	# Disable shadows and set rendering priority
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sorting_offset = -10.0
