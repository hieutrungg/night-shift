extends SceneTree
## Writes the Godot engine licence and third-party notices next to the build.
## Used by tests/export_build.ps1 (not part of the game).


func _init() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	var text := "Night Shift is made with the Godot Engine.\n\n"
	text += "=== Godot Engine ===\n" + Engine.get_license_text() + "\n\n"
	text += "=== Third-party components bundled in the engine ===\n"
	for part: Dictionary in Engine.get_copyright_info():
		text += "\n- %s\n" % part["name"]
		for entry: Dictionary in part["parts"]:
			text += "  files: %s\n  license: %s\n" % [str(entry["files"]), str(entry["license"])]
			for line: String in entry["copyright"]:
				text += "  (c) %s\n" % line
	text += "\n=== License texts ===\n"
	var licenses := Engine.get_license_info()
	for key: String in licenses.keys():
		text += "\n--- %s ---\n%s\n" % [key, licenses[key]]
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	print("wrote ", path, " (", text.length(), " chars)")
	quit()
