extends "res://scenes/native_3d_run.gd"
## Headless coverage for the debug-build pause panel and native command surface.

const DEV_MENU := preload("res://ui/dev_menu.tscn")
const PAUSE_MENU := preload("res://ui/pause_menu.tscn")

var _failures: Array[String] = []


func _ready() -> void:
	await super._ready()
	_run_checks.call_deferred()


func _run_checks() -> void:
	_expect(GameManager.is_game_active, "Native run initializes for debug commands")
	_expect(OS.is_debug_build(), "Smoke test runs as a debug build")
	_check_debug_ui()
	_check_player_commands()
	_check_run_commands()
	await _check_enemy_commands()
	await _check_reward_commands()
	await _check_boss_command()
	GameManager.is_game_active = false
	if _failures.is_empty():
		print("DEV_COMMANDS_SMOKE_PASS")
		print("PASS: debug UI, player overrides, run actions, enemies, rewards, and boss variants")
		await get_tree().process_frame
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("DEV_COMMANDS_SMOKE_FAIL: %d assertion(s)" % _failures.size())
		await get_tree().process_frame
		get_tree().quit(1)


func _check_debug_ui() -> void:
	var pause_overlay := CanvasLayer.new()
	add_child(pause_overlay)
	var pause := PAUSE_MENU.instantiate()
	pause_overlay.add_child(pause)
	_expect(pause.find_child("DevWrap", true, false) != null, "Pause menu exposes Dev / Debug in debug builds")
	var panel := DEV_MENU.instantiate()
	add_child(panel)
	_expect(panel.get_child_count() == 1, "Developer panel has one layout root")
	_expect(panel.find_children("*", "Button", true, false).size() >= 30, "Developer panel builds the full command set")
	_expect(panel.get_child(0).get_child_count() == 3, "Developer panel builds title, separator, and command scroller")
	panel.queue_free()
	pause_overlay.queue_free()


func _check_player_commands() -> void:
	var lives_before := GameManager.lives
	player.set_dev_god_mode(true)
	_expect(player.dev_god_mode, "God mode enables")
	_expect(
		not player.receive_damage(player.global_position, Player3D.DamageSource.ENEMY_PROJECTILE),
		"God mode rejects incoming damage"
	)
	_expect(GameManager.lives == lives_before, "God mode preserves lives")
	player.set_dev_god_mode(false)

	for power_id in Player3D.DEV_POWER_IDS:
		_expect(player.set_dev_power_override(power_id, true), "Power override enables: " + power_id)
		_expect(player.get_dev_power_override(power_id), "Power override is queryable: " + power_id)
		_expect(player.set_dev_power_override(power_id, false), "Power override disables: " + power_id)

	var chosen_before := GameManager.chosen_upgrade_ids.duplicate()
	_expect(player.set_elite_upgrade_enabled("hull_plating", true, false), "Elite debug toggle enables")
	_expect(GameManager.lives == lives_before, "Elite debug toggle skips Hull Plating's one-time reward")
	_expect(player.set_elite_upgrade_enabled("hull_plating", false, false), "Elite debug toggle disables")
	_expect(GameManager.chosen_upgrade_ids == chosen_before, "Elite debug toggles do not change reward history")

	for flag in Player3D.VISUAL_DEBUG_FLAGS:
		_expect(player.set_visual_debug(flag, true), "Visual debug enables: " + flag)
		_expect(player.get_visual_debug(flag), "Visual debug is queryable: " + flag)
		_expect(player.set_visual_debug(flag, false), "Visual debug disables: " + flag)


func _check_run_commands() -> void:
	var lives_before := GameManager.lives
	dev_add_lives(5)
	_expect(GameManager.lives == lives_before + 5, "Add Lives uses the run authority")
	var orbs_before := GameManager.orbs_collected_this_wave
	dev_add_orbs(1)
	_expect(GameManager.orbs_collected_this_wave == orbs_before + 1, "Add Orbs uses the shared orb event")
	dev_force_generation(4)
	_expect(GameManager.dev_enemy_generation_override == 4, "Generation override is stored")
	_expect(encounters.threat.generation == 4, "Generation override updates the live threat director")
	_expect("Gen 4" in get_dev_debug_state(), "Debug state reports the forced generation")


func _check_enemy_commands() -> void:
	var enemy := dev_spawn_archetype(&"tank")
	_expect(enemy != null, "Spawn archetype creates a native enemy")
	if enemy != null:
		_expect(enemy.is_in_group(&"native_3d_regular_enemies"), "Debug enemy uses the production group contract")
		dev_trigger_enemy_abilities()
	dev_clear_hostiles()
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(get_tree().get_nodes_in_group(&"native_3d_regular_enemies").is_empty(), "Clear Hostiles removes regular enemies")


func _check_reward_commands() -> void:
	dev_trigger_point_allocation(2)
	await get_tree().process_frame
	_expect(is_instance_valid(_run_overlay), "Point Allocation command opens the native reward overlay")
	if is_instance_valid(_run_overlay):
		_finish_reward()
		await get_tree().process_frame
	dev_trigger_elite_reward()
	await get_tree().process_frame
	_expect(is_instance_valid(_run_overlay), "Elite Upgrade command opens the native reward overlay")
	if is_instance_valid(_run_overlay):
		_finish_reward()
		await get_tree().process_frame


func _check_boss_command() -> void:
	_expect(dev_spawn_boss_variant(&"core"), "Tempest Core command is accepted")
	await get_tree().process_frame
	await get_tree().process_frame
	var bosses := get_tree().get_nodes_in_group(&"native_3d_bosses")
	_expect(bosses.size() == 1, "Boss command creates exactly one boss")
	if bosses.size() == 1:
		_expect(int(bosses[0].variant) == 4, "Tempest Core command selects the exact boss variant")
	_expect(GameManager.current_wave == GameManager.FINAL_EXPEDITION_WAVE, "Tempest Core command targets the final wave")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
