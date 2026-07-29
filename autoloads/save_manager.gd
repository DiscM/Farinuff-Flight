extends Node
## Persists player preferences and durable progress between sessions.

signal settings_changed

const SAVE_PATH := "user://save_data.json"
## Schema version of the save file. Bump when the layout changes and add a
## migration path in _load_data.
const SAVE_VERSION := 1
const DEFAULT_SETTINGS: Dictionary = {
	"master_volume": 0.8,
	"music_volume": 0.8,
	"screen_shake": true,
	"crt_effect": true,
	"screen_distortion": true,
	"alt_controls": false,
	"fullscreen": false,
	"reduced_flashing": false,
}

var high_score: int = 0
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)

## Loads saved data from disk on startup and applies the persisted audio
## and control-scheme settings.
func _ready() -> void:
	_load_data()
	_apply_audio_settings()
	_apply_control_scheme()
	_apply_display_settings()

## Returns the value of a saved setting by key, or the provided fallback
## if the key does not exist.
func get_setting(key: String, fallback: Variant = null) -> Variant:
	return settings.get(key, fallback)

## Updates a setting value in memory, applies audio and control-scheme
## changes immediately, persists the change to disk, and emits
## settings_changed. Silently ignores keys not present in DEFAULT_SETTINGS
## to prevent storing arbitrary data.
func update_setting(key: String, value: Variant) -> void:
	if not DEFAULT_SETTINGS.has(key):
		return
	settings[key] = value
	_apply_audio_settings()
	_apply_control_scheme()
	_apply_display_settings()
	_save_data()
	settings_changed.emit()

## Records a new high score if it exceeds the current record, then
## persists it to disk.
func record_high_score(value: int) -> void:
	if value <= high_score:
		return
	high_score = value
	_save_data()

## Clears the saved high score back to 0 and persists the change.
func reset_high_score() -> void:
	high_score = 0
	_save_data()

## Loads saved data (high score and settings) from the JSON save file.
## Falls back to defaults if the file doesn't exist, can't be opened,
## or contains malformed data. Only overwrites settings keys that exist
## in DEFAULT_SETTINGS to avoid stale/invalid entries.
func _load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var data := parsed as Dictionary
	# Missing version means a pre-versioning save, which matches v1. A
	# different explicit version falls back to defaults until a migration exists.
	if int(data.get("version", SAVE_VERSION)) != SAVE_VERSION:
		return
	high_score = maxi(int(data.get("high_score", 0)), 0)
	var stored_settings: Variant = data.get("settings", {})
	if stored_settings is Dictionary:
		for key in DEFAULT_SETTINGS:
			if stored_settings.has(key):
				# Validate against the default's type: a hand-edited save like
				# "screen_shake": "false" would otherwise coerce the non-empty
				# string to true, silently inverting the user's intent.
				var value: Variant = stored_settings[key]
				if typeof(value) == typeof(DEFAULT_SETTINGS[key]):
					settings[key] = value

## Writes the current high score and settings dictionary to the JSON
## save file, formatted with tabs for readability.
func _save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Unable to save player data.")
		return
	var data := {
		"version": SAVE_VERSION,
		"high_score": high_score,
		"settings": settings,
	}
	file.store_string(JSON.stringify(data, "\t"))

## Applies the current master_volume and music_volume settings to their
## audio buses. Mutes a bus when its volume is effectively zero, otherwise
## converts the linear 0–1 value to decibels.
func _apply_audio_settings() -> void:
	_apply_bus_volume("Master", float(settings.get("master_volume", 0.8)))
	_apply_bus_volume("Music", float(settings.get("music_volume", 0.8)))

func _apply_bus_volume(bus_name: String, raw_volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var volume := clampf(raw_volume, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, volume <= 0.001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(volume, 0.001)))

## Applies the fullscreen setting to the main window.
func _apply_display_settings() -> void:
	var fullscreen := bool(settings.get("fullscreen", false))
	var window := get_tree().root
	if window == null:
		return
	var target := Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
	if window.mode != target:
		window.mode = target

## Applies the persisted control scheme to the global InputMap.
## Default: Space shoots, Shift boosts. Alt: left mouse button shoots,
## Space boosts. The swap is strict — Space never does both at once.
func _apply_control_scheme() -> void:
	var alt := bool(settings.get("alt_controls", false))
	_set_key_binding(&"shoot", KEY_SPACE, not alt)
	_set_mouse_binding(&"shoot", MOUSE_BUTTON_LEFT, alt)
	_set_key_binding(&"boost", KEY_SHIFT, not alt)
	_set_key_binding(&"boost", KEY_SPACE, alt)

## Ensures the given physical key is present on (enabled) or absent from
## (disabled) an input action, without disturbing the action's other events.
func _set_key_binding(action: StringName, physical_key: Key, enabled: bool) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == physical_key:
			InputMap.action_erase_event(action, event)
	if enabled:
		var event := InputEventKey.new()
		event.physical_keycode = physical_key
		InputMap.action_add_event(action, event)

## Ensures the given mouse button is present on (enabled) or absent from
## (disabled) an input action, without disturbing the action's other events.
func _set_mouse_binding(action: StringName, button: MouseButton, enabled: bool) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and event.button_index == button:
			InputMap.action_erase_event(action, event)
	if enabled:
		var event := InputEventMouseButton.new()
		event.button_index = button
		InputMap.action_add_event(action, event)
