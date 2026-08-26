extends Area3D
class_name Player3D
## Native Player Craft wrapper. Gameplay behavior is added in later slices;
## this scene owns the stable visual, hitbox, attachment, and socket contract.

const PhysicsLayers := preload("res://systems/native_3d_physics_layers.gd")

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visuals: Node3D = $Visuals
@onready var attachments: Node3D = $Attachments
@onready var sockets: Node3D = $Attachments/Sockets

var _socket_names: Array[StringName] = []


func _init() -> void:
	collision_layer = PhysicsLayers.PLAYER_CRAFT
	collision_mask = PhysicsLayers.PLAYER_CRAFT_MASK


func _ready() -> void:
	_cache_socket_names()
	set_combat_position(global_position)


func set_combat_position(combat_position: Vector3) -> void:
	global_position = Vector3(combat_position.x, 0.0, combat_position.z)


func get_combat_position() -> Vector3:
	return Vector3(global_position.x, 0.0, global_position.z)


func get_socket(socket_name: StringName) -> Marker3D:
	if not _socket_names.has(socket_name):
		return null
	return sockets.get_node_or_null(NodePath(String(socket_name))) as Marker3D


func get_socket_names() -> Array[StringName]:
	return _socket_names.duplicate()


func _cache_socket_names() -> void:
	_socket_names.clear()
	for child in sockets.get_children():
		if not (child is Marker3D):
			push_error("Player3D socket container only accepts Marker3D children: %s" % child.name)
			continue
		_socket_names.append(child.name)
	if _socket_names.is_empty():
		push_error("Player3D requires at least one Marker3D socket")
