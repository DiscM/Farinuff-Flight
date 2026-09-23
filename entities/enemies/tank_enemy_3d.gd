extends BasicEnemy3D
class_name TankEnemy3D
## Native Tank. A slow close strafe ring, timed radial bursts, orbiting armor,
## and a coordinated overload run as an explicit finite-state machine. The
## tank braces its plates under pressure and overloads faster as it takes
## damage, and it never stops moving between attacks.

signal burst_fired(shot_count: int)

const ProjectileManager := preload("res://systems/projectile_manager_3d.gd")
const Plate3D := preload("res://entities/enemies/tank_plate_3d.gd")
const TankStats := preload("res://entities/enemies/enemy_generation_stats.gd")
const TANK_GENERATION_STATS := [
	preload("res://entities/enemies/tank_enemy_generation_1.tres"),
	preload("res://entities/enemies/tank_enemy_generation_2.tres"),
	preload("res://entities/enemies/tank_enemy_generation_3.tres"),
	preload("res://entities/enemies/tank_enemy_generation_4.tres"),
]

const FIRST_BURST_MIN_SECONDS := 0.5
const ARMOR_PLATE_COUNT := 3
const ARMOR_ORBIT_RADIUS_PIXELS := 43.0
const ARMOR_RADIUS_STEP_PIXELS := 3.0
const HULL_PRESENTATION_SCALE := 1.75
const SHOT_SPEED_EVEN_PIXELS := 245.0
const SHOT_SPEED_ODD_PIXELS := 305.0
const SHOT_SPEED_VARIANCE_PIXELS := 8.0
const BARRAGE_WINDUP_SECONDS := 0.35
const DOUBLE_RING_DELAY := 0.35
const OVERLOAD_INTERVAL := 9.0
const OVERLOAD_WARNING_SECONDS := 1.0
const OVERLOAD_STEP_SECONDS := 0.1
const OVERLOAD_STEPS := 16
const OVERLOAD_RECOVERY_SECONDS := 0.6
const BRACE_DURATION_SECONDS := 1.2
const BRACE_COOLDOWN_SECONDS := 3.5
const BRACE_RADIUS_PIXELS := 200.0
const BRACE_RADIUS_HURT_PIXELS := 260.0
const BRACE_ORBIT_SCALE := 0.55
const STRAFE_RADIUS_PIXELS := 185.0
const STRAFE_TANGENTIAL_PIXELS := 85.0
const STRAFE_WEAVE_PIXELS := 28.0
const BRACE_SPEED_SCALE := 0.55
const OVERLOAD_SPEED_SCALE := 0.45
const WINDUP_SPEED_SCALE := 0.7

@export_range(1, 16, 1) var bullet_count: int = 8
@export_range(0.1, 10.0, 0.1) var burst_interval: float = 2.5

@onready var armor_plates_root: Node3D = $Attachments/ArmorPlates
@onready var overload_warning: MeshInstance3D = $Attachments/OverloadWarning

var _second_ring_timer := -1.0
var _visible_time := 0.0
var _overload_step_timer := 0.0
var _overload_shots := 0
var _overload_angle := 0.0
var _overload_timer := OVERLOAD_INTERVAL
var _coordinator: SpecialAttackCoordinator
var _burst_timer := 0.0
var _brace_cooldown := 0.0
var _armor_plates: Array[Plate3D] = []
var _plate_base_radius := ARMOR_ORBIT_RADIUS_PIXELS * 1.3 * HULL_PRESENTATION_SCALE
var _braced := false


func _ready() -> void:
	super._ready()
	for child in armor_plates_root.get_children():
		var plate := child as Plate3D
		if plate == null:
			continue
		_armor_plates.append(plate)


func activate_generation(
	flight_space: FlightSpace,
	combat_position: Vector3,
	direction: Vector3,
	generation_override: int
) -> bool:
	var activated := super.activate_generation(
		flight_space, combat_position, direction, generation_override
	)
	if activated:
		_configure_armor_plates()
	return activated


func _is_basic_lineage() -> bool:
	return false


func _get_generation_stats() -> TankStats:
	if generation == 1 and gameplay_stats != null:
		return gameplay_stats
	return TANK_GENERATION_STATS[generation - 1] as TankStats


func _configure_movement() -> void:
	_configure_strafe(STRAFE_RADIUS_PIXELS, STRAFE_TANGENTIAL_PIXELS, STRAFE_WEAVE_PIXELS)
	_configure_movement_from_screen(
		_flight_space.combat_motion_to_screen(_heading).normalized()
	)
	var gameplay := get_tree().get_first_node_in_group(&"native_3d_gameplay")
	_coordinator = (
		gameplay.get_node_or_null("GameplayManagers/SpecialAttackCoordinator")
		as SpecialAttackCoordinator
		if gameplay != null
		else null
	)
	_second_ring_timer = -1.0
	_visible_time = 0.0
	_overload_timer = _overload_interval_seconds()
	_brace_cooldown = 0.0
	_braced = false
	overload_warning.hide()
	var warning_radius := 64.0 * HULL_PRESENTATION_SCALE
	var horizontal := _flight_space.screen_motion_to_combat(Vector2(warning_radius, 0.0)).length()
	var vertical := _flight_space.screen_motion_to_combat(Vector2(0.0, warning_radius)).length()
	overload_warning.global_basis = Basis.IDENTITY.scaled(Vector3(horizontal, 1.0, vertical))
	_burst_timer = randf_range(FIRST_BURST_MIN_SECONDS, burst_interval)
	state = State.TRANSIT
	state_remaining = 0.0


func _configure_armor_plates() -> void:
	var plates_enabled := generation >= 2
	_plate_base_radius = (
		(ARMOR_ORBIT_RADIUS_PIXELS + float(generation - 2) * ARMOR_RADIUS_STEP_PIXELS)
		* 1.3
		* HULL_PRESENTATION_SCALE
	)
	for index in _armor_plates.size():
		var plate := _armor_plates[index]
		if not is_instance_valid(plate):
			continue
		if not plates_enabled:
			plate.deactivate()
			continue
		plate.configure(
			self,
			_flight_space,
			TAU * float(index) / float(ARMOR_PLATE_COUNT),
			_plate_base_radius
		)


func _advance_movement(delta: float) -> void:
	_observe_player()
	_brace_cooldown = maxf(0.0, _brace_cooldown - delta)
	if _second_ring_timer >= 0.0:
		_second_ring_timer -= delta
		if _second_ring_timer <= 0.0:
			_second_ring_timer = -1.0
			_fire_radial_burst(PI / 8.0)
	match state:
		State.BARRAGE:
			_advance_strafe(delta, WINDUP_SPEED_SCALE)
			state_remaining = maxf(0.0, state_remaining - delta)
			if state_remaining <= 0.0:
				_fire_radial_burst()
				if generation >= 3:
					_second_ring_timer = DOUBLE_RING_DELAY
				_enter(State.TRANSIT)
			return
		State.BRACE:
			_advance_strafe(delta, BRACE_SPEED_SCALE)
			state_remaining = maxf(0.0, state_remaining - delta)
			if state_remaining <= 0.0:
				_end_brace()
				_enter(State.TRANSIT)
			return
		State.OVERLOAD_WINDUP:
			_advance_strafe(delta, OVERLOAD_SPEED_SCALE)
			state_remaining = maxf(0.0, state_remaining - delta)
			if state_remaining <= 0.0:
				overload_warning.hide()
				_overload_step_timer = 0.0
				_overload_shots = 0
				_overload_angle = randf_range(0.0, TAU)
				_enter(State.OVERLOAD, OVERLOAD_STEP_SECONDS * OVERLOAD_STEPS)
			return
		State.OVERLOAD:
			_advance_strafe(delta, OVERLOAD_SPEED_SCALE)
			_overload_step_timer -= delta
			if _overload_step_timer <= 0.0:
				_overload_step_timer = OVERLOAD_STEP_SECONDS
				_discharge_overload_step()
				_overload_shots += 1
				if _overload_shots >= OVERLOAD_STEPS:
					_end_overload()
					_enter(State.RECOVERY, OVERLOAD_RECOVERY_SECONDS)
			return
		State.RECOVERY:
			_advance_strafe(delta, WINDUP_SPEED_SCALE)
			state_remaining = maxf(0.0, state_remaining - delta)
			if state_remaining <= 0.0:
				_enter(State.TRANSIT)
			return
		State.WITHDRAW:
			_integrate_velocity(delta)
			return
		_:
			pass
	var in_view := _is_inside_combat_view()
	if not in_view:
		if state != State.TRANSIT:
			_cancel_attacks()
			_enter(State.TRANSIT)
		else:
			_advance_strafe(delta)
		return
	_visible_time += delta
	if _tick_engagement(delta):
		_begin_withdraw()
		return
	if generation >= 2 and _brace_cooldown <= 0.0 and _should_brace():
		_begin_brace()
		return
	if generation >= 4:
		_overload_timer -= delta
		if _overload_timer <= 0.0 and _visible_time >= 0.35 and _try_begin_overload():
			return
	if _burst_timer > BARRAGE_WINDUP_SECONDS and _burst_timer - delta <= BARRAGE_WINDUP_SECONDS:
		play_motion(&"windup", BARRAGE_WINDUP_SECONDS, true)
	_burst_timer -= delta
	if _burst_timer <= 0.0:
		_burst_timer = _burst_interval_seconds()
		play_motion(&"windup", BARRAGE_WINDUP_SECONDS, true)
		_enter(State.BARRAGE, BARRAGE_WINDUP_SECONDS)
		return
	_advance_strafe(delta)


func _burst_interval_seconds() -> float:
	return burst_interval


func _overload_interval_seconds() -> float:
	return OVERLOAD_INTERVAL * lerpf(1.0, 0.55, 1.0 - _health_fraction())


func _should_brace() -> bool:
	if _armor_plates.is_empty() or _braced:
		return false
	var threat_radius := BRACE_RADIUS_PIXELS
	if _health_fraction() < 0.5:
		threat_radius = BRACE_RADIUS_HURT_PIXELS
	if _player_distance_pixels > 0.0 and _player_distance_pixels < threat_radius:
		return true
	return _find_incoming_projectile() != null


func _begin_brace() -> void:
	_braced = true
	_brace_cooldown = BRACE_COOLDOWN_SECONDS
	for plate in _armor_plates:
		if is_instance_valid(plate) and plate.is_active:
			plate.orbit_radius_pixels = _plate_base_radius * BRACE_ORBIT_SCALE
	play_motion(&"windup", BRACE_DURATION_SECONDS, true)
	_enter(State.BRACE, BRACE_DURATION_SECONDS)


func _end_brace() -> void:
	_braced = false
	for plate in _armor_plates:
		if is_instance_valid(plate) and plate.is_active:
			plate.orbit_radius_pixels = _plate_base_radius
	play_motion(&"cruise")


func _is_inside_combat_view() -> bool:
	return _inside_view()


func _fire_radial_burst(angle_offset: float = 0.0) -> void:
	var manager := get_tree().get_first_node_in_group(
		&"native_3d_projectile_manager"
	) as ProjectileManager
	var muzzle := sockets.get_node_or_null("MuzzleCenter") as Marker3D
	if manager == null or not manager.is_ready or muzzle == null:
		return
	play_motion(&"attack")
	for index in range(bullet_count):
		var angle := (TAU / float(bullet_count)) * float(index) + angle_offset
		var screen_direction := Vector2(sin(angle), cos(angle))
		var combat_direction := _flight_space.screen_motion_to_combat(screen_direction)
		var base_speed := SHOT_SPEED_EVEN_PIXELS if index % 2 == 0 else SHOT_SPEED_ODD_PIXELS
		var shot_speed := base_speed + randf_range(-SHOT_SPEED_VARIANCE_PIXELS, SHOT_SPEED_VARIANCE_PIXELS)
		manager.fire_enemy_projectile(muzzle.global_position, combat_direction, shot_speed)
	burst_fired.emit(bullet_count)


func _try_begin_overload() -> bool:
	if state != State.TRANSIT:
		return false
	if not is_instance_valid(_coordinator) or not _coordinator.request_major(self):
		return false
	play_motion(&"windup", OVERLOAD_WARNING_SECONDS, true)
	overload_warning.show()
	_enter(State.OVERLOAD_WINDUP, OVERLOAD_WARNING_SECONDS)
	return true


func _discharge_overload_step() -> void:
	var angle := _overload_angle + float(_overload_shots) * 0.52
	var corridor := _overload_angle + PI
	if absf(wrapf(angle - corridor, -PI, PI)) > PI / 8.0:
		var manager := get_tree().get_first_node_in_group(
			&"native_3d_projectile_manager"
		) as ProjectileManager
		var muzzle := get_socket(&"MuzzleCenter")
		if manager != null and manager.is_ready and muzzle != null:
			play_motion(&"attack")
			manager.fire_enemy_projectile(
				muzzle.global_position,
				_flight_space.screen_motion_to_combat(Vector2.from_angle(angle)),
				260.0
			)


func _end_overload() -> void:
	_overload_timer = _overload_interval_seconds()
	overload_warning.hide()
	if is_instance_valid(_coordinator):
		_coordinator.release_major(self)


func _cancel_attacks() -> void:
	_second_ring_timer = -1.0
	if state in [State.OVERLOAD_WINDUP, State.OVERLOAD]:
		_end_overload()
	if state == State.BRACE:
		_end_brace()
	overload_warning.hide()


func _exit_tree() -> void:
	if is_instance_valid(_coordinator):
		_coordinator.release_major(self)


func _finish(reason: FinishReason) -> void:
	_cancel_attacks()
	for plate in _armor_plates:
		if is_instance_valid(plate):
			plate.deactivate()
	super._finish(reason)


func dev_trigger_ability() -> void:
	_overload_timer = 0.0


func get_attack_status() -> Dictionary:
	var debug := get_debug_state()
	debug["overload_steps"] = _overload_shots
	debug["warning_visible"] = overload_warning.visible
	debug["second_ring_pending"] = _second_ring_timer >= 0.0
	debug["braced"] = _braced
	return debug
