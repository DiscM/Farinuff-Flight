extends Area3D
class_name Projectile3D
## Shared pooled native projectile lifecycle and overlap/sweep detection;
## damage routing belongs to the later native combat slice.

signal hit(target: Area3D, combat_position: Vector3)
signal returned_to_pool(projectile: Area3D)

const PhysicsLayers := preload("res://systems/native_3d_physics_layers.gd")
const InteractionRange := preload("res://systems/projectile_interaction_range_3d.gd")

enum Kind { PLAYER, ENEMY }

@export var kind: Kind = Kind.PLAYER

## Fallback cleanup, beyond a normal traversal of the visible Combat Plane.
@export_range(1.0, 20.0, 0.5) var lifetime_seconds: float = 6.0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var sweep: ShapeCast3D = $Sweep
@onready var visuals: Node3D = $Visuals
@onready var projectile_mesh: MeshInstance3D = $Visuals/ProjectileMesh

var is_active := false
var is_armed := false
var velocity := Vector3.ZERO
var remaining_lifetime := 0.0
var last_step_usec := 0
var last_sweep_performed := false
var _bounds := Rect2()
var _idle_parent: Node3D
var _interaction_range: InteractionRange
var _return_pending := false
var _activation_physics_frame := -1
var _active_group: StringName
var _armed_layer := 0
var _armed_mask := 0
var _hit_target_mask := 0


func _ready() -> void:
	if kind == Kind.PLAYER:
		_active_group = &"player_projectiles"
		_armed_layer = PhysicsLayers.PLAYER_PROJECTILE
		_armed_mask = PhysicsLayers.PLAYER_PROJECTILE_MASK
		_hit_target_mask = PhysicsLayers.ENEMY_CRAFT | PhysicsLayers.HOSTILE_ORDNANCE
	else:
		_active_group = &"enemy_projectiles"
		_armed_layer = PhysicsLayers.ENEMY_PROJECTILE
		_armed_mask = PhysicsLayers.ENEMY_PROJECTILE_MASK
		_hit_target_mask = PhysicsLayers.PLAYER_CRAFT
	area_entered.connect(_on_area_entered)
	sweep.collision_mask = _hit_target_mask
	set_physics_process(false)


func configure_pool(idle_parent: Node3D, interaction_range: InteractionRange = null) -> void:
	_idle_parent = idle_parent
	_interaction_range = interaction_range


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
	last_sweep_performed = false
	_activation_physics_frame = Engine.get_physics_frames()
	_return_pending = false
	is_active = true
	_reset_visuals()
	sweep.clear_exceptions()
	sweep.target_position = Vector3.ZERO
	_update_collision_arming(Vector3.ZERO)
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)
	add_to_group(_active_group)
	if not _inside_bounds(global_position):
		despawn()


func update_combat_bounds(value: Rect2) -> void:
	_bounds = value


func _physics_process(delta: float) -> void:
	if not is_active or not GameManager.is_game_active:
		return
	var started := Time.get_ticks_usec()
	last_sweep_performed = false
	remaining_lifetime -= delta
	if remaining_lifetime <= 0.0 or not _inside_bounds(global_position):
		despawn()
		return
	var motion := velocity * delta
	_update_collision_arming(motion)
	if is_armed:
		_sweep_motion(motion)
	if is_active:
		global_position += motion
		global_position.y = 0.0
		if not _inside_bounds(global_position):
			despawn()
	last_step_usec = Time.get_ticks_usec() - started


func _update_collision_arming(motion: Vector3) -> void:
	var should_arm := kind == Kind.PLAYER
	if kind == Kind.ENEMY and _interaction_range != null:
		should_arm = _interaction_range.should_arm(global_position, motion, is_armed)
	if should_arm == is_armed:
		return
	is_armed = should_arm
	collision_shape.disabled = not is_armed
	collision_layer = _armed_layer if is_armed else 0
	collision_mask = _armed_mask if is_armed else 0
	monitoring = is_armed
	monitorable = is_armed


func _sweep_motion(motion: Vector3) -> void:
	last_sweep_performed = true
	var target_motion := Vector3.ZERO
	if _interaction_range != null and _activation_physics_frame != Engine.get_physics_frames():
		target_motion = _interaction_range.target_motion
	# Cast relative motion against the player's current physics transform. This
	# also catches the player crossing a slow projectile between two samples.
	var original_transform := sweep.transform
	sweep.global_position += target_motion
	sweep.target_position = sweep.to_local(global_position + motion)
	sweep.force_shapecast_update()
	var target: Area3D
	var impact_position := Vector3.ZERO
	if sweep.is_colliding():
		target = sweep.get_collider(0) as Area3D
		impact_position = sweep.get_collision_point(0)
		if not target_motion.is_zero_approx():
			impact_position = global_position + motion * sweep.get_closest_collision_unsafe_fraction()
		impact_position.y = 0.0
	sweep.transform = original_transform
	sweep.target_position = Vector3.ZERO
	if target != null and _inside_bounds(impact_position):
		_report_hit(target, impact_position)


func _on_area_entered(area: Area3D) -> void:
	if not is_active or not is_armed or not GameManager.is_game_active or not _inside_bounds(global_position):
		return
	# Pickups retain their own overlap response, as in the 2D reference; they
	# do not absorb the projectile or obstruct its damage-target sweep.
	if area.collision_layer & _hit_target_mask:
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
	remove_from_group(_active_group)
	# Overlap signals run during physics-query flushing. Reparent/disable only
	# after that flush, and make the node available only after reset completes.
	_finish_return.call_deferred()


func _finish_return() -> void:
	is_armed = false
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
	last_sweep_performed = false
	_activation_physics_frame = -1
	transform = Transform3D.IDENTITY
	_reset_visuals()
	process_mode = Node.PROCESS_MODE_DISABLED
	_return_pending = false
	ObjectPool.release(self, _idle_parent)
	returned_to_pool.emit(self)


func _reset_visuals() -> void:
	visuals.transform = Transform3D.IDENTITY
	projectile_mesh.set_instance_shader_parameter(&"instance_modulate", Color.WHITE)
	projectile_mesh.set_instance_shader_parameter(&"instance_flash", 0.0)
	projectile_mesh.set_instance_shader_parameter(&"instance_phase_offset", 0.0)
	projectile_mesh.set_instance_shader_parameter(&"instance_energy_override", Color.TRANSPARENT)
	projectile_mesh.set_instance_shader_parameter(&"instance_accent_override", Color.TRANSPARENT)


func _inside_bounds(combat_position: Vector3) -> bool:
	return _bounds.has_point(Vector2(combat_position.x, combat_position.z))
