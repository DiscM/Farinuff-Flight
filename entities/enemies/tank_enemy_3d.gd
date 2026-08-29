extends BasicEnemy3D
class_name TankEnemy3D
## Native Generation I Tank. The reference's slow straight entry and timed
## radial projectile bursts are retained; plates and overload remain deferred.

signal burst_fired(shot_count: int)

const ProjectileManager := preload("res://systems/projectile_manager_3d.gd")

const FIRST_BURST_MIN_SECONDS := 0.5
const SHOT_SPEED_EVEN_PIXELS := 245.0
const SHOT_SPEED_ODD_PIXELS := 305.0
const SHOT_SPEED_VARIANCE_PIXELS := 8.0

@export_range(1, 16, 1) var bullet_count: int = 8
@export_range(0.1, 10.0, 0.1) var burst_interval: float = 2.5

var _burst_timer := 0.0


func _configure_movement() -> void:
	super._configure_movement()
	_burst_timer = randf_range(FIRST_BURST_MIN_SECONDS, burst_interval)


func _advance_movement(delta: float) -> void:
	super._advance_movement(delta)
	if not _is_inside_combat_view():
		return
	_burst_timer -= delta
	if _burst_timer <= 0.0:
		_burst_timer = burst_interval
		_fire_radial_burst()


func _is_inside_combat_view() -> bool:
	var bounds := _flight_space.get_combat_bounds()
	return bounds.has_point(Vector2(global_position.x, global_position.z))


func _fire_radial_burst() -> void:
	var manager := get_tree().get_first_node_in_group(&"native_3d_projectile_manager") as ProjectileManager
	var muzzle := sockets.get_node_or_null("MuzzleCenter") as Marker3D
	if manager == null or not manager.is_ready or muzzle == null:
		return
	for index in range(bullet_count):
		var angle := (TAU / float(bullet_count)) * float(index)
		# Match the 2D reference's angle convention: angle zero travels down.
		var screen_direction := Vector2(sin(angle), cos(angle))
		var combat_direction := _flight_space.screen_motion_to_combat(screen_direction)
		var base_speed := SHOT_SPEED_EVEN_PIXELS if index % 2 == 0 else SHOT_SPEED_ODD_PIXELS
		var shot_speed := base_speed + randf_range(-SHOT_SPEED_VARIANCE_PIXELS, SHOT_SPEED_VARIANCE_PIXELS)
		manager.fire_enemy_projectile(muzzle.global_position, combat_direction, shot_speed)
	burst_fired.emit(bullet_count)
