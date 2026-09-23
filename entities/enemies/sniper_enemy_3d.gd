extends BasicEnemy3D
class_name SniperEnemy3D
## Native Sniper lineage with locked warnings, predictive fire, and pooled
## rails. The craft flies a standoff strafe ring around the player instead of
## holding a fixed station, relocating outward when the player closes.

signal aimed_shot_fired(speed_pixels: float)

const ProjectileManager := preload("res://systems/projectile_manager_3d.gd")
const ShotTuning := preload("res://entities/projectiles/enemy_projectile_tuning.gd")

const ENTRY_BAND_PIXELS := 60.0
const HOLD_DURATION_SECONDS := 6.0
const HOLD_DURATION_GEN4_SECONDS := 9.0
const FIRST_SHOT_MIN_SECONDS := 0.6
const FIRST_SHOT_MAX_SECONDS := 1.2
const SHOT_INTERVAL_SECONDS := 1.55
const SHOT_SPEED_MIN_PIXELS := 430.0
const SHOT_SPEED_MAX_PIXELS := 500.0
const AIM_TELEGRAPH_SECONDS := 0.5
const HOLD_BREAK_DISTANCE_PIXELS := 260.0
const HOLD_BREAK_DISTANCE_HURT_PIXELS := 330.0
const REPOSITION_SECONDS := 0.45
const STRAFE_RADIUS_PIXELS := 330.0
const STRAFE_TANGENTIAL_PIXELS := 105.0
const STRAFE_WEAVE_PIXELS := 48.0
const STRAFE_RADIUS_MIN_PIXELS := 240.0
const STRAFE_RADIUS_MAX_PIXELS := 420.0

const SNIPER_STATS := [
	preload("res://entities/enemies/sniper_enemy_generation_1.tres"),
	preload("res://entities/enemies/sniper_enemy_generation_2.tres"),
	preload("res://entities/enemies/sniper_enemy_generation_3.tres"),
	preload("res://entities/enemies/sniper_enemy_generation_4.tres"),
]

@export var aim_material_gen2: Material
@export var aim_material_later: Material

@onready var aim_warning: MeshInstance3D = $Attachments/AimWarning
var _bracket_warnings: Array[MeshInstance3D] = []
var _bracket_shot := false
var _locked_direction := Vector3.ZERO
var _ordinary_shots := 0
var _rail_used := false
var _visible_time := 0.0
var _shoot_timer := 0.0
var _has_withdrawn := false


func _get_generation_stats() -> GenerationStats:
	return SNIPER_STATS[generation - 1]


func _is_basic_lineage() -> bool:
	return false


func engagement_seconds() -> float:
	return HOLD_DURATION_GEN4_SECONDS if generation >= 4 else HOLD_DURATION_SECONDS


func _configure_movement() -> void:
	if _bracket_warnings.is_empty():
		for index in 2:
			var warning := MeshInstance3D.new()
			warning.mesh = aim_warning.mesh
			aim_warning.get_parent().add_child(warning)
			_bracket_warnings.append(warning)
	_bracket_shot = false
	_locked_direction = Vector3.ZERO
	_ordinary_shots = 0
	_rail_used = false
	_visible_time = 0.0
	_hide_aim_warning()
	aim_warning.material_override = aim_material_gen2 if generation == 2 else aim_material_later
	var envelopes := [Vector2(32, 32), Vector2(35, 34), Vector2(38, 36), Vector2(40, 38)]
	var envelope: Vector2 = envelopes[generation - 1]
	collision_shape.scale = Vector3(envelope.x / 32.0, 1.0, envelope.y / 32.0)
	_configure_strafe(STRAFE_RADIUS_PIXELS, STRAFE_TANGENTIAL_PIXELS, STRAFE_WEAVE_PIXELS)
	_shoot_timer = randf_range(FIRST_SHOT_MIN_SECONDS, FIRST_SHOT_MAX_SECONDS)
	_has_withdrawn = false
	state = State.ENTRY
	state_remaining = 0.0
	velocity = _flight_space.screen_motion_to_combat(
		_flight_space.combat_motion_to_screen(_heading).normalized() * _speed_pixels
	)
	velocity.y = 0.0


func _advance_movement(delta: float) -> void:
	_observe_player()
	if _inside_view():
		_visible_time += delta
	match state:
		State.ENTRY:
			_advance_strafe(delta, 1.0)
			if _player_distance_pixels > 0.0 and _player_distance_pixels <= _strafe_radius + ENTRY_BAND_PIXELS:
				_enter(State.HOLD)
			return
		State.HOLD:
			_advance_strafe(delta, 1.0)
			if _tick_engagement(delta):
				_begin_sniper_withdraw()
				return
			if _should_break_hold():
				_begin_reposition()
				return
			_update_aim_and_fire(delta)
			return
		State.AIM:
			_advance_strafe(delta, 0.9)
			var muzzle := get_socket(&"MuzzleCenter") as Marker3D
			if muzzle != null:
				_face_target(muzzle)
				_update_warning(muzzle)
			state_remaining = maxf(0.0, state_remaining - delta)
			if state_remaining <= 0.0:
				if muzzle != null:
					_fire_locked_shot(muzzle, true)
				_enter(State.HOLD)
			return
		State.REPOSITION:
			_advance_strafe(delta, 1.1)
			state_remaining = maxf(0.0, state_remaining - delta)
			if state_remaining <= 0.0:
				play_motion(&"cruise")
				_enter(State.HOLD)
			return
		State.WITHDRAW:
			_integrate_velocity(delta)
			return
		_:
			_advance_strafe(delta, 1.0)
			if _tick_engagement(delta):
				_begin_sniper_withdraw()
			return


func _hold_break_distance_pixels() -> float:
	if _health_fraction() < 0.5:
		return HOLD_BREAK_DISTANCE_HURT_PIXELS
	return HOLD_BREAK_DISTANCE_PIXELS


func _should_break_hold() -> bool:
	if _observed_player == null or _player_distance_pixels <= 0.0:
		return false
	return _player_distance_pixels < _hold_break_distance_pixels()


func _begin_reposition() -> void:
	_hide_aim_warning()
	play_motion(&"cruise")
	_strafe_radius = clampf(
		_strafe_radius + 90.0, STRAFE_RADIUS_MIN_PIXELS, STRAFE_RADIUS_MAX_PIXELS
	)
	_strafe_angle += _strafe_sign * 0.7
	_strafe_sign = -_strafe_sign
	_enter(State.REPOSITION, REPOSITION_SECONDS)


func _begin_sniper_withdraw() -> void:
	_has_withdrawn = true
	_begin_withdraw()


func _update_aim_and_fire(delta: float) -> void:
	var player := _observed_player
	var muzzle := get_socket(&"MuzzleCenter") as Marker3D
	if player == null or muzzle == null:
		return
	_face_target(muzzle)
	_shoot_timer -= delta
	if _shoot_timer > 0.0:
		return
	_shoot_timer = SHOT_INTERVAL_SECONDS
	_begin_aimed_shot(player, muzzle)


func _face_target(muzzle: Marker3D) -> void:
	if _observed_player == null:
		return
	var aim_direction := _observed_player.global_position - muzzle.global_position
	aim_direction.y = 0.0
	if aim_direction.is_zero_approx():
		return
	var normalized_direction := aim_direction.normalized()
	rotation.y = atan2(-normalized_direction.x, -normalized_direction.z)
	collision_shape.global_rotation = Vector3.ZERO


func _begin_aimed_shot(player: Node3D, muzzle: Marker3D) -> void:
	var can_special := _visible_time >= 0.35 and _inside_view()
	_bracket_shot = generation >= 2 and _ordinary_shots % 3 == 2 and can_special
	if generation >= 4 and _ordinary_shots >= 3 and not _rail_used and can_special:
		var hazards := get_tree().get_first_node_in_group(
			&"native_3d_hazard_manager"
		) as NativeHazardManager
		if hazards != null and hazards.spawn_rail_beam(
			muzzle.global_position, player.global_position - muzzle.global_position, self
		) != null:
			_rail_used = true
			play_motion(&"windup", 0.9, true)
			return
	var target := player.global_position
	if generation >= 2 and _ordinary_shots % 3 != 0:
		target = _predicted_player
	_locked_direction = target - muzzle.global_position
	_locked_direction.y = 0.0
	_locked_direction = _locked_direction.normalized()
	if generation >= 2 and can_special:
		play_motion(&"windup", AIM_TELEGRAPH_SECONDS, true)
		aim_warning.show()
		_update_warning(muzzle)
		_enter(State.AIM, AIM_TELEGRAPH_SECONDS)
	else:
		_fire_locked_shot(muzzle)


func _hide_aim_warning() -> void:
	aim_warning.hide()
	for warning in _bracket_warnings:
		warning.hide()


func _update_warning(muzzle: Marker3D) -> void:
	var screen_direction := _flight_space.combat_motion_to_screen(_locked_direction).normalized()
	_position_warning(aim_warning, muzzle, screen_direction)
	for index in _bracket_warnings.size():
		var warning := _bracket_warnings[index]
		warning.visible = _bracket_shot
		warning.material_override = aim_warning.material_override
		_position_warning(
			warning, muzzle, screen_direction.rotated(-0.16 if index == 0 else 0.16)
		)


func _position_warning(
	warning: MeshInstance3D, muzzle: Marker3D, screen_direction: Vector2
) -> void:
	var along := _flight_space.screen_motion_to_combat(screen_direction)
	var across := _flight_space.screen_motion_to_combat(
		Vector2(-screen_direction.y, screen_direction.x)
	)
	var width := 2.8 if generation == 2 else 4.2
	warning.global_transform = Transform3D(
		Basis(across * (width + 12.0), Vector3.UP, along * 900.0),
		Vector3(muzzle.global_position.x, 0.04, muzzle.global_position.z) + along * 450.0
	)
	warning.set_instance_shader_parameter(&"lane_size", Vector2(width, 900.0))
	var remaining := state_remaining if state == State.AIM else 0.0
	warning.set_instance_shader_parameter(
		&"charge_progress", clampf(1.0 - remaining / AIM_TELEGRAPH_SECONDS, 0.0, 1.0)
	)


func _fire_locked_shot(muzzle: Marker3D, telegraphed: bool = false) -> void:
	_hide_aim_warning()
	var manager := get_tree().get_first_node_in_group(
		&"native_3d_projectile_manager"
	) as ProjectileManager
	if manager == null or not manager.is_ready or _locked_direction.is_zero_approx():
		return
	var speed := (
		randf_range(SHOT_SPEED_MIN_PIXELS, SHOT_SPEED_MAX_PIXELS)
		if generation == 1
		else 550.0
	)
	if telegraphed:
		speed *= ShotTuning.TELEGRAPH_SPEED_MULTIPLIER
	play_motion(&"attack")
	manager.fire_enemy_projectile(muzzle.global_position, _locked_direction, speed)
	if _bracket_shot:
		var screen_aim := _flight_space.combat_motion_to_screen(_locked_direction).normalized()
		for side in [-1.0, 1.0]:
			manager.fire_enemy_projectile(
				muzzle.global_position,
				_flight_space.input_to_combat_direction(screen_aim.rotated(side * 0.16)),
				speed * 0.8
			)
	_ordinary_shots += 1
	aimed_shot_fired.emit(speed)


func _finish(reason: FinishReason) -> void:
	_hide_aim_warning()
	super._finish(reason)


func get_attack_status() -> Dictionary:
	var debug := get_debug_state()
	debug["ordinary_shots"] = _ordinary_shots
	debug["locked_direction"] = _locked_direction
	debug["rail_used"] = _rail_used
	debug["holding"] = state in [State.HOLD, State.AIM]
	debug["has_withdrawn"] = _has_withdrawn
	return debug
