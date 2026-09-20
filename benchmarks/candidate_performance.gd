extends Node
## Only admitted by a dedicated benchmark build or a disposable source runner.
## The shipping presets exclude this entire directory.
const Sampler := preload("res://benchmarks/performance_sampler.gd")
const SCENARIO := "candidate-pressure-v1"
const ROLES := [&"basic", &"fast", &"bomber", &"tank", &"sniper"]
const BOSSES := [&"assault", &"bulwark", &"tempest", &"core", &"harbinger"]
const UPGRADES := ["auto_aim", "piercing", "explosive_rounds", "drone_escort", "twin_cannons", "spread_shot_elite", "overclock"]
var _config: Dictionary
var _game: Node
var _sampler: Node
var _cycle := 0
var _stage := ""
var _sim_seconds := 0.0
var _refill_at := 0.0
var _boss: Node
var _driving := false
var _failed := false
var _boss_attacks: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	get_window().close_requested.connect(func(): _fail("Benchmark window was closed."))
	if not bool(ProjectSettings.get_setting("benchmark/enabled", false)) or not OS.get_user_data_dir().get_file().begins_with("farinuff-performance-"):
		_fail("Benchmark requires a dedicated, isolated benchmark profile.")
		return
	if not OS.is_debug_build() and not OS.has_feature("performance_benchmark"):
		_fail("This release was not built for benchmarking.")
		return
	var config_path := OS.get_environment("FARINUFF_PERFORMANCE_CONFIG")
	if config_path.is_empty():
		config_path = str(ProjectSettings.get_setting("benchmark/config_path", ""))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	if not parsed is Dictionary:
		_fail("Missing benchmark configuration.")
		return
	_config = parsed
	for key: String in ["cycles", "seconds", "warmup_seconds", "endless_seconds", "seed", "quality", "resolution", "capture_path"]:
		if not _config.has(key):
			_fail("Missing configuration key: " + key)
			return
	for key: String in ["cycles", "seconds", "warmup_seconds", "endless_seconds", "seed"]:
		if not (_config[key] is float or _config[key] is int) or not is_finite(float(_config[key])):
			_fail("Invalid numeric configuration: " + key)
			return
	if _config.cycles != int(_config.cycles) or int(_config.cycles) < 1 or int(_config.cycles) > 20 or float(_config.seconds) <= 0 or float(_config.seconds) > 600 or float(_config.endless_seconds) <= 0 or float(_config.endless_seconds) > 3600 or float(_config.warmup_seconds) < 0 or float(_config.warmup_seconds) > 60:
		_fail("Invalid benchmark duration or cycle count.")
		return
	if not _config.quality in ["low", "medium", "high"] or not _config.resolution is Array or _config.resolution.size() != 2:
		_fail("Invalid benchmark graphics configuration.")
		return
	for dimension: Variant in _config.resolution:
		if not (dimension is float or dimension is int) or not is_finite(float(dimension)) or dimension != int(dimension) or dimension < 64 or dimension > 16384:
			_fail("Invalid benchmark resolution.")
			return
	SaveManager.settings = SaveManager.DEFAULT_SETTINGS.duplicate(true)
	SaveManager.settings.merge({"story_frequency": 2, "frame_cap": 0, "vsync": false, "graphics_quality": str(_config.quality), "fullscreen": false}, true)
	SaveManager._apply_display_settings()
	get_window().size = Vector2i(int(_config.resolution[0]), int(_config.resolution[1]))
	if DisplayServer.get_name() != "headless":
		get_window().grab_focus()
		await _frames(3)
	MetaProgression.selected_ship = "ship_swallowtail"
	MetaProgression.unlock_levels.clear()
	MetaProgression.active_modifiers.clear()
	_sampler = Sampler.new()
	add_child(_sampler)
	get_tree().node_added.connect(_configure_run)
	var metadata := {
		"scenario": SCENARIO, "config": _config, "engine": Engine.get_version_info().string, "engine_hash": Engine.get_version_info().hash,
		"debug_build": OS.is_debug_build(), "os": OS.get_name(), "os_version": OS.get_version(),
		"cpu": OS.get_processor_name(), "logical_cpus": OS.get_processor_count(),
		"gpu": RenderingServer.get_video_adapter_name(), "display": DisplayServer.get_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(), "driver": RenderingServer.get_current_rendering_driver_name(),
		"physical_memory_bytes": OS.get_memory_info().get("physical", -1),
		"frame_cap": Engine.max_fps, "vsync": null,
		"upgrades": UPGRADES, "profile": OS.get_user_data_dir().get_file(),
		"window_size": [get_window().size.x, get_window().size.y], "physics_ticks_per_second": Engine.physics_ticks_per_second,
	}
	if DisplayServer.get_name() != "headless":
		metadata.vsync = DisplayServer.window_get_vsync_mode()
	_emit("metadata", metadata)
	_run.call_deferred()

func _run() -> void:
	for cycle in int(_config.cycles):
		_cycle = cycle
		seed(int(_config.seed))
		await _menu()
		if _failed:
			return
		await _launch()
		if _failed:
			return
		await _pressure("late_generation", 24, float(_config.seconds))
		if _failed:
			return
		for boss_id: StringName in BOSSES:
			await _boss_pressure(boss_id)
			if _failed:
				return
		await _pressure("endless", 55, float(_config.endless_seconds))
		if _failed:
			return
		_driving = false
		_release_input()
		await _retry()
		if _failed:
			return
		var before_free := Time.get_ticks_usec()
		_game.queue_free()
		_game = null
		_sampler.game = null
		get_tree().current_scene = self
		await _frames(4)
		ObjectPool.prune_stale()
		_emit("cleanup", {"cycle": _cycle, "elapsed_ms": (Time.get_ticks_usec() - before_free) / 1000.0, "state": _sampler.snapshot()})
		await _wait_for_cleanup_sample()
		if _failed:
			return
	_emit("complete", {"cycles": int(_config.cycles), "scenario": SCENARIO})
	get_tree().quit(0)

func _menu() -> void:
	var start := Time.get_ticks_usec()
	var packed: PackedScene = await ResourceCache.wait_for_scene(ResourceCache.MAIN_MENU_PATH)
	if packed == null:
		_fail("Menu resource did not load.")
		return
	var menu := packed.instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await _frames(3)
	_emit("transition", {"cycle": _cycle, "name": "menu", "elapsed_ms": (Time.get_ticks_usec() - start) / 1000.0})
	menu.queue_free()
	get_tree().current_scene = self
	await _frames(3)

func _launch() -> void:
	var start := Time.get_ticks_usec()
	var packed: PackedScene = await ResourceCache.wait_for_scene(ResourceCache.NATIVE_RUN_PATH)
	if packed == null:
		_fail("Run resource did not load.")
		return
	_game = packed.instantiate()
	_game.practice_session = true
	_game.consume_field_supplies = false
	_game.rewards_enabled = false
	get_tree().root.add_child(_game)
	get_tree().current_scene = _game
	await _prepare_game(start, "launch")

func _configure_run(node: Node) -> void:
	# SceneTree emits node_added before _ready, including a production retry.
	if node.get_parent() == get_tree().root and node.scene_file_path == ResourceCache.NATIVE_RUN_PATH:
		node.practice_session = true
		node.consume_field_supplies = false
		node.rewards_enabled = false
		_game = node
		if bool(_config.get("allow_background", false)):
			# Node.ready fires at the first await in the async _ready, before
			# pool warmup yields frames. Remove only the focus signal handler.
			node.ready.connect(_allow_background_diagnostic.bind(node), CONNECT_ONE_SHOT)

func _allow_background_diagnostic(game: Node) -> void:
	# Explicit diagnostic-only mode: retain gameplay while the host is used.
	# The report disqualifies this mode from foreground hardware acceptance.
	var pause_on_focus_loss := Callable(game, "_pause_for_interruption")
	if get_window().focus_exited.is_connected(pause_on_focus_loss):
		get_window().focus_exited.disconnect(pause_on_focus_loss)

func _retry() -> void:
	var previous_id := _game.get_instance_id()
	_game._pause_for_interruption()
	var pause_menu: Node = _game._pause_overlay.get_child(0)
	var start := Time.get_ticks_usec()
	pause_menu._restart_confirmed()
	while not is_instance_valid(_game) or _game.get_instance_id() == previous_id:
		if Time.get_ticks_usec() - start > 60000000:
			_fail("Production retry did not replace the run.")
			return
		await get_tree().process_frame
	await _prepare_game(start, "retry")

func _prepare_game(start: int, transition: String) -> void:
	var timeout := Time.get_ticks_msec() + 60000
	while not _game._gameplay_prepared or not _game.encounters.started:
		if Time.get_ticks_msec() > timeout:
			_fail("Run preparation timed out.")
			return
		await get_tree().process_frame
	await _frames(3)
	if get_tree().paused:
		_fail("Run was interrupted during preparation; keep the benchmark focused.")
		return
	_game.encounters.set_physics_process(false)
	_game.player.set_dev_god_mode(true)
	for upgrade: String in UPGRADES:
		_game.player.set_elite_upgrade_enabled(upgrade, true)
	_sampler.game = _game
	_emit("transition", {"cycle": _cycle, "name": transition, "elapsed_ms": (Time.get_ticks_usec() - start) / 1000.0, "state": _sampler.snapshot()})

func _wait_for_cleanup_sample() -> void:
	if not bool(_config.get("external_cleanup_ack", false)):
		return
	var acknowledgement := str(_config.capture_path).get_base_dir().path_join("cleanup-%d.ack" % _cycle)
	var deadline := Time.get_ticks_msec() + 10000
	# No next menu allocation or process exit until the host has sampled RSS.
	while not FileAccess.file_exists(acknowledgement):
		if Time.get_ticks_msec() > deadline:
			_fail("External cleanup sampler did not acknowledge the boundary.")
			return
		await get_tree().process_frame

func _clear_field() -> void:
	_driving = false
	_release_input()
	_boss = null
	_boss_attacks.clear()
	for actor: Node in get_tree().get_nodes_in_group(&"native_3d_enemies"):
		actor.queue_free()
	_game.projectile_manager.clear_projectiles()
	_game.hazard_manager.clear_hazards()
	_game.effect_manager.clear_effects()
	GameManager.boss_active = false
	_game.player.global_position = _game.flight_space.screen_to_combat_plane(get_viewport().get_visible_rect().size * Vector2(0.5, 0.82))
	_game.player.velocity = Vector3.ZERO
	await _frames(3)

func _pressure(stage: String, wave: int, seconds: float) -> void:
	await _clear_field()
	_stage = stage
	GameManager.current_wave = wave
	_game.hud.update_all()
	_game.encounters.threat.set_generation(4)
	await _sample_stage(seconds)

func _boss_pressure(boss_id: StringName) -> void:
	await _clear_field()
	_stage = "boss_" + str(boss_id)
	if not _game.encounters.dev_spawn_boss_variant(boss_id):
		_fail("Could not schedule boss: " + str(boss_id))
		return
	var timeout := Time.get_ticks_msec() + 10000
	while get_tree().get_nodes_in_group(&"native_3d_bosses").is_empty():
		if Time.get_ticks_msec() > timeout:
			_fail("Boss spawn timed out.")
			return
		await get_tree().process_frame
	_boss = get_tree().get_first_node_in_group(&"native_3d_bosses")
	var profile: Resource = _boss._boss_ai.profile.duplicate()
	profile.selection_seed = int(_config.seed) + BOSSES.find(boss_id) + 1
	_boss._boss_ai.profile = profile
	_boss._boss_ai.selector.configure(profile)
	_boss._boss_ai.attack_committed.connect(_record_boss_attack)
	# Hold a real boss in its third phase while its real AI/ordnance runs.
	# High HP is a fixture, preventing the automated build from ending the stage.
	_boss.max_health = 100000000
	_boss._health.configure(_boss.max_health, _boss._health.phase_two_threshold, _boss._health.phase_three_threshold)
	_boss._health.apply_damage(80000000)
	await _sample_stage(float(_config.seconds))

func _record_boss_attack(attack_id: StringName) -> void:
	_boss_attacks.append({"id": str(attack_id), "simulation_seconds": _sim_seconds})

func _sample_stage(seconds: float) -> void:
	seed(int(_config.seed) + ["late_generation", "boss_assault", "boss_bulwark", "boss_tempest", "boss_core", "boss_harbinger", "endless"].find(_stage))
	_sim_seconds = 0.0
	_refill_at = 0.0
	_driving = true
	Input.action_press("shoot")
	_sampler.begin()
	await _duration(float(_config.warmup_seconds))
	var warmup: Dictionary = _sampler.finish()
	if _failed:
		return
	warmup.merge({"cycle": _cycle, "name": _stage, "simulation_seconds": _sim_seconds})
	_emit("warmup", warmup)
	var start_sim := _sim_seconds
	_sampler.begin()
	await _duration(seconds)
	var samples: Dictionary = _sampler.finish()
	if _failed:
		return
	if samples.frame_intervals_ms.size() < 2 or (is_instance_valid(_boss) and _boss.phase != 2):
		_fail("Stage did not produce its required workload: " + _stage)
		return
	samples.merge({"cycle": _cycle, "name": _stage, "simulation_seconds": _sim_seconds - start_sim, "wave": GameManager.current_wave, "boss_phase": _boss.phase if is_instance_valid(_boss) else null, "boss_attacks": _boss_attacks.duplicate(true), "boss_selection_seed": _boss._boss_ai.profile.selection_seed if is_instance_valid(_boss) else null})
	_emit("stage", samples)
	_driving = false
	if _cycle == 0 and _stage == "late_generation" and DisplayServer.get_name() != "headless" and not str(_config.capture_path).is_empty():
		RenderingServer.force_draw(false)
		var error := get_viewport().get_texture().get_image().save_png(str(_config.capture_path))
		if error != OK:
			_fail("Could not save the workload capture.")

func _duration(seconds: float) -> void:
	var until := _sim_seconds + seconds
	var deadline := Time.get_ticks_msec() + int(maxf(30.0, seconds * 20.0) * 1000.0)
	while _sim_seconds < until:
		if get_tree().paused or not GameManager.is_game_active or Time.get_ticks_msec() > deadline:
			_fail("Benchmark paused, ended, or timed out in " + _stage + ".")
			return
		await get_tree().process_frame

func _physics_process(delta: float) -> void:
	if not _driving or _failed:
		return
	_sim_seconds += delta
	var motion := Vector2(sin(_sim_seconds * 0.7), cos(_sim_seconds * 0.9))
	for axis: Array in [["move_left", -motion.x], ["move_right", motion.x], ["move_up", -motion.y], ["move_down", motion.y]]:
		if float(axis[1]) > 0.0:
			Input.action_press(str(axis[0]), float(axis[1]))
		else:
			Input.action_release(str(axis[0]))
	_game.player.last_aim_direction = (Vector3(0, 0, -15) - _game.player.global_position).normalized()
	_game.player.is_using_free_aim = true
	if _sim_seconds >= _refill_at:
		_refill_at += 1.0
		_refill_workload()

func _refill_workload() -> void:
	if not GameManager.boss_active:
		for index in ROLES.size():
			var count := 0
			for actor: Node in get_tree().get_nodes_in_group(&"native_3d_regular_enemies"):
				if actor.archetype_id == ROLES[index]:
					count += 1
			while count < 2:
				var actor: Node = _game.encounters.dev_spawn_archetype(ROLES[index])
				if actor == null:
					break
				var screen := Vector2(0.15 + index * 0.17, 0.15 + count * 0.18) * get_viewport().get_visible_rect().size
				actor.global_position = _game.flight_space.screen_to_combat_plane(screen)
				actor.health = 1000000
				count += 1
	var position: Vector3 = _game.player.global_position + Vector3(4, 0, -8)
	_game.hazard_manager.spawn_mine(position, true, true)
	_game.hazard_manager.spawn_seeker_fragment(position, Vector3.BACK)
	_game.hazard_manager.spawn_plasma_field(position + Vector3(-8, 0, 0))

func _release_input() -> void:
	for action: String in InputBindings.ACTIONS:
		Input.action_release(action)

func _frames(count: int) -> void:
	for frame in count:
		await get_tree().process_frame

func _emit(kind: String, payload: Dictionary) -> void:
	print("PERFORMANCE_EVENT " + JSON.stringify({"version": 1, "kind": kind, "payload": payload}))

func _fail(message: String) -> void:
	_failed = true
	_driving = false
	_release_input()
	_emit("failure", {"message": message, "stage": _stage, "simulation_seconds": _sim_seconds,
		"paused": get_tree().paused, "window_focused": get_window().has_focus(), "game_active": GameManager.is_game_active,
		"pause_overlay": is_instance_valid(_game) and is_instance_valid(_game._pause_overlay),
		"run_overlay": is_instance_valid(_game) and is_instance_valid(_game._run_overlay)})
	get_tree().quit(1)
