extends Node
## Autoload "Settings": player preferences, saved to user://settings.cfg.

signal locale_changed(locale: String)

const SAVE_PATH: String = "user://settings.cfg"
const SECTION: String = "settings"

var locale: String = GameConfig.DEFAULT_LOCALE
var mouse_sensitivity: float = 0.0025
var master_volume_db: float = 0.0
var player_name: String = ""


func _ready() -> void:
	InputActions.register_defaults()
	load_settings()
	_apply()


func set_locale(new_locale: String) -> void:
	if not GameConfig.SUPPORTED_LOCALES.has(new_locale):
		push_warning("Unsupported locale: %s" % new_locale)
		return
	locale = new_locale
	TranslationServer.set_locale(locale)
	save_settings()
	locale_changed.emit(locale)


func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.0005, 0.01)
	save_settings()


func set_master_volume_db(value: float) -> void:
	master_volume_db = clampf(value, -60.0, 6.0)
	AudioServer.set_bus_volume_db(0, master_volume_db)
	save_settings()


func set_player_name(value: String) -> void:
	player_name = value.strip_edges()
	save_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return  # First launch: keep defaults (English).
	var saved_locale: String = config.get_value(SECTION, "locale", GameConfig.DEFAULT_LOCALE)
	if GameConfig.SUPPORTED_LOCALES.has(saved_locale):
		locale = saved_locale
	mouse_sensitivity = config.get_value(SECTION, "mouse_sensitivity", mouse_sensitivity)
	master_volume_db = config.get_value(SECTION, "master_volume_db", master_volume_db)
	player_name = config.get_value(SECTION, "player_name", player_name)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "locale", locale)
	config.set_value(SECTION, "mouse_sensitivity", mouse_sensitivity)
	config.set_value(SECTION, "master_volume_db", master_volume_db)
	config.set_value(SECTION, "player_name", player_name)
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("Could not save settings: %s" % error_string(error))


func _apply() -> void:
	TranslationServer.set_locale(locale)
	AudioServer.set_bus_volume_db(0, master_volume_db)
