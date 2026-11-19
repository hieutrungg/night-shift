class_name SettingsPanel
extends Control
## Full-screen settings overlay: language, mouse sensitivity, volume.
## Used by the main menu and the in-game pause screen. Changes apply and save
## immediately through the Settings autoload.

signal closed

const MIN_SENSITIVITY: float = 0.0005
const MAX_SENSITIVITY: float = 0.01
## Volume slider is 0..100 %, stored as decibels.
const MAX_VOLUME_PERCENT: float = 100.0

## Order matches GameConfig.SUPPORTED_LOCALES; each language shows its own name.
const LANGUAGE_KEYS: Dictionary[String, String] = {
	"en": "SET_LANG_EN",
	"vi": "SET_LANG_VI",
}

@onready var _language_option: OptionButton = %LanguageOption
@onready var _sensitivity_slider: HSlider = %SensitivitySlider
@onready var _volume_slider: HSlider = %VolumeSlider
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	for locale in GameConfig.SUPPORTED_LOCALES:
		var key: String = LANGUAGE_KEYS.get(locale, locale)
		_language_option.add_item(key)
	_sensitivity_slider.min_value = MIN_SENSITIVITY
	_sensitivity_slider.max_value = MAX_SENSITIVITY
	_sensitivity_slider.step = MIN_SENSITIVITY / 5.0
	_volume_slider.max_value = MAX_VOLUME_PERCENT
	_load_values()
	_language_option.item_selected.connect(_on_language_selected)
	_sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	_volume_slider.value_changed.connect(_on_volume_changed)
	_close_button.pressed.connect(close)
	visibility_changed.connect(_on_visibility_changed)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(InputActions.PAUSE):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _load_values() -> void:
	_language_option.select(maxi(GameConfig.SUPPORTED_LOCALES.find(Settings.locale), 0))
	_sensitivity_slider.set_value_no_signal(Settings.mouse_sensitivity)
	_volume_slider.set_value_no_signal(db_to_linear(Settings.master_volume_db) * MAX_VOLUME_PERCENT)


func _on_visibility_changed() -> void:
	if visible:
		_load_values()
		_close_button.grab_focus()


func _on_language_selected(index: int) -> void:
	Settings.set_locale(GameConfig.SUPPORTED_LOCALES[index])


func _on_sensitivity_changed(value: float) -> void:
	Settings.set_mouse_sensitivity(value)


func _on_volume_changed(value: float) -> void:
	Settings.set_master_volume_db(linear_to_db(value / MAX_VOLUME_PERCENT))
