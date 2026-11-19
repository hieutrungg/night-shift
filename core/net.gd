extends Node
## Autoload "Net": hosting, joining, the lobby roster and starting a match.
## The host (peer 1) owns the roster; clients only send requests.

signal roster_changed
signal connected_to_lobby
signal join_failed(reason_key: String)
signal all_players_loaded
signal player_left(peer_id: int)

const LEVEL_SCENE_PATH: String = "res://levels/greybox_01/greybox_01.tscn"
const MENU_SCENE_PATH: String = "res://ui/main_menu/main_menu.tscn"
const MAX_NAME_LENGTH: int = 16
## Lets the rejection message reach the peer before it is disconnected.
const KICK_DELAY_SEC: float = 0.5

## peer id -> display name. Only the host edits it; clients receive copies.
var players: Dictionary[int, String] = {}
var in_game: bool = false
## Translation key explaining why the last session ended; the menu shows it once.
var last_end_reason_key: String = ""

var _local_name: String = ""
var _loaded_peers: Array[int] = []


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_online() -> bool:
	return not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


func host(player_name: String, port: int = GameConfig.DEFAULT_PORT) -> Error:
	_close_peer()
	var peer := ENetMultiplayerPeer.new()
	# One spare slot so an extra peer can be told "room full" instead of timing out.
	var error := peer.create_server(port, GameConfig.MAX_PLAYERS)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	players[1] = _clean_name(player_name, 1)
	_set_window_title(players[1])
	roster_changed.emit()
	connected_to_lobby.emit()
	return OK


func join(address: String, player_name: String, port: int = GameConfig.DEFAULT_PORT) -> Error:
	_close_peer()
	_local_name = player_name
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.strip_edges(), port)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	return OK


func leave() -> void:
	_close_peer()


func return_to_menu(reason_key: String = "") -> void:
	_close_peer()
	last_end_reason_key = reason_key
	get_tree().change_scene_to_file(MENU_SCENE_PATH)


func can_start_game() -> bool:
	return (multiplayer.is_server() and is_online() and not in_game
		and players.size() >= GameConfig.MIN_PLAYERS
		and players.size() <= GameConfig.MAX_PLAYERS)


func start_game() -> bool:
	if not can_start_game():
		return false
	_begin_game.rpc()
	return true


## Called by the level once it is ready on this peer. The host spawns players
## only after every peer reported, so no spawn message is lost.
func report_level_loaded() -> void:
	if multiplayer.is_server():
		_mark_loaded(1)
	else:
		_level_loaded.rpc_id(1)


@rpc("authority", "call_local", "reliable")
func _begin_game() -> void:
	in_game = true
	_loaded_peers.clear()
	get_tree().change_scene_to_file(LEVEL_SCENE_PATH)


@rpc("any_peer", "call_remote", "reliable")
func _level_loaded() -> void:
	if not multiplayer.is_server():
		return
	_mark_loaded(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func _request_register(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var reason := _admission_problem()
	if not reason.is_empty():
		_reject(peer_id, reason)
		return
	players[peer_id] = _clean_name(player_name, peer_id)
	_broadcast_roster()


@rpc("authority", "call_local", "reliable")
func _sync_roster(roster: Dictionary) -> void:
	var was_listed := players.has(multiplayer.get_unique_id())
	players.assign(roster)
	roster_changed.emit()
	if not was_listed and players.has(multiplayer.get_unique_id()):
		_set_window_title(players[multiplayer.get_unique_id()])
		connected_to_lobby.emit()


@rpc("authority", "call_remote", "reliable")
func _rejected(reason_key: String) -> void:
	_fail_join(reason_key)


func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var reason := _admission_problem()
	if not reason.is_empty():
		_reject(peer_id, reason)
	# Otherwise wait for the peer to send its name.


func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if not players.erase(peer_id):
		return
	_loaded_peers.erase(peer_id)
	_broadcast_roster()
	player_left.emit(peer_id)
	if in_game and _all_loaded():
		all_players_loaded.emit()


func _on_connected_to_server() -> void:
	_request_register.rpc_id(1, _local_name)


func _on_connection_failed() -> void:
	_fail_join("ERR_CONNECT_FAILED")


func _on_server_disconnected() -> void:
	return_to_menu("MSG_HOST_LEFT")


func _admission_problem() -> String:
	if in_game:
		return "ERR_GAME_IN_PROGRESS"
	if players.size() >= GameConfig.MAX_PLAYERS:
		return "ERR_ROOM_FULL"
	return ""


func _reject(peer_id: int, reason_key: String) -> void:
	_rejected.rpc_id(peer_id, reason_key)
	get_tree().create_timer(KICK_DELAY_SEC).timeout.connect(_kick.bind(peer_id))


func _kick(peer_id: int) -> void:
	if is_online() and multiplayer.get_peers().has(peer_id):
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)


func _fail_join(reason_key: String) -> void:
	_close_peer()
	last_end_reason_key = reason_key
	join_failed.emit(reason_key)


func _broadcast_roster() -> void:
	var roster: Dictionary = players.duplicate()
	_sync_roster.rpc(roster)


func _mark_loaded(peer_id: int) -> void:
	if not players.has(peer_id) or _loaded_peers.has(peer_id):
		return
	_loaded_peers.append(peer_id)
	if _all_loaded():
		all_players_loaded.emit()


func _all_loaded() -> bool:
	for peer_id: int in players.keys():
		if not _loaded_peers.has(peer_id):
			return false
	return true


func _clean_name(player_name: String, peer_id: int) -> String:
	var cleaned := player_name.strip_edges().left(MAX_NAME_LENGTH)
	if cleaned.is_empty():
		cleaned = tr("UI_DEFAULT_PLAYER_NAME").format({"number": peer_id % 1000})
	return cleaned


func _close_peer() -> void:
	if is_online():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	_loaded_peers.clear()
	in_game = false


func _set_window_title(player_name: String) -> void:
	# Makes several local test instances easy to tell apart.
	get_window().title = "%s - %s" % [tr("UI_GAME_TITLE"), player_name]
