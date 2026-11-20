extends Control
## Main menu: host or join by IP, then the lobby until the host starts.

const ADDRESS_SEPARATOR: String = "  ·  "
const VERSION_LABEL_ALPHA: float = 0.5
const VERSION_LABEL_MARGIN: int = 12

var _status_key: String = ""
var _status_args: Dictionary = {}
var _version_label: Label

@onready var _menu_panel: Control = %MenuPanel
@onready var _lobby_panel: Control = %LobbyPanel
@onready var _name_edit: LineEdit = %NameEdit
@onready var _address_edit: LineEdit = %AddressEdit
@onready var _solo_button: Button = %SoloButton
@onready var _friends_label: Label = %FriendsLabel
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _status_label: Label = %StatusLabel
@onready var _player_list: VBoxContainer = %PlayerList
@onready var _lobby_status_label: Label = %LobbyStatusLabel
@onready var _address_info_label: Label = %AddressInfoLabel
@onready var _start_button: Button = %StartButton
@onready var _leave_button: Button = %LeaveButton
@onready var _settings_panel: SettingsPanel = %SettingsPanel


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_name_edit.text = Settings.player_name
	_name_edit.max_length = Net.MAX_NAME_LENGTH
	_solo_button.pressed.connect(_on_solo_pressed)
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_settings_button.pressed.connect(_settings_panel.open)
	_quit_button.pressed.connect(_on_quit_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	_leave_button.pressed.connect(_on_leave_pressed)
	Net.roster_changed.connect(_refresh_lobby)
	Net.connected_to_lobby.connect(_show_lobby)
	Net.join_failed.connect(_on_join_failed)
	Settings.locale_changed.connect(_on_locale_changed)
	_add_version_label()
	_refresh_friends_label()
	_show_menu()
	if not Net.last_end_reason_key.is_empty():
		_set_status(Net.last_end_reason_key)
		Net.last_end_reason_key = ""


func _on_solo_pressed() -> void:
	Settings.set_player_name(_name_edit.text)
	Net.start_solo(_name_edit.text)


func _on_host_pressed() -> void:
	Settings.set_player_name(_name_edit.text)
	var error := Net.host(_name_edit.text)
	if error != OK:
		_set_status("ERR_HOST_FAILED", {"port": GameConfig.DEFAULT_PORT, "error": error_string(error)})


func _on_join_pressed() -> void:
	var address := _address_edit.text.strip_edges()
	if address.is_empty():
		_set_status("ERR_INVALID_ADDRESS")
		return
	Settings.set_player_name(_name_edit.text)
	var error := Net.join(address, _name_edit.text)
	if error != OK:
		_set_status("ERR_CONNECT_FAILED")
		return
	_set_status("MSG_CONNECTING")
	_set_menu_buttons_enabled(false)


func _on_join_failed(reason_key: String) -> void:
	_show_menu()
	_set_status(reason_key)


func _on_start_pressed() -> void:
	Net.start_game()


func _on_leave_pressed() -> void:
	Net.leave()
	_show_menu()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_locale_changed(_locale: String) -> void:
	_version_label.text = tr("UI_VERSION").format({"version": GameConfig.GAME_VERSION})
	_refresh_friends_label()
	_refresh_lobby()
	if not _status_key.is_empty():
		_set_status(_status_key, _status_args)


func _show_menu() -> void:
	_menu_panel.visible = true
	_lobby_panel.visible = false
	_set_menu_buttons_enabled(true)
	_status_key = ""
	_status_label.text = ""


func _show_lobby() -> void:
	_menu_panel.visible = false
	_lobby_panel.visible = true
	_refresh_lobby()


func _refresh_lobby() -> void:
	if not _lobby_panel.visible:
		return
	for child in _player_list.get_children():
		child.queue_free()
	var peer_ids: Array[int] = []
	peer_ids.assign(Net.players.keys())
	peer_ids.sort()
	for peer_id in peer_ids:
		_player_list.add_child(_make_player_row(peer_id))

	var is_host := multiplayer.is_server()
	_start_button.visible = is_host
	_start_button.disabled = not Net.can_start_game()
	_lobby_status_label.text = tr("UI_LOBBY_STATUS").format({
		"count": Net.players.size(),
		"max": GameConfig.MAX_PLAYERS,
		"min": GameConfig.MIN_PLAYERS,
	})
	if is_host:
		_address_info_label.text = tr("UI_YOUR_ADDRESSES").format(
			{"addresses": ADDRESS_SEPARATOR.join(_local_ipv4_addresses())})
	else:
		_address_info_label.text = tr("UI_WAITING_FOR_HOST")


func _make_player_row(peer_id: int) -> Label:
	var row := Label.new()
	row.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var text: String = Net.players[peer_id]
	if peer_id == 1:
		text += " " + tr("UI_TAG_HOST")
	if peer_id == multiplayer.get_unique_id():
		text += " " + tr("UI_TAG_YOU")
	row.text = text
	return row


func _local_ipv4_addresses() -> PackedStringArray:
	var result := PackedStringArray()
	for address in IP.get_local_addresses():
		var is_ipv4 := address.count(".") == 3
		if is_ipv4 and not address.begins_with("127.") and not address.begins_with("169.254."):
			result.append(address)
	return result


func _set_status(key: String, args: Dictionary = {}) -> void:
	_status_key = key
	_status_args = args
	var values := {"max": GameConfig.MAX_PLAYERS, "min": GameConfig.MIN_PLAYERS, "version": GameConfig.GAME_VERSION}
	values.merge(args, true)
	_status_label.text = tr(key).format(values)


func _refresh_friends_label() -> void:
	_friends_label.text = tr("UI_WITH_FRIENDS").format(
		{"min": GameConfig.MIN_PLAYERS, "max": GameConfig.MAX_PLAYERS})


func _set_menu_buttons_enabled(enabled: bool) -> void:
	_solo_button.disabled = not enabled
	_host_button.disabled = not enabled
	_join_button.disabled = not enabled


## Shown in the corner so friends can check they all run the same build.
func _add_version_label() -> void:
	_version_label = Label.new()
	_version_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_version_label.text = tr("UI_VERSION").format({"version": GameConfig.GAME_VERSION})
	_version_label.modulate = Color(1.0, 1.0, 1.0, VERSION_LABEL_ALPHA)
	_version_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, VERSION_LABEL_MARGIN)
	_version_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_version_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_version_label)
