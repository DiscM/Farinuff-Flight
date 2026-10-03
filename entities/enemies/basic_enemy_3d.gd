extends Area3D
class_name BasicEnemy3D
## Scene-managed Basic Enemy lineage. The native wrapper owns the shared
## contact/damage lifecycle while generation-specific movement and death
## behavior stay in the wrapper; score/orb authority is routed by the native
## gameplay controller.
## Regular-enemy combat runs an explicit finite-state machine in the BossAI
## style: a shared State vocabulary, one state boundary per tick, and
## observation (distance, radial speed, capped prediction) feeding decisions.
## Normal flight follows a player-relative strafe ring; combat maneuvers
## commit short paths with their own timing and defensive windows.

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
	REFLECT_WINDUP,
	REFLECT_ROLL,
	TACTICAL_WINDUP,
	SPLIT_S,
	IMMELMANN,
	SCISSORS,
	CORKSCREW,
	KNIFE_EDGE,
	HIGH_YO_YO,
	LOW_YO_YO,
	HAMMERHEAD,
	BOMBING_RUN,
	BOMB_WINDUP,
	RAIL_AIM,
}

const MANEUVER_STATES := [State.SPLIT_S, State.IMMELMANN, State.SCISSORS,
	State.CORKSCREW, State.KNIFE_EDGE, State.HIGH_YO_YO, State.LOW_YO_YO,
	State.HAMMERHEAD, State.BOMBING_RUN]

const FlightSpace := preload("res://systems/flight_space_3d.gd")
const PhysicsLayers := preload("res://systems/native_3d_physics_layers.gd")
const GenerationStats := preload("res://entities/enemies/enemy_generation_stats.gd")
const NativeHazardManager := preload("res://systems/native_hazard_manager_3d.gd")
const Projectile := preload("res://entities/projectiles/projectile_3d.gd")
const EXIT_MARGIN_PIXELS := 80.0
const SurfaceMaterials := preload("res://effects/rendering/enemy_surface_materials.gd")
const ShipMotion := preload("res://effects/ship_motion_3d.gd")
const FlightMotion := preload("res://effects/enemy_flight_motion_3d.gd")
const ReflectTell := preload("res://effects/enemy_reflect_tell_3d.gd")
const ManeuverPath := preload("res://entities/enemies/enemy_maneuver_path.gd")
const ReflectionDefense := preload("res://entities/enemies/enemy_reflection_defense.gd")
const Tactics := preload("res://systems/enemy_tactics_3d.gd")
const ManeuverAttack := preload("res://systems/enemy_maneuver_attack_3d.gd")
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
const PROJECTILE_ALERT_PIXELS := 340.0
const EVADE_SCAN_SECONDS := 0.12
const EVADE_COOLDOWN_SECONDS := 2.5
const EVADE_DISTANCE_PIXELS := 420.0
const EVADE_DURATION_SECONDS := 0.65
const REFLECT_ALERT_PIXELS := 520.0
const REFLECT_WARNING_SECONDS := 0.3
const REFLECT_ROLL_SECONDS := 0.85
const REFLECT_COOLDOWN_SECONDS := 4.0
const REFLECT_MAX_SHOTS := 3
const FLIGHT_RESPONSE := 10.0
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
@export var flight_style: FlightMotion.Style = FlightMotion.Style.FIGHTER

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visuals: Node3D = $Visuals
@onready var attachments: Node3D = $Attachments
@onready var sockets: Node3D = $Attachments/Sockets
@onready var _authored_visual_transform: Transform3D = visuals.transform
@onready var _authored_attachment_transform: Transform3D = attachments.transform
@onready var _authored_collision_scale: Vector3 = collision_shape.scale

@export var archetype_id: StringName = &"basic"
var is_active := false
var health: int = 0
var max_health: int = 0
var velocity := Vector3.ZERO
var state: State = State.TRANSIT
var state_remaining := 0.0
var combat_scale := 1.0

var _flight_space: FlightSpace
var _active_stats: GenerationStats
var _exit_bounds := Rect2()
var _heading := Vector3.BACK
var _speed_pixels := 0.0
var _meshes: Array[MeshInstance3D] = []
var _animation_time := 0.0
var _flash_time_left := 0.0
var _motions: Array[ShipMotion] = []
var _flight_motion: FlightMotion
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
var _defense := ReflectionDefense.new()
var _reflect_tell: ReflectTell
var _maneuver := ManeuverPath.new()
var _withdraw_velocity := Vector3.ZERO
var _tactics := Tactics.new()
var _maneuver_attack := ManeuverAttack.new()


func _ready() -> void:
	set_physics_process(false)
	_flight_motion = FlightMotion.new(visuals, sockets, flight_style)
	for model in visuals.get_children():
		if model is Node3D and model.find_child("AnimationPlayer", true, false) != null:
			_motions.append(ShipMotion.new(model))
			_motions[-1].blend_seconds = 0.1
			_bind_motion_sockets(model)
	_sync_motion_sockets()
	SurfaceMaterials.apply_to(visuals, surface_style, surface_pixel_density)
	for node in visuals.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(node as MeshInstance3D)
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
	combat_scale = flight_space.configuration.enemy_scale_multiplier
	var presentation_scale := Vector3.ONE * combat_scale
	visuals.transform = _authored_visual_transform.scaled(presentation_scale)
	attachments.transform = _authored_attachment_transform.scaled(presentation_scale)
	collision_shape.scale = _authored_collision_scale
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
	_defense.reset(get_instance_id() % 2 == 0)
	_maneuver.duration = 0.0
	_tactics.reset(get_instance_id())
	_maneuver_attack.cancel()
	if _reflect_tell != null:
		_reflect_tell.hide()
	_evade_scan_timer = randf_range(0.0, EVADE_SCAN_SECONDS)
	_strafe_radius = DEFAULT_STRAFE_RADIUS_PIXELS
	_strafe_tangential = DEFAULT_STRAFE_TANGENTIAL_PIXELS
	_strafe_weave = DEFAULT_STRAFE_WEAVE_PIXELS
	_configure_movement()
	# Archetypes configure generation-specific envelopes; enlarge the final shape.
	collision_shape.scale *= combat_scale
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
	_flight_motion.reset(global_rotation.y + visuals.rotation.y, get_instance_id())
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
	target = _tactics.adjust_target(self, target)
	var bounds := _flight_space.get_combat_bounds(-HITBOX_MARGIN_PIXELS)
	target.x = clampf(target.x, bounds.position.x, bounds.end.x)
	target.z = clampf(target.z, bounds.position.y, bounds.end.y)
	return target


func _advance_strafe(delta: float, speed_scale: float = 1.0, face_flight: bool = true) -> void:
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
	var current_speed := _flight_space.combat_motion_to_screen(velocity).length()
	var speed := lerpf(current_speed, _speed_pixels * speed_scale, 1.0 - exp(-FLIGHT_RESPONSE * delta))
	_configure_movement_from_screen(new_screen * speed / maxf(_speed_pixels, 0.001))
	if face_flight:
		_update_facing(_heading, delta)
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
	_withdraw_velocity = _flight_space.screen_motion_to_combat(screen_out * _speed_pixels * WITHDRAW_SPEED_MULTIPLIER)
	play_motion(&"cruise")
	_enter(State.WITHDRAW)


func _advance_movement(delta: float) -> void:
	if not _is_basic_lineage():
		_integrate_velocity(delta)
		return
	if _advance_combat_state(delta):
		return
	if _advance_defense(delta):
		return
	match state:
		State.CHARGE_WINDUP:
			_advance_strafe(delta, CHARGE_WINDUP_SPEED_SCALE)
			state_remaining = maxf(0.0, state_remaining - delta)
			if state_remaining <= 0.0:
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
			_advance_velocity(charge_velocity, delta)
			state_remaining = maxf(0.0, state_remaining - delta)
			if state_remaining <= 0.0:
				_strafe_angle += _strafe_sign * 0.9
				_enter(State.TRANSIT)
			return
		State.WITHDRAW:
			_advance_velocity(_withdraw_velocity, delta)
			return
		_:
			pass
	if _tick_engagement(delta):
		_begin_withdraw()
		return
	if _try_begin_tactical_maneuver():
		return
	if generation >= 2 and state == State.TRANSIT:
		_evade_scan_timer -= delta
		if _evade_scan_timer <= 0.0:
			_evade_scan_timer = EVADE_SCAN_SECONDS
			if _try_begin_defense():
				return
		if generation >= 3 and _try_begin_charge():
			return
	_advance_strafe(delta)


func _advance_combat_state(delta: float) -> bool:
	_observe_player()
	_evade_cooldown = maxf(0.0, _evade_cooldown - delta)
	_defense.advance(delta)
	_tactics.tick(self, delta)
	match state:
		State.TACTICAL_WINDUP:
			_advance_strafe(delta, 0.5)
			global_position = _clamp_maneuver_point(global_position)
			_tactics.update_warning(self)
			_maneuver_attack.update_warning(self)
			state_remaining = maxf(0.0, state_remaining - delta)
			if state_remaining <= 0.0:
				_enter(_tactics._flight_state as State, _tactics._duration)
			return true
		_:
			if state in MANEUVER_STATES:
				state_remaining = maxf(0.0, state_remaining - delta)
				var progress := 1.0 - state_remaining / _tactics._duration
				_tactics.advance_path(self, progress, delta)
				_maneuver_attack.advance(self, progress)
				_on_tactical_flight(_tactics._action, progress)
				if state_remaining <= 0.0:
					_enter(_maneuver_entry_state())
				return true
	return false


func _supports_maneuver(action: Tactics.Action) -> bool:
	return _is_basic_lineage() and _supports_fighter_maneuver(action)


func _supports_fighter_maneuver(action: Tactics.Action) -> bool:
	match action:
		Tactics.Action.IMMELMANN:
			return generation >= 2
		Tactics.Action.SPLIT_S, Tactics.Action.SCISSORS, Tactics.Action.CORKSCREW, Tactics.Action.HAMMERHEAD:
			return generation >= 3
		Tactics.Action.HIGH_YO_YO, Tactics.Action.LOW_YO_YO:
			return generation >= 4
	return false


func _maneuver_entry_state() -> State:
	return State.TRANSIT


func is_maneuver_committed() -> bool:
	return _tactics.has_plan() and (state == State.TACTICAL_WINDUP or state in MANEUVER_STATES)


func _try_begin_tactical_maneuver() -> bool:
	if not _tactics.prepare_best_plan(self):
		return false
	return _enter_planned_maneuver()


func _begin_tactical_maneuver(action: Tactics.Action, reason: String) -> bool:
	if not _tactics.prepare_plan(self, action, reason):
		return false
	return _enter_planned_maneuver()


func _enter_planned_maneuver() -> bool:
	_evade_cooldown = maxf(_evade_cooldown, 3.0)
	_strafe_sign = _tactics._direction
	_maneuver_attack.prepare(_tactics._action, _tactics._locked_target)
	_on_tactical_plan(_tactics._action, _tactics._locked_target)
	if _tactics._warning > 0.0:
		return _enter(State.TACTICAL_WINDUP, _tactics._warning)
	return _enter(_tactics._flight_state as State, _tactics._duration)


func _enter(next: State, duration: float = 0.0) -> bool:
	if state == next:
		return false
	# A flight state requires a prepared route and its advertised predecessor.
	# Neither debug requests nor another behavior may skip the warning or flight.
	if next == State.TACTICAL_WINDUP:
		if not _tactics.has_plan() or state != _maneuver_entry_state() or _tactics._warning <= 0.0:
			return false
		duration = _tactics._warning
	elif next in MANEUVER_STATES:
		if not _tactics.has_plan() or next != _tactics._flight_state:
			return false
		if state != State.TACTICAL_WINDUP and not (state == _maneuver_entry_state() and _tactics._warning <= 0.0):
			return false
		if state == State.TACTICAL_WINDUP and state_remaining > 0.0:
			return false
		duration = _tactics._duration
	elif next == _maneuver_entry_state() and state in MANEUVER_STATES:
		if state_remaining > 0.0:
			return false
	var previous := state
	_exit_state(next)
	state = next
	state_remaining = maxf(0.0, duration)
	_on_state_entered(previous)
	_flight_motion.react(StringName(State.keys()[next]), _strafe_sign, duration)
	state_changed.emit(previous, next)
	return true


func _exit_state(next: State) -> void:
	if _tactics.has_plan():
		var continuing := false
		if state == _maneuver_entry_state():
			continuing = next == State.TACTICAL_WINDUP or next == _tactics._flight_state
		elif state == State.TACTICAL_WINDUP:
			continuing = next == _tactics._flight_state
		if state == _tactics._flight_state and state_remaining <= 0.0 and next == _maneuver_entry_state():
			_tactics.complete(self)
			_maneuver_attack.cancel()
		elif not continuing:
			_tactics.cancel()
			_maneuver_attack.cancel()
	elif next != _maneuver_entry_state():
		_tactics.discard_followup()
	if state in [State.REFLECT_WINDUP, State.REFLECT_ROLL] and next != State.REFLECT_ROLL:
		_defense.charges = 0
		if is_instance_valid(_reflect_tell):
			_reflect_tell.hide()
	if state in [State.EVADE, State.REPOSITION, State.PHASE_DASH]:
		_maneuver.duration = 0.0
	# Release held bone warnings on an interruption without masking shot recoil.
	for motion in _motions:
		if motion.is_windup():
			motion.play(&"cruise")
	_flight_motion.set_telegraph(false)
	_flight_motion.play(FlightMotion.Maneuver.NONE, 0.0, FlightMotion.BLEND_SECONDS)


func _on_state_entered(_previous: State) -> void:
	match state:
		State.TACTICAL_WINDUP:
			play_motion(&"windup", state_remaining, true)
			_tactics.update_warning(self)
			_maneuver_attack.update_warning(self)
		State.REFLECT_WINDUP:
			play_motion(&"windup", state_remaining, true)
			_update_reflect_tell(false)
		State.REFLECT_ROLL:
			play_motion(&"attack", state_remaining)
			_update_reflect_tell(true)
		State.CHARGE_WINDUP, State.PHASE_WINDUP, State.AIM, State.RAIL_AIM, State.MINE_DEPLOY, State.BOMB_WINDUP, State.BARRAGE, State.OVERLOAD_WINDUP:
			play_motion(&"windup", state_remaining, true)
		State.CHARGE, State.PHASE_DASH, State.EVADE, State.REPOSITION, State.OVERLOAD:
			play_motion(&"attack", state_remaining)
		State.BRACE:
			play_motion(&"windup", state_remaining, true)
			_flight_motion.set_telegraph(false)
		_:
			if state in MANEUVER_STATES:
				_tactics.hide_warning()
				_maneuver_attack.update_warning(self)
				play_motion(&"attack", state_remaining)


func _on_tactical_plan(_action: int, _target: Vector3) -> void:
	pass


func _on_tactical_flight(_action: int, _progress: float) -> void:
	pass


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


func _find_incoming_projectile(alert_pixels: float = PROJECTILE_ALERT_PIXELS) -> Projectile:
	if _flight_space == null:
		return null
	var alert_squared := alert_pixels * alert_pixels
	var nearest: Projectile
	for node in get_tree().get_nodes_in_group(&"player_projectiles"):
		var projectile := node as Projectile
		if projectile == null or not projectile.is_active:
			continue
		var offset := _flight_space.combat_motion_to_screen(
			global_position - projectile.global_position
		)
		if offset.is_zero_approx() or offset.length_squared() > alert_squared:
			continue
		if not Tactics.threatens(self, projectile, 1.5):
			continue
		nearest = projectile
		alert_squared = offset.length_squared()
	return nearest


func _try_begin_evade() -> bool:
	if _evade_cooldown > 0.0 or state != State.TRANSIT:
		return false
	var projectile := _find_incoming_projectile()
	if projectile == null:
		return false
	return _begin_barrel_dodge(projectile)


func _try_begin_defense() -> bool:
	if state != State.TRANSIT or _evade_cooldown > 0.0 or not _inside_view():
		return false
	var threat := _find_incoming_projectile(REFLECT_ALERT_PIXELS)
	if threat == null:
		return false
	if _defense.prefer_reflect and _try_begin_reflect(threat):
		return true
	var distance := _flight_space.combat_motion_to_screen(threat.global_position - global_position).length()
	if distance < PROJECTILE_ALERT_PIXELS and _begin_barrel_dodge(threat):
		return true
	return distance < PROJECTILE_ALERT_PIXELS and _try_begin_reflect(threat)


func _try_begin_reflect(threat: Projectile) -> bool:
	if generation < 2 or state != State.TRANSIT or _defense.cooldown > 0.0 or _evade_cooldown > 0.0 or not _inside_view():
		return false
	if not is_instance_valid(threat) or not threat.is_active:
		return false
	var offset := _flight_space.combat_motion_to_screen(global_position - threat.global_position)
	var relative_velocity := _flight_space.combat_motion_to_screen(threat.velocity - velocity)
	var radius := _flight_space.combat_motion_to_screen(_maneuver_half_extents()).length()
	if not _defense.begin(offset, relative_velocity, radius, REFLECT_WARNING_SECONDS, REFLECT_COOLDOWN_SECONDS, REFLECT_MAX_SHOTS):
		return false
	_evade_cooldown = EVADE_COOLDOWN_SECONDS
	_enter(State.REFLECT_WINDUP, REFLECT_WARNING_SECONDS)
	return true


func can_reflect_projectile() -> bool:
	return is_active and GameManager.is_game_active and state == State.REFLECT_ROLL and state_remaining > 0.0 and _defense.charges > 0


func consume_reflection() -> void:
	if _defense.consume():
		_enter(State.TRANSIT)
	else:
		_update_reflect_tell(true)


func _update_reflect_tell(armed: bool) -> void:
	if _reflect_tell == null:
		_reflect_tell = ReflectTell.new()
		add_child(_reflect_tell)
	var extent := _maneuver_half_extents()
	_reflect_tell.present(maxf(extent.x, extent.z) * 1.2, armed, _defense.charges)


func _advance_defense(delta: float) -> bool:
	match state:
		State.REFLECT_WINDUP, State.REFLECT_ROLL:
			_advance_strafe(delta, 0.65)
			state_remaining = maxf(0.0, state_remaining - delta)
			if state_remaining <= 0.0:
				if state == State.REFLECT_WINDUP:
					_enter(State.REFLECT_ROLL, REFLECT_ROLL_SECONDS)
				else:
					_enter(State.TRANSIT)
			return true
		State.EVADE:
			_advance_maneuver_path(delta)
			if state_remaining <= 0.0:
				_enter(State.TRANSIT)
			return true
	return false


func _begin_barrel_dodge(projectile: Projectile) -> bool:
	var shot_direction := _flight_space.combat_motion_to_screen(projectile.velocity).normalized()
	var side := Vector2(-shot_direction.y, shot_direction.x)
	var clearance := _dodge_clearance_pixels(side)
	var shift := _choose_maneuver_shift(side, maxf(EVADE_DISTANCE_PIXELS, clearance * 2.4))
	if absf(_flight_space.combat_motion_to_screen(shift).dot(side)) < clearance:
		return false
	var duration := EVADE_DURATION_SECONDS * (0.85 if flight_style == FlightMotion.Style.INTERCEPTOR else 1.0)
	_start_maneuver_path(shift, duration)
	_evade_cooldown = EVADE_COOLDOWN_SECONDS
	_defense.after_dodge(EVADE_COOLDOWN_SECONDS)
	_strafe_sign = signf(side.dot(_flight_space.combat_motion_to_screen(shift)))
	_enter(State.EVADE, duration)
	return true


func _dodge_clearance_pixels(side: Vector2) -> float:
	# Measure the actual scaled contact envelope perpendicular to the shot.
	# Extra travel lets the hull clear the lane before the roll finishes.
	var half_size := (collision_shape.shape as BoxShape3D).size * 0.5
	var contact_basis := collision_shape.global_basis
	var clearance := HITBOX_MARGIN_PIXELS
	clearance += absf(_flight_space.combat_motion_to_screen(contact_basis.x * half_size.x).dot(side))
	clearance += absf(_flight_space.combat_motion_to_screen(contact_basis.z * half_size.z).dot(side))
	return clearance


func _maneuver_half_extents() -> Vector3:
	var size: Vector3 = (collision_shape.shape as BoxShape3D).size
	var contact_basis := collision_shape.global_basis
	return (contact_basis.x.abs() * size.x + contact_basis.y.abs() * size.y + contact_basis.z.abs() * size.z) * 0.5


func _clamp_maneuver_point(point: Vector3) -> Vector3:
	var bounds := _flight_space.get_combat_bounds()
	# A circumscribed footprint remains inside the arena even as the craft turns.
	var half_size: Vector3 = (collision_shape.shape as BoxShape3D).size * collision_shape.global_basis.get_scale().abs() * 0.5
	var radius := Vector2(half_size.x, half_size.z).length()
	return Vector3(clampf(point.x, bounds.position.x + radius, bounds.end.x - radius), 0.0, clampf(point.z, bounds.position.y + radius, bounds.end.y - radius))


func _choose_maneuver_shift(side: Vector2, pixels: float) -> Vector3:
	var shift := _flight_space.screen_motion_to_combat(side.normalized() * pixels * _strafe_sign)
	var first := _clamp_maneuver_point(global_position + shift) - global_position
	var opposite := _clamp_maneuver_point(global_position - shift) - global_position
	var first_score := _flight_space.combat_motion_to_screen(first).length() - _tactics.lane_cost(self, global_position + first)
	var opposite_score := _flight_space.combat_motion_to_screen(opposite).length() - _tactics.lane_cost(self, global_position + opposite)
	return first if first_score >= opposite_score else opposite


func _start_maneuver_path(shift: Vector3, duration: float, bend_pixels: float = -1.0) -> void:
	var target := _clamp_maneuver_point(global_position + shift)
	var bend := minf(150.0, _flight_space.combat_motion_to_screen(shift).length() * 0.32) if bend_pixels < 0.0 else bend_pixels
	var forward := _flight_space.combat_motion_to_screen(_heading).normalized() * bend
	var control := _clamp_maneuver_point(global_position + shift * 0.5 + _flight_space.screen_motion_to_combat(forward))
	_maneuver.begin(global_position, control, target, duration, velocity, _cruise_velocity(target - control))


func _advance_maneuver_path(delta: float) -> void:
	var step := minf(delta, state_remaining)
	state_remaining = maxf(0.0, state_remaining - delta)
	if _maneuver.duration <= 0.0:
		_advance_strafe(delta)
		return
	var next := _maneuver.sample(state_remaining, state == State.EVADE)
	next = _clamp_maneuver_point(next)
	velocity = (next - global_position) / maxf(step, 0.0001)
	global_position = next
	if state_remaining <= 0.0:
		velocity = _maneuver.exit_velocity
	if velocity.length_squared() > 0.001:
		_heading = velocity.normalized()
		_update_facing(_heading, delta)
	if state_remaining <= 0.0:
		_maneuver.duration = 0.0
		if is_instance_valid(_observed_player):
			var offset := _flight_space.combat_motion_to_screen(global_position - _observed_player.global_position)
			_strafe_angle = offset.angle()
			_strafe_radius = clampf(offset.length(), 110.0, 420.0)


func _try_begin_charge() -> bool:
	if _charge_used or _time_alive < 0.35 or state != State.TRANSIT:
		return false
	if not _tactics.attack_slot_available(self):
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
	charge_started.emit(
		get_combat_position(),
		_flight_space.screen_motion_to_combat(_charge_screen_direction)
	)
	_enter(State.CHARGE_WINDUP, CHARGE_TELEGRAPH_SECONDS)
	return true


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
	_tactics.record_damage(float(amount) / maxf(float(max_health), 1.0))
	health -= amount
	if health <= 0:
		_finish(FinishReason.DESTROYED)
	else:
		_flash_time_left = 0.15
		play_motion(&"hit")


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
		"flight_maneuver": FlightMotion.Maneuver.keys()[_flight_motion.current_maneuver],
		"reflecting": can_reflect_projectile(),
		"reflect_charges": _defense.charges,
		"reflect_cooldown": _defense.cooldown,
		"tactics": _tactics.debug_state(),
		"maneuver_attack": _maneuver_attack.debug_state(),
	}


func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group(&"player_craft"):
		_finish(FinishReason.CONTACT)


func _finish(reason: FinishReason) -> void:
	if not is_active:
		return
	is_active = false
	_tactics.cancel()
	_maneuver_attack.cancel()
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
	_exit_bounds = _flight_space.get_combat_bounds(EXIT_MARGIN_PIXELS * combat_scale)


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


func _cruise_velocity(direction: Vector3) -> Vector3:
	return _flight_space.screen_motion_to_combat(_flight_space.combat_motion_to_screen(direction).normalized() * _speed_pixels)


func _advance_velocity(desired: Vector3, delta: float) -> void:
	velocity = velocity.lerp(desired, 1.0 - exp(-FLIGHT_RESPONSE * delta))
	if not velocity.is_zero_approx():
		_heading = velocity.normalized()
		_update_facing(_heading, delta)
	_integrate_velocity(delta)


func _update_facing(direction: Vector3, delta: float = 0.0) -> void:
	if direction.is_zero_approx():
		return
	var target := atan2(-direction.x, -direction.z)
	if delta <= 0.0:
		rotation.y = target
		return
	var turn := angle_difference(rotation.y, target) * (1.0 - exp(-FLIGHT_RESPONSE * delta))
	rotation.y += clampf(turn, -TAU * delta, TAU * delta)


func play_motion(clip: StringName, seconds: float = 0.0, hold: bool = false) -> void:
	# State-specific articulation complements the flight maneuver on Visuals.
	var prefix := ""
	if state in [State.CHARGE_WINDUP, State.CHARGE] and archetype_id == &"basic":
		prefix = "charge"
	elif state in [State.PHASE_WINDUP, State.PHASE_DASH] and archetype_id in [&"fast", &"courier"]:
		prefix = "phase"
	elif state in [State.MINE_DEPLOY, State.BOMB_WINDUP] and archetype_id == &"bomber":
		prefix = "deploy"
	elif state in [State.BARRAGE, State.OVERLOAD_WINDUP, State.OVERLOAD] and archetype_id == &"tank":
		prefix = "radial"
	elif state in [State.AIM, State.RAIL_AIM] and archetype_id == &"sniper":
		prefix = "rail"
	if not prefix.is_empty() and clip in [&"windup", &"attack"]:
		clip = StringName(prefix + "_" + String(clip))
	if clip == &"windup" or String(clip).ends_with("_windup"):
		_flight_motion.set_telegraph(true)
	elif clip == &"cruise" or clip == &"attack" or String(clip).ends_with("_attack"):
		_flight_motion.set_telegraph(false)
	for motion in _motions:
		if motion.model_root.visible:
			motion.play(clip, seconds, hold)
	_sync_motion_sockets()


func advance_motion(delta: float) -> void:
	_flight_motion.advance(
		delta, global_rotation.y + visuals.rotation.y,
		bool(SaveManager.get_setting("reduced_motion", false))
	)
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
	_flight_motion.sync_sockets()
	for pair in _animated_sockets:
		pair[0].global_transform = ShipMotion.socket_transform(pair[1])
