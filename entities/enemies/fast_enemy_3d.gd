extends BasicEnemy3D
class_name FastEnemy3D
## Native Fast lineage: evolving weave, reactive sidestep, and phase dash.
## All displacement stays on X/Z; warnings and feedback are presentation only.

const Projectile := preload("res://entities/projectiles/projectile_3d.gd")
const Effect := preload("res://effects/native_effect_3d.gd")
const FAST_STATS := [
	preload("res://entities/enemies/fast_enemy_generation_1.tres"),
	preload("res://entities/enemies/fast_enemy_generation_2.tres"),
	preload("res://entities/enemies/fast_enemy_generation_3.tres"),
	preload("res://entities/enemies/fast_enemy_generation_4.tres"),
]
const HITBOX_PIXELS := [20.0, 21.0, 23.0, 25.0]
const SIDESTEP_SCAN_SECONDS := 0.12
const SIDESTEP_COOLDOWN_SECONDS := 2.5
const SIDESTEP_DISTANCE_PIXELS := 44.0
const PROJECTILE_ALERT_PIXELS := 95.0
const PHASE_WARNING_SECONDS := 0.4
const PHASE_DASH_SECONDS := 0.16
const PHASE_DISTANCE_PIXELS := 100.0

enum PhaseState { WAITING, WARNING, DASHING, COMPLETE }

@export_range(0.0, 256.0, 0.5) var weave_amplitude_pixels: float = 80.0
@export_range(0.0, 12.0, 0.1) var weave_frequency: float = 3.0

@onready var phase_warning: MeshInstance3D = $Attachments/PhaseWarning

var _start_position := Vector3.ZERO
var _screen_travel_direction := Vector2.ZERO
var _screen_perpendicular := Vector2.ZERO
var _weave_time := 0.0
var _amplitude := 80.0
var _frequency := 3.0
var _pattern_timer := 0.0
var _sidestep_cooldown := 0.0
var _scan_timer := 0.0
var _visible_time := 0.0
var _phase_state := PhaseState.WAITING
var _phase_timer := 1.5
var _phase_displacement := Vector3.ZERO


func _is_basic_lineage() -> bool:
	return false


func _get_generation_stats() -> GenerationStats:
	return FAST_STATS[generation - 1]


func _configure_movement() -> void:
	_start_position = global_position
	_screen_travel_direction = _flight_space.combat_motion_to_screen(_heading).normalized()
	_screen_perpendicular = Vector2(-_screen_travel_direction.y, _screen_travel_direction.x)
	velocity = _flight_space.screen_motion_to_combat(_screen_travel_direction * _speed_pixels)
	_weave_time = 0.0
	_amplitude = weave_amplitude_pixels
	_frequency = weave_frequency
	_pattern_timer = randf_range(1.4, 2.2)
	_sidestep_cooldown = 0.0
	_scan_timer = randf_range(0.0, SIDESTEP_SCAN_SECONDS)
	_visible_time = 0.0
	_phase_state = PhaseState.WAITING
	_phase_timer = 1.5
	_phase_displacement = Vector3.ZERO
	phase_warning.hide()
	var hitbox_scale: float = HITBOX_PIXELS[generation - 1] / HITBOX_PIXELS[0]
	collision_shape.scale = Vector3(hitbox_scale, 1.0, hitbox_scale)


func _advance_movement(delta: float) -> void:
	var previous_position := global_position
	_weave_time += delta
	var in_view := _inside_view()
	if in_view:
		_visible_time += delta
	_pattern_timer -= delta
	_sidestep_cooldown = maxf(0.0, _sidestep_cooldown - delta)
	# Hold the weave settings steady during a telegraphed dash.
	if generation >= 2 and _pattern_timer <= 0.0 and not _phase_in_progress():
		_change_pattern()
	if generation >= 3 and in_view and not _phase_in_progress() and _sidestep_cooldown <= 0.0:
		_scan_timer -= delta
		if _scan_timer <= 0.0:
			_scan_timer = SIDESTEP_SCAN_SECONDS
			_try_reactive_sidestep()
	if generation >= 4:
		_update_phase(delta, in_view)
	var screen_offset := _screen_travel_direction * (_speed_pixels * _weave_time)
	screen_offset += _screen_perpendicular * sin(_weave_time * _frequency) * _amplitude
	global_position = _start_position + _flight_space.screen_motion_to_combat(screen_offset)
	global_position.y = 0.0
	velocity = (global_position - previous_position) / maxf(delta, 0.00001)
	if _phase_state == PhaseState.WARNING:
		_update_phase_warning()


func _change_pattern() -> void:
	_pattern_timer = randf_range(1.4, 2.2)
	var old_offset := sin(_weave_time * _frequency) * _amplitude
	_amplitude = randf_range(48.0, 104.0)
	_frequency = randf_range(2.4, 4.6)
	var new_offset := sin(_weave_time * _frequency) * _amplitude
	# Recenter when changing frequency so the new pattern starts continuously.
	_start_position += _flight_space.screen_motion_to_combat(_screen_perpendicular * (old_offset - new_offset))
	if _inside_view():
		_play_feedback(0.35)


func _try_reactive_sidestep() -> void:
	for node in get_tree().get_nodes_in_group(&"player_projectiles"):
		var projectile := node as Projectile
		if projectile == null or not projectile.is_active:
			continue
		var offset := _flight_space.combat_motion_to_screen(global_position - projectile.global_position)
		if offset.is_zero_approx() or offset.length_squared() > PROJECTILE_ALERT_PIXELS * PROJECTILE_ALERT_PIXELS:
			continue
		var shot_direction := _flight_space.combat_motion_to_screen(projectile.velocity).normalized()
		if shot_direction.dot(offset.normalized()) <= 0.78:
			continue
		var side := Vector2(-shot_direction.y, shot_direction.x)
		var shift := _choose_shift(side, SIDESTEP_DISTANCE_PIXELS)
		if shift.is_zero_approx():
			continue
		_start_position += shift
		_sidestep_cooldown = SIDESTEP_COOLDOWN_SECONDS
		_play_feedback(0.5)
		return


func _update_phase(delta: float, in_view: bool) -> void:
	match _phase_state:
		PhaseState.WAITING:
			_phase_timer -= delta
			if _phase_timer <= 0.0 and in_view and _visible_time >= 0.35:
				_phase_displacement = _choose_shift(_screen_perpendicular, PHASE_DISTANCE_PIXELS)
				if _phase_displacement.is_zero_approx():
					return
				_phase_state = PhaseState.WARNING
				_phase_timer = PHASE_WARNING_SECONDS
				phase_warning.show()
		PhaseState.WARNING:
			if not in_view:
				_cancel_phase()
				return
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				# Motion during the warning can shorten the available lane. Keep
				# its direction, but trim the displacement at the visible bounds.
				_phase_displacement = _trim_shift(_phase_displacement)
				_phase_state = PhaseState.DASHING
				_phase_timer = PHASE_DASH_SECONDS
				phase_warning.hide()
				_play_feedback(0.8)
		PhaseState.DASHING:
			var step := minf(delta, _phase_timer)
			_start_position += _phase_displacement * (step / PHASE_DASH_SECONDS)
			_phase_timer -= step
			if _phase_timer <= 0.0:
				_phase_state = PhaseState.COMPLETE


func _choose_shift(screen_side: Vector2, pixels: float) -> Vector3:
	var direction := _flight_space.screen_motion_to_combat(screen_side.normalized() * pixels)
	if randf() < 0.5:
		direction = -direction
	var first := _trim_shift(direction)
	var opposite := _trim_shift(-direction)
	return first if first.length_squared() >= opposite.length_squared() else opposite


func _trim_shift(shift: Vector3) -> Vector3:
	var bounds := _flight_space.get_combat_bounds(-HITBOX_PIXELS[generation - 1])
	var target := global_position + shift
	target.x = clampf(target.x, bounds.position.x, bounds.end.x)
	target.z = clampf(target.z, bounds.position.y, bounds.end.y)
	# Scale the original vector rather than steering the warning at an edge.
	var fraction := 1.0
	if not is_zero_approx(shift.x):
		fraction = minf(fraction, (target.x - global_position.x) / shift.x)
	if not is_zero_approx(shift.z):
		fraction = minf(fraction, (target.z - global_position.z) / shift.z)
	return shift * clampf(fraction, 0.0, 1.0)


func _update_phase_warning() -> void:
	var screen_direction := _flight_space.combat_motion_to_screen(_phase_displacement).normalized()
	var across := _flight_space.screen_motion_to_combat(Vector2(-screen_direction.y, screen_direction.x) * 4.0)
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


func _inside_view() -> bool:
	return _flight_space.get_combat_bounds().has_point(Vector2(global_position.x, global_position.z))


func _phase_in_progress() -> bool:
	return _phase_state == PhaseState.WARNING or _phase_state == PhaseState.DASHING


func _cancel_phase() -> void:
	_phase_state = PhaseState.COMPLETE
	_phase_timer = 0.0
	phase_warning.hide()


func _finish(reason: FinishReason) -> void:
	_cancel_phase()
	super._finish(reason)
