extends Native3DGameplay
## Exercise real pooled shots and the boss scheduler in a non-banking session.
const BossScene := preload("res://entities/enemies/boss_enemy_3d.tscn")
const Boss := preload("res://entities/enemies/boss_enemy_3d.gd")
const EnemyTuning := preload("res://entities/projectiles/enemy_projectile_tuning.gd")
var _failures: Array[String] = []
var _shots: Array[Dictionary] = []

func _ready() -> void:
	await super._ready()
	_run.call_deferred()

func _run() -> void:
	player.set_physics_process(false)
	player.set_dev_god_mode(true)
	GameManager.boss_active = true
	flight_space._physics_process(0.0)
	projectile_manager.projectile_fired.connect(_record_shot)
	await _check_projectile_speeds()
	for variant in 5:
		var boss := BossScene.instantiate() as Boss
		actors_root.add_child(boss)
		boss.dev_variant_override = variant
		GameManager.current_wave = 5 * (variant + 1)
		_expect(boss.activate_generation(flight_space, Vector3.ZERO, Vector3.BACK, 1), "Boss activates")
		_expect(is_zero_approx(boss._ram_cooldown), "A new boss encounter starts with its charge available")
		boss.set_physics_process(false)
		boss._arena_patterns.set_physics_process(false)
		_check_pursuit(boss)
		for phase in 3:
			boss.phase = phase
			for section in boss._sections:
				if variant > 0:
					section.activate(100)
			var label := "%s phase %d" % [Boss.TITLES[variant], phase + 1]
			var signature := await _exercise_attack(boss, true)
			var healthy_count := _shots.size()
			_expect(healthy_count > 0, label + " releases its mixup")
			var speeds: Array[float] = []
			for shot in _shots:
				if not speeds.has(float(shot.speed)):
					speeds.append(float(shot.speed))
			speeds.sort()
			_expect(speeds.size() >= 2 and speeds.back() > speeds.front() * 1.8, label + " mixes clearly slow and fast shots")
			_expect(is_equal_approx(speeds.front(), 526.5) and is_equal_approx(speeds.back(), 1111.5), label + " applies the telegraph speed increase once to both layers")
			var primary_signature := await _exercise_attack(boss, false)
			_expect(signature != primary_signature, label + " adds a different formation or motion rule")
			if variant > 0:
				boss._sections[0].take_damage(99999)
				await _exercise_attack(boss, true)
				var one_pod_count := _shots.size()
				boss._sections[1].take_damage(99999)
				await _exercise_attack(boss, true)
				_expect(one_pod_count < healthy_count and _shots.size() < one_pod_count and not _shots.is_empty(), label + " loses fire with each pod but retains core attacks")
			await _check_arena(boss, label)
			await _check_transition(boss, label)
		_check_rotation(boss)
		if variant == 0:
			await _check_ram_cooldown(boss)
		boss._before_finish(BasicEnemy.FinishReason.ESCAPED, boss.global_position)
		boss.queue_free()
		await _clear_field()
	var metrics := projectile_manager.get_metrics()
	_expect(int(metrics.enemy.pool_growth_after_warmup) == 0 and int(metrics.enemy.rejected_shots) == 0, "All sequences fit the warmed enemy pool")
	GameManager.is_game_active = false
	for failure in _failures:
		push_error(failure)
	print("BOSS_PATTERNS_SMOKE_PASS" if _failures.is_empty() else "BOSS_PATTERNS_SMOKE_FAIL")
	get_tree().quit(0 if _failures.is_empty() else 1)

func _check_pursuit(boss: Boss) -> void:
	var label: String = Boss.TITLES[boss.variant]
	boss._phase_transition = 0.0
	boss._volley_timer = 120.0
	player.velocity = Vector3.ZERO
	for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		boss.global_position = Vector3.ZERO
		boss.velocity = Vector3.ZERO
		player.global_position = flight_space.screen_motion_to_combat(direction * 650.0)
		for step in 60:
			boss._advance_movement(1.0 / 60.0)
		var distance := flight_space.combat_motion_to_screen(player.global_position - boss.global_position).length()
		_expect(distance < 550.0, label + " approaches the player from every direction")
		# Reverse the target while already flying: stale waypoints must not win.
		player.global_position = -player.global_position
		var before := flight_space.combat_motion_to_screen(player.global_position - boss.global_position).length()
		for step in 60:
			boss._advance_movement(1.0 / 60.0)
		distance = flight_space.combat_motion_to_screen(player.global_position - boss.global_position).length()
		_expect(distance < before - 60.0, label + " turns back when the player changes sides")
	# Compare the same approach with and without lateral player motion.
	boss.global_position = Vector3.ZERO
	boss.velocity = Vector3.ZERO
	player.global_position = flight_space.screen_motion_to_combat(Vector2(0, 650))
	boss._advance_movement(0.1)
	var stationary_step := flight_space.combat_motion_to_screen(boss.global_position)
	boss.global_position = Vector3.ZERO
	boss.velocity = Vector3.ZERO
	player.velocity = flight_space.screen_motion_to_combat(Vector2(280, 0))
	boss._advance_movement(0.1)
	_expect(flight_space.combat_motion_to_screen(boss.global_position).x > stationary_step.x, label + " leads a moving player")
	player.velocity = Vector3.ZERO
	boss.global_position = Vector3.ZERO
	boss.velocity = Vector3.ZERO
	player.global_position = flight_space.screen_motion_to_combat(Vector2(0, 340))
	for step in 180:
		boss._advance_movement(1.0 / 60.0)
	var orbit_step := flight_space.combat_motion_to_screen(boss.global_position)
	_expect(absf(orbit_step.x) > 60.0, label + " keeps flying around a nearby player")
	_expect(flight_space.combat_motion_to_screen(player.global_position - boss.global_position).length() > 200.0, label + " leaves room to dodge while circling")
	var bounds := flight_space.get_combat_bounds()
	for corner in [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]:
		boss.global_position = Vector3(corner.x, 0, corner.y)
		boss.velocity = Vector3.ZERO
		player.global_position = Vector3.ZERO
		var start := boss.global_position
		boss._advance_movement(1.0 / 60.0)
		_expect(flight_space.combat_motion_to_screen(boss.global_position - start).length() <= 4.01, label + " flies smoothly back from the arena edge")
		for step in 120:
			boss._advance_movement(1.0 / 60.0)
		_expect(bounds.has_point(Vector2(boss.global_position.x, boss.global_position.z)), label + " stays inside the arena")
		_expect(flight_space.combat_motion_to_screen(boss.global_position - start).length() > 150.0, label + " leaves corners to pursue the player")
	var position := boss.global_position
	player.remove_from_group(&"player_craft")
	boss._advance_movement(0.1)
	_expect(boss.global_position.is_equal_approx(position) and boss.velocity.is_zero_approx(), label + " waits safely when the player is absent")
	player.add_to_group(&"player_craft")

func _check_ram_cooldown(boss: Boss) -> void:
	await _clear_field()
	boss._begin_phase_transition()
	boss.phase = 0
	boss._phase_transition = 0.0
	boss._volley_timer = 0.0
	boss._ram_cooldown = 0.0
	boss.global_position = Vector3.ZERO
	player.global_position = flight_space.screen_motion_to_combat(Vector2(0, 500))
	var charge_starts: Array[float] = []
	var elapsed := 0.0
	var volleys_during_cooldown := 0
	var resumed_flight := false
	for step in 4200:
		var was_primed := boss._ram_primed
		var previous_pattern := boss._pattern_index
		var previous_position := boss.global_position
		boss._advance_movement(1.0 / 60.0)
		elapsed += 1.0 / 60.0
		if boss._ram_primed and not was_primed:
			charge_starts.append(elapsed)
			_expect(is_equal_approx(boss._ram_cooldown, 25.0), "Commander starts a 25-second cooldown with each charge warning")
			var held_cooldown := boss._ram_cooldown
			GameManager.is_game_active = false
			boss._physics_process(10.0)
			_expect(is_equal_approx(boss._ram_cooldown, held_cooldown), "Charge cooldown freezes outside active gameplay")
			GameManager.is_game_active = true
		if boss._pattern_index > previous_pattern and boss._ram_cooldown > 0.0:
			volleys_during_cooldown += 1
		if boss._ram_cooldown > 0.0 and boss._ram_time <= 0.0 and boss._ram_recovery <= 0.0 and not boss._ram_primed:
			resumed_flight = resumed_flight or not boss.global_position.is_equal_approx(previous_position)
		if step == 30:
			_expect(boss._ram_primed, "First Commander charge has its full windup")
			var held_cooldown := boss._ram_cooldown
			boss._begin_phase_transition()
			_expect(not boss._ram_primed and is_equal_approx(boss._ram_cooldown, held_cooldown), "A health phase cancels the ram without refunding its cooldown")
		if step % 60 == 0:
			await _clear_field()
	_expect(charge_starts.size() >= 3, "Commander charges again after cooldown expires")
	for index in range(1, charge_starts.size()):
		_expect(charge_starts[index] - charge_starts[index - 1] >= 25.0, "Commander never charges twice within 25 seconds")
	_expect(volleys_during_cooldown >= 3 and resumed_flight, "Commander flies and fires regular volleys while charge cools down")
	await _clear_field()

func _check_projectile_speeds() -> void:
	player.global_position = flight_space.screen_motion_to_combat(Vector2(0, 500))
	projectile_manager.fire_enemy_projectile(Vector3.ZERO, Vector3.BACK)
	projectile_manager.fire_enemy_projectile(Vector3.ZERO, Vector3.BACK, EnemyTuning.SLOW_SPEED)
	projectile_manager.fire_enemy_projectile(Vector3.ZERO, Vector3.BACK, EnemyTuning.FAST_SPEED)
	var shots := get_tree().get_nodes_in_group(&"enemy_projectiles")
	_expect(shots.size() == 3, "Default and explicit enemy shots spawn")
	var measured: Array[float] = []
	for shot: Projectile in shots:
		measured.append(flight_space.combat_motion_to_screen(shot.velocity).length())
	measured.sort()
	_expect(measured.size() == 3 and is_equal_approx(measured[0], 234.0) and is_equal_approx(measured[1], 494.0) and is_equal_approx(measured[2], 520.0), "Global 30% increase applies exactly once, including explicit speeds")
	projectile_manager.fire_player_projectile(Vector3.ZERO, Vector3.FORWARD)
	var player_shots := get_tree().get_nodes_in_group(&"player_projectiles")
	_expect(not player_shots.is_empty() and is_equal_approx(flight_space.combat_motion_to_screen(player_shots.back().velocity).length(), WeaponTuning.PROJECTILE_SPEED), "Player projectile speed stays at its weapon tuning")
	await _clear_field()
	for motion in [Projectile.Motion.STOP_RELEASE, Projectile.Motion.RETURNING]:
		projectile_manager.fire_telegraphed_enemy_projectile(Vector3.ZERO, Vector3.RIGHT, EnemyTuning.FAST_SPEED, motion)
		var shot := get_tree().get_first_node_in_group(&"enemy_projectiles") as Projectile
		if shot == null:
			_expect(false, "Motion test shot spawns")
			continue
		shot.set_physics_process(false)
		for step in 120:
			shot._advance_enemy_motion(1.0 / 60.0)
			shot.global_position += shot.velocity / 60.0
			if step == 59:
				_expect(shot.velocity.length() < 0.01, "Fast motion retains its suspended warning beat")
		if motion == Projectile.Motion.RETURNING:
			_expect(flight_space.combat_motion_to_screen(shot.global_position).length() < 0.1, "Fast returning shot retraces its origin")
		else:
			_expect(is_equal_approx(flight_space.combat_motion_to_screen(shot.velocity).length(), 1111.5 * 1.35), "Parked telegraphed shot releases at its intended faster speed")
		_expect(shot.deflect(player.global_position, Vector3.ZERO), "Mixed-speed shots remain reflectable")
		_expect(shot.is_deflected and shot.enemy_motion == Projectile.Motion.STRAIGHT, "Reflection exits scripted motion")
		await _clear_field()

func _exercise_attack(boss: Boss, mixup: bool) -> String:
	await _clear_field()
	boss._clear_echo_marks()
	boss._cancel_ram()
	boss._cancel_core_weapon()
	boss.global_position = Vector3.ZERO
	player.global_position = flight_space.screen_motion_to_combat(Vector2(0, 420))
	boss._phase_transition = 0.0
	boss._warning_timer = 0.0
	boss._burst_remaining = 0
	boss._volley_timer = 0.0
	boss._volley_index = 1
	boss._pattern_index = 1 if mixup else 0
	boss._advance_movement(0.001)
	_expect(boss._warning_timer >= 0.9 and _shots.is_empty(), "Pattern windup precedes damage")
	_expect(boss._attack_mixup == mixup, "Scheduler selects the requested attack family")
	var locked_aim := boss._locked_aim
	var locked_origin := boss.global_position
	var flight_time: float = boss._flight_ai.get_debug_state().flight_time
	player.global_position += flight_space.screen_motion_to_combat(Vector2(250, 0))
	boss._advance_movement(boss._warning_timer + 0.01)
	_release_echoes(boss)
	for beat in (1 + boss.phase):
		boss._advance_movement(boss._burst_delay() + 0.01)
		_release_echoes(boss)
	_expect(boss._burst_remaining == 0 and boss._locked_aim.is_equal_approx(locked_aim), "Whole sequence finishes without retargeting after its warning")
	_expect(boss.global_position.is_equal_approx(locked_origin), "Pursuit holds the advertised origin throughout the warning and volley")
	_expect(boss._flight_ai.get_debug_state().held and is_equal_approx(float(boss._flight_ai.get_debug_state().flight_time), flight_time), "Attack sequence suspends the flight orchestrator without skipping its maneuver")
	if boss.variant == 0:
		for shot in _shots:
			var direction := flight_space.combat_motion_to_screen(shot.direction).normalized()
			_expect(absf(boss._commander_escape_direction().angle_to(direction)) >= 0.219, "Every Commander layer preserves its sidestep corridor")
	var signature: Array[String] = []
	for shot in _shots:
		signature.append("%s:%s:%s" % [shot.direction, shot.speed, shot.motion])
	return "|".join(signature)

func _release_echoes(boss: Boss) -> void:
	if boss.variant != 3:
		return
	var position := player.global_position
	player.global_position += flight_space.screen_motion_to_combat(Vector2(500, 0))
	boss._update_echo_marks(2.1)
	player.global_position = position

func _check_arena(boss: Boss, label: String) -> void:
	await _clear_field()
	var arena := boss._arena_patterns
	arena.reset_patterns()
	arena._plan_pattern()
	_expect(not arena.pending.is_empty(), label + " schedules arena pressure")
	var minimum := INF
	var maximum := 0.0
	for event in arena.pending:
		_expect(float(event.time) >= 1.8, label + " warns before arena release")
		if not bool(event.trap):
			minimum = minf(minimum, float(event.speed_scale))
			maximum = maxf(maximum, float(event.speed_scale))
		var previous_count := _shots.size()
		arena._release(event)
		if not bool(event.trap) and _shots.size() > previous_count:
			var base_speed := 325.0 if boss.variant in [0, 1, 3] else 260.0
			_expect(is_equal_approx(float(_shots.back().speed), base_speed * float(event.speed_scale) * 1.3 * 2.25), label + " launches its line-marked arena shots at the faster speed")
	_expect(maximum > minimum * 1.5 and not _shots.is_empty(), label + " releases mixed-speed arena layers")
	arena.reset_patterns()
	_expect(arena.pending.is_empty() and arena.safe_routes.is_empty() and arena.sequence == 0, label + " resets queued arena layers")

func _check_transition(boss: Boss, label: String) -> void:
	boss._pattern_index = 3
	boss._attack_mixup = true
	boss._burst_remaining = 2
	boss._arena_patterns._plan_pattern()
	boss._begin_phase_transition()
	_expect(boss._burst_remaining == 0 and boss._warning_timer == 0.0 and boss._pattern_index == 0 and not boss._attack_mixup, label + " cancels old attack scheduling")
	_expect(boss._echo_marks.is_empty() and boss._arena_patterns.pending.is_empty() and boss._siege_mines.is_empty(), label + " clears delayed attacks and mines")
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(get_tree().get_nodes_in_group(&"enemy_projectiles").is_empty(), label + " clears the projectile field")
	_shots.clear()
	boss._advance_movement(1.0)
	_expect(_shots.is_empty(), label + " leaves a phase-transition breathing window")

func _check_rotation(boss: Boss) -> void:
	boss._begin_phase_transition()
	boss.phase = 0
	boss._phase_transition = 0.0
	boss._volley_timer = 0.0
	boss.global_position = Vector3.ZERO
	player.global_position = flight_space.screen_motion_to_combat(Vector2(0, 420))
	var patterns: Array[bool] = []
	for step in 2400:
		var previous := boss._pattern_index
		boss._advance_movement(1.0 / 60.0)
		if boss._pattern_index != previous:
			patterns.append(boss._attack_mixup)
			if patterns.size() >= 3:
				break
	_expect(patterns == [false, true, false], Boss.TITLES[boss.variant] + " alternates patterns even across rams and beam charges")

func _record_shot(kind: Projectile.Kind, origin: Vector3, direction: Vector3, speed: float) -> void:
	if kind != Projectile.Kind.ENEMY:
		return
	var active := get_tree().get_nodes_in_group(&"enemy_projectiles")
	var shot := active.back() as Projectile
	_shots.append({"origin": origin, "direction": direction, "speed": speed, "motion": shot.enemy_motion})
	# Test sequences advance the boss explicitly, so keep projectile observations
	# deterministic between awaited pool returns.
	shot.set_physics_process(false)

func _clear_field() -> void:
	projectile_manager.clear_projectiles()
	hazard_manager.clear_hazards()
	await get_tree().process_frame
	await get_tree().process_frame
	_shots.clear()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
