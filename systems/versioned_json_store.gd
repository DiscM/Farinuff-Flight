extends RefCounted
## Atomic, version-guarded storage shared by progression and local preferences.
var path: String
var version: int
var read_only := false
var last_error := ""

func _init(file_path: String, supported_version: int) -> void:
	path = file_path
	version = supported_version

func read_candidate(candidate: String) -> Variant:
	if not FileAccess.file_exists(candidate):
		return null
	var file := FileAccess.open(candidate, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else null

func stored_version(data: Variant) -> int:
	if not data is Dictionary:
		return -1
	var value: Variant = data.get("version", 1)
	if not (value is int or value is float) or not is_finite(float(value)):
		return -1
	return int(value) if float(int(value)) == float(value) else -1

func supports(data: Variant) -> bool:
	var saved := stored_version(data)
	return saved >= 1 and saved <= version

func load_data() -> Dictionary:
	last_error = ""
	var primary: Variant = read_candidate(path)
	var backup: Variant = read_candidate(path + ".bak")
	read_only = stored_version(primary) > version or stored_version(backup) > version
	if read_only:
		last_error = "This file belongs to a newer game version. Reopen that version to save changes."
	if supports(primary):
		return primary
	if supports(backup):
		push_warning("Recovered " + path.get_file() + " from its backup.")
		return backup
	# Temporary files are never committed state, even if they contain valid JSON.
	return {}

func write_data(payload: Dictionary) -> bool:
	last_error = ""
	var previous: Variant = read_candidate(path)
	var backup: Variant = read_candidate(path + ".bak")
	# Recheck both files at write time, including when a newer file appeared
	# after startup. Never rotate away the only newer-format copy.
	read_only = stored_version(previous) > version or stored_version(backup) > version
	if read_only:
		return _fail("This file belongs to a newer game version. Reopen that version to save changes.")
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _fail("Could not write the save folder. Check free disk space and folder permissions.")
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return _fail("The save could not be written completely. Check free disk space.")
	if FileAccess.file_exists(path):
		if supports(previous):
			if FileAccess.file_exists(path + ".bak") and DirAccess.remove_absolute(path + ".bak") != OK:
				return _fail("Could not replace the previous backup. Check folder permissions.")
			if DirAccess.rename_absolute(path, path + ".bak") != OK:
				return _fail("Could not preserve the previous save. Check folder permissions.")
		elif DirAccess.remove_absolute(path) != OK:
			return _fail("Could not replace the damaged save. Check folder permissions.")
	if DirAccess.rename_absolute(temporary, path) != OK:
		if not FileAccess.file_exists(path) and FileAccess.file_exists(path + ".bak"):
			DirAccess.rename_absolute(path + ".bak", path)
		return _fail("Could not finish saving. The previous save has been retained.")
	return true

func _fail(message: String) -> bool:
	last_error = message
	push_warning(path.get_file() + ": " + message)
	return false
