extends Native3DGameplay
## Exercise combat effects through the real enemy, collision router and pools.
const Flight := preload("res://effects/enemy_flight_motion_3d.gd")
const Shot := preload("res://entities/projectiles/projectile_3d.gd")
const ENEMIES := {
	"basic": preload("res://entities/enemies/basic_enemy_3d.tscn"),
	"fast": preload("res://entities/enemies/fast_enemy_3d.tscn"),
	"bomber": preload("res://entities/enemies/bomber_enemy_3d.tscn"),
	"tank": preload("res://entities/enemies/tank_enemy_3d.tscn"),
	"sniper": preload("res://entities/enemies/sniper_enemy_3d.tscn"),
}
var _failures: Array[String] = []
var _explosions := 0


func _ready() -> void:
	projectile_manager.enemy_pool_size = 16
	projectile_manager.player_pool_size = 32
	await super._ready()
	_run.call_deferred()


func _run() -> void:
	player.set_physics_process(false)
	player.set_dev_god_mode(true)
	player.global_position = flight_space.screen_motion_to_combat(Vector2(300, 300))
	GameManager.is_game_active = true
	# Let the physics server and relative-motion snapshot settle after fixture
	# placement; teleporting the player must not count as crossing a new shot.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var previous_reduced: bool = SaveManager.get_setting("reduced_motion", false)
	SaveManager.settings["reduced_motion"] = false
	projectile_manager.explosion_requested.connect(func(_position, _target): _explosions += 1)
	await _check_reflect_lifecycle()
	await _check_reflect_limits()
	await _check_clear_and_pool_pressure()
	for role in ["basic", "fast"]:
		await _check_physical_dodge(role)
	await _check_roles()
	await _check_pause_and_reduced_motion()
	SaveManager.settings["reduced_motion"] = previous_reduced
	await ResourceCache.wait_for_scene("res://scenes/native_3d_run.tscn")
	for failure in _failures:
		push_error(failure)
	print("ENEMY_MANEUVER_SMOKE_PASS" if _failures.is_empty() else "ENEMY_MANEUVER_SMOKE_FAIL")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _spawn(role: String, generation: int = 3) -> BasicEnemy3D:
	var enemy := (ENEMIES[role] as PackedScene).instantiate() as BasicEnemy3D
	actors_root.add_child(enemy)
	enemy.activate_generation(flight_space, Vector3.ZERO, Vector3.FORWARD, generation)
	enemy.set_physics_process(false)
	enemy.health = 100
	enemy.max_health = 100
	enemy._time_alive = 1.0
	enemy._charge_used = true
	enemy._engagement_timer = 30.0
	return enemy


func _incoming(enemy: BasicEnemy3D, distance: float = 450.0) -> Shot:
	var offset := flight_space.screen_motion_to_combat(Vector2(0.0, distance))
	projectile_manager.fire_player_projectile(enemy.global_position + offset, -offset)
	var shot: Shot = projectile_manager._pools[Shot.Kind.PLAYER].checked_out.back()
	shot.set_physics_process(false)
	return shot


func _hostile() -> Shot:
	for shot: Shot in projectile_manager._pools[Shot.Kind.ENEMY].checked_out:
		if shot.is_active and not shot.is_deflected:
			shot.set_physics_process(false)
			return shot
	return null


func _arm_reflect(enemy: BasicEnemy3D) -> void:
	var threat := _incoming(enemy)
	enemy._prefer_reflect = true
	_expect(enemy._try_begin_defense(), "Incoming fire selects the aileron defense")
	_expect(enemy.state == BasicEnemy3D.State.REFLECT_WINDUP and not enemy.can_reflect_projectile(), "Reflect starts with a vulnerable warning")
	threat.despawn()
	enemy._advance_movement(BasicEnemy3D.REFLECT_WARNING_SECONDS)
	_expect(enemy.can_reflect_projectile(), "Only the released roll arms reflection")
	if not SaveManager.get_setting("reduced_motion", false):
		_expect(enemy._flight_motion.current_maneuver == Flight.Maneuver.AILERON_ROLL, "Reflection is represented by an aileron roll")


func _check_reflect_lifecycle() -> void:
	var enemy := _spawn("basic", 2)
	var threat := _incoming(enemy)
	enemy._prefer_reflect = true
	_expect(enemy._try_begin_defense(), "Generation II fighter anticipates incoming fire")
	var health_before := enemy.health
	threat._report_hit(enemy, enemy.global_position)
	_expect(enemy.health < health_before and projectile_manager._pending_reflections == 0, "A shot during windup damages the fighter normally")
	enemy._advance_movement(BasicEnemy3D.REFLECT_WARNING_SECONDS)
	var shot := _incoming(enemy)
	var inbound := shot.velocity
	shot.piercing = true
	shot.explosive = true
	shot.homing = true
	health_before = enemy.health
	var explosions_before := _explosions
	shot._report_hit(enemy, enemy.global_position)
	_expect(not shot.is_active and enemy.health == health_before, "Active roll consumes an upgraded shot without hull damage")
	_expect(_explosions == explosions_before, "A reflected explosive shot cannot also explode on the defender")
	await get_tree().process_frame
	await get_tree().process_frame
	var returned := _hostile()
	_expect(returned != null, "Reflection emits a real hostile projectile from the enemy pool")
	if returned != null:
		_expect(returned.velocity.normalized().dot(inbound.normalized()) < -0.99, "The returned shot retraces the incoming direction")
		var speed := flight_space.combat_motion_to_screen(returned.velocity).length()
		_expect(speed >= 319.9 and speed <= 520.1, "Returned fire has bounded readable speed")
		_expect(not returned.piercing and not returned.explosive and not returned.homing and returned.damage == 1, "Player upgrades cannot leak into hostile payloads")
		player.set_dev_god_mode(false)
		player.reset_damage_state()
		var lives := GameManager.lives
		returned._report_hit(player, player.global_position)
		_expect(GameManager.lives == lives - 1, "Returned player fire can actually damage the player")
		player.set_dev_god_mode(true)
		player.reset_damage_state()
		GameManager.lives = lives
	shot = _incoming(enemy)
	shot._report_hit(enemy, enemy.global_position)
	await get_tree().process_frame
	await get_tree().process_frame
	returned = _hostile()
	_expect(returned != null, "A second reflected shot is available for the boost counter")
	if returned != null:
		player._begin_boost()
		var redirected := returned._report_hit(player, player.global_position)
		_expect(redirected and returned.is_active and returned.is_deflected, "Boost can counter-reflect the returned shot through the real contact route")
		health_before = enemy.health
		var charges := enemy._reflect_charges
		returned._report_hit(enemy, enemy.global_position)
		_expect(enemy.health == health_before - 2 and enemy._reflect_charges == charges, "Boost counters pierce the reflect defense without an infinite reflection loop")
		player.is_boosting = false
	await _cleanup(enemy)


func _check_reflect_limits() -> void:
	var enemy := _spawn("fast")
	_arm_reflect(enemy)
	for index in BasicEnemy3D.REFLECT_MAX_SHOTS:
		var shot := _incoming(enemy)
		shot._report_hit(enemy, enemy.global_position)
	_expect(enemy.state == BasicEnemy3D.State.TRANSIT and not enemy.can_reflect_projectile(), "Three reflections end the roll directly into normal flight")
	_expect(not enemy._reflect_tell.visible, "Exhausted defense clears its reflection tell")
	var health_before := enemy.health
	_incoming(enemy)._report_hit(enemy, enemy.global_position)
	_expect(enemy.health < health_before, "The exhausted roll leaves the moving fighter vulnerable")
	_expect(not enemy._try_begin_defense(), "Shared cooldown prevents consecutive defenses")
	await _cleanup(enemy)
	# Time alone ends the defense, even when no shot touches it.
	enemy = _spawn("basic")
	_arm_reflect(enemy)
	enemy._advance_movement(BasicEnemy3D.REFLECT_ROLL_SECONDS)
	_expect(not enemy.can_reflect_projectile(), "Reflection expires after its fixed active window")
	await _cleanup(enemy)
	enemy = _spawn("basic", 1)
	var threat := _incoming(enemy)
	_expect(not enemy._try_begin_reflect(threat), "Introductory Generation I fighters do not gain reflect defenses")
	await _cleanup(enemy)


func _check_clear_and_pool_pressure() -> void:
	var enemy := _spawn("basic")
	_arm_reflect(enemy)
	_incoming(enemy)._report_hit(enemy, enemy.global_position)
	projectile_manager.clear_projectiles()
	await get_tree().process_frame
	_expect(_hostile() == null and projectile_manager._pending_reflections == 0, "Clearing a wave cancels queued reflected shots")
	var pool = projectile_manager._pools[Shot.Kind.ENEMY]
	for index in pool.warmed_ids.size():
		projectile_manager.fire_enemy_projectile(Vector3.ZERO, Vector3.FORWARD)
		pool.checked_out.back().set_physics_process(false)
	var health_before := enemy.health
	var charges := enemy._reflect_charges
	_incoming(enemy)._report_hit(enemy, enemy.global_position)
	_expect(enemy.health < health_before and enemy._reflect_charges == charges, "A saturated hostile pool fails open to normal damage")
	_expect(pool.checked_out.size() == pool.warmed_ids.size() and pool.pool_growth == 0, "Reflection respects pool capacity without allocating extra shots")
	await _cleanup(enemy)
	projectile_manager.fire_player_projectile(Vector3.ZERO, Vector3.FORWARD)
	var reused: Shot = projectile_manager._pools[Shot.Kind.PLAYER].checked_out.back()
	_expect(reused.kind == Shot.Kind.PLAYER and reused.is_in_group(&"player_projectiles") and not reused.is_deflected, "Reused source projectile retains the player faction")
	projectile_manager.clear_projectiles()
	await get_tree().process_frame


func _check_physical_dodge(role: String) -> void:
	var enemy := _spawn(role)
	var incoming := _incoming(enemy, 300.0)
	var origin := enemy.global_position
	var collider_origin := enemy.collision_shape.global_position
	_expect(enemy._try_begin_evade(), role + " selects a physical barrel dodge")
	_expect(enemy.global_position.is_equal_approx(origin), role + " does not teleport on dodge entry")
	var destination := enemy._maneuver_target
	var duration := enemy.state_remaining
	enemy._physics_process(duration * 0.35)
	var moved := enemy.global_position - origin
	_expect(moved.length() > 0.2 and moved.length() < origin.distance_to(destination), role + " travels through intermediate positions")
	_expect((enemy.collision_shape.global_position - collider_origin).is_equal_approx(moved), role + " dodge moves the real contact envelope with the ship")
	_expect(enemy.collision_shape.disabled == false and enemy.collision_layer != 0, role + " remains hittable throughout its dodge")
	enemy._physics_process(duration * 0.65 + 0.001)
	_expect(enemy.global_position.distance_to(destination) < 0.001, role + " finishes at the committed new lane")
	var health_before := enemy.health
	await get_tree().physics_frame
	await get_tree().physics_frame
	incoming._sweep_motion(incoming.velocity * 0.5)
	_expect(incoming.is_active and enemy.health == health_before, role + " physically clears the original bullet lane")
	_incoming(enemy, 75.0)._report_hit(enemy, enemy.global_position)
	_expect(enemy.health < health_before, role + " can be hit at its new position")
	await _cleanup(enemy)
	# Advance both actors on the real physics clock: the dodge must be early
	# enough to avoid a moving shot, not merely finish outside a frozen lane.
	enemy = _spawn(role)
	incoming = _incoming(enemy, 300.0)
	enemy._prefer_reflect = false
	_expect(enemy._try_begin_defense() and enemy.state == BasicEnemy3D.State.EVADE, role + " chooses dodge when reflection is not preferred")
	health_before = enemy.health
	enemy.set_physics_process(true)
	incoming.set_physics_process(true)
	for tick in 45:
		await get_tree().physics_frame
	enemy.set_physics_process(false)
	incoming.set_physics_process(false)
	_expect(incoming.is_active and enemy.health == health_before, role + " dodges a moving projectile at combat speed")
	await _cleanup(enemy)
	# Boundary case: the full hitbox, including its corners, stays in bounds.
	enemy = _spawn(role)
	var bounds := flight_space.get_combat_bounds()
	enemy.global_position = Vector3(bounds.end.x - 18.0, 0, 0)
	_incoming(enemy, 75.0)
	_expect(enemy._try_begin_evade(), role + " selects the available lane near an arena edge")
	for tick in 45:
		if enemy.state != BasicEnemy3D.State.EVADE:
			break
		enemy._physics_process(1.0 / 60.0)
		var half := enemy._maneuver_half_extents()
		var footprint := Rect2(Vector2(enemy.global_position.x - half.x, enemy.global_position.z - half.z), Vector2(half.x, half.z) * 2.0)
		_expect(bounds.encloses(footprint), role + " curved dodge keeps the hitbox inside the arena")
	await _cleanup(enemy)


func _check_roles() -> void:
	var sniper := _spawn("sniper") as SniperEnemy3D
	player.global_position = flight_space.screen_motion_to_combat(Vector2(0, 180))
	sniper._observe_player()
	var distance_before := sniper._player_distance_pixels
	sniper._begin_reposition()
	for tick in 55:
		sniper._physics_process(1.0 / 60.0)
	var distance_after := flight_space.combat_motion_to_screen(sniper.global_position - player.global_position).length()
	_expect(distance_after > distance_before + 100.0, "Sniper wingover physically opens firing distance")
	await _cleanup(sniper)
	var bomber := _spawn("bomber") as BomberEnemy3D
	bomber._drop_timer = 1.5
	_incoming(bomber, 75.0)
	var direction_before := bomber._strafe_sign
	_expect(bomber._try_begin_drift_evade(), "Bomber reacts with a bank reversal")
	_expect(bomber._strafe_sign == -direction_before, "Bomber bank reversal changes its orbit direction")
	bomber._physics_process(0.45)
	_expect(bomber.global_position.length() > 1.0, "Bomber bank reversal moves to another lane")
	await _cleanup(bomber)
	var tank := _spawn("tank") as TankEnemy3D
	direction_before = tank._strafe_sign
	tank._begin_brace()
	_expect(tank._strafe_sign == -direction_before and tank._flight_motion.current_maneuver == Flight.Maneuver.BANK_REVERSAL, "Tank banks into its defensive reversal")
	for plate in tank._armor_plates:
		_expect(is_equal_approx(plate.orbit_radius_pixels, tank._plate_base_radius * TankEnemy3D.BRACE_ORBIT_SCALE) and signf(plate.orbit_speed_degrees) == tank._strafe_sign, "Tank reversal draws armor inward and changes its moving coverage")
	await _cleanup(tank)
	var fast := _spawn("fast", 4) as FastEnemy3D
	fast._phase_cooldown = 0.0
	_expect(fast._try_begin_phase(), "Fast fighter commits its spin flank")
	fast._physics_process(FastEnemy3D.PHASE_WARNING_SECONDS)
	var origin := fast.global_position
	direction_before = fast._strafe_sign
	for tick in 34:
		fast._physics_process(1.0 / 60.0)
	_expect(fast.global_position.distance_to(origin) > 5.0 and fast._strafe_sign == -direction_before, "Spin moves the fighter to the flank and reverses its next approach")
	_expect(fast.state == BasicEnemy3D.State.TRANSIT and fast._flight_motion.current_maneuver == Flight.Maneuver.NONE, "Spin flank resumes normal flight without a recovery")
	await _cleanup(fast)


func _check_pause_and_reduced_motion() -> void:
	var enemy := _spawn("basic")
	SaveManager.settings["reduced_motion"] = true
	enemy.advance_motion(0.01)
	_arm_reflect(enemy)
	enemy.advance_motion(0.2)
	_expect(enemy._flight_motion.pose.is_equal_approx(Transform3D.IDENTITY) and enemy.can_reflect_projectile() and enemy._reflect_tell.visible, "Reduced Motion preserves reflection and its readable tell without a spinning hull")
	var remaining := enemy.state_remaining
	var position_before := enemy.global_position
	get_tree().paused = true
	enemy.set_physics_process(true)
	await get_tree().create_timer(0.06, true).timeout
	_expect(enemy.state_remaining == remaining and enemy.global_position == position_before, "Pause freezes the defensive window and physical movement together")
	enemy.set_physics_process(false)
	get_tree().paused = false
	GameManager.is_game_active = false
	enemy._physics_process(0.3)
	_expect(enemy.state_remaining == remaining, "Inactive gameplay does not spend defense time")
	GameManager.is_game_active = true
	await _cleanup(enemy)


func _cleanup(enemy: BasicEnemy3D) -> void:
	enemy.queue_free()
	projectile_manager.clear_projectiles()
	await get_tree().process_frame
	await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
