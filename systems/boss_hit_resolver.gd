extends RefCounted
class_name BossHitResolver
## One hit per target per attack, including across many frames of a charge.
var _victims: Dictionary[int, bool] = {}

func reset() -> void:
	_victims.clear()

func circle(space: FlightSpace3D, target: Node3D, center: Vector3, radius: float, damage: int) -> bool:
	return sweep(space, target, center, center, radius, damage)

func sweep(space: FlightSpace3D, target: Node3D, start: Vector3, finish: Vector3, half_width: float, damage: int) -> bool:
	if not is_instance_valid(target) or not target.has_method("receive_damage"):
		return false
	var id := target.get_instance_id()
	if _victims.has(id):
		return false
	var offset := space.combat_motion_to_screen(target.global_position - start)
	var segment := space.combat_motion_to_screen(finish - start)
	var progress := clampf(offset.dot(segment) / segment.length_squared(), 0.0, 1.0) if segment.length_squared() > 0.001 else 0.0
	if offset.distance_to(segment * progress) > half_width:
		return false
	_victims[id] = true # A shield/boost also consumes this attack's single hit.
	return target.receive_damage(finish, Player3D.DamageSource.ENEMY_CONTACT, damage)
