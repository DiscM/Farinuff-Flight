extends BasicEnemy3D
class_name SniperEnemy3D
## Native Generation I Sniper. The reference's entry, hold weave, aimed
## projectile timing, and withdrawal are retained; telegraphs and rail beams
## remain later-generation abilities.

signal aimed_shot_fired(speed_pixels: float)

const ProjectileManager := preload("res://systems/projectile_manager_3d.gd")

const ENTRY_DISTANCE_PIXELS := 115.0
const HOLD_AMPLITUDE_PIXELS := 54.0
const HOLD_FREQUENCY := 1.8
const HOLD_DURATION_SECONDS := 6.0
const WITHDRAW_SPEED_PIXELS := 210.0
const FIRST_SHOT_MIN_SECONDS := 0.6
const FIRST_SHOT_MAX_SECONDS := 1.2
const SHOT_INTERVAL_SECONDS := 1.55
const SHOT_SPEED_MIN_PIXELS := 430.0
const SHOT_SPEED_MAX_PIXELS := 500.0

var _screen_travel_direction := Vector2.ZERO
var _screen_perpendicular := Vector2.ZERO
var _entry_distance := 0.0
var _hold_position := Vector3.ZERO
var _hold_timer := 0.0
var _shoot_timer := 0.0
var _holding := false
var _has_withdrawn := false


func _is_basic_lineage() -> bool:
	return false


func _configure_movement() -> void:
	_screen_travel_direction = _flight_space.combat_motion_to_screen(_heading).normalized()
	_screen_perpendicular = Vector2(-_screen_travel_direction.y, _screen_travel_direction.x)
	_entry_distance = 0.0
	_hold_position = global_position
	_hold_timer = 0.0
	_shoot_timer = randf_range(FIRST_SHOT_MIN_SECONDS, FIRST_SHOT_MAX_SECONDS)
	_holding = false
	_has_withdrawn = false
	velocity = _flight_space.screen_motion_to_combat(_screen_travel_direction * _speed_pixels)
	velocity.y = 0.0


func _advance_movement(delta: float) -> void:
	if not _holding:
		var movement_speed := WITHDRAW_SPEED_PIXELS if _has_withdrawn else _speed_pixels
		var screen_motion := _screen_travel_direction * movement_speed * delta
		global_position += _flight_space.screen_motion_to_combat(screen_motion)
		global_position.y = 0.0
		_entry_distance += movement_speed * delta
		if not _has_withdrawn and _entry_distance >= ENTRY_DISTANCE_PIXELS:
			_holding = true
			_hold_position = global_position
			_hold_timer = 0.0
		return

	_hold_timer += delta
	var screen_offset := _screen_perpendicular * sin(_hold_timer * HOLD_FREQUENCY) * HOLD_AMPLITUDE_PIXELS
	global_position = _hold_position + _flight_space.screen_motion_to_combat(screen_offset)
	global_position.y = 0.0
	_update_aim_and_fire(delta)
	if _hold_timer >= HOLD_DURATION_SECONDS:
		_holding = false
		_has_withdrawn = true
		rotation.y = atan2(-_heading.x, -_heading.z)
		collision_shape.global_rotation = Vector3.ZERO


func _update_aim_and_fire(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player_craft") as Node3D
	var muzzle := sockets.get_node_or_null("MuzzleCenter") as Marker3D
	if player == null or muzzle == null:
		return
	var target_position := player.global_position
	target_position.y = 0.0
	var aim_direction := target_position - muzzle.global_position
	aim_direction.y = 0.0
	if aim_direction.is_zero_approx():
		return
	var normalized_direction := aim_direction.normalized()
	rotation.y = atan2(-normalized_direction.x, -normalized_direction.z)
	# Keep the gameplay primitive world-aligned while the visual/model aims.
	collision_shape.global_rotation = Vector3.ZERO
	_shoot_timer -= delta
	if _shoot_timer > 0.0:
		return
	_shoot_timer = SHOT_INTERVAL_SECONDS
	_fire_aimed_shot(target_position, muzzle)


func _fire_aimed_shot(target_position: Vector3, muzzle: Marker3D) -> void:
	var manager := get_tree().get_first_node_in_group(&"native_3d_projectile_manager") as ProjectileManager
	if manager == null or not manager.is_ready:
		return
	var direction := target_position - muzzle.global_position
	direction.y = 0.0
	if direction.is_zero_approx():
		return
	var speed := randf_range(SHOT_SPEED_MIN_PIXELS, SHOT_SPEED_MAX_PIXELS)
	manager.fire_enemy_projectile(muzzle.global_position, direction, speed)
	aimed_shot_fired.emit(speed)
