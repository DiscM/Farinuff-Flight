extends Node

const POOL_KEY_META := "_pool_key"
const POOL_IDLE_META := "_pool_idle"
## Maximum idle nodes retained per scene. Boss-wave spikes would otherwise
## keep hundreds of idle nodes alive for the rest of the run.
const MAX_IDLE_PER_SCENE := 512

var _available: Dictionary = {}

## Returns an active instance of the given scene, reusing a cached node when
## one is available. The caller is responsible for configuring the node state.
func acquire(scene: PackedScene, parent: Node) -> Node:
	if scene == null or parent == null:
		return null
	var key := scene.resource_path
	var node := _take_from_pool(key)
	if node == null:
		node = scene.instantiate()
		node.set_meta(POOL_KEY_META, key)
	elif node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.set_meta(POOL_IDLE_META, false)
	parent.add_child(node)
	return node

## Returns a node to the pool immediately. A scene-owned idle parent can keep
## pooled nodes within that scene's lifetime; the default remains this autoload.
func release(node: Node, idle_parent: Node = null) -> void:
	if not is_instance_valid(node):
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
		parent.remove_child(node)
	var bucket: Array = _available.get(key, [])
	if bucket.size() >= MAX_IDLE_PER_SCENE:
		node.queue_free()
		return
	var destination := idle_parent if is_instance_valid(idle_parent) else self
	node.set_meta(POOL_IDLE_META, true)
	destination.add_child(node)
	bucket.append(weakref(node))
	_available[key] = bucket

func _take_from_pool(key: String) -> Node:
	if key.is_empty():
		return null
	var bucket: Array = _available.get(key, [])
	while not bucket.is_empty():
		# Weak references make scene teardown safe: a freed pooled node resolves
		# to null instead of becoming an invalid Object value in a typed local.
		var candidate_ref: Variant = bucket.pop_back()
		if candidate_ref is WeakRef:
			var candidate: Variant = candidate_ref.get_ref()
			if candidate != null and is_instance_valid(candidate):
				_available[key] = bucket
				return candidate as Node
	_available[key] = bucket
	return null
