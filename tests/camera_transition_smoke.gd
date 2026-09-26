extends Native3DGameplay
## Exercise real cameras, player controls and projectile pools through an orbit.

var _failures: Array[String] = []
var _finished_count := 0
var _maximum_aim_error_pixels := 0.0


func _ready() -> void:
	var disk_snapshot := preload("res://tests/save_file_snapshot.gd").new()
	await super._ready()
	if is_instance_valid(_pause_overlay):
		_close_pause_menu()
	SaveManager.update_setting("reduced_motion", false)
	SaveManager.update_setting("screen_shake", false)
	player.set_dev_god_mode(true)
	player.set_physics_process(false)
	camera_rig.set_process(false)
	camera_rig.set_physics_process(false)
	camera_rig.view_transition_finished.connect(func(): _finished_count += 1)
	_check_orbit()
	_check_quarter_turn_cycle()
	_check_retarget()
	await _check_bindings_and_pause()
	_check_edge_follow()
	await _check_aspect_ratios()
	_check_reduced_motion()
	await ResourceCache.wait_for_scene("res://scenes/native_3d_run.tscn")
	disk_snapshot.restore()
	for failure in _failures:
		push_error(failure)
	print("CAMERA_PROJECTION maximum aiming error: %.4f pixels" % _maximum_aim_error_pixels)
	print("CAMERA_TRANSITION_SMOKE_PASS" if _failures.is_empty() else "CAMERA_TRANSITION_SMOKE_FAIL")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check_orbit() -> void:
	camera_rig.set_view_preset(Native3DCameraRig.View.ANGLED, 0.0)
	var bounds := flight_space.get_combat_bounds()
	var margin_bounds := flight_space.get_combat_bounds(140.0)
	var stable_transform := flight_space.stable_camera.global_transform
	var facing := camera_rig.view_pivot.basis.z
	var finished_before := _finished_count
	projectile_manager.fire_player_projectile(Vector3.ZERO, Vector3.FORWARD)
	var projectile := get_tree().get_first_node_in_group(&"player_projectiles") as Projectile3D
	_expect(projectile != null, "Fixture fires a real pooled projectile")
	if projectile == null:
		return
	projectile.set_physics_process(false)
	var original_velocity := projectile.velocity
	var original_bounds := projectile._bounds
	camera_rig.flip_horizontal(2.0)
	_expect(camera_rig.is_transitioning() and camera_rig.view_pivot.basis.z.is_equal_approx(facing), "Flip starts without a pose jump")
	for step in 120:
		camera_rig._advance_view_transition(2.0 / 119.0)
		_check_view_controls()
		_check_camera_framing()
		_expect(flight_space.stable_camera.global_transform.is_equal_approx(stable_transform), "Orbit keeps the arena projection fixed")
		_expect(flight_space.get_combat_bounds().is_equal_approx(bounds) and flight_space.get_combat_bounds(140.0).is_equal_approx(margin_bounds), "Orbit preserves arena and despawn margins")
		_expect(projectile.velocity == original_velocity and projectile._bounds == original_bounds, "Orbit does not redirect bullets or change their lifetime bounds")
	var turned := camera_rig.view_pivot.basis.z
	_expect(turned.is_equal_approx(facing.rotated(Vector3.UP, PI * 0.5)), "One press rotates the camera exactly 90 degrees")
	_expect(is_equal_approx(facing.y, turned.y), "Horizontal orbit preserves camera elevation")
	_expect(not camera_rig.is_transitioning() and _finished_count == finished_before + 1, "Transition completes exactly once")
	_check_player_actions()
	projectile_manager.clear_projectiles()


func _check_view_controls() -> void:
	var camera := flight_space.active_camera
	_expect(camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "View stays orthographic throughout the transition")
	for input in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(0.3, -0.4)]:
		var motion := flight_space.view_input_to_combat_motion(input * 317.0)
		var pixels := camera.unproject_position(motion) - camera.unproject_position(Vector3.ZERO)
		_expect(pixels.normalized().dot(input.normalized()) > 0.9999, "Movement and controller aim follow the visible direction throughout the orbit")
		_expect(absf(flight_space.combat_motion_to_screen(motion).length() - input.length() * 317.0) < 0.002, "Camera angle and zoom preserve tuned speed and analog magnitude")
		_expect(flight_space.combat_motion_to_view_input(motion).distance_to(input * 317.0) < 0.002, "Steering and braking use the same view-relative direction")
	var point := Vector3(17.0, 0.0, -13.0)
	var projected := flight_space.combat_to_screen(point)
	var error := flight_space.combat_motion_to_view(flight_space.screen_to_combat_plane(projected) - point).length()
	_maximum_aim_error_pixels = maxf(_maximum_aim_error_pixels, error)
	# Expanded viewports round their logical width to whole pixels.
	_expect(error < 0.25, "Mouse aiming round-trips within a quarter of a tuning pixel")


func _check_camera_framing() -> void:
	camera_rig._process(0.0)
	var camera := flight_space.active_camera
	_expect(is_equal_approx(camera.size, 220.0), "Every intermediate view keeps the current 220-unit zoom")
	_expect(get_viewport().get_visible_rect().has_point(camera.unproject_position(player.global_position)), "The pilot stays visible throughout an orbit")
	var depth := -(camera.global_transform.affine_inverse() * player.global_position).z
	_expect(depth > camera.near and depth < camera.far, "Camera clipping includes the pilot throughout an orbit")


func _check_player_actions() -> void:
	var camera := flight_space.active_camera
	player.set_combat_position(Vector3.ZERO)
	player.velocity = Vector3.ZERO
	player.is_boosting = false
	player._update_movement(Vector2.RIGHT, 1.0 / 60.0)
	var pixels := camera.unproject_position(player.global_position) - camera.unproject_position(Vector3.ZERO)
	_expect(pixels.x > 0.0 and absf(pixels.y) < 0.002, "Actual player movement moves right after the flip")
	player.velocity = Vector3.ZERO
	player._begin_boost()
	var boost_screen := flight_space.combat_motion_to_view(player.boost_direction).normalized()
	_expect(boost_screen.dot(Vector2.UP) > 0.9999, "Boost from rest starts up-screen after a flip")
	player._move_boost(Vector2.RIGHT, 0.1)
	_expect(flight_space.combat_motion_to_view(player.velocity).x > 0.0, "Boost steering accepts right-screen input after a flip")
	player._end_boost()
	player.last_aim_direction = flight_space.view_motion_to_combat(Vector2.UP).normalized()
	player.has_spread_shot = true
	var shots := player._get_fire_directions()
	_expect(shots.size() == 3, "Spread produces its normal three shots")
	if shots.size() == 3:
		var left := flight_space.combat_motion_to_view(shots[1]).normalized()
		var right := flight_space.combat_motion_to_view(shots[2]).normalized()
		_expect(absf(Vector2.UP.angle_to(left) + deg_to_rad(15.0)) < 0.001 and absf(Vector2.UP.angle_to(right) - deg_to_rad(15.0)) < 0.001, "Spread remains symmetric around the visible aiming direction")
	player.has_spread_shot = false
	var reticle := flight_space.combat_to_screen(player.get_aim_reticle_combat_position())
	var ship := flight_space.combat_to_screen(player.global_position)
	var expected := FlightTuning.AIM_RETICLE_DISTANCE * get_viewport().get_visible_rect().size.y / flight_space.configuration.baseline_viewport_size.y
	_expect(absf(reticle.distance_to(ship) - expected) < 0.01, "Facing reticle keeps its screen distance after view changes")


func _check_quarter_turn_cycle() -> void:
	var initial_basis := camera_rig.view_pivot.basis
	var initial_step := camera_rig.orbit_step
	for turn in 4:
		camera_rig.flip_horizontal(0.5)
		camera_rig._advance_view_transition(0.5)
		_expect(camera_rig.view_pivot.basis.is_equal_approx(initial_basis.rotated(Vector3.UP, PI * 0.5 * (turn + 1))), "Successive presses visit all four camera sides")
	_expect(camera_rig.orbit_step == initial_step, "Four presses wrap back to the starting side")
	var travel := 0.0
	var previous_yaw := camera_rig._view_angles.y
	# Rapid presses should still produce a full circle, without a reversal.
	for turn in 4:
		camera_rig.flip_horizontal(0.5)
		camera_rig._advance_view_transition(0.1)
		var advance := wrapf(camera_rig._view_angles.y - previous_yaw, -180.0, 180.0)
		_expect(advance > 0.0, "Repeated presses keep the orbit moving in the same direction")
		travel += advance
		previous_yaw = camera_rig._view_angles.y
	for frame in 31:
		camera_rig._advance_view_transition(1.0 / 60.0)
		var advance := wrapf(camera_rig._view_angles.y - previous_yaw, -180.0, 180.0)
		_expect(advance >= -0.001, "A pending orbit never reverses to take a shortcut")
		travel += advance
		previous_yaw = camera_rig._view_angles.y
	_expect(is_equal_approx(travel, 360.0) and camera_rig.view_pivot.basis.is_equal_approx(initial_basis), "Four rapid presses complete one full circle")


func _check_retarget() -> void:
	camera_rig.flip_horizontal(2.0)
	camera_rig._advance_view_transition(0.6)
	var pose := camera_rig.view_pivot.transform
	camera_rig.toggle_view()
	_expect(camera_rig.view_pivot.transform.is_equal_approx(pose), "Changing view mid-orbit starts from the current pose")
	camera_rig._advance_view_transition(3.0)
	_expect(not camera_rig.is_transitioning() and camera_rig.view_preset == Native3DCameraRig.View.OVERHEAD, "Retargeting finishes on the requested preset")
	_expect(is_equal_approx(wrapf(camera_rig._view_angles.y, 0.0, 360.0), camera_rig.orbit_step * 90.0), "Changing elevation preserves the selected quarter-turn")


func _send_action(action: String, family: String, pressed: bool, echo: bool = false) -> void:
	var event: InputEvent = InputBindings.events_for(action, family)[0].duplicate()
	event.pressed = pressed
	if event is InputEventKey:
		event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _check_bindings_and_pause() -> void:
	for family in ["keyboard", "gamepad"]:
		var step_before := camera_rig.orbit_step
		_send_action("camera_flip", family, true)
		_expect(camera_rig.orbit_step == (step_before + 1) % 4, "The actual %s orbit binding reaches gameplay" % family)
		_send_action("camera_flip", family, false)
		var preset_before := camera_rig.view_preset
		_send_action("camera_view", family, true)
		_expect(camera_rig.view_preset != preset_before, "The actual %s angle binding reaches gameplay" % family)
		_send_action("camera_view", family, false)
	var step_before := camera_rig.orbit_step
	_send_action("camera_flip", "keyboard", true, true)
	_expect(camera_rig.orbit_step == step_before, "Keyboard auto-repeat does not repeatedly rotate the camera")
	_send_action("camera_flip", "keyboard", false)
	camera_rig._advance_view_transition(3.0)
	camera_rig.flip_horizontal()
	step_before = camera_rig.orbit_step
	camera_rig.set_physics_process(true)
	get_tree().paused = true
	var paused_pose := camera_rig.view_pivot.transform
	_send_action("camera_flip", "keyboard", true)
	_send_action("camera_flip", "keyboard", false)
	await get_tree().create_timer(0.08, true).timeout
	_expect(camera_rig.view_pivot.transform.is_equal_approx(paused_pose) and camera_rig.orbit_step == step_before, "Pause freezes the transition and ignores camera bindings")
	get_tree().paused = false
	await get_tree().create_timer(0.08).timeout
	_expect(not camera_rig.view_pivot.transform.is_equal_approx(paused_pose), "Unpausing resumes the unfinished transition")
	camera_rig.set_physics_process(false)
	camera_rig._advance_view_transition(3.0)


func _check_aspect_ratios() -> void:
	for resolution in [Vector2i(1280, 800), Vector2i(1920, 810)]:
		get_window().size = resolution
		await get_tree().process_frame
		await get_tree().process_frame
		for elevation in [Native3DCameraRig.ANGLED_ELEVATION, 90.0]:
			for azimuth in [0.0, 45.0, 90.0, 180.0, 270.0]:
				camera_rig.transition_to_view(elevation, azimuth, 0.0)
				_check_camera_framing()
				_check_view_controls()


func _check_edge_follow() -> void:
	for boss_active in [false, true]:
		GameManager.boss_active = boss_active
		flight_space._physics_process(0.0)
		var arena := flight_space.get_combat_bounds(-player.boundary_margin_pixels)
		for corner in [arena.position, arena.end, Vector2(arena.position.x, arena.end.y), Vector2(arena.end.x, arena.position.y)]:
			player.set_combat_position(Vector3(corner.x, 0.0, corner.y))
			for elevation in [Native3DCameraRig.ANGLED_ELEVATION, 90.0]:
				camera_rig.transition_to_view(elevation, 180.0, 1.0)
				for step in 120:
					camera_rig._advance_view_transition(1.0 / 60.0)
					camera_rig._process(1.0 / 60.0)
					_check_camera_framing()
				_expect(flight_space.get_combat_bounds(-player.boundary_margin_pixels).is_equal_approx(arena), "Pilot framing and orbit preserve regular and boss arena bounds")
	GameManager.boss_active = false
	flight_space._physics_process(0.0)
	player.set_combat_position(Vector3.ZERO)
	camera_rig.configure(flight_space.configuration)


func _check_reduced_motion() -> void:
	camera_rig.flip_horizontal()
	SaveManager.update_setting("reduced_motion", true)
	_expect(not camera_rig.is_transitioning(), "Enabling Reduced Motion settles an in-flight transition")
	var facing := camera_rig.view_pivot.basis.z
	camera_rig.flip_horizontal()
	_expect(not camera_rig.is_transitioning() and not camera_rig.view_pivot.basis.z.is_equal_approx(facing), "Reduced Motion changes sides without an orbit animation")
	camera_rig.configure(flight_space.configuration)
	_expect(not camera_rig.is_transitioning() and camera_rig.orbit_step == 0, "Reconfiguration clears pending transition state")


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
