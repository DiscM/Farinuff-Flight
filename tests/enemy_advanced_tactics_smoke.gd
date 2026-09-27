extends "res://tests/enemy_tactics_smoke.gd"
## Uses the same real actors, projectile pools and isolated native fixture.
const ADVANCED_ACTIONS := [Brain.Action.HIGH_YO_YO, Brain.Action.LOW_YO_YO, Brain.Action.HAMMERHEAD, Brain.Action.BOMBING_RUN]


func _run() -> void:
	player.set_physics_process(false)
	player.set_dev_god_mode(true)
	GameManager.is_game_active = true
	_place_player(Vector2(0, 440))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var reduced: bool = SaveManager.get_setting("reduced_motion", false)
	SaveManager.settings["reduced_motion"] = false
	await _check_advanced_decisions()
	await _check_complementary_routes()
	await _check_reactive_followups()
	await _check_bomb_run()
	await _check_advanced_paths()
	await _check_advanced_lifecycle()
	SaveManager.settings["reduced_motion"] = reduced
	await ResourceCache.wait_for_scene("res://scenes/native_3d_run.tscn")
	for failure in _failures:
		push_error(failure)
	print("ENEMY_ADVANCED_TACTICS_SMOKE_PASS" if _failures.is_empty() else "ENEMY_ADVANCED_TACTICS_SMOKE_FAIL")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _face_player(enemy: BasicEnemy3D) -> void:
	enemy._heading = (player.global_position - enemy.global_position).normalized()
	enemy._update_facing(enemy._heading)
	_observe(enemy)


func _finish_flight(enemy: BasicEnemy3D) -> void:
	for tick in 300:
		if not enemy._tactics.has_plan():
			return
		enemy._physics_process(1.0 / 120.0)
	_expect(false, "Committed flight finishes into its normal behavior")


func _check_advanced_decisions() -> void:
	_place_player(Vector2(0, 230), Vector2(220, 0))
	var enemy := _spawn("fast", 4)
	_face_player(enemy)
	_expect(enemy._try_begin_tactical_maneuver() and enemy._tactics.last_action == Brain.Action.HIGH_YO_YO, "A crossing target causes a Generation IV fighter to brake into a high yo-yo")
	var endpoint := enemy._tactics.sample_path(1.0)
	_expect(flight_space.combat_motion_to_screen(endpoint).length() > 120.0, "The high yo-yo opens a real turning lane")
	await _cleanup()

	_place_player(Vector2(0, 400), Vector2(0, 260))
	enemy = _spawn("basic", 4)
	_face_player(enemy)
	_expect(enemy._try_begin_tactical_maneuver() and enemy._tactics.last_action == Brain.Action.LOW_YO_YO, "A receding target causes an inside pursuit cut")
	endpoint = enemy._tactics.sample_path(1.0)
	_expect(endpoint.distance_to(player.global_position) < enemy.global_position.distance_to(player.global_position), "The low yo-yo closes range instead of merely spinning")
	var locked := endpoint
	_place_player(Vector2(330, -250))
	enemy._physics_process(0.41)
	_expect(enemy._tactics.sample_path(1.0) == locked, "Pursuit cannot retarget after its path warning")
	await _cleanup()

	_place_player(Vector2(0, 300))
	enemy = _spawn("fast", 3)
	var bounds := flight_space.get_combat_bounds()
	enemy.global_position = enemy._clamp_maneuver_point(Vector3(bounds.end.x, 0.0, bounds.get_center().y))
	enemy._heading = Vector3.RIGHT
	_observe(enemy)
	_expect(enemy._try_begin_tactical_maneuver() and enemy.state == BasicEnemy3D.State.HAMMERHEAD, "An outward approach near the edge chooses a hammerhead")
	var initial_x := enemy.global_position.x
	_expect(enemy._tactics.sample_path(0.4) == enemy._tactics.sample_path(0.5), "The hammerhead has a real vulnerable stall at its apex")
	_finish_flight(enemy)
	_expect(enemy.global_position.x < initial_x - flight_space.screen_motion_to_combat(Vector2(150, 0)).length(), "Hammerhead exits back toward the arena interior")
	await _cleanup()

	_place_player(Vector2(0, 400), Vector2(0, 260))
	enemy = _spawn("fast", 3)
	_face_player(enemy)
	enemy._try_begin_tactical_maneuver()
	_expect(enemy._tactics.last_action != Brain.Action.LOW_YO_YO, "Generation III does not acquire the Generation IV energy turns")
	await _cleanup()
	var bomber := _spawn("bomber", 3) as BomberEnemy3D
	_face_player(bomber)
	bomber._drop_timer = 0.2
	_expect(not bomber._try_begin_tactical_maneuver(), "A bomber does not cancel an already warned ordinary payload")
	bomber._drop_timer = 1.4
	bomber._mine_timer = 0.1
	_observe(bomber)
	_expect(not bomber._try_begin_tactical_maneuver(), "A due mine retains its deployment opening")
	bomber._mine_timer = 5.0
	_observe(bomber)
	_expect(bomber._try_begin_tactical_maneuver() and bomber.state == BasicEnemy3D.State.TACTICAL_WINDUP, "A clear bomber approach starts a warned run")
	await _cleanup()


func _check_complementary_routes() -> void:
	_place_player(Vector2(0, 440))
	var first := _spawn("fast", 4)
	var second := _spawn("fast", 4)
	var bomber := _spawn("bomber", 3)
	first._strafe_sign = 1.0
	second._strafe_sign = 1.0
	_face_player(first)
	_face_player(second)
	_face_player(bomber)
	# Observe both before either commits: reservations must be live.
	_expect(first._begin_tactical_maneuver(Brain.Action.CORKSCREW, "first flank"), "First fighter reserves a flank")
	_expect(second._begin_tactical_maneuver(Brain.Action.LOW_YO_YO, "second flank"), "Second fighter reserves an alternate approach")
	var first_end := flight_space.combat_motion_to_screen(first._tactics.sample_path(1.0))
	var second_end := flight_space.combat_motion_to_screen(second._tactics.sample_path(1.0))
	_expect(first_end.x * second_end.x < 0.0, "Attackers choose opposite flanks from current intentions")
	_expect(not bomber._begin_tactical_maneuver(Brain.Action.BOMBING_RUN, "third attack"), "A bomber shares the two-attack squad budget with fighters")
	first.take_damage(1000)
	_expect(bomber._begin_tactical_maneuver(Brain.Action.BOMBING_RUN, "released slot"), "Destruction releases a squad reservation immediately")
	await _cleanup()


func _check_reactive_followups() -> void:
	for scenario in 4:
		_place_player(Vector2(0, 230), Vector2(220, 0))
		var enemy := _spawn("fast", 4)
		_face_player(enemy)
		enemy._begin_tactical_maneuver(Brain.Action.HIGH_YO_YO, "chain setup")
		_finish_flight(enemy)
		_expect(enemy.state == BasicEnemy3D.State.TRANSIT and not enemy.can_reflect_projectile(), "Flight finishes directly into hittable normal flight")
		_expect(enemy._tactics._followup == Brain.Action.LOW_YO_YO, "Flight completion immediately opens one short pursuit opportunity")
		# Present a fresh fleeing target relative to the new, real position.
		var offset := flight_space.combat_motion_to_screen(enemy.global_position)
		_place_player(offset + Vector2(0, 320), Vector2(0, 220))
		_face_player(enemy)
		if scenario == 1:
			_shot(enemy, Vector2(0, 250))
			_observe(enemy)
		elif scenario == 2:
			enemy._tactics.tick(enemy, Brain.FOLLOWUP_SECONDS + 0.01)
		elif scenario == 3:
			enemy._enter(BasicEnemy3D.State.REFLECT_WINDUP, 0.3)
			enemy._tactics.tick(enemy, 0.01)
			enemy._enter(BasicEnemy3D.State.TRANSIT)
			_observe(enemy)
		var began := enemy._try_begin_tactical_maneuver()
		if scenario == 0:
			_expect(began and enemy.state == BasicEnemy3D.State.TACTICAL_WINDUP and enemy._tactics._chain_depth == 1, "A changed target earns one freshly warned follow-up during the normal cooldown")
			_finish_flight(enemy)
			_expect(enemy._tactics._followup == Brain.Action.NONE and enemy._tactics._cooldown > 0.0, "The two-maneuver sequence ends with cooldown, not an endless chain")
		else:
			_expect(not began and enemy._tactics._followup == Brain.Action.NONE, "Threats, expiry and intervening defense cancel a pursuit opportunity")
		await _cleanup()


func _check_bomb_run() -> void:
	_place_player(Vector2(0, 440))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var bomber := _spawn("bomber", 3) as BomberEnemy3D
	_face_player(bomber)
	bomber._begin_tactical_maneuver(Brain.Action.BOMBING_RUN, "payload probe")
	var locked := bomber._run_target
	var cadence := bomber._drop_timer
	var mine_cadence := bomber._mine_timer
	bomber._physics_process(0.64)
	_expect(projectile_manager._pools[Shot.Kind.ENEMY].checked_out.is_empty() and bomber._run_releases == 0, "No payload escapes before the complete bombing-run warning")
	_expect(bomber._drop_timer == cadence and bomber._mine_timer == mine_cadence, "Ordinary bomb and mine timers remain suspended during a committed run")
	_place_player(Vector2(-380, -250))
	await get_tree().physics_frame
	await get_tree().physics_frame
	bomber._physics_process(0.02)
	_expect(bomber.state == BasicEnemy3D.State.BOMBING_RUN and bomber._run_target == locked, "Bombing run keeps the target advertised before the player dodged")
	# A deliberately coarse step crosses all release points. Spacing and the
	# three-attempt budget must be independent of the physics frame rate.
	bomber._physics_process(1.7)
	_expect(bomber._run_releases == 3 and bomber.state == BasicEnemy3D.State.TRANSIT, "A complete run releases exactly three payloads and resumes flight")
	var shots: Array = projectile_manager._pools[Shot.Kind.ENEMY].checked_out.duplicate()
	_expect(shots.size() == 3, "Run payloads come from the existing hostile projectile pool")
	var origins := PackedVector3Array()
	for shot: Shot in shots:
		shot.set_physics_process(false)
		origins.append(shot.global_position)
		var to_locked := (locked - shot.global_position)
		to_locked.y = 0.0
		_expect(shot.velocity.normalized().dot(to_locked.normalized()) > 0.99, "Every run payload aims at the locked location, not the moved player")
		_expect(not shot.homing and shot.damage == 1, "Run payloads retain ordinary damage and no homing")
	if origins.size() == 3:
		_expect(origins[0].distance_to(origins[1]) > 1.0 and origins[1].distance_to(origins[2]) > 1.0, "A slow frame cannot stack all bombs at one endpoint")
	bomber._physics_process(0.54)
	_expect(bomber._run_releases == 3 and is_equal_approx(bomber._drop_timer, cadence - 0.54), "Normal bomb scheduling resumes immediately without repeating run payloads")
	await _cleanup()

	var second := _spawn("bomber", 3) as BomberEnemy3D
	_face_player(second)
	second._begin_tactical_maneuver(Brain.Action.BOMBING_RUN, "cancel probe")
	second.take_damage(1000)
	second._physics_process(3.0)
	_expect(second._run_releases == 0 and projectile_manager._pools[Shot.Kind.ENEMY].checked_out.is_empty(), "Destroying a warned bomber cancels every pending run payload")
	await _cleanup()


func _check_advanced_paths() -> void:
	_place_player(Vector2(0, 440))
	for action: Brain.Action in ADVANCED_ACTIONS:
		for edge in [false, true]:
			var enemy := _spawn("bomber" if action == Brain.Action.BOMBING_RUN else "fast", 4)
			var bounds := flight_space.get_combat_bounds()
			if edge:
				enemy.global_position = enemy._clamp_maneuver_point(Vector3(bounds.end.x, 0.0, bounds.get_center().y))
			_face_player(enemy)
			var began := enemy._begin_tactical_maneuver(action, "path probe")
			if not began:
				_expect(edge, "New maneuvers are available with open central space")
				await _cleanup()
				continue
			var maximum_step := 0.0
			for tick in 300:
				if not enemy._tactics.has_plan():
					break
				var previous := enemy.global_position
				enemy._physics_process(1.0 / 120.0)
				maximum_step = maxf(maximum_step, flight_space.combat_motion_to_screen(enemy.global_position - previous).length())
				var half := enemy._maneuver_half_extents()
				var footprint := Rect2(Vector2(enemy.global_position.x - half.x, enemy.global_position.z - half.z), Vector2(half.x, half.z) * 2.0)
				_expect(bounds.encloses(footprint), Brain.Action.keys()[action] + " keeps its complete contact envelope in the arena")
			_expect(maximum_step < 18.0, "New maneuver paths advance continuously without teleports")
			_expect(enemy.state == BasicEnemy3D.State.TRANSIT, "Every new maneuver resumes normal flight immediately")
			await _cleanup()
	var sample := _spawn("fast", 4)
	for maneuver in [Flight.Maneuver.HIGH_YO_YO, Flight.Maneuver.LOW_YO_YO, Flight.Maneuver.HAMMERHEAD, Flight.Maneuver.BOMBING_RUN]:
		for direction in [-1.0, 1.0]:
			sample._flight_motion._direction = direction
			var previous := Quaternion.IDENTITY
			var angular_travel := 0.0
			for frame in 241:
				var pose := sample._flight_motion._sample(maneuver, float(frame) / 240.0)
				var rotation := pose.basis.get_rotation_quaternion()
				var step := previous.angle_to(rotation)
				_expect(step < 0.12, "New flight poses have no abrupt angular discontinuities")
				angular_travel += step
				previous = rotation
			_expect(previous.angle_to(Quaternion.IDENTITY) < 0.002 and angular_travel > 1.0, "Both directions animate visibly and finish level")
	await _cleanup()


func _check_advanced_lifecycle() -> void:
	_place_player(Vector2(0, 440))
	var bomber := _spawn("bomber", 3) as BomberEnemy3D
	_face_player(bomber)
	SaveManager.settings["reduced_motion"] = true
	bomber.advance_motion(0.01)
	bomber._begin_tactical_maneuver(Brain.Action.BOMBING_RUN, "accessible run")
	_expect(bomber._tactics._tell.visible, "Reduced Motion keeps the flight route and bomb-target warning")
	var timer := bomber.state_remaining
	get_tree().paused = true
	bomber.set_physics_process(true)
	await get_tree().create_timer(0.06, true).timeout
	bomber.set_physics_process(false)
	get_tree().paused = false
	_expect(bomber.state_remaining == timer and bomber._run_releases == 0, "Pause freezes the run and its unreleased payloads")
	_finish_flight(bomber)
	_expect(bomber._run_releases == 3 and bomber._flight_motion.pose == Transform3D.IDENTITY, "Reduced Motion retains physical flight and payload timing")
	SaveManager.settings["reduced_motion"] = false
	await _cleanup()
