extends Node

const LEVEL: PackedScene = preload("res://levels/greybox_01/greybox_01.tscn")


func _ready() -> void:
	Net.players[1] = "Driver"
	var level := LEVEL.instantiate() as GreyboxLevel
	add_child(level)
	await get_tree().create_timer(1.0).timeout
	var mode := "arrival"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--trip-mode="):
			mode = arg.trim_prefix("--trip-mode=")
	if mode == "arrival":
		return
	var trip := level.get_trip()
	trip.motion_tween.kill()
	trip.van.position = trip.parked_position
	trip.van.rotation.y = 0.0
	trip.arrival_elapsed = GameConfig.ARRIVAL_SEC
	trip._try_board(1)
	trip._check_arrival_complete()
	level.get_player().global_position = trip.van.approach_point()
	trip._try_board(1)
	level.get_round().add_collected(level.get_round().quota)
	if mode == "driver":
		trip._set_driver_hold(1, true)
	elif mode == "departure":
		trip._depart(RoundManager.EndReason.TEAM_LEFT)
