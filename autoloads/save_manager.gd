extends Node
## Persists player preferences and durable progress between sessions.

signal settings_changed
signal storage_status_changed

const WindowLayout := preload("res://systems/game_window_layout.gd")
const SAVE_FILE_NAME := "save_data.json"
const SAVE_TEMP_FILE_NAME := "save_data.json.tmp"
const SAVE_BACKUP_FILE_NAME := "save_data.json.bak"
const SAVE_PATH := "user://" + SAVE_FILE_NAME
const SAVE_TEMP_PATH := "user://" + SAVE_TEMP_FILE_NAME
const SAVE_BACKUP_PATH := "user://" + SAVE_BACKUP_FILE_NAME
## Schema version of the save file. Bump when the layout changes and add a
## migration path in _load_data. Version 3 adds durable campaign discovery
## state while keeping active-run state intentionally in memory only.
## Version 4 adds encountered boss waves; version 5 separates recovered fragments
## from viewed story so Story Off does not prevent archive collection.
## Version 7 moves all preferences and bindings into a machine-local file.
const SAVE_VERSION := 7
const PREFERENCES_PATH := "user://local_settings.json"
const PREFERENCES_VERSION := 1
const JsonStore := preload("res://systems/versioned_json_store.gd")
const DEFAULT_SETTINGS: Dictionary = {
	"master_volume": 0.8,
	"music_volume": 0.8,
	# Preserve the previous direct-to-Master mix for existing and fresh profiles.
	"sfx_volume": 1.0,
	"ui_volume": 0.8,
	"screen_shake": true,
	"crt_effect": true,
	"screen_distortion": true,
	"alt_controls": false,
	"fullscreen": false,
	"window_size": WindowLayout.DEFAULT_PRESET,
	"reduced_flashing": false,
	"reduced_motion": false,
	"hold_to_confirm": false,
	"menu_text_scale": 1.0,
	"aim_deadzone": 0.4,
	"story_frequency": 0,
	"graphics_quality": "high",
	"frame_cap": 0,
	"vsync": true,
	"hud_scale": 1.0,
	"toggle_fire": false,
}
const DEFAULT_CAMPAIGN_STATE: Dictionary = {
	"discovered_node_ids": [],
	"seen_story_beat_ids": [],
	"recovered_fragment_ids": [],
	"expedition_clear_count": 0,
	"last_ending_id": "",
}

var encountered_boss_waves: Array[int] = []
var high_score: int = 0
var control_bindings: Dictionary = {}
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
# Meta-progression state, owned by the MetaProgression autoload and
# persisted here alongside the high score.
var salvage: int = 0
## Unlock state: item id -> owned level (absent key = locked).
var unlock_levels: Dictionary = {}
var selected_ship: String = "ship_swallowtail"
var active_modifiers: Array[String] = []
## Stockpiled try-again stocks from the Hangar (consumed at next run start).
var consumable_stocks: int = 0
## Whether a pre-loaded drop pod is armed for the next run.
var consumable_powerup: bool = false
## First-clear milestone waves already awarded.
var claimed_milestones: Array[int] = []
var stat_total_runs: int = 0
var stat_total_kills: int = 0
var stat_best_wave: int = 0
## First-run onboarding state. Kept in the save so the player sees Flight
## School once, but can reopen it from the main menu at any time.
var has_seen_flight_school: bool = false
## Durable campaign-only state. Current route, wave, score, upgrades, and
## active entities are deliberately excluded because runs cannot resume after exit.
var campaign_state: Dictionary = DEFAULT_CAMPAIGN_STATE.duplicate(true)
## A newer build's save is preserved read-only until a compatible migration
## exists. This prevents a settings change from replacing buyer progress.
var _save_read_only_due_to_future_version := false
var _legacy_preferences_pending := false
var _window_layout := WindowLayout.new()
var _progress_store := JsonStore.new(SAVE_PATH, SAVE_VERSION)
var _preferences_store := JsonStore.new(PREFERENCES_PATH, PREFERENCES_VERSION)

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
	settings[key] = _normalize_setting(key, value)
	_apply_audio_settings()
	_apply_control_scheme()
	_apply_display_settings()
	_save_preferences()
	settings_changed.emit()

## Records a new high score if it exceeds the current record, then
## persists it to disk.
func record_high_score(value: int) -> void:
	if value <= high_score:
		return
	high_score = value
	_save_data()

func mark_flight_school_seen() -> void:
	if has_seen_flight_school:
		return
	has_seen_flight_school = true
	_save_data()

## Stores the meta-progression wallet, unlock levels, run-loadout selections,
## consumable stockpile, claimed milestones, and lifetime stats, then persists
## them. Called by the MetaProgression autoload whenever any of these change.
func save_meta(state: Dictionary) -> void:
	salvage = maxi(int(state.get("salvage", salvage)), 0)
	unlock_levels = (state.get("unlock_levels", {}) as Dictionary).duplicate()
	selected_ship = str(state.get("selected_ship", selected_ship))
	active_modifiers = (state.get("active_modifiers", []) as Array[String]).duplicate()
	consumable_stocks = maxi(int(state.get("consumable_stocks", consumable_stocks)), 0)
	consumable_powerup = bool(state.get("consumable_powerup", consumable_powerup))
	claimed_milestones = (state.get("claimed_milestones", []) as Array[int]).duplicate()
	stat_total_runs = maxi(int(state.get("stat_total_runs", stat_total_runs)), 0)
	stat_total_kills = maxi(int(state.get("stat_total_kills", stat_total_kills)), 0)
	stat_best_wave = maxi(int(state.get("stat_best_wave", stat_best_wave)), 0)
	_save_data()


## Stores only the durable v3 campaign fields. ExpeditionManager owns the
## campaign invariants; this boundary rejects malformed primitive values and
## never serializes active-run data supplied by a caller.
func save_campaign(state: Dictionary) -> void:
	campaign_state = _normalize_campaign_state(state)
	_save_data()


func get_campaign_state() -> Dictionary:
	return campaign_state.duplicate(true)

## Loads saved data (high score and settings) from the JSON save file.
## Falls back to defaults if the file doesn't exist, can't be opened,
## or contains malformed data. Only overwrites settings keys that exist
## in DEFAULT_SETTINGS to avoid stale/invalid entries.
func _load_data() -> void:
	var data := _select_load_data()
	_load_preferences(data)
	storage_status_changed.emit()
	if data.is_empty():
		return
	high_score = maxi(int(data.get("high_score", 0)), 0)
	var stored_bosses: Variant = data.get("encountered_boss_waves", [])
	if stored_bosses is Array:
		for entry: Variant in stored_bosses:
			if (entry is int or entry is float) and int(entry) in [5, 10, 15, 20, 25] and not encountered_boss_waves.has(int(entry)):
				encountered_boss_waves.append(int(entry))
	# Meta-progression keys are additive to the v1 schema: absent keys keep
	# the in-memory defaults, and mistyped values are rejected the same way
	# settings are.
	var stored_salvage: Variant = data.get("salvage", salvage)
	if stored_salvage is float or stored_salvage is int:
		salvage = maxi(int(stored_salvage), 0)
	var stored_levels: Variant = data.get("unlock_levels", null)
	if stored_levels is Dictionary:
		unlock_levels.clear()
		for key: Variant in stored_levels:
			var level: Variant = stored_levels[key]
			if key is String and (level is int or level is float) and int(level) >= 1:
				unlock_levels[key] = int(level)
	else:
		# Migration: the pre-tiers schema stored a flat purchased_unlocks
		# array; each entry becomes a level-1 unlock.
		var stored_unlocks: Variant = data.get("purchased_unlocks", null)
		if stored_unlocks is Array:
			unlock_levels.clear()
			for entry: Variant in stored_unlocks:
				if entry is String:
					unlock_levels[entry] = 1
	var stored_ship: Variant = data.get("selected_ship", null)
	if stored_ship is String:
		selected_ship = stored_ship
	var stored_modifiers: Variant = data.get("active_modifiers", null)
	if stored_modifiers is Array:
		active_modifiers.clear()
		for entry: Variant in stored_modifiers:
			if entry is String and not active_modifiers.has(entry):
				active_modifiers.append(entry)
	# Consumables, milestones, and lifetime stats are likewise additive keys.
	var stored_stocks: Variant = data.get("consumable_stocks", null)
	if stored_stocks is int or stored_stocks is float:
		consumable_stocks = maxi(int(stored_stocks), 0)
	var stored_powerup: Variant = data.get("consumable_powerup", null)
	if stored_powerup is bool:
		consumable_powerup = stored_powerup
	var stored_milestones: Variant = data.get("claimed_milestones", null)
	if stored_milestones is Array:
		claimed_milestones.clear()
		for entry: Variant in stored_milestones:
			var wave := int(entry) if entry is int or entry is float else -1
			if wave >= 0 and not claimed_milestones.has(wave):
				claimed_milestones.append(wave)
	for stat_key: String in ["stat_total_runs", "stat_total_kills", "stat_best_wave"]:
		var stored_stat: Variant = data.get(stat_key, null)
		if stored_stat is int or stored_stat is float:
			set(stat_key, maxi(int(stored_stat), 0))
	var stored_flight_school: Variant = data.get("has_seen_flight_school", null)
	if stored_flight_school is bool:
		has_seen_flight_school = stored_flight_school
	var stored_campaign: Variant = data.get("campaign", {})
	campaign_state = _normalize_campaign_state(
		stored_campaign as Dictionary if stored_campaign is Dictionary else {}
	)


func _load_preferences(legacy: Dictionary) -> void:
	var local := _preferences_store.load_data()
	# A local file always wins over a copied/roaming legacy progress file.
	# Corrupt or newer local files must not cause old machine settings to return.
	var local_exists := FileAccess.file_exists(PREFERENCES_PATH) or FileAccess.file_exists(PREFERENCES_PATH + ".bak")
	var source := local if local_exists else legacy
	var stored: Variant = source.get("settings", {})
	if stored is Dictionary:
		for key: String in DEFAULT_SETTINGS:
			if stored.has(key):
				settings[key] = _normalize_setting(key, stored[key])
	var bindings: Variant = source.get("control_bindings", {})
	control_bindings.clear()
	if bindings is Dictionary:
		for action: String in bindings:
			if bindings[action] is Dictionary:
				control_bindings[action] = bindings[action].duplicate(true)
	_legacy_preferences_pending = not local_exists and (legacy.has("settings") or legacy.has("control_bindings"))
	if _legacy_preferences_pending:
		_save_preferences()


func _normalize_setting(key: String, value: Variant) -> Variant:
	var fallback: Variant = DEFAULT_SETTINGS[key]
	if key == "window_size":
		return WindowLayout.normalize_preset(value)
	if key == "graphics_quality":
		return value if value is String and value in ["low", "medium", "high"] else fallback
	if fallback is bool:
		return value if value is bool else fallback
	if fallback is float or fallback is int:
		if not (value is int or value is float) or not is_finite(float(value)):
			return fallback
		match key:
			"menu_text_scale", "hud_scale":
				return clampf(float(value), 1.0, 1.3)
			"aim_deadzone":
				return clampf(float(value), 0.15, 0.6)
			"story_frequency":
				return clampi(int(value), 0, 2)
			"frame_cap":
				return int(value) if value in [0, 30, 60, 120, 144, 240] else fallback
			_:
				return clampf(float(value), 0.0, 1.0)
	return value if typeof(value) == typeof(fallback) else fallback


func _save_preferences() -> bool:
	var saved := _preferences_store.write_data({"version": PREFERENCES_VERSION, "settings": settings, "control_bindings": control_bindings})
	if saved:
		_legacy_preferences_pending = false
	storage_status_changed.emit()
	return saved


## Called after settlement, and again on retry without awarding the run twice.
func save_before_quit() -> bool:
	var preferences_saved := _save_preferences()
	var progress_saved := _save_data()
	return preferences_saved and progress_saved


func get_storage_notice() -> String:
	var notices := PackedStringArray()
	if not _progress_store.last_error.is_empty():
		notices.append("PROGRESS NOT SAVED · " + _progress_store.last_error)
	if not _preferences_store.last_error.is_empty():
		notices.append("SETTINGS NOT SAVED · " + _preferences_store.last_error)
	return "\n".join(notices)


func _normalize_campaign_state(raw_state: Dictionary) -> Dictionary:
	var ending_value: Variant = raw_state.get("last_ending_id", "")
	return {
		"discovered_node_ids": _unique_string_entries(raw_state.get("discovered_node_ids", [])),
		"seen_story_beat_ids": _unique_string_entries(raw_state.get("seen_story_beat_ids", [])),
		"recovered_fragment_ids": _unique_string_entries(raw_state.get("recovered_fragment_ids", raw_state.get("seen_story_beat_ids", []))),
		"expedition_clear_count": _non_negative_integer(
			raw_state.get("expedition_clear_count", 0)
		),
		"last_ending_id": str(ending_value) if ending_value is String else "",
	}


func _unique_string_entries(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for entry: Variant in value:
		if entry is String and not result.has(entry):
			result.append(entry)
	return result


func _non_negative_integer(value: Variant) -> int:
	return maxi(int(value), 0) if value is int or value is float else 0


func _select_load_data() -> Dictionary:
	var data := _progress_store.load_data()
	_save_read_only_due_to_future_version = _progress_store.read_only
	return data


func _save_data() -> bool:
	if _save_read_only_due_to_future_version:
		push_warning("Save remains read-only because it was created by a newer build.")
		return false
	var payload := {
		"version": SAVE_VERSION,
		"encountered_boss_waves": encountered_boss_waves,
		"high_score": high_score,
		"salvage": salvage,
		"unlock_levels": unlock_levels,
		"selected_ship": selected_ship,
		"active_modifiers": active_modifiers,
		"consumable_stocks": consumable_stocks,
		"consumable_powerup": consumable_powerup,
		"claimed_milestones": claimed_milestones,
		"stat_total_runs": stat_total_runs,
		"stat_total_kills": stat_total_kills,
		"stat_best_wave": stat_best_wave,
		"has_seen_flight_school": has_seen_flight_school,
		"campaign": campaign_state,
	}
	# Migrate local preferences successfully before dropping legacy copies from
	# progression. A failed local write leaves the old progress file untouched.
	if _legacy_preferences_pending and not _save_preferences():
		_progress_store.last_error = "Local settings must be saved before older progress can be upgraded. Check free disk space and folder permissions."
		storage_status_changed.emit()
		return false
	var saved := _progress_store.write_data(payload)
	_save_read_only_due_to_future_version = _progress_store.read_only
	storage_status_changed.emit()
	return saved

## Applies the current master_volume and music_volume settings to their
## audio buses. Mutes a bus when its volume is effectively zero, otherwise
## converts the linear 0–1 value to decibels.
func _apply_audio_settings() -> void:
	_apply_bus_volume("Master", float(settings.get("master_volume", 0.8)))
	_apply_bus_volume("Music", float(settings.get("music_volume", 0.8)))
	_apply_bus_volume("SFX", float(settings.get("sfx_volume", 1.0)))
	_apply_bus_volume("UI", float(settings.get("ui_volume", 0.8)))

func _apply_bus_volume(bus_name: String, raw_volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var volume := clampf(raw_volume, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, volume <= 0.001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(volume, 0.001)))

## Applies window size/fullscreen only when those preferences actually change.
func _apply_display_settings() -> void:
	Engine.max_fps = int(get_setting("frame_cap", 0))
	var quality := str(get_setting("graphics_quality", "high"))
	get_tree().root.scaling_3d_scale = 0.75 if quality == "low" else 1.0
	get_tree().root.msaa_3d = {"low": Viewport.MSAA_DISABLED, "medium": Viewport.MSAA_2X, "high": Viewport.MSAA_4X}[quality]
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(get_setting("vsync", true)) else DisplayServer.VSYNC_DISABLED)
	_window_layout.apply(
		get_tree().root,
		bool(settings.get("fullscreen", false)),
		settings.get("window_size", WindowLayout.DEFAULT_PRESET)
	)

## Applies the persisted control scheme to the global InputMap.
## Default: Space shoots, Shift boosts. Alt: left mouse button shoots,
## Space boosts. The swap is strict — Space never does both at once.
func _apply_control_scheme() -> void:
	var bindings := get_node_or_null("/root/InputBindings")
	if bindings != null and bindings.is_node_ready():
		bindings.apply_bindings()
		return
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


func record_boss_encounter(wave: int) -> void:
	if wave not in [5, 10, 15, 20, 25] or encountered_boss_waves.has(wave):
		return
	encountered_boss_waves.append(wave)
	_save_data()


func save_control_bindings(bindings: Dictionary) -> void:
	control_bindings = bindings.duplicate(true)
	_save_preferences()
