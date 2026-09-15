extends "res://scenes/flight_practice.gd"
## Real practice boss activation, phase changes and defeat; no banking or supplies.

var _failures: Array[String] = []
@onready var _landmarks: Node3D = $World3D/FrontierLandmarks
@onready var _planet: Node2D = $Backdrop/Celestial


func _ready() -> void:
	GameManager.practice_boss_wave = 0
	await super._ready()
	set_physics_process(false)
	player.set_physics_process(false)
	player.set_dev_god_mode(true)
	await _check_travel()
	_check_wrapping()
	for wave in [5, 10, 15, 25, 20]:
		await _check_boss(wave)
	# The last real boss explosion can outlive this short test. Release its
	# playback before quitting so audio-thread cleanup does not mask leaks.
	for voice in AudioManager.get_children():
		if voice is AudioStreamPlayer:
			voice.stop()
	await get_tree().create_timer(.12).timeout
	for failure in _failures:
		push_error(failure)
	print("BACKGROUND_DRIFT_SMOKE_PASS" if _failures.is_empty() else "BACKGROUND_DRIFT_SMOKE_FAIL")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _screen_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = [_planet.global_position]
	positions.append(_landmarks._camera.unproject_position(_landmarks._relay.global_position))
	for model in _landmarks._debris:
		positions.append(_landmarks._camera.unproject_position(model.global_position))
	return positions


func _rotations() -> Array[Vector3]:
	var rotations: Array[Vector3] = [_landmarks._relay.rotation]
	for model in _landmarks._debris:
		rotations.append(model.rotation)
	return rotations


func _check_travel() -> void:
	var before := _screen_positions()
	await get_tree().create_timer(.2).timeout
	var after := _screen_positions()
	for index in before.size():
		_expect(after[index].y > before[index].y + 1.0, "Scenery %d travels down" % index)
		_expect(after[index].y < before[index].y + 16.0, "Scenery %d resumes without catching up paused time" % index)
	var variants: Array[String] = []
	for model in _landmarks._debris:
		if not variants.has(model.scene_file_path):
			variants.append(model.scene_file_path)
	_expect(variants.size() == 11, "All eleven station and space debris variants enter the bounded field")


func _check_boss(wave: int) -> void:
	_boss_wave = wave
	_start_boss()
	var boss := get_tree().get_first_node_in_group(&"native_3d_enemies")
	_expect(GameManager.boss_active and boss != null, "Boss wave %d activates" % wave)
	await _expect_frozen("Boss entry %d" % wave)
	# Breaking weapons and changing phases must not count as defeating the boss.
	for section in boss._sections:
		section.take_damage(99999)
	await _expect_frozen("Destroyed weapon pods %d" % wave)
	boss.take_damage(ceili(boss.max_health * .4))
	_expect(boss.phase == 1, "Wave %d reaches phase two" % wave)
	await _expect_frozen("Second phase %d" % wave)
	boss.take_damage(boss.health - floori(boss.max_health * .29))
	_expect(boss.phase == 2, "Wave %d reaches final phase" % wave)
	await _expect_frozen("Final phase %d" % wave)
	get_tree().paused = true
	await _expect_frozen("Paused boss %d" % wave)
	get_tree().paused = false
	await _expect_frozen("Unpaused living boss %d" % wave)
	boss.take_damage(99999)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(not GameManager.boss_active, "Actual boss defeat releases wave %d" % wave)
	await _check_travel()


func _expect_frozen(context: String) -> void:
	var positions := _screen_positions()
	var rotations := _rotations()
	var planet_time: float = _planet.current_planet.time
	await get_tree().create_timer(.12, true).timeout
	var after := _screen_positions()
	var rotations_after := _rotations()
	for index in positions.size():
		_expect(positions[index].distance_to(after[index]) < .05, "%s holds screen position %d" % [context, index])
	for index in rotations.size():
		_expect(rotations[index].is_equal_approx(rotations_after[index]), "%s holds tumble %d" % [context, index])
	_expect(is_equal_approx(planet_time, _planet.current_planet.time), context + " holds planet surface time")
	if not get_tree().paused:
		_expect(GameManager.is_game_active and projectile_manager.is_physics_processing(), context + " leaves combat running")


func _visual_screen_bounds(model: Node3D) -> Rect2:
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for corner in 8:
			var point: Vector2 = _landmarks._camera.unproject_position(mesh.global_transform * mesh.get_aabb().get_endpoint(corner))
			minimum = minimum.min(point)
			maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)


func _check_wrapping() -> void:
	var height := get_viewport().get_visible_rect().size.y
	var original_relay: Vector2 = _landmarks._relay_anchor
	var original_anchors: Array[Vector2] = _landmarks._anchors.duplicate()
	_landmarks._relay_anchor.y = 1.0 + _landmarks._relay_radius / _landmarks._camera.size + _landmarks.wrap_padding / height - .0001
	for index in _landmarks._debris.size():
		_landmarks._anchors[index].y = 1.0 + _landmarks._radii[index] / _landmarks._camera.size + _landmarks.wrap_padding / height - .0001
	_landmarks._update_positions()
	var models: Array[Node3D] = [_landmarks._relay]
	models.append_array(_landmarks._debris)
	for model in models:
		_expect(_visual_screen_bounds(model).position.y > height, "Entire %s exits below before wrapping" % model.name)
	_landmarks._process(.1)
	for model in models:
		_expect(_visual_screen_bounds(model).end.y < 0, "Entire %s returns above after wrapping" % model.name)
	# Compare one long frame with subdivided travel, including multiple wraps.
	var start_relay: Vector2 = _landmarks._relay_anchor
	var start_anchors: Array[Vector2] = _landmarks._anchors.duplicate()
	_landmarks._process(200.0)
	var long_relay: Vector2 = _landmarks._relay_anchor
	var long_anchors: Array[Vector2] = _landmarks._anchors.duplicate()
	_landmarks._relay_anchor = start_relay
	_landmarks._anchors.assign(start_anchors)
	for step in 200:
		_landmarks._process(1.0)
	_expect(long_relay.distance_to(_landmarks._relay_anchor) < .0001, "Relay travel retains overshoot across frame rates")
	for index in long_anchors.size():
		_expect(long_anchors[index].distance_to(_landmarks._anchors[index]) < .0001, "Debris %d travel retains overshoot across frame rates" % index)
	_landmarks._relay_anchor = original_relay
	_landmarks._anchors.assign(original_anchors)
	_landmarks._update_positions()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
