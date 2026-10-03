extends RefCounted
## Fire input and shot-pattern policy. The craft owns sockets, cooldown timers,
## and emission; this module needs no scene tree or run-manager dependencies.

const FlightSpace := preload("res://systems/flight_space_3d.gd")
const Tuning := preload("res://entities/player/player_weapon_tuning.gd")
var latched := false
var waiting_for_release := true


func reset_input(held: bool = true) -> void:
	latched = false
	waiting_for_release = held


func wants_fire(pressed: bool, just_pressed: bool, toggle: bool) -> bool:
	if waiting_for_release:
		waiting_for_release = pressed
		return false
	if toggle:
		if just_pressed:
			latched = not latched
		return latched
	return pressed


func interval(base: float, bonus: float, rapid: bool, overclock: bool) -> float:
	return Tuning.fire_interval(base, bonus, rapid, overclock)


func directions(aim: Vector3, space: FlightSpace, temporary_spread: bool, elite_spread: bool) -> Array[Vector3]:
	var result: Array[Vector3] = [aim]
	if (not temporary_spread and not elite_spread) or space == null:
		return result
	var screen_direction: Vector2 = space.combat_motion_to_view(aim).normalized()
	var angles: Array[float] = [-deg_to_rad(15.0), deg_to_rad(15.0)]
	if temporary_spread and elite_spread:
		angles.append_array([-deg_to_rad(30.0), deg_to_rad(30.0)])
	for angle in angles:
		result.append(space.view_motion_to_combat(screen_direction.rotated(angle)).normalized())
	return result
