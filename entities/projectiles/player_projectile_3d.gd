extends Area3D
class_name PlayerProjectile3D
## Pooled native Player Projectile. This wrapper owns overlap/sweep detection;
## damage routing belongs to the later native combat slice.

signal hit(target: Area3D, combat_position: Vector3)
signal returned_to_pool(projectile: Area3D)

const PhysicsLayers := preload("res://systems/native_3d_physics_layers.gd")
const HIT_TARGET_MASK := PhysicsLayers.ENEMY_CRAFT | PhysicsLayers.HOSTILE_ORDNANCE

## Fallback cleanup, beyond a normal traversal of the visible Combat Plane.
@export_range(1.0, 20.0, 0.5) var lifetime_seconds: float = 6.0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var sweep: ShapeCast3D = $Sweep
@onready var visuals: Node3D = $Visuals
@onready var bolt: MeshInstance3D = $Visuals/Bolt

var is_active := false
var velocity := Vector3.ZERO
var remaining_lifetime := 0.0
var last_step_usec := 0
var _bounds := Rect2()
var _idle_parent: Node3D
var _return_pending := false


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	sweep.collision_mask = HIT_TARGET_MASK
	set_physics_process(false)


func configure_pool(idle_parent: Node3D) -> void:
	_idle_parent = idle_parent


## Render the shared mesh/material under the transition cover without arming
## collisions, running movement, or joining an active projectile group.
func prepare_visual_warmup() -> void:
	transform = Transform3D.IDENTITY
	visible = true


func pool_activate(spawn_position: Vector3, new_velocity: Vector3, combat_bounds: Rect2) -> void:
	transform = Transform3D.IDENTITY
	global_position = Vector3(spawn_position.x, 0.0, spawn_position.z)
	velocity = Vector3(new_velocity.x, 0.0, new_velocity.z)
	rotation.y = atan2(-velocity.x, -velocity.z)
	_bounds = combat_bounds
	remaining_lifetime = lifetime_seconds
	last_step_usec = 0
	_return_pending = false
	is_active = true
	_reset_visuals()
	sweep.clear_exceptions()
	sweep.target_position = Vector3.ZERO
	collision_shape.disabled = false
	collision_layer = PhysicsLayers.PLAYER_PROJECTILE
	collision_mask = PhysicsLayers.PLAYER_PROJECTILE_MASK
	monitoring = true
	monitorable = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)
	add_to_group(&"player_projectiles")
	if not _inside_bounds(global_position):
		despawn()


func update_combat_bounds(value: Rect2) -> void:
	_bounds = value


func _physics_process(delta: float) -> void:
	if not is_active or not GameManager.is_game_active:
		return
	var started := Time.get_ticks_usec()
	remaining_lifetime -= delta
	if remaining_lifetime <= 0.0 or not _inside_bounds(global_position):
		despawn()
		return
	var motion := velocity * delta
	# A projectile can cross a thin hitbox between overlap updates. Sweep its
	# primitive envelope across this tick, using the same shape as the Area3D.
	sweep.target_position = sweep.to_local(global_position + motion)
	sweep.force_shapecast_update()
	if sweep.is_colliding():
		var target := sweep.get_collider(0) as Area3D
		var impact_position := sweep.get_collision_point(0)
		impact_position.y = 0.0
		if target != null and _inside_bounds(impact_position):
			_report_hit(target, impact_position)
	if is_active:
		global_position += motion
		global_position.y = 0.0
		if not _inside_bounds(global_position):
			despawn()
	last_step_usec = Time.get_ticks_usec() - started


func _on_area_entered(area: Area3D) -> void:
	if not is_active or not GameManager.is_game_active or not _inside_bounds(global_position):
		return
	# Pickups retain their own overlap response, as in the 2D reference; they
	# do not absorb the projectile or obstruct its damage-target sweep.
	if area.collision_layer & HIT_TARGET_MASK:
		_report_hit(area, global_position)


func _report_hit(target: Area3D, combat_position: Vector3) -> void:
	if not is_active:
		return
	combat_position.y = 0.0
	despawn()
	hit.emit(target, combat_position)


func despawn() -> void:
	if _return_pending or get_parent() == _idle_parent:
		return
	is_active = false
	_return_pending = true
	visible = false
	set_physics_process(false)
	remove_from_group(&"player_projectiles")
	# Overlap signals run during physics-query flushing. Reparent/disable only
	# after that flush, and make the node available only after reset completes.
	_finish_return.call_deferred()


func _finish_return() -> void:
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0
	collision_shape.disabled = true
	sweep.target_position = Vector3.ZERO
	sweep.clear_exceptions()
	velocity = Vector3.ZERO
	remaining_lifetime = 0.0
	last_step_usec = 0
	transform = Transform3D.IDENTITY
	_reset_visuals()
	process_mode = Node.PROCESS_MODE_DISABLED
	_return_pending = false
	ObjectPool.release(self, _idle_parent)
	returned_to_pool.emit(self)


func _reset_visuals() -> void:
	visuals.transform = Transform3D.IDENTITY
	bolt.set_instance_shader_parameter(&"instance_modulate", Color.WHITE)
	bolt.set_instance_shader_parameter(&"instance_flash", 0.0)
	bolt.set_instance_shader_parameter(&"instance_phase_offset", 0.0)
	bolt.set_instance_shader_parameter(&"instance_energy_override", Color.TRANSPARENT)
	bolt.set_instance_shader_parameter(&"instance_accent_override", Color.TRANSPARENT)


func _inside_bounds(combat_position: Vector3) -> bool:
	return _bounds.has_point(Vector2(combat_position.x, combat_position.z))
