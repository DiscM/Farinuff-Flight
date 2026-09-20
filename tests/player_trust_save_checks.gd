extends RefCounted
## Schema migration and failure recovery through real files and SaveManager.
const Manager := preload("res://autoloads/save_manager.gd")
const Store := preload("res://systems/versioned_json_store.gd")
var _failures: Array[String] = []

func run() -> Array[String]:
	var snapshot := preload("res://tests/save_file_snapshot.gd").new()
	_clear_files()
	var legacy := {
		"version": 6, "high_score": 7200, "salvage": 321,
		"selected_ship": "ship_interceptor", "unlock_levels": {"ship_interceptor": 1},
		"campaign": {"recovered_fragment_ids": ["iron_wake_fragment"], "expedition_clear_count": 2},
		"settings": {"window_size": "compact", "music_volume": 0.35, "hud_scale": 1.3},
		"control_bindings": {"shoot": {"keyboard": [{"kind": "key", "code": KEY_F}]}},
	}
	_write(SaveManager.SAVE_PATH, legacy)
	var original := FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	var manager := Manager.new()
	manager._load_data()
	_expect(FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == original, "Loading legacy progress never rewrites it")
	_expect(manager.salvage == 321 and manager.selected_ship == "ship_interceptor" and manager.campaign_state.expedition_clear_count == 2,
		"Migration retains wallet, hull, and campaign clears")
	_expect(manager.get_setting("window_size") == "compact" and manager.control_bindings.has("shoot"), "Migration retains local settings and remapped controls")
	_expect(FileAccess.file_exists(SaveManager.PREFERENCES_PATH), "Migration writes the local preferences before changing the progress schema")
	manager._save_data()
	var progress: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	_expect(progress.version == 7 and not progress.has("settings") and not progress.has("control_bindings"), "Progress schema contains no device preferences or bindings")
	manager.free()
	manager = Manager.new()
	manager._load_data()
	_expect(manager.high_score == 7200 and manager.salvage == 321 and manager.get_setting("window_size") == "compact", "Reopening migrated files retains progress and preferences")

	# Copying old/cloud progression onto an established machine cannot override
	# its local preferences. Neither can a local setting alter the progress bytes.
	legacy.settings.window_size = "large"
	_write(SaveManager.SAVE_PATH, legacy)
	manager._load_data()
	_expect(manager.get_setting("window_size") == "compact", "Existing local preferences win over copied legacy progress")
	original = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	manager.settings.hud_scale = 1.15
	manager._save_preferences()
	_expect(FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == original, "Changing preferences never rotates or writes progress")
	manager.free()

	# A prior build can read its compatible backup but cannot replace the newer
	# primary. A newer backup is also protected when the primary is corrupt.
	var store := Store.new(SaveManager.SAVE_PATH, 6)
	_write(SaveManager.SAVE_PATH, {"version": 7, "high_score": 9000})
	_write(SaveManager.SAVE_BACKUP_PATH, legacy)
	original = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	_expect(store.load_data().high_score == 7200 and store.read_only, "Rollback offers compatible backup read-only")
	_expect(not store.write_data(legacy) and FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == original, "Rollback preserves the newer primary byte for byte")
	_write(SaveManager.SAVE_BACKUP_PATH, {"version": 99, "high_score": 9000})
	_write_text(SaveManager.SAVE_PATH, "{broken")
	var future_backup := FileAccess.get_file_as_bytes(SaveManager.SAVE_BACKUP_PATH)
	_expect(store.load_data().is_empty() and store.read_only and not store.write_data(legacy), "A newer backup is protected even with a corrupt primary")
	_expect(FileAccess.get_file_as_bytes(SaveManager.SAVE_BACKUP_PATH) == future_backup, "Failed rollback never removes the only newer copy")

	# Settings remain independently writable while progression is read-only.
	manager = Manager.new()
	manager._load_data()
	manager.settings.window_size = "medium"
	manager._save_preferences()
	_expect(not manager._preferences_store.read_only and manager.get_storage_notice().contains("PROGRESS NOT SAVED"), "Progress compatibility failures are visible without blocking local settings")
	manager.free()

	# A missing local primary with a protected newer backup must not block an
	# already-migrated progress store; each store reports its own failure.
	_clear_files()
	_write(SaveManager.SAVE_PATH, {"version": 7, "salvage": 100})
	_write(SaveManager.PREFERENCES_PATH + ".bak", {"version": 99, "settings": {"hud_scale": 1.3}})
	future_backup = FileAccess.get_file_as_bytes(SaveManager.PREFERENCES_PATH + ".bak")
	manager = Manager.new()
	manager._load_data()
	manager.salvage = 250
	_expect(manager._save_data(), "Independent progression saves despite protected local preferences")
	progress = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	_expect(progress.salvage == 250 and not manager._save_preferences(), "Progress changes persist while incompatible preferences remain read-only")
	_expect(FileAccess.get_file_as_bytes(SaveManager.PREFERENCES_PATH + ".bak") == future_backup, "Local version protection preserves the newer backup")
	_expect(manager.get_storage_notice().contains("SETTINGS NOT SAVED") and not manager.get_storage_notice().contains("PROGRESS NOT SAVED"), "Independent store errors identify only the blocked store")
	manager.free()

	_clear_files()
	_write(SaveManager.PREFERENCES_PATH, {"version": 1, "settings": {"hud_scale": 1.3, "vsync": false}})
	var local_store := Store.new(SaveManager.PREFERENCES_PATH, 1)
	local_store.write_data({"version": 1, "settings": {"hud_scale": 1.15}})
	_write_text(SaveManager.PREFERENCES_PATH, "{broken")
	_write_text(SaveManager.PREFERENCES_PATH + ".tmp", "{interrupted")
	manager = Manager.new()
	manager._load_data()
	_expect(is_equal_approx(manager.get_setting("hud_scale"), 1.3) and manager.get_setting("vsync") == false, "Local preferences recover from backup without progress")
	var good_backup := FileAccess.get_file_as_bytes(SaveManager.PREFERENCES_PATH + ".bak")
	manager.settings.hud_scale = 1.15
	manager._save_preferences()
	_expect(FileAccess.get_file_as_bytes(SaveManager.PREFERENCES_PATH + ".bak") == good_backup, "Saving recovered preferences keeps the good backup")
	manager.free()
	manager = Manager.new()
	manager._load_data()
	_expect(is_equal_approx(manager.get_setting("hud_scale"), 1.15), "Recovered preferences survive another reopen")
	manager.free()

	# Failure to migrate preferences cannot erase them from legacy progression.
	_clear_files()
	_write(SaveManager.SAVE_PATH, legacy)
	original = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	DirAccess.make_dir_absolute(SaveManager.PREFERENCES_PATH + ".tmp")
	manager = Manager.new()
	manager._load_data()
	manager._save_data()
	_expect(FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == original and manager.get_storage_notice().contains("PROGRESS NOT SAVED") and manager.get_storage_notice().contains("SETTINGS NOT SAVED"), "A failed local migration preserves legacy progress and identifies both blocked stores")
	DirAccess.remove_absolute(SaveManager.PREFERENCES_PATH + ".tmp")
	manager._save_data()
	_expect(manager.get_storage_notice().is_empty(), "A successful retry clears the storage warning")
	manager.free()

	# Malformed settings are normalized at the load boundary.
	_clear_files()
	_write(SaveManager.PREFERENCES_PATH, {"version": 1, "settings": {"hud_scale": 9, "frame_cap": -1, "graphics_quality": "ultra", "vsync": "false", "music_volume": -20, "toggle_fire": true}})
	manager = Manager.new()
	manager._load_data()
	_expect(manager.get_setting("hud_scale") == 1.3 and manager.get_setting("frame_cap") == 0 and manager.get_setting("graphics_quality") == "high", "Invalid display preferences stay within supported settings")
	_expect(manager.get_setting("vsync") == true and manager.get_setting("music_volume") == 0.0 and manager.get_setting("toggle_fire"), "Typed accessibility/audio preferences normalize safely")
	manager.free()
	_clear_files()
	snapshot.restore()
	return _failures

func _clear_files() -> void:
	for base: String in [SaveManager.SAVE_PATH, SaveManager.PREFERENCES_PATH]:
		for suffix: String in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(base + suffix):
				DirAccess.remove_absolute(base + suffix)

func _write(path: String, data: Dictionary) -> void:
	_write_text(path, JSON.stringify(data))

func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
