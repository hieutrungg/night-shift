class_name Hud
extends CanvasLayer
## In-game overlay: crosshair, prompts, held item, round clock and quota,
## pause screen (settings, leave) and the end-of-round results.

## Host only: the host pressed "Play again".
signal play_again_requested

const SECONDS_PER_MINUTE: int = 60

var _held_item: Item = null
var _round: RoundManager = null
var _shown_seconds: int = -1

@onready var _prompt_label: Label = %PromptLabel
@onready var _held_label: Label = %HeldLabel
@onready var _time_label: Label = %TimeLabel
@onready var _quota_label: Label = %QuotaLabel
@onready var _pause_panel: Control = %PausePanel
@onready var _settings_button: Button = %SettingsButton
@onready var _leave_button: Button = %LeaveButton
@onready var _settings_panel: SettingsPanel = %SettingsPanel
@onready var _results_panel: Control = %ResultsPanel
@onready var _result_title: Label = %ResultTitle
@onready var _result_detail: Label = %ResultDetail
@onready var _play_again_button: Button = %PlayAgainButton
@onready var _result_waiting_label: Label = %ResultWaitingLabel
@onready var _result_leave_button: Button = %ResultLeaveButton


func _ready() -> void:
	_prompt_label.text = ""
	_time_label.text = ""
	_quota_label.text = ""
	_results_panel.visible = false
	Settings.locale_changed.connect(_on_locale_changed)
	_settings_button.pressed.connect(_settings_panel.open)
	_leave_button.pressed.connect(_on_leave_pressed)
	_result_leave_button.pressed.connect(_on_leave_pressed)
	_play_again_button.pressed.connect(_on_play_again_pressed)
	_refresh_held()


func _process(_delta: float) -> void:
	# Esc frees the mouse; that is when the pause buttons are reachable.
	var overlay_open := _results_panel.visible or _settings_panel.visible
	_pause_panel.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not overlay_open
	_refresh_time()


func bind_player(player: Player) -> void:
	player.interact_prompt_changed.connect(_on_interact_prompt_changed)
	player.held_item_changed.connect(_on_held_item_changed)


func bind_round(round_manager: RoundManager) -> void:
	_round = round_manager
	_round.collected_changed.connect(_on_collected_changed)
	_round.round_ended.connect(_on_round_ended)
	_refresh_quota()
	if _round.phase == RoundManager.Phase.ENDED:
		_show_results()


func _on_interact_prompt_changed(text: String) -> void:
	_prompt_label.text = text


func _on_held_item_changed(item: Item) -> void:
	_held_item = item
	_refresh_held()


func _on_collected_changed(_collected: int, _quota: int) -> void:
	_refresh_quota()


func _on_round_ended(_success: bool, _collected: int, _quota: int) -> void:
	_refresh_quota()
	_show_results()


func _on_locale_changed(_locale: String) -> void:
	_refresh_held()
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
	_result_detail.text = tr("ROUND_COLLECTED").format({"collected": _round.collected, "quota": _round.quota})
	var is_host := multiplayer.is_server()
	_play_again_button.visible = is_host
	_result_waiting_label.visible = not is_host


func _refresh_held() -> void:
	if not is_instance_valid(_held_item):
		_held_label.text = ""
		return
	_held_label.text = tr("HUD_HOLDING").format({
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
	@warning_ignore("integer_division")
	var clock := "%d:%02d" % [seconds / SECONDS_PER_MINUTE, seconds % SECONDS_PER_MINUTE]
	_time_label.text = tr("HUD_TIME_LEFT").format({"time": clock})
