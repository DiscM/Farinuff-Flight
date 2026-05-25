extends Node
## Persists player preferences and durable progress between sessions.

signal settings_changed

const SAVE_PATH := "user://save_data.json"
const DEFAULT_SETTINGS: Dictionary = {
	"master_volume": 0.8,
	"screen_shake": true,
	"crt_effect": true,
	"screen_distortion": true,
}

var high_score: int = 0
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)

func _ready() -> void:
	_load_data()
	_apply_audio_settings()

func get_setting(key: String, fallback: Variant = null) -> Variant:
	return settings.get(key, fallback)

func update_setting(key: String, value: Variant) -> void:
	if not DEFAULT_SETTINGS.has(key):
		return
	settings[key] = value
	_apply_audio_settings()
	_save_data()
	settings_changed.emit()

func record_high_score(value: int) -> void:
	if value <= high_score:
		return
	high_score = value
	_save_data()

func reset_high_score() -> void:
	high_score = 0
	_save_data()

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
	high_score = maxi(int(data.get("high_score", 0)), 0)
	var stored_settings: Variant = data.get("settings", {})
	if stored_settings is Dictionary:
		for key in DEFAULT_SETTINGS:
			if stored_settings.has(key):
				settings[key] = stored_settings[key]

func _save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Unable to save player data.")
		return
	var data := {
		"high_score": high_score,
		"settings": settings,
	}
	file.store_string(JSON.stringify(data, "\t"))

func _apply_audio_settings() -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index < 0:
		return
	var volume := clampf(float(settings.get("master_volume", 0.8)), 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, volume <= 0.001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(volume, 0.001)))
