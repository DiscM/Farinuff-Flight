extends Native3DGameplay
## Defensive-build, opening-admission and opt-in wave measurement contracts.
const Director := preload("res://systems/native_encounter_director.gd")
const Metrics := preload("res://systems/opening_metrics.gd")
var _failures: Array[String] = []

func _ready() -> void:
	await super._ready()
	_run.call_deferred()

func _run() -> void:
	player.set_physics_process(false)
	GameManager.practice_mode = false
	_check_armor()
	await _check_opening()
	await _check_metrics()
	for failure in _failures:
		push_error(failure)
	print("REFLECTION_MASTERY_SMOKE_PASS" if _failures.is_empty() else "REFLECTION_MASTERY_SMOKE_FAIL")
	get_tree().quit(0 if _failures.is_empty() else 1)

func _reflect(count: int) -> void:
	for shot in count:
		player.register_boost_reflection()

func _check_armor() -> void:
	GameManager.lives = 3
	player.set_elite_upgrade_enabled("hull_plating", true, true)
	_expect(GameManager.lives == 4 and not player.armor_guard_ready, "Plating grants its life but requires reflection to charge armor")
	player._begin_boost()
	_reflect(2)
	_expect(not player.armor_guard_ready, "Two reflections cannot charge a guard")
	_reflect(1)
	_expect(player.armor_guard_ready and player.shield_visual.visible, "Third reflection charges a visible guard")
	hud._sync_power_up_timers()
	_expect(hud._effect_chips.has(&"armor"), "Charged armor has an explicit HUD state")
	_reflect(1)
	player._apply_shield()
	player.receive_damage(player.global_position, PlayerCraft.DamageSource.ENEMY_PROJECTILE)
	_expect(not player.has_shield and player.armor_guard_ready and GameManager.lives == 4, "Pickup shield is spent before armor")
	player.receive_damage(player.global_position, PlayerCraft.DamageSource.ENEMY_CONTACT)
	_expect(player.armor_guard_ready, "Invulnerable overlap cannot consume a second guard")
	player.reset_damage_state()
	player.receive_damage(player.global_position, PlayerCraft.DamageSource.HOSTILE_ORDNANCE, 3)
	_expect(not player.armor_guard_ready and GameManager.lives == 4, "One guard blocks one damage event, including a multi-life blast")
	_expect(GameManager.run_insights.armor_saves == 1 and GameManager.run_insights.hits_taken == 0, "Armor save is recorded separately from hull damage")
	_reflect(1)
	_expect(not player.armor_guard_ready, "Further shots in the same boost cannot refill spent armor")
	player._begin_boost()
	_reflect(3)
	_expect(player.armor_guard_ready, "A new successful boost can recharge armor")
	player.reset_power_up_state()
	_expect(player.armor_guard_ready and player.shield_visual.visible, "Temporary pickup reset preserves the installed armor")
	player.set_elite_upgrade_enabled("hull_plating", false)
	_expect(not player.armor_guard_ready and not player.shield_visual.visible, "Removing plating removes its guard and visual")
	player._begin_boost()
	_reflect(3)
	_expect(not player.armor_guard_ready, "Uninstalled armor cannot recharge")
	player.is_boosting = false
	player.reset_damage_state()

func _check_opening() -> void:
	GameManager.current_wave = 3
	GameManager.run_insights.reflections = 0
	var director := Director.new()
	add_child(director)
	director.configure(self)
	director.set_physics_process(false)
	director.started = true
	director._on_wave_started(3)
	_expect(director._opening_reflection_remaining > 0.0, "Wave 3 schedules an introductory firing opportunity")
	_expect(director._try_opening_reflection(), "Opening encounter consumes an ordinary spawn slot")
	var enemies := get_tree().get_nodes_in_group(&"native_3d_regular_enemies")
	_expect(enemies.size() == 1 and enemies[0] is TankEnemy3D, "Opening uses exactly one production tank")
	if not enemies.is_empty():
		var tank := enemies[0] as TankEnemy3D
		tank.set_physics_process(false)
		tank._fire_radial_burst()
		_expect(hud._reflection_hint.visible, "Actual tank volley reveals the contextual reflection cue")
		tank.queue_free()
	projectile_manager.clear_projectiles()
	var remaining: float = hud._reflection_hint_remaining
	get_tree().paused = true
	hud._process(2.0)
	_expect(is_equal_approx(hud._reflection_hint_remaining, remaining), "Paused time does not consume the teaching cue")
	get_tree().paused = false
	GameManager.run_insights.reflections = 1
	hud._process(0.1)
	_expect(not hud._reflection_hint.visible, "First success dismisses the teaching cue")
	director._on_wave_started(3)
	_expect(is_zero_approx(director._opening_reflection_remaining), "Repeated start does not queue a second teaching tank")
	await get_tree().process_frame
	# Fill the active cap without spawning attacks: admission must still win.
	var blockers: Array[Node] = []
	for index in 12:
		var blocker := Node.new()
		add_child(blocker)
		blocker.add_to_group(&"native_3d_regular_enemies")
		blockers.append(blocker)
	director._opening_reflection_remaining = 8.0
	director._try_opening_reflection()
	_expect(get_tree().get_nodes_in_group(&"native_3d_regular_enemies").size() == 12, "Teaching encounter never bypasses threat admission")
	director._physics_process(9.0)
	_expect(is_zero_approx(director._opening_reflection_remaining), "Blocked teaching encounter expires rather than accumulating")
	director._on_wave_started(4)
	_expect(is_zero_approx(director._opening_reflection_remaining), "Wave transition cancels pending teaching")
	for blocker in blockers:
		blocker.queue_free()
	director.queue_free()
	await get_tree().process_frame

func _check_metrics() -> void:
	var metrics := Metrics.new()
	add_child(metrics)
	metrics.start(self)
	metrics.set_process(false)
	metrics._record_wave_started(3)
	var start_hits := GameManager.run_insights.hits_taken
	GameManager.run_insights.hits_taken += 2
	GameManager.run_insights.armor_saves += 1
	metrics._active_seconds += 12.5
	var detail := metrics.wave_detail(3)
	_expect(detail.hits_taken == 2 and detail.armor_saves == 1 and detail.wave_active_seconds == 12.5, "Wave metrics record deltas rather than lifetime totals")
	metrics._record_wave_started(4)
	_expect(metrics.wave_detail(4).hits_taken == 0, "New wave establishes a clean measurement baseline")
	get_tree().paused = true
	metrics._process(5.0)
	_expect(metrics.wave_detail(4).wave_active_seconds == 0.0, "Paused overlay time stays out of wave duration")
	get_tree().paused = false
	player.set_dev_god_mode(true)
	metrics._record("assistance_probe")
	_expect(metrics._developer_assisted, "Assistance is marked even before the next process frame")
	player.set_dev_god_mode(false)
	metrics.queue_free()
	await get_tree().process_frame
	GameManager.run_insights.hits_taken = start_hits

func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
