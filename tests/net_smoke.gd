extends Node
## Multi-process network test. Each role runs as its own headless Godot:
##   godot --headless --path . res://tests/net_smoke.tscn -- --role=host
##   godot --headless --path . res://tests/net_smoke.tscn -- --role=client --name=C1
##   godot --headless --path . res://tests/net_smoke.tscn -- --role=extra
## The host waits for MAX_PLAYERS, gives the extra client time to be refused,
## starts the match and checks that every client's movement reaches it.
## tests/run_net_smoke.ps1 launches all of them.
##
## The runner moves itself to the tree root because starting the match
## changes the current scene, which would free this node.

const PORT: int = 17777
const ADDRESS: String = "127.0.0.1"
const CLIENT_SHIFT: float = 3.0
const EXTRA_ATTEMPT_WAIT_SEC: float = 8.0
## Gives the host time to check movement before clients start teleporting.
const CONTEST_START_DELAY_SEC: float = 3.0
## Lets a teleported position reach the host before a request is sent.
const POSITION_SETTLE_SEC: float = 1.0
## C1 and C2 both grab this item; C3 asks for FAR_ITEM from outside.
const CONTEST_ITEM: int = 0
const FAR_ITEM: int = 14
const CONTENDERS: PackedStringArray = ["C1", "C2"]
## The host kills this client to check death sync and spectating.
const VICTIM: String = "C3"
## The winner keeps the item this long so every client sees who holds it.
const WINNER_HOLD_SEC: float = 4.0
## Frames to let audio and nodes shut down before quitting (avoids exit leaks).
const SHUTDOWN_FRAMES: int = 30
## The host sets this mannequin pose; clients must see it.
const SYNC_POSE: int = 2
## Closer than this (m) means a decoy and a mannequin share a spot.
const DECOY_CLEARANCE: float = 0.3
const OUTDATED_VERSION: String = "0.0.0-outdated"
## Items spawned by greybox_01 at the start of a round (15 loot + 2 bulky).
const ITEM_COUNT: int = 17
## Lets clients check the result before the host starts the next round.
const ROUND_RESULT_WAIT_SEC: float = 2.0

var _failures: int = 0
var _role: String = ""
var _player_name: String = ""


func _ready() -> void:
	if get_parent() != get_tree().root or get_tree().current_scene == self:
		_relaunch_at_root()
		return
	_parse_args()
	match _role:
		"host":
			await _run_host()
		"client":
			await _run_client()
		"extra":
			await _run_extra()
		"outdated":
			await _run_outdated()
		_:
			_check(false, "unknown role '%s'" % _role)
	_finish()


func _relaunch_at_root() -> void:
	var runner := Node.new()
	runner.name = "NetSmokeRunner"
	runner.set_script(get_script())
	get_tree().root.add_child.call_deferred(runner)


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			_role = arg.trim_prefix("--role=")
		elif arg.begins_with("--name="):
			_player_name = arg.trim_prefix("--name=")


func _run_host() -> void:
	_check(Net.host("Host", PORT) == OK, "host started on port %d" % PORT)
	_check(not Net.can_start_game(), "cannot start with 1 player")
	_check(not Net.start_game(), "start_game refused with 1 player")
	var full := await _wait_until(func() -> bool: return Net.players.size() == GameConfig.MAX_PLAYERS, 40.0)
	_check(full, "lobby reached %d players (has %d)" % [GameConfig.MAX_PLAYERS, Net.players.size()])
	_check(Net.can_start_game(), "can start with a full lobby")
	await _seconds(EXTRA_ATTEMPT_WAIT_SEC)
	_check(Net.players.size() == GameConfig.MAX_PLAYERS, "extra player was not admitted")

	_check(Net.start_game(), "match started")
	var spawned := await _wait_until(func() -> bool: return _level_players().size() == GameConfig.MAX_PLAYERS, 30.0)
	_check(spawned, "host sees %d players (has %d)" % [GameConfig.MAX_PLAYERS, _level_players().size()])
	var arrival := await _wait_until(_arrival_synced, 10.0)
	_check(arrival, "host sees all players seated during arrival")
	var engine_started := await _wait_until(_truck_engine_playing, 5.0)
	_check(engine_started, "host hears engine during arrival")
	var ready := await _wait_until(func() -> bool: return (get_tree().current_scene as GreyboxLevel).get_round().is_playing(), 25.0)
	_check(ready, "host sees arrival complete")
	var host_level := get_tree().current_scene as GreyboxLevel
	_check_mannequins_on_host(host_level)
	var monster := host_level.get_monster()
	_check(monster != null, "mannequin spawned on the host")
	# This test is about sync, not the chase: keep every mannequin asleep.
	for sleeper in host_level.get_monsters():
		sleeper.asleep_for = INF
	if monster != null:
		monster.pose_index = SYNC_POSE
	var moved := await _wait_until(_all_clients_moved, 15.0)
	_check(moved, "every client's movement reached the host")
	await _run_host_music_check(monster)
	await _run_host_contest()
	# Let clients finish their own checks before the host leaves.
	await _seconds(3.0)


func _run_host_music_check(monster: Mannequin) -> void:
	if monster == null:
		return
	# Reproduce movement while keeping the AI asleep, isolating audio replication.
	for _frame in 60:
		monster.position.x += 0.04
		await get_tree().physics_frame
	var music := monster.get_node(^"Music") as AudioStreamPlayer3D
	_check(music.playing, "host plays music while mannequin moves")
	await _seconds(0.6)
	_check(music.playing, "host keeps music playing briefly after mannequin stops")
	await _seconds(monster.music_stop_delay_sec)
	_check(not music.playing, "host stops music after the movement tail")
	monster.pose_index = SYNC_POSE
	var client := Player.find_by_peer(get_tree(), _peer_id_of("C1"))
	_check(client != null and not client.is_flashlight_on(), "client flashlight off state reached the host")


func _run_host_contest() -> void:
	var level := get_tree().current_scene as GreyboxLevel
	var item := level.get_item(CONTEST_ITEM)
	var door := level.get_doors()[0]
	var taken := await _wait_until(func() -> bool: return item.is_held() and door.is_open, 20.0)
	_check(taken, "contested item taken and door opened by clients")
	_check(_is_contender(item.holder_id), "item went to one contender (holder %d)" % item.holder_id)
	var holders := 0
	for player in level.get_players():
		if player.held_item == item:
			holders += 1
	_check(holders == 1, "exactly one player holds the item (got %d)" % holders)
	_check(not level.get_item(FAR_ITEM).is_held(), "far pick-up was refused")
	await _run_host_round(level, item)


## The winner loads the item into the van; the host ends the round and starts
## the next one, and every peer must follow.
func _run_host_round(level: GreyboxLevel, item: Item) -> void:
	var value := item.data.value
	var item_count := level.get_items().size()
	var round_manager := level.get_round()
	var deposited := await _wait_until(
		func() -> bool: return level.get_item(CONTEST_ITEM) == null and round_manager.collected == value, 20.0)
	_check(deposited, "winner loaded the item into the van (+%d)" % value)
	_check(level.get_items().size() == item_count - 1, "deposited item removed on the host")
	round_manager.add_collected(round_manager.quota - round_manager.collected)
	var trip := level.get_trip()
	var boarded := await _wait_until(func() -> bool: return trip.seats.has(_peer_id_of("C1")) and trip.seats.has(_peer_id_of("C2")), 20.0)
	_check(boarded and trip.driver_id == _peer_id_of("C1"), "host sees same boarded players and driver")
	if not boarded:
		for peer_id: int in [_peer_id_of("C1"), _peer_id_of("C2")]:
			var candidate := Player.find_by_peer(get_tree(), peer_id)
			if candidate != null:
				print("  DEBUG boarding ", peer_id, " position=", candidate.global_position, " van=", trip.van.global_position, " distance=", trip.van.distance_to(candidate.global_position), " seats=", trip.seats, " driver=", trip.driver_id)
	var engine_started := await _wait_until(_truck_engine_playing, 10.0)
	_check(engine_started, "host hears engine during departure")
	var ended := await _wait_until(func() -> bool: return round_manager.phase == RoundManager.Phase.ENDED, 20.0)
	var victim := Player.find_by_peer(get_tree(), _peer_id_of(VICTIM))
	_check(ended and round_manager.success and round_manager.end_reason == RoundManager.EndReason.DRIVER_LEFT and round_manager.survivors == 2 and round_manager.left_names.has("C3") and round_manager.left_names.has("Host") and victim != null and victim.is_dead, "driver leaves client behind with matching result")
	await _seconds(ROUND_RESULT_WAIT_SEC)
	var old_level_id := level.get_instance_id()
	level.restart_round()
	var restarted := await _wait_until(func() -> bool: return _is_new_round(old_level_id), 30.0)
	_check(restarted, "new round running with %d players" % GameConfig.MAX_PLAYERS)


func _run_client() -> void:
	_check(Net.join(ADDRESS, _player_name, PORT) == OK, "join started")
	var in_lobby := await _wait_signal_or_timeout(Net.connected_to_lobby, 20.0)
	_check(in_lobby, "joined the lobby")
	_check(not Net.can_start_game(), "client cannot start the match")
	var spawned := await _wait_until(func() -> bool: return _level_players().size() == GameConfig.MAX_PLAYERS, 60.0)
	_check(spawned, "client sees %d players (has %d)" % [GameConfig.MAX_PLAYERS, _level_players().size()])
	var level := get_tree().current_scene as GreyboxLevel
	var me := level.get_player() if level != null else null
	_check(me != null and me.is_multiplayer_authority(), "client controls its own player")
	if me == null:
		return
	var arrival := await _wait_until(_arrival_synced, 10.0)
	_check(arrival, "client sees all players seated during arrival")
	await _check_mannequins_on_client(get_tree().current_scene as GreyboxLevel)
	var engine_started := await _wait_until(_truck_engine_playing, 5.0)
	_check(engine_started, "client hears engine during arrival")
	var ready := await _wait_until(func() -> bool: return level.get_round().is_playing(), 25.0)
	_check(ready, "client sees arrival complete")
	for other in _level_players():
		if other != me and other.is_multiplayer_authority():
			_check(false, "client must not control player %s" % other.name)
	var monster_spawned := await _wait_until(func() -> bool: return level.get_monster() != null, 10.0)
	_check(monster_spawned, "client mannequin loaded before movement audio check")
	if not monster_spawned:
		return
	if _player_name == "C1" and me.is_flashlight_on():
		me.toggle_flashlight()
	me.global_position.x += CLIENT_SHIFT
	var monster := level.get_monster()
	var music := monster.get_node(^"Music") as AudioStreamPlayer3D
	var heard := await _wait_until(func() -> bool: return music.playing, 10.0)
	_check(heard, "client plays music from synced mannequin movement")
	var silent := await _wait_until(func() -> bool: return not music.playing, 5.0)
	_check(silent, "client stops music when synced mannequin stops")
	await _seconds(CONTEST_START_DELAY_SEC)
	await _run_client_contest(me)
	var host_left := await _wait_until(func() -> bool: return not Net.is_online(), 60.0)
	_check(host_left, "host ended the session")


func _run_client_contest(me: Player) -> void:
	var level := get_tree().current_scene as GreyboxLevel
	var item := level.get_item(CONTEST_ITEM)
	var door := level.get_doors()[0]
	if _player_name in CONTENDERS:
		# Two spots next to the item so the contenders don't overlap.
		var offset := Vector3(1.5, 0.0, 1.0) if _player_name == CONTENDERS[0] else Vector3(1.0, 0.0, 2.0)
		_teleport(me, Vector3(item.global_position.x, 0.1, item.global_position.z) + offset)
		await _seconds(POSITION_SETTLE_SEC)
		item.request_pick_up()
	else:
		var far_item := level.get_item(FAR_ITEM)
		far_item.request_pick_up()
		_teleport(me, door.global_position + Vector3(1.5, 0.1, 0.5))
		await _seconds(POSITION_SETTLE_SEC)
		door.request_set_open(true)
		await _seconds(POSITION_SETTLE_SEC)
		_check(not far_item.is_held(), "host refused a far pick-up")

	var settled := await _wait_until(func() -> bool: return item.is_held() and door.is_open, 15.0)
	_check(settled, "sees the contested item taken and the door open")
	var winner := item.holder_id
	_check(_is_contender(winner), "item went to one contender (holder %d)" % winner)
	var i_won := winner == me.get_peer_id()
	_check((me.held_item == item) == i_won, "local held item matches the host's decision")
	await _run_client_round(level, me, item, i_won)


func _run_client_round(level: GreyboxLevel, me: Player, item: Item, i_won: bool) -> void:
	var value := item.data.value
	var round_manager := level.get_round()
	if i_won:
		await _seconds(WINNER_HOLD_SEC)
		var van := level.get_van()
		_teleport(me, van.approach_point())
		await _seconds(POSITION_SETTLE_SEC)
		van.request_deposit()
	# The host tops up the quota right after the deposit, so only a minimum holds.
	var deposited := await _wait_until(
		func() -> bool: return level.get_item(CONTEST_ITEM) == null and round_manager.collected >= value, 15.0)
	_check(deposited and me.held_item == null, "deposit seen on this peer (+%d)" % value)
	await _run_client_departure(level, me)
	await _check_victim(level)
	var engine_started := await _wait_until(_truck_engine_playing, 10.0)
	_check(engine_started, "client hears engine during departure")
	var ended := await _wait_until(func() -> bool: return round_manager.phase == RoundManager.Phase.ENDED, 20.0)
	_check(ended and round_manager.success and round_manager.end_reason == RoundManager.EndReason.DRIVER_LEFT and round_manager.survivors == 2 and round_manager.left_names.has("C3") and round_manager.left_names.has("Host"), "same driver departure result as the host")
	var old_level_id := level.get_instance_id()
	var restarted := await _wait_until(func() -> bool: return _is_new_round(old_level_id), 30.0)
	_check(restarted, "new round loaded after play again")


func _run_client_departure(level: GreyboxLevel, me: Player) -> void:
	var trip := level.get_trip()
	var quota_ready := await _wait_until(func() -> bool: return level.get_round().collected >= level.get_round().quota, 15.0)
	_check(quota_ready, "quota reached on client")
	if _player_name == "C2":
		await _wait_until(func() -> bool: return trip.driver_id == _peer_id_of("C1"), 10.0)
	if _player_name in CONTENDERS:
		var deadline := Time.get_ticks_msec() + 10000
		while not trip.seats.has(me.get_peer_id()) and Time.get_ticks_msec() < deadline:
			var offset := Vector3.RIGHT if _player_name == "C2" else Vector3.ZERO
			_teleport(me, trip.van.approach_point() + offset)
			await _seconds(POSITION_SETTLE_SEC)
			if not trip.seats.has(me.get_peer_id()):
				trip.request_board_toggle()
			await _seconds(POSITION_SETTLE_SEC)
	var boarded := await _wait_until(func() -> bool: return trip.seats.has(_peer_id_of("C1")) and trip.seats.has(_peer_id_of("C2")), 15.0)
	_check(boarded and trip.driver_id == _peer_id_of("C1") and level.get_round().is_playing(), "client sees same phase, seats and driver")
	if _player_name == "C1":
		await _seconds(POSITION_SETTLE_SEC)
		trip.request_driver_hold(true)


func _check_victim(level: GreyboxLevel) -> void:
	_check(level.get_monster() != null, "mannequin spawned on this peer")
	var monster := level.get_monster()
	var posed := await _wait_until(func() -> bool: return monster != null and monster.pose_index == SYNC_POSE, 10.0)
	_check(posed, "mannequin pose synced from the host")
	var victim := Player.find_by_peer(get_tree(), _peer_id_of(VICTIM))
	if victim == null:
		_check(false, "victim player exists")
		return
	var dead := await _wait_until(func() -> bool: return victim.is_dead, 10.0)
	_check(dead and not victim.visible, "%s's death seen on this peer" % VICTIM)
	if _player_name != VICTIM:
		return
	var spectator := level.get_node_or_null(^"Spectator") as Spectator
	var target := spectator.get_target() if spectator != null else null
	_check(target != null and not target.is_dead, "dead player spectates a living player")


func _peer_id_of(player_name: String) -> int:
	for peer_id: int in Net.players.keys():
		if Net.players[peer_id] == player_name:
			return peer_id
	return 0


## Four players face GameConfig.mannequin_count(4) mannequins that wake one
## after another (spawn order = wake order).
func _check_mannequins_on_host(level: GreyboxLevel) -> void:
	var monsters := level.get_monsters()
	var expected := GameConfig.mannequin_count(Net.players.size())
	_check(monsters.size() == expected, "host spawned %d mannequins for %d players (got %d)" % [expected, Net.players.size(), monsters.size()])
	var staggered := true
	for index in range(1, monsters.size()):
		staggered = staggered and monsters[index].asleep_for > monsters[index - 1].asleep_for
	_check(staggered, "mannequins wake one after another")


## Spawn data travels with the spawner, so a client must have the same number
## of mannequins and must have applied the secret showroom swap: no decoy may
## stand where a real mannequin is.
func _check_mannequins_on_client(level: GreyboxLevel) -> void:
	var expected := GameConfig.mannequin_count(Net.players.size())
	var spawned := await _wait_until(func() -> bool: return level.get_monsters().size() == expected, 10.0)
	_check(spawned, "client sees %d mannequins (got %d)" % [expected, level.get_monsters().size()])
	var clashes := 0
	for node in get_tree().get_nodes_in_group(PropFactory.DECOY_GROUP):
		var decoy := node as Node3D
		for monster in level.get_monsters():
			var gap := Vector2(decoy.global_position.x - monster.global_position.x,
				decoy.global_position.z - monster.global_position.z)
			if gap.length() < DECOY_CLEARANCE:
				clashes += 1
	_check(clashes == 0, "showroom swap matches the host (no decoy on a real mannequin)")


## A client with another build is refused with a clear reason.
func _run_outdated() -> void:
	Net.game_version = OUTDATED_VERSION
	_check(Net.join(ADDRESS, "Old", PORT) == OK, "outdated join started")
	var refused := await _wait_until(func() -> bool: return not Net.last_end_reason_key.is_empty(), 20.0)
	var reason := Net.last_end_reason_key
	_check(refused and reason == "ERR_VERSION_MISMATCH", "outdated build refused with ERR_VERSION_MISMATCH (got '%s')" % reason)


func _run_extra() -> void:
	_check(Net.join(ADDRESS, "Extra", PORT) == OK, "extra join started")
	# join_failed carries an argument, so poll the stored reason instead.
	var refused := await _wait_until(func() -> bool: return not Net.last_end_reason_key.is_empty(), 20.0)
	var reason := Net.last_end_reason_key
	_check(refused and reason == "ERR_ROOM_FULL", "extra player refused with ERR_ROOM_FULL (got '%s')" % reason)


func _all_clients_moved() -> bool:
	var level := get_tree().current_scene as GreyboxLevel
	if level == null:
		return false
	var spawns := level.get_player_spawns()
	var peer_ids: Array[int] = []
	peer_ids.assign(Net.players.keys())
	peer_ids.sort()
	for index in peer_ids.size():
		if peer_ids[index] == 1:
			continue
		var player := level.get_node_or_null(NodePath("Players/%d" % peer_ids[index])) as Player
		if player == null or absf(player.global_position.x - spawns[index].x) < CLIENT_SHIFT * 0.8:
			return false
	return true


func _is_new_round(old_level_id: int) -> bool:
	var level := get_tree().current_scene as GreyboxLevel
	if level == null or level.get_instance_id() == old_level_id or not level.is_node_ready():
		return false
	var round_manager := level.get_round()
	return (round_manager.phase == RoundManager.Phase.ARRIVING and round_manager.collected == 0
		and level.get_players().size() == GameConfig.MAX_PLAYERS
		and level.get_items().size() == ITEM_COUNT)


func _arrival_synced() -> bool:
	var level := get_tree().current_scene as GreyboxLevel
	if level == null or level.get_round().phase != RoundManager.Phase.ARRIVING:
		return false
	for peer_id: int in Net.players.keys():
		if not level.get_trip().seats.has(peer_id):
			return false
		var player := Player.find_by_peer(get_tree(), peer_id)
		if player == null or not (player.get_node(^"Footsteps") as Footsteps).boarded:
			return false
	return level.get_trip().driver_id == 0


func _truck_engine_playing() -> bool:
	var level := get_tree().current_scene as GreyboxLevel
	if level == null or not is_instance_valid(level.get_van()):
		return false
	return (level.get_van().get_node(^"EngineSound") as AudioStreamPlayer3D).playing


func _is_contender(peer_id: int) -> bool:
	var player_name: String = Net.players.get(peer_id, "")
	return player_name in CONTENDERS


func _teleport(player: Player, at: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO


func _level_players() -> Array[Player]:
	var level := get_tree().current_scene as GreyboxLevel
	if level == null or not level.is_node_ready():
		return []
	return level.get_players()


func _wait_until(condition: Callable, timeout_sec: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var done: bool = condition.call()
		if done:
			return true
		await get_tree().process_frame
	return false


func _wait_signal_or_timeout(target_signal: Signal, timeout_sec: float) -> bool:
	var fired := [false]
	var mark := func() -> void: fired[0] = true
	target_signal.connect(mark, CONNECT_ONE_SHOT)
	return await _wait_until(func() -> bool: return fired[0] == true, timeout_sec)


func _seconds(duration: float) -> void:
	await get_tree().create_timer(duration).timeout


func _check(condition: bool, label: String) -> void:
	var tag := "[%s %s]" % [_role, _player_name]
	if condition:
		print("  PASS ", tag, " ", label)
	else:
		_failures += 1
		print("  FAIL ", tag, " ", label)


func _finish() -> void:
	print("NET SMOKE %s: %s (%d failed)" % [_role, "OK" if _failures == 0 else "FAILED", _failures])
	Net.leave()
	get_tree().unload_current_scene()
	for _frame in SHUTDOWN_FRAMES:
		await get_tree().process_frame
	get_tree().quit(0 if _failures == 0 else 1)
