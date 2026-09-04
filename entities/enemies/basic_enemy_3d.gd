extends Area3D
class_name BasicEnemy3D
## Scene-managed Basic Enemy lineage. The native wrapper owns the shared
## contact/damage lifecycle while generation-specific movement and death
## behavior stay in the wrapper; score/orb authority is routed by the native
## gameplay controller.

signal finished(reason: FinishReason, combat_position: Vector3)
signal charge_started(combat_position: Vector3, direction: Vector3)
signal charge_released(combat_position: Vector3, direction: Vector3)

enum FinishReason { DESTROYED, CONTACT, ESCAPED }

const FlightSpace := preload("res://systems/flight_space_3d.gd")
const PhysicsLayers := preload("res://systems/native_3d_physics_layers.gd")
const GenerationStats := preload("res://entities/enemies/enemy_generation_stats.gd")
const SpawnTuning := preload("res://entities/enemies/enemy_spawn_tuning.gd")
const NativeHazardManager := preload("res://systems/native_hazard_manager_3d.gd")
const GENERATION_STATS := [
	preload("res://entities/enemies/basic_enemy_generation_1.tres"),
	preload("res://entities/enemies/basic_enemy_generation_2.tres"),
	preload("res://entities/enemies/basic_enemy_generation_3.tres"),
	preload("res://entities/enemies/basic_enemy_generation_4.tres"),
]

const SCORE_MULTIPLIERS := [1.0, 1.5, 2.25, 3.25]
const STEERING_RATE_RADIANS := deg_to_rad(40.0)
const CHARGE_TRIGGER_DISTANCE_PIXELS := 240.0
const CHARGE_TELEGRAPH_SECONDS := 0.55
const CHARGE_DURATION_SECONDS := 0.45
const CHARGE_SPEED_MULTIPLIER := 2.2
const CHARGE_WARNING_LENGTH_PIXELS := 260.0

@export var gameplay_stats: GenerationStats
@export_range(1, 4, 1) var generation: int = 1

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visuals: Node3D = $Visuals
@onready var sockets: Node3D = $Attachments/Sockets

var archetype_id: StringName = &"basic"
var is_active := false
var health: int = 0
var velocity := Vector3.ZERO

var _flight_space: FlightSpace
var _active_stats: GenerationStats
var _exit_bounds := Rect2()
var _heading := Vector3.BACK
var _speed_pixels := 0.0
var _meshes: Array[MeshInstance3D] = []
var _socket_markers: Array[Marker3D] = []
var _animation_time := 0.0
var _flash_time_left := 0.0
var _breathing: Tween
var _time_alive := 0.0
var _charge_used := false
var _charge_state := 0
var _charge_timer := 0.0
var _charge_screen_direction := Vector2.ZERO
var _charge_warning: MeshInstance3D


func _ready() -> void:
	# Inert but visible before activation: the transition can warm the actual
	# first enemy without collision, gameplay groups, timers, or reward effects.
	set_physics_process(false)
	for node in visuals.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(node as MeshInstance3D)
	for child in sockets.get_children():
		if child is Marker3D:
			_socket_markers.append(child as Marker3D)
	area_entered.connect(_on_area_entered)
	_set_instance_parameter(&"instance_animation_time", 0.0)
	_set_instance_parameter(&"instance_flash", 0.0)


func activate(flight_space: FlightSpace, combat_position: Vector3, direction: Vector3) -> bool:
	return activate_generation(flight_space, combat_position, direction, generation)


func activate_generation(
	flight_space: FlightSpace,
	combat_position: Vector3,
	direction: Vector3,
	generation_override: int
) -> bool:
	if is_active or is_queued_for_deletion():
		return false
	if flight_space == null or flight_space.configuration == null:
		push_error("BasicEnemy3D requires shared generation stats and a configured FlightSpace3D")
		return false
	generation = clampi(generation_override, 1, 4)
	_active_stats = _get_generation_stats()
	if _active_stats == null:
		push_error("BasicEnemy3D requires generation %d stats" % generation)
		return false
	direction.y = 0.0
	if direction.is_zero_approx():
		return false
	_flight_space = flight_space
	_heading = direction.normalized()
	combat_position.y = 0.0
	global_position = combat_position
	rotation = Vector3(0.0, atan2(-_heading.x, -_heading.z), 0.0)
	# Gen I enters from four cardinal edges. The reference's square stays
	# 26x26 screen pixels at each heading; compensate camera foreshortening
	# with the authored box, independently of visual/socket yaw.
	collision_shape.global_rotation = Vector3.ZERO
	_speed_pixels = _active_stats.move_speed * GameManager.get_late_game_speed_multiplier()
	_configure_movement()
	# Preserve the reference's two separate rounding steps.
	health = roundi(float(_active_stats.max_health) * GameManager.get_enemy_health_multiplier())
	health = roundi(float(health) * GameManager.get_late_game_health_multiplier())
	_refresh_exit_bounds()
	if not get_viewport().size_changed.is_connected(_refresh_exit_bounds):
		get_viewport().size_changed.connect(_refresh_exit_bounds)
	_animation_time = 0.0
	_flash_time_left = 0.0
	_time_alive = 0.0
	_charge_used = false
	_charge_state = 0
	_charge_timer = 0.0
	_charge_screen_direction = Vector2.ZERO
	_clear_charge_warning()
	_set_instance_parameter(&"instance_animation_time", 0.0)
	_set_instance_parameter(&"instance_flash", 0.0)
	_set_generation_visuals()
	is_active = true
	add_to_group(&"enemy_craft")
	add_to_group(&"native_3d_enemies")
	collision_layer = PhysicsLayers.ENEMY_CRAFT
	collision_mask = PhysicsLayers.ENEMY_CRAFT_MASK
	monitoring = true
	monitorable = true
	collision_shape.disabled = false
	force_update_transform()
	set_physics_process(true)
	show()
	_breathing = create_tween().set_loops().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_breathing.tween_property(visuals, "scale", Vector3(1.05, 1.0, 0.95), 0.6).set_trans(Tween.TRANS_SINE)
	_breathing.tween_property(visuals, "scale", Vector3(0.95, 1.0, 1.05), 0.6).set_trans(Tween.TRANS_SINE)
	return true


func _physics_process(delta: float) -> void:
	if not is_active or not GameManager.is_game_active:
		return
	_time_alive += delta
	_advance_movement(delta)
	global_position.y = 0.0
	# Player Projectiles sweep at priority 2, after actor transforms reach physics.
	force_update_transform()
	if _has_crossed_exit_edge():
		_finish(FinishReason.ESCAPED)
		return
	_animation_time += delta
	_set_instance_parameter(&"instance_animation_time", _animation_time)
	if _flash_time_left > 0.0:
		_flash_time_left = maxf(_flash_time_left - delta, 0.0)
		var flash := (0.15 - _flash_time_left) / 0.05 if _flash_time_left > 0.1 else _flash_time_left / 0.1
		_set_instance_parameter(&"instance_flash", clampf(flash, 0.0, 1.0))


## Hook for movement variants. The default is the Generation I straight path;
## specialized native roles override these two methods while retaining the
## shared hitbox, damage, contact, and finish lifecycle.
func _configure_movement() -> void:
	var screen_direction := _flight_space.combat_motion_to_screen(_heading).normalized()
	_configure_movement_from_screen(screen_direction)


func _advance_movement(delta: float) -> void:
	if not _is_basic_lineage():
		global_position += velocity * delta
		global_position.y = 0.0
		return
	if _charge_state == 1:
		_charge_timer -= delta
		if _charge_timer <= 0.0:
			_charge_state = 2
			_charge_timer = CHARGE_DURATION_SECONDS
			_clear_charge_warning()
			charge_released.emit(get_combat_position(), _flight_space.screen_motion_to_combat(_charge_screen_direction))
		return
	if _charge_state == 2:
		var charge_velocity := _flight_space.screen_motion_to_combat(
			_charge_screen_direction * _speed_pixels * CHARGE_SPEED_MULTIPLIER
		)
		velocity = Vector3(charge_velocity.x, 0.0, charge_velocity.z)
		_heading = _flight_space.input_to_combat_direction(_charge_screen_direction)
		_update_facing(_heading)
		global_position += velocity * delta
		global_position.y = 0.0
		_charge_timer -= delta
		if _charge_timer <= 0.0:
			_charge_state = 3
			_configure_movement_from_screen(_charge_screen_direction)
		return

	if generation >= 2 and _charge_state == 0:
		_update_targeting(delta)
	if generation >= 3 and _charge_state == 0:
		_try_begin_charge()
	global_position += velocity * delta
	global_position.y = 0.0


func _update_targeting(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player_craft") as Node3D
	if player == null:
		return
	var desired_screen := _flight_space.combat_motion_to_screen(
		player.global_position - global_position
	).normalized()
	var current_screen := _flight_space.combat_motion_to_screen(_heading).normalized()
	if desired_screen.is_zero_approx() or current_screen.is_zero_approx():
		return
	var turn := clampf(
		current_screen.angle_to(desired_screen),
		-STEERING_RATE_RADIANS * delta,
		STEERING_RATE_RADIANS * delta
	)
	var new_screen_direction := current_screen.rotated(turn)
	_heading = _flight_space.input_to_combat_direction(new_screen_direction)
	_configure_movement_from_screen(new_screen_direction)
	_update_facing(_heading)


func _try_begin_charge() -> void:
	if _charge_used or _time_alive < 0.35:
		return
	var player := get_tree().get_first_node_in_group(&"player_craft") as Node3D
	if player == null:
		return
	var to_player := _flight_space.combat_motion_to_screen(player.global_position - global_position)
	if to_player.length() > CHARGE_TRIGGER_DISTANCE_PIXELS or to_player.is_zero_approx():
		return
	_charge_used = true
	_charge_state = 1
	_charge_timer = CHARGE_TELEGRAPH_SECONDS
	_charge_screen_direction = to_player.normalized()
	velocity = Vector3.ZERO
	_create_charge_warning()
	charge_started.emit(get_combat_position(), _flight_space.screen_motion_to_combat(_charge_screen_direction))


func _create_charge_warning() -> void:
	_clear_charge_warning()
	_charge_warning = MeshInstance3D.new()
	_charge_warning.name = "ChargeTelegraph"
	var mesh := BoxMesh.new()
	var length := _flight_space.screen_motion_to_combat(
		_charge_screen_direction * CHARGE_WARNING_LENGTH_PIXELS
	).length()
	mesh.size = Vector3(0.12, 0.025, maxf(length, 0.1))
	_charge_warning.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.2, 0.08, 0.78)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.08, 0.02)
	material.emission_energy_multiplier = 2.0
	_charge_warning.material_override = material
	add_child(_charge_warning)
	_charge_warning.position = _flight_space.screen_motion_to_combat(
		_charge_screen_direction * CHARGE_WARNING_LENGTH_PIXELS * 0.5
	)
	_charge_warning.position.y = 0.04
	_charge_warning.rotation.y = atan2(-_charge_screen_direction.x, -_charge_screen_direction.y)


func _clear_charge_warning() -> void:
	if is_instance_valid(_charge_warning):
		_charge_warning.queue_free()
	_charge_warning = null


func take_damage(amount: int) -> void:
	if not is_active or amount <= 0:
		return
	health -= amount
	if health <= 0:
		_finish(FinishReason.DESTROYED)
	else:
		_flash_time_left = 0.15


func get_socket_markers() -> Array[Marker3D]:
	return _socket_markers


func get_socket(socket_name: StringName) -> Marker3D:
	return sockets.get_node_or_null(NodePath(String(socket_name))) as Marker3D


func get_combat_position() -> Vector3:
	return Vector3(global_position.x, 0.0, global_position.z)


func get_reward_points() -> int:
	if _active_stats == null:
		return 0
	return roundi(float(_active_stats.base_points) * SCORE_MULTIPLIERS[generation - 1])


func get_orb_value() -> int:
	return _active_stats.orb_value if _active_stats != null else 1


func should_drop_xp_orb() -> bool:
	if _active_stats == null:
		return false
	return _active_stats.guaranteed_orb or randf() < _active_stats.orb_drop_chance


func get_generation_stats() -> GenerationStats:
	return _active_stats


func _on_area_entered(area: Area3D) -> void:
	# Projectile damage is routed once by Native3DGameplay, never also here.
	if area.is_in_group(&"player_craft"):
		_finish(FinishReason.CONTACT)


func _finish(reason: FinishReason) -> void:
	if not is_active:
		return
	is_active = false
	set_physics_process(false)
	remove_from_group(&"enemy_craft")
	remove_from_group(&"native_3d_enemies")
	remove_from_group(&"native_3d_regular_enemies")
	hide()
	if _breathing != null:
		_breathing.kill()
	_clear_charge_warning()
	# Contacts may arrive during a physics flush. Deactivate logically now and
	# defer physics mutations; repeated damage/contact callbacks cannot finish twice.
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	collision_shape.set_deferred("disabled", true)
	var combat_position := global_position
	combat_position.y = 0.0
	var native_gameplay := get_tree().get_first_node_in_group(&"native_3d_gameplay")
	if native_gameplay != null and native_gameplay.has_method("route_enemy_finish"):
		native_gameplay.route_enemy_finish(self, reason, combat_position, _heading)
	_before_finish(reason, combat_position)
	finished.emit(reason, combat_position)
	queue_free()


## Extension point for the Basic lineage's Generation IV death fragments.
func _before_finish(_reason: FinishReason, _combat_position: Vector3) -> void:
	if _is_basic_lineage() and _reason == FinishReason.DESTROYED and generation >= 4:
		_release_generation_fragments()


func _is_basic_lineage() -> bool:
	return true


func _release_generation_fragments() -> void:
	var manager := get_tree().get_first_node_in_group(&"native_3d_hazard_manager") as NativeHazardManager
	if manager == null or _flight_space == null:
		return
	var screen_heading := _flight_space.combat_motion_to_screen(_heading).normalized()
	var marker_names := [&"FragmentLeft", &"FragmentRight"]
	var offsets := [-0.36, 0.36]
	for index in marker_names.size():
		var marker := get_socket(marker_names[index])
		if marker == null:
			continue
		var fragment_direction := _flight_space.input_to_combat_direction(
			screen_heading.rotated(offsets[index])
		)
		# Death can be entered from a projectile overlap callback. The manager
		# defers activation until the physics flush and cancels it on reset/Nuke.
		manager.queue_seeker_fragment(marker.global_position, fragment_direction)


func _refresh_exit_bounds() -> void:
	_exit_bounds = _flight_space.get_combat_bounds(SpawnTuning.DESPAWN_MARGIN)


func _has_crossed_exit_edge() -> bool:
	return (
		(_heading.z > 0.3 and global_position.z > _exit_bounds.end.y)
		or (_heading.z < -0.3 and global_position.z < _exit_bounds.position.y)
		or (_heading.x > 0.3 and global_position.x > _exit_bounds.end.x)
		or (_heading.x < -0.3 and global_position.x < _exit_bounds.position.x)
	)


func _set_instance_parameter(parameter: StringName, value: float) -> void:
	for mesh in _meshes:
		mesh.set_instance_shader_parameter(parameter, value)


func _set_generation_visuals() -> void:
	var energy_colors := [
		Color(1.0, 0.231, 0.141, 1.0),
		Color(0.12, 1.0, 0.55, 1.0),
		Color(1.0, 0.16, 0.04, 1.0),
		Color(0.92, 0.18, 1.0, 1.0),
	]
	var accent_colors := [
		Color(1.0, 0.757, 0.302, 1.0),
		Color(0.72, 1.0, 0.86, 1.0),
		Color(1.0, 0.72, 0.18, 1.0),
		Color(1.0, 0.82, 1.0, 1.0),
	]
	var energy: Color = energy_colors[generation - 1]
	var accent: Color = accent_colors[generation - 1]
	for mesh in _meshes:
		mesh.set_instance_shader_parameter(&"instance_energy_override", energy)
		mesh.set_instance_shader_parameter(&"instance_accent_override", accent)
		mesh.set_instance_shader_parameter(&"instance_phase_offset", float(generation - 1) * 0.43)


func _get_generation_stats() -> GenerationStats:
	if generation == 1 and gameplay_stats != null:
		return gameplay_stats
	return GENERATION_STATS[generation - 1] as GenerationStats


func _configure_movement_from_screen(screen_direction: Vector2) -> void:
	var combat_velocity := _flight_space.screen_motion_to_combat(screen_direction * _speed_pixels)
	velocity = Vector3(combat_velocity.x, 0.0, combat_velocity.z)


func _update_facing(direction: Vector3) -> void:
	if direction.is_zero_approx():
		return
	rotation.y = atan2(-direction.x, -direction.z)
