class_name Hud
extends CanvasLayer
## In-game overlay: crosshair, prompts, held item, round clock and quota,
## pause screen (settings, leave) and the end-of-round results.

## Host only: the host pressed "Play again".
signal play_again_requested

const SECONDS_PER_MINUTE: int = 60
## Seconds left at which the clock beeps; it also beeps every second below FINAL_BEEP_SEC.
const WARNING_BEEP_SECONDS: Array[int] = [60, 30]
const FINAL_BEEP_SEC: int = 10

var _held_item: Item = null
var _round: RoundManager = null
var _shown_seconds: int = -1
var _spectate_target: Player = null
var _last_beep_second: int = -1
var _player: Player = null
var _trip_label: Label
var _notice_label: Label
var _warning_label: Label
var _progress: ProgressBar
var _fade: ColorRect
var _notice_left: float = 0.0
var _last_driver: int = 0
var _quota_reached: bool = false
var _pending_driver_notice: bool = false

@onready var _prompt_label: Label = %PromptLabel
@onready var _held_label: Label = %HeldLabel
@onready var _time_label: Label = %TimeLabel
@onready var _quota_label: Label = %QuotaLabel
@onready var _death_panel: Control = %DeathPanel
@onready var _spectate_label: Label = %SpectateLabel
@onready var _pause_panel: Control = %PausePanel
@onready var _paused_label: Label = %PausedLabel
@onready var _settings_button: Button = %SettingsButton
@onready var _leave_button: Button = %LeaveButton
@onready var _settings_panel: SettingsPanel = %SettingsPanel
@onready var _results_panel: Control = %ResultsPanel
@onready var _result_title: Label = %ResultTitle
@onready var _result_reason: Label = %ResultReason
@onready var _result_detail: Label = %ResultDetail
@onready var _play_again_button: Button = %PlayAgainButton
@onready var _result_waiting_label: Label = %ResultWaitingLabel
@onready var _result_leave_button: Button = %ResultLeaveButton
@onready var _sting_sound: AudioStreamPlayer = %StingSound
@onready var _beep_sound: AudioStreamPlayer = %BeepSound


func _ready() -> void:
	_prompt_label.text = ""
	_time_label.text = ""
	_quota_label.text = ""
	_results_panel.visible = false
	_death_panel.visible = false
	_paused_label.visible = Net.is_solo
	_sting_sound.stream = Sfx.death_sting()
	_beep_sound.stream = Sfx.beep()
	Settings.locale_changed.connect(_on_locale_changed)
	_settings_button.pressed.connect(_settings_panel.open)
	_leave_button.pressed.connect(_on_leave_pressed)
	_result_leave_button.pressed.connect(_on_leave_pressed)
	_play_again_button.pressed.connect(_on_play_again_pressed)
	_refresh_held()
	_create_trip_ui()


func _process(delta: float) -> void:
	# Esc frees the mouse; that is when the pause buttons are reachable.
	var menu_open := Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not _results_panel.visible
	_pause_panel.visible = menu_open and not _settings_panel.visible
	# Only solo can freeze the world; online the others keep playing.
	if Net.is_solo and get_tree().paused != menu_open:
		get_tree().paused = menu_open
	_refresh_time()
	_refresh_trip(delta)


func bind_player(player: Player) -> void:
	_player = player
	player.interact_prompt_changed.connect(_on_interact_prompt_changed)
	player.held_item_changed.connect(_on_held_item_changed)


func bind_round(round_manager: RoundManager) -> void:
	_round = round_manager
	_round.collected_changed.connect(_on_collected_changed)
	_round.round_ended.connect(_on_round_ended)
	_refresh_quota()
	if _round.phase == RoundManager.Phase.ENDED:
		_show_results()


func play_death_sting() -> void:
	_sting_sound.play()


## Shown once this peer's player died.
func bind_spectator(spectator: Spectator) -> void:
	_death_panel.visible = true
	_prompt_label.text = ""
	spectator.target_changed.connect(_on_spectate_target_changed)
	_on_spectate_target_changed(spectator.get_target())


func _on_interact_prompt_changed(text: String) -> void:
	_prompt_label.text = text


func _on_held_item_changed(item: Item) -> void:
	_held_item = item
	_refresh_held()


func _on_collected_changed(_collected: int, _quota: int) -> void:
	_refresh_quota()
	if _round.quota > 0 and _round.collected >= _round.quota and not _quota_reached:
		_quota_reached = true
		if _notice_left > 0.0:
			_notice_label.text += "\n" + tr("HUD_QUOTA_REACHED")
		else:
			_notice_label.text = tr("HUD_QUOTA_REACHED")
		_notice_left = GameConfig.TRIP_NOTICE_SEC
		_beep_sound.stream = Sfx.quota_reached()
		_beep_sound.play()


func _on_round_ended(_success: bool, _collected: int, _quota: int) -> void:
	_refresh_quota()
	_show_results()


func _on_locale_changed(_locale: String) -> void:
	_refresh_held()
	_refresh_spectate()
	_refresh_quota()
	_shown_seconds = -1
	if _results_panel.visible:
		_show_results()


func _on_play_again_pressed() -> void:
	_play_again_button.disabled = true
	play_again_requested.emit()


func _on_leave_pressed() -> void:
	Net.return_to_menu()


func _show_results() -> void:
	_settings_panel.close()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_results_panel.visible = true
	_result_title.text = tr("ROUND_SUCCESS" if _round.success else "ROUND_FAILED")
	_result_reason.text = tr(_round.get_end_reason_key())
	_result_detail.text = tr("ROUND_COLLECTED").format({"collected": _round.collected, "quota": _round.quota})
	_result_detail.text += "\n" + tr("ROUND_SURVIVORS").format({"count": _round.survivors})
	if not _round.left_names.is_empty():
		_result_detail.text += "\n" + tr("ROUND_LEFT_BEHIND").format({"names": ", ".join(_round.left_names)})
	var is_host := multiplayer.is_server()
	_play_again_button.visible = is_host
	_result_waiting_label.visible = not is_host


func _refresh_held() -> void:
	if not is_instance_valid(_held_item):
		_held_label.text = ""
		return
	var key := "HUD_CARRYING_BULKY" if _held_item.data.bulky else "HUD_HOLDING"
	_held_label.text = tr(key).format({
		"item": tr(_held_item.data.name_key),
		"value": _held_item.data.value,
	})


func _refresh_quota() -> void:
	if _round == null or _round.phase == RoundManager.Phase.WAITING:
		_quota_label.text = ""
		return
	_quota_label.text = tr("HUD_QUOTA").format({"current": _round.collected, "target": _round.quota})


func _refresh_time() -> void:
	if _round == null or _round.phase == RoundManager.Phase.WAITING:
		return
	var seconds := ceili(_round.time_left)
	if seconds == _shown_seconds:
		return
	_shown_seconds = seconds
	_maybe_beep(seconds)
	@warning_ignore("integer_division")
	var clock := "%d:%02d" % [seconds / SECONDS_PER_MINUTE, seconds % SECONDS_PER_MINUTE]
	_time_label.text = tr("HUD_TIME_LEFT").format({"time": clock})


func _on_spectate_target_changed(target: Player) -> void:
	_spectate_target = target
	_refresh_spectate()


func _refresh_spectate() -> void:
	if not is_instance_valid(_spectate_target):
		_spectate_label.text = ""
		return
	var target_name: String = Net.players.get(_spectate_target.get_peer_id(), "")
	_spectate_label.text = tr("HUD_SPECTATING").format({"name": target_name})


func _maybe_beep(seconds: int) -> void:
	if not _round.is_playing() or seconds == _last_beep_second or seconds <= 0:
		return
	if seconds in WARNING_BEEP_SECONDS or seconds <= FINAL_BEEP_SEC:
		_last_beep_second = seconds
		_beep_sound.stream = Sfx.beep()
		_beep_sound.play()


func _create_trip_ui() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER_TOP)
	column.offset_left = -300.0
	column.offset_right = 300.0
	column.offset_top = 80.0
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root.add_child(column)
	_notice_label = Label.new()
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice_label.add_theme_font_size_override("font_size", 20)
	column.add_child(_notice_label)
	_trip_label = Label.new()
	_trip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trip_label.add_theme_font_size_override("font_size", 20)
	column.add_child(_trip_label)
	_warning_label = Label.new()
	_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_label.add_theme_font_size_override("font_size", 32)
	_warning_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.25))
	_warning_label.text = "HUD_DEPARTURE_WARNING"
	column.add_child(_warning_label)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size.y = 16.0
	_progress.max_value = GameConfig.DRIVER_HOLD_SEC
	_progress.show_percentage = false
	_progress.visible = false
	column.add_child(_progress)
	_fade = ColorRect.new()
	_fade.color = Color.TRANSPARENT
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Root.add_child(_fade)
	$Root.move_child(_fade, 0)


func _refresh_trip(delta: float) -> void:
	if not is_instance_valid(_player) or not _player.is_inside_tree() or _player.trip == null or _round == null:
		return
	var trip := _player.trip
	if not is_instance_valid(trip.van) or not trip.van.is_inside_tree():
		return
	var local_id := _player.get_peer_id()
	if trip.driver_id != _last_driver:
		_last_driver = trip.driver_id
		if trip.driver_id == local_id:
			_pending_driver_notice = true
		else:
			_pending_driver_notice = false
	_notice_left = maxf(_notice_left - delta, 0.0)
	if _pending_driver_notice:
		_pending_driver_notice = false
		if _notice_left > 0.0:
			_notice_label.text += "\n" + tr("HUD_YOU_ARE_DRIVER")
		else:
			_notice_label.text = tr("HUD_YOU_ARE_DRIVER")
		_notice_left = GameConfig.TRIP_NOTICE_SEC
	_notice_label.visible = _notice_left > 0.0
	var lines: Array[String] = []
	var seated := _player.seat_index >= 0
	# Once the truck is about to leave only the warning and the countdown matter.
	var leaving_soon := trip.hold_elapsed >= 0.0 or trip.countdown >= 0.0
	var nearby := trip.van.distance_to(_player.global_position) <= GameConfig.INTERACT_MAX_DISTANCE
	if leaving_soon:
		pass
	elif seated and (_round.is_playing() or (_round.phase == RoundManager.Phase.ARRIVING and trip.arrival_elapsed >= GameConfig.ARRIVAL_SEC)):
		lines.append(tr("HUD_DISEMBARK"))
		if trip.driver_id == local_id:
			lines.append(tr("HUD_DRIVER_HINT"))
	elif nearby and _round.is_playing():
		lines.append(tr("HUD_BOARD"))
	if not leaving_soon and (nearby or seated) and trip.driver_id != 0 and trip.driver_id != local_id:
		lines.append(tr("HUD_DRIVER_NAME").format({"name": Net.players.get(trip.driver_id, "")}))
	if not leaving_soon and seated and _round.is_playing() and _round.collected < _round.quota:
		lines.append(tr("HUD_QUOTA_MISSING").format({"missing": _round.quota - _round.collected}))
	if trip.countdown >= 0.0:
		lines.append(tr("HUD_DEPARTURE_COUNTDOWN").format({"seconds": ceili(trip.countdown)}))
	_warning_label.visible = trip.hold_elapsed >= 0.0 and _round.is_playing()
	_progress.visible = _warning_label.visible
	_progress.value = maxf(trip.hold_elapsed, 0.0)
	_trip_label.text = "\n".join(lines)
	if _round.phase == RoundManager.Phase.DEPARTING:
		_fade.color = Color(0.0, 0.0, 0.0, minf(_fade.color.a + delta / GameConfig.DEPARTURE_SEC, 1.0))


# While a solo game is paused the player node gets no input, so the HUD
# (which always runs) handles the click that resumes it.
func _unhandled_input(event: InputEvent) -> void:
	if not get_tree().paused or _settings_panel.visible or not is_instance_valid(_player):
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_player.capture_mouse()
		get_viewport().set_input_as_handled()
