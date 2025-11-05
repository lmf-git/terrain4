extends Control

## Simple scene selector for choosing between view modes

var orbital_scene = "res://scenes/main.tscn"
var player_scene = "res://scenes/player_mode.tscn"
var orbital_lod_scene = "res://scenes/main_lod.tscn"
var player_lod_scene = "res://scenes/player_mode_lod.tscn"

func _ready() -> void:
	# Create UI
	var label = Label.new()
	label.text = """Spherical Terrain Demo

BASIC MODES:
O - Orbital Camera (Basic)
P - Player Mode (Basic)

OPTIMIZED MODES (LOD + Culling):
L - Orbital Camera (LOD Optimized)
K - Player Mode (LOD Optimized)

ESC - Quit

LOD modes feature:
• Frustum culling (only render visible terrain)
• Distance-based Level of Detail
• Chunk-based terrain system
• Better performance for large terrains"""
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Style the label
	label.add_theme_font_size_override("font_size", 24)

	add_child(label)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_O:
			get_tree().change_scene_to_file(orbital_scene)
		elif event.keycode == KEY_P:
			get_tree().change_scene_to_file(player_scene)
		elif event.keycode == KEY_L:
			get_tree().change_scene_to_file(orbital_lod_scene)
		elif event.keycode == KEY_K:
			get_tree().change_scene_to_file(player_lod_scene)
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()
