extends Node
## Exercises background loading while paused and resident-resource reuse.
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	get_tree().create_timer(20.0, true).timeout.connect(_timeout)
	_expect(not ResourceCache.prime_scene("res://tests/autoload_smoke.tscn"), "Cache rejects paths outside its allowlist")
	_expect(await ResourceCache.wait_for_scene("res://tests/autoload_smoke.tscn") == null, "Unsupported waits return immediately")
	var run_path: String = ResourceCache.NATIVE_RUN_PATH
	var menu_path: String = ResourceCache.MAIN_MENU_PATH
	get_tree().paused = true
	_expect(ResourceCache.prime_scene(run_path), "Run background load starts")
	_expect(ResourceCache.prime_scene(run_path), "Duplicate request is accepted without another load")
	_expect(ResourceCache.get_pending_scene_count() <= 1, "Duplicate request keeps one pending entry")
	_expect(ResourceCache.prime_scene(menu_path), "Menu background load starts")
	var run_scene: PackedScene = await ResourceCache.wait_for_scene(run_path)
	var menu_scene: PackedScene = await ResourceCache.wait_for_scene(menu_path)
	_expect(run_scene != null and menu_scene != null, "Both resources load while gameplay is paused")
	_expect(get_tree().paused, "Cache does not unpause gameplay")
	_expect(ResourceCache.get_cached_scene_count() == 2, "Exactly two root resources are retained")
	_expect(ResourceCache.get_pending_scene_count() == 0, "Completed requests are drained")
	_expect(ResourceCache.get_scene(run_path) == run_scene, "Retry uses the same PackedScene resource")
	if run_scene != null:
		var first := run_scene.instantiate()
		var second := run_scene.instantiate()
		_expect(first != second, "Retries create distinct gameplay trees")
		first.free()
		second.free()
	await get_tree().process_frame
	_expect(not ResourceCache.is_processing(), "Idle cache stops processing")
	get_tree().paused = false
	if _failures.is_empty():
		print("RESOURCE_CACHE_SMOKE_PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


func _timeout() -> void:
	push_error("RESOURCE_CACHE_SMOKE_FAIL: background load timed out")
	get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
