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
	var moved := await _wait_until(_all_clients_moved, 15.0)
	_check(moved, "every client's movement reached the host")
	# Let clients finish their own checks before the host leaves.
	await _seconds(3.0)


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
	for other in _level_players():
		if other != me and other.is_multiplayer_authority():
			_check(false, "client must not control player %s" % other.name)
	me.global_position.x += CLIENT_SHIFT
	var host_left := await _wait_until(func() -> bool: return not Net.is_online(), 60.0)
	_check(host_left, "host ended the session")


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
	get_tree().quit(0 if _failures == 0 else 1)
