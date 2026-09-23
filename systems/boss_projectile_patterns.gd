extends Node3D
class_name BossProjectilePatterns
## Hull-specific projectile geometry. Scheduling belongs to AttackExecutor.
## Every layer uses a locked aim and preserves the hull's authored escape gaps.
const Section := preload("res://entities/enemies/boss_section_3d.gd")
const ProjectileManager := preload("res://systems/projectile_manager_3d.gd")
const Shot := preload("res://entities/projectiles/projectile_3d.gd")
const ShotTuning := preload("res://entities/projectiles/enemy_projectile_tuning.gd")
const SHOT_COLORS := [Color(1.0, 0.42, 0.1), Color(1.0, 0.8, 0.25), Color(0.65, 0.4, 1.0), Color(1.0, 0.25, 0.55), Color(1.0, 0.95, 0.8)]
var _flight_space: FlightSpace3D
var variant := 0
var _sections: Array[Section] = []
var _attack_plan: BossAttackPlan
var _locked_aim := Vector2.DOWN
var _attack_phase := 0
var _attack_mixup := false
var _attack_has_breakers := true
var _volley_index := 0
var _pattern_index := 0
var _burst_step := 0
var _echo_marks: Array[Dictionary] = []

func configure(space: FlightSpace3D, hull: int, sections: Array[Section]) -> void:
	_flight_space = space
	variant = hull
	_sections = sections
	cancel()

func fire(plan: BossAttackPlan, step: int) -> void:
	global_position = plan.origin
	_attack_plan = plan
	_locked_aim = plan.aim
	_attack_phase = plan.phase
	_attack_mixup = plan.definition.alternate_pattern
	_volley_index = plan.sequence
	_pattern_index = plan.sequence
	_burst_step = step
	_fire_pattern()

func advance(delta: float) -> void:
	_update_echo_marks(delta)

func has_pending() -> bool:
	return not _echo_marks.is_empty()

func cancel() -> void:
	_clear_echo_marks()
	_attack_plan = null

## Continuous suppressive fire between committed volleys. One straight shot at
## the predictor's intercept point; volley geometry stays in `_fire_pattern`.
func fire_support(aim: Vector2, origin: Vector3, speed_pixels: float, damage: int = 1) -> void:
	var manager := get_tree().get_first_node_in_group(&"native_3d_projectile_manager") as ProjectileManager
	if manager == null or not manager.is_ready or aim.is_zero_approx():
		return
	var direction := _flight_space.input_to_combat_direction(aim.normalized())
	if direction.is_zero_approx():
		return
	manager.fire_telegraphed_enemy_projectile(
		origin,
		direction,
		speed_pixels,
		Shot.Motion.STRAIGHT,
		SHOT_COLORS[variant],
		variant,
		damage
	)

func _emit_shot(manager: ProjectileManager, origin: Vector3, direction: Vector3, speed: float, motion: Shot.Motion, tint: Color, style: int, damage: int = -1, speed_scale: float = -1.0) -> void:
	if damage < 0:
		damage = _attack_plan.definition.damage
	if speed_scale < 0.0:
		speed_scale = _attack_plan.definition.projectile_speed_scale
	manager.fire_telegraphed_enemy_projectile(origin, direction, speed * speed_scale, motion, tint, style, damage)

func _fire_pattern() -> void:
	var manager := get_tree().get_first_node_in_group(&"native_3d_projectile_manager") as ProjectileManager
	if manager == null:
		return
	if _attack_mixup:
		match variant:
			0: _fire_commander_mixup(manager)
			1: _fire_siege_mixup(manager)
			2: _fire_storm_mixup(manager)
			3: _place_echo_mixup()
			4: _fire_core_mixup(manager)
		return
	var step := float(_burst_step)
	var turn := -1.0 if _volley_index % 2 == 0 else 1.0
	var p := _attack_phase
	match variant:
		0: # Commander: spearheads become flanking lances, then a sweeping assault.
			var aim := _locked_aim.rotated(turn * (step - 0.5) * 0.18)
			if p == 0:
				_fire_commander_lances(manager, global_position, aim, 7, 0.16, 240.0, Shot.Motion.ACCELERATING)
			elif p == 1:
				for side in [-1.0, 1.0]:
					_fire_commander_lances(manager, global_position, aim.rotated(side * 0.48), 4, 0.14, 235.0, Shot.Motion.ACCELERATING)
			else:
				_fire_commander_lances(manager, global_position, aim, 11, 0.14, 250.0, Shot.Motion.ACCELERATING, true)
		1: # Parallel masonry moves as a wall, not rays from a central fan.
			_fire_siege_wall(manager)
		2: # Tempest owns persistent circular motion; no aimed support volleys.
			if _burst_step == 0:
				_deploy_storm_orbit(manager)
		3: # Echoes threaten the return journey as well as their outward flight.
			_place_echo_mark()
		4: # Reactor pulses park in space before releasing along their original axes.
			var diagonal := p == 1 or (p == 2 and _burst_step % 2 == 1)
			var axis := _locked_aim.rotated(PI * 0.25 if diagonal else 0.0)
			_fire_core_arms(manager, axis, 4, 200.0, Shot.Motion.STOP_RELEASE)

func _fire_commander_mixup(manager: ProjectileManager) -> void:
	var fast := _burst_step % 2 == 1
	var speed := ShotTuning.FAST_SPEED if fast else ShotTuning.SLOW_SPEED
	var motion := Shot.Motion.STRAIGHT if fast else Shot.Motion.BRAKING
	var turn := -1.0 if _volley_index % 4 < 2 else 1.0
	match _attack_phase:
		0:
			_fire_commander_lances(manager, global_position, _locked_aim, 5 if fast else 9, 0.16 if fast else 0.2, speed, motion)
		1:
			for side in [-1.0, 1.0]:
				var aim := _locked_aim.rotated(side * (0.32 if fast else 0.85))
				_fire_commander_lances(manager, global_position, aim, 5, 0.14, speed, motion)
		2:
			for side in [-1.0, 1.0]:
				var aim := _locked_aim.rotated(side * (0.9 - _burst_step * 0.16) + turn * 0.12)
				_fire_commander_lances(manager, global_position, aim, 6, 0.16, speed, motion, fast)

func _fire_siege_mixup(manager: ProjectileManager) -> void:
	var fast := _burst_step % 2 == 1
	var aim := _locked_aim
	var gap := 0
	var motion := Shot.Motion.STRAIGHT
	if _attack_phase == 1:
		aim = aim.rotated(-0.38 if fast else 0.38)
	elif _attack_phase == 2:
		aim = aim.rotated((_burst_step - 1.5) * 0.22)
		gap = [-2, 0, 2, 0][_burst_step % 4]
		motion = Shot.Motion.STRAIGHT if fast else Shot.Motion.STOP_RELEASE
	_fire_siege_row(manager, aim, gap, ShotTuning.FAST_SPEED if fast else ShotTuning.SLOW_SPEED, motion)

func _fire_storm_mixup(manager: ProjectileManager) -> void:
	var count := 16
	var axis := _locked_aim.rotated(_burst_step * (0.24 if _attack_phase == 2 else 0.12))
	for slot in count:
		# Remove pod-owned spokes without redistributing the surviving lanes.
		if slot % 8 == 3 and not _sections[0].is_active:
			continue
		if slot % 8 == 5 and not _sections[1].is_active:
			continue
		var direction := axis.rotated(slot * TAU / count)
		# Opposed openings include the full bend of a curved ribbon.
		var gap := 0.95 if _attack_phase == 1 else 0.4
		if absf(axis.angle_to(direction)) < gap or absf((-axis).angle_to(direction)) < gap:
			continue
		var fast := (slot + _burst_step) % 2 == 1
		var motion := Shot.Motion.STRAIGHT
		if _attack_phase == 1:
			motion = Shot.Motion.CURVE_LEFT if _burst_step % 2 == 0 else Shot.Motion.CURVE_RIGHT
		elif _attack_phase == 2 and not fast:
			motion = Shot.Motion.BRAKING if _burst_step % 2 == 0 else Shot.Motion.STOP_RELEASE
		var origin := global_position + _flight_space.screen_motion_to_combat(direction * 140.0)
		if _shot_origin_is_clear(origin):
			_emit_shot(manager, origin, _flight_space.input_to_combat_direction(direction), ShotTuning.FAST_SPEED if fast else ShotTuning.SLOW_SPEED, motion, SHOT_COLORS[2], 2)

func _place_echo_mixup() -> void:
	if _attack_phase == 1 and _active_section_count() > 0:
		for index in _sections.size():
			if _sections[index].is_active:
				var side := -1.0 if index == 0 else 1.0
				_place_echo_mark(_locked_aim.orthogonal() * side * 130.0, true, side * 0.3, index * 0.35)
	else:
		_place_echo_mark(Vector2.ZERO, true)

func _fire_core_mixup(manager: ProjectileManager) -> void:
	var fast := _burst_step % 2 == 1
	var axis := _locked_aim
	var arms := 4
	var motion := Shot.Motion.STRAIGHT if fast else Shot.Motion.STOP_RELEASE
	if _attack_phase == 0:
		axis = axis.rotated(PI * 0.25 if fast else 0.0)
	elif _attack_phase == 1:
		axis = axis.rotated((_burst_step - 1) * 0.3)
		motion = Shot.Motion.STRAIGHT if fast else Shot.Motion.BRAKING
	else:
		arms = 6
		axis = axis.rotated(_burst_step * PI / 12.0)
	_fire_core_arms(manager, axis, arms, ShotTuning.FAST_SPEED if fast else ShotTuning.SLOW_SPEED, motion)

func _fire_core_arms(manager: ProjectileManager, axis: Vector2, arms: int, speed: float, motion: Shot.Motion) -> void:
	for arm in arms:
		var direction := axis.rotated(arm * TAU / arms)
		var across := direction.orthogonal()
		# The core retains one emitter; each surviving pod contributes a wing.
		for lane in range(-1, 2):
			if lane != 0 and not _sections[0 if lane < 0 else 1].is_active:
				continue
			var origin := global_position + _flight_space.screen_motion_to_combat(across * lane * 32.0)
			if _shot_origin_is_clear(origin):
				_emit_shot(manager, origin, _flight_space.input_to_combat_direction(direction), speed, motion, SHOT_COLORS[4], 4)

func _shot_origin_is_clear(origin: Vector3, cushion: float = 90.0) -> bool:
	var player := get_tree().get_first_node_in_group(&"player_craft") as Node3D
	return player == null or _flight_space.combat_motion_to_screen(origin - player.global_position).length() >= cushion

## Iron Bulwark masonry: a wide dense wall with one narrow breach. Casual
## strafing cannot clear it; the breach steps so a parked dodge lane dies.
const SIEGE_LANE_SPACING_PIXELS := 52.0
const SIEGE_HALF_LANES := 8

func _fire_siege_wall(manager: ProjectileManager) -> void:
	var gap := 0
	if _attack_phase == 1:
		gap = -4 if _burst_step % 2 == 0 else 4
	elif _attack_phase == 2:
		gap = [-5, -1, 3, 6][_burst_step % 4]
	_fire_siege_row(manager, _locked_aim, gap, 165.0, Shot.Motion.STRAIGHT)

func _fire_siege_row(manager: ProjectileManager, aim: Vector2, gap: int, speed: float, motion: Shot.Motion) -> void:
	var across := aim.orthogonal()
	for lane in range(-SIEGE_HALF_LANES, SIEGE_HALF_LANES + 1):
		if lane == gap:
			continue
		if absi(lane) >= SIEGE_HALF_LANES - 2 and not _sections[0 if lane < 0 else 1].is_active:
			continue
		var origin := global_position + _flight_space.screen_motion_to_combat(across * lane * SIEGE_LANE_SPACING_PIXELS)
		if not _shot_origin_is_clear(origin):
			continue
		var profile := Shot.Motion.BOOST_BREAKER if absi(lane) == SIEGE_HALF_LANES else motion
		_emit_shot(manager, origin, _flight_space.input_to_combat_direction(aim), speed, profile, SHOT_COLORS[1], 1)

func _fire_commander_lances(manager: ProjectileManager, origin: Vector3, aim: Vector2, count: int, spacing: float, speed: float, motion: Shot.Motion = Shot.Motion.STRAIGHT, breaker_center: bool = false) -> void:
	for index in count:
		var direction := aim.rotated((index - (count - 1) * 0.5) * spacing)
		var profile := Shot.Motion.BOOST_BREAKER if breaker_center and index == (count >> 1) else motion
		_fire_commander_shot(manager, origin, direction, speed, profile, index)

func _commander_escape_direction() -> Vector2:
	var side := -1.0 if _pattern_index % 2 == 0 else 1.0
	return _locked_aim.rotated(side * 0.42)

func _fire_commander_shot(manager: ProjectileManager, origin: Vector3, direction: Vector2, speed: float, motion: Shot.Motion, slot: int) -> void:
	if not _shot_origin_is_clear(origin):
		return
	# Commander lance groups preserve a shared sidestep corridor.
	# Bound parallax from offset weapons outside the boss's 120-pixel near zone.
	# A single sample farther out can miss a ray crossing the lane on approach.
	var origin_offset := _flight_space.combat_motion_to_screen(origin - global_position).length()
	var gap_angle := absf(_commander_escape_direction().angle_to(direction))
	var clearance := 0.22 + asin(clampf(origin_offset / 120.0, 0.0, 1.0))
	if motion in [Shot.Motion.CURVE_LEFT, Shot.Motion.CURVE_RIGHT]:
		# Keep the whole bounded bend out of the corridor, not just its launch ray.
		clearance += 0.66
	if gap_angle < clearance:
		return
	# Every sixth slot is cyan; its offset alternates between successive layers.
	# Straight motion keeps these dangerous shots predictable within the weave.
	var profile := motion
	if _attack_has_breakers and (slot + _burst_step * 3) % 6 == 2:
		profile = Shot.Motion.BOOST_BREAKER
	_emit_shot(manager, origin, _flight_space.input_to_combat_direction(direction), speed, profile, SHOT_COLORS[variant].lightened(_attack_phase * 0.08), variant)

func _active_section_count() -> int:
	var count := 0
	for section in _sections:
		if section.is_active:
			count += 1
	return count

func _deploy_storm_orbit(manager: ProjectileManager) -> void:
	var reverse := _attack_phase == 1 or (_attack_phase == 2 and _pattern_index % 4 >= 2)
	var rotation_sign := -1.0 if reverse else 1.0
	var motion := Shot.Motion.ORBIT_RIGHT if reverse else Shot.Motion.ORBIT_LEFT
	var player := get_tree().get_first_node_in_group(&"player_craft") as Node3D
	# Two opposite broad openings revolve with the storm. Reflected shots leave
	# orbit immediately, allowing a controlled boost to carve another crossing.
	var count := 8 + _active_section_count() * 4
	for slot in count:
		if slot % (count >> 1) in [0, 1]:
			continue
		var radial := _locked_aim.rotated(slot * TAU / count)
		var origin := global_position + _flight_space.screen_motion_to_combat(radial * 140.0)
		if player != null and _flight_space.combat_motion_to_screen(origin - player.global_position).length() < 75.0:
			continue
		var tangent := radial.rotated(rotation_sign * PI * 0.5)
		_emit_shot(manager, origin, _flight_space.input_to_combat_direction(tangent), 95.0 + _attack_phase * 10.0, motion, SHOT_COLORS[2], 2)

func _place_echo_mark(offset_pixels: Vector2 = Vector2.ZERO, mixup: bool = false, aim_offset: float = 0.0, extra_delay: float = 0.0) -> void:
	if _echo_marks.size() >= 3:
		return
	var player := get_tree().get_first_node_in_group(&"player_craft") as Node3D
	if player == null:
		return
	var mark_position := (_attack_plan.target_position if _attack_plan != null else player.global_position) + _flight_space.screen_motion_to_combat(offset_pixels)
	var bounds := _flight_space.get_combat_bounds(-45.0)
	mark_position.x = clampf(mark_position.x, bounds.position.x, bounds.end.x)
	mark_position.z = clampf(mark_position.z, bounds.position.y, bounds.end.y)
	# Nearby marks merge rather than stacking several bursts under one position.
	for mark in _echo_marks:
		if _flight_space.combat_motion_to_screen(mark_position - Vector3(mark.position)).length() < 90.0:
			return
	var marker := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.85
	ring.outer_radius = 1.0
	ring.rings = 24
	ring.ring_segments = 6
	marker.mesh = ring
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = SHOT_COLORS[3]
	marker.material_override = material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)
	marker.top_level = true
	var across := _flight_space.screen_motion_to_combat(Vector2(35.0, 0.0))
	var along := _flight_space.screen_motion_to_combat(Vector2(0.0, 35.0))
	marker.global_transform = Transform3D(Basis(across, Vector3.UP * 0.05, along), mark_position + Vector3.UP * 0.03)
	_echo_marks.append({"position": mark_position, "marker": marker, "timer": 1.6 + extra_delay, "phase": _attack_phase,
		"aim": _locked_aim.rotated(aim_offset), "sequence": _burst_step, "mixup": mixup, "damage": _attack_plan.definition.damage, "speed_scale": _attack_plan.definition.projectile_speed_scale})

func _update_echo_marks(delta: float) -> void:
	for index in range(_echo_marks.size() - 1, -1, -1):
		var mark := _echo_marks[index]
		mark.timer = float(mark.timer) - delta
		if float(mark.timer) > 0.0:
			continue
		var manager := get_tree().get_first_node_in_group(&"native_3d_projectile_manager") as ProjectileManager
		if manager != null:
			var count := 6 + int(mark.phase) * 2 + _active_section_count() * 2
			# Even fans leave the aimed center open. Later phases offset alternating
			# echoes, requiring a small lane correction rather than more density.
			# Keep an actual central opening: shifting by half a slot would put a
			# projectile directly on the previously open aim line.
			var offset := 0.04 if int(mark.phase) > 0 and int(mark.sequence) % 2 == 0 else 0.0
			for slot in count:
				var direction := Vector2(mark.aim).rotated((slot - (count - 1) * 0.5) * 0.18 + offset)
				var profile := Shot.Motion.BOOST_BREAKER if int(mark.phase) > 0 and slot % 5 == 0 else Shot.Motion.RETURNING
				var speed := 180.0
				if bool(mark.mixup):
					var fast := slot % 2 == int(mark.sequence) % 2
					speed = ShotTuning.FAST_SPEED if fast else ShotTuning.SLOW_SPEED
					if int(mark.phase) == 2:
						direction = direction.rotated(PI * 0.5 if int(mark.sequence) % 2 == 1 else 0.0)
						if fast and profile != Shot.Motion.BOOST_BREAKER:
							profile = Shot.Motion.STOP_RELEASE
				var origin := Vector3(mark.position) + _flight_space.screen_motion_to_combat(direction * 35.0)
				# This origin has its own 1.6-second warning, so allow close releases
				# while still avoiding a projectile appearing in the craft's hitbox.
				if _shot_origin_is_clear(origin, 25.0):
					_emit_shot(manager, origin, _flight_space.input_to_combat_direction(direction), speed, profile, SHOT_COLORS[3], 3, int(mark.damage), float(mark.speed_scale))
		var marker: MeshInstance3D = mark.marker
		marker.queue_free()
		_echo_marks.remove_at(index)

func _clear_echo_marks() -> void:
	for mark in _echo_marks:
		var marker: MeshInstance3D = mark.marker
		if is_instance_valid(marker):
			marker.queue_free()
	_echo_marks.clear()
