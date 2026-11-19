class_name Hud
extends CanvasLayer
## In-game overlay: crosshair, interaction prompt, held item, controls hint.

var _held_item: Item = null

@onready var _prompt_label: Label = %PromptLabel
@onready var _held_label: Label = %HeldLabel
@onready var _pause_panel: Control = %PausePanel
@onready var _leave_button: Button = %LeaveButton


func _ready() -> void:
	_prompt_label.text = ""
	Settings.locale_changed.connect(_on_locale_changed)
	_leave_button.pressed.connect(_on_leave_pressed)
	_refresh_held()


func _process(_delta: float) -> void:
	# Esc frees the mouse; that is when the leave button is reachable.
	_pause_panel.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED


func bind_player(player: Player) -> void:
	player.interact_prompt_changed.connect(_on_interact_prompt_changed)
	player.held_item_changed.connect(_on_held_item_changed)


func _on_interact_prompt_changed(text: String) -> void:
	_prompt_label.text = text


func _on_held_item_changed(item: Item) -> void:
	_held_item = item
	_refresh_held()


func _on_locale_changed(_locale: String) -> void:
	_refresh_held()


func _on_leave_pressed() -> void:
	Net.return_to_menu()


func _refresh_held() -> void:
	if _held_item == null:
		_held_label.text = ""
		return
	_held_label.text = tr("HUD_HOLDING").format({
		"item": tr(_held_item.data.name_key),
		"value": _held_item.data.value,
	})
