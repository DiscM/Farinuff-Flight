extends RefCounted
class_name ProjectileInteractionRange3D
## Shared, once-per-physics-tick target snapshot for incoming projectiles.
## Distances use the same baseline-pixel metric as movement and boost tuning.

const FlightSpace := preload("res://systems/flight_space_3d.gd")

var target_position := Vector3.ZERO
var target_motion := Vector3.ZERO
var _target: Node3D
var _combat_to_pixels := Basis.IDENTITY
var _radius_pixels := 0.0
var _hysteresis_pixels := 0.0


func configure(flight_space: FlightSpace, target: Node3D, radius_pixels: float, hysteresis_pixels: float) -> void:
	_target = target
	_radius_pixels = radius_pixels
	_hysteresis_pixels = hysteresis_pixels
	_combat_to_pixels = Basis(
		flight_space.screen_motion_to_combat(Vector2.RIGHT),
		Vector3.UP,
		flight_space.screen_motion_to_combat(Vector2.DOWN)
	).inverse()
	if is_instance_valid(_target):
		target_position = _target.global_position
		target_position.y = 0.0
	target_motion = Vector3.ZERO


## The manager runs after Player Craft movement and before projectile steps.
func update_target() -> void:
	if not has_target():
		target_motion = Vector3.ZERO
		return
	var previous_position := target_position
	target_position = _target.global_position
	target_position.y = 0.0
	target_motion = target_position - previous_position
	# Flush the target's new transform before immediate ShapeCast3D queries.
	_target.force_update_transform()


func has_target() -> bool:
	return is_instance_valid(_target) and _target.is_inside_tree()


func should_arm(position: Vector3, motion: Vector3, was_armed: bool) -> bool:
	if not has_target():
		return false
	var relative_start := _to_pixels(position - (target_position - target_motion))
	var relative_end := _to_pixels(position + motion - target_position)
	var relative_motion := relative_end - relative_start
	var closest := Geometry2D.get_closest_point_to_segment(Vector2.ZERO, relative_start, relative_end)
	# Include a full relative step: fast projectiles and a boosting player can
	# cross the base range between physics samples. Hysteresis prevents chatter.
	var threshold := _radius_pixels + relative_motion.length()
	if was_armed:
		threshold += _hysteresis_pixels
	return closest.length_squared() <= threshold * threshold


func _to_pixels(motion: Vector3) -> Vector2:
	var converted := _combat_to_pixels * motion
	return Vector2(converted.x, converted.z)
