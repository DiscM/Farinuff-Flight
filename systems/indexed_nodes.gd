extends RefCounted
## Dense node registries with constant-time insertion and unordered removal.

static func add(node: Node, nodes: Array, indices: Dictionary) -> void:
	var instance_id := node.get_instance_id()
	if indices.has(instance_id):
		return
	indices[instance_id] = nodes.size()
	nodes.append(node)

static func remove(node: Node, nodes: Array, indices: Dictionary) -> void:
	if node == null:
		return
	var instance_id := node.get_instance_id()
	if not indices.has(instance_id):
		return
	var index := int(indices[instance_id])
	var last_index := nodes.size() - 1
	if index != last_index:
		var last_node: Node = nodes[last_index]
		nodes[index] = last_node
		indices[last_node.get_instance_id()] = index
	nodes.pop_back()
	indices.erase(instance_id)
