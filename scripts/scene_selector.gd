extends Control

## Simple scene selector for choosing between view modes

var orbital_scene = "res://scenes/main.tscn"
var player_scene = "res://scenes/player_mode.tscn"

func _ready() -> void:
	# Create UI
	var label = Label.new()
	label.text = """Spherical Terrain Demo - Unified Edition

O - Orbital Camera Mode
P - Player Mode

ESC - Quit

Features:
• Tectonic plates with realistic geology
• Mountains at plate collision boundaries
• Procedural cities with buildings
• Cave entrance markers
• Advanced triplanar shader with biomes
• Polar regions with flattened terrain
• Swimming mechanics with buoyancy
• First/third person camera toggle (O key in-game)
• All features in one unified terrain system!"""
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Style the label
	label.add_theme_font_size_override("font_size", 20)

	add_child(label)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_O:
			get_tree().change_scene_to_file(orbital_scene)
		elif event.keycode == KEY_P:
			get_tree().change_scene_to_file(player_scene)
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()
