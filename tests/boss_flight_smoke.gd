extends Native3DGameplay
## Behavioral contracts for BossMovementBrain: CHASE, STRAFE and DODGE flight,
## arena safety, and constant motion across every hull and health phase.
const BossScene := preload("res://entities/enemies/boss_enemy_3d.tscn")
const Boss := preload("res://entities/enemies/boss_enemy_3d.gd")
const Movement := preload("res://systems/boss_movement_brain.gd")
const STEP := 1.0 / 60.0
var _failures: Array[String] = []


func _ready() -> void:
	await super._ready()
	_run.call_deferred()


func _run() -> void:
	player.set_physics_process(false)
	player.set_dev_god_mode(true)
	GameManager.boss_active = true
	flight_space._physics_process(0.0)
	var signatures: Array[String] = []
	for variant in 5:
		var boss := BossScene.instantiate() as Boss
		actors_root.add_child(boss)
		boss.dev_variant_override = variant
		_expect(boss.activate_generation(flight_space, Vector3.ZERO, Vector3.BACK, 1), "Boss flight activates")
		boss.set_physics_process(false)
		boss._arena_patterns.set_physics_process(false)
		for phase in 3:
			_reset(boss, phase)
			var signature := _check_strafe(boss)
			if phase == 0:
				_expect(not signatures.has(signature), "Each boss strafes a distinct ring")
				signatures.append(signature)
			_check_chase(boss)
			_check_dodge(boss)
			_check_arena_edges(boss)
		boss._before_finish(BasicEnemy.FinishReason.ESCAPED, boss.global_position)
		_expect(
			boss._boss_ai.movement.steer(STEP, boss.global_position, Vector3.ONE, player.global_position, player.global_position, boss.phase).is_zero_approx(),
			"Finished boss movement stays inactive"
		)
		boss.queue_free()
		await get_tree().process_frame
	GameManager.is_game_active = false
	for failure in _failures:
		push_error(failure)
	print("BOSS_FLIGHT_SMOKE_PASS" if _failures.is_empty() else "BOSS_FLIGHT_SMOKE_FAIL")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _reset(boss: Boss, phase: int) -> void:
	boss.phase = phase
	boss._boss_ai.movement.configure(flight_space, boss.variant)
	boss._boss_ai.movement.begin_phase(phase)
	boss._boss_ai.movement.release_hold(&"test")
	boss._boss_ai.movement.mode = Movement.Mode.STRAFE
	boss.global_position = flight_space.screen_motion_to_combat(Vector2(0, -340))
	boss.velocity = Vector3.ZERO
	player.global_position = Vector3.ZERO
	player.velocity = Vector3.ZERO


func _step(boss: Boss) -> void:
	boss.velocity = boss._boss_ai.movement.steer(
		STEP, boss.global_position, boss.velocity,
		player.global_position, player.global_position, boss.phase
	)
	boss.global_position += boss.velocity * STEP


func _check_strafe(boss: Boss) -> String:
	_reset(boss, boss.phase)
	boss._boss_ai.movement.mode = Movement.Mode.STRAFE
	var label := "%s phase %d" % [Boss.TITLES[boss.variant], boss.phase + 1]
	var trace: Array[String] = []
	var distance_flown := 0.0
	var minimum_distance := INF
	var maximum_speed := 0.0
	var still_ticks := 0
	for tick in 900:
		var previous := boss.global_position
		_step(boss)
		var moved := flight_space.combat_motion_to_screen(boss.global_position - previous).length()
		distance_flown += moved
		if moved < 0.2:
			still_ticks += 1
		minimum_distance = minf(
			minimum_distance,
			flight_space.combat_motion_to_screen(boss.global_position - player.global_position).length()
		)
		maximum_speed = maxf(maximum_speed, flight_space.combat_motion_to_screen(boss.velocity).length())
		if tick % 45 == 0:
			var point := flight_space.combat_motion_to_screen(boss.global_position)
			trace.append("%d,%d" % [roundi(point.x), roundi(point.y)])
	_expect(distance_flown > 900.0, label + " strafes a substantial ring")
	_expect(still_ticks < 40, label + " never parks on the strafe ring")
	_expect(minimum_distance > 90.0, label + " keeps contact clearance while strafing")
	var cruise: float = boss._boss_ai.movement.profile.cruise_speed * (1.0 + boss.phase * 0.08) + 1.0
	_expect(maximum_speed <= cruise, label + " obeys its phase flight speed")
	print("BOSS_FLIGHT %s strafe distance=%d" % [label, roundi(distance_flown)])
	return "|".join(trace)


func _check_chase(boss: Boss) -> void:
	_reset(boss, boss.phase)
	boss._boss_ai.movement.mode = Movement.Mode.CHASE
	boss.global_position = flight_space.screen_motion_to_combat(Vector2(-650, 0))
	player.global_position = flight_space.screen_motion_to_combat(Vector2(500, 0))
	var before := flight_space.combat_motion_to_screen(player.global_position - boss.global_position).length()
	for tick in 120:
		_step(boss)
	var after := flight_space.combat_motion_to_screen(player.global_position - boss.global_position).length()
	_expect(after < before - 200.0, "Chase closes on a distant player")
	player.global_position = flight_space.screen_motion_to_combat(Vector2(-700, -150))
	before = flight_space.combat_motion_to_screen(player.global_position - boss.global_position).length()
	for tick in 90:
		_step(boss)
	after = flight_space.combat_motion_to_screen(player.global_position - boss.global_position).length()
	var engagement := maxf(230.0, boss._boss_ai.movement.profile.preferred_distance - boss.phase * 20.0)
	_expect(
		after < maxf(before - 60.0, engagement + 90.0),
		"%s phase %d replans the chase after the player changes sides (%.1f to %.1f)" % [
			Boss.TITLES[boss.variant], boss.phase + 1, before, after
		]
	)


func _check_dodge(boss: Boss) -> void:
	_reset(boss, boss.phase)
	boss._boss_ai.movement.mode = Movement.Mode.STRAFE
	for tick in 24:
		_step(boss)
	var center := boss.global_position
	_expect(
		boss._boss_ai.movement.request_dodge(Vector2.DOWN, 1.0),
		"A projectile threat opens a dodge"
	)
	_expect(boss._boss_ai.movement.mode == Movement.Mode.DODGE, "Dodge is an explicit mobility mode")
	var lateral := Vector2.ZERO
	for tick in 12:
		_step(boss)
		lateral = flight_space.combat_motion_to_screen(boss.global_position - center)
	_expect(lateral.length() > 20.0, "Dodge displaces the hull sideways")
	for tick in 30:
		_step(boss)
	_expect(
		boss._boss_ai.movement.mode == Movement.Mode.STRAFE,
		"Dodge resolves back into the strafe ring"
	)


func _check_arena_edges(boss: Boss) -> void:
	var bounds := flight_space.get_combat_bounds()
	var stayed_inside := true
	for corner in [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]:
		_reset(boss, boss.phase)
		boss._boss_ai.movement.mode = Movement.Mode.STRAFE
		boss.global_position = Vector3(corner.x, 0, corner.y)
		var start := boss.global_position
		_step(boss)
		_expect(
			boss._boss_ai.movement.reason == &"arena_edge" or flight_space.get_combat_bounds(-Movement.ARENA_INSET).has_point(Vector2(boss.global_position.x, boss.global_position.z)) or flight_space.combat_motion_to_screen(boss.global_position - start).length() < 6.0,
			"Flight never teleports after a ram"
		)
		for tick in 180:
			_step(boss)
		_expect(
			flight_space.get_combat_bounds(-Movement.ARENA_INSET).has_point(Vector2(boss.global_position.x, boss.global_position.z)),
			"Every enlarged hull recovers from every corner"
		)
		player.global_position = Vector3(corner.x, 0, corner.y)
		for tick in 360:
			_step(boss)
			stayed_inside = stayed_inside and bounds.has_point(Vector2(boss.global_position.x, boss.global_position.z)) and is_zero_approx(boss.global_position.y)
	_expect(stayed_inside, "Flight paths stay in the combat plane and arena")


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
