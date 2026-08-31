extends Area3D
class_name PlasmaField3D
## Pooled native short-lived area hazard released by a clustered mine.

signal returned_to_pool(field: PlasmaField3D)

const PhysicsLayers := preload("res://systems/native_3d_physics_layers.gd")
const PlayerCraft := preload("res://entities/player/player_3d.gd")

@export_range(0.1, 10.0, 0.1) var lifetime_seconds: float = 2.0

@onready var visuals: Node3D = $Visuals
@onready var outer: MeshInstance3D = $Visuals/Outer
@onready var inner: MeshInstance3D = $Visuals/Inner
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var is_active := false
var remaining_lifetime := 0.0

var _idle_parent: Node3D
var _coordinator: SpecialAttackCoordinator
var _return_pending := false
var _pulse_time := 0.0
var _hit_cooldown := 0.0


func _ready() -> void:
	set_physics_process(false)
	area_entered.connect(_on_area_entered)


func configure_pool(idle_parent: Node3D, shared_coordinator: SpecialAttackCoordinator) -> void:
	_idle_parent = idle_parent
	_coordinator = shared_coordinator


func prepare_visual_warmup() -> void:
	transform = Transform3D.IDENTITY
	visuals.scale = Vector3.ONE
	visible = true


func pool_activate(spawn_position: Vector3) -> bool:
	if _idle_parent == null:
		return false
	global_position = Vector3(spawn_position.x, 0.0, spawn_position.z)
	remaining_lifetime = lifetime_seconds
	_pulse_time = 0.0
	_hit_cooldown = 0.0
	_return_pending = false
	is_active = true
	visuals.scale = Vector3.ONE
	outer.transparency = 0.58
	inner.transparency = 0.38
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)
	add_to_group(&"native_3d_plasma_fields")
	add_to_group(&"native_3d_hazards")
	add_to_group(&"evolved_pressure")
	collision_shape.disabled = false
	collision_layer = PhysicsLayers.HOSTILE_ORDNANCE
	collision_mask = PhysicsLayers.PLAYER_CRAFT
	monitoring = true
	monitorable = true
	force_update_transform()
	return true


func _physics_process(delta: float) -> void:
	if not is_active or not GameManager.is_game_active:
		return
	remaining_lifetime -= delta
	_pulse_time += delta
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	var pulse := (sin(_pulse_time * 9.0) + 1.0) * 0.5
	visuals.scale = Vector3.ONE * lerpf(0.94, 1.08, pulse)
	outer.transparency = lerpf(0.72, 0.42, pulse)
	inner.transparency = lerpf(0.55, 0.22, pulse)
	if remaining_lifetime <= 0.0:
		despawn()


func clear_ordnance() -> void:
	despawn()


func despawn() -> void:
	if _return_pending or get_parent() == _idle_parent:
		return
	is_active = false
	_return_pending = true
	_release_cap()
	visible = false
	set_physics_process(false)
	remove_from_group(&"native_3d_plasma_fields")
	remove_from_group(&"native_3d_hazards")
	remove_from_group(&"evolved_pressure")
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	collision_shape.set_deferred("disabled", true)
	_finish_return.call_deferred()


func _finish_return() -> void:
	collision_shape.disabled = true
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	remaining_lifetime = 0.0
	visuals.scale = Vector3.ONE
	outer.transparency = 0.58
	inner.transparency = 0.38
	transform = Transform3D.IDENTITY
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	_return_pending = false
	ObjectPool.release(self, _idle_parent)
	returned_to_pool.emit(self)


func _release_cap() -> void:
	if _coordinator != null and is_instance_valid(_coordinator):
		_coordinator.release_hazard(&"plasma_field")


func _on_area_entered(area: Area3D) -> void:
	if not is_active or _hit_cooldown > 0.0 or not area.is_in_group(&"player_craft"):
		return
	_hit_cooldown = 0.8
	if area.has_method("receive_damage"):
		area.receive_damage(global_position, PlayerCraft.DamageSource.HOSTILE_ORDNANCE)
