extends RefCounted
class_name EnemyFlightMotion3D
## Presents combat maneuvers above the imported bone clips. Gameplay owns
## their timing, displacement and defenses; this layer only poses the hull.

enum Style { FIGHTER, INTERCEPTOR, BOMBER, TANK, SNIPER, CAPITAL }
enum Maneuver { NONE, AILERON_ROLL, BARREL_ROLL, SPIN, WINGOVER, BANK_REVERSAL, PITCH_RECOVERY,
	SPLIT_S, IMMELMANN, SCISSORS, CORKSCREW, KNIFE_EDGE,
	HIGH_YO_YO, LOW_YO_YO, HAMMERHEAD, BOMBING_RUN }

## Readable at the normal 220-world-unit camera span, including the angled view.
const BANK_LIMITS := [0.85, 1.05, 0.65, 0.42, 0.7, 0.28]
const AMPLITUDES := [1.0, 1.15, 1.05, 0.85, 1.05, 0.55]
const TEMPOS := [1.0, 0.8, 1.2, 1.5, 1.1, 1.75]
const DURATIONS := [0.18, 1.1, 1.35, 0.9, 1.55, 1.7, 1.0, 1.35, 1.45, 1.85, 1.5, 1.15, 1.6, 1.35, 1.7, 1.6]
const BLEND_SECONDS := 0.24

var current_maneuver: Maneuver = Maneuver.NONE
var pose := Transform3D.IDENTITY
var _style: Style
var _visuals: Node3D
var _sockets: Node3D
var _models: Array[Node3D] = []
var _model_rest: Array[Transform3D] = []
var _markers: Array[Node3D] = []
var _marker_rest: Array[Transform3D] = []
var _rng := RandomNumberGenerator.new()
var _direction := 1.0
var _clock := 0.0
var _elapsed := 0.0
var _duration := 0.0
var _bank := 0.0
var _bank_velocity := 0.0
var _previous_heading := 0.0
var _telegraph := false
var _reduced_motion := false
var _maneuver_pose := Transform3D.IDENTITY
var _blend_from := Transform3D.IDENTITY


func _init(visuals: Node3D, sockets: Node3D, style: Style) -> void:
	_visuals = visuals
	_sockets = sockets
	_style = style
	for child in visuals.get_children():
		if child is Node3D:
			_models.append(child)
			_model_rest.append(child.transform)
	for child in sockets.get_children():
		if child is Marker3D:
			_markers.append(child)
			_marker_rest.append(child.transform)


func reset(heading: float, seed_value: int) -> void:
	# A private RNG keeps visual variety from changing spawn/attack randomness.
	_rng.seed = seed_value
	_direction = -1.0 if _rng.randf() < 0.5 else 1.0
	_clock = _rng.randf_range(0.0, TAU)
	_previous_heading = heading
	_telegraph = false
	_reduced_motion = false
	_clear_pose()


func is_playing() -> bool:
	return _elapsed < _duration


func play(maneuver: Maneuver, direction: float = 0.0, seconds: float = 0.0) -> void:
	if _reduced_motion or (_telegraph and maneuver != Maneuver.NONE):
		return
	_blend_from = _maneuver_pose
	current_maneuver = maneuver
	_elapsed = 0.0
	_duration = seconds if seconds > 0.0 else DURATIONS[maneuver] * TEMPOS[_style]
	if not is_zero_approx(direction):
		_direction = signf(direction)


func set_telegraph(held: bool) -> void:
	if held and not _telegraph:
		# Unwind the current pose smoothly before the committed release frame.
		play(Maneuver.NONE, 0.0, BLEND_SECONDS)
	_telegraph = held


func react(state_name: StringName, direction: float, seconds: float = 0.0) -> void:
	match state_name:
		&"REFLECT_ROLL":
			play(Maneuver.AILERON_ROLL, direction, seconds)
		&"EVADE":
			play(Maneuver.BARREL_ROLL if _style <= Style.INTERCEPTOR else Maneuver.BANK_REVERSAL, direction, seconds)
		&"PHASE_DASH":
			play(Maneuver.SPIN, direction, seconds)
		&"REPOSITION":
			play(Maneuver.WINGOVER if _style == Style.SNIPER else Maneuver.PITCH_RECOVERY, direction, seconds)
		&"WITHDRAW":
			play(Maneuver.WINGOVER, direction)
		&"BRACE", &"OVERLOAD":
			play(Maneuver.BANK_REVERSAL, direction, seconds)
		&"SPLIT_S":
			play(Maneuver.SPLIT_S, direction, seconds)
		&"IMMELMANN":
			play(Maneuver.IMMELMANN, direction, seconds)
		&"SCISSORS":
			play(Maneuver.SCISSORS, direction, seconds)
		&"CORKSCREW":
			play(Maneuver.CORKSCREW, direction, seconds)
		&"KNIFE_EDGE":
			play(Maneuver.KNIFE_EDGE, direction, seconds)
		&"HIGH_YO_YO":
			play(Maneuver.HIGH_YO_YO, direction, seconds)
		&"LOW_YO_YO":
			play(Maneuver.LOW_YO_YO, direction, seconds)
		&"HAMMERHEAD":
			play(Maneuver.HAMMERHEAD, direction, seconds)
		&"BOMBING_RUN":
			play(Maneuver.BOMBING_RUN, direction, seconds)


func advance(delta: float, heading: float, reduced_motion: bool) -> void:
	if delta <= 0.0:
		return
	_reduced_motion = reduced_motion
	if reduced_motion:
		_previous_heading = heading
		_clear_pose()
		return
	_clock += delta
	var turn_rate := angle_difference(_previous_heading, heading) / delta
	_previous_heading = heading
	var bank_target := clampf(turn_rate * 0.55, -BANK_LIMITS[_style], BANK_LIMITS[_style])
	if _telegraph:
		bank_target = 0.0
	# Critical damping carries angular velocity through changing turn inputs.
	# This keeps broad banks smooth without overshoot or frame-rate dependence.
	var bank_offset := _bank - bank_target
	var change := (_bank_velocity + 14.0 * bank_offset) * delta
	var decay := exp(-14.0 * delta)
	_bank = bank_target + (bank_offset + change) * decay
	_bank_velocity = (_bank_velocity - 14.0 * change) * decay
	if is_playing():
		_elapsed = minf(_elapsed + delta, _duration)
		var progress := _elapsed / _duration
		var sampled := _sample(current_maneuver, progress)
		var blend_t := clampf(_elapsed / minf(BLEND_SECONDS, _duration), 0.0, 1.0)
		var blend := blend_t * blend_t * blend_t * (blend_t * (blend_t * 6.0 - 15.0) + 10.0)
		# Fade a fixed old orientation before applying the new clip. Blending
		# directly toward a moving full turn can flip slerp's shortest arc.
		_maneuver_pose = _blend_from.interpolate_with(Transform3D.IDENTITY, blend) * sampled
		if _elapsed >= _duration:
			current_maneuver = Maneuver.NONE
			_maneuver_pose = Transform3D.IDENTITY
	var quiet_pitch: float = sin(_clock * 1.7) * 0.07 * AMPLITUDES[_style] if not _telegraph else 0.0
	pose = Transform3D(Basis.from_euler(Vector3(quiet_pitch, 0.0, _bank)), Vector3.ZERO) * _maneuver_pose
	_apply_models()


func sync_sockets() -> void:
	# Unrigged markers (cores, fragment mounts, center bomb bay) follow the
	# same additive transform. The actor then resolves bone-bound sockets.
	var world_pose := _visuals.global_transform * pose * _visuals.global_transform.affine_inverse()
	for index in _markers.size():
		_markers[index].global_transform = world_pose * _sockets.global_transform * _marker_rest[index]


func _clear_pose() -> void:
	current_maneuver = Maneuver.NONE
	_elapsed = 0.0
	_duration = 0.0
	_bank = 0.0
	_bank_velocity = 0.0
	pose = Transform3D.IDENTITY
	_maneuver_pose = Transform3D.IDENTITY
	_blend_from = Transform3D.IDENTITY
	_apply_models()


func _apply_models() -> void:
	for index in _models.size():
		_models[index].transform = pose * _model_rest[index]


func _sample(maneuver: Maneuver, progress: float) -> Transform3D:
	# Quintic easing brings angular velocity AND acceleration to rest at both
	# ends. Never lerp a full turn's endpoints: they describe the same rotation.
	var t := clampf(progress, 0.0, 1.0)
	var eased := t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
	var turn := TAU * eased
	var arch := pow(sin(PI * eased), 2.0)
	var angles := Vector3.ZERO
	var offset := Vector3.ZERO
	var amplitude: float = AMPLITUDES[_style]
	match maneuver:
		Maneuver.AILERON_ROLL:
			angles.z = turn * _direction
		Maneuver.BARREL_ROLL:
			angles = Vector3(sin(turn) * 0.55, sin(turn) * 0.28 * _direction, turn * _direction)
			# A small helical arc distinguishes a barrel roll from an axial roll;
			# keep it well inside the hull footprint so contact stays readable.
			offset = Vector3(sin(turn) * 0.4 * _direction, (1.0 - cos(turn)) * 0.25, 0.0)
		Maneuver.SPIN:
			angles = Vector3(-sin(turn) * 0.32, turn * _direction, arch * 1.1 * _direction)
		Maneuver.WINGOVER:
			angles = Vector3(-arch * 0.9, sin(turn) * 0.38 * _direction, sin(turn) * 1.35 * _direction) * amplitude
		Maneuver.BANK_REVERSAL:
			angles = Vector3(arch * 0.25, sin(turn) * 0.16 * _direction, sin(turn) * 1.05 * _direction) * amplitude
		Maneuver.PITCH_RECOVERY:
			angles = Vector3(-sin(turn) * 0.55, 0.0, arch * 0.3 * _direction) * amplitude
		Maneuver.SPLIT_S:
			# Half roll, then a descending half loop. Remove the net yaw because
			# the real flight path supplies the heading reversal on the actor.
			var roll := PI * smoothstep(0.0, 0.4, t) * _direction
			var dive := PI * smoothstep(0.28, 1.0, t)
			return Transform3D(Basis(Vector3.UP, -PI * eased * _direction) * Basis(Vector3.RIGHT, dive) * Basis(Vector3.BACK, roll), Vector3.ZERO)
		Maneuver.IMMELMANN:
			var climb := -PI * smoothstep(0.0, 0.72, t)
			var roll := PI * smoothstep(0.55, 1.0, t) * _direction
			return Transform3D(Basis(Vector3.UP, -PI * eased * _direction) * Basis(Vector3.BACK, roll) * Basis(Vector3.RIGHT, climb), Vector3.ZERO)
		Maneuver.SCISSORS:
			angles = Vector3(-arch * 0.32, sin(turn * 2.0) * 0.3 * _direction, sin(turn * 2.0) * 1.25 * _direction)
		Maneuver.CORKSCREW:
			angles = Vector3(sin(turn) * 0.48, sin(turn) * 0.24 * _direction, turn * 2.0 * _direction)
			offset = Vector3(sin(turn * 2.0) * 0.32, arch * 0.42, 0.0)
		Maneuver.KNIFE_EDGE:
			# Hold the edge-on silhouette through the middle of the lane change.
			var held_bank := smoothstep(0.0, 0.22, t) * (1.0 - smoothstep(0.72, 1.0, t))
			angles = Vector3(-arch * 0.22, 0.0, held_bank * PI * 0.48 * _direction)
		Maneuver.HIGH_YO_YO:
			# Pitch up to bleed pursuit speed, bank across the top, then level.
			angles = Vector3(-sin(PI * eased) * 1.2, sin(turn) * 0.35 * _direction, arch * 1.35 * _direction)
		Maneuver.LOW_YO_YO:
			# A nose-down cut inside the target's turn, followed by a pull-up.
			angles = Vector3(sin(turn) * 1.05, -sin(turn) * 0.26 * _direction, -arch * 1.15 * _direction)
		Maneuver.HAMMERHEAD:
			# Pitch vertically, yaw at the apex, then descend and roll level.
			# The actor supplies the permanent heading change on the real path.
			var rise := smoothstep(0.0, 0.32, t)
			var fall := smoothstep(0.68, 1.0, t)
			var pivot := smoothstep(0.3, 0.7, t)
			return Transform3D(Basis(Vector3.UP, -PI * eased * _direction) * Basis(Vector3.RIGHT, -PI * 0.5 * (rise - fall)) * Basis(Vector3.UP, PI * pivot * _direction), Vector3.ZERO)
		Maneuver.BOMBING_RUN:
			angles = Vector3(sin(turn) * 0.62, 0.0, sin(turn) * 1.0 * _direction)
	return Transform3D(Basis.from_euler(angles), offset)
