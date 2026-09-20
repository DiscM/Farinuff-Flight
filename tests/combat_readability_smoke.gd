extends Native3DGameplay
## Exercise real projection and HUD opacity without changing combat bounds.

var _failures: Array[String] = []
var _quit_attempts := 0

func _ready() -> void:
	var disk_snapshot := preload("res://tests/save_file_snapshot.gd").new()
	await super._ready()
	_expect(get_tree().paused and is_instance_valid(_pause_overlay), "Focus loss during warmup pauses the prepared game")
	_close_pause_menu()
	player.set_physics_process(false)
	player.set_dev_god_mode(true)
	_check_window_fit()
	var projection_reference := await _check_combat_framing()
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(1280, 800), Vector2i(1920, 810)]:
		get_window().size = resolution
		await get_tree().process_frame
		await get_tree().process_frame
		_check_resized_projection(projection_reference, resolution)
		await _check_hud_scale()
		for boss_active in [false, true]:
			GameManager.boss_active = boss_active
			await get_tree().physics_frame
			var before := flight_space.get_combat_bounds()
			var header := hud.get_node("CombatHeader") as Control
			await _hold_at_screen_position(header.get_global_rect().get_center(), 0.2)
			_expect(header.modulate.a < 0.3, "Header yields to the craft at %s (boss=%s)" % [resolution, boss_active])
			await _hold_at_screen_position(get_viewport().get_visible_rect().size * 0.5, 0.2)
			_expect(header.modulate.a > 0.95, "HUD returns to full readability away from the craft")
			_expect(flight_space.get_combat_bounds().is_equal_approx(before), "HUD fading preserves combat bounds")
	await _check_boss_hud_visibility()
	await _check_input_interruptions()
	var planet := $Backdrop/Celestial
	planet.type_index = 10 # Star: brightest palette with multiple shader layers.
	planet._spawn_planet()
	GameManager.boss_active = false
	await get_tree().create_timer(0.6).timeout
	var flight_colors: Array = planet.current_planet.get_colors()
	GameManager.boss_active = true
	await get_tree().create_timer(0.6).timeout
	var boss_colors: Array = planet.current_planet.get_colors()
	_expect(flight_colors.size() == boss_colors.size() and not flight_colors.is_empty(), "Boss palette preserves all planet layers")
	for index in mini(flight_colors.size(), boss_colors.size()):
		_expect(boss_colors[index].v < flight_colors[index].v, "Boss backdrop lowers each bright palette entry")
	GameManager.boss_active = false
	await _check_quit_save_retry()
	disk_snapshot.restore()
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("COMBAT_READABILITY_SMOKE_PASS")
	get_tree().quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _prepare_run_actors() -> void:
	get_window().focus_exited.emit()
	await super._prepare_run_actors()

func _quit_application() -> void:
	_quit_attempts += 1


func _check_window_fit() -> void:
	var layout := preload("res://systems/game_window_layout.gd")
	# Offset displays catch accidental centering at the desktop origin; the
	# small usable rectangles require the new default to scale down safely.
	for usable in [Rect2i(67, 44, 1024, 700), Rect2i(-1280, 24, 1280, 696)]:
		for preset in [layout.DEFAULT_PRESET, "fit"]:
			var fitted: Rect2i = layout.preset_rect(preset, usable)
			_expect(fitted.has_area() and usable.encloses(fitted), "Window preset %s stays inside the usable display" % preset)
			_expect(fitted.size.x <= floori(usable.size.x * 0.9) and fitted.size.y <= floori(usable.size.y * 0.9), "Window preset %s leaves the display's ten-percent safety margin" % preset)
			_expect(Vector2(fitted.get_center()).distance_to(Vector2(usable.get_center())) <= 1.5, "Window preset %s centers on its own display" % preset)
			_expect(absf(float(fitted.size.x) / fitted.size.y - 16.0 / 9.0) < 0.005, "Fitting a large window preserves its widescreen shape")
	var desktop := Rect2i(0, 24, 3840, 2110)
	var default_rect: Rect2i = layout.preset_rect(layout.DEFAULT_PRESET, desktop)
	var previous_rect: Rect2i = layout.preset_rect("large", desktop)
	_expect(default_rect.size.x > previous_rect.size.x and default_rect.size.y > previous_rect.size.y, "The new default uses more room when the display can accommodate it")


func _projection_snapshot() -> Dictionary:
	var view := flight_space.get_view_bounds()
	var combat := flight_space.get_combat_bounds()
	return {
		"view": view,
		"movement": flight_space.screen_motion_to_combat(Vector2(317.0, -229.0)),
		"view_margin": flight_space.get_view_bounds(80.0).size - view.size,
		"combat_margin": flight_space.get_combat_bounds(60.0).size - combat.size,
		"player_inset": combat.size - flight_space.get_combat_bounds(-player.boundary_margin_pixels).size,
	}


func _check_combat_framing() -> Dictionary:
	var rig := $World3D/CameraRig3D as Native3DCameraRig
	var production := flight_space.configuration
	var old_configuration := production.duplicate(true) as FlightSpace3DConfig
	old_configuration.baseline_viewport_size = Vector2i(1280, 720)
	var was_boss_active := GameManager.boss_active
	GameManager.boss_active = false
	flight_space.configuration = old_configuration
	rig.configure(old_configuration)
	flight_space.bounds_changed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var previous := _projection_snapshot()
	GameManager.boss_active = true
	var previous_boss_bounds := flight_space.get_combat_bounds()
	# Restore the production resource before any assertion or later HUD test.
	flight_space.configuration = production
	rig.configure(production)
	flight_space.bounds_changed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var current_boss_bounds := flight_space.get_combat_bounds()
	GameManager.boss_active = false
	var current := _projection_snapshot()
	var previous_view: Rect2 = previous.view
	var current_view: Rect2 = current.view
	_expect(current_view.size.distance_to(previous_view.size * 1.25) < 0.001, "The expanded combat frame provides 25 percent more space on each axis")
	_expect(current_view.get_center().distance_to(previous_view.get_center()) < 0.001, "Expanded combat framing preserves the arena origin")
	_expect(current_boss_bounds.size.distance_to(previous_boss_bounds.size * 1.25) < 0.001, "The boss arena expands with the normal combat frame")
	for key in ["movement", "view_margin", "combat_margin", "player_inset"]:
		_expect(current[key].distance_to(previous[key]) < 0.001, "Expanded framing preserves world-space %s" % key)
	GameManager.boss_active = was_boss_active
	flight_space.bounds_changed.emit()
	return current


func _check_resized_projection(reference: Dictionary, resolution: Vector2i) -> void:
	var current := _projection_snapshot()
	var reference_view: Rect2 = reference.view
	var current_view: Rect2 = current.view
	_expect(absf(current_view.size.y - reference_view.size.y) < 0.001, "Window resizing preserves combat depth at %s" % resolution)
	for key in ["movement", "combat_margin", "player_inset"]:
		_expect(current[key].distance_to(reference[key]) < 0.001, "Window resizing preserves world-space %s at %s (before=%s, after=%s, error=%.6f)" % [key, resolution, reference[key], current[key], current[key].distance_to(reference[key])])
	# An expanded ultrawide viewport rounds its logical width to whole pixels.
	# Ray-derived margins and aiming may differ by a fraction of a tuning pixel;
	# movement and combat bounds above do not rely on that raster rounding.
	var margin_difference: Vector2 = current.view_margin - reference.view_margin
	var margin_error := flight_space.combat_motion_to_screen(Vector3(margin_difference.x, 0.0, margin_difference.y)).length()
	_expect(margin_error < 0.25, "Window resizing preserves the ray-derived margin within a quarter pixel at %s (error=%.6f pixels)" % [resolution, margin_error])
	var tuning_motion := Vector2(317.0, -229.0)
	_expect(flight_space.combat_motion_to_screen(current.movement).distance_to(tuning_motion) < 0.001, "Movement conversion remains reversible at %s" % resolution)
	# Use the rendered camera for aiming, including its boss-follow offset.
	var point := player.global_position + flight_space.screen_motion_to_combat(Vector2(85.0, -60.0))
	var projected := flight_space.combat_to_screen(point)
	var aiming_error := flight_space.combat_motion_to_screen(flight_space.screen_to_combat_plane(projected) - point).length()
	_expect(aiming_error < 0.25, "Rendered-camera aiming remains reversible within a quarter pixel at %s (error=%.6f pixels)" % [resolution, aiming_error])


func _check_boss_hud_visibility() -> void:
	var boss_scene := preload("res://entities/enemies/boss_enemy_3d.tscn")
	var rig := $World3D/CameraRig3D as Native3DCameraRig
	var camera := flight_space.active_camera
	var panel := hud.get_node("BossDock") as Control
	var bar := panel.get_node("BossBarContainer") as Control
	var previous_bar_visible := bar.visible
	var previous_position := player.global_position
	var previous_wave := GameManager.current_wave
	var previous_boss_active := GameManager.boss_active
	var rig_was_processing := rig.is_processing()
	# Keep the camera still while placing precise hull-edge fixtures. Ordinary
	# moving-camera craft occlusion is already exercised at every size above.
	rig.set_process(false)
	GameManager.boss_active = true
	GameManager.current_wave = 15
	flight_space.bounds_changed.emit()
	var arena := flight_space.get_combat_bounds()
	var view := get_viewport().get_visible_rect().size
	player.global_position = flight_space.screen_to_combat_plane(view * Vector2(0.5, 0.8))
	var boss := boss_scene.instantiate() as BasicEnemy3D
	actors_root.add_child(boss)
	boss.set("dev_variant_override", 2) # Tempest's broad vanes extend beyond its center.
	_expect(boss.activate_generation(flight_space, flight_space.screen_to_combat_plane(panel.get_global_rect().get_center()), Vector3.BACK, 1), "HUD fixture activates a real Tempest boss")
	boss.set_physics_process(false)
	await get_tree().create_timer(0.2).timeout
	_expect(absf(panel.modulate.a - 0.2) < 0.01, "Boss dock yields when the visible boss crosses its center")
	_expect(flight_space.get_combat_bounds().is_equal_approx(arena), "Boss occlusion never changes combat bounds")
	var selected_hull := boss.visuals.get_child(2) as Node3D
	# Place an actual mesh vertex across the dock's lower edge. This verifies
	# hull overlap without deriving the fixture from the HUD's AABB helper.
	var hull_tip := _topmost_mesh_vertex(selected_hull, camera)
	var edge_point := Vector2(panel.get_global_rect().get_center().x, panel.get_global_rect().end.y - 3.0)
	boss.global_position += flight_space.screen_to_combat_plane(edge_point) - flight_space.screen_to_combat_plane(camera.unproject_position(hull_tip))
	_expect(not panel.get_global_rect().grow(44.0).has_point(camera.unproject_position(boss.global_position)), "Hull-edge fixture keeps the boss center beyond the old craft-clearance test")
	await get_tree().create_timer(0.2).timeout
	_expect(absf(panel.modulate.a - 0.2) < 0.01, "Boss dock yields to a visible hull edge even when the boss center is clear")
	boss.global_position = flight_space.screen_to_combat_plane(view * Vector2(0.5, 0.55))
	await get_tree().create_timer(0.2).timeout
	_expect(panel.modulate.a > 0.99, "Boss dock returns to full visibility after the hull clears it")
	var hidden_hull := boss.visuals.get_child(0) as Node3D
	var hidden_transform := hidden_hull.transform
	hidden_hull.global_position = flight_space.screen_to_combat_plane(panel.get_global_rect().get_center())
	_expect(not hidden_hull.is_visible_in_tree(), "The displaced alternate hull remains hidden")
	await get_tree().create_timer(0.2).timeout
	_expect(panel.modulate.a > 0.99, "Hidden boss variants cannot keep the HUD faded")
	hidden_hull.transform = hidden_transform
	boss.global_position = flight_space.screen_to_combat_plane(panel.get_global_rect().get_center())
	await get_tree().create_timer(0.2).timeout
	_expect(absf(panel.modulate.a - 0.2) < 0.01, "The active hull still fades the dock after ignoring hidden variants")
	boss.take_damage(999999)
	await get_tree().create_timer(0.2).timeout
	_expect(not is_instance_valid(boss), "Destroyed boss retires through the production lifecycle")
	_expect(panel.modulate.a > 0.99, "Destroyed bosses cannot leave stale HUD occlusion")
	_expect(flight_space.get_combat_bounds().is_equal_approx(arena), "Boss movement and retirement preserve arena geometry")
	GameManager.current_wave = previous_wave
	GameManager.boss_active = previous_boss_active
	player.global_position = previous_position
	bar.visible = previous_bar_visible
	flight_space.bounds_changed.emit()
	rig.set_process(rig_was_processing)


func _topmost_mesh_vertex(model: Node3D, camera: Camera3D) -> Vector3:
	var highest := Vector3.ZERO
	var top := INF
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for surface in mesh.mesh.get_surface_count():
			var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var point := mesh.global_transform * vertex
				var screen_y := camera.unproject_position(point).y
				if screen_y < top:
					top = screen_y
					highest = point
	_expect(is_finite(top), "The imported boss hull supplies a visible vertex for edge occlusion")
	return highest


func _check_quit_save_retry() -> void:
	# A directory at the temporary file path simulates an unwritable save.
	DirAccess.make_dir_absolute(SaveManager.SAVE_TEMP_PATH)
	GameManager.practice_mode = false # Settlement is intentionally disabled in practice.
	GameManager.score = 7654
	_confirm_window_close()
	_exit_confirmation.get_child(0)._finish(true)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(_quit_attempts == 0 and get_tree().paused, "A failed final save keeps the application open and paused")
	var dialog: Control = _exit_confirmation.get_child(0)
	_expect(dialog.title == "Save failed" and dialog.confirm_text == "QUIT WITHOUT SAVING" and dialog.cancel_text == "RETRY SAVE", "Failed quit offers retry or an explicit unsaved exit")
	var wallet := MetaProgression.salvage
	var runs := MetaProgression.stat_total_runs
	DirAccess.remove_absolute(SaveManager.SAVE_TEMP_PATH)
	dialog._finish(false) # The safe/default action retries the save.
	_expect(_quit_attempts == 1 and SaveManager.get_storage_notice().is_empty(), "A successful retry allows exit and clears the notice")
	_expect(MetaProgression.salvage == wallet and MetaProgression.stat_total_runs == runs, "Quit retry never awards settlement twice")
	var reloaded := preload("res://autoloads/save_manager.gd").new()
	reloaded._load_data()
	_expect(reloaded.high_score == 7654 and reloaded.salvage == wallet, "Final score and salvage survive reopening after retry")
	reloaded.free()
	_exit_confirmation.queue_free()
	_exit_confirmation = null
	get_tree().paused = false
	GameManager.practice_mode = true

func _hold_at_screen_position(point: Vector2, duration: float) -> void:
	# The boss camera follows the craft; continue moving under the HUD so this
	# checks occlusion while the camera moves, not a stale world coordinate.
	var until := Time.get_ticks_msec() + int(duration * 1000.0)
	while Time.get_ticks_msec() < until:
		player.global_position = flight_space.screen_to_combat_plane(point)
		await get_tree().process_frame


func _check_hud_scale() -> void:
	var bounds := flight_space.get_combat_bounds()
	for type in [PowerUp.Type.RAPID_FIRE, PowerUp.Type.SPREAD_SHOT, PowerUp.Type.MAGNET, PowerUp.Type.SHIELD]:
		SignalBus.power_up_collected.emit(type, player.global_position)
	for factor in [1.0, 1.3]:
		SaveManager.update_setting("hud_scale", factor)
		await get_tree().process_frame
		await get_tree().process_frame
		var header := hud.get_node("CombatHeader") as Control
		var boss := hud.get_node("BossDock") as Control
		var view := get_viewport().get_visible_rect()
		_expect(is_equal_approx(header.scale.x, factor) and is_equal_approx(boss.scale.x, factor), "Combat and boss information scale independently from menus")
		_expect(view.encloses(header.get_global_rect()) and view.encloses(boss.get_global_rect()), "Largest HUD with full power-up chips stays inside the viewport")
		_expect(header.get_global_rect().end.y < boss.get_global_rect().position.y, "Scaled HUD never overlaps the boss warning")
		_expect(flight_space.get_combat_bounds().is_equal_approx(bounds), "HUD scale never changes aiming or spawn bounds")


func _check_input_interruptions() -> void:
	var shots := [0]
	player.fire_requested.connect(func(_position: Vector3, _direction: Vector3): shots[0] += 1)
	SaveManager.update_setting("toggle_fire", true)
	Input.action_release("shoot")
	player._update_shooting() # Establish neutral after the settings change.
	Input.action_press("shoot")
	player._update_shooting()
	Input.action_release("shoot")
	var first: int = shots[0]
	_expect(first > 0, "The first toggle press fires")
	await get_tree().create_timer(0.25).timeout
	player._update_shooting()
	_expect(shots[0] > first, "Toggle fire continues after releasing the button")
	Input.action_press("shoot")
	player._update_shooting()
	Input.action_release("shoot")
	var stopped: int = shots[0]
	await get_tree().create_timer(0.25).timeout
	player._update_shooting()
	_expect(shots[0] == stopped, "The second toggle press stops firing")

	Input.action_press("shoot")
	player._update_shooting()
	get_window().focus_exited.emit()
	_expect(get_tree().paused and is_instance_valid(_pause_overlay), "Window focus loss pauses active flight")
	_close_pause_menu()
	var after_pause: int = shots[0]
	player._update_shooting()
	_expect(shots[0] == after_pause and not player._fire_latched, "Resuming with a held fire button cannot restart firing")
	Input.action_release("shoot")
	player._update_shooting()
	await get_tree().process_frame
	Input.action_press("shoot")
	player._update_shooting()
	_expect(player._fire_latched, "A fresh press can restart toggle fire after resume")
	Input.action_release("shoot")

	InputBindings.family = "gamepad"
	InputBindings.active_gamepad = 42
	InputBindings._on_joy_connection_changed(41, false)
	_expect(not get_tree().paused, "An unrelated controller disconnect does not pause flight")
	InputBindings._on_joy_connection_changed(42, false)
	_expect(get_tree().paused and InputBindings.family == "keyboard" and not player._fire_latched, "Losing the active pad pauses and clears automatic fire")
	var pause_overlay := _pause_overlay
	get_window().focus_exited.emit()
	_expect(_pause_overlay == pause_overlay, "Repeated interruptions cannot stack pause menus")
	_confirm_window_close()
	_expect(is_instance_valid(_exit_confirmation) and get_tree().paused, "OS close requests confirm abandonment")
	_exit_confirmation.get_child(0)._finish(false)
	_expect(get_tree().paused, "Cancelling quit preserves an existing pause")
	_close_pause_menu()
	await get_tree().process_frame
	_confirm_window_close()
	_exit_confirmation.get_child(0)._finish(false)
	_expect(not get_tree().paused, "Cancelling quit from active flight resumes that flight")
	await get_tree().process_frame
	SaveManager.update_setting("toggle_fire", false)
	player._update_shooting()
	Input.action_press("shoot")
	await get_tree().create_timer(0.25).timeout
	player._update_shooting()
	var held: int = shots[0]
	Input.action_release("shoot")
	await get_tree().create_timer(0.25).timeout
	player._update_shooting()
	_expect(held > after_pause and shots[0] == held, "Default hold-to-fire still stops on release")
