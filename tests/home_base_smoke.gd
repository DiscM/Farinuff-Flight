extends Node
## Real harbor scene: safe navigation, independent progression and pause lifecycle.

const HOME := preload("res://scenes/home_base.tscn")
const CRESCENT_MODEL := "res://assets/models/wayfarer_crescent/meshes/wayfarer_crescent.glb"
const MOVING_SHIPS: Array[String] = [
	"Ship_05_ArrivingCarrier", "Ship_06_PassengerArrival", "Ship_07_DepartingCourier",
	"Ship_08_CargoTug", "Ship_09_RelayTransfer", "Ship_10_CableInspector",
	"Ship_11_RepairDrone", "Ship_12_StationMaintenance", "Ship_13_PracticeCourier",
]
const PARKED_SHIPS := {
	"Ship_01_BerthedCarrier": "Relay_03_OrbitalLogistics",
	"Ship_02_RefuelingCarrier": "Relay_05_RefuelRepair",
	"Ship_03_ArrivalsShuttle": "Wayfarer_Core",
	"Ship_04_ChargingTug": "Relay_02_PowerDistribution",
	"Ship_14_RepairCradle": "Relay_05_RefuelRepair",
}
const CRESCENT_CLIPS: Array[String] = [
	"Ship_10_CableInspector_InspectionSweep", "Ship_11_RepairDrone_InspectionSweep",
	"Ship_12_StationMaintenance_InspectionSweep", "beacon_direction_finder_scan",
	"cargo_arm_east_handling", "cargo_arm_west_handling", "cooling_rotors",
	"correction_thrusters", "harbor_machinery", "harbor_traffic", "navigation_lights",
	"neighborhood_traffic_scan", "orbital_correction", "power_telemetry_scan",
	"repair_manipulator_handling", "traffic_tracking_dish_scan",
]
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var before := _progress_snapshot()
	var home := HOME.instantiate()
	add_child(home)
	await get_tree().process_frame
	home.set_physics_process(false)
	_expect(not GameManager.is_game_active, "Home port never starts a combat run")
	_expect(home.station != null, "Authored station model is present")
	_expect(home._traffic.size() == 9, "All nine authored through-traffic routes run in the harbor")
	_expect(get_tree().get_nodes_in_group("native_3d_projectile_manager").is_empty(), "Peaceful port creates no projectile pool")
	_expect(home._motion.animation_player != null, "Selected ship retains its authored wing animations")
	_check_station_animation(home)
	_check_fleet(home)
	_check_reduced_motion(home)
	_check_movement(home)
	_check_camera_and_locator(home)
	_check_collisions(home)
	_check_service_reachability(home)
	await _check_docking(home)
	_check_input_focus(home)
	_check_remapped_flight_input(home)
	await _check_focused_waypoint(home)
	await _check_pause(home)
	_expect(_progress_snapshot() == before, "Flight, docking, boost and pause never change progression or supplies")
	await _check_quit(home)
	home.queue_free()
	await get_tree().process_frame
	_expect(not get_tree().paused, "Leaving the harbor cannot leave the next scene paused")
	# Allow the project's existing background resource cache to finish before exit.
	await ResourceCache.wait_for_scene(ResourceCache.HOME_BASE_PATH)
	await ResourceCache.wait_for_scene("res://scenes/native_3d_run.tscn")
	# The flight and focus checks trigger real boost/UI feedback. Release these
	# test voices before immediate headless shutdown races the audio mix thread.
	for voice: AudioStreamPlayer in AudioManager._players + MenuAudio._voices:
		voice.stop()
		voice.stream = null
	await get_tree().create_timer(0.05, true).timeout
	for failure in _failures:
		push_error(failure)
	print("HOME_BASE_SMOKE_PASS" if _failures.is_empty() else "HOME_BASE_SMOKE_FAIL")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check_station_animation(home: Node) -> void:
	if home.station == null:
		return
	_expect(home.station.scene_file_path == CRESCENT_MODEL, "Runtime uses the complete Crescent composition")
	var visuals: Node = home._harbor_visuals
	var source: AnimationPlayer = visuals.source_animation_player
	var player: AnimationPlayer = visuals.animation_player
	_expect(source != null and player != null, "Authored clips and synchronized runtime animation are both present")
	if source == null or player == null:
		return
	var clips: PackedStringArray = visuals.get_source_clip_names()
	_expect(clips.size() == 16, "All sixteen Blender clips participate in the synchronized harbor loop")
	_expect(player.is_playing() and not source.is_playing(), "The synchronized loop is the only automatic owner of imported transforms")
	var animation := player.get_animation(player.current_animation)
	_expect(animation != null and animation.loop_mode == Animation.LOOP_LINEAR and is_equal_approx(animation.length, 20.0), "Crescent animation retains its twenty-second loop")
	for required: String in CRESCENT_CLIPS:
		var matched := ""
		for name: String in clips:
			if name.trim_suffix("_cycle").ends_with(required):
				matched = name
				break
		_expect(not matched.is_empty(), "Synchronized harbor includes " + required)
		if not matched.is_empty():
			_check_clip_changes_its_target(visuals, source, matched)
	visuals.seek(0.0)


func _check_clip_changes_its_target(visuals: Node, source: AnimationPlayer, clip_name: String) -> void:
	# Godot imports rest-pose filler tracks into each GLB clip. Select a genuinely
	# animated channel, then prove that its property moves in the combined loop.
	var animation := source.get_animation(clip_name)
	for track in animation.get_track_count():
		var type := animation.track_get_type(track)
		if type not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			continue
		if animation.track_get_key_count(track) < 2:
			continue
		var first: Variant = animation.track_get_key_value(track, 0)
		for key in range(1, animation.track_get_key_count(track)):
			if not _different_pose(first, animation.track_get_key_value(track, key)):
				continue
			var target_path := NodePath(str(animation.track_get_path(track)).get_slice(":", 0))
			var target := source.get_node(source.root_node).get_node_or_null(target_path) as Node3D
			_expect(target != null, "Animated target resolves for " + clip_name)
			if target == null:
				return
			var time_scale := 20.0 / animation.length
			visuals.seek(animation.track_get_key_time(track, 0) * time_scale)
			var before: Variant = _track_pose(target, type)
			visuals.seek(animation.track_get_key_time(track, key) * time_scale)
			_expect(_different_pose(before, _track_pose(target, type)), "Combined loop actually animates " + clip_name)
			return
	_expect(false, "Imported source clip has a moving channel: " + clip_name)


func _track_pose(target: Node3D, track_type: int) -> Variant:
	match track_type:
		Animation.TYPE_POSITION_3D:
			return target.position
		Animation.TYPE_ROTATION_3D:
			return target.quaternion
		_:
			return target.scale


func _different_pose(first: Variant, second: Variant) -> bool:
	if first is Quaternion and second is Quaternion:
		return absf(first.dot(second)) < 0.999999
	if first is Vector3 and second is Vector3:
		return first.distance_to(second) > 0.00001
	return first != second


func _check_fleet(home: Node) -> void:
	var visuals: Node = home._harbor_visuals
	var roots: Dictionary = visuals.get_authored_roots()
	var fleet_count := 0
	for name: String in roots:
		if name.begins_with("Ship_"):
			fleet_count += 1
	_expect(fleet_count == 14, "Full Crescent composition preserves all fourteen authored ships")
	visuals.seek(0.0)
	var starting_positions: Dictionary = {}
	var parked_poses: Dictionary = {}
	for name: String in MOVING_SHIPS:
		_expect(roots.has(name), "Through-traffic craft is present: " + name)
		if roots.has(name):
			starting_positions[name] = roots[name].global_position
	for name: String in PARKED_SHIPS:
		_expect(roots.has(name) and roots.has(PARKED_SHIPS[name]), "Docked craft and its parent berth are present: " + name)
		if roots.has(name) and roots.has(PARKED_SHIPS[name]):
			_expect(roots[name].get_parent() == roots[PARKED_SHIPS[name]], "Docked craft inherits its station correction: " + name)
			parked_poses[name] = roots[name].transform
	visuals.seek(4.25)
	for name: String in starting_positions:
		_expect(roots[name].global_position.distance_to(starting_positions[name]) > 5.0, "Authored route advances through the harbor: " + name)
	for time: float in [4.25, 9.5, 15.0]:
		visuals.seek(time)
		for name: String in parked_poses:
			_expect(roots[name].transform.is_equal_approx(parked_poses[name]), "Parked craft stays attached to its moving berth: " + name)
	visuals.seek(0.0)


func _authored_poses(home: Node) -> Dictionary:
	var poses: Dictionary = {}
	var roots: Dictionary = home._harbor_visuals.get_authored_roots()
	for name: String in roots:
		poses[name] = roots[name].global_transform
	return poses


func _check_reduced_motion(home: Node) -> void:
	var previous: Variant = SaveManager.get_setting("reduced_motion", false)
	home._harbor_visuals.seek(3.0)
	SaveManager.settings["reduced_motion"] = true
	var before := _authored_poses(home)
	home._update_visuals(0.75)
	_expect(_authored_poses(home) == before, "Reduced motion freezes authored station corrections and traffic without resetting the scene")
	SaveManager.settings["reduced_motion"] = false
	home._update_visuals(0.75)
	_expect(_authored_poses(home) != before, "Disabling reduced motion resumes authored harbor animation")
	SaveManager.settings["reduced_motion"] = previous
	home._harbor_visuals.seek(0.0)


func _check_movement(home: Node) -> void:
	var distances: Array[float] = []
	for zoom in [home.MIN_ZOOM, home.MAX_ZOOM]:
		home.player.position = home.INITIAL_POSITION + Vector3(-20, 0, 0)
		home.velocity = Vector3.ZERO
		home.is_boosting = false
		home.camera.size = zoom
		var start: Vector3 = home.player.position
		for frame in 60:
			home.step_flight(Vector2.RIGHT, false, 1.0 / 60.0)
		distances.append(home.player.position.distance_to(start))
	_expect(distances[0] > 15.0 and is_equal_approx(distances[0], distances[1]), "Cruise stays responsive and independent of camera zoom")
	home.player.position = home.INITIAL_POSITION + Vector3(-20, 0, 0)
	home.velocity = Vector3.ZERO
	home.is_boosting = false
	home.step_flight(Vector2.RIGHT, true, 1.0 / 60.0)
	_expect(home.is_boosting and home.velocity.length() > home.CRUISE_SPEED, "Holding boost accelerates the selected ship")
	for frame in 240:
		home.step_flight(Vector2.RIGHT, true, 1.0 / 60.0)
	_expect(home.is_boosting, "Wayfarer boost never runs out while held")
	home.step_flight(Vector2.RIGHT, false, 1.0 / 60.0)
	_expect(not home.is_boosting, "Letting go of boost ends the unlimited burn")
	home.adjust_zoom(-1000)
	_expect(is_equal_approx(home._zoom, home.MIN_ZOOM), "Camera zoom has a useful minimum")
	home.adjust_zoom(1000)
	_expect(is_equal_approx(home._zoom, home.MAX_ZOOM), "Camera zoom has a useful maximum")


func _check_collisions(home: Node) -> void:
	var tower_center: Vector3 = home.Layout.CORE_CENTER
	var tower_radius: float = home.Layout.CORE_RADIUS
	home.player.position = tower_center + Vector3.BACK * (tower_radius + 7.0)
	_expect(home.Layout.is_clear(home.player.position), "Tower sweep starts in the open approach walkway")
	home.heading = Vector3.FORWARD
	home.velocity = Vector3.ZERO
	home.is_boosting = false
	# A long frame must still stop at the near side, never tunnel to the far side.
	var screen_toward_tower := Vector2(Vector3.FORWARD.dot(home.screen_direction_to_world(Vector2.RIGHT)), Vector3.FORWARD.dot(home.screen_direction_to_world(Vector2.DOWN)))
	home.step_flight(screen_toward_tower, true, 1.0)
	_expect(home.player.position.z >= tower_center.z + tower_radius - 0.01, "Swept boost cannot tunnel through the actual central tower")
	_expect(home.Layout.is_clear(home.player.position), "Swept boost finishes outside padded station geometry")
	_expect(is_zero_approx(home.player.position.y), "Flight remains on the shared clearance plane")
	var basin := Vector3(20.0, 0.0, -50.0)
	_expect(home.constrain_flight_position(basin).is_equal_approx(basin), "The arrival basin stays open between the crescent components")
	home.velocity = Vector3.RIGHT * 30.0
	var boundary: Vector3 = home.constrain_flight_position(home.Layout.FLIGHT_CENTER + Vector3(300, 0, 0))
	_expect(is_equal_approx(boundary.distance_to(home.Layout.FLIGHT_CENTER), home.FLIGHT_RADIUS) and is_zero_approx(home.velocity.x), "Perimeter stops outward motion relative to the harbor center")
	for blocker: Dictionary in home.Layout.blockers():
		var resolved: Vector3 = home.constrain_flight_position(blocker.center)
		_expect(home.Layout.is_clear(resolved), "A spawn inside station machinery resolves to a safe position")
	for section: Dictionary in home.Sections.SECTIONS:
		_expect(home.Layout.is_clear(section.position) and home.constrain_flight_position(section.position).is_equal_approx(section.position), "Physical service berth remains accessible: " + str(section.id))


func _check_camera_and_locator(home: Node) -> void:
	home.velocity = Vector3.ZERO
	var frame := get_viewport().get_visible_rect().grow(-16.0)
	for zoom in [home.MIN_ZOOM, home.INITIAL_ZOOM, home.MAX_ZOOM]:
		home._zoom = zoom
		for radius in [0.0, 95.0, 125.0, home.FLIGHT_RADIUS]:
			for index in 16:
				var angle := TAU * float(index) / 16.0
				home.player.position = home.Layout.FLIGHT_CENTER + Vector3(cos(angle), 0, sin(angle)) * radius
				home._update_camera(10.0)
				home._update_pilot_locator()
				var pilot_screen: Vector2 = home.camera.unproject_position(home.player.position)
				_expect(frame.has_point(pilot_screen), "Pilot stays within the camera frame at zoom %s / radius %s / angle %s" % [zoom, radius, index])
				_expect(home._pilot_locator.position.is_equal_approx(pilot_screen), "Pilot locator matches its projected position")
				_expect(home._pilot_locator.visible, "The small ship always retains a readable position marker")
	home.player.position = home.INITIAL_POSITION
	home._zoom = home.INITIAL_ZOOM
	home._update_camera(10.0)


func _check_service_reachability(home: Node) -> void:
	# A clear marker can still be stranded inside a closed ring of blockers.
	# Check connected open flight space from the arrival point to every service.
	const GRID_STEP := 4.0
	var center: Vector3 = home.Layout.FLIGHT_CENTER
	var relative: Vector3 = (home.INITIAL_POSITION - center) / GRID_STEP
	var start := Vector2i(roundi(relative.x), roundi(relative.z))
	_expect(home.Layout.is_clear(home.INITIAL_POSITION), "Player arrival position has station clearance")
	_expect(home.Layout.is_clear(center + Vector3(start.x, 0, start.y) * GRID_STEP), "Arrival connects to the sampled open flight space")
	var queue: Array[Vector2i] = [start]
	var visited := {start: true}
	var index := 0
	var limit := ceili(home.FLIGHT_RADIUS / GRID_STEP)
	while index < queue.size():
		var cell := queue[index]
		index += 1
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor := cell + direction
			if visited.has(neighbor) or absi(neighbor.x) > limit or absi(neighbor.y) > limit:
				continue
			var point := center + Vector3(neighbor.x, 0, neighbor.y) * GRID_STEP
			var midpoint := center + Vector3(cell.x + neighbor.x, 0, cell.y + neighbor.y) * GRID_STEP * 0.5
			if not home.Layout.is_clear(point) or not home.Layout.is_clear(midpoint):
				continue
			visited[neighbor] = true
			queue.append(neighbor)
	for section: Dictionary in home.Sections.SECTIONS:
		var target: Vector3 = (section.position - center) / GRID_STEP
		var cell := Vector2i(roundi(target.x), roundi(target.z))
		_expect(visited.has(cell), "Open flight space connects arrivals to " + str(section.id))


func _check_docking(home: Node) -> void:
	_expect(home._harbor_visuals.scale.is_equal_approx(Vector3.ONE * home.Sections.STATION_SCALE) and home.player.scale.is_equal_approx(Vector3.ONE), "Complete Crescent composition uses the shared scale without enlarging the player ship")
	_expect(home.Sections.SECTIONS.size() == 6 and home._section_signs.size() == 6, "Each menu function has its own marked physical berth")
	var original_scene := get_tree().current_scene
	for section in home.Sections.SECTIONS:
		home.player.position = section.position
		home._refresh_hud()
		_expect(home.is_docked and home._active_section.id == section.id, "The correct nearby service is offered: " + str(section.id))
		home.interact_with_section()
		await get_tree().process_frame
		await get_tree().process_frame
		_expect(home._services.is_open() and home._services.get_current_page_id() == section.id, "Interaction opens the matching local service: " + str(section.id))
		_expect(get_tree().paused and not home.hud.visible, "Services pause flight and hide the flight HUD")
		_expect(get_tree().current_scene == original_scene, "Service stays in the station scene")
		_expect(home._services.frontend.service_mode, "Service navigation cannot revive the old command deck")
		home._services.close_service()
		await get_tree().process_frame
		_expect(not get_tree().paused and home.hud.visible and get_viewport().gui_get_focus_owner() == null, "Leaving a service returns directly to flight")
		home.player.position = section.position + Vector3(home.DOCK_RADIUS + 1, 0, 0)
		home.interact_with_section()
		_expect(not home._services.is_open(), "Crossing outside a section's boundary prevents remote interaction")
	home.player.position = Vector3(160, 0, 50)
	var before: Vector3 = home.player.position
	home.select_section(&"settings")
	_expect(home._navigation_target == &"settings" and home.player.position == before and not home._services.is_open(), "Directory selects a waypoint without teleporting or opening a remote service")
	home.interact_with_section()
	_expect(not home._services.is_open(), "Open space cannot activate a service")
	home.player.position = home.DOCK_POSITION
	home._refresh_hud()
	var boost_button := InputEventJoypadButton.new()
	boost_button.button_index = JOY_BUTTON_B
	boost_button.pressed = true
	home._unhandled_input(boost_button)
	_expect(not home._menu_open, "Default controller B boost never opens the pause menu")


func _check_input_focus(home: Node) -> void:
	home.player.position = home.DOCK_POSITION
	home._refresh_hud()
	home.hud.focus_primary()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	home._unhandled_input(escape)
	_expect(get_viewport().gui_get_focus_owner() == null and not home._menu_open, "Escape exits keyboard service selection directly back to flight")
	home.hud.focus_primary()
	home.set_menu_open(true)
	home.set_menu_open(false)
	_expect(get_viewport().gui_get_focus_owner() == null, "Resume always returns flight control, even when the pause invoker was a button")


func _check_remapped_flight_input(home: Node) -> void:
	var original_events := InputMap.action_get_events("boost")
	var candidates: Array[InputEvent] = []
	for key in [KEY_TAB, KEY_MINUS, KEY_EQUAL]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.keycode = key
		event.pressed = true
		candidates.append(event)
	for button in [JOY_BUTTON_A, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = true
		candidates.append(event)
	for candidate in candidates:
		var binding: InputEvent = candidate.duplicate()
		# Saved key bindings use physical codes; real input additionally carries
		# the platform's logical code. Keep the same separation as InputBindings.
		if binding is InputEventKey:
			binding.keycode = 0
		InputMap.action_add_event("boost", binding)
		home._boost_released = true
		var before_zoom: float = home._zoom
		Input.parse_input_event(candidate)
		Input.flush_buffered_events()
		_expect(get_viewport().gui_get_focus_owner() == null and home._boost_released, "A remapped flight button cannot be stolen by service selection: " + candidate.as_text())
		_expect(Input.is_action_pressed("boost"), "The remapped action remains available to the flight controller")
		home._unhandled_input(candidate)
		_expect(is_equal_approx(home._zoom, before_zoom), "A remapped boost button cannot also zoom the harbor camera")
		var service: InputEvent = home.hud.get_service_event(InputBindings.event_family(candidate))
		_expect(service != null and not service.is_match(candidate), "Service selection offers a nonconflicting fallback for " + candidate.as_text())
		var release: InputEvent = candidate.duplicate()
		release.pressed = false
		Input.parse_input_event(release)
		Input.flush_buffered_events()
		InputMap.action_erase_event("boost", binding)
	InputMap.action_erase_events("boost")
	for event in original_events:
		InputMap.action_add_event("boost", event)
	Input.action_release("boost")
	InputBindings.family = "keyboard"


func _check_pause(home: Node) -> void:
	home.set_physics_process(true)
	home.set_menu_open(true)
	var before: float = home._elapsed
	var poses := _authored_poses(home)
	await get_tree().create_timer(0.06, true).timeout
	_expect(get_tree().paused and home.hud._resume_button.has_focus(), "Pause freezes the harbor and focuses Resume")
	_expect(is_equal_approx(home._elapsed, before), "Paused harbor stops simulation time")
	_expect(_authored_poses(home) == poses, "Pause freezes all authored fleet, station and cable roots together")
	home.set_menu_open(false)
	_expect(not get_tree().paused and not home._boost_released, "Resume is safe against a held boost button")
	home.set_physics_process(false)


func _check_focused_waypoint(home: Node) -> void:
	home.player.position = home.DOCK_POSITION
	home._refresh_hud()
	home.hud._section_buttons[&"settings"].grab_focus()
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	Input.parse_input_event(button)
	Input.flush_buffered_events()
	await get_tree().process_frame
	button = button.duplicate()
	button.pressed = false
	Input.parse_input_event(button)
	Input.flush_buffered_events()
	await get_tree().process_frame
	_expect(home._navigation_target == &"settings" and not home._services.is_open(), "Controller accept activates a focused waypoint without opening the nearby Launch Bay")
	_expect(get_viewport().gui_get_focus_owner() == null, "Selecting a waypoint restores flight control")
	InputBindings.family = "keyboard"


func _check_quit(home: Node) -> void:
	home.request_quit()
	await get_tree().process_frame
	_expect(is_instance_valid(home._quit_layer) and get_tree().paused, "Window close presents a save-aware quit decision")
	var dialog: Control = home._quit_layer.get_child(0)
	_expect(dialog.is_ancestor_of(get_viewport().gui_get_focus_owner()), "Quit decision owns keyboard/controller focus")
	dialog._finish(false)
	await get_tree().process_frame
	_expect(not get_tree().paused and not is_instance_valid(home._quit_layer), "Canceling quit restores flight")
	home.open_service(&"settings")
	await get_tree().process_frame
	await get_tree().process_frame
	home.request_quit()
	await get_tree().process_frame
	dialog = home._quit_layer.get_child(0)
	dialog._finish(false)
	await get_tree().process_frame
	_expect(get_tree().paused and home._services.get_current_page_id() == &"settings", "Canceling quit from a service retains its paused local page")
	home._services.close_service()
	# Route saves to a missing folder in this test's disposable profile.
	var store = SaveManager._progress_store
	var saved_path: String = store.path
	store.path = "user://missing-home-port-folder/progress.json"
	home.request_quit()
	await get_tree().process_frame
	home._quit_layer.get_child(0)._finish(true)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(is_instance_valid(home._quit_layer) and get_tree().paused, "Save failure keeps the game open")
	dialog = home._quit_layer.get_child(0)
	_expect(dialog.confirm_text == "RETRY SAVE", "Failed quit offers a recoverable save retry")
	dialog._finish(false)
	await get_tree().process_frame
	store.path = saved_path
	store.last_error = ""
	_expect(not get_tree().paused, "Returning from save failure restores station flight")


func _progress_snapshot() -> Dictionary:
	return {
		"save_bytes": FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) if FileAccess.file_exists(SaveManager.SAVE_PATH) else PackedByteArray(),
		"salvage": SaveManager.salvage,
		"score": GameManager.score,
		"lives": GameManager.lives,
		"wave": GameManager.current_wave,
		"kills": GameManager.run_kills,
		"selected_ship": MetaProgression.selected_ship,
		"pending_start_powerup": GameManager.pending_start_powerup,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
