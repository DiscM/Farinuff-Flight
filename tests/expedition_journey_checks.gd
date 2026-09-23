extends RefCounted
## Assisted progression checks through the shipping run, actors, and reward UI.
## Invoked by the existing Expedition scene; these do not measure player skill.
const RUN := preload("res://scenes/native_3d_run.tscn")
const CHART := preload("res://ui/expedition_chart.gd")
const HULLS := ["ship_swallowtail", "ship_interceptor", "ship_bulwark"]
const BUILDS := [
	["afterburner", "hull_plating", "shield_burst"],
	["auto_aim", "piercing", "twin_cannons", "overclock"],
	["drone_escort", "orbitals", "spread_shot_elite", "magnet_field", "rear_gunner"],
]
var _tree: SceneTree
var _owner: Node
var _failures: Array[String] = []
var _case := ""
var _observed_steps: Array[String] = []


func run(owner: Node) -> Array[String]:
	_owner = owner
	_tree = owner.get_tree()
	owner.process_mode = Node.PROCESS_MODE_ALWAYS
	await _check_reward_quit_overlap()
	var index := 0
	for full_meta in [false, true]:
		for hull: String in HULLS:
			for second: StringName in [&"iron_wake", &"ghost_lanes"]:
				for third: StringName in [&"tempest_veil", &"echo_field"]:
					_case = "%s/%s/%s/%s" % [hull, second, third, "full" if full_meta else "base"]
					await _journey(hull, [second, third, &"quiet_core"], full_meta, index)
					index += 1
	_tree.current_scene = owner
	_tree.paused = false
	return _failures


func _check_reward_quit_overlap() -> void:
	_case = "reward/quit overlap"
	_fixture("ship_swallowtail", false, 2) # Story Off, so the elite is the last overlay.
	var game := RUN.instantiate()
	_tree.root.add_child(game)
	_tree.current_scene = game
	game.get_window().focus_exited.emit() # Interrupt while actor warmup is awaiting.
	if not await _until(func(): return game.encounters.started, "interrupted run preparation"):
		await _dispose(game)
		return
	game.encounters.set_physics_process(false)
	game.player.set_dev_god_mode(true)
	await _frames(2)
	_expect(_tree.paused and is_instance_valid(game._pause_overlay), "Run startup and its empty reward queue preserve the loading interruption")
	game._close_pause_menu()
	for interruption: String in ["quit", "focus", "controller"]:
		game._queue_elite_reward()
		var panel := await _overlay(game, &"upgrade_chosen")
		if panel == null:
			break
		var selected: String = panel.chosen_upgrades[0].id
		var select: Button = panel.cards_by_id[selected].get_meta("select_button")
		select.pressed.emit()
		panel._install_button.pressed.emit()
		match interruption:
			"quit":
				game._confirm_window_close()
			"focus":
				game.get_window().focus_exited.emit()
			"controller":
				InputBindings.family = "gamepad"
				InputBindings.active_gamepad = 42
				InputBindings._on_joy_connection_changed(42, false)
		await _tree.create_timer(0.25, true).timeout
		_expect(_tree.paused and not is_instance_valid(game._run_overlay), "The final reward cannot resume unattended after " + interruption)
		if interruption == "quit":
			game._exit_confirmation.get_child(0)._finish(false)
		else:
			_expect(is_instance_valid(game._pause_overlay), "Reward completion retains an interruption until explicit resume")
			game._close_pause_menu()
		await _frames(2)
		_expect(not _tree.paused and not is_instance_valid(game._pause_overlay), "Explicit resume never strands a pause after " + interruption)
	GameManager.is_game_active = false
	game._end_run(GameManager.score)
	game._confirm_window_close() # Before the deferred Try Again mount.
	await _frames(2)
	_expect(not is_instance_valid(game._run_overlay) and game._exit_confirmation.is_ancestor_of(_tree.root.gui_get_focus_owner()), "A deferred end screen waits for quit cancellation without stealing focus")
	game._exit_confirmation.get_child(0)._finish(false)
	var retry := await _overlay(game, &"try_again_accepted")
	if retry != null:
		game._confirm_window_close()
		await _tree.create_timer(0.25, true).timeout
		_expect(is_instance_valid(retry) and not retry._action_taken, "Quit confirmation preserves the pending recovery decision")
		_expect(game._exit_confirmation.is_ancestor_of(_tree.root.gui_get_focus_owner()), "Recovery cannot move focus behind the quit modal")
		game._exit_confirmation.get_child(0)._finish(false)
		retry._on_try_again()
		await _frames(2)
		_expect(GameManager.is_game_active and not _tree.paused, "Cancelling quit retains the offered continuation")
	await _dispose(game)


func _fixture(hull: String, full_meta: bool, index: int) -> void:
	MetaProgression.unlock_levels.clear()
	# Alternate hulls are unlocked, but base cases have no permanent stat buffs.
	MetaProgression.unlock_levels[hull] = 1
	if full_meta:
		for item: Dictionary in MetaProgression.SHOP_ITEMS:
			MetaProgression.unlock_levels[item.id] = item.costs.size()
	MetaProgression.selected_ship = hull
	MetaProgression.active_modifiers.clear()
	MetaProgression.salvage = 0
	MetaProgression.claimed_milestones.clear()
	MetaProgression.stat_total_runs = 0
	MetaProgression.stat_total_kills = 0
	MetaProgression.stat_best_wave = 0
	MetaProgression.consumable_stocks = 3 if full_meta else 0
	MetaProgression.consumable_powerup_armed = full_meta
	MetaProgression._persist()
	GameManager.high_score = 0
	SaveManager.high_score = 0
	GameManager.return_to_flight_school = false
	SaveManager.campaign_state = {
		"discovered_node_ids": [], "seen_story_beat_ids": [],
		"recovered_fragment_ids": [], "expedition_clear_count": 0, "last_ending_id": "",
	}
	ExpeditionManager._load_durable_state()
	ExpeditionManager._route_override_profile_id = &""
	SaveManager.update_setting("story_frequency", index % 3)
	SaveManager.update_setting("reduced_motion", true)
	seed(6100 + index)
	_observed_steps.clear()


func _journey(hull: String, routes: Array, full_meta: bool, index: int) -> void:
	_fixture(hull, full_meta, index)
	var game := RUN.instantiate()
	_tree.root.add_child(game)
	_tree.current_scene = game
	if not await _until(func(): return game.encounters.started, "run preparation"):
		await _dispose(game)
		return
	game.encounters.set_physics_process(false)
	game.player.set_dev_god_mode(true)
	var expected_lives: int = [3, 2, 5][HULLS.find(hull)] + (3 if full_meta else 0)
	_expect(GameManager.starting_lives == expected_lives, "Selected hull and permanent lives apply")
	_expect(GameManager.try_again_stocks == (7 if full_meta else 2), "Field supplies are consumed once at launch")
	_expect(MetaProgression.consumable_stocks == 0 and not MetaProgression.consumable_powerup_armed,
		"Consumed field supplies leave the persistent inventory")
	var model: String = ["PlayerHullGLB", "InterceptorHull", "BulwarkHull"][HULLS.find(hull)]
	_expect(game.player.get_node("Visuals/" + model).visible, "Selected hull is visible")
	await _drain_steps(game, routes, BUILDS[index % BUILDS.size()])
	for wave in range(1, 21):
		_expect(GameManager.current_wave == wave, "Reach wave %d without skips" % wave)
		if wave % 5 == 0:
			await _boss(game, wave, index == 0 and wave == 20)
		elif wave % 5 == 3:
			await _objective(game, wave == 3 or wave == 13)
		if wave % 5 != 0:
			SignalBus.xp_orb_collected.emit(GameManager.orbs_needed_this_wave - GameManager.orbs_collected_this_wave)
		if wave < 20:
			await _drain_steps(game, routes, BUILDS[index % BUILDS.size()])
	var screen := await _overlay(game, &"continue_endless")
	if screen == null:
		await _dispose(game)
		return
	_expect(GameManager.expedition_completed and not GameManager.is_game_active, "Finale pauses on a distinct victory decision")
	_expect(GameManager.current_wave == 21 and not game.encounters.started, "Endless cannot start before the decision")
	_expect(GameManager.chosen_upgrade_ids.size() == 3, "Expedition installs three distinct upgrades")
	_expect(GameManager.stat_fire_rate_level == 3 and GameManager.stat_health_level == 3 and GameManager.stat_speed_level == 3,
		"Three allocation screens commit exactly nine points")
	_expect(GameManager.run_salvage_boss == 180, "Four Expedition bosses bank the intended 180 salvage")
	_expect(GameManager.run_objectives_attempted == 4 and GameManager.run_objectives_completed == 2,
		"Optional objective success and escape never block progression")
	var snapshot := ExpeditionManager.get_snapshot()
	_expect(snapshot.cleared_node_ids == [&"far_reach", routes[0], routes[1], &"quiet_core"], "Chosen routes reach the complete four-sector ending")
	_expect(snapshot.recovered_fragment_ids.size() == 2, "Only the two completed branches yield fragments")
	_expect(_observed_steps.count("elite") == 3 and _observed_steps.count("allocation") == 3 and _observed_steps.count("route") == 3,
		"Every milestone presents its reward and route decision once")
	var installed := GameManager.chosen_upgrade_ids.duplicate()
	var ending := "return_home" if index % 2 == 0 else "follow_signal"
	if ending == "return_home":
		screen._menu_button.pressed.emit()
		await _until(func(): return _tree.current_scene != null and _tree.current_scene.scene_file_path == "res://scenes/home_base.tscn", "return home")
		_expect(SaveManager.high_score == GameManager.score and GameManager.score > 0, "Return Home retains the score record")
	else:
		screen._continue_button.pressed.emit()
		await _frames(2)
		_expect(GameManager.is_game_active and not GameManager.expedition_completed and GameManager.current_wave == 21,
			"Endless resumes once at wave 21")
		_expect(GameManager.chosen_upgrade_ids == installed and GameManager.stat_fire_rate_level == 3,
			"Endless preserves the installed build and allocations")
		for wave in range(21, 26):
			_expect(GameManager.current_wave == wave, "Endless reaches wave %d" % wave)
			if wave < 25:
				SignalBus.xp_orb_collected.emit(GameManager.orbs_needed_this_wave - GameManager.orbs_collected_this_wave)
				await _frames(2)
			else:
				await _boss(game, wave, false)
				await _drain_steps(game, [], BUILDS[index % BUILDS.size()])
		_expect(GameManager.chosen_upgrade_ids == installed, "Wave 25 does not grant a duplicate elite reward")
		game.abandon_run()
		_expect(SaveManager.high_score == GameManager.score, "Ending an Endless run retains the score record")
	_expect(ExpeditionManager.get_snapshot().expedition_clear_count == 1, "Ending choice banks one campaign clear")
	_expect(ExpeditionManager.get_snapshot().last_ending_id == StringName(ending), "Ending choice persists")
	var wallet := MetaProgression.salvage
	GameManager.finalize_run()
	_expect(MetaProgression.salvage == wallet and MetaProgression.stat_total_runs == 1, "Settlement cannot duplicate currency or lifetime runs")
	_expect(GameManager.run_salvage == wallet, "Run breakdown equals the wallet credit")
	print("EXPEDITION_JOURNEY " + JSON.stringify({"case": _case, "ending": ending, "upgrades": installed,
		"score": GameManager.score, "salvage": wallet, "waves_cleared": GameManager.current_wave - 1,
		"assisted": true, "failures_so_far": _failures.size()}))
	await _dispose(_tree.current_scene)


func _boss(game: Node, wave: int, simultaneous_defeat: bool) -> void:
	if not await _until(func(): return not _tree.get_nodes_in_group(&"native_3d_bosses").is_empty(), "wave %d boss spawn" % wave):
		return
	var bosses := _tree.get_nodes_in_group(&"native_3d_bosses")
	_expect(bosses.size() == 1, "Exactly one boss spawns at a milestone")
	var boss: Node = bosses[0]
	_expect(boss.variant == {5: 0, 10: 1, 15: 2, 20: 4, 25: 3}[wave], "Authored boss identity at wave %d" % wave)
	boss.set_physics_process(false)
	boss._arena_patterns.set_physics_process(false)
	for section: Node in boss._sections:
		if section.is_active:
			section.take_damage(99999)
	for phase in [1, 2]:
		boss._arena_patterns._plan_pattern()
		game.projectile_manager.fire_enemy_projectile(boss.global_position, Vector3.BACK)
		var target_hp := floori(float(boss.max_health) * (0.55 if phase == 1 else 0.20))
		boss.take_damage(int(boss.health) - target_hp)
		await _frames(2)
		_expect(boss.phase == phase, "Damage crosses boss phase %d" % (phase + 1))
		_expect(boss._arena_patterns.pending.is_empty() and _tree.get_nodes_in_group(&"enemy_projectiles").is_empty(),
			"Phase transitions clear pending pressure and hostile shots")
	boss.take_damage(99999)
	if simultaneous_defeat:
		game.player.set_dev_god_mode(false)
		game.player.reset_power_up_state()
		game.player.reset_damage_state()
		game.player.receive_damage(game.player.global_position, Player3D.DamageSource.ENEMY_PROJECTILE, GameManager.lives)
		var retry := await _overlay(game, &"try_again_accepted")
		if retry != null:
			var stocks := GameManager.try_again_stocks
			retry._on_try_again()
			await _frames(2)
			_expect(GameManager.try_again_stocks == stocks - 1 and GameManager.lives == GameManager.starting_lives,
				"Simultaneous boss death consumes one continue and restores the hull's lives")
			game.player.set_dev_god_mode(true)
			game.encounters._physics_process(0.01)
	await _frames(2)
	_expect(not GameManager.boss_active, "Boss death settles its wave")
	_expect(_tree.get_nodes_in_group(&"native_3d_bosses").is_empty(), "Finished boss leaves the actor graph")


func _objective(game: Node, complete: bool) -> void:
	_expect(game.encounters.objectives.try_start(), "Optional courier starts in its sector")
	var courier: Node = game.encounters.objectives._courier
	if courier == null:
		return
	var score_before := GameManager.score
	if complete:
		courier.take_damage(99999)
		_expect(GameManager.score == score_before + 500, "Courier banks its objective reward exactly once")
	else:
		game.encounters.objectives._process(20.0)
		_expect(GameManager.score == score_before, "Timed-out courier cannot bank rewards")
	_expect(game.encounters.objectives._sealed and game.encounters.objectives._courier == null,
		"Objective completion releases the active courier")
	await _frames(2)
	_expect(not is_instance_valid(courier), "Finished objective removes its courier actor")
	_expect(not game.encounters.objectives.try_start(), "A sector cannot repeat its optional reward")


func _drain_steps(game: Node, routes: Array, preferred: Array) -> void:
	for attempt in range(240):
		await _frames(1)
		if not is_instance_valid(game._run_overlay):
			if not game._interludes.has_work():
				_expect(not _tree.paused, "Completed interludes resume gameplay")
				return
			continue
		var panel: Node = game._run_overlay.get_child(0)
		if panel.has_signal(&"upgrade_chosen") and not panel.selection_locked:
			_observed_steps.append("elite")
			var selected: String = panel.chosen_upgrades[0].id
			for id: String in preferred:
				if panel.cards_by_id.has(id):
					selected = id
					break
			var select: Button = panel.cards_by_id[selected].get_meta("select_button")
			select.pressed.emit()
			panel._install_button.pressed.emit()
			panel._install_button.pressed.emit()
		elif panel.has_signal(&"allocation_done") and not panel.allocation_committed:
			_observed_steps.append("allocation")
			panel.fire_rate_btn.pressed.emit()
			panel.health_btn.pressed.emit()
			panel.speed_btn.pressed.emit()
			panel.confirm_btn.pressed.emit()
			panel.confirm_btn.pressed.emit()
		elif panel.has_signal(&"resolved") and not panel._resolved:
			if panel.routes.is_empty():
				_observed_steps.append("story")
				panel._choose(&"")
			else:
				_observed_steps.append("route")
				var sector: int = panel.routes[0].sector_index
				var destination: StringName = routes[sector - 2]
				for control: Node in panel.find_children("*", "Control", true, false):
					if control is CHART:
						control._graph._buttons[destination].pressed.emit()
						var name: String = MetaProgression.get_item(MetaProgression.selected_ship).name
						_expect(control._dossier.text.split("\n")[3].ends_with(name), "Route dossier identifies the selected hull")
				panel._choose(destination)
	_expect(false, "Interlude flow completed within its bounded wait")


func _overlay(game: Node, expected_signal: StringName) -> Node:
	if not await _until(func(): return (is_instance_valid(game._run_overlay)
		and game._run_overlay.get_child_count() == 1
		and game._run_overlay.get_child(0).has_signal(expected_signal)), "overlay " + str(expected_signal)):
		return null
	return game._run_overlay.get_child(0)


func _until(condition: Callable, description: String) -> bool:
	for attempt in range(600):
		if condition.call():
			return true
		await _frames(1)
	_expect(false, "Timed out waiting for " + description)
	return false


func _dispose(scene: Node) -> void:
	_tree.paused = false
	_tree.current_scene = _owner
	if is_instance_valid(scene) and scene != _owner:
		scene.queue_free()
	await _frames(3)


func _frames(count: int) -> void:
	for frame in count:
		await _tree.process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(_case + ": " + message)
