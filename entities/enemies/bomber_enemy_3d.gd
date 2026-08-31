extends BasicEnemy3D
class_name BomberEnemy3D
## Native Bomber. Generation I retains the reference's slow forward travel,
## bounded perpendicular drift, and periodic bomb drops; later generations can
## request the pooled native mine path without adding a second hazard owner.

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

const DRIFT_BOUNDARY_MARGIN_PIXELS := 30.0
const BOMB_FIRST_DROP_MIN_SECONDS := 0.5
const BOMB_SPEED_MIN_PIXELS := 300.0
const BOMB_SPEED_MAX_PIXELS := 400.0
const MINE_FIRST_DROP_SECONDS := 5.0

@export_range(0.0, 512.0, 1.0) var drift_speed_pixels: float = 120.0
@export_range(0.1, 10.0, 0.1) var bomb_interval: float = 2.0

var _screen_travel_direction := Vector2.ZERO
var _screen_perpendicular := Vector2.ZERO
var _drift_direction := 1.0
var _drop_timer := 0.0
var _drop_left := true
var _mine_timer := MINE_FIRST_DROP_SECONDS
var _mine_count := 0
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
	_screen_travel_direction = _flight_space.combat_motion_to_screen(_heading).normalized()
	_screen_perpendicular = Vector2(-_screen_travel_direction.y, _screen_travel_direction.x)
	_drift_direction = -1.0 if randf() < 0.5 else 1.0
	_drop_timer = randf_range(BOMB_FIRST_DROP_MIN_SECONDS, bomb_interval)
	_drop_left = true
	_mine_timer = MINE_FIRST_DROP_SECONDS
	_mine_count = 0
	velocity = _flight_space.screen_motion_to_combat(_screen_travel_direction * _speed_pixels)
	velocity.y = 0.0


func _advance_movement(delta: float) -> void:
	var screen_motion := _screen_travel_direction * (_speed_pixels * delta)
	screen_motion += _screen_perpendicular * (drift_speed_pixels * _drift_direction * delta)
	var next_position := global_position + _flight_space.screen_motion_to_combat(screen_motion)
	var bounds := _flight_space.get_combat_bounds()
	var horizontal_margin := absf(
		_flight_space.screen_motion_to_combat(Vector2(DRIFT_BOUNDARY_MARGIN_PIXELS, 0.0)).x
	)
	var vertical_margin := absf(
		_flight_space.screen_motion_to_combat(Vector2(0.0, DRIFT_BOUNDARY_MARGIN_PIXELS)).z
	)

	# The reference bomber bounces only on the axis perpendicular to travel;
	# its forward component still exits through the matching edge.
	if absf(_screen_perpendicular.x) > 0.5:
		var minimum_x := bounds.position.x + horizontal_margin
		var maximum_x := bounds.end.x - horizontal_margin
		if next_position.x < minimum_x:
			next_position.x = minimum_x
			if _screen_perpendicular.x * _drift_direction < 0.0:
				_drift_direction *= -1.0
		elif next_position.x > maximum_x:
			next_position.x = maximum_x
			if _screen_perpendicular.x * _drift_direction > 0.0:
				_drift_direction *= -1.0
	if absf(_screen_perpendicular.y) > 0.5:
		var minimum_z := bounds.position.y + vertical_margin
		var maximum_z := bounds.end.y - vertical_margin
		if next_position.z < minimum_z:
			next_position.z = minimum_z
			if _screen_perpendicular.y * _drift_direction < 0.0:
				_drift_direction *= -1.0
		elif next_position.z > maximum_z:
			next_position.z = maximum_z
			if _screen_perpendicular.y * _drift_direction > 0.0:
				_drift_direction *= -1.0

	global_position = next_position
	global_position.y = 0.0
	if _is_inside_combat_view():
		_drop_timer -= delta
		if _drop_timer <= 0.0:
			_drop_timer = bomb_interval
			_drop_bomb()
	if generation >= 2:
		_mine_timer -= delta
		if _mine_timer <= 0.0 and _can_begin_special():
			_mine_timer = MINE_FIRST_DROP_SECONDS
			_try_drop_mine()


func _is_inside_combat_view() -> bool:
	var bounds := _flight_space.get_combat_bounds()
	return bounds.has_point(Vector2(global_position.x, global_position.z))


func _can_begin_special() -> bool:
	return _time_alive >= 0.35 and _is_inside_combat_view()


func _drop_bomb() -> void:
	var manager := get_tree().get_first_node_in_group(&"native_3d_projectile_manager") as ProjectileManager
	if manager == null or not manager.is_ready:
		return
	var marker_name := "BombBayLeft" if _drop_left else "BombBayRight"
	var marker := sockets.get_node_or_null(marker_name) as Marker3D
	if marker == null:
		return
	_drop_left = not _drop_left
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
		_mine_count += 1
		mine_dropped.emit(cluster, leaves_plasma)
