extends Area3D
class_name SeekerFragment3D
## Pooled native Apex death fragment. It homes toward the Player Craft in
## screen-equivalent space and remains a hostile ordnance hitbox.

signal returned_to_pool(fragment: SeekerFragment3D)

const PhysicsLayers := preload("res://systems/native_3d_physics_layers.gd")
const FlightSpace := preload("res://systems/flight_space_3d.gd")

@export_range(1.0, 1000.0, 1.0) var speed_pixels: float = 190.0
@export_range(0.1, 10.0, 0.1) var lifetime_seconds: float = 2.5
@export_range(0.1, 8.0, 0.1) var turn_rate: float = 1.8

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visuals: Node3D = $Visuals

var is_active := false
var remaining_lifetime := 0.0
var _return_pending := false
var _idle_parent: Node3D
var _flight_space: FlightSpace
var _bounds := Rect2()
var _screen_direction := Vector2.DOWN


func _ready() -> void:
	set_physics_process(false)
	area_entered.connect(_on_area_entered)


func configure_pool(idle_parent: Node3D) -> void:
	_idle_parent = idle_parent


func prepare_visual_warmup() -> void:
	transform = Transform3D.IDENTITY
	visible = true


func pool_activate(
	flight_space: FlightSpace,
	spawn_position: Vector3,
	initial_direction: Vector3,
	combat_bounds: Rect2
) -> bool:
	if flight_space == null or flight_space.configuration == null or _idle_parent == null:
		return false
	_flight_space = flight_space
	_bounds = combat_bounds
	_screen_direction = _flight_space.combat_motion_to_screen(initial_direction).normalized()
	if _screen_direction.is_zero_approx():
		_screen_direction = Vector2.DOWN
	remaining_lifetime = lifetime_seconds
	_return_pending = false
	is_active = true
	global_position = Vector3(spawn_position.x, 0.0, spawn_position.z)
	rotation.y = atan2(-_screen_direction.x, -_screen_direction.y)
	visuals.scale = Vector3.ONE
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)
	add_to_group(&"native_3d_fragments")
	collision_shape.disabled = false
	collision_layer = PhysicsLayers.HOSTILE_ORDNANCE
	collision_mask = PhysicsLayers.HOSTILE_ORDNANCE_MASK
	monitoring = true
	monitorable = true
	force_update_transform()
	return true


func _physics_process(delta: float) -> void:
	if not is_active or not GameManager.is_game_active:
		return
	remaining_lifetime -= delta
	if remaining_lifetime <= 0.0:
		despawn()
		return
	var player := get_tree().get_first_node_in_group(&"player_craft") as Node3D
	if player != null:
		var desired := _flight_space.combat_motion_to_screen(player.global_position - global_position).normalized()
		if not desired.is_zero_approx():
			_screen_direction = _screen_direction.rotated(
				clampf(_screen_direction.angle_to(desired), -turn_rate * delta, turn_rate * delta)
			).normalized()
	rotation.y = atan2(-_screen_direction.x, -_screen_direction.y)
	global_position += _flight_space.screen_motion_to_combat(_screen_direction * speed_pixels * delta)
	global_position.y = 0.0
	if not _bounds.has_point(Vector2(global_position.x, global_position.z)):
		despawn()


func take_damage(_amount: int) -> void:
	despawn()


func clear_ordnance() -> void:
	despawn()


func despawn() -> void:
	if _return_pending or get_parent() == _idle_parent:
		return
	is_active = false
	_return_pending = true
	visible = false
	set_physics_process(false)
	remove_from_group(&"native_3d_fragments")
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	collision_shape.set_deferred("disabled", true)
	call_deferred("_finish_return")


func _finish_return() -> void:
	collision_shape.disabled = true
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	remaining_lifetime = 0.0
	_flight_space = null
	_bounds = Rect2()
	_screen_direction = Vector2.DOWN
	visuals.transform = Transform3D.IDENTITY
	transform = Transform3D.IDENTITY
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	_return_pending = false
	ObjectPool.release(self, _idle_parent)
	returned_to_pool.emit(self)


func _on_area_entered(area: Area3D) -> void:
	if is_active and area.is_in_group(&"player_craft"):
		despawn()
