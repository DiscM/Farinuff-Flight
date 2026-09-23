extends Node
class_name BossMovementBrain
## Explicitly stepped by BossAI. Executes CHASE, STRAFE, and DODGE flight with
## arena safety. Perception, prediction and combat decisions belong to the
## overarching AI. Three mobility states keep the hull in constant motion.

const Profile := preload("res://systems/boss_flight_profile.gd")
const ARENA_INSET := 160.0
const STRAFE_WAVE_FREQUENCY := 2.2
const DODGE_COOLDOWN_SECONDS := 1.6
const DODGE_STEERING_RESPONSE := 22.0
const DODGE_SPEED_SCALE := 1.35
const PROFILES: Array[Profile] = [
	preload("res://entities/enemies/flight_profiles/commander.tres"),
	preload("res://entities/enemies/flight_profiles/bulwark.tres"),
	preload("res://entities/enemies/flight_profiles/tempest.tres"),
	preload("res://entities/enemies/flight_profiles/harbinger.tres"),
	preload("res://entities/enemies/flight_profiles/core.tres"),
]

enum Mode { CHASE, STRAFE, DODGE }

@export var profile_override: Profile

var profile: Profile
var mode: Mode = Mode.CHASE
var reason: StringName = &"inactive"
var strafe_angle := 0.0
var strafe_sign := 1.0
var strafe_clock := 0.0
var dodge_remaining := 0.0
var dodge_side := 1.0
var speed_scale := 1.0
var combat_distance := -1.0

var _space: FlightSpace3D
var _enabled := false
var _held := true
var _phase := 0
var _variant := 0
var _last_speed := 0.0
var _waypoint := Vector3.ZERO
var _dodge_cooldown := 0.0
var _dodge_axis := Vector2.RIGHT


func configure(space: FlightSpace3D, variant: int) -> void:
	_space = space
	_variant = clampi(variant, 0, PROFILES.size() - 1)
	profile = profile_override if profile_override != null else PROFILES[_variant]
	_enabled = true
	_held = true
	_phase = 0
	_waypoint = Vector3.ZERO
	strafe_clock = 0.0
	strafe_angle = float(_variant) * TAU / 5.0
	strafe_sign = -1.0 if _variant % 2 == 0 else 1.0
	dodge_remaining = 0.0
	_dodge_cooldown = 0.0
	speed_scale = 1.0
	combat_distance = -1.0
	reason = &"idle"
	mode = Mode.CHASE


func set_combat_distance(distance: float = -1.0) -> void:
	combat_distance = distance


func begin_phase(health_phase: int) -> void:
	_phase = clampi(health_phase, 0, 2)
	strafe_sign = -1.0 if (_variant + _phase) % 2 == 0 else 1.0
	strafe_angle += PI * 0.5
	dodge_remaining = 0.0


func hold(reason: StringName = &"attack") -> void:
	_held = true
	_last_speed = 0.0
	self.reason = reason


func release_hold(reason: StringName = &"pattern") -> void:
	_held = false
	self.reason = reason


func set_speed_scale(scale: float) -> void:
	speed_scale = clampf(scale, 0.2, 1.4)


func request_dodge(threat_screen: Vector2, side: float) -> bool:
	if not _enabled or _held or dodge_remaining > 0.0 or _dodge_cooldown > 0.0:
		return false
	var axis := threat_screen.normalized()
	if axis.is_zero_approx():
		return false
	_dodge_axis = axis
	dodge_side = side if not is_zero_approx(side) else (1.0 if randf() < 0.5 else -1.0)
	dodge_remaining = profile.dodge_seconds
	_dodge_cooldown = DODGE_COOLDOWN_SECONDS
	mode = Mode.DODGE
	reason = &"projectile_threat"
	_held = false
	return true


func shutdown() -> void:
	_enabled = false
	_held = true
	dodge_remaining = 0.0
	reason = &"inactive"


## Returns a world velocity; the caller remains the sole writer of its transform.
func steer(
	delta: float,
	origin: Vector3,
	current_velocity: Vector3,
	target_position: Vector3,
	predicted_target: Vector3,
	health_phase: int
) -> Vector3:
	if not _enabled or not is_instance_valid(_space) or delta <= 0.0:
		return Vector3.ZERO
	if _phase != clampi(health_phase, 0, 2):
		begin_phase(health_phase)
	_dodge_cooldown = maxf(0.0, _dodge_cooldown - delta)
	if _held:
		return Vector3.ZERO
	var displacement := _space.combat_motion_to_screen(target_position - origin)
	var distance := displacement.length()
	var toward := displacement.normalized() if distance > 0.01 else Vector2.DOWN
	var radius := _combat_radius()
	var speed := profile.cruise_speed * (1.0 + _phase * 0.08) * speed_scale
	if mode == Mode.CHASE and distance > radius + 60.0:
		speed *= profile.chase_surge
	if mode == Mode.DODGE:
		speed *= DODGE_SPEED_SCALE
	var steering := Vector2.ZERO
	match mode:
		Mode.CHASE:
			steering = _chase_steering(origin, toward, distance, radius, predicted_target)
		Mode.STRAFE:
			steering = _strafe_steering(delta, origin, target_position, distance, radius)
		Mode.DODGE:
			steering = _dodge_steering(delta, origin)
	var bounds := _space.get_combat_bounds(-ARENA_INSET)
	var look_ahead := origin + _space.screen_motion_to_combat(steering.limit_length(1.0) * speed * 0.6)
	var correction := _space.combat_motion_to_screen(_clamp_point(look_ahead, bounds) - look_ahead)
	steering += correction / maxf(speed * 0.6, 1.0) * 1.6
	if not bounds.has_point(Vector2(origin.x, origin.z)):
		var center := Vector3(bounds.get_center().x, 0.0, bounds.get_center().y)
		steering = _space.combat_motion_to_screen(center - origin).normalized()
		reason = &"arena_edge"
	var desired_velocity := _space.screen_motion_to_combat(steering.limit_length(1.0) * speed)
	var response := DODGE_STEERING_RESPONSE if mode == Mode.DODGE else profile.steering_response
	var next_velocity := current_velocity.lerp(desired_velocity, 1.0 - exp(-response * delta))
	# A blended turn can stall through zero; keep a visible floor so the hull
	# never reads as parked while a mobility state is active.
	var floor_speed := speed * 0.4
	if next_velocity.length() < floor_speed:
		var fallback := desired_velocity if not desired_velocity.is_zero_approx() else _space.screen_motion_to_combat(steering.limit_length(1.0))
		next_velocity = fallback.limit_length(maxf(fallback.length(), floor_speed))
	var movement_bounds := bounds.expand(Vector2(origin.x, origin.z))
	var next_position := _clamp_point(origin + next_velocity * delta, movement_bounds)
	next_velocity = (next_position - origin) / delta
	_last_speed = _space.combat_motion_to_screen(next_velocity).length()
	_waypoint = next_position
	return next_velocity


func _combat_radius() -> float:
	var base := combat_distance if combat_distance > 0.0 else profile.preferred_distance - _phase * 20.0
	return maxf(profile.minimum_separation + 10.0, base)


func _chase_steering(
	origin: Vector3,
	toward: Vector2,
	distance: float,
	radius: float,
	predicted_target: Vector3
) -> Vector2:
	_waypoint = predicted_target
	if distance < profile.minimum_separation:
		return -toward + toward.orthogonal() * strafe_sign * 0.35
	return toward * clampf((distance - radius) / 140.0, -1.0, 1.0)


func _strafe_steering(
	delta: float,
	origin: Vector3,
	target_position: Vector3,
	distance: float,
	radius: float
) -> Vector2:
	strafe_clock += delta
	var tangential := maxf(profile.strafe_tangential, 60.0)
	strafe_angle += (tangential / maxf(radius, 1.0)) * strafe_sign * delta
	var ring := Vector2.from_angle(strafe_angle) * radius
	var weave := Vector2.from_angle(strafe_angle + PI * 0.5)
	weave *= sin(strafe_clock * STRAFE_WAVE_FREQUENCY) * profile.strafe_weave
	var bounds := _space.get_combat_bounds(-ARENA_INSET)
	_waypoint = _clamp_point(target_position + _space.screen_motion_to_combat(ring + weave), bounds)
	var to_point := _space.combat_motion_to_screen(_waypoint - origin)
	if distance < profile.minimum_separation:
		return to_point.normalized() * 0.5 - _space.combat_motion_to_screen(
			target_position - origin
		).normalized() * 0.85
	var radial := (to_point / 110.0).limit_length(1.0)
	var drive := Vector2.from_angle(strafe_angle + PI * 0.5) * strafe_sign
	var steering := (radial + drive * 0.9).limit_length(1.0)
	if steering.length_squared() < 0.09:
		return drive
	return steering


func _dodge_steering(delta: float, _origin: Vector3) -> Vector2:
	dodge_remaining = maxf(0.0, dodge_remaining - delta)
	if dodge_remaining <= 0.0:
		mode = Mode.STRAFE
		reason = &"dodge_complete"
		return Vector2.ZERO
	var lateral := Vector2(-_dodge_axis.y, _dodge_axis.x) * dodge_side
	return lateral * 1.25


func _clamp_point(point: Vector3, bounds: Rect2) -> Vector3:
	return Vector3(
		clampf(point.x, bounds.position.x, bounds.end.x),
		0.0,
		clampf(point.z, bounds.position.y, bounds.end.y)
	)


func get_debug_state() -> Dictionary:
	return {
		"profile": profile.display_name if profile != null else &"none",
		"mode": Mode.keys()[mode],
		"reason": reason,
		"held": _held,
		"phase": _phase,
		"speed_scale": speed_scale,
		"strafe_angle": strafe_angle,
		"dodge_remaining": dodge_remaining,
		"predicted_target": _waypoint,
		"waypoint": _waypoint,
		"speed_pixels": _last_speed,
	}
