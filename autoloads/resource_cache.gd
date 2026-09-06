extends Node
## Bounded cache for the two root scenes that are crossed repeatedly.
##
## ResourceLoader already caches individual resources, but every transition
## still has to resolve and instantiate its PackedScene. Keeping only these
## explicit root scenes lets menus prime the next transition without turning
## this autoload into an unbounded resource registry.

const MAIN_MENU_PATH := "res://ui/main_menu.tscn"
const NATIVE_RUN_PATH := "res://scenes/native_3d_run.tscn"
const CACHEABLE_SCENES: PackedStringArray = [MAIN_MENU_PATH, NATIVE_RUN_PATH]
const MAX_CACHED_SCENES := 2
const MAX_PENDING_LOADS := 2

var _packed_scenes: Dictionary = {}
var _pending_paths: Dictionary = {}
var _last_errors: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func _process(_delta: float) -> void:
	# Menus are not the only callers that can prime a scene. Polling here keeps
	# completed requests captured even when a benchmark or another scene exits
	# before it asks for the resource.
	for path in _pending_paths.keys():
		_poll_scene(path)
	if _pending_paths.is_empty():
		set_process(false)


## Starts a background load for an approved root scene. Calling this repeatedly
## is cheap: ready and already-pending paths are not requested again.
func prime_scene(path: String) -> bool:
	if not is_cacheable(path):
		return false
	if _packed_scenes.has(path):
		return true
	if _pending_paths.has(path):
		return true
	if _pending_paths.size() >= MAX_PENDING_LOADS:
		return false

	# A request may have been started by a transition before this autoload saw
	# it. Adopt that request instead of issuing a duplicate load.
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(path, progress)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		return _capture_threaded_scene(path)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_pending_paths[path] = true
		set_process(true)
		return true

	var request_error := ResourceLoader.load_threaded_request(path, "PackedScene", true)
	if request_error != OK and request_error != ERR_BUSY:
		_last_errors[path] = request_error
		return false
	_pending_paths[path] = true
	set_process(true)
	return true


## Returns a cached scene once ready. A request that is still loading remains
## asynchronous; callers can poll or await wait_for_scene instead of blocking.
func get_scene(path: String) -> PackedScene:
	if not is_cacheable(path):
		return null
	if _packed_scenes.has(path):
		return _packed_scenes[path] as PackedScene

	var status := _poll_scene(path)
	if _packed_scenes.has(path):
		return _packed_scenes[path] as PackedScene
	# Never turn an in-flight request into a synchronous load. That defeats the
	# point of priming and can freeze the transition on slower machines.
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return null
	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		return null
	return null


## Waits while a primed scene is loading, yielding one frame at a time so the
## caller remains responsive. ResourceLoader's terminal failure states end the
## wait without converting an in-flight request into a blocking load.
func wait_for_scene(path: String) -> PackedScene:
	if not is_cacheable(path):
		return null
	prime_scene(path)
	while true:
		var scene := get_scene(path)
		if scene != null:
			return scene
		if is_scene_failed(path):
			return null
		await get_tree().process_frame
	return null


func is_cacheable(path: String) -> bool:
	return CACHEABLE_SCENES.has(path)


func is_scene_ready(path: String) -> bool:
	return get_scene(path) != null


func is_scene_loading(path: String) -> bool:
	if _packed_scenes.has(path):
		return false
	if _pending_paths.has(path):
		_poll_scene(path)
		return _pending_paths.has(path)
	var progress: Array = []
	return ResourceLoader.load_threaded_get_status(path, progress) == ResourceLoader.THREAD_LOAD_IN_PROGRESS


func is_scene_failed(path: String) -> bool:
	if _packed_scenes.has(path) or _pending_paths.has(path):
		return false
	if _last_errors.has(path):
		return true
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(path, progress)
	return status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE


func get_scene_progress(path: String) -> float:
	if _packed_scenes.has(path):
		return 1.0
	var progress: Array = []
	var status := _poll_scene(path, progress)
	if _packed_scenes.has(path) or status == ResourceLoader.THREAD_LOAD_LOADED:
		return 1.0
	if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS or progress.is_empty():
		return 0.0
	return clampf(float(progress[0]), 0.0, 0.99)


func get_cached_scene_count() -> int:
	return _packed_scenes.size()


func get_pending_scene_count() -> int:
	return _pending_paths.size()


func _poll_scene(path: String, progress: Array = []) -> int:
	if _packed_scenes.has(path):
		return ResourceLoader.THREAD_LOAD_LOADED
	if not is_cacheable(path):
		return ResourceLoader.THREAD_LOAD_INVALID_RESOURCE

	var status := ResourceLoader.load_threaded_get_status(path, progress)
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			_pending_paths.erase(path)
			_capture_threaded_scene(path)
		ResourceLoader.THREAD_LOAD_FAILED:
			_pending_paths.erase(path)
			_last_errors[path] = status
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_pending_paths.erase(path)
	return status


func _capture_threaded_scene(path: String) -> bool:
	var scene := ResourceLoader.load_threaded_get(path) as PackedScene
	if scene == null:
		_last_errors[path] = ERR_CANT_ACQUIRE_RESOURCE
		return false
	_store_scene(path, scene)
	_pending_paths.erase(path)
	_last_errors.erase(path)
	return true


func _store_scene(path: String, scene: PackedScene) -> void:
	if not is_cacheable(path) or scene == null:
		return
	if not _packed_scenes.has(path) and _packed_scenes.size() >= MAX_CACHED_SCENES:
		return
	_packed_scenes[path] = scene
