extends "res://tests/enemy_tactics_smoke.gd"
## Integration contract: normal physics decisions enter every flight behavior.
## Direct state requests below are only used to probe invalid transitions and
## interruptions; no maneuver is manually started in the automatic scenarios.
@export var quit_when_complete := true
@export var show_steps := false
var completed := false
var automatic_traces := {}


func _run() -> void:
	player.set_physics_process(false)
	player.set_dev_god_mode(true)
	GameManager.is_game_active = true
	_place_player(Vector2(0, 400))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var reduced: bool = SaveManager.get_setting("reduced_motion", false)
	SaveManager.settings["reduced_motion"] = false
	await _check_automatic_maneuvers()
	await _check_automatic_rolls()
	await _check_state_authority()
	await _check_interruptions()
	await _check_bomber_windup()
	await _check_sniper_rail_commitment()
	SaveManager.settings["reduced_motion"] = reduced
	await ResourceCache.wait_for_scene("res://scenes/native_3d_run.tscn")
	for failure in _failures:
		push_error(failure)
	completed = true
	print("ENEMY_FSM_MANEUVERS_SMOKE_PASS" if _failures.is_empty() else "ENEMY_FSM_MANEUVERS_SMOKE_FAIL")
	if quit_when_complete:
		get_tree().quit(0 if _failures.is_empty() else 1)


func _check_automatic_maneuvers() -> void:
	for action: Brain.Action in [Brain.Action.SPLIT_S, Brain.Action.IMMELMANN, Brain.Action.SCISSORS,
		Brain.Action.CORKSCREW, Brain.Action.KNIFE_EDGE, Brain.Action.HIGH_YO_YO,
		Brain.Action.LOW_YO_YO, Brain.Action.HAMMERHEAD, Brain.Action.BOMBING_RUN]:
		_place_player(Vector2(0, 380))
		var role_name := "fast"
		if action == Brain.Action.KNIFE_EDGE:
			role_name = "sniper"
		elif action == Brain.Action.BOMBING_RUN:
			role_name = "bomber"
		var enemy := _spawn(role_name, 2 if action == Brain.Action.IMMELMANN else 4)
		enemy._heading = Vector3.BACK
		enemy._tactics._observe_in = 0.0
		match action:
			Brain.Action.SPLIT_S:
				enemy.health = 30
				_place_player(Vector2(0, 240))
			Brain.Action.IMMELMANN:
				enemy._heading = Vector3.FORWARD
			Brain.Action.SCISSORS:
				for x in [-20, 0, 20]:
					_shot(enemy, Vector2(x, 300))
			Brain.Action.CORKSCREW:
				enemy._tactics.role = 1
			Brain.Action.KNIFE_EDGE:
				var ally := _spawn()
				ally.global_position = flight_space.screen_motion_to_combat(Vector2(0, 170))
				enemy._shoot_timer = 5.0
			Brain.Action.HIGH_YO_YO:
				_place_player(Vector2(0, 230), Vector2(220, 0))
			Brain.Action.LOW_YO_YO:
				_place_player(Vector2(0, 400), Vector2(0, 260))
			Brain.Action.HAMMERHEAD:
				var bounds := flight_space.get_combat_bounds()
				enemy.global_position = enemy._clamp_maneuver_point(Vector3(bounds.end.x, 0.0, bounds.get_center().y))
				enemy._heading = Vector3.RIGHT
			Brain.Action.BOMBING_RUN:
				enemy._drop_timer = 2.0
		enemy._update_facing(enemy._heading)
		var expected: int = BasicEnemy3D.State[Brain.Action.keys()[action]]
		var history: Array[int] = []
		enemy.state_changed.connect(func(_previous, next):
			history.append(next)
			if next == expected:
				_expect(enemy._flight_motion.current_maneuver == Flight.Maneuver[Brain.Action.keys()[action]], "FSM entry starts the matching hull animation for " + Brain.Action.keys()[action])
			if next == BasicEnemy3D.State.TACTICAL_WINDUP:
				_expect(enemy._tactics._tell.visible and enemy._motions[0].current_clip == &"windup", "FSM warning owns both the path tell and held wing pose")
		)
		for tick in 300:
			if not is_instance_valid(enemy):
				break
			var boundaries := history.size()
			enemy._physics_process(1.0 / 60.0)
			_expect(history.size() - boundaries <= 1, "A physics tick crosses at most one FSM boundary")
			if history.has(expected) and enemy.state == enemy._maneuver_entry_state():
				break
			if show_steps:
				await get_tree().process_frame
		if not is_instance_valid(enemy):
			_expect(false, "The full-cycle fixture lost its actor before completing flight: " + Brain.Action.keys()[action])
			await _cleanup()
			continue
		_expect(history.has(expected), "Normal AI chooses " + Brain.Action.keys()[action])
		_expect(enemy.state == enemy._maneuver_entry_state() and not enemy._tactics.has_plan(), "Normal FSM completes the maneuver and clears its plan immediately")
		var flight_index := history.find(expected)
		if flight_index >= 0:
			_expect(history.size() == flight_index + 2 and history[flight_index + 1] == enemy._maneuver_entry_state(), "Flight returns directly to the archetype's normal behavior without a recovery state")
		var names: Array[String] = []
		for next in history:
			names.append(BasicEnemy3D.State.keys()[next])
		automatic_traces[Brain.Action.keys()[action]] = names
		print("FSM_FLIGHT ", Brain.Action.keys()[action], " ", names)
		await _cleanup()


func _check_automatic_rolls() -> void:
	for reflect in [true, false]:
		_place_player(Vector2(0, 400))
		var enemy := _spawn("fast", 4) if reflect else _spawn("basic", 2)
		enemy._tactics._observe_in = 0.0
		enemy._prefer_reflect = reflect
		enemy._evade_scan_timer = 0.0
		if reflect:
			# An interceptor travelling with the shot sees it early enough to
			# reflect, before the shorter imminent-hit observation horizon.
			enemy.velocity = flight_space.screen_motion_to_combat(Vector2.UP * enemy._speed_pixels)
		_shot(enemy, Vector2(0, 510 if reflect else 280))
		var history: Array[int] = []
		enemy.state_changed.connect(func(_from, next): history.append(next))
		enemy._physics_process(0.01)
		var expected: int = BasicEnemy3D.State.REFLECT_WINDUP if reflect else BasicEnemy3D.State.EVADE
		_expect(enemy.state == expected, "Incoming fire naturally selects the fighter's roll defense")
		if reflect:
			_expect(enemy._tactics.approaching_fire and enemy._tactics.threat_count == 0, "Approaching fire keeps pursuit from stealing the early reflection opportunity")
			_expect(not enemy.can_reflect_projectile(), "The FSM warning stays vulnerable")
			enemy._physics_process(BasicEnemy3D.REFLECT_WARNING_SECONDS + 0.001)
			_expect(enemy.state == BasicEnemy3D.State.REFLECT_ROLL and enemy.can_reflect_projectile() and enemy._flight_motion.current_maneuver == Flight.Maneuver.AILERON_ROLL, "Reflect state arms the actual defense and the aileron animation together")
		else:
			_expect(enemy._flight_motion.current_maneuver == Flight.Maneuver.BARREL_ROLL and not enemy.can_reflect_projectile(), "Evade state owns the physical barrel roll without reflect immunity")
		for tick in 140:
			enemy._physics_process(1.0 / 60.0)
			if enemy.state == BasicEnemy3D.State.TRANSIT:
				break
		_expect(history.size() == (3 if reflect else 2) and enemy.state == BasicEnemy3D.State.TRANSIT, "Roll defenses return directly to normal combat")
		await _cleanup()


func _check_state_authority() -> void:
	_place_player(Vector2(0, 400))
	var enemy := _spawn("basic", 4)
	_observe(enemy)
	_expect(not enemy._enter(BasicEnemy3D.State.CORKSCREW), "A raw flight state cannot start without a committed route")
	_expect(enemy._tactics.prepare_plan(enemy, Brain.Action.CORKSCREW, "advisory probe"), "The planner can provide a route to the FSM")
	var position_before := enemy.global_position
	var state_before := enemy.state
	var timer := enemy.state_remaining
	enemy._tactics.tick(enemy, 1.0)
	_expect(enemy.global_position == position_before and enemy.state == state_before and enemy.state_remaining == timer and enemy._flight_motion.current_maneuver == Flight.Maneuver.NONE, "Planning and perception cannot move an actor, change its state, or start an animation")
	_expect(not enemy._enter(BasicEnemy3D.State.CORKSCREW), "A prepared attack cannot skip its warning")
	enemy._enter_planned_maneuver()
	_expect(not enemy._enter(BasicEnemy3D.State.CORKSCREW), "The release cannot occur before the warning expires")
	enemy._physics_process(4.0)
	_expect(enemy.state == BasicEnemy3D.State.CORKSCREW and is_equal_approx(enemy.state_remaining, enemy._tactics._duration), "A long warning frame enters flight with the full flight duration")
	_expect(not enemy._enter(BasicEnemy3D.State.TRANSIT), "A flight cannot complete before its own timer expires")
	enemy._physics_process(4.0)
	_expect(enemy.state == BasicEnemy3D.State.TRANSIT and not enemy._tactics.has_plan(), "A long flight frame completes directly into normal flight")
	await _cleanup()
	for role_name in ["basic", "fast", "bomber", "sniper", "tank"]:
		enemy = _spawn(role_name, 4)
		_observe(enemy)
		var unsupported := Brain.Action.BOMBING_RUN if role_name in ["basic", "fast", "sniper", "tank"] else Brain.Action.CORKSCREW
		_expect(not enemy._begin_tactical_maneuver(unsupported, "unsupported request"), "The " + role_name + " FSM rejects another archetype's maneuver")
		await _cleanup()
	var courier := preload("res://entities/enemies/courier_enemy_3d.tscn").instantiate() as BasicEnemy3D
	actors_root.add_child(courier)
	courier.activate_generation(flight_space, Vector3.ZERO, Vector3.BACK, 4)
	courier.set_physics_process(false)
	_expect(not courier._begin_tactical_maneuver(Brain.Action.CORKSCREW, "courier guard"), "Courier FSM keeps its objective route")
	courier.queue_free()
	await get_tree().process_frame


func _check_interruptions() -> void:
	_place_player(Vector2(0, 400))
	var bomber := _spawn("bomber", 3) as BomberEnemy3D
	bomber._tactics._observe_in = 0.0
	bomber._drop_timer = 2.0
	bomber._physics_process(0.01)
	_expect(bomber.state == BasicEnemy3D.State.TACTICAL_WINDUP, "Bomber naturally commits before the interruption probe")
	bomber._begin_withdraw()
	_expect(not bomber._tactics.has_plan() and not bomber._tactics._tell.visible and not bomber._flight_motion._telegraph, "FSM interruption immediately cancels route, reservation and held warning")
	bomber._physics_process(0.5)
	_expect(bomber._run_releases == 0, "An interrupted warning cannot emit delayed payloads")
	await _cleanup()
	var fighter := _spawn("fast", 4)
	fighter._tactics._cooldown = 99.0
	fighter._phase_cooldown = 0.0
	fighter._visible_time = 1.0
	fighter._physics_process(0.01)
	_expect(fighter.state == BasicEnemy3D.State.PHASE_WINDUP and fighter.phase_warning.visible, "Fast FSM starts its phase warning and motion together")
	fighter._enter(BasicEnemy3D.State.TRANSIT)
	_expect(not fighter.phase_warning.visible and not fighter._flight_motion._telegraph, "Exiting phase windup clears its warning immediately")
	fighter._phase_cooldown = 0.0
	fighter._physics_process(0.01)
	fighter._physics_process(0.41)
	_expect(fighter.state == BasicEnemy3D.State.PHASE_DASH and fighter._flight_motion.current_maneuver == Flight.Maneuver.SPIN, "Phase release starts the spin through the FSM")
	fighter._enter(BasicEnemy3D.State.TRANSIT)
	_expect(fighter._flight_motion.current_maneuver == Flight.Maneuver.NONE, "Interrupted flight cannot keep displaying the previous maneuver")
	await _cleanup()
	var tank := _spawn("tank", 4) as TankEnemy3D
	_place_player(Vector2(0, 120))
	tank._brace_cooldown = 0.0
	tank._physics_process(0.01)
	_expect(tank.state == BasicEnemy3D.State.BRACE and tank._flight_motion.current_maneuver == Flight.Maneuver.BANK_REVERSAL, "Tank brace state owns its bank reversal")
	tank._begin_withdraw()
	_expect(not tank._braced, "Leaving brace restores the armor behavior")
	await _cleanup()


func _check_bomber_windup() -> void:
	_place_player(Vector2(0, 400))
	var bomber := _spawn("bomber", 2) as BomberEnemy3D
	bomber._drop_timer = 0.41
	var bombs := [0]
	bomber.bomb_dropped.connect(func(): bombs[0] += 1)
	bomber._physics_process(0.02)
	_expect(bomber.state == BasicEnemy3D.State.BOMB_WINDUP and bombs[0] == 0, "Ordinary bombs have a real windup state before release")
	bomber._physics_process(0.39)
	_expect(bombs[0] == 0 and bomber._motions[0].current_clip == &"windup", "Ordinary bomb warning holds for its complete interval")
	bomber._physics_process(0.02)
	_expect(bombs[0] == 1 and bomber.state == BasicEnemy3D.State.TRANSIT and bomber._motions[0].current_clip == &"attack", "Bomb release returns to transit without canceling the payload recoil")
	await _cleanup()


func _check_sniper_rail_commitment() -> void:
	for interrupted in [false, true]:
		_place_player(Vector2(0, 350))
		var sniper := _spawn("sniper", 4) as SniperEnemy3D
		sniper._shoot_timer = 0.0
		sniper._visible_time = 1.0
		sniper._ordinary_shots = 3
		sniper._physics_process(0.01) # ENTRY -> HOLD
		sniper._physics_process(0.01) # HOLD -> RAIL_AIM
		_expect(sniper.state == BasicEnemy3D.State.RAIL_AIM and is_instance_valid(sniper._rail), "Rail windup is a committed sniper FSM state")
		if not is_instance_valid(sniper._rail):
			await _cleanup()
			continue
		var rail := sniper._rail
		rail.set_physics_process(false)
		_place_player(Vector2(0, 80))
		sniper._physics_process(0.3)
		_expect(sniper.state == BasicEnemy3D.State.RAIL_AIM, "Closing pressure cannot start a wingover during an advertised rail shot")
		if interrupted:
			sniper._begin_withdraw()
			_expect(not rail.is_active and sniper._rail == null, "Interrupted rail aim cancels the pooled warning immediately")
		else:
			rail._physics_process(0.91)
			sniper._physics_process(0.01)
			_expect(rail.fired and sniper.state == BasicEnemy3D.State.HOLD and sniper._motions[0].current_clip == &"attack", "The actual rail release ends the committed state while preserving recoil")
		hazard_manager.clear_hazards()
		await _cleanup()
