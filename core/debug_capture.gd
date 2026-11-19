extends Node
## Autoload "DebugCapture": dev-only screenshot tool. Does nothing unless
## launched with user arguments, e.g.
##   godot --path . -- --capture=C:/tmp/shot.png --frames=120 --locale=vi
## --locale here only overrides this run; it is not saved to settings.

const DEFAULT_FRAMES: int = 120

var _capture_path: String = ""
var _frames_left: int = 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			_capture_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--frames="):
			_frames_left = arg.trim_prefix("--frames=").to_int()
		elif arg.begins_with("--locale="):
			TranslationServer.set_locale(arg.trim_prefix("--locale="))
	if _capture_path.is_empty():
		set_process(false)
	elif _frames_left <= 0:
		_frames_left = DEFAULT_FRAMES


func _process(_delta: float) -> void:
	_frames_left -= 1
	if _frames_left > 0:
		return
	var image: Image = get_viewport().get_texture().get_image()
	var error := image.save_png(_capture_path)
	print("capture: %s (%s)" % [_capture_path, error_string(error)])
	get_tree().quit()
