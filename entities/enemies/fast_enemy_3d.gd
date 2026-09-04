extends BasicEnemy3D
class_name FastEnemy3D
## Native Generation I Fast Enemy. The reference's straight entry is retained
## while a screen-space sine weave is projected onto the Combat Plane.

@export_range(0.0, 256.0, 0.5) var weave_amplitude_pixels: float = 80.0
@export_range(0.0, 12.0, 0.1) var weave_frequency: float = 3.0

var _start_position := Vector3.ZERO
var _screen_travel_direction := Vector2.ZERO
var _screen_perpendicular := Vector2.ZERO
var _weave_time := 0.0


func _is_basic_lineage() -> bool:
	return false


func _configure_movement() -> void:
	_start_position = global_position
	_screen_travel_direction = _flight_space.combat_motion_to_screen(_heading).normalized()
	_screen_perpendicular = Vector2(-_screen_travel_direction.y, _screen_travel_direction.x)
	velocity = _flight_space.screen_motion_to_combat(_screen_travel_direction * _speed_pixels)
	velocity.y = 0.0
	_weave_time = 0.0


func _advance_movement(delta: float) -> void:
	_weave_time += delta
	var screen_offset := _screen_travel_direction * (_speed_pixels * _weave_time)
	screen_offset += _screen_perpendicular * sin(_weave_time * weave_frequency) * weave_amplitude_pixels
	global_position = _start_position + _flight_space.screen_motion_to_combat(screen_offset)
	global_position.y = 0.0
