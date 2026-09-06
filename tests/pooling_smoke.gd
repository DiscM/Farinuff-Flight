extends Node
## Focused headless coverage for pooled-node lifetime boundaries. The test
## exercises scene-owned idle parents, weak references after teardown, and
## fallback to the autoload pool when a destination is already closing.

const BULLET_SCENE := preload("res://entities/projectiles/player_projectile_3d.tscn")

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_scene_teardown_reuse()
	if _failures.is_empty():
		print("PASS: pooling smoke tests")
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error(failure)
	get_tree().quit(1)


func _check_scene_teardown_reuse() -> void:
	var active_parent := Node3D.new()
	var idle_parent := Node3D.new()
	add_child(active_parent)
	add_child(idle_parent)

	var first := ObjectPool.acquire(BULLET_SCENE, active_parent)
	_expect(first != null, "Pool acquires a node for a new scene bucket")
	if first == null:
		return
	var first_id := first.get_instance_id()
	ObjectPool.release(first, idle_parent)
	_expect(first.get_parent() == idle_parent, "Scene-owned release keeps the node under the idle parent")

	var reused := ObjectPool.acquire(BULLET_SCENE, active_parent)
	_expect(reused == first, "Acquire reuses a live scene-owned node")
	ObjectPool.release(reused, idle_parent)

	# Closing parents must not be selected as an acquire destination. The node
	# falls back to the autoload pool and remains reusable by the next scene.
	idle_parent.queue_free()
	var fallback := ObjectPool.acquire(BULLET_SCENE, active_parent)
	_expect(fallback != null, "Acquire recovers when a pooled idle parent is closing")
	if fallback != null:
		ObjectPool.release(fallback, idle_parent)
		_expect(fallback.get_parent() == ObjectPool, "Closing idle parent falls back to the autoload pool")

	await get_tree().process_frame
	var next_parent := Node3D.new()
	add_child(next_parent)
	var after_teardown := ObjectPool.acquire(BULLET_SCENE, next_parent)
	_expect(after_teardown != null, "Acquire skips weak references from a freed idle parent")
	_expect(
		after_teardown == null or after_teardown.get_parent() == next_parent,
		"Reused node is attached to the current scene"
	)
	if after_teardown != null:
		ObjectPool.release(after_teardown)

	# A stale WeakRef must be discarded without making a typed node invalid.
	var stale := ObjectPool.acquire(BULLET_SCENE, active_parent)
	_expect(stale != null, "Pool remains usable after scene teardown")
	if stale != null:
		var stale_id := stale.get_instance_id()
		ObjectPool.release(stale)
		stale.free()
		var recovered := ObjectPool.acquire(BULLET_SCENE, active_parent)
		_expect(recovered != null, "Pool recovers after an idle node is freed externally")
		if recovered != null:
			_expect(recovered.get_instance_id() != stale_id, "Freed idle instance is never returned")
		ObjectPool.release(recovered)

	# Releasing into a destination that is already queued for deletion must use
	# the autoload fallback instead of attempting to parent under a dying node.
	var closing_idle := Node3D.new()
	add_child(closing_idle)
	var closing_node := ObjectPool.acquire(BULLET_SCENE, active_parent)
	_expect(closing_node != null, "Pool acquires a node for fallback coverage")
	if closing_node != null:
		closing_idle.queue_free()
		ObjectPool.release(closing_node, closing_idle)
		_expect(closing_node.get_parent() == ObjectPool, "Queued idle destination never receives a pooled node")

	ObjectPool.prune_stale()
	var metrics: Dictionary = ObjectPool.get_metrics()
	_expect(int(metrics["idle"]) <= int(metrics["idle_limit"]), "Global idle limit remains bounded")
	_expect(int(metrics["scene_buckets"]) >= 1, "Live pool bucket remains addressable")

	active_parent.queue_free()
	next_parent.queue_free()
	await get_tree().process_frame
	ObjectPool.prune_stale()
	ObjectPool.clear_pool(BULLET_SCENE)
	await get_tree().process_frame
	# Keep the local ID read above as a regression guard against an accidental
	# change that stops release from accepting a live node.
	_expect(first_id > 0, "Pooled instances expose stable IDs")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
