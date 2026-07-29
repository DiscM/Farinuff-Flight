extends Node
## Headless regression coverage for the SaveManager and ObjectPool autoloads.
##
## Run with:
## godot --headless --path . res://tests/autoload_smoke.tscn
## (Run the .tscn wrapper, not --script: --script mode skips the autoloads
## these tests depend on and never exits.)

const BULLET_SCENE := preload("res://entities/bullets/bullet.tscn")

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_object_pool()
	await _check_save_manager()

	if _failures.is_empty():
		print("PASS: autoload smoke tests")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


# --- ObjectPool ---

func _check_object_pool() -> void:
	var holder := Node.new()
	add_child(holder)

	var first := ObjectPool.acquire(BULLET_SCENE, holder)
	_expect(first != null, "Pool acquire must return a node for an empty bucket")
	_expect(first.get_parent() == holder, "Acquired node must be parented to the given parent")

	ObjectPool.release(first)
	_expect(first.get_parent() == ObjectPool, "Released node must be reparented to the pool")

	var second := ObjectPool.acquire(BULLET_SCENE, holder)
	_expect(second == first, "Second acquire must reuse the released instance")

	# Double release must not corrupt the bucket
	ObjectPool.release(second)
	ObjectPool.release(second)
	var third := ObjectPool.acquire(BULLET_SCENE, holder)
	_expect(third == second, "Double release must not duplicate the pooled instance")
	ObjectPool.release(third)

	# Releasing a node with no pool key must fall back to queue_free
	var stray := Node2D.new()
	holder.add_child(stray)
	ObjectPool.release(stray)
	_expect(stray.is_queued_for_deletion(), "Non-pooled release must queue_free the node")

	# Idle cap: releasing more than the cap frees the overflow instead of pooling it
	var extra: Array[Node] = []
	for i in range(ObjectPool.MAX_IDLE_PER_SCENE + 2):
		extra.append(ObjectPool.acquire(BULLET_SCENE, holder))
	for node in extra:
		ObjectPool.release(node)
	var pooled_count := 0
	for child in ObjectPool.get_children():
		if child is Area2D:
			pooled_count += 1
	_expect(pooled_count <= ObjectPool.MAX_IDLE_PER_SCENE, "Idle pool must respect MAX_IDLE_PER_SCENE")

	holder.queue_free()


# --- SaveManager ---

func _check_save_manager() -> void:
	var save_path: String = SaveManager.SAVE_PATH
	var had_save := FileAccess.file_exists(save_path)
	var original_bytes: PackedByteArray = []
	if had_save:
		original_bytes = FileAccess.get_file_as_bytes(save_path)
	var original_settings: Dictionary = SaveManager.settings.duplicate(true)
	var original_high_score: int = SaveManager.high_score

	# Unknown keys are ignored by update_setting
	SaveManager.update_setting("not_a_real_key", 123)
	_expect(not SaveManager.settings.has("not_a_real_key"), "update_setting must ignore unknown keys")

	# Malformed JSON keeps current in-memory state
	_write_save("{not valid json")
	SaveManager._load_data()
	_expect(
		bool(SaveManager.settings.get("screen_shake")) == bool(original_settings.get("screen_shake")),
		"Malformed save must not corrupt in-memory settings"
	)

	# Hand-edited type mismatch: "screen_shake": "false" (string) must be
	# rejected, not coerced to true
	_write_save('{"version": 1, "high_score": 500, "settings": {"screen_shake": "false", "music_volume": 0.3}}')
	SaveManager._load_data()
	_expect(
		bool(SaveManager.settings.get("screen_shake")) == bool(SaveManager.DEFAULT_SETTINGS.get("screen_shake")),
		"String-typed boolean must be rejected in favor of the default"
	)
	_expect(SaveManager.high_score == 500, "Valid high_score must load from the save file")
	_expect(
		is_equal_approx(float(SaveManager.settings.get("music_volume")), 0.3),
		"Valid music_volume must load from the save file"
	)

	# Pre-versioning save (no version key) is treated as the current schema
	_write_save('{"high_score": 700, "settings": {}}')
	SaveManager._load_data()
	_expect(SaveManager.high_score == 700, "Save without a version key must still load")

	# Mismatched explicit version is rejected
	_write_save('{"version": 999, "high_score": 1, "settings": {}}')
	SaveManager.high_score = 42
	SaveManager._load_data()
	_expect(SaveManager.high_score == 42, "Mismatched save version must be rejected")

	# Restore the player's real save data and in-memory state
	if had_save:
		var file := FileAccess.open(save_path, FileAccess.WRITE)
		file.store_buffer(original_bytes)
		file.close()
	else:
		DirAccess.remove_absolute(save_path)
	SaveManager.settings = original_settings
	SaveManager.high_score = original_high_score
	SaveManager._apply_audio_settings()
	SaveManager._apply_control_scheme()
	await get_tree().process_frame


func _write_save(content: String) -> void:
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
