extends Node

const POOL_KEY_META := "_pool_key"
const POOL_IDLE_META := "_pool_idle"
## Maximum idle nodes retained per scene. Boss-wave spikes would otherwise
## keep hundreds of idle nodes alive for the rest of the run.
const MAX_IDLE_PER_SCENE := 512
## Keep a runaway collection of dynamically loaded scenes from retaining an
## unbounded number of idle nodes. The per-scene limit still protects a single
## burst while this global limit bounds the autoload's retained memory.
const MAX_IDLE_TOTAL := 2048

var _available: Dictionary = {}
var _idle_count := 0

## Returns an active instance of the given scene, reusing a cached node when
## one is available. The caller is responsible for configuring the node state.
func acquire(scene: PackedScene, parent: Node) -> Node:
	if scene == null or not _is_usable_parent(parent):
		return null
	var key := scene.resource_path
	var node := _take_from_pool(key)
	if node == null:
		node = scene.instantiate()
		if node == null:
			return null
		node.set_meta(POOL_KEY_META, key)
	elif node.get_parent() != null:
		var previous_parent := node.get_parent()
		if not _is_usable_parent(previous_parent):
			node.queue_free()
			node = scene.instantiate()
			if node == null:
				return null
			node.set_meta(POOL_KEY_META, key)
		else:
			previous_parent.remove_child(node)
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return null
	node.set_meta(POOL_IDLE_META, false)
	parent.add_child(node)
	if node.get_parent() != parent:
		node.queue_free()
		return null
	return node

## Returns a node to the pool immediately. A scene-owned idle parent can keep
## pooled nodes within that scene's lifetime; the default remains this autoload.
func release(node: Node, idle_parent: Node = null) -> void:
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	if node.get_meta(POOL_IDLE_META, false):
		return
	var key := ""
	if node.has_meta(POOL_KEY_META):
		key = String(node.get_meta(POOL_KEY_META))
	if key.is_empty():
		node.queue_free()
		return
	var parent := node.get_parent()
	if parent != null:
		if not _is_usable_parent(parent):
			node.queue_free()
			return
		parent.remove_child(node)
	var bucket: Array = _available.get(key, [])
	# A full bucket can contain weak references whose scene-owned parent was
	# already torn down. Compact only on pressure so the common release path
	# stays allocation-free.
	if bucket.size() >= MAX_IDLE_PER_SCENE:
		bucket = _compact_bucket(bucket)
		_store_bucket(key, bucket)
	if _idle_count >= MAX_IDLE_TOTAL:
		prune_stale()
		bucket = _available.get(key, bucket)
	if bucket.size() >= MAX_IDLE_PER_SCENE or _idle_count >= MAX_IDLE_TOTAL:
		_store_bucket(key, bucket)
		node.queue_free()
		return
	var destination := idle_parent if _is_usable_parent(idle_parent) else self
	if not _is_usable_parent(destination):
		node.queue_free()
		return
	node.set_meta(POOL_IDLE_META, true)
	destination.add_child(node)
	if node.get_parent() != destination:
		node.queue_free()
		return
	bucket.append(weakref(node))
	_idle_count += 1
	_available[key] = bucket

func _take_from_pool(key: String) -> Node:
	if key.is_empty():
		return null
	var bucket: Array = _available.get(key, [])
	while not bucket.is_empty():
		# Weak references make scene teardown safe: a freed pooled node resolves
		# to null instead of becoming an invalid Object value in a typed local.
		var candidate_ref: Variant = bucket.pop_back()
		_idle_count = maxi(0, _idle_count - 1)
		var candidate := _resolve_entry(candidate_ref)
		if candidate != null and not candidate.is_queued_for_deletion():
			_store_bucket(key, bucket)
			return candidate
		if candidate != null:
			candidate.queue_free()
	_store_bucket(key, bucket)
	return null


## Removes dead weak references left behind when a scene-owned idle parent is
## freed. This is intentionally explicit/pressure-triggered instead of a
## per-frame autoload scan.
func prune_stale() -> int:
	var removed := 0
	for key in _available.keys():
		var bucket: Array = _available[key]
		var compact: Array = []
		for entry: Variant in bucket:
			var candidate := _resolve_entry(entry)
			if candidate != null and not candidate.is_queued_for_deletion():
				compact.append(entry)
			else:
				_idle_count = maxi(0, _idle_count - 1)
				removed += 1
		_store_bucket(key, compact)
	return removed


func get_metrics() -> Dictionary:
	return {
		"idle": _idle_count,
		"idle_limit": MAX_IDLE_TOTAL,
		"idle_limit_per_scene": MAX_IDLE_PER_SCENE,
		"scene_buckets": _available.size(),
	}


## Frees cached nodes for one scene, or every scene when no scene is given.
## Scene owners normally release these nodes as part of teardown; this explicit
## hook lets deterministic tests and low-memory transitions drain the cache.
func clear_pool(scene: PackedScene = null) -> int:
	var keys: Array = _available.keys() if scene == null else [scene.resource_path]
	var freed := 0
	for key: String in keys:
		var bucket: Array = _available.get(key, [])
		for entry: Variant in bucket:
			var candidate := _resolve_entry(entry)
			if candidate != null:
				candidate.queue_free()
				freed += 1
		_idle_count = maxi(0, _idle_count - bucket.size())
		_available.erase(key)
	return freed


func _compact_bucket(bucket: Array) -> Array:
	var compact: Array = []
	for entry: Variant in bucket:
		var candidate := _resolve_entry(entry)
		if candidate != null and not candidate.is_queued_for_deletion():
			compact.append(entry)
		else:
			_idle_count = maxi(0, _idle_count - 1)
	return compact


func _resolve_entry(entry: Variant) -> Node:
	var candidate: Variant = entry.get_ref() if entry is WeakRef else entry
	if candidate == null or not is_instance_valid(candidate) or not candidate is Node:
		return null
	return candidate as Node


func _store_bucket(key: String, bucket: Array) -> void:
	if bucket.is_empty():
		_available.erase(key)
	else:
		_available[key] = bucket


func _is_usable_parent(parent: Node) -> bool:
	return parent != null and is_instance_valid(parent) and not parent.is_queued_for_deletion()
