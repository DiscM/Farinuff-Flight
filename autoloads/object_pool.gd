extends Node

const POOL_KEY_META := "_pool_key"

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
	parent.add_child(node)
	return node

## Returns a node to the pool on the next idle tick. Nodes without a pool key
## fall back to queue_free so the helper stays safe for non-pooled objects.
func release_deferred(node: Node) -> void:
	if is_instance_valid(node):
		call_deferred("release", node)

## Returns a node to the pool immediately.
func release(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node.get_parent() == self:
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
	add_child(node)
	var bucket: Array = _available.get(key, [])
	bucket.append(node)
	_available[key] = bucket

func _take_from_pool(key: String) -> Node:
	if key.is_empty():
		return null
	var bucket: Array = _available.get(key, [])
	if bucket.is_empty():
		return null
	var node: Node = bucket.pop_back()
	_available[key] = bucket
	return node
