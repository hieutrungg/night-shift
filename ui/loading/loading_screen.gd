class_name LoadingScreen
extends CanvasLayer
## Covers the window while a match loads: the level builds, then waits for
## every peer before the host spawns players. Without it there is no camera
## yet and the window shows a bare grey frame that looks like a crash.

const LAYER_ON_TOP: int = 100
const BACKGROUND: Color = Color(0.02, 0.02, 0.03)
const TEXT_COLOUR: Color = Color(0.75, 0.75, 0.72)
const FONT_SIZE: int = 28


func _init() -> void:
	layer = LAYER_ON_TOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var label := Label.new()
	label.text = "UI_LOADING"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_color_override(&"font_color", TEXT_COLOUR)
	label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	background.add_child(label)
