extends BasicEnemy3D
class_name BomberEnemy3D
## Native Bomber. Slow forward travel and bounded perpendicular drift become
## a wide player-relative strafe ring; periodic bomb drops and the pooled
## native mine path keep their frozen cadence without parking the hull.

signal bomb_dropped
signal mine_dropped(is_cluster: bool, leaves_plasma: bool)

const ProjectileManager := preload("res://systems/projectile_manager_3d.gd")
const EnemyMineScript := preload("res://entities/enemies/enemy_mine_3d.gd")
const BomberStats := preload("res://entities/enemies/enemy_generation_stats.gd")
const BOMBER_GENERATION_STATS := [
	preload("res://entities/enemies/bomber_enemy_generation_1.tres"),
	preload("res://entities/enemies/bomber_enemy_generation_2.tres"),
	preload("res://entities/enemies/bomber_enemy_generation_3.tres"),
	preload("res://entities/enemies/bomber_enemy_generation_4.tres"),
]

const BOMB_FIRST_DROP_MIN_SECONDS := 0.5
const BOMB_WINDUP_SECONDS := 0.4
const BOMB_SPEED_MIN_PIXELS := 300.0
const BOMB_SPEED_MAX_PIXELS := 400.0
const MINE_FIRST_DROP_SECONDS := 5.0
const MINE_DEPLOY_SECONDS := 0.35
const EVADE_JINK_SECONDS := 0.9
const STRAFE_RADIUS_PIXELS := 270.0
const STRAFE_TANGENTIAL_PIXELS := 90.0
const RUN_RELEASE_PROGRESS := [0.24, 0.5, 0.76]

@export_range(0.0, 512.0, 1.0) var drift_speed_pixels: float = 120.0
@export_range(0.1, 10.0, 0.1) var bomb_interval: float = 2.0

var _drop_timer := 0.0
var _drop_left := true
var _mine_timer := MINE_FIRST_DROP_SECONDS
var _mine_count := 0
var _route_timer := 0.0
var _hazard_manager: NativeHazardManager
var _run_target := Vector3.ZERO
var _run_releases := 0


func _is_basic_lineage() -> bool:
	return false


func _supports_maneuver(action: Tactics.Action) -> bool:
	return generation >= 3 and action == Tactics.Action.BOMBING_RUN


func _get_generation_stats() -> BomberStats:
	if generation == 1 and gameplay_stats != null:
		return gameplay_stats
	return BOMBER_GENERATION_STATS[generation - 1] as BomberStats


func configure_hazard_manager(manager: NativeHazardManager) -> void:
	_hazard_manager = manager


func _configure_movement() -> void:
	_configure_strafe(
		STRAFE_RADIUS_PIXELS,
		STRAFE_TANGENTIAL_PIXELS,
		drift_speed_pixels * 0.4
	)
	velocity = _flight_space.screen_motion_to_combat(
		_flight_space.combat_motion_to_screen(_heading).normalized() * _speed_pixels
	)
	velocity.y = 0.0
	_drop_timer = randf_range(BOMB_FIRST_DROP_MIN_SECONDS, bomb_interval)
	_drop_left = true
	_mine_timer = MINE_FIRST_DROP_SECONDS
	_mine_count = 0
	_run_releases = 0
	_run_target = Vector3.ZERO
	_route_timer = randf_range(0.65, 1.1)
	state = State.TRANSIT
	state_remaining = 0.0


func _advance_movement(delta: float) -> void:
	if _advance_combat_state(delta):
		return
	var in_view := _is_inside_combat_view()
	match state:
		State.BOMB_WINDUP:
			_advance_strafe(delta, 0.85)
			state_remaining = maxf(0.0, state_remaining - delta)
			if state_remaining <= 0.0:
				_drop_timer = bomb_interval
				_drop_bomb()
				_enter(State.TRANSIT)
			return
		State.MINE_DEPLOY:
			_advance_strafe(delta, 0.85)
			state_remaining = maxf(0.0, state_remaining - delta)
			if state_remaining <= 0.0:
				_try_drop_mine()
				_enter(State.TRANSIT)
			return
		State.EVADE:
			_advance_maneuver_path(delta)
			if state_remaining <= 0.0:
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
	if generation >= 2 and in_view:
		_route_timer -= delta
		if _route_timer <= 0.0:
			_route_timer = 1.1
			_choose_interception_lane()
	_advance_strafe(delta)
	if not in_view:
		return
	_drop_timer -= delta
	if _drop_timer <= BOMB_WINDUP_SECONDS:
		_enter(State.BOMB_WINDUP, BOMB_WINDUP_SECONDS)
		return
	if generation >= 2:
		_mine_timer -= delta
		if _mine_timer <= 0.0 and _can_begin_special():
			_mine_timer = MINE_FIRST_DROP_SECONDS
			_enter(State.MINE_DEPLOY, MINE_DEPLOY_SECONDS)
			return
	if generation >= 3 and _evade_cooldown <= 0.0:
		_evade_scan_timer -= delta
		if _evade_scan_timer <= 0.0:
			_evade_scan_timer = EVADE_SCAN_SECONDS
			if _try_begin_drift_evade():
				return


func _try_begin_drift_evade() -> bool:
	if state != State.TRANSIT or _drop_timer <= BOMB_WINDUP_SECONDS:
		return false
	var projectile := _find_incoming_projectile()
	if projectile == null:
		return false
	var shot_direction := _flight_space.combat_motion_to_screen(projectile.velocity).normalized()
	var shift := _choose_maneuver_shift(Vector2(-shot_direction.y, shot_direction.x), 280.0)
	if _flight_space.combat_motion_to_screen(shift).length() < 25.0:
		return false
	_strafe_sign = -_strafe_sign
	_start_maneuver_path(shift, EVADE_JINK_SECONDS)
	_evade_cooldown = EVADE_COOLDOWN_SECONDS
	_enter(State.EVADE, EVADE_JINK_SECONDS)
	return true


func _choose_interception_lane() -> void:
	if _observed_player == null:
		return
	var offset := _flight_space.combat_motion_to_screen(_predicted_player - global_position)
	var ring_tangent := Vector2.from_angle(_strafe_angle + PI * 0.5) * _strafe_sign
	var lateral_distance := offset.dot(ring_tangent)
	if absf(lateral_distance) > 60.0:
		_strafe_sign = signf(lateral_distance)
	_strafe_radius = clampf(
		_strafe_radius - signf(offset.length() - _strafe_radius) * 12.0, 180.0, 360.0
	)


func _is_inside_combat_view() -> bool:
	return _inside_view()


func _can_begin_special() -> bool:
	return _time_alive >= 0.35 and _is_inside_combat_view()


func _on_tactical_plan(action: int, target: Vector3) -> void:
	if action != Tactics.Action.BOMBING_RUN:
		return
	_run_target = target
	_run_releases = 0
	# The run replaces the ordinary cadence. Returning to normal flight cannot
	# release a previously overdue bomb or mine in the same frame.
	_drop_timer = bomb_interval
	_mine_timer = maxf(_mine_timer, MINE_DEPLOY_SECONDS + 0.1)


func _on_tactical_flight(action: int, progress: float) -> void:
	if action != Tactics.Action.BOMBING_RUN:
		return
	while _run_releases < RUN_RELEASE_PROGRESS.size() and progress >= RUN_RELEASE_PROGRESS[_run_releases]:
		var release: float = RUN_RELEASE_PROGRESS[_run_releases]
		_run_releases += 1
		_drop_bomb(release)


func _drop_bomb(run_progress: float = -1.0) -> void:
	var manager := get_tree().get_first_node_in_group(
		&"native_3d_projectile_manager"
	) as ProjectileManager
	if manager == null or not manager.is_ready:
		return
	var marker_name := "BombBayLeft" if _drop_left else "BombBayRight"
	var marker := sockets.get_node_or_null(marker_name) as Marker3D
	if marker == null:
		return
	_drop_left = not _drop_left
	play_motion(&"deploy_attack")
	var origin := marker.global_position
	var direction := _heading
	if run_progress >= 0.0:
		# Exact path locations preserve spacing even if a slow frame crosses
		# two release points. Aim stays at the point advertised by the warning.
		origin = _tactics.sample_path(run_progress) + (marker.global_position - global_position)
		direction = (_run_target - origin).normalized()
	manager.fire_enemy_projectile(
		origin,
		direction,
		randf_range(BOMB_SPEED_MIN_PIXELS, BOMB_SPEED_MAX_PIXELS),
	)
	bomb_dropped.emit()


func _try_drop_mine() -> void:
	if _hazard_manager == null:
		return
	var marker := sockets.get_node_or_null("BombBayCenter") as Marker3D
	if marker == null:
		marker = sockets.get_node_or_null("BombBayLeft") as Marker3D
	if marker == null:
		return
	var cluster := generation >= 3 and (_mine_count + 1) % 3 == 0
	var leaves_plasma := generation >= 4 and cluster
	var mine: EnemyMineScript = _hazard_manager.spawn_mine(
		marker.global_position, cluster, leaves_plasma
	)
	if mine != null:
		play_motion(&"deploy_attack")
		_mine_count += 1
		mine_dropped.emit(cluster, leaves_plasma)


func get_debug_state() -> Dictionary:
	var debug := super.get_debug_state()
	debug["mine_count"] = _mine_count
	debug["drop_timer"] = _drop_timer
	debug["drift_weave"] = _strafe_weave
	debug["run_releases"] = _run_releases
	return debug
