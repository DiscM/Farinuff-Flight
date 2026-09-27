extends "res://tests/enemy_tactics_smoke.gd"
## Verify payloads through the actual FSM, projectile pool and damage route.
const ARMED_ACTIONS := [Brain.Action.IMMELMANN, Brain.Action.CORKSCREW, Brain.Action.LOW_YO_YO]
const EXPECTED_COUNTS := [2, 4, 3]
var _fired: Array[Dictionary] = []
var _emitter: BasicEnemy3D


func _run() -> void:
	player.set_physics_process(false)
	player.set_dev_god_mode(true)
	GameManager.is_game_active = true
	projectile_manager.projectile_fired.connect(_record_shot)
	var reduced: bool = SaveManager.get_setting("reduced_motion", false)
	SaveManager.settings["reduced_motion"] = false
	await _check_patterns()
	await _check_cancellation()
	await _check_squad_and_unarmed_moves()
	await _check_pool_capacity()
	await _check_pause_and_reduced_motion()
	SaveManager.settings["reduced_motion"] = reduced
	await ResourceCache.wait_for_scene("res://scenes/native_3d_run.tscn")
	for failure in _failures:
		push_error(failure)
	print("ENEMY_MANEUVER_ATTACKS_SMOKE_PASS" if _failures.is_empty() else "ENEMY_MANEUVER_ATTACKS_SMOKE_FAIL")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _record_shot(kind: int, origin: Vector3, direction: Vector3, speed: float) -> void:
	if kind != Shot.Kind.ENEMY:
		return
	var shot: Shot = projectile_manager._pools[Shot.Kind.ENEMY].checked_out.back()
	shot.set_physics_process(false)
	_fired.append({"origin": origin, "direction": direction, "speed": speed,
		"state": _emitter.state if is_instance_valid(_emitter) else -1})


func _armed(action: Brain.Action, role_name: String = "fast") -> BasicEnemy3D:
	_place_player(Vector2(0, 440))
	var enemy := _spawn(role_name, 4)
	_observe(enemy)
	_emitter = enemy
	_fired.clear()
	_expect(enemy._begin_tactical_maneuver(action, "weapon check"), "An eligible fighter can commit its armed maneuver")
	return enemy


func _fly(enemy: BasicEnemy3D, step: float) -> void:
	for tick in 500:
		if not enemy._tactics.has_plan():
			return
		enemy._physics_process(step)
	_expect(false, "An armed maneuver completes without getting stuck")


func _check_patterns() -> void:
	for role_name in ["basic", "fast"]:
		for step in [1.0 / 30.0, 1.0 / 120.0, 3.0]:
			for index in ARMED_ACTIONS.size():
				var action: Brain.Action = ARMED_ACTIONS[index]
				var enemy := _armed(action, role_name)
				var locked := enemy._predicted_player
				var flight_state := enemy._tactics._flight_state
				var side := enemy._tactics._direction
				_expect(enemy._maneuver_attack._tell.visible, "The target and attack lanes appear at commitment")
				enemy._physics_process(enemy.state_remaining - 0.01)
				_expect(_fired.is_empty() and enemy.state == BasicEnemy3D.State.TACTICAL_WINDUP, "No maneuver shots bypass the full warning")
				_place_player(Vector2(-850, -500))
				enemy._physics_process(0.02)
				_expect(_fired.is_empty() and enemy.state == flight_state, "Crossing into flight never fires prematurely")
				_expect(enemy._maneuver_attack._tell.visible, "Attack cues persist after the path warning ends")
				_fly(enemy, step)
				_expect(_fired.size() == EXPECTED_COUNTS[index], "Every frame rate preserves the shot count for " + Brain.Action.keys()[action])
				_expect(enemy.state == BasicEnemy3D.State.TRANSIT and enemy.velocity.length() > 0.1, "Attacking returns directly to moving flight")
				_expect(not enemy._maneuver_attack._tell.visible, "A completed pattern clears its attack warning")
				var angles := PackedFloat32Array()
				for release in _fired:
					var aimed := flight_space.combat_motion_to_screen(locked - release.origin).normalized()
					var fired := flight_space.combat_motion_to_screen(release.direction).normalized()
					angles.append(rad_to_deg(aimed.angle_to(fired)) * side)
					_expect(release.state == flight_state, "Only the owning flight state releases the pattern")
					_expect(release.speed > 450.0 and release.speed < 600.0, "Maneuver bullets keep readable ordinary projectile speeds")
				match action:
					Brain.Action.IMMELMANN:
						for angle in angles:
							_expect(absf(angle) < 0.05, "Turn bursts aim at the advertised target after the player moves")
					Brain.Action.CORKSCREW:
						if angles.size() == 4:
							_expect(angles[0] < -9.9 and angles[3] > 9.9 and angles[1] < angles[2], "Corkscrew fire sweeps across the locked lane in roll order")
					Brain.Action.LOW_YO_YO:
						if angles.size() == 3:
							_expect(absf(angles[0] + 14.0) < 0.05 and absf(angles[1]) < 0.05 and absf(angles[2] - 14.0) < 0.05, "Dive volleys leave gaps around a fixed three-way fan")
				if _fired.size() > 1:
					var spread: float = _fired.front().origin.distance_to(_fired.back().origin)
					_expect(spread < 0.001 if action == Brain.Action.LOW_YO_YO else spread > 1.0, "A slow frame preserves fan simultaneity and burst travel spacing")
				for shot: Shot in projectile_manager._pools[Shot.Kind.ENEMY].checked_out:
					_expect(shot.damage == 1 and not shot.homing and not shot.piercing and not shot.explosive, "Maneuver payloads use ordinary damage without hidden upgrades")
				var before := _fired.size()
				enemy._tactics._cooldown = 99.0
				enemy._physics_process(0.01)
				_expect(_fired.size() == before, "Returning to cruise cannot repeat a release")
				await _cleanup()


func _check_cancellation() -> void:
	for action: Brain.Action in ARMED_ACTIONS:
		for interrupted_flight in [false, true]:
			var enemy := _armed(action)
			if interrupted_flight:
				enemy._physics_process(enemy.state_remaining + 0.01)
				enemy._physics_process(enemy.state_remaining * 0.3)
			var before := _fired.size()
			enemy._begin_withdraw()
			enemy._physics_process(3.0)
			_expect(_fired.size() == before and not enemy._maneuver_attack._tell.visible, "Withdrawal cancels every unreleased shot and its cue")
			await _cleanup()
		var destroyed := _armed(action)
		destroyed.take_damage(1000)
		destroyed._physics_process(4.0)
		_expect(_fired.is_empty() and not destroyed._maneuver_attack._tell.visible, "Destroyed enemies cannot finish queued maneuver attacks")
		await _cleanup()


func _check_squad_and_unarmed_moves() -> void:
	var first := _armed(Brain.Action.IMMELMANN, "basic")
	var second := _armed(Brain.Action.CORKSCREW)
	var third := _spawn("basic", 4)
	_observe(third)
	_expect(not third._begin_tactical_maneuver(Brain.Action.LOW_YO_YO, "full squad"), "Turn bursts share the two-attack budget with sweeps and volleys")
	first._begin_withdraw()
	_expect(third._begin_tactical_maneuver(Brain.Action.LOW_YO_YO, "released slot"), "Cancelling a turn burst frees its attack slot immediately")
	_expect(second.is_maneuver_committed(), "Freeing a slot does not interrupt the other attack")
	await _cleanup()
	for action: Brain.Action in [Brain.Action.SPLIT_S, Brain.Action.SCISSORS, Brain.Action.HIGH_YO_YO, Brain.Action.HAMMERHEAD]:
		var enemy := _armed(action)
		_fly(enemy, 1.0 / 60.0)
		_expect(_fired.is_empty(), "Escape and positioning maneuvers do not inherit offensive payloads")
		await _cleanup()
	var novice := _spawn("basic", 1)
	_observe(novice)
	_expect(not novice._begin_tactical_maneuver(Brain.Action.IMMELMANN, "novice"), "Generation I remains introductory")
	await _cleanup()


func _check_pool_capacity() -> void:
	var enemy := _armed(Brain.Action.CORKSCREW)
	var pool = projectile_manager._pools[Shot.Kind.ENEMY]
	for index in pool.capacity:
		projectile_manager.fire_enemy_projectile(Vector3.ZERO, Vector3.FORWARD)
	var growth: int = pool.pool_growth
	var rejected: int = pool.rejected_shots
	_fired.clear()
	enemy._physics_process(1.0)
	enemy._physics_process(3.0)
	_expect(_fired.is_empty() and pool.rejected_shots == rejected + 4 and pool.pool_growth == growth, "A full pool drops scheduled shots without growth or a delayed burst")
	projectile_manager.clear_projectiles()
	await get_tree().process_frame
	await get_tree().process_frame
	enemy._physics_process(0.01)
	_expect(_fired.is_empty(), "Released pool capacity does not replay a spent attack")
	await _cleanup()


func _check_pause_and_reduced_motion() -> void:
	SaveManager.settings["reduced_motion"] = true
	var enemy := _armed(Brain.Action.LOW_YO_YO)
	enemy.advance_motion(0.01)
	var timer := enemy.state_remaining
	get_tree().paused = true
	enemy.set_physics_process(true)
	await get_tree().create_timer(0.06, true).timeout
	enemy.set_physics_process(false)
	get_tree().paused = false
	_expect(_fired.is_empty() and enemy.state_remaining == timer, "Pause freezes movement and weapon release")
	_expect(enemy._maneuver_attack._tell.visible, "Reduced Motion keeps the attack warning visible")
	GameManager.is_game_active = false
	enemy._physics_process(3.0)
	_expect(_fired.is_empty() and enemy.state_remaining == timer, "Inactive gameplay cannot release an attack")
	GameManager.is_game_active = true
	_fly(enemy, 1.0 / 60.0)
	_expect(_fired.size() == 3 and enemy._flight_motion.pose == Transform3D.IDENTITY, "Reduced Motion retains the full volley and physical flight")
	if not projectile_manager._pools[Shot.Kind.ENEMY].checked_out.is_empty():
		var shot: Shot = projectile_manager._pools[Shot.Kind.ENEMY].checked_out.front()
		player.set_dev_god_mode(false)
		player.reset_damage_state()
		var lives := GameManager.lives
		shot._report_hit(player, player.global_position)
		_expect(GameManager.lives == lives - 1, "A maneuver projectile inflicts real player damage")
		player.set_dev_god_mode(true)
		player.reset_damage_state()
		GameManager.lives = lives
	await _cleanup()
