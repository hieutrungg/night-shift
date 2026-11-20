extends Node

const LEVEL: PackedScene = preload("res://levels/greybox_01/greybox_01.tscn")
const PLAYER: PackedScene = preload("res://features/player/player.tscn")
const FRAMES_TO_SETTLE: int = 30
## The rider is placed in physics, the arriving truck moves in idle, so the
## rider can trail by one frame of truck travel.
const SEAT_FOLLOW_TOLERANCE: float = 0.3

var failures: int = 0
var caught_count: int = 0


func _ready() -> void:
	Net.players[1] = "Host"
	var level := LEVEL.instantiate() as GreyboxLevel
	add_child(level)
	await _frames(FRAMES_TO_SETTLE)
	var trip := level.get_trip()
	var round_manager := level.get_round()
	var player := level.get_player()
	_check(round_manager.phase == RoundManager.Phase.ARRIVING and player.seat_index >= 0, "arrival seats player")
	_check(round_manager.time_left == round_manager.duration_sec and not level.get_monster().hunting, "clock and monster wait")
	var engine := trip.van.get_node(^"EngineSound") as AudioStreamPlayer3D
	var engine_stream := engine.stream as AudioStreamWAV
	_check(engine_stream != null and engine_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "truck uses a looping engine sound")
	trip.motion_tween.custom_step(GameConfig.GATE_MOVE_SEC + 0.1)
	_check(engine.playing, "engine starts as the truck moves")
	var remote := PLAYER.instantiate() as Player
	remote.name = "2"
	level.get_node(^"Players").add_child(remote)
	remote.global_position = trip.seat_position(1)
	var both_seated: Array[int] = [1, 2, 0, 0]
	trip._sync_seats(both_seated, 0)
	var own_steps := player.get_node(^"Footsteps") as Footsteps
	var remote_steps := remote.get_node(^"Footsteps") as Footsteps
	var own_before := own_steps.steps_played
	var remote_before := remote_steps.steps_played
	for _frame in 12:
		trip.van.position.x += 0.2
		remote.global_position.x += 0.2
		await get_tree().physics_frame
	_check(own_steps.steps_played == own_before and remote_steps.steps_played == remote_before, "no footsteps for local or remote riders")
	remote.queue_free()
	var only_host: Array[int] = [1, 0, 0, 0]
	trip._sync_seats(only_host, 0)
	Input.action_press(InputActions.MOVE_FORWARD)
	await _frames(FRAMES_TO_SETTLE)
	Input.action_release(InputActions.MOVE_FORWARD)
	_check(player.seat_index >= 0 and player.global_position.distance_to(trip.seat_position(player.seat_index)) < SEAT_FOLLOW_TOLERANCE and player.velocity.is_zero_approx(), "seated player follows truck instead of walking")
	trip.motion_tween.custom_step(GameConfig.ARRIVAL_SEC)
	_check(not engine.playing, "engine stops when the truck parks")
	trip.motion_tween.kill()
	trip.van.position = trip.parked_position
	trip.van.rotation.y = 0.0
	trip.arrival_elapsed = GameConfig.ARRIVAL_SEC
	var board_event := InputEventAction.new()
	board_event.action = InputActions.BOARD
	board_event.pressed = true
	player._unhandled_input(board_event)
	trip._check_arrival_complete()
	await _frames(FRAMES_TO_SETTLE)
	_check(round_manager.is_playing() and player.seat_index < 0 and trip.van.distance_to(player.global_position) <= GameConfig.INTERACT_MAX_DISTANCE, "manual exit on arrival leaves you beside the truck")
	_check(not own_steps.boarded, "footsteps are restored after disembarking")
	player.global_position = Vector3.ZERO
	trip._try_board(1)
	_check(player.seat_index < 0, "far boarding refused")
	player.global_position = trip.van.approach_point()
	round_manager.begin_departing()
	trip._try_board(1)
	_check(player.seat_index < 0, "boarding refused during departure")
	round_manager.begin_playing()
	player.is_dead = true
	trip._try_board(1)
	_check(player.seat_index < 0, "dead player cannot board")
	player.is_dead = false
	var full: Array[int] = [2, 3, 4, 5]
	trip._sync_seats(full, 2)
	trip._try_board(1)
	_check(player.seat_index < 0, "full truck refuses boarding")
	var empty: Array[int] = [0, 0, 0, 0]
	trip._sync_seats(empty, 0)
	var item := level.get_item(0)
	var value := item.data.value
	item._set_holder(1)
	trip._try_board(1)
	_check(player.seat_index >= 0 and trip.driver_id == 1, "first boarder is driver")
	_check(round_manager.collected == value and item.is_queued_for_deletion(), "boarding deposits held loot")
	var nearby_item := level.get_item(1)
	nearby_item.global_position = player.global_position
	nearby_item.request_pick_up()
	_check(not nearby_item.is_held(), "seated player cannot pick up loot")
	level.kill_player(1)
	_check(not player.is_dead, "boarded player is safe")
	var monster := level.get_monster()
	monster.global_position = player.global_position
	_check(monster._nearest_living_player() == null, "monster does not target boarded player")
	monster.player_caught.connect(func(_peer_id: int) -> void: caught_count += 1)
	monster._catch_players()
	_check(caught_count == 0, "monster cannot catch boarded player")
	trip._set_driver_hold(2, true)
	_check(trip.hold_elapsed < 0.0, "non-driver cannot hold")
	trip._set_driver_hold(1, true)
	_check(trip.hold_elapsed < 0.0 and round_manager.is_playing(), "hold below quota refused")
	level._hud._refresh_trip(0.0)
	_check(level._hud._trip_label.text.contains(tr("HUD_QUOTA_MISSING").format({"missing": round_manager.quota - round_manager.collected})), "HUD shows quota shortfall")
	trip._update_departure(1.0)
	_check(trip.countdown < 0.0, "no countdown below quota")
	trip._try_board(1)
	_check(player.seat_index < 0 and trip.driver_id == 0, "driver can disembark")
	_check(trip.van.distance_to(player.global_position) <= GameConfig.INTERACT_MAX_DISTANCE,
		"getting off mid-round leaves you beside the truck")
	player.global_position = trip.van.approach_point()
	trip._try_board(1)
	_check(player.seat_index >= 0, "player can board again")
	round_manager.add_collected(round_manager.quota)
	trip._set_driver_hold(1, true)
	trip._update_departure(GameConfig.DRIVER_HOLD_SEC * 0.5)
	trip._set_driver_hold(1, false)
	_check(trip.hold_elapsed < 0.0 and round_manager.is_playing(), "released hold cancels")
	trip._update_departure(0.1)
	trip._try_board(1)
	trip._update_departure(0.1)
	_check(trip.countdown < 0.0, "countdown cancels when player leaves")
	player.global_position = trip.van.approach_point()
	trip._try_board(1)
	trip._update_departure(GameConfig.DEPARTURE_COUNTDOWN_SEC + 0.1)
	_check(round_manager.phase == RoundManager.Phase.DEPARTING, "quota and all aboard depart")
	trip.motion_tween.custom_step(GameConfig.GATE_MOVE_SEC + 0.1)
	_check(engine.playing, "engine starts on departure")
	trip.motion_tween.custom_step(GameConfig.DEPARTURE_SEC)
	_check(not engine.playing, "engine stops after departure")
	trip._try_board(1)
	_check(player.seat_index >= 0, "cannot leave while departing")
	trip._process(GameConfig.DEPARTURE_SEC)
	_check(round_manager.phase == RoundManager.Phase.ENDED and round_manager.success and round_manager.end_reason == RoundManager.EndReason.TEAM_LEFT, "team departure succeeds")
	level.queue_free()
	await _frames(FRAMES_TO_SETTLE)
	await _check_driver_and_timeout()
	await _check_keyboard_after_loot()
	await _check_auto_departure_after_loot()
	print("ARRIVAL DEPARTURE SMOKE: %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(0 if failures == 0 else 1)


func _check_driver_and_timeout() -> void:
	Net._loaded_peers.clear()
	var level := LEVEL.instantiate() as GreyboxLevel
	add_child(level)
	await _frames(FRAMES_TO_SETTLE)
	var trip := level.get_trip()
	trip.motion_tween.kill()
	trip.van.position = trip.parked_position
	trip.van.rotation.y = 0.0
	trip._process(GameConfig.ARRIVAL_SEC + GameConfig.AUTO_DISEMBARK_SEC)
	_check(level.get_round().is_playing() and level.get_player().seat_index < 0 and trip.van.distance_to(level.get_player().global_position) <= GameConfig.INTERACT_MAX_DISTANCE, "automatic disembark leaves you beside the truck")
	for peer_id: int in [2, 3]:
		Net.players[peer_id] = "Player%d" % peer_id
		var other := PLAYER.instantiate() as Player
		other.name = str(peer_id)
		other.position = trip.van.approach_point()
		level.get_node(^"Players").add_child(other)
	trip._try_board(2)
	trip._try_board(3)
	_check(trip.driver_id == 2, "earliest boarder is driver")
	trip._try_board(2)
	_check(trip.driver_id == 3, "driver role passes to next boarder")
	trip._set_driver_hold(2, true)
	_check(trip.hold_elapsed < 0.0, "former driver cannot trigger departure")
	level.get_player().global_position = trip.van.approach_point()
	trip._try_board(1)
	trip.remove_player(3)
	_check(trip.driver_id == 1, "disconnect transfers driver role")
	trip._try_board(3)
	trip._try_board(1)
	_check(trip.driver_id == 3, "remaining boarder becomes driver")
	level.get_round().add_collected(level.get_round().quota)
	trip._set_driver_hold(3, true)
	trip._update_departure(GameConfig.DRIVER_HOLD_SEC)
	_check(level.get_round().phase == RoundManager.Phase.DEPARTING and level.get_player().is_dead, "driver leaves players on ground")
	trip._process(GameConfig.DEPARTURE_SEC)
	_check(level.get_round().success and level.get_round().end_reason == RoundManager.EndReason.DRIVER_LEFT and level.get_round().survivors == 1, "driver departure reports survivor")
	level.queue_free()
	await _frames(FRAMES_TO_SETTLE)
	Net.players.erase(2)
	Net.players.erase(3)
	Net._loaded_peers.clear()
	level = LEVEL.instantiate() as GreyboxLevel
	add_child(level)
	await _frames(FRAMES_TO_SETTLE)
	trip = level.get_trip()
	trip.motion_tween.kill()
	trip.van.position = trip.parked_position
	trip.van.rotation.y = 0.0
	trip._process(GameConfig.ARRIVAL_SEC + GameConfig.AUTO_DISEMBARK_SEC)
	trip._on_time_expired()
	_check(level.get_player().is_dead and level.get_round().phase == RoundManager.Phase.DEPARTING, "time up leaves unboarded player")
	trip._process(GameConfig.DEPARTURE_SEC)
	_check(not level.get_round().success and level.get_round().end_reason == RoundManager.EndReason.TIME_UP, "time up below quota fails")
	level.queue_free()
	await _frames(FRAMES_TO_SETTLE)


func _frames(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame


func _check_keyboard_after_loot() -> void:
	Net._loaded_peers.clear()
	var level := LEVEL.instantiate() as GreyboxLevel
	add_child(level)
	await _frames(FRAMES_TO_SETTLE)
	var trip := level.get_trip()
	var player := level.get_player()
	trip.motion_tween.kill()
	trip.van.position = trip.parked_position
	trip.van.rotation.y = 0.0
	trip._process(GameConfig.ARRIVAL_SEC + GameConfig.AUTO_DISEMBARK_SEC)
	var item := level.get_item(0)
	level.get_round().quota = item.data.value
	player.global_position = item.global_position
	item.request_pick_up()
	_check(player.held_item == item, "host accepts picking up loot before boarding")
	player.global_position = trip.van.approach_point()
	_send_key(KEY_H, true)
	await _frames(2)
	_send_key(KEY_H, false)
	_check(player.seat_index >= 0 and trip.driver_id == 1 and level.get_round().collected >= level.get_round().quota,
		"physical H boards and deposits enough loot")
	_send_key(KEY_G, true)
	await get_tree().create_timer(GameConfig.DRIVER_HOLD_SEC + 0.5).timeout
	_send_key(KEY_G, false)
	_check(level.get_round().phase == RoundManager.Phase.DEPARTING,
		"physical G held after depositing starts departure")
	level.queue_free()
	await _frames(FRAMES_TO_SETTLE)


func _send_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)


func _check_auto_departure_after_loot() -> void:
	Net._loaded_peers.clear()
	var level := LEVEL.instantiate() as GreyboxLevel
	add_child(level)
	await _frames(FRAMES_TO_SETTLE)
	var trip := level.get_trip()
	var player := level.get_player()
	trip.motion_tween.kill()
	trip.van.position = trip.parked_position
	trip.van.rotation.y = 0.0
	trip._process(GameConfig.ARRIVAL_SEC + GameConfig.AUTO_DISEMBARK_SEC)
	var item := level.get_item(0)
	level.get_round().quota = item.data.value
	player.global_position = item.global_position
	item.request_pick_up()
	player.global_position = trip.van.approach_point()
	_send_key(KEY_H, true)
	await _frames(2)
	_send_key(KEY_H, false)
	_check(player.seat_index >= 0 and level.get_round().collected >= level.get_round().quota,
		"boarding automatically loads loot and reaches quota")
	await get_tree().create_timer(GameConfig.DEPARTURE_COUNTDOWN_SEC + 0.5).timeout
	_check(level.get_round().phase == RoundManager.Phase.DEPARTING,
		"truck leaves automatically after enough loot and everyone boards")
	level.queue_free()
	await _frames(FRAMES_TO_SETTLE)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)
