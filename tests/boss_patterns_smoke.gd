extends Native3DGameplay
## Exercise committed volleys against the real pooled projectile system.
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
		_expect(boss.activate_generation(flight_space, Vector3.ZERO, Vector3.BACK, 1), "Boss activates")
		boss.set_physics_process(false)
		boss._arena_patterns.set_physics_process(false)
		for phase in 3:
			boss.phase = phase
			for section in boss._sections:
				if variant > 0:
					section.activate(100)
			var label := "%s phase %d" % [Boss.TITLES[variant], phase + 1]
			var primary := await _exercise_attack(boss, false)
			_expect(not _shots.is_empty(), label + " fires its primary projectile pattern")
			if phase == 2:
				var alternate := await _exercise_attack(boss, true)
				var healthy := _shots.size()
				_expect(primary != alternate, label + " gains a distinct projectile pattern")
				var speeds: Array[float] = []
				for shot in _shots:
					if not speeds.has(float(shot.speed)):
						speeds.append(float(shot.speed))
				speeds.sort()
				_expect(speeds.size() >= 2 and is_equal_approx(speeds.front(), 526.5) and is_equal_approx(speeds.back(), 1111.5), label + " preserves fast/slow speed tuning exactly once")
				if variant > 0:
					boss._sections[0].take_damage(99999)
					await _exercise_attack(boss, true)
					var one_pod := _shots.size()
					boss._sections[1].take_damage(99999)
					await _exercise_attack(boss, true)
					_expect(one_pod < healthy and _shots.size() < one_pod and not _shots.is_empty(), label + " loses fire with each pod but retains core attacks")
			await _check_arena(boss, label)
		boss._before_finish(BasicEnemy.FinishReason.ESCAPED, boss.global_position)
		boss.queue_free()
		await _clear_field()
	var metrics := projectile_manager.get_metrics()
	_expect(int(metrics.enemy.pool_growth_after_warmup) == 0 and int(metrics.enemy.rejected_shots) == 0, "Sequences fit the warmed enemy pool")
	GameManager.is_game_active = false
	for failure in _failures:
		push_error(failure)
	print("BOSS_PATTERNS_SMOKE_PASS" if _failures.is_empty() else "BOSS_PATTERNS_SMOKE_FAIL")
	get_tree().quit(0 if _failures.is_empty() else 1)

func _exercise_attack(boss: Boss, alternate: bool) -> String:
	await _clear_field()
	boss._boss_ai.executor.cancel()
	# Use an offset origin to catch accidentally treating a child Node3D as world zero.
	boss.global_position = flight_space.screen_motion_to_combat(Vector2(-170, -110))
	player.global_position = boss.global_position + flight_space.screen_motion_to_combat(Vector2(0, 420))
	var plan := BossAttackPlan.new()
	plan.configure(boss._boss_ai.profile.attacks[3 if alternate else 2], boss._boss_ai.profile, boss.phase)
	plan.aim = Vector2.DOWN
	plan.target_position = player.global_position
	plan.sequence = 1
	boss._boss_ai.movement.hold(&"attack")
	boss._boss_ai.executor.begin(plan)
	boss._boss_ai.executor.advance(plan.warning_seconds - 0.01, player)
	_expect(_shots.is_empty(), "Entire projectile warning precedes damage")
	var origin := boss.global_position
	player.global_position += flight_space.screen_motion_to_combat(Vector2(400, 0))
	boss._boss_ai.executor.advance(0.02, player)
	for beat in 8:
		boss._boss_ai.executor.advance(2.1, player)
		if not boss._boss_ai.executor.active:
			break
	_expect(not boss._boss_ai.executor.active and plan.aim == Vector2.DOWN, "Sequence finishes with the committed aim")
	_expect(boss.global_position.is_equal_approx(origin), "Volley holds its advertised origin")
	_expect(boss._boss_ai.patterns.global_position.is_equal_approx(origin), "Projectile geometry follows its boss's world origin")
	if boss.variant == 0:
		for shot in _shots:
			var direction := flight_space.combat_motion_to_screen(shot.direction).normalized()
			_expect(absf(boss._boss_ai.patterns._commander_escape_direction().angle_to(direction)) >= 0.219, "Every Commander layer preserves its sidestep corridor")
	var pods_live := boss._sections.size() >= 2 and boss._sections[0].is_active and boss._sections[1].is_active
	if boss.variant == 1 and pods_live:
		var across: Vector2 = plan.aim.orthogonal()
		var lateral_span := 0.0
		for shot in _shots:
			var shot_origin: Vector3 = shot.origin
			var offset := flight_space.combat_motion_to_screen(shot_origin - origin)
			lateral_span = maxf(lateral_span, absf(offset.dot(across)))
		_expect(_shots.size() >= 14, "Bulwark wall fills a dense lane set")
		_expect(lateral_span >= 340.0, "Bulwark wall spans a front too wide to strafe clear")
	var signature: Array[String] = []
	for shot in _shots:
		signature.append("%s:%s:%s" % [shot.direction, shot.speed, shot.motion])
	return "|".join(signature)

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
