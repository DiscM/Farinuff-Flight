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
enum Motion { STRAIGHT, ACCELERATING, CURVE_LEFT, CURVE_RIGHT, BOOST_BREAKER, BRAKING, ORBIT_LEFT, ORBIT_RIGHT, RETURNING, STOP_RELEASE }

static var _breaker_mesh: SphereMesh
var _default_projectile_mesh: Mesh

var enemy_motion: Motion = Motion.STRAIGHT
var _motion_age := 0.0
var _launch_speed := 0.0
var _launch_direction := Vector2.ZERO
var _launch_position := Vector3.ZERO
var _orbit_center := Vector3.ZERO
var _orbit_radius := Vector2.ZERO

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

var piercing := false
var explosive := false
var homing := false
var _hit_ids: Dictionary[int, bool] = {}
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
	_default_projectile_mesh = projectile_mesh.mesh
	if _breaker_mesh == null:
		_breaker_mesh = SphereMesh.new()
		_breaker_mesh.radius = 0.9
		_breaker_mesh.height = 1.8
		_breaker_mesh.radial_segments = 4
		_breaker_mesh.rings = 1
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


func pool_activate(
	spawn_position: Vector3,
	new_velocity: Vector3,
	combat_bounds: Rect2,
	size_multiplier: float = 1.0
) -> void:
	transform = Transform3D.IDENTITY
	scale = Vector3.ONE * maxf(size_multiplier, 1.0)
	is_deflected = false
	enemy_motion = Motion.STRAIGHT
	_motion_age = 0.0
	piercing = false
	explosive = false
	homing = false
	_hit_ids.clear()
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
	_advance_enemy_motion(delta)
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


## Motion never retargets after launch. Reflection immediately restores straight flight.
func configure_enemy_motion(profile: Motion, tint: Color = Color.TRANSPARENT, boss_style: int = -1) -> void:
	enemy_motion = profile
	_motion_age = 0.0
	_launch_speed = _flight_space.combat_motion_to_screen(velocity).length()
	_launch_direction = _flight_space.combat_motion_to_screen(velocity).normalized()
	_launch_position = global_position
	if profile == Motion.RETURNING:
		remaining_lifetime = minf(remaining_lifetime, 1.9)
	_orbit_center = Vector3.ZERO
	_orbit_radius = Vector2.ZERO
	if profile in [Motion.ORBIT_LEFT, Motion.ORBIT_RIGHT]:
		var sign := 1.0 if profile == Motion.ORBIT_LEFT else -1.0
		var tangent := _flight_space.combat_motion_to_screen(velocity).normalized()
		var to_center := tangent.rotated(sign * PI * 0.5) * 140.0
		_orbit_center = global_position + _flight_space.screen_motion_to_combat(to_center)
		_orbit_radius = -to_center
		remaining_lifetime = minf(remaining_lifetime, 3.0)
	if boss_style >= 0 and profile != Motion.BOOST_BREAKER:
		projectile_mesh.mesh = _get_boss_mesh(boss_style)
	var color := Color.TRANSPARENT
	match profile:
		Motion.BOOST_BREAKER:
			color = Color(0.05, 0.95, 1.0)
			projectile_mesh.mesh = _breaker_mesh
			projectile_mesh.set_instance_shader_parameter(&"instance_base_override", Color(0.02, 0.45, 0.65))
			projectile_mesh.set_instance_shader_parameter(&"instance_accent_override", Color.WHITE)
		Motion.ACCELERATING:
			color = Color(1.0, 0.65, 0.08)
		Motion.CURVE_LEFT, Motion.CURVE_RIGHT:
			color = Color(0.7, 0.25, 1.0)
	if profile == Motion.BRAKING:
		color = Color(1.0, 0.35, 0.5)
	if tint.a > 0.0 and profile != Motion.BOOST_BREAKER:
		color = tint
		projectile_mesh.set_instance_shader_parameter(&"instance_base_override", tint.darkened(0.35))
	# Shape communicates motion as well as color; only cyan has diamond geometry.
	if profile == Motion.ACCELERATING:
		visuals.scale = Vector3(0.8, 0.8, 1.6)
	elif profile == Motion.BRAKING:
		visuals.scale = Vector3(1.2, 0.8, 1.2)
	projectile_mesh.set_instance_shader_parameter(&"instance_energy_override", color)
	projectile_mesh.set_instance_shader_parameter(&"instance_glow_override", color)

## Shared meshes keep the pooled silhouettes immutable and allocation bounded.
static func _get_boss_mesh(style: int) -> Mesh:
	return preload("res://assets/models/projectiles/boss_projectile_meshes.gd").get_mesh(style)

func _advance_enemy_motion(delta: float) -> void:
	if kind != Kind.ENEMY or is_deflected or enemy_motion in [Motion.STRAIGHT, Motion.BOOST_BREAKER]:
		return
	if enemy_motion in [Motion.ORBIT_LEFT, Motion.ORBIT_RIGHT]:
		_motion_age += delta
		var sign := 1.0 if enemy_motion == Motion.ORBIT_LEFT else -1.0
		var angle := _motion_age * _launch_speed / 140.0 * sign
		var next_position := _orbit_center + _flight_space.screen_motion_to_combat(_orbit_radius.rotated(angle))
		velocity = (next_position - global_position) / maxf(delta, 0.00001)
		rotation.y = atan2(-velocity.x, -velocity.z)
		return
	if enemy_motion == Motion.RETURNING:
		_motion_age += delta
		# Outbound, brief suspended beat, then retrace the same path to its origin.
		var distance := _launch_speed * (minf(_motion_age, 0.8) - clampf(_motion_age - 1.1, 0.0, 0.8))
		var target := _launch_position + _flight_space.screen_motion_to_combat(_launch_direction * distance)
		velocity = (target - global_position) / maxf(delta, 0.00001)
		return
	if enemy_motion == Motion.STOP_RELEASE:
		_motion_age += delta
		var multiplier := 0.55 if _motion_age < 0.65 else 0.0 if _motion_age < 1.35 else 1.35
		velocity = _flight_space.screen_motion_to_combat(_launch_direction * _launch_speed * multiplier)
		projectile_mesh.set_instance_shader_parameter(&"instance_flash", 0.35 if multiplier == 0.0 else 0.0)
		return
	var previous_age := _motion_age
	_motion_age += delta
	var screen_velocity := _flight_space.combat_motion_to_screen(velocity)
	if enemy_motion == Motion.BRAKING:
		screen_velocity = screen_velocity.normalized() * _launch_speed * lerpf(1.0, 0.45, clampf((_motion_age - 0.3) / 0.8, 0.0, 1.0))
	elif enemy_motion == Motion.ACCELERATING:
		# A slow readable launch becomes a fast lance over the first second.
		screen_velocity = screen_velocity.normalized() * _launch_speed * lerpf(1.0, 1.85, clampf((_motion_age - 0.25) / 0.9, 0.0, 1.0))
	else:
		# Bend for a bounded duration, then continue along the exit tangent.
		var curve_delta := minf(_motion_age, 1.2) - minf(previous_age, 1.2)
		screen_velocity = screen_velocity.rotated(curve_delta * (0.55 if enemy_motion == Motion.CURVE_LEFT else -0.55))
	velocity = _flight_space.screen_motion_to_combat(screen_velocity)
	rotation.y = atan2(-velocity.x, -velocity.z)


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
	if kind != Kind.ENEMY or not is_active or is_deflected or _return_pending or _flight_space == null or enemy_motion == Motion.BOOST_BREAKER:
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
	projectile_mesh.set_instance_shader_parameter(&"instance_flash", 0.0)
	enemy_motion = Motion.STRAIGHT
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


func _sweep_motion(motion: Vector3, piercing_contacts: int = 0) -> bool:
	last_sweep_performed = true
	var target_motion := Vector3.ZERO
	if (
		kind == Kind.ENEMY
		and not is_deflected
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
		var redirected := _report_hit(target, impact_position)
		if redirected:
			return true
		# Recast the same motion after adding a piercing exception. This catches
		# closely spaced targets crossed in one frame, with a bounded query budget.
		if is_active and piercing and piercing_contacts < 7 and _hit_ids.has(target.get_instance_id()):
			return _sweep_motion(motion, piercing_contacts + 1)
		return false
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
	if target == null or not is_active or _impact_pending or _hit_ids.has(target.get_instance_id()):
		return false
	# Plasma fields share the hostile-ordnance layer for Player Craft contact,
	# but the 2D reference does not let regular Player Projectiles defuse them.
	# Keep those shots moving through a field instead of consuming the projectile
	# on a non-damageable overlap.
	if (
		kind == Kind.PLAYER
		and target != null
		and target.collision_layer & PhysicsLayers.HOSTILE_ORDNANCE
		and not target.has_method(&"take_damage")
	):
		return false
	combat_position.y = 0.0
	# Contact listeners may redirect the projectile synchronously. Make its
	# reflection vector and telemetry originate at the actual swept impact.
	var previous_position := global_position
	global_position = combat_position
	_hit_ids[target.get_instance_id()] = true
	var was_deflected := is_deflected
	_impact_pending = true
	hit.emit(target, combat_position)
	if not was_deflected and is_deflected and is_active:
		_impact_pending = false
		return true
	if is_active and piercing and target.collision_layer & PhysicsLayers.ENEMY_CRAFT:
		sweep.add_exception(target)
		global_position = previous_position
		_impact_pending = false
	elif is_active:
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
	piercing = false
	explosive = false
	homing = false
	_hit_ids.clear()
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
	projectile_mesh.mesh = _default_projectile_mesh
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
