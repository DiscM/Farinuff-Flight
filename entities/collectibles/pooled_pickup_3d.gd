extends Area3D
class_name PooledPickup3D
## Shared pickup movement, magnet attraction, contact collection, and deferred
## pool return. Variants own their value, visuals, and collection side effects.

signal collected(value: int, combat_position: Vector3)
signal returned_to_pool(pickup: Area3D)

const PhysicsLayers := preload("res://systems/native_3d_physics_layers.gd")
const FlightSpace := preload("res://systems/flight_space_3d.gd")

@export_range(0.0, 500.0, 0.1) var drift_speed_pixels: float = 40.0
@export_range(0.0, 128.0, 0.1) var bob_amplitude_pixels: float = 24.0
@export_range(0.0, 12.0, 0.1) var bob_frequency: float = 3.0
@export_range(1.0, 60.0, 0.5) var lifetime_seconds: float = 20.0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visuals: Node3D = $Visuals

var is_active := false
var remaining_lifetime := 0.0
var _return_pending := false
var _idle_parent: Node3D
var _flight_space: FlightSpace
var _bounds := Rect2()
var _screen_direction := Vector2.DOWN
var _bob_time := 0.0
var _pickup_group: StringName
var _requires_idle_parent := false


func _ready() -> void:
	set_physics_process(false)
	area_entered.connect(_on_area_entered)


func configure_pool(idle_parent: Node3D) -> void:
	_idle_parent = idle_parent


## Render the low-poly pickup under a transition cover without arming it.
func prepare_visual_warmup() -> void:
	transform = Transform3D.IDENTITY
	visible = true


## Reuses the orb with a fresh value, drift heading, and camera-derived bounds.
## The direction is supplied in the native Combat Plane, but the frozen
## behavior is evaluated in screen-equivalent pixels before being projected.
func pool_activate(
	flight_space: FlightSpace,
	spawn_position: Vector3,
	value: int,
	drift_direction: Vector3,
	combat_bounds: Rect2
) -> bool:
	if flight_space == null or flight_space.configuration == null or (_requires_idle_parent and _idle_parent == null):
		return false
	_flight_space = flight_space
	_bounds = combat_bounds
	var screen_direction := _flight_space.combat_motion_to_screen(drift_direction).normalized()
	_screen_direction = screen_direction if not screen_direction.is_zero_approx() else Vector2.DOWN
	_bob_time = 0.0
	remaining_lifetime = lifetime_seconds
	_return_pending = false
	is_active = true
	global_position = Vector3(spawn_position.x, 0.0, spawn_position.z)
	transform.basis = Basis.IDENTITY
	_activate_visuals(value)
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)
	add_to_group(_pickup_group)
	collision_shape.disabled = false
	collision_layer = PhysicsLayers.PICKUP
	collision_mask = PhysicsLayers.PICKUP_MASK
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
	_bob_time += delta
	var bob_motion := _screen_direction.orthogonal() * sin(_bob_time * bob_frequency) * bob_amplitude_pixels
	var screen_motion := _screen_direction * drift_speed_pixels + bob_motion
	global_position += _flight_space.screen_motion_to_combat(screen_motion * delta)
	global_position.y = 0.0
	_advance_visuals(delta)
	if not _bounds.has_point(Vector2(global_position.x, global_position.z)):
		despawn()


## Moves toward a native Player Craft when the Magnet power-up is active.
func magnet_pull_to(target_position: Vector3, delta: float, pull_speed_pixels: float) -> void:
	if not is_active or _flight_space == null:
		return
	var screen_offset := _flight_space.combat_motion_to_screen(target_position - global_position)
	if screen_offset.is_zero_approx():
		return
	var screen_direction := screen_offset.normalized()
	global_position += _flight_space.screen_motion_to_combat(screen_direction * pull_speed_pixels * delta)
	global_position.y = 0.0


func _on_area_entered(area: Area3D) -> void:
	if not is_active or _return_pending or not GameManager.is_game_active:
		return
	if area.is_in_group(&"player_craft"):
		_collect()


func _collect() -> void:
	if not is_active or _return_pending:
		return
	var combat_position := global_position
	combat_position.y = 0.0
	collected.emit(_collection_value(), combat_position)
	_after_collection(combat_position)
	despawn()


## Returns the orb to the scene-owned pool after disabling collision and motion.
func despawn() -> void:
	if _return_pending or get_parent() == _idle_parent:
		return
	is_active = false
	_return_pending = true
	visible = false
	set_physics_process(false)
	remove_from_group(_pickup_group)
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
	_bob_time = 0.0
	_flight_space = null
	_bounds = Rect2()
	_screen_direction = Vector2.DOWN
	_reset_visuals()
	transform = Transform3D.IDENTITY
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	_return_pending = false
	ObjectPool.release(self, _idle_parent)
	returned_to_pool.emit(self)


func _activate_visuals(_value: int) -> void:
	pass


func _advance_visuals(_delta: float) -> void:
	pass


func _collection_value() -> int:
	return 0


func _after_collection(_position: Vector3) -> void:
	pass


func _reset_visuals() -> void:
	pass
