extends "res://scenes/flight_practice.gd"
## Exercises the production lesson, real reflection/chain signals, and orb actors.
var _failures: Array[String] = []

func _ready() -> void:
	GameManager.practice_boss_wave = 0
	await super._ready()
	_run.call_deferred()

func _run() -> void:
	set_physics_process(false)
	player.set_physics_process(false)
	var salvage := MetaProgression.salvage
	_expect(GameManager.orbs_needed_this_wave == 12, "Practice HUD agrees with the twelve-point lesson target")
	player.set_combat_position(_origin + flight_space.screen_motion_to_combat(Vector2(120, 0)))
	_physics_process(0.01)
	_expect(_moved and _step == 0, "Movement is acknowledged before firing")
	player.set_combat_position(_origin)
	player.fire_requested.emit(player.global_position, Vector3.FORWARD)
	_physics_process(0.01)
	_expect(_step == 1, "Returning to the origin does not erase completed movement")
	projectile_manager.clear_projectiles()
	await get_tree().process_frame
	await get_tree().process_frame
	_prepare_volley()
	_expect(get_tree().get_nodes_in_group("enemy_projectiles").is_empty(), "Volley warning precedes hostile shots")
	_expect(_volley_cue.origins.size() == 3 and _volley_warning > 0, "All three shot origins are previewed")
	var warning_before := _volley_warning
	set_physics_process(true)
	get_tree().paused = true
	await get_tree().create_timer(0.1, true).timeout
	_expect(is_equal_approx(_volley_warning, warning_before), "Pausing preserves the training warning")
	set_physics_process(false)
	get_tree().paused = false
	_physics_process(VOLLEY_WARNING + 0.01)
	var shots := get_tree().get_nodes_in_group("enemy_projectiles")
	_expect(shots.size() == 3, "One warning releases exactly three production shots")
	player.is_boosting = true
	player.boost_reflected_projectiles = 0
	player.velocity = flight_space.screen_motion_to_combat(Vector2.UP * 800)
	for shot in shots:
		shot.global_position = player.global_position + Vector3(0, 0, -1)
	projectile_manager.deflect_enemy_projectiles(player.global_position, player.velocity)
	_expect(_step == 2 and player.boost_reflected_projectiles == 3, "Real reflected shots advance the lesson and unlock a chain")
	_show_step()
	_expect(_lesson.text.contains("CHAIN READY"), "Ready chain gives a direct second-press cue")
	# Complete the chain near a corner: every collection target must remain reachable.
	var bounds := flight_space.get_combat_bounds()
	player.set_combat_position(Vector3(bounds.end.x, 0, bounds.position.y))
	player._begin_boost()
	_expect(_step == 3 and _volley_warning == 0, "Actual chained boost ends incoming practice fire")
	var orbs := get_tree().get_nodes_in_group("xp_orbs")
	_expect(orbs.size() == 6, "Chain creates the twelve-point collection exercise")
	# Simulate the old edge falling outside a narrowed viewport.
	orbs[0].global_position.x = bounds.end.x + 10.0
	_keep_lesson_orbs_reachable()
	for orb in orbs:
		var before: Vector3 = orb.global_position
		orb._physics_process(25.0)
		_expect(orb.is_active and orb.global_position.is_equal_approx(before), "Learning supplies neither expire nor drift away")
		_expect(bounds.has_point(Vector2(before.x, before.z)), "Corner-spawned supplies stay inside the arena")
		orb._collect()
	_expect(_step == 4 and _launch_button.visible, "Collecting actual orb actors unlocks expedition preparation")
	Input.action_press("shoot")
	_physics_process(0.01)
	_expect(_launch_button.disabled, "Held fire cannot accept expedition preparation")
	Input.action_release("shoot")
	Input.action_release("ui_accept")
	_physics_process(0.01)
	_expect(not _launch_button.disabled and _launch_button.has_focus(), "Completion is controller-accessible after releasing fire")
	_expect(MetaProgression.salvage == salvage and GameManager.practice_mode, "Lesson never banks salvage or starts a real run")
	for corner in [bounds.position, bounds.end, Vector2(bounds.position.x, bounds.end.y), Vector2(bounds.end.x, bounds.position.y)]:
		player.set_combat_position(Vector3(corner.x, 0, corner.y))
		_prepare_volley()
		for origin in _volley_origins:
			_expect(bounds.has_point(Vector2(origin.x, origin.z)), "Corner volley origins stay on screen")
			_expect(flight_space.combat_motion_to_screen(origin - player.global_position).length() > 100.0, "Corner volley preserves reaction distance")
	_volley_cue.remaining = 0.0
	SaveManager.settings["menu_text_scale"] = 1.3
	SaveManager.settings["hud_scale"] = 1.3
	SaveManager.settings_changed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_layout_lesson()
	var header := hud.get_node("CombatHeader") as Control
	_expect(_lesson_panel.position.y >= header.position.y + header.size.y * header.scale.y, "Large-text lesson clears the combat header")
	_expect(_launch_button.get_global_rect().end.y < get_viewport().get_visible_rect().size.y, "Completion action stays visible at large text")
	for failure in _failures:
		push_error(failure)
	print("PRACTICE_LESSON_SMOKE_PASS" if _failures.is_empty() else "PRACTICE_LESSON_SMOKE_FAIL")
	get_tree().quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
