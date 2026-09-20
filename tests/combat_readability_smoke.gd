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
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1280, 800), Vector2i(1920, 810)]:
		get_window().size = resolution
		await get_tree().process_frame
		await get_tree().process_frame
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
