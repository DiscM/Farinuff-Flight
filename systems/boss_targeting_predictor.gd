extends RefCounted
class_name BossTargetingPredictor
## Bounded intercept predictor for boss attack targeting. Samples visible
## target motion, estimates velocity and acceleration, then iterates the
## time at which a shot would meet the target. Explicit extrapolation only;
## no learned model and no input inspection.

const HISTORY_LIMIT := 8
const HISTORY_SECONDS := 0.5
const SOLVER_ITERATIONS := 3
const MAXIMUM_ACCELERATION_PIXELS := 2400.0

var _space: FlightSpace3D
var _shot_speed_pixels := 320.0
var _clock := 0.0
var _times: Array[float] = []
var _positions: Array[Vector3] = []
var _velocities: Array[Vector3] = []


func configure(space: FlightSpace3D, shot_speed_pixels: float) -> void:
	_space = space
	_shot_speed_pixels = maxf(shot_speed_pixels, 1.0)
	clear()


func set_shot_speed(shot_speed_pixels: float) -> void:
	_shot_speed_pixels = maxf(shot_speed_pixels, 1.0)


func clear() -> void:
	_clock = 0.0
	_times.clear()
	_positions.clear()
	_velocities.clear()


func sample_count() -> int:
	return _positions.size()


func advance(delta: float, position: Vector3, velocity: Vector3) -> void:
	_clock += maxf(delta, 0.0)
	_times.append(_clock)
	_positions.append(position)
	_velocities.append(velocity)
	while _times.size() > 1 and (
		_times.size() > HISTORY_LIMIT or _clock - _times[0] > HISTORY_SECONDS
	):
		_times.pop_front()
		_positions.pop_front()
		_velocities.pop_front()


func estimated_velocity() -> Vector3:
	if _velocities.is_empty():
		return Vector3.ZERO
	var total := Vector3.ZERO
	for sample in _velocities:
		total += sample
	return total / float(_velocities.size())


func estimated_acceleration() -> Vector3:
	if _times.size() < 2:
		return Vector3.ZERO
	var span: float = float(_times.back()) - float(_times[0])
	if span <= 0.001:
		return Vector3.ZERO
	var acceleration: Vector3 = (_velocities.back() as Vector3) - (_velocities.front() as Vector3)
	acceleration = acceleration / span
	return acceleration.limit_length(MAXIMUM_ACCELERATION_PIXELS)


func predicted_position(lead_seconds: float) -> Vector3:
	if _positions.is_empty():
		return Vector3.ZERO
	var lead := maxf(lead_seconds, 0.0)
	return (
		_positions.back()
		+ estimated_velocity() * lead
		+ estimated_acceleration() * 0.5 * lead * lead
	)


## Iterates shot travel time against the extrapolated target so a crossing
## player is aimed at the meeting point rather than their current seat.
func solve_intercept(
	shooter: Vector3, max_lead_seconds: float, max_lead_pixels: float
) -> Vector3:
	if _positions.is_empty() or _space == null:
		return shooter
	var latest: Vector3 = _positions.back() as Vector3
	var travel := 0.0
	for iteration in SOLVER_ITERATIONS:
		var future := predicted_position(travel)
		var distance := _space.combat_motion_to_screen(future - shooter).length()
		travel = clampf(distance / _shot_speed_pixels, 0.0, maxf(max_lead_seconds, 0.0))
	var intercept := predicted_position(travel)
	var offset: Vector3 = intercept - latest
	var screen_offset := _space.combat_motion_to_screen(offset)
	if screen_offset.length() > max_lead_pixels and max_lead_pixels > 0.0:
		offset = _space.screen_motion_to_combat(screen_offset.limit_length(max_lead_pixels))
	return latest + offset
