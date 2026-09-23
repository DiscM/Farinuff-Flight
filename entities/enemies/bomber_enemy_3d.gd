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
const EVADE_JINK_SECONDS := 0.3
const STRAFE_RADIUS_PIXELS := 270.0
const STRAFE_TANGENTIAL_PIXELS := 90.0

@export_range(0.0, 512.0, 1.0) var drift_speed_pixels: float = 120.0
@export_range(0.1, 10.0, 0.1) var bomb_interval: float = 2.0

var _drop_timer := 0.0
var _drop_left := true
var _mine_timer := MINE_FIRST_DROP_SECONDS
var _mine_count := 0
var _route_timer := 0.0
var _hazard_manager: NativeHazardManager


func _is_basic_lineage() -> bool:
	return false


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
	_route_timer = randf_range(0.65, 1.1)
	state = State.TRANSIT
	state_remaining = 0.0


func _advance_movement(delta: float) -> void:
	_observe_player()
	_evade_cooldown = maxf(0.0, _evade_cooldown - delta)
	var in_view := _is_inside_combat_view()
	match state:
		State.MINE_DEPLOY:
			_advance_strafe(delta, 0.85)
			state_remaining = maxf(0.0, state_remaining - delta)
			if state_remaining <= 0.0:
				_try_drop_mine()
				_enter(State.TRANSIT)
			return
		State.EVADE:
			_advance_strafe(delta, 1.1)
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
	if generation >= 2 and in_view:
		_route_timer -= delta
		if _route_timer <= 0.0:
			_route_timer = 1.1
			_choose_interception_lane()
	_advance_strafe(delta)
	if not in_view:
		return
	if _drop_timer > BOMB_WINDUP_SECONDS and _drop_timer - delta <= BOMB_WINDUP_SECONDS:
		play_motion(&"windup", BOMB_WINDUP_SECONDS, true)
	_drop_timer -= delta
	if _drop_timer <= 0.0:
		_drop_timer = bomb_interval
		_drop_bomb()
	if generation >= 2:
		_mine_timer -= delta
		if _mine_timer <= 0.0 and _can_begin_special():
			_mine_timer = MINE_FIRST_DROP_SECONDS
			play_motion(&"windup", MINE_DEPLOY_SECONDS, true)
			_enter(State.MINE_DEPLOY, MINE_DEPLOY_SECONDS)
			return
	if generation >= 3 and _evade_cooldown <= 0.0:
		_evade_scan_timer -= delta
		if _evade_scan_timer <= 0.0:
			_evade_scan_timer = EVADE_SCAN_SECONDS
			if _try_begin_drift_evade():
				return


func _try_begin_drift_evade() -> bool:
	if state != State.TRANSIT:
		return false
	var projectile := _find_incoming_projectile()
	if projectile == null:
		return false
	var shot_direction := _flight_space.combat_motion_to_screen(projectile.velocity).normalized()
	var ring_direction := Vector2.from_angle(_strafe_angle + PI * 0.5) * _strafe_sign
	if absf(shot_direction.dot(ring_direction)) < 0.85:
		_strafe_sign = -_strafe_sign
	_strafe_angle += _strafe_sign * 0.4
	_strafe_weave = minf(_strafe_weave * 1.6, drift_speed_pixels * 0.7)
	_evade_cooldown = EVADE_COOLDOWN_SECONDS
	play_motion(&"attack", EVADE_JINK_SECONDS)
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


func _drop_bomb() -> void:
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
	play_motion(&"attack")
	manager.fire_enemy_projectile(
		marker.global_position,
		_heading,
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
		play_motion(&"attack")
		_mine_count += 1
		mine_dropped.emit(cluster, leaves_plasma)


func get_debug_state() -> Dictionary:
	var debug := super.get_debug_state()
	debug["mine_count"] = _mine_count
	debug["drop_timer"] = _drop_timer
	debug["drift_weave"] = _strafe_weave
	return debug
