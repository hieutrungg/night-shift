extends Node
## Rendered 1280x720 benchmark, not a headless FPS estimate.
## godot --path . res://tests/exterior_benchmark.tscn -- --output-dir=C:/tmp/night-shift

const LEVEL_SCENE: PackedScene = preload("res://levels/greybox_01/greybox_01.tscn")
const RESOLUTION: Vector2i = Vector2i(1280, 720)
const WARMUP_SEC: float = 4.0
const SAMPLE_SEC: float = 6.0
const MIN_FPS: float = 120.0
const VIEWS: Array[Vector3] = [Vector3(18.5, 1.65, 33.0), Vector3(18.5, 1.65, 23.0),
	Vector3(5.0, 1.65, 26.0), Vector3(6.5, 1.65, 26.3), Vector3(17.0, 1.65, 34.6)]
const TARGETS: Array[Vector3] = [Vector3(18.5, 1.4, 21.0), Vector3(16.0, 1.6, 35.0),
	Vector3(27.0, 1.2, 29.0), Vector3(4.3, 0.8, 23.2), Vector3(14.3, 1.4, 32.5)]

var _output_dir: String = "user://exterior_benchmark"
var _failures: int = 0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("FPS benchmark requires a real renderer")
		get_tree().quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="):
			_output_dir = arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_dir))
	get_window().size = RESOLUTION
	get_window().content_scale_size = RESOLUTION
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Net.players[1] = "Benchmark"
	var level := LEVEL_SCENE.instantiate() as GreyboxLevel
	add_child(level)
	for _frame in 30:
		await get_tree().process_frame
	level.get_monster().asleep_for = INF
	var player := level.get_player()
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	var hud := level.get_node(^"Hud") as CanvasLayer
	hud.visible = false
	var camera := player.get_node(^"Head/Camera3D") as Camera3D
	var eye_offset := camera.global_position - player.global_position
	camera.current = true
	print("BENCHMARK GPU: ", RenderingServer.get_video_adapter_name())
	print("BENCHMARK viewport: ", get_viewport().get_visible_rect().size, " renderer: ", RenderingServer.get_current_rendering_method(), " HUD and flashlight: on during samples")
	for index in VIEWS.size():
		player.global_position = VIEWS[index] - eye_offset
		camera.look_at(TARGETS[index])
		if not player.is_flashlight_on():
			player.toggle_flashlight()
		hud.visible = true
		await get_tree().create_timer(WARMUP_SEC).timeout
		await _measure(index)
		# Capture the environment alone after measuring the cost with the torch on.
		hud.visible = false
		player.toggle_flashlight()
		for _frame in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var picture := get_viewport().get_texture().get_image()
		var error := picture.save_png(_output_dir.path_join("parking_%d.png" % index))
		if error != OK:
			_failures += 1
			push_error("Cannot save parking screenshot: %s" % error_string(error))
	print("EXTERIOR BENCHMARK: %s" % ("PASS" if _failures == 0 else "FAIL"))
	level.queue_free()
	for _frame in 30:
		await get_tree().process_frame
	get_tree().quit(0 if _failures == 0 else 1)


func _measure(index: int) -> void:
	var samples: Array[float] = []
	var start := Time.get_ticks_usec()
	var previous := start
	while float(Time.get_ticks_usec() - start) / 1000000.0 < SAMPLE_SEC:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now - previous) / 1000.0)
		previous = now
	var seconds := float(previous - start) / 1000000.0
	var fps := samples.size() / seconds
	samples.sort()
	var p95_ms := samples[mini(int(samples.size() * 0.95), samples.size() - 1)]
	print("PARKING VIEW %d: %.1f FPS, p95 %.2f ms, %d frames / %.2f s" % [index, fps, p95_ms, samples.size(), seconds])
	if fps <= MIN_FPS:
		_failures += 1
