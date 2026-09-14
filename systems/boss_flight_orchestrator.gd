extends Node
class_name BossFlightOrchestrator
## Explicitly stepped by the boss: attacks own movement locks and physical rams.
## This node owns maneuver selection, predictive steering and arena recovery.
## Pattern clocks count flight time, so a volley cannot skip a flight maneuver.

const Profile := preload("res://systems/boss_flight_profile.gd")
const Maneuver = Profile.Maneuver
const PROFILES: Array[Profile] = [
	preload("res://entities/enemies/flight_profiles/commander.tres"),
	preload("res://entities/enemies/flight_profiles/bulwark.tres"),
	preload("res://entities/enemies/flight_profiles/tempest.tres"),
	preload("res://entities/enemies/flight_profiles/harbinger.tres"),
	preload("res://entities/enemies/flight_profiles/core.tres"),
]
const ARENA_INSET := 100.0
const MINIMUM_SEPARATION := 170.0

signal maneuver_changed(maneuver: Profile.Maneuver)

@export var profile_override: Profile

var profile: Profile
var maneuver: Profile.Maneuver = Maneuver.INTERCEPT
var _space: FlightSpace3D
var _enabled := false
var _phase := 0
var _variant := 0
var _sequence_index := -1
var _maneuver_time := 0.0
var _maneuver_duration := 1.0
var _tactical := true
var _side := 1.0
var _axis := Vector2.UP
var _held := true
var _reason: StringName = &"inactive"
var _predicted_target := Vector3.ZERO
var _waypoint := Vector3.ZERO
var _last_speed := 0.0


func configure(space: FlightSpace3D, variant: int) -> void:
	_space = space
	_variant = clampi(variant, 0, PROFILES.size() - 1)
	profile = profile_override if profile_override != null else PROFILES[_variant]
	_enabled = true
	_predicted_target = Vector3.ZERO
	_waypoint = Vector3.ZERO
	begin_phase(0)


func begin_phase(health_phase: int) -> void:
	_phase = clampi(health_phase, 0, 2)
	_sequence_index = -1
	_maneuver_time = 0.0
	_maneuver_duration = 1.0
	_tactical = true
	_side = -1.0 if (_variant + _phase) % 2 == 0 else 1.0
	_axis = Vector2.UP
	maneuver = Maneuver.INTERCEPT
	hold(&"phase")


func hold(reason: StringName = &"attack") -> void:
	_held = true
	_reason = reason
	_last_speed = 0.0


func shutdown() -> void:
	_enabled = false
	_maneuver_time = 0.0
	_sequence_index = -1
	hold(&"inactive")


## Returns a world velocity; the caller remains the sole writer of its transform.
func steer(delta: float, origin: Vector3, current_velocity: Vector3, target: Node3D, health_phase: int) -> Vector3:
	if not _enabled or not is_instance_valid(_space) or delta <= 0.0:
		return Vector3.ZERO
	if not is_instance_valid(target):
		hold(&"no_player")
		return Vector3.ZERO
	if _phase != clampi(health_phase, 0, 2):
		begin_phase(health_phase)
	_held = false
	var displacement := _space.combat_motion_to_screen(target.global_position - origin)
	var distance := displacement.length()
	var toward := displacement.normalized() if distance > 0.01 else Vector2.DOWN
	var target_velocity: Vector3 = target.get("velocity")
	var lead := (_space.combat_motion_to_screen(target_velocity) * profile.lead_seconds).limit_length(profile.maximum_lead)
	var radius := maxf(230.0, profile.preferred_distance - _phase * 20.0)
	var speed := profile.cruise_speed * (1.0 + _phase * 0.08)
	# Predict aggressively when closing, gently when already alongside the player.
	lead *= clampf((distance - MINIMUM_SEPARATION) / radius, 0.0, 1.0)
	_predicted_target = target.global_position + _space.screen_motion_to_combat(lead)
	var bounds := _space.get_combat_bounds(-ARENA_INSET)
	_select_maneuver(origin, toward, distance, radius, bounds)
	_maneuver_time = minf(_maneuver_time + delta, _maneuver_duration)
	var steering := _pattern_steering(origin, toward, distance, radius, bounds)
	# Look ahead before the hull reaches an edge. This bends a path back inside
	# while the final clamp remains a guard against large physics steps.
	var look_ahead := origin + _space.screen_motion_to_combat(steering.limit_length(1.0) * speed * 0.6)
	var correction := _space.combat_motion_to_screen(_clamp_point(look_ahead, bounds) - look_ahead)
	steering += correction / maxf(speed * 0.6, 1.0) * 1.6
	var desired_velocity := _space.screen_motion_to_combat(steering.limit_length(1.0) * speed)
	var next_velocity := current_velocity.lerp(desired_velocity, 1.0 - exp(-profile.steering_response * delta))
	# Include an outer-edge ram endpoint while flying back inward: never teleport
	# the boss by snapping its current position to the inset rectangle.
	var movement_bounds := bounds.expand(Vector2(origin.x, origin.z))
	var next_position := _clamp_point(origin + next_velocity * delta, movement_bounds)
	next_velocity = (next_position - origin) / delta
	_last_speed = _space.combat_motion_to_screen(next_velocity).length()
	return next_velocity


func _select_maneuver(origin: Vector3, toward: Vector2, distance: float, radius: float, bounds: Rect2) -> void:
	var point := Vector2(origin.x, origin.z)
	var recovery_bounds := _space.get_combat_bounds(-ARENA_INSET - 60.0)
	var priority := -1
	if not bounds.has_point(point) or (_tactical and maneuver == Maneuver.REENTER and not recovery_bounds.has_point(point)):
		priority = Maneuver.REENTER
	elif distance < MINIMUM_SEPARATION or (_tactical and maneuver == Maneuver.WITHDRAW and distance < radius * 0.85):
		priority = Maneuver.WITHDRAW
	elif distance > radius + 240.0 or (_tactical and maneuver == Maneuver.INTERCEPT and distance > radius + 100.0):
		priority = Maneuver.INTERCEPT
	if priority >= 0:
		if not _tactical or maneuver != priority:
			_enter_maneuver(priority as Profile.Maneuver, -toward)
		_tactical = true
		_reason = &"arena_edge" if priority == Maneuver.REENTER else &"separation" if priority == Maneuver.WITHDRAW else &"close_gap"
		return
	if _tactical or _sequence_index < 0 or _maneuver_time >= _maneuver_duration:
		_sequence_index += 1
		if _sequence_index >= profile.sequence.size():
			_sequence_index = 0
			_side *= -1.0
		var next: Profile.Maneuver = profile.sequence[_sequence_index] if not profile.sequence.is_empty() else Maneuver.ORBIT
		_enter_maneuver(next, -toward)
	_tactical = false
	_reason = &"pattern"


func _enter_maneuver(next: Profile.Maneuver, away: Vector2) -> void:
	maneuver = next
	_maneuver_time = 0.0
	_maneuver_duration = profile.maneuver_seconds / (1.0 + _phase * 0.16)
	if maneuver == Maneuver.FIGURE_EIGHT:
		_maneuver_duration *= 2.0
	elif maneuver == Maneuver.ORBIT:
		_maneuver_duration *= 1.4
	_axis = away
	maneuver_changed.emit(maneuver)


func _pattern_steering(origin: Vector3, toward: Vector2, distance: float, radius: float, bounds: Rect2) -> Vector2:
	var progress := clampf(_maneuver_time / _maneuver_duration, 0.0, 1.0)
	var amplitude := profile.pattern_amplitude * (1.0 + _phase * 0.12)
	var tangent := _axis.orthogonal() * _side
	var offset := Vector2.ZERO
	match maneuver:
		Maneuver.INTERCEPT:
			_waypoint = _predicted_target
			return _space.combat_motion_to_screen(_predicted_target - origin).normalized()
		Maneuver.REENTER:
			var center := Vector3(bounds.get_center().x, 0, bounds.get_center().y)
			_waypoint = _clamp_point(origin, bounds).lerp(center, 0.3)
			return _space.combat_motion_to_screen(_waypoint - origin).normalized()
		Maneuver.WITHDRAW:
			if _tactical:
				_waypoint = origin + _space.screen_motion_to_combat(-toward * radius)
				return -toward + toward.orthogonal() * _side * 0.3
			offset = _axis.rotated(_side * progress * 0.65) * radius * (1.25 + sin(progress * PI) * 0.12)
		Maneuver.FLANK:
			offset = _axis.rotated(_side * (0.25 + progress * 1.1)) * radius
		Maneuver.ORBIT:
			var orbit_radius := radius + sin(progress * TAU) * amplitude * 0.3
			_waypoint = _predicted_target - _space.screen_motion_to_combat(toward * orbit_radius)
			return toward * clampf((distance - orbit_radius) / 130.0, -1.0, 1.0) + toward.orthogonal() * _side * 0.85
		Maneuver.WEAVE:
			offset = _axis * radius + tangent * sin(progress * TAU) * amplitude
		Maneuver.FIGURE_EIGHT:
			offset = _axis * (radius + sin(progress * TAU * 2.0) * amplitude * 0.45) + tangent * sin(progress * TAU) * amplitude * 1.5
	_waypoint = _clamp_point(_predicted_target + _space.screen_motion_to_combat(offset), bounds)
	# Arrival slows the hull at a moving waypoint without teleporting it onto a
	# curve. Every curve follows the live target; its axis stays stable per leg.
	return (_space.combat_motion_to_screen(_waypoint - origin) / 110.0).limit_length(1.0)


func _clamp_point(point: Vector3, bounds: Rect2) -> Vector3:
	return Vector3(clampf(point.x, bounds.position.x, bounds.end.x), 0.0, clampf(point.z, bounds.position.y, bounds.end.y))


func get_debug_state() -> Dictionary:
	return {
		"profile": profile.display_name if profile != null else &"none",
		"maneuver": Maneuver.keys()[maneuver],
		"reason": _reason,
		"held": _held,
		"phase": _phase,
		"sequence_index": _sequence_index,
		"flight_time": _maneuver_time,
		"duration": _maneuver_duration,
		"predicted_target": _predicted_target,
		"waypoint": _waypoint,
		"speed_pixels": _last_speed,
	}
