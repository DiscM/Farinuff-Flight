extends RefCounted
## Restore all on-disk player files after a save-writing scene, including the
## machine-local preferences introduced by schema 7.
var _files: Dictionary = {}

func _init() -> void:
	for base: String in [SaveManager.SAVE_PATH, SaveManager.PREFERENCES_PATH]:
		for suffix: String in ["", ".bak", ".tmp"]:
			var path := base + suffix
			_files[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null

func restore() -> void:
	for path: String in _files:
		if _files[path] != null:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(_files[path])
			file.close()
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
