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
	# Create inner atmosphere layer (for viewing from inside/on surface)
	var inner_sphere = SphereMesh.new()
	inner_sphere.radius = atmosphere_radius
	inner_sphere.height = atmosphere_radius * 2.0
	inner_sphere.radial_segments = 64
	inner_sphere.rings = 32

	mesh = inner_sphere

	# Inner atmosphere shader (cull_front - visible from inside)
	var inner_shader = load("res://shaders/atmosphere.gdshader")
	var inner_material = ShaderMaterial.new()
	inner_material.shader = inner_shader
	inner_material.set_shader_parameter("planet_radius", planet_radius)
	inner_material.set_shader_parameter("atmosphere_radius", atmosphere_radius)
	inner_material.set_shader_parameter("atmosphere_color", atmosphere_color)
	inner_material.set_shader_parameter("density", atmosphere_density)

	material_override = inner_material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sorting_offset = -10.0

	# Create outer atmosphere layer (for viewing from above/orbital)
	var outer_atmo = MeshInstance3D.new()
	var outer_sphere = SphereMesh.new()
	outer_sphere.radius = atmosphere_radius * 1.02  # Slightly larger
	outer_sphere.height = atmosphere_radius * 2.04
	outer_sphere.radial_segments = 64
	outer_sphere.rings = 32
	outer_atmo.mesh = outer_sphere

	# Outer atmosphere shader (cull_back - visible from outside)
	var outer_shader = load("res://shaders/atmosphere_outer.gdshader")
	var outer_material = ShaderMaterial.new()
	outer_material.shader = outer_shader
	outer_material.set_shader_parameter("planet_radius", planet_radius)
	outer_material.set_shader_parameter("atmosphere_radius", atmosphere_radius)
	outer_material.set_shader_parameter("atmosphere_color", atmosphere_color)
	outer_material.set_shader_parameter("density", atmosphere_density * 0.8)

	outer_atmo.material_override = outer_material
	outer_atmo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outer_atmo.sorting_offset = -11.0

	add_child(outer_atmo)
