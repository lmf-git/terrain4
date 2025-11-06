extends Node3D
class_name SphericalWater

## Spherical water system for planet
## Creates ocean shell around planet

# Shader path as constant
const WATER_SHADER_PATH := "res://shaders/water.gdshader"

@export var planet_radius: float = 500.0
@export var water_level: float = -1.0  # Height above planet surface
@export var subdivisions: int = 5  # Sphere subdivisions for water mesh

@export_group("Wave Properties")
@export var wave_speed: float = 0.5
@export var wave_scale: float = 1.0
@export var wave_height: float = 0.3

var water_mesh: MeshInstance3D
var water_material: ShaderMaterial
var time: float = 0.0

func _ready() -> void:
	setup_material()
	generate_water_sphere()

func setup_material() -> void:
	var shader := load(WATER_SHADER_PATH) as Shader
	if not shader:
		push_error("Failed to load water shader: " + WATER_SHADER_PATH)
		return

	water_material = ShaderMaterial.new()
	water_material.shader = shader

	# Set shader parameters
	water_material.set_shader_parameter("wave_speed", wave_speed)
	water_material.set_shader_parameter("wave_scale", wave_scale)
	water_material.set_shader_parameter("wave_height", wave_height)
	water_material.set_shader_parameter("water_color_deep", Color(0.0, 0.15, 0.4, 0.92))
	water_material.set_shader_parameter("water_color_shallow", Color(0.1, 0.45, 0.7, 0.75))
	water_material.set_shader_parameter("roughness", 0.15)
	water_material.set_shader_parameter("metallic", 0.0)

func generate_water_sphere() -> void:
	# Create UV sphere for water
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = planet_radius + water_level
	sphere_mesh.height = (planet_radius + water_level) * 2.0
	sphere_mesh.radial_segments = 64
	sphere_mesh.rings = 32

	water_mesh = MeshInstance3D.new()
	water_mesh.mesh = sphere_mesh
	water_mesh.material_override = water_material
	water_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Flip normals inward so we can see from inside
	water_mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED

	add_child(water_mesh)

func _process(delta: float) -> void:
	time += delta
	if water_material:
		water_material.set_shader_parameter("time", time)
