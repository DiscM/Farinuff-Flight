extends Native3DGameplay
## Behavioral contracts for the regular-enemy finite-state machines: state
## boundaries, one-boundary-per-tick, smarter reactions, constant strafing
## flight, and debug reporting.
const BasicScene := preload("res://entities/enemies/basic_enemy_3d.tscn")
const FastScene := preload("res://entities/enemies/fast_enemy_3d.tscn")
const BomberScene := preload("res://entities/enemies/bomber_enemy_3d.tscn")
const TankScene := preload("res://entities/enemies/tank_enemy_3d.tscn")
const SniperScene := preload("res://entities/enemies/sniper_enemy_3d.tscn")
const CourierScene := preload("res://entities/enemies/courier_enemy_3d.tscn")

var _failures: Array[String] = []
var _transitions := 0


func _ready() -> void:
	await super._ready()
	_run.call_deferred()


func _run() -> void:
	player.set_physics_process(false)
	player.set_dev_god_mode(true)
	GameManager.is_game_active = true
	flight_space._physics_process(0.0)
	await _check_basic_charge_cycle()
	await _check_basic_evade()
	await _check_fast_phase_cycle()
	await _check_sniper_station_keeping()
	await _check_bomber_deploy_cycle()
	await _check_tank_pressure_cycle()
	await _check_constant_strafing_motion()
	await _check_courier_transit()
	await ResourceCache.wait_for_scene("res://scenes/native_3d_run.tscn")
	for failure in _failures:
		push_error(failure)
	print("ENEMY_FSM_SMOKE_PASS" if _failures.is_empty() else "ENEMY_FSM_SMOKE_FAIL")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _spawn(scene: PackedScene, generation: int) -> BasicEnemy3D:
	var enemy := scene.instantiate() as BasicEnemy3D
	actors_root.add_child(enemy)
	var bounds: Rect2 = flight_space.get_combat_bounds()
	var origin := Vector3(bounds.get_center().x, 0.0, bounds.get_center().y)
	enemy.activate_generation(flight_space, origin, Vector3.FORWARD, generation)
	enemy.set_physics_process(false)
	enemy.state_changed.connect(func(_from, _to): _transitions += 1)
	return enemy


func _place_player_near(enemy: BasicEnemy3D, pixels: float) -> void:
	var offset := flight_space.screen_motion_to_combat(Vector2(0.0, pixels))
	player.global_position = enemy.global_position + offset
	enemy._observe_player()


func _check_basic_charge_cycle() -> void:
	var enemy := _spawn(BasicScene, 3)
	_place_player_near(enemy, 120.0)
	enemy._time_alive = 1.0
	_expect(enemy.state == BasicEnemy3D.State.TRANSIT, "Basic starts in TRANSIT")
	_expect(enemy._try_begin_charge(), "Closing player commits the Generation III charge")
	_expect(enemy.state == BasicEnemy3D.State.CHARGE_WINDUP, "Charge opens with its telegraph state")
	_expect(
		enemy.get_debug_state()["state"] == "CHARGE_WINDUP",
		"Debug state reports the charge windup"
	)
	_transitions = 0
	enemy._advance_movement(4.0)
	_expect(
		enemy.state == BasicEnemy3D.State.CHARGE and _transitions == 1,
		"A long frame crosses one state boundary only"
	)
	enemy.state_remaining = 0.0
	enemy._advance_movement(0.016)
	_expect(enemy.state == BasicEnemy3D.State.RECOVERY, "Released charge enters a brief recovery")
	enemy.state_remaining = 0.0
	enemy._advance_movement(0.016)
	_expect(enemy.state == BasicEnemy3D.State.TRANSIT, "Recovery returns to TRANSIT")
	_expect(not enemy._try_begin_charge(), "Charge stays single-use per activation")
	enemy.queue_free()
	await get_tree().process_frame


func _check_basic_evade() -> void:
	var enemy := _spawn(BasicScene, 3)
	var bounds: Rect2 = flight_space.get_combat_bounds()
	var shot_direction := flight_space.input_to_combat_direction(Vector2(0.0, -1.0))
	var ahead := enemy.global_position + flight_space.screen_motion_to_combat(Vector2(0.0, 70.0))
	ahead.x = clampf(ahead.x, bounds.position.x + 4.0, bounds.end.x - 4.0)
	ahead.z = clampf(ahead.z, bounds.position.y + 4.0, bounds.end.y - 4.0)
	projectile_manager.fire_player_projectile(ahead, shot_direction)
	var shots := get_tree().get_nodes_in_group(&"player_projectiles")
	_expect(not shots.is_empty(), "A live Player Projectile is available to the threat scan")
	enemy._evade_cooldown = 0.0
	enemy._evade_scan_timer = 0.0
	enemy._time_alive = 1.0
	_expect(enemy._try_begin_evade(), "Incoming fire triggers the Generation III evade")
	_expect(enemy.state == BasicEnemy3D.State.EVADE, "Evade is an explicit state")
	enemy.state_remaining = 0.0
	enemy._advance_movement(0.016)
	_expect(enemy.state == BasicEnemy3D.State.TRANSIT, "Evade resolves back into TRANSIT")
	projectile_manager.clear_player_projectiles()
	enemy.queue_free()
	await get_tree().process_frame


func _check_fast_phase_cycle() -> void:
	var enemy := _spawn(FastScene, 4)
	enemy._visible_time = 1.0
	enemy._phase_cooldown = 0.0
	_expect(enemy._try_begin_phase(), "Generation IV opens a phase dash")
	_expect(
		enemy.state == BasicEnemy3D.State.PHASE_WINDUP,
		"Phase dash announces its warning state"
	)
	enemy.state_remaining = 0.0
	enemy._advance_movement(0.016)
	_expect(enemy.state == BasicEnemy3D.State.PHASE_DASH, "Warning releases into the dash")
	enemy.state_remaining = 0.0
	enemy._advance_movement(0.016)
	_expect(enemy.state == BasicEnemy3D.State.REPOSITION, "Dash finishes with a re-approach")
	enemy.state_remaining = 0.0
	enemy._advance_movement(0.016)
	_expect(enemy.state == BasicEnemy3D.State.TRANSIT, "Re-approach returns to the strafe")
	_expect(enemy.get_debug_state()["state"] == "TRANSIT", "Debug state reports the strafe")
	enemy.queue_free()
	await get_tree().process_frame


func _check_sniper_station_keeping() -> void:
	var enemy := _spawn(SniperScene, 2)
	_expect(enemy.state == BasicEnemy3D.State.ENTRY, "Sniper begins its entry travel")
	_place_player_near(enemy, 300.0)
	enemy._advance_movement(0.016)
	_expect(enemy.state == BasicEnemy3D.State.HOLD, "Closing to the ring opens the hold strafe")
	_place_player_near(enemy, 180.0)
	enemy._advance_movement(0.016)
	_expect(
		enemy.state == BasicEnemy3D.State.REPOSITION,
		"A closing player forces range-keeping reposition"
	)
	var widened: float = enemy._strafe_radius
	enemy.state_remaining = 0.0
	enemy._advance_movement(0.016)
	_expect(enemy.state == BasicEnemy3D.State.HOLD, "Reposition settles back into a hold strafe")
	_expect(widened >= 330.0, "Reposition widens the standoff ring")
	enemy._locked_direction = Vector3.FORWARD
	enemy._enter(BasicEnemy3D.State.AIM, 0.0)
	enemy._advance_movement(0.016)
	_expect(enemy.state == BasicEnemy3D.State.HOLD, "Released aim returns to HOLD")
	enemy.max_health = 100
	enemy.health = 20
	_expect(
		enemy._hold_break_distance_pixels() > 260.0,
		"A wounded sniper keeps the player farther out"
	)
	enemy._engagement_timer = 0.0
	enemy._advance_movement(0.016)
	_expect(enemy.state == BasicEnemy3D.State.WITHDRAW, "Expired hold withdraws the sniper")
	_expect(enemy.get_attack_status()["holding"] == false, "Attack status reports the withdrawal")
	enemy.queue_free()
	await get_tree().process_frame


func _check_bomber_deploy_cycle() -> void:
	var enemy := _spawn(BomberScene, 2)
	enemy.configure_hazard_manager(hazard_manager)
	_expect(enemy.state == BasicEnemy3D.State.TRANSIT, "Bomber runs its bomb pass in TRANSIT")
	enemy._mine_timer = 0.0
	enemy._time_alive = 1.0
	enemy._advance_movement(0.016)
	_expect(
		enemy.state == BasicEnemy3D.State.MINE_DEPLOY,
		"Mine timer opens an explicit deploy state"
	)
	enemy.state_remaining = 0.0
	enemy._advance_movement(0.016)
	_expect(enemy.state == BasicEnemy3D.State.TRANSIT, "Deploy resolves back into the bomb pass")
	enemy.queue_free()
	await get_tree().process_frame


func _check_tank_pressure_cycle() -> void:
	var enemy := _spawn(TankScene, 4)
	var full_interval: float = enemy._overload_interval_seconds()
	enemy.health = maxi(1, enemy.max_health / 5)
	_expect(
		enemy._overload_interval_seconds() < full_interval,
		"A damaged tank overloads sooner"
	)
	enemy.health = enemy.max_health
	_place_player_near(enemy, 120.0)
	enemy._brace_cooldown = 0.0
	enemy._advance_movement(0.016)
	_expect(enemy.state == BasicEnemy3D.State.BRACE, "Close-range pressure braces the armor")
	_expect(enemy._braced, "Brace tightens the plate orbit")
	enemy.state_remaining = 0.0
	enemy._advance_movement(0.016)
	_expect(
		enemy.state == BasicEnemy3D.State.TRANSIT and not enemy._braced,
		"Brace releases back into TRANSIT"
	)
	enemy._burst_timer = 0.0
	enemy._advance_movement(0.016)
	_expect(enemy.state == BasicEnemy3D.State.BARRAGE, "Burst timer opens the barrage windup")
	enemy.state_remaining = 0.0
	enemy._advance_movement(0.016)
	_expect(enemy.state == BasicEnemy3D.State.TRANSIT, "Barrage resolves back into TRANSIT")
	enemy.queue_free()
	await get_tree().process_frame


func _check_constant_strafing_motion() -> void:
	var scenes := {
		"basic": [BasicScene, 3],
		"fast": [FastScene, 4],
		"bomber": [BomberScene, 3],
		"tank": [TankScene, 4],
		"sniper": [SniperScene, 2],
	}
	for role in scenes:
		var scene: PackedScene = scenes[role][0]
		var generation: int = scenes[role][1]
		var enemy := _spawn(scene, generation)
		_place_player_near(enemy, 220.0)
		enemy._engagement_timer = 30.0
		enemy._time_alive = 1.0
		enemy._charge_used = true
		enemy._evade_cooldown = 99.0
		if enemy is TankEnemy3D:
			(enemy as TankEnemy3D)._brace_cooldown = 99.0
		if enemy is TankEnemy3D:
			(enemy as TankEnemy3D)._burst_timer = 99.0
			(enemy as TankEnemy3D)._overload_timer = 99.0
			(enemy as TankEnemy3D)._visible_time = 1.0
		if enemy is BomberEnemy3D:
			(enemy as BomberEnemy3D)._drop_timer = 99.0
			(enemy as BomberEnemy3D)._mine_timer = 99.0
		if enemy is SniperEnemy3D:
			(enemy as SniperEnemy3D)._shoot_timer = 99.0
			(enemy as SniperEnemy3D)._visible_time = 1.0
		if enemy is FastEnemy3D:
			(enemy as FastEnemy3D)._phase_cooldown = 99.0
			(enemy as FastEnemy3D)._visible_time = 1.0
		var states: Array = [BasicEnemy3D.State.TRANSIT]
		if role == "basic":
			states.append_array([
				BasicEnemy3D.State.CHARGE_WINDUP,
				BasicEnemy3D.State.EVADE,
				BasicEnemy3D.State.RECOVERY,
				BasicEnemy3D.State.WITHDRAW,
			])
		elif role == "fast":
			states.append_array([
				BasicEnemy3D.State.EVADE,
				BasicEnemy3D.State.PHASE_WINDUP,
				BasicEnemy3D.State.REPOSITION,
				BasicEnemy3D.State.WITHDRAW,
			])
		elif role == "bomber":
			states.append_array([
				BasicEnemy3D.State.MINE_DEPLOY,
				BasicEnemy3D.State.EVADE,
				BasicEnemy3D.State.WITHDRAW,
			])
		elif role == "tank":
			states.append_array([
				BasicEnemy3D.State.BARRAGE,
				BasicEnemy3D.State.BRACE,
				BasicEnemy3D.State.OVERLOAD_WINDUP,
				BasicEnemy3D.State.OVERLOAD,
				BasicEnemy3D.State.RECOVERY,
				BasicEnemy3D.State.WITHDRAW,
			])
		elif role == "sniper":
			states.append_array([
				BasicEnemy3D.State.HOLD,
				BasicEnemy3D.State.AIM,
				BasicEnemy3D.State.REPOSITION,
				BasicEnemy3D.State.WITHDRAW,
			])
		for next_state in states:
			enemy.state = next_state
			enemy.state_remaining = 3.0
			if next_state == BasicEnemy3D.State.OVERLOAD:
				(enemy as TankEnemy3D)._overload_step_timer = 99.0
			if next_state == BasicEnemy3D.State.AIM:
				enemy.state_remaining = 99.0
			if next_state == BasicEnemy3D.State.WITHDRAW:
				enemy.velocity = flight_space.screen_motion_to_combat(Vector2(0.0, 200.0))
			var before := enemy.global_position
			for step in 12:
				if next_state == BasicEnemy3D.State.WITHDRAW:
					enemy._integrate_velocity(1.0 / 60.0)
				else:
					enemy._advance_movement(1.0 / 60.0)
			var traveled := enemy.global_position.distance_to(before)
			_expect(
				traveled > 0.5,
				"%s keeps flying through %s (moved %.2f)" % [role, BasicEnemy3D.State.keys()[next_state], traveled]
			)
		enemy.queue_free()
		await get_tree().process_frame


func _check_courier_transit() -> void:
	var enemy := _spawn(CourierScene, 1)
	var start := enemy.global_position
	enemy._advance_movement(0.1)
	_expect(enemy.global_position != start, "Courier keeps its uninterrupted transit")
	_expect(not enemy.should_drop_xp_orb(), "Courier still withholds orb drops")
	enemy.queue_free()
	await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
