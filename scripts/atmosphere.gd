extends MeshInstance3D
class_name Atmosphere

## Atmospheric scattering effect for planet
## Creates atmospheric halo around planet with dual-layer rendering

# Shader paths as constants
const ATMOSPHERE_INNER_SHADER_PATH := "res://shaders/atmosphere.gdshader"
const ATMOSPHERE_OUTER_SHADER_PATH := "res://shaders/atmosphere_outer.gdshader"

@export var planet_radius: float = 500.0
@export var atmosphere_radius: float = 550.0
@export var atmosphere_color: Color = Color(0.35, 0.6, 1.0, 1.0)
@export var atmosphere_density: float = 0.2

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
	var inner_shader := load(ATMOSPHERE_INNER_SHADER_PATH) as Shader
	if inner_shader:
		var inner_material := ShaderMaterial.new()
		inner_material.shader = inner_shader
		inner_material.set_shader_parameter("planet_radius", planet_radius)
		inner_material.set_shader_parameter("atmosphere_radius", atmosphere_radius)
		inner_material.set_shader_parameter("atmosphere_color", atmosphere_color)
		inner_material.set_shader_parameter("density", atmosphere_density)
		material_override = inner_material
	else:
		push_error("Failed to load inner atmosphere shader: " + ATMOSPHERE_INNER_SHADER_PATH)

	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sorting_offset = -10.0

	# Create outer atmosphere layer (for viewing from above/orbital)
	var outer_atmo := MeshInstance3D.new()
	var outer_sphere := SphereMesh.new()
	outer_sphere.radius = atmosphere_radius * 1.02  # Slightly larger
	outer_sphere.height = atmosphere_radius * 2.04
	outer_sphere.radial_segments = 64
	outer_sphere.rings = 32
	outer_atmo.mesh = outer_sphere

	# Outer atmosphere shader (cull_back - visible from outside)
	var outer_shader := load(ATMOSPHERE_OUTER_SHADER_PATH) as Shader
	if outer_shader:
		var outer_material := ShaderMaterial.new()
		outer_material.shader = outer_shader
		outer_material.set_shader_parameter("planet_radius", planet_radius)
		outer_material.set_shader_parameter("atmosphere_radius", atmosphere_radius)
		outer_material.set_shader_parameter("atmosphere_color", atmosphere_color)
		outer_material.set_shader_parameter("density", atmosphere_density * 0.8)
		outer_atmo.material_override = outer_material
	else:
		push_error("Failed to load outer atmosphere shader: " + ATMOSPHERE_OUTER_SHADER_PATH)

	outer_atmo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outer_atmo.sorting_offset = -11.0

	add_child(outer_atmo)
