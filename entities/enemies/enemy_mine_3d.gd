extends Area3D
class_name EnemyMine3D
## Pooled native hostile mine. The wrapper owns the fuse, contact/boost
## contract, and safe return; the hazard manager resolves its detonation.

signal detonated(combat_position: Vector3, is_cluster: bool, leaves_plasma: bool)
signal returned_to_pool(mine: EnemyMine3D)

const PhysicsLayers := preload("res://systems/native_3d_physics_layers.gd")
const PlayerCraft := preload("res://entities/player/player_3d.gd")
const FlightSpace := preload("res://systems/flight_space_3d.gd")

@export_range(0.1, 10.0, 0.1) var fuse_seconds: float = 2.2
@export_range(0.1, 8.0, 0.1) var visual_spin_speed: float = 1.2

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visuals: Node3D = $Visuals
@onready var core: MeshInstance3D = $Visuals/Core
@onready var telegraph: MeshInstance3D = $Visuals/Telegraph

var is_active := false
var is_cluster := false
var leaves_plasma := false
var remaining_fuse := 0.0

var _idle_parent: Node3D
var _coordinator: SpecialAttackCoordinator
var _flight_space: FlightSpace
var _bounds := Rect2()
var _return_pending := false
var _detonating := false
var _pulse_time := 0.0


func _ready() -> void:
	set_physics_process(false)
	area_entered.connect(_on_area_entered)


func configure_pool(idle_parent: Node3D, shared_coordinator: SpecialAttackCoordinator) -> void:
	_idle_parent = idle_parent
	_coordinator = shared_coordinator


func prepare_visual_warmup() -> void:
	transform = Transform3D.IDENTITY
	visuals.rotation = Vector3.ZERO
	core.scale = Vector3.ONE
	telegraph.scale = Vector3.ONE * 0.25
	telegraph.transparency = 0.35
	visible = true


func pool_activate(
	flight_space: FlightSpace,
	spawn_position: Vector3,
	cluster: bool,
	plasma: bool,
	combat_bounds: Rect2
) -> bool:
	if flight_space == null or flight_space.configuration == null or _idle_parent == null:
		return false
	_flight_space = flight_space
	_bounds = combat_bounds
	is_cluster = cluster
	leaves_plasma = plasma
	remaining_fuse = fuse_seconds
	_pulse_time = 0.0
	_return_pending = false
	_detonating = false
	is_active = true
	global_position = Vector3(spawn_position.x, 0.0, spawn_position.z)
	rotation = Vector3.ZERO
	visuals.rotation = Vector3.ZERO
	core.scale = Vector3.ONE
	telegraph.scale = Vector3.ONE * 0.25
	telegraph.transparency = 0.35
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)
	add_to_group(&"native_3d_mines")
	add_to_group(&"native_3d_hazards")
	add_to_group(&"evolved_pressure")
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
	remaining_fuse -= delta
	_pulse_time += delta
	var progress := clampf(1.0 - remaining_fuse / fuse_seconds, 0.0, 1.0)
	var pulse := (sin(_pulse_time * 12.0) + 1.0) * 0.5
	telegraph.scale = Vector3.ONE * lerpf(0.25, 1.65, progress) * lerpf(0.9, 1.08, pulse)
	telegraph.transparency = lerpf(0.62, 0.08, pulse)
	core.scale = Vector3.ONE * lerpf(1.0, 1.12, pulse)
	visuals.rotation.y += visual_spin_speed * delta
	if remaining_fuse <= 0.0:
		_detonate()


func take_damage(_amount: int) -> void:
	# Player projectiles defuse mines without awarding score or triggering the
	# mine's radial payload.
	despawn()


func clear_ordnance() -> void:
	despawn()


func _detonate() -> void:
	if not is_active or _detonating:
		return
	_detonating = true
	detonated.emit(get_combat_position(), is_cluster, leaves_plasma)
	despawn()


func detonate_for_review() -> void:
	_detonate()


func despawn() -> void:
	if _return_pending or get_parent() == _idle_parent:
		return
	is_active = false
	_return_pending = true
	_release_caps()
	visible = false
	set_physics_process(false)
	remove_from_group(&"native_3d_mines")
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
	remaining_fuse = 0.0
	is_cluster = false
	leaves_plasma = false
	_detonating = false
	_flight_space = null
	_bounds = Rect2()
	core.scale = Vector3.ONE
	telegraph.scale = Vector3.ONE * 0.25
	telegraph.transparency = 0.35
	visuals.rotation = Vector3.ZERO
	transform = Transform3D.IDENTITY
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	_return_pending = false
	ObjectPool.release(self, _idle_parent)
	returned_to_pool.emit(self)


func get_combat_position() -> Vector3:
	return Vector3(global_position.x, 0.0, global_position.z)


func _release_caps() -> void:
	if _coordinator == null or not is_instance_valid(_coordinator):
		return
	_coordinator.release_hazard(&"mine")
	if is_cluster:
		_coordinator.release_hazard(&"cluster_mine")


func _on_area_entered(area: Area3D) -> void:
	if not is_active or not area.is_in_group(&"player_craft"):
		return
	if bool(area.get("is_boosting")):
		clear_ordnance()
		return
	if area.has_method("receive_damage"):
		area.receive_damage(get_combat_position(), PlayerCraft.DamageSource.HOSTILE_ORDNANCE)
	_detonate()
