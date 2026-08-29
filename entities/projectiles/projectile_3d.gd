extends Area3D
class_name Projectile3D
## Shared pooled native projectile lifecycle and overlap/sweep detection;
## damage routing belongs to the native gameplay controller.

signal hit(target: Area3D, combat_position: Vector3)
signal returned_to_pool(projectile: Area3D)

const PhysicsLayers := preload("res://systems/native_3d_physics_layers.gd")
const InteractionRange := preload("res://systems/projectile_interaction_range_3d.gd")
const FlightSpace := preload("res://systems/flight_space_3d.gd")
const EnemyTuning := preload("res://entities/projectiles/enemy_projectile_tuning.gd")

enum Kind { PLAYER, ENEMY }

@export var kind: Kind = Kind.PLAYER

## Fallback cleanup, beyond a normal traversal of the visible Combat Plane.
@export_range(1.0, 20.0, 0.5) var lifetime_seconds: float = 6.0

@export_group("Deflected Visual")
@export var deflected_base_color := Color.TRANSPARENT
@export var deflected_energy_color := Color.TRANSPARENT
@export var deflected_accent_color := Color.TRANSPARENT
@export var deflected_glow_color := Color.TRANSPARENT

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var sweep: ShapeCast3D = $Sweep
@onready var visuals: Node3D = $Visuals
@onready var projectile_mesh: MeshInstance3D = $Visuals/ProjectileMesh

var is_active := false
var is_armed := false
var is_deflected := false
var velocity := Vector3.ZERO
var remaining_lifetime := 0.0
var last_step_usec := 0
var last_sweep_performed := false
var _bounds := Rect2()
var _idle_parent: Node3D
var _interaction_range: InteractionRange
var _flight_space: FlightSpace
var _return_pending := false
var _impact_pending := false
var _activation_physics_frame := -1
var _active_group: StringName
var _armed_layer := 0
var _armed_mask := 0
var _hit_target_mask := 0


func _ready() -> void:
	_reset_faction_contract()
	area_entered.connect(_on_area_entered)
	set_physics_process(false)


func configure_pool(
	idle_parent: Node3D,
	flight_space: FlightSpace,
	interaction_range: InteractionRange = null
) -> void:
	_idle_parent = idle_parent
	_flight_space = flight_space
	_interaction_range = interaction_range


## Render the shared mesh/material under the transition cover without arming
## collisions, running movement, or joining an active projectile group.
func prepare_visual_warmup() -> void:
	transform = Transform3D.IDENTITY
	visible = true


func pool_activate(spawn_position: Vector3, new_velocity: Vector3, combat_bounds: Rect2) -> void:
	transform = Transform3D.IDENTITY
	is_deflected = false
	_reset_faction_contract()
	global_position = Vector3(spawn_position.x, 0.0, spawn_position.z)
	velocity = Vector3(new_velocity.x, 0.0, new_velocity.z)
	rotation.y = atan2(-velocity.x, -velocity.z)
	_bounds = combat_bounds
	remaining_lifetime = lifetime_seconds
	last_step_usec = 0
	last_sweep_performed = false
	_activation_physics_frame = Engine.get_physics_frames()
	_return_pending = false
	_impact_pending = false
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
	var redirected_on_contact := false
	if is_armed:
		redirected_on_contact = _sweep_motion(motion)
	if is_active and not redirected_on_contact:
		global_position += motion
		global_position.y = 0.0
		if not _inside_bounds(global_position):
			despawn()
	last_step_usec = Time.get_ticks_usec() - started


func _update_collision_arming(motion: Vector3) -> void:
	var should_arm := kind == Kind.PLAYER or is_deflected
	if kind == Kind.ENEMY and not is_deflected and _interaction_range != null:
		should_arm = _interaction_range.should_arm(global_position, motion, is_armed)
	if should_arm == is_armed:
		return
	_set_collision_armed(should_arm)


## Converts an incoming Enemy Projectile into a Player-aligned projectile.
## Motion is calculated in the shared screen-pixel metric, then mapped back
## onto the Combat Plane so the reference speed and velocity bias stay exact.
func deflect(deflector_position: Vector3, deflector_velocity: Vector3) -> bool:
	if kind != Kind.ENEMY or not is_active or is_deflected or _return_pending or _flight_space == null:
		return false
	var current_screen_velocity := _flight_space.combat_motion_to_screen(velocity)
	var reflected_direction := _flight_space.combat_motion_to_screen(
		global_position - deflector_position
	).normalized()
	if reflected_direction.is_zero_approx():
		reflected_direction = -current_screen_velocity.normalized()
	if reflected_direction.is_zero_approx():
		reflected_direction = Vector2.UP
	var deflector_screen_velocity := _flight_space.combat_motion_to_screen(deflector_velocity)
	if not deflector_screen_velocity.is_zero_approx():
		reflected_direction = reflected_direction.lerp(
			deflector_screen_velocity.normalized(), EnemyTuning.DEFLECT_VELOCITY_BIAS
		).normalized()
	var reflected_speed := maxf(
		current_screen_velocity.length() * EnemyTuning.DEFLECT_SPEED_MULTIPLIER,
		EnemyTuning.DEFLECT_MIN_SPEED
	)
	is_deflected = true
	velocity = _flight_space.screen_motion_to_combat(reflected_direction * reflected_speed)
	velocity.y = 0.0
	rotation.y = atan2(-velocity.x, -velocity.z)
	_armed_layer = PhysicsLayers.PLAYER_PROJECTILE
	_armed_mask = PhysicsLayers.ENEMY_CRAFT
	_hit_target_mask = PhysicsLayers.ENEMY_CRAFT
	sweep.collision_mask = _hit_target_mask
	_set_collision_armed(true)
	projectile_mesh.set_instance_shader_parameter(&"instance_base_override", deflected_base_color)
	projectile_mesh.set_instance_shader_parameter(&"instance_energy_override", deflected_energy_color)
	projectile_mesh.set_instance_shader_parameter(&"instance_accent_override", deflected_accent_color)
	projectile_mesh.set_instance_shader_parameter(&"instance_glow_override", deflected_glow_color)
	return true


func _sweep_motion(motion: Vector3) -> bool:
	last_sweep_performed = true
	var target_motion := Vector3.ZERO
	if (
		not is_deflected
		and _interaction_range != null
		and _activation_physics_frame != Engine.get_physics_frames()
	):
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
		return _report_hit(target, impact_position)
	return false


func _on_area_entered(area: Area3D) -> void:
	if not is_active or not is_armed or not GameManager.is_game_active or not _inside_bounds(global_position):
		return
	# Pickups retain their own overlap response, as in the 2D reference; they
	# do not absorb the projectile or obstruct its damage-target sweep.
	if area.collision_layer & _hit_target_mask:
		_report_hit(area, global_position)


## Returns true when a synchronous contact listener reflected this incoming
## projectile, allowing the physics step to discard its stale inbound motion.
func _report_hit(target: Area3D, combat_position: Vector3) -> bool:
	if not is_active or _impact_pending:
		return false
	combat_position.y = 0.0
	# Contact listeners may redirect the projectile synchronously. Make its
	# reflection vector and telemetry originate at the actual swept impact.
	global_position = combat_position
	var was_deflected := is_deflected
	_impact_pending = true
	hit.emit(target, combat_position)
	if not was_deflected and is_deflected and is_active:
		_impact_pending = false
		return true
	if is_active:
		despawn()
	return false


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
	is_deflected = false
	_set_collision_armed(false)
	sweep.target_position = Vector3.ZERO
	sweep.clear_exceptions()
	velocity = Vector3.ZERO
	remaining_lifetime = 0.0
	last_step_usec = 0
	last_sweep_performed = false
	_activation_physics_frame = -1
	transform = Transform3D.IDENTITY
	_reset_visuals()
	_reset_faction_contract()
	process_mode = Node.PROCESS_MODE_DISABLED
	_return_pending = false
	_impact_pending = false
	ObjectPool.release(self, _idle_parent)
	returned_to_pool.emit(self)


func _reset_visuals() -> void:
	visuals.transform = Transform3D.IDENTITY
	projectile_mesh.set_instance_shader_parameter(&"instance_modulate", Color.WHITE)
	projectile_mesh.set_instance_shader_parameter(&"instance_flash", 0.0)
	projectile_mesh.set_instance_shader_parameter(&"instance_phase_offset", 0.0)
	projectile_mesh.set_instance_shader_parameter(&"instance_base_override", Color.TRANSPARENT)
	projectile_mesh.set_instance_shader_parameter(&"instance_energy_override", Color.TRANSPARENT)
	projectile_mesh.set_instance_shader_parameter(&"instance_accent_override", Color.TRANSPARENT)
	projectile_mesh.set_instance_shader_parameter(&"instance_glow_override", Color.TRANSPARENT)


func _set_collision_armed(value: bool) -> void:
	is_armed = value
	collision_shape.disabled = not value
	collision_layer = _armed_layer if value else 0
	collision_mask = _armed_mask if value else 0
	monitoring = value
	monitorable = value


func _reset_faction_contract() -> void:
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
	sweep.collision_mask = _hit_target_mask


func _inside_bounds(combat_position: Vector3) -> bool:
	return _bounds.has_point(Vector2(combat_position.x, combat_position.z))
