extends Native3DGameplay
## Exercise authored flight profiles through the real boss movement entry point.
const BossScene := preload("res://entities/enemies/boss_enemy_3d.tscn")
const Boss := preload("res://entities/enemies/boss_enemy_3d.gd")
const Flight := preload("res://systems/boss_flight_orchestrator.gd")
const Profile := preload("res://systems/boss_flight_profile.gd")
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
			_reset_flight(boss, phase)
			var signature := _check_sequence(boss)
			if phase == 0:
				_expect(not signatures.has(signature), "Each boss flies a distinct route")
				signatures.append(signature)
			_check_tracking(boss)
			_check_arena_edges(boss)
		_check_holds_and_lifecycle(boss)
		if variant == 0:
			_check_authored_curves(boss)
		boss._before_finish(BasicEnemy.FinishReason.ESCAPED, boss.global_position)
		_expect(boss._flight_ai.steer(STEP, boss.global_position, Vector3.ONE, player, boss.phase).is_zero_approx(), "Finished flight controller stays inactive")
		boss.queue_free()
		await get_tree().process_frame
	GameManager.is_game_active = false
	for failure in _failures:
		push_error(failure)
	print("BOSS_FLIGHT_SMOKE_PASS" if _failures.is_empty() else "BOSS_FLIGHT_SMOKE_FAIL")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _reset_flight(boss: Boss, phase: int) -> void:
	boss.phase = phase
	boss._phase_transition = 0.0
	boss._warning_timer = 0.0
	boss._burst_remaining = 0
	boss._cancel_ram()
	boss._flight_ai.configure(flight_space, boss.variant)
	boss.global_position = flight_space.screen_motion_to_combat(Vector2(0, -340))
	boss.velocity = Vector3.ZERO
	player.global_position = Vector3.ZERO
	player.velocity = Vector3.ZERO


func _step(boss: Boss) -> void:
	# Isolate flight scheduling; the boss-pattern scene exercises attack locks.
	boss._volley_timer = 120.0
	boss._advance_movement(STEP)


func _check_sequence(boss: Boss) -> String:
	var label := "%s phase %d" % [Boss.TITLES[boss.variant], boss.phase + 1]
	var maneuvers: Array[String] = []
	var trace: Array[String] = []
	var distance_flown := 0.0
	var minimum_distance := INF
	var maximum_speed := 0.0
	for tick in 1800:
		var previous := boss.global_position
		_step(boss)
		distance_flown += flight_space.combat_motion_to_screen(boss.global_position - previous).length()
		minimum_distance = minf(minimum_distance, flight_space.combat_motion_to_screen(boss.global_position - player.global_position).length())
		maximum_speed = maxf(maximum_speed, flight_space.combat_motion_to_screen(boss.velocity).length())
		if tick % 30 == 0:
			var state := boss._flight_ai.get_debug_state()
			if not maneuvers.has(String(state.maneuver)):
				maneuvers.append(String(state.maneuver))
			var point := flight_space.combat_motion_to_screen(boss.global_position)
			trace.append("%d,%d" % [roundi(point.x), roundi(point.y)])
	_expect(maneuvers.size() >= 3 and distance_flown > 1200.0, label + " chains several substantial flight maneuvers")
	_expect(minimum_distance > 120.0, label + " maintains room around a stationary player")
	_expect(maximum_speed <= boss._flight_ai.profile.cruise_speed * (1.0 + boss.phase * 0.08) + 0.2, label + " obeys its phase flight speed")
	print("BOSS_FLIGHT %s: %s; distance=%d" % [label, ", ".join(maneuvers), roundi(distance_flown)])
	return "|".join(trace)


func _check_tracking(boss: Boss) -> void:
	_reset_flight(boss, boss.phase)
	boss.global_position = flight_space.screen_motion_to_combat(Vector2(-650, 0))
	player.global_position = flight_space.screen_motion_to_combat(Vector2(500, 0))
	var before := flight_space.combat_motion_to_screen(player.global_position - boss.global_position).length()
	for tick in 120:
		_step(boss)
	var after := flight_space.combat_motion_to_screen(player.global_position - boss.global_position).length()
	_expect(after < before - 200.0, "Distant player takes priority over a decorative flight pattern")
	player.global_position = flight_space.screen_motion_to_combat(Vector2(-700, -150))
	before = flight_space.combat_motion_to_screen(player.global_position - boss.global_position).length()
	for tick in 90:
		_step(boss)
	after = flight_space.combat_motion_to_screen(player.global_position - boss.global_position).length()
	var engagement_distance := maxf(230.0, boss._flight_ai.profile.preferred_distance - boss.phase * 20.0)
	_expect(after < maxf(before - 60.0, engagement_distance + 70.0), "%s phase %d replans toward engagement range after the player changes sides (%.1f to %.1f)" % [Boss.TITLES[boss.variant], boss.phase + 1, before, after])
	# Follow a moving target with matching analytic position and velocity.
	var worst_distance := 0.0
	for tick in 1200:
		var time := tick * STEP
		player.global_position = flight_space.screen_motion_to_combat(Vector2(sin(time * 0.55) * 330, cos(time * 0.75) * 220))
		player.velocity = flight_space.screen_motion_to_combat(Vector2(cos(time * 0.55) * 181.5, -sin(time * 0.75) * 165))
		_step(boss)
		if tick > 120:
			worst_distance = maxf(worst_distance, flight_space.combat_motion_to_screen(player.global_position - boss.global_position).length())
	_expect(worst_distance < 900.0, "Complex flight remains attached to the moving player")
	player.velocity = flight_space.screen_motion_to_combat(Vector2(1500, 0))
	_step(boss)
	var state := boss._flight_ai.get_debug_state()
	_expect(flight_space.combat_motion_to_screen(Vector3(state.predicted_target) - player.global_position).length() <= boss._flight_ai.profile.maximum_lead + 0.1, "Player boosts cannot create an unbounded intercept")
	player.velocity = Vector3.ZERO


func _check_arena_edges(boss: Boss) -> void:
	var bounds := flight_space.get_combat_bounds()
	var stayed_inside := true
	var minimum_distance := INF
	for corner in [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]:
		_reset_flight(boss, boss.phase)
		boss.global_position = Vector3(corner.x, 0, corner.y)
		var start := boss.global_position
		_step(boss)
		_expect(boss._flight_ai.maneuver == Profile.Maneuver.REENTER, "Arena reentry overrides the authored sequence")
		_expect(flight_space.combat_motion_to_screen(boss.global_position - start).length() < 6.0, "Flight never snaps inward after a ram")
		for tick in 180:
			_step(boss)
		_expect(flight_space.get_combat_bounds(-100.0).has_point(Vector2(boss.global_position.x, boss.global_position.z)), "Every hull recovers from every corner")
		# Put the player near the wall and ensure pursuit does not pin the boss there.
		player.global_position = Vector3(corner.x, 0, corner.y)
		for tick in 480:
			_step(boss)
			stayed_inside = stayed_inside and bounds.has_point(Vector2(boss.global_position.x, boss.global_position.z)) and is_zero_approx(boss.global_position.y)
			minimum_distance = minf(minimum_distance, flight_space.combat_motion_to_screen(player.global_position - boss.global_position).length())
	_expect(stayed_inside, "Flight paths stay in the combat plane and arena")
	_expect(minimum_distance > 100.0, "Wall pursuit leaves contact clearance")


func _check_holds_and_lifecycle(boss: Boss) -> void:
	_reset_flight(boss, 0)
	for tick in 20:
		_step(boss)
	var held_position := boss.global_position
	var flight_time: float = boss._flight_ai.get_debug_state().flight_time
	boss._warning_timer = 1.0
	boss._advance_movement(0.5)
	_expect(boss.global_position.is_equal_approx(held_position) and is_equal_approx(float(boss._flight_ai.get_debug_state().flight_time), flight_time), "Attack warnings hold both the hull and maneuver clock")
	GameManager.is_game_active = false
	boss._physics_process(5.0)
	GameManager.is_game_active = true
	_expect(is_equal_approx(float(boss._flight_ai.get_debug_state().flight_time), flight_time), "Gameplay pause does not advance the flight sequence")
	boss.phase = 2
	boss._begin_phase_transition()
	var state := boss._flight_ai.get_debug_state()
	_expect(state.held and state.phase == 2 and state.sequence_index == -1 and is_zero_approx(float(state.flight_time)), "Health phases reset the maneuver planner during their breathing window")
	boss._phase_transition = 0.0
	player.remove_from_group(&"player_craft")
	_step(boss)
	_expect(boss.global_position.is_equal_approx(held_position) and boss._flight_ai.get_debug_state().reason == &"no_player", "Missing player suspends flight safely")
	player.add_to_group(&"player_craft")
	_step(boss)
	_expect(not boss._flight_ai.get_debug_state().held, "Flight reacquires the player when it returns")
	var second := Flight.new()
	add_child(second)
	second.configure(flight_space, boss.variant)
	_expect(second.profile == boss._flight_ai.profile and second.get_debug_state().phase == 0 and is_zero_approx(float(second.get_debug_state().flight_time)), "Shared tuning does not share an encounter's maneuver state")
	second.queue_free()


func _check_authored_curves(boss: Boss) -> void:
	for maneuver in [Profile.Maneuver.WEAVE, Profile.Maneuver.FIGURE_EIGHT]:
		var custom := Profile.new()
		custom.sequence.assign([maneuver])
		custom.cruise_speed = 260.0
		custom.maneuver_seconds = 4.0
		custom.pattern_amplitude = 120.0
		boss._flight_ai.profile_override = custom
		_reset_flight(boss, 0)
		var minimum := Vector2(INF, INF)
		var maximum := Vector2(-INF, -INF)
		for tick in (240 if maneuver == Profile.Maneuver.WEAVE else 480):
			_step(boss)
			var point := flight_space.combat_motion_to_screen(boss.global_position)
			minimum = minimum.min(point)
			maximum = maximum.max(point)
		_expect(minimum.x < -50.0 and maximum.x > 50.0, "Authored curve flies across both sides of its approach axis")
		if maneuver == Profile.Maneuver.FIGURE_EIGHT:
			_expect(maximum.y - minimum.y > 50.0, "Figure eight also crosses its radial axis")
	boss._flight_ai.profile_override = null


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
