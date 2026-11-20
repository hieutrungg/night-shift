extends Node
## Dev tool: a real (windowed) host and client, each saving screenshots of
## what its own camera shows. Run two copies:
##   godot --path . res://tests/two_player_capture.tscn -- --role=host --out=C:/tmp/h
##   godot --path . res://tests/two_player_capture.tscn -- --role=client --out=C:/tmp/c

const ADDRESS: String = "127.0.0.1"
const PORT: int = 17778
## Seconds after the level loads: riding in, just after getting off, later.
const SHOT_TIMES: Array[float] = [6.0, 16.0, 24.0]
const GIVE_UP_SEC: float = 40.0

var _role: String = ""
var _out: String = ""


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			_role = arg.trim_prefix("--role=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	# Net changes scene, so this node must outlive it: a stand-in becomes the
	# scene that gets replaced.
	await get_tree().process_frame
	var stand_in := Node.new()
	get_tree().root.add_child(stand_in)
	get_tree().current_scene = stand_in
	if _role == "host":
		Net.host("Host", PORT)
		var started := false
		var waited := 0.0
		while not started and waited < GIVE_UP_SEC:
			await get_tree().create_timer(0.5).timeout
			waited += 0.5
			started = Net.start_game()
	else:
		await get_tree().create_timer(1.0).timeout
		Net.join(ADDRESS, "Client", PORT)
	var waited_level := 0.0
	while not (get_tree().current_scene is GreyboxLevel) and waited_level < GIVE_UP_SEC:
		await get_tree().create_timer(0.25).timeout
		waited_level += 0.25
	var elapsed := 0.0
	for shot_time: float in SHOT_TIMES:
		await get_tree().create_timer(shot_time - elapsed).timeout
		elapsed = shot_time
		_shoot("%s_%02d.png" % [_out, int(shot_time)])
	get_tree().quit()


func _shoot(path: String) -> void:
	var camera := get_viewport().get_camera_3d()
	var level := get_tree().current_scene as GreyboxLevel
	var info := "camera=%s" % (camera.get_path() if camera != null else ^"<none>")
	if level != null:
		info += " players=%d phase=%d" % [level.get_players().size(), level.get_round().phase]
		var me := level.get_player()
		if me != null:
			info += " me=%s pos=%s seat=%d" % [me.name, me.global_position, me.seat_index]
	print("SHOT %s %s" % [path, info])
	get_viewport().get_texture().get_image().save_png(path)
