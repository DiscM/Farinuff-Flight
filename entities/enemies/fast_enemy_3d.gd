extends BasicEnemy3D
class_name FastEnemy3D
## Native Fast lineage: a tight player-relative strafing weave, reactive
## sidestep, and phase dash. The craft never parks; every state keeps it
## flying the strafe ring except the committed phase dash.

const Effect := preload("res://effects/native_effect_3d.gd")
const FAST_STATS := [
	preload("res://entities/enemies/fast_enemy_generation_1.tres"),
	preload("res://entities/enemies/fast_enemy_generation_2.tres"),
	preload("res://entities/enemies/fast_enemy_generation_3.tres"),
	preload("res://entities/enemies/fast_enemy_generation_4.tres"),
]
const HITBOX_PIXELS := [20.0, 21.0, 23.0, 25.0]
const PHASE_WARNING_SECONDS := 0.4
const PHASE_DASH_SECONDS := 0.16
const PHASE_DISTANCE_PIXELS := 100.0
const PHASE_COOLDOWN_SECONDS := 1.5
const STRAFE_RADIUS_PIXELS := 175.0
const STRAFE_TANGENTIAL_PIXELS := 130.0
const STRAFE_WEAVE_PIXELS := 42.0
const PATTERN_MIN := 1.4
const PATTERN_MAX := 2.2

@export_range(0.0, 256.0, 0.5) var weave_amplitude_pixels: float = 80.0
@export_range(0.0, 12.0, 0.1) var weave_frequency: float = 3.0

@onready var phase_warning: MeshInstance3D = $Attachments/PhaseWarning

var _pattern_timer := 0.0
var _visible_time := 0.0
var _phase_displacement := Vector3.ZERO
var _phase_cooldown := PHASE_COOLDOWN_SECONDS
var _phase_origin := Vector3.ZERO


func _is_basic_lineage() -> bool:
	return false


func _get_generation_stats() -> GenerationStats:
	return FAST_STATS[generation - 1]


func _configure_movement() -> void:
	_configure_strafe(STRAFE_RADIUS_PIXELS, STRAFE_TANGENTIAL_PIXELS, STRAFE_WEAVE_PIXELS)
	_strafe_weave = weave_amplitude_pixels * 0.5
	velocity = _flight_space.screen_motion_to_combat(
		_flight_space.combat_motion_to_screen(_heading).normalized() * _speed_pixels
	)
	_pattern_timer = randf_range(PATTERN_MIN, PATTERN_MAX)
	_visible_time = 0.0
	_phase_displacement = Vector3.ZERO
	_phase_origin = global_position
	_phase_cooldown = PHASE_COOLDOWN_SECONDS
	phase_warning.hide()
	state = State.TRANSIT
	state_remaining = 0.0
	var hitbox_scale: float = HITBOX_PIXELS[generation - 1] / HITBOX_PIXELS[0]
	collision_shape.scale = Vector3(hitbox_scale, 1.0, hitbox_scale)


func _advance_movement(delta: float) -> void:
	_observe_player()
	_evade_cooldown = maxf(0.0, _evade_cooldown - delta)
	var in_view := _inside_view()
	if in_view:
		_visible_time += delta
	match state:
		State.EVADE:
			_advance_strafe(delta, 1.1)
			state_remaining = maxf(0.0, state_remaining - delta)
			if state_remaining <= 0.0:
				_enter(State.TRANSIT)
			return
		State.PHASE_WINDUP:
			if not in_view:
				_cancel_phase()
				return
			_advance_strafe(delta, 0.85)
			_update_phase_warning()
			state_remaining = maxf(0.0, state_remaining - delta)
			if state_remaining <= 0.0:
				_phase_displacement = _trim_shift(_phase_displacement)
				_phase_origin = global_position
				phase_warning.hide()
				play_motion(&"attack", PHASE_DASH_SECONDS)
				_play_feedback(0.8)
				_enter(State.PHASE_DASH, PHASE_DASH_SECONDS)
			return
		State.PHASE_DASH:
			var step := minf(delta, state_remaining)
			var progress := step / maxf(PHASE_DASH_SECONDS, 0.0001)
			global_position += _phase_displacement * progress
			global_position.y = 0.0
			velocity = _phase_displacement / maxf(PHASE_DASH_SECONDS, 0.0001)
			state_remaining = maxf(0.0, state_remaining - step)
			if state_remaining <= 0.0:
				_strafe_angle += _strafe_sign * 0.8
				_enter(State.REPOSITION, 0.3)
			return
		State.REPOSITION:
			_advance_strafe(delta, 1.0)
			state_remaining = maxf(0.0, state_remaining - delta)
			if state_remaining <= 0.0:
				_enter(State.TRANSIT)
			return
		State.WITHDRAW:
			_integrate_velocity(delta)
			return
		_:
			pass
	if _tick_engagement(delta):
		_begin_withdraw()
		return
	_phase_cooldown = maxf(0.0, _phase_cooldown - delta)
	_pattern_timer -= delta
	if generation >= 2 and _pattern_timer <= 0.0:
		_change_pattern()
	if generation >= 3 and in_view and _evade_cooldown <= 0.0:
		_evade_scan_timer -= delta
		if _evade_scan_timer <= 0.0:
			_evade_scan_timer = EVADE_SCAN_SECONDS
			if _try_begin_weave_evade():
				return
	if generation >= 4 and in_view and _visible_time >= 0.35 and _phase_cooldown <= 0.0:
		if _try_begin_phase():
			return
	_advance_strafe(delta)


func _change_pattern() -> void:
	_pattern_timer = randf_range(PATTERN_MIN, PATTERN_MAX)
	_strafe_weave = weave_amplitude_pixels * randf_range(0.35, 0.75)
	_strafe_tangential = maxf(
		STRAFE_TANGENTIAL_PIXELS * randf_range(0.8, 1.2),
		STRAFE_MINIMUM_TANGENTIAL_PIXELS
	)
	if _inside_view() and _observed_player != null:
		var desired := _flight_space.combat_motion_to_screen(
			_predicted_player - global_position
		).normalized()
		if not desired.is_zero_approx():
			var toward := _flight_space.combat_motion_to_screen(
				_strafe_target() - global_position
			).normalized()
			if toward.dot(desired) < 0.0:
				_strafe_sign = -_strafe_sign
		_play_feedback(0.35)


func _try_begin_weave_evade() -> bool:
	if state != State.TRANSIT:
		return false
	var projectile := _find_incoming_projectile()
	if projectile == null:
		return false
	var shot_direction := _flight_space.combat_motion_to_screen(projectile.velocity).normalized()
	var side := Vector2(-shot_direction.y, shot_direction.x)
	var shift := _choose_shift(side, EVADE_DISTANCE_PIXELS)
	if shift.is_zero_approx():
		return false
	global_position += shift
	global_position.y = 0.0
	_strafe_angle += _strafe_sign * 0.5
	_strafe_radius = clampf(_strafe_radius + (20.0 if randf() < 0.5 else -20.0), 110.0, 280.0)
	play_motion(&"attack", 0.2)
	_evade_cooldown = EVADE_COOLDOWN_SECONDS
	_play_feedback(0.5)
	_enter(State.EVADE, EVADE_DURATION_SECONDS)
	return true


func _try_begin_phase() -> bool:
	if state != State.TRANSIT:
		return false
	_phase_displacement = _choose_shift(_screen_perpendicular_axis(), PHASE_DISTANCE_PIXELS)
	if _phase_displacement.is_zero_approx():
		return false
	_phase_cooldown = PHASE_COOLDOWN_SECONDS
	play_motion(&"windup", PHASE_WARNING_SECONDS, true)
	phase_warning.show()
	_update_phase_warning()
	_enter(State.PHASE_WINDUP, PHASE_WARNING_SECONDS)
	return true


func _screen_perpendicular_axis() -> Vector2:
	var travel := _flight_space.combat_motion_to_screen(_heading).normalized()
	if travel.is_zero_approx():
		travel = Vector2.DOWN
	return Vector2(-travel.y, travel.x)


func _update_phase_warning() -> void:
	var screen_direction := _flight_space.combat_motion_to_screen(_phase_displacement).normalized()
	if screen_direction.is_zero_approx():
		return
	var across := _flight_space.screen_motion_to_combat(
		Vector2(-screen_direction.y, screen_direction.x) * 4.0
	)
	phase_warning.global_transform = Transform3D(
		Basis(across, Vector3.UP, _phase_displacement),
		global_position + _phase_displacement * 0.5 + Vector3.UP * 0.04
	)


func _play_feedback(intensity: float) -> void:
	var game := get_tree().get_first_node_in_group(&"native_3d_gameplay")
	if game == null:
		return
	var manager := game.get("effect_manager") as Node
	if manager != null:
		manager.play_effect(Effect.EffectKind.BOOST, global_position, _heading, intensity)


func _cancel_phase() -> void:
	phase_warning.hide()
	play_motion(&"cruise")
	if state in [State.PHASE_WINDUP, State.PHASE_DASH]:
		_enter(State.TRANSIT)


func _finish(reason: FinishReason) -> void:
	_cancel_phase()
	super._finish(reason)


func get_debug_state() -> Dictionary:
	var debug := super.get_debug_state()
	debug["phase_displacement"] = _phase_displacement
	debug["visible_time"] = _visible_time
	debug["phase_cooldown"] = _phase_cooldown
	return debug
