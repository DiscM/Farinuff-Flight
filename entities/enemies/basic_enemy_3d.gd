extends Area3D
class_name BasicEnemy3D
## Scene-managed Basic Enemy lineage. The native wrapper owns the shared
## contact/damage lifecycle while generation-specific movement and death
## behavior stay in the wrapper; score/orb authority is routed by the native
## gameplay controller.
## Regular-enemy combat runs an explicit finite-state machine in the BossAI
## style: a shared State vocabulary, one state boundary per tick, and
## observation (distance, radial speed, capped prediction) feeding decisions.
## Every living state keeps the craft flying a player-relative strafe ring so
## no archetype parks in place or appears still between attacks.

signal finished(reason: FinishReason, combat_position: Vector3)
signal charge_started(combat_position: Vector3, direction: Vector3)
signal charge_released(combat_position: Vector3, direction: Vector3)
signal state_changed(previous: State, next: State)

enum FinishReason { DESTROYED, CONTACT, ESCAPED }

## Shared regular-enemy state vocabulary. Each archetype advances a subset.
enum State {
	TRANSIT,
	CHARGE_WINDUP,
	CHARGE,
	RECOVERY,
	EVADE,
	PHASE_WINDUP,
	PHASE_DASH,
	REPOSITION,
	ENTRY,
	HOLD,
	AIM,
	WITHDRAW,
	MINE_DEPLOY,
	BARRAGE,
	BRACE,
	OVERLOAD_WINDUP,
	OVERLOAD,
}

const FlightSpace := preload("res://systems/flight_space_3d.gd")
const PhysicsLayers := preload("res://systems/native_3d_physics_layers.gd")
const GenerationStats := preload("res://entities/enemies/enemy_generation_stats.gd")
const NativeHazardManager := preload("res://systems/native_hazard_manager_3d.gd")
const Projectile := preload("res://entities/projectiles/projectile_3d.gd")
const EXIT_MARGIN_PIXELS := 80.0
const SurfaceMaterials := preload("res://effects/rendering/enemy_surface_materials.gd")
const ShipMotion := preload("res://effects/ship_motion_3d.gd")
const GENERATION_STATS := [
	preload("res://entities/enemies/basic_enemy_generation_1.tres"),
	preload("res://entities/enemies/basic_enemy_generation_2.tres"),
	preload("res://entities/enemies/basic_enemy_generation_3.tres"),
	preload("res://entities/enemies/basic_enemy_generation_4.tres"),
]

const SCORE_MULTIPLIERS := [1.0, 1.5, 2.25, 3.25]
const CHARGE_TRIGGER_DISTANCE_PIXELS := 240.0
const CHARGE_TELEGRAPH_SECONDS := 0.55
const CHARGE_DURATION_SECONDS := 0.45
const CHARGE_SPEED_MULTIPLIER := 2.2
const PREDICTION_SECONDS := 0.35
const MAXIMUM_PREDICTION_PIXELS := 110.0
const PROJECTILE_ALERT_PIXELS := 95.0
const EVADE_SCAN_SECONDS := 0.12
const EVADE_COOLDOWN_SECONDS := 2.5
const EVADE_DISTANCE_PIXELS := 44.0
const EVADE_DURATION_SECONDS := 0.12
const HITBOX_MARGIN_PIXELS := 24.0
const STRAFE_STEERING_RATE_RADIANS := deg_to_rad(75.0)
const STRAFE_MINIMUM_TANGENTIAL_PIXELS := 75.0
const STRAFE_WEAVE_FREQUENCY := 1.55
const STRAFE_MINIMUM_SPEED_SCALE := 0.4
const ENGAGEMENT_SECONDS := 6.0
const WITHDRAW_SPEED_MULTIPLIER := 1.25
const CHARGE_WINDUP_SPEED_SCALE := 0.55
const DEFAULT_STRAFE_RADIUS_PIXELS := 205.0
const DEFAULT_STRAFE_TANGENTIAL_PIXELS := 95.0
const DEFAULT_STRAFE_WEAVE_PIXELS := 34.0

@export var gameplay_stats: GenerationStats
@export_range(1, 4, 1) var generation: int = 1
@export var surface_style: SurfaceMaterials.Style = SurfaceMaterials.Style.AUTHORED_ALLOY
@export_range(2.0, 16.0, 0.5) var surface_pixel_density: float = 8.0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visuals: Node3D = $Visuals
@onready var sockets: Node3D = $Attachments/Sockets

var archetype_id: StringName = &"basic"
var is_active := false
var health: int = 0
var max_health: int = 0
var velocity := Vector3.ZERO
var state: State = State.TRANSIT
var state_remaining := 0.0

var _flight_space: FlightSpace
var _active_stats: GenerationStats
var _exit_bounds := Rect2()
var _heading := Vector3.BACK
var _speed_pixels := 0.0
var _meshes: Array[MeshInstance3D] = []
var _socket_markers: Array[Marker3D] = []
var _animation_time := 0.0
var _flash_time_left := 0.0
var _motions: Array[ShipMotion] = []
var _animated_sockets: Array = []
var _time_alive := 0.0
var _charge_used := false
var _charge_screen_direction := Vector2.ZERO
var _observed_player: Node3D
var _player_distance_pixels := 0.0
var _player_radial_speed := 0.0
var _predicted_player := Vector3.ZERO
var _evade_cooldown := 0.0
var _evade_scan_timer := 0.0
var _strafe_angle := 0.0
var _strafe_radius := DEFAULT_STRAFE_RADIUS_PIXELS
var _strafe_tangential := DEFAULT_STRAFE_TANGENTIAL_PIXELS
var _strafe_weave := DEFAULT_STRAFE_WEAVE_PIXELS
var _strafe_sign := 1.0
var _strafe_clock := 0.0
var _engagement_timer := ENGAGEMENT_SECONDS


func _ready() -> void:
	set_physics_process(false)
	for model in visuals.get_children():
		if model is Node3D and model.find_child("AnimationPlayer", true, false) != null:
			_motions.append(ShipMotion.new(model))
			_bind_motion_sockets(model)
	_sync_motion_sockets()
	SurfaceMaterials.apply_to(visuals, surface_style, surface_pixel_density)
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
	collision_shape.global_rotation = Vector3.ZERO
	_speed_pixels = _active_stats.move_speed * GameManager.get_late_game_speed_multiplier()
	_animation_time = 0.0
	_flash_time_left = 0.0
	_time_alive = 0.0
	_charge_used = false
	_charge_screen_direction = Vector2.ZERO
	state = State.TRANSIT
	state_remaining = 0.0
	_evade_cooldown = 0.0
	_evade_scan_timer = randf_range(0.0, EVADE_SCAN_SECONDS)
	_strafe_radius = DEFAULT_STRAFE_RADIUS_PIXELS
	_strafe_tangential = DEFAULT_STRAFE_TANGENTIAL_PIXELS
	_strafe_weave = DEFAULT_STRAFE_WEAVE_PIXELS
	_configure_movement()
	health = roundi(float(_active_stats.max_health) * GameManager.get_enemy_health_multiplier())
	health = roundi(float(health) * GameManager.get_late_game_health_multiplier())
	max_health = health
	_refresh_exit_bounds()
	if not get_viewport().size_changed.is_connected(_refresh_exit_bounds):
		get_viewport().size_changed.connect(_refresh_exit_bounds)
	_observe_player()
	_seed_strafe()
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
	for motion in _motions:
		motion.reset()
	_sync_motion_sockets()
	return true


func _physics_process(delta: float) -> void:
	if not is_active or not GameManager.is_game_active:
		return
	advance_motion(delta)
	_time_alive += delta
	_advance_movement(delta)
	global_position.y = 0.0
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


func _configure_movement() -> void:
	_configure_strafe(
		DEFAULT_STRAFE_RADIUS_PIXELS,
		DEFAULT_STRAFE_TANGENTIAL_PIXELS,
		DEFAULT_STRAFE_WEAVE_PIXELS
	)
	_configure_movement_from_screen(
		_flight_space.combat_motion_to_screen(_heading).normalized()
	)


func _configure_strafe(radius_pixels: float, tangential_pixels: float, weave_pixels: float) -> void:
	_strafe_radius = maxf(radius_pixels, 40.0)
	_strafe_tangential = maxf(tangential_pixels, STRAFE_MINIMUM_TANGENTIAL_PIXELS)
	_strafe_weave = maxf(weave_pixels, 0.0)


func _seed_strafe() -> void:
	_strafe_sign = -1.0 if get_instance_id() % 2 == 0 else 1.0
	_strafe_clock = randf_range(0.0, TAU)
	_engagement_timer = engagement_seconds()
	if _observed_player != null and _flight_space != null:
		var offset := _flight_space.combat_motion_to_screen(
			global_position - _observed_player.global_position
		)
		_strafe_angle = offset.angle() if offset.length() > 1.0 else randf_range(0.0, TAU)
	else:
		_strafe_angle = randf_range(0.0, TAU)


func engagement_seconds() -> float:
	return ENGAGEMENT_SECONDS


func _strafe_target() -> Vector3:
	var center := global_position
	if _observed_player != null:
		center = _observed_player.global_position
	center.y = 0.0
	var ring := Vector2.from_angle(_strafe_angle) * _strafe_radius
	var weave := Vector2.from_angle(_strafe_angle + PI * 0.5)
	weave *= sin(_strafe_clock * STRAFE_WEAVE_FREQUENCY) * _strafe_weave
	var target := center + _flight_space.screen_motion_to_combat(ring + weave)
	var bounds := _flight_space.get_combat_bounds(-HITBOX_MARGIN_PIXELS)
	target.x = clampf(target.x, bounds.position.x, bounds.end.x)
	target.z = clampf(target.z, bounds.position.y, bounds.end.y)
	return target


func _advance_strafe(delta: float, speed_scale: float = 1.0) -> void:
	speed_scale = maxf(speed_scale, STRAFE_MINIMUM_SPEED_SCALE)
	if _observed_player == null or _flight_space == null:
		_integrate_velocity(delta)
		return
	_strafe_clock += delta
	var angular_rate := (
		maxf(_strafe_tangential, STRAFE_MINIMUM_TANGENTIAL_PIXELS) / maxf(_strafe_radius, 1.0)
	)
	_strafe_angle += angular_rate * _strafe_sign * speed_scale * delta
	var to_target := _strafe_target() - global_position
	to_target.y = 0.0
	var desired_screen := _flight_space.combat_motion_to_screen(to_target).normalized()
	var current_screen := _flight_space.combat_motion_to_screen(_heading).normalized()
	if desired_screen.is_zero_approx():
		desired_screen = current_screen
	if current_screen.is_zero_approx():
		current_screen = desired_screen
	if desired_screen.is_zero_approx():
		_integrate_velocity(delta)
		return
	var turn := clampf(
		current_screen.angle_to(desired_screen),
		-STRAFE_STEERING_RATE_RADIANS * delta,
		STRAFE_STEERING_RATE_RADIANS * delta
	)
	var new_screen := current_screen.rotated(turn)
	_heading = _flight_space.input_to_combat_direction(new_screen)
	_configure_movement_from_screen(new_screen * speed_scale)
	_update_facing(_heading)
	_integrate_velocity(delta)


func _tick_engagement(delta: float) -> bool:
	if state == State.WITHDRAW:
		return false
	_engagement_timer = maxf(0.0, _engagement_timer - delta)
	return _engagement_timer <= 0.0


func _begin_withdraw() -> void:
	var outward := _heading
	if _observed_player != null:
		var away := global_position - _observed_player.global_position
		away.y = 0.0
		if not away.is_zero_approx():
			outward = away.normalized()
	var bounds := _flight_space.get_combat_bounds()
	var from_center := Vector2(global_position.x, global_position.z) - bounds.get_center()
	var screen_out := _flight_space.combat_motion_to_screen(outward).normalized()
	if from_center.length_squared() > 1.0:
		screen_out = (screen_out + from_center.normalized()).normalized()
	if screen_out.is_zero_approx():
		screen_out = Vector2.DOWN
	_heading = _flight_space.input_to_combat_direction(screen_out)
	_configure_movement_from_screen(screen_out * WITHDRAW_SPEED_MULTIPLIER)
	_update_facing(_heading)
	play_motion(&"cruise")
	_enter(State.WITHDRAW)


func _advance_movement(delta: float) -> void:
	if not _is_basic_lineage():
		_integrate_velocity(delta)
		return
	_observe_player()
	_evade_cooldown = maxf(0.0, _evade_cooldown - delta)
	match state:
		State.CHARGE_WINDUP:
			_advance_strafe(delta, CHARGE_WINDUP_SPEED_SCALE)
			state_remaining = maxf(0.0, state_remaining - delta)
			if state_remaining <= 0.0:
				play_motion(&"attack", CHARGE_DURATION_SECONDS)
				charge_released.emit(
					get_combat_position(),
					_flight_space.screen_motion_to_combat(_charge_screen_direction)
				)
				_enter(State.CHARGE, CHARGE_DURATION_SECONDS)
			return
		State.CHARGE:
			var charge_velocity := _flight_space.screen_motion_to_combat(
				_charge_screen_direction * _speed_pixels * CHARGE_SPEED_MULTIPLIER
			)
			velocity = Vector3(charge_velocity.x, 0.0, charge_velocity.z)
			_heading = _flight_space.input_to_combat_direction(_charge_screen_direction)
			_update_facing(_heading)
			_integrate_velocity(delta)
			state_remaining = maxf(0.0, state_remaining - delta)
			if state_remaining <= 0.0:
				_strafe_angle += _strafe_sign * 0.9
				_enter(State.RECOVERY, 0.25)
			return
		State.RECOVERY:
			_advance_strafe(delta, 0.75)
			state_remaining = maxf(0.0, state_remaining - delta)
			if state_remaining <= 0.0:
				_enter(State.TRANSIT)
			return
		State.EVADE:
			_advance_strafe(delta, 1.05)
			state_remaining = maxf(0.0, state_remaining - delta)
			if state_remaining <= 0.0:
				_enter(State.TRANSIT)
			return
		State.WITHDRAW:
			_integrate_velocity(delta)
			return
		_:
			pass
	if _tick_engagement(delta):
		_begin_withdraw()
		return
	if generation >= 3 and state == State.TRANSIT:
		_evade_scan_timer -= delta
		if _evade_scan_timer <= 0.0:
			_evade_scan_timer = EVADE_SCAN_SECONDS
			if _try_begin_evade():
				return
		if _try_begin_charge():
			return
	_advance_strafe(delta)


func _enter(next: State, duration: float = 0.0) -> void:
	if state == next:
		return
	var previous := state
	state = next
	state_remaining = maxf(0.0, duration)
	state_changed.emit(previous, next)


func _observe_player() -> void:
	_observed_player = get_tree().get_first_node_in_group(&"player_craft") as Node3D
	if _observed_player == null or _flight_space == null:
		_player_distance_pixels = 0.0
		_player_radial_speed = 0.0
		_predicted_player = global_position
		return
	var offset := _flight_space.combat_motion_to_screen(
		_observed_player.global_position - global_position
	)
	_player_distance_pixels = offset.length()
	var speed := Vector3.ZERO
	if _observed_player is Player3D:
		speed = _observed_player.velocity
	var screen_speed := _flight_space.combat_motion_to_screen(speed)
	_player_radial_speed = (
		0.0 if offset.is_zero_approx() else screen_speed.dot(offset.normalized())
	)
	var lead := (screen_speed * PREDICTION_SECONDS).limit_length(MAXIMUM_PREDICTION_PIXELS)
	_predicted_player = _observed_player.global_position + _flight_space.screen_motion_to_combat(lead)
	var bounds := _flight_space.get_combat_bounds(-HITBOX_MARGIN_PIXELS)
	_predicted_player.x = clampf(_predicted_player.x, bounds.position.x, bounds.end.x)
	_predicted_player.z = clampf(_predicted_player.z, bounds.position.y, bounds.end.y)


func _find_incoming_projectile() -> Projectile:
	if _flight_space == null:
		return null
	var alert_squared := PROJECTILE_ALERT_PIXELS * PROJECTILE_ALERT_PIXELS
	for node in get_tree().get_nodes_in_group(&"player_projectiles"):
		var projectile := node as Projectile
		if projectile == null or not projectile.is_active:
			continue
		var offset := _flight_space.combat_motion_to_screen(
			global_position - projectile.global_position
		)
		if offset.is_zero_approx() or offset.length_squared() > alert_squared:
			continue
		var shot_direction := _flight_space.combat_motion_to_screen(projectile.velocity).normalized()
		if shot_direction.dot(offset.normalized()) <= 0.78:
			continue
		return projectile
	return null


func _try_begin_evade() -> bool:
	if _evade_cooldown > 0.0 or state != State.TRANSIT:
		return false
	var projectile := _find_incoming_projectile()
	if projectile == null:
		return false
	var shot_direction := _flight_space.combat_motion_to_screen(projectile.velocity).normalized()
	var side := Vector2(-shot_direction.y, shot_direction.x)
	var shift := _choose_shift(side, EVADE_DISTANCE_PIXELS)
	if shift.is_zero_approx():
		return false
	global_position += shift
	global_position.y = 0.0
	_strafe_angle += _strafe_sign * 0.45
	_strafe_radius = clampf(_strafe_radius + (28.0 if randf() < 0.5 else -28.0), 130.0, 360.0)
	_evade_cooldown = EVADE_COOLDOWN_SECONDS
	_heading = _flight_space.input_to_combat_direction(
		_flight_space.combat_motion_to_screen(shift).normalized()
	)
	_update_facing(_heading)
	play_motion(&"attack", EVADE_DURATION_SECONDS)
	_enter(State.EVADE, EVADE_DURATION_SECONDS)
	return true


func _try_begin_charge() -> bool:
	if _charge_used or _time_alive < 0.35 or state != State.TRANSIT:
		return false
	if _observed_player == null:
		return false
	var to_player := _flight_space.combat_motion_to_screen(
		_observed_player.global_position - global_position
	)
	if to_player.length() > CHARGE_TRIGGER_DISTANCE_PIXELS or to_player.is_zero_approx():
		return false
	_charge_used = true
	_charge_screen_direction = to_player.normalized()
	play_motion(&"windup", CHARGE_TELEGRAPH_SECONDS, true)
	charge_started.emit(
		get_combat_position(),
		_flight_space.screen_motion_to_combat(_charge_screen_direction)
	)
	_enter(State.CHARGE_WINDUP, CHARGE_TELEGRAPH_SECONDS)
	return true


func _choose_shift(screen_side: Vector2, pixels: float) -> Vector3:
	var direction := _flight_space.screen_motion_to_combat(screen_side.normalized() * pixels)
	if randf() < 0.5:
		direction = -direction
	var first := _trim_shift(direction)
	var opposite := _trim_shift(-direction)
	return first if first.length_squared() >= opposite.length_squared() else opposite


func _trim_shift(shift: Vector3) -> Vector3:
	var bounds := _flight_space.get_combat_bounds(-HITBOX_MARGIN_PIXELS)
	var target := global_position + shift
	target.x = clampf(target.x, bounds.position.x, bounds.end.x)
	target.z = clampf(target.z, bounds.position.y, bounds.end.y)
	var fraction := 1.0
	if not is_zero_approx(shift.x):
		fraction = minf(fraction, (target.x - global_position.x) / shift.x)
	if not is_zero_approx(shift.z):
		fraction = minf(fraction, (target.z - global_position.z) / shift.z)
	return shift * clampf(fraction, 0.0, 1.0)


func _integrate_velocity(delta: float) -> void:
	global_position += velocity * delta
	global_position.y = 0.0


func _health_fraction() -> float:
	if max_health <= 0:
		return 1.0
	return clampf(float(health) / float(max_health), 0.0, 1.0)


func _inside_view() -> bool:
	if _flight_space == null:
		return false
	return _flight_space.get_combat_bounds().has_point(
		Vector2(global_position.x, global_position.z)
	)


func take_damage(amount: int) -> void:
	if not is_active or amount <= 0:
		return
	health -= amount
	if health <= 0:
		_finish(FinishReason.DESTROYED)
	else:
		_flash_time_left = 0.15
		play_motion(&"hit")


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


func get_debug_state() -> Dictionary:
	return {
		"state": State.keys()[state],
		"state_remaining": state_remaining,
		"generation": generation,
		"health": health,
		"player_distance": _player_distance_pixels,
		"player_radial_speed": _player_radial_speed,
		"charge_used": _charge_used,
		"strafe_angle": _strafe_angle,
		"engagement_remaining": _engagement_timer,
	}


func _on_area_entered(area: Area3D) -> void:
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
		manager.queue_seeker_fragment(marker.global_position, fragment_direction)


func _refresh_exit_bounds() -> void:
	_exit_bounds = _flight_space.get_combat_bounds(EXIT_MARGIN_PIXELS)


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


func play_motion(clip: StringName, seconds: float = 0.0, hold: bool = false) -> void:
	for motion in _motions:
		if motion.model_root.visible:
			motion.play(clip, seconds, hold)
	_sync_motion_sockets()


func advance_motion(delta: float) -> void:
	for motion in _motions:
		if motion.model_root.visible:
			motion.advance(delta)
	_sync_motion_sockets()


func _bind_motion_sockets(model: Node3D) -> void:
	var aliases := {"MuzzleCenter": "Socket_Muzzle", "LaserOrigin": "Socket_Muzzle",
		"EngineLeft": "Socket_EngineLeft", "EngineRight": "Socket_EngineRight",
		"BombBayLeft": "Socket_PayloadLeft", "BombBayRight": "Socket_PayloadRight"}
	for wrapper_name in aliases:
		var wrapper := sockets.get_node_or_null(NodePath(wrapper_name)) as Node3D
		var authored := model.find_child(aliases[wrapper_name], true, false) as Node3D
		if wrapper != null and authored != null:
			_animated_sockets.append([wrapper, authored])


func _sync_motion_sockets() -> void:
	for pair in _animated_sockets:
		pair[0].global_transform = ShipMotion.socket_transform(pair[1])
