class_name TripController
extends Node
## The host owns seat order and all departure decisions.


var level: GreyboxLevel
var van: Van
var round_manager: RoundManager
var seats: Array[int] = []
var driver_id: int = 0
var hold_elapsed: float = -1.0
var countdown: float = -1.0
var arrival_elapsed: float = 0.0
var departure_elapsed: float = 0.0
var departure_reason: RoundManager.EndReason = RoundManager.EndReason.TIME_UP
var left_names: Array[String] = []
var parked_position: Vector3
var _boarding_order: Array[int] = []
var motion_tween: Tween


func setup(owner_level: GreyboxLevel, truck: Van, round_node: RoundManager) -> void:
	level = owner_level
	van = truck
	round_manager = round_node
	parked_position = van.position
	seats.resize(GameConfig.MAX_PLAYERS)
	seats.fill(0)
	round_manager.time_expired.connect(_on_time_expired)


func begin_arrival() -> void:
	if not multiplayer.is_server():
		return
	var players := level.get_players()
	for index in mini(players.size(), GameConfig.MAX_PLAYERS):
		seats[index] = players[index].get_peer_id()
	_sync_seats.rpc(seats, 0)
	_start_motion.rpc(true)


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		if round_manager.phase == RoundManager.Phase.ARRIVING:
			arrival_elapsed += delta
		if hold_elapsed >= 0.0:
			hold_elapsed = minf(hold_elapsed + delta, GameConfig.DRIVER_HOLD_SEC)
		if countdown >= 0.0:
			countdown = maxf(countdown - delta, 0.0)
		return
	if round_manager.phase == RoundManager.Phase.ARRIVING:
		arrival_elapsed += delta
		if arrival_elapsed >= GameConfig.ARRIVAL_SEC + GameConfig.AUTO_DISEMBARK_SEC:
			for peer_id: int in seats.duplicate():
				if peer_id != 0:
					_disembark(peer_id)
		_check_arrival_complete()
	elif round_manager.phase == RoundManager.Phase.PLAYING:
		_update_departure(delta)
	elif round_manager.phase == RoundManager.Phase.DEPARTING:
		departure_elapsed += delta
		if departure_elapsed >= GameConfig.DEPARTURE_SEC:
			var survivor_count := 0
			for peer_id in seats:
				if peer_id != 0:
					survivor_count += 1
			round_manager.finish(departure_reason, survivor_count, left_names)


func seat_position(index: int) -> Vector3:
	return van.seat_markers[index].global_position


func request_board_toggle() -> void:
	_request_board.rpc_id(1)


func request_driver_hold(pressed: bool) -> void:
	_request_hold.rpc_id(1, pressed)


@rpc("any_peer", "call_local", "reliable")
func _request_board() -> void:
	if not multiplayer.is_server():
		return
	_try_board(multiplayer.get_remote_sender_id())


func _try_board(sender: int) -> void:
	if not multiplayer.is_server():
		return
	var player := Player.find_by_peer(get_tree(), sender)
	if player == null or player.is_dead:
		return
	if seats.has(sender):
		if round_manager.phase == RoundManager.Phase.PLAYING or (round_manager.phase == RoundManager.Phase.ARRIVING and arrival_elapsed >= GameConfig.ARRIVAL_SEC):
			_disembark(sender)
		return
	if round_manager.phase != RoundManager.Phase.PLAYING or not seats.has(0):
		return
	if van.distance_to(player.global_position) > GameConfig.INTERACT_MAX_DISTANCE:
		return
	if player.held_item != null:
		level.deposit_for_boarding(player)
	seats[seats.find(0)] = sender
	if driver_id == 0:
		driver_id = sender
	_sync_seats.rpc(seats, driver_id)


func _disembark(peer_id: int) -> void:
	var index := seats.find(peer_id)
	if index < 0:
		return
	seats[index] = 0
	if driver_id == peer_id:
		driver_id = 0
		hold_elapsed = -1.0
		_sync_progress.rpc(hold_elapsed, countdown)
		# Order is maintained independently of seat reuse below.
		for boarded in _boarding_order:
			if seats.has(boarded):
				driver_id = boarded
				break
	_boarding_order.erase(peer_id)
	_sync_seats.rpc(seats, driver_id)
	_place_on_ground.rpc(peer_id, index)


@rpc("authority", "call_local", "reliable")
func _sync_seats(new_seats: Array[int], new_driver: int) -> void:
	if multiplayer.is_server():
		for peer_id in new_seats:
			if peer_id != 0 and not _boarding_order.has(peer_id) and round_manager.phase == RoundManager.Phase.PLAYING:
				_boarding_order.append(peer_id)
	seats.assign(new_seats)
	driver_id = new_driver
	for player in level.get_players():
		player.seat_index = seats.find(player.get_peer_id())


@rpc("authority", "call_local", "reliable")
func _place_on_ground(peer_id: int, index: int) -> void:
	var player := Player.find_by_peer(get_tree(), peer_id)
	if player != null and player.is_local():
		var spawns := level.get_player_spawns()
		player.global_position = spawns[index % spawns.size()]


@rpc("any_peer", "call_local", "reliable")
func _request_hold(pressed: bool) -> void:
	if not multiplayer.is_server():
		return
	_set_driver_hold(multiplayer.get_remote_sender_id(), pressed)


func _set_driver_hold(sender: int, pressed: bool) -> void:
	if not multiplayer.is_server():
		return
	if sender != driver_id or not seats.has(sender):
		return
	if not pressed:
		hold_elapsed = -1.0
		_sync_progress.rpc(hold_elapsed, countdown)
	elif round_manager.phase == RoundManager.Phase.PLAYING and round_manager.collected >= round_manager.quota:
		hold_elapsed = 0.0
		_sync_progress.rpc(hold_elapsed, countdown)


@rpc("authority", "call_local", "reliable")
func _sync_progress(hold: float, automatic: float) -> void:
	hold_elapsed = hold
	countdown = automatic


func _check_arrival_complete() -> void:
	if arrival_elapsed >= GameConfig.ARRIVAL_SEC and seats.all(func(id: int) -> bool: return id == 0):
		round_manager.begin_playing.rpc()


func _update_departure(delta: float) -> void:
	if hold_elapsed >= 0.0:
		hold_elapsed += delta
		if hold_elapsed >= GameConfig.DRIVER_HOLD_SEC:
			_depart(RoundManager.EndReason.DRIVER_LEFT)
			return
	var everyone := true
	for player in level.get_players():
		if not player.is_dead and not seats.has(player.get_peer_id()):
			everyone = false
			break
	var eligible := everyone and seats.any(func(id: int) -> bool: return id != 0) and round_manager.collected >= round_manager.quota
	if eligible:
		if countdown < 0.0:
			countdown = GameConfig.DEPARTURE_COUNTDOWN_SEC
			_sync_progress.rpc(hold_elapsed, countdown)
		countdown -= delta
		if countdown <= 0.0:
			_depart(RoundManager.EndReason.TEAM_LEFT)
			return
	else:
		if countdown >= 0.0:
			countdown = -1.0
			_sync_progress.rpc(hold_elapsed, countdown)


func _on_time_expired() -> void:
	_depart(RoundManager.EndReason.TIME_UP)


func _depart(reason: RoundManager.EndReason) -> void:
	if not multiplayer.is_server() or round_manager.phase != RoundManager.Phase.PLAYING:
		return
	round_manager.begin_departing.rpc()
	left_names.clear()
	for player in level.get_players():
		if not player.is_dead and not seats.has(player.get_peer_id()):
			left_names.append(Net.players.get(player.get_peer_id(), ""))
			level.kill_player(player.get_peer_id())
	if reason == RoundManager.EndReason.DRIVER_LEFT and left_names.is_empty():
		reason = RoundManager.EndReason.TEAM_LEFT
	departure_reason = reason
	_start_motion.rpc(false)


@rpc("authority", "call_local", "reliable")
func _start_motion(arriving: bool) -> void:
	var outside := Vector3(float(level.get_layout_width()) * 0.5, parked_position.y, float(level.get_layout_depth()) + GameConfig.TRUCK_OUTSIDE_DISTANCE)
	var inside := Vector3(outside.x, parked_position.y, float(level.get_layout_depth()) - GameConfig.TRUCK_WAYPOINT_INSET)
	var gate := level.get_node(^"Navigation/Geometry/Gate") as Node3D
	for shape in gate.find_children("*", "CollisionShape3D", true, false):
		(shape as CollisionShape3D).set_deferred(&"disabled", true)
	var gate_tween := create_tween()
	gate_tween.tween_property(gate, "position:x", ExteriorBuilder.GATE_WIDTH, GameConfig.GATE_MOVE_SEC)
	if arriving:
		van.position = outside
		van.rotation.y = PI * 0.5
	var tween := create_tween()
	motion_tween = tween
	var duration := GameConfig.ARRIVAL_SEC if arriving else GameConfig.DEPARTURE_SEC
	tween.tween_interval(GameConfig.GATE_MOVE_SEC)
	tween.tween_callback(van.start_engine)
	tween.tween_property(van, "position", inside, (duration - GameConfig.GATE_MOVE_SEC) * 0.5)
	if not arriving:
		tween.parallel().tween_property(van, "rotation:y", PI * 0.5, (duration - GameConfig.GATE_MOVE_SEC) * 0.5)
	tween.tween_property(van, "position", parked_position if arriving else outside, (duration - GameConfig.GATE_MOVE_SEC) * 0.5)
	if arriving:
		tween.parallel().tween_property(van, "rotation:y", 0.0, (duration - GameConfig.GATE_MOVE_SEC) * 0.5)
	tween.tween_callback(van.stop_engine)
	if arriving:
		tween.tween_callback(_close_gate.bind(gate))


func _close_gate(gate: Node3D) -> void:
	var tween := create_tween()
	tween.tween_property(gate, "position:x", 0.0, GameConfig.GATE_MOVE_SEC)
	tween.tween_callback(_enable_gate_collision.bind(gate))


func _enable_gate_collision(gate: Node3D) -> void:
	for shape in gate.find_children("*", "CollisionShape3D", true, false):
		(shape as CollisionShape3D).set_deferred(&"disabled", false)


func remove_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if seats.has(peer_id):
		_disembark(peer_id)
