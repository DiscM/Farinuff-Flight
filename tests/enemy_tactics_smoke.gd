extends Native3DGameplay
## Exercise decisions, real paths, squad coordination and advertised openings.
const Brain := preload("res://systems/enemy_tactics_3d.gd")
const Flight := preload("res://effects/enemy_flight_motion_3d.gd")
const Shot := preload("res://entities/projectiles/projectile_3d.gd")
const SCENES := {
	"basic": preload("res://entities/enemies/basic_enemy_3d.tscn"),
	"fast": preload("res://entities/enemies/fast_enemy_3d.tscn"),
	"sniper": preload("res://entities/enemies/sniper_enemy_3d.tscn"),
	"tank": preload("res://entities/enemies/tank_enemy_3d.tscn"),
	"bomber": preload("res://entities/enemies/bomber_enemy_3d.tscn"),
}
var _failures: Array[String] = []
var _actors: Array[BasicEnemy3D] = []


func _ready() -> void:
	projectile_manager.player_pool_size = 32
	projectile_manager.enemy_pool_size = 16
	await super._ready()
	_run.call_deferred()


func _run() -> void:
	player.set_physics_process(false)
	player.set_dev_god_mode(true)
	GameManager.is_game_active = true
	_place_player(Vector2(0, 400))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var reduced: bool = SaveManager.get_setting("reduced_motion", false)
	SaveManager.settings["reduced_motion"] = false
	await _check_perception()
	await _check_decisions()
	await _check_commitment_and_memory()
	await _check_squad()
	await _check_paths_and_animation()
	await _check_gameplay_scale()
	await _check_continuous_flight()
	await _check_lifecycle()
	SaveManager.settings["reduced_motion"] = reduced
	await ResourceCache.wait_for_scene("res://scenes/native_3d_run.tscn")
	for failure in _failures:
		push_error(failure)
	print("ENEMY_TACTICS_SMOKE_PASS" if _failures.is_empty() else "ENEMY_TACTICS_SMOKE_FAIL")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _spawn(role_name: String = "basic", generation: int = 3) -> BasicEnemy3D:
	var enemy := (SCENES[role_name] as PackedScene).instantiate() as BasicEnemy3D
	actors_root.add_child(enemy)
	enemy.activate_generation(flight_space, Vector3.ZERO, Vector3.FORWARD, generation)
	enemy.set_physics_process(false)
	enemy.health = 100
	enemy.max_health = 100
	enemy._time_alive = 1.5
	enemy._engagement_timer = 30.0
	enemy._charge_used = true
	enemy._tactics._cooldown = 0.0
	enemy.velocity = Vector3.ZERO
	_actors.append(enemy)
	return enemy


func _place_player(offset: Vector2, motion: Vector2 = Vector2.ZERO, boosting: bool = false) -> void:
	player.global_position = flight_space.screen_motion_to_combat(offset)
	player.velocity = flight_space.screen_motion_to_combat(motion)
	player.is_boosting = boosting
	player.force_update_transform()


func _shot(enemy: BasicEnemy3D, offset: Vector2, heading: Vector2 = Vector2.UP) -> Shot:
	projectile_manager.fire_player_projectile(enemy.global_position + flight_space.screen_motion_to_combat(offset), flight_space.input_to_combat_direction(heading))
	var shot: Shot = projectile_manager._pools[Shot.Kind.PLAYER].checked_out.back()
	shot.set_physics_process(false)
	return shot


func _observe(enemy: BasicEnemy3D) -> void:
	enemy._observe_player()
	enemy._tactics.observe(enemy)


func _check_perception() -> void:
	var enemy := _spawn()
	_shot(enemy, Vector2(170, 250))
	_shot(enemy, Vector2(0, 250), Vector2.DOWN)
	_observe(enemy)
	_expect(enemy._tactics.threat_count == 0 and enemy._find_incoming_projectile() == null, "Shots that miss or travel away do not waste a defensive maneuver")
	_shot(enemy, Vector2(0, 300))
	_observe(enemy)
	_expect(enemy._tactics.threat_count == 1 and enemy._find_incoming_projectile() != null, "Closest-approach prediction recognizes a real collision course")
	enemy.take_damage(25)
	var pressure := enemy._tactics.pressure
	projectile_manager.clear_projectiles()
	await get_tree().process_frame
	await get_tree().process_frame
	enemy._tactics.tick(enemy, 0.5)
	_expect(enemy._tactics.pressure > 0 and enemy._tactics.pressure < pressure, "Recent incoming pressure decays instead of disappearing instantly")
	await _cleanup()


func _check_decisions() -> void:
	_place_player(Vector2(0, 280))
	var enemy := _spawn()
	enemy.health = 30
	_observe(enemy)
	_expect(enemy._try_begin_tactical_maneuver() and enemy.state == BasicEnemy3D.State.SPLIT_S, "A wounded fighter prioritizes a Split-S disengagement")
	var initial_range := enemy._player_distance_pixels
	for tick in 67:
		enemy._physics_process(1.0 / 60.0)
	_expect(flight_space.combat_motion_to_screen(enemy.global_position - player.global_position).length() > initial_range + 120, "Split-S opens actual distance from the player")
	_expect(not enemy.can_reflect_projectile(), "A Split-S is not secretly a reflection or immunity window")
	await _cleanup()

	_place_player(Vector2(0, 280), Vector2(0, -700), true)
	enemy = _spawn("fast")
	_observe(enemy)
	_expect(enemy._try_begin_tactical_maneuver() and enemy.state == BasicEnemy3D.State.SPLIT_S, "A fast fighter responds to a closing boost")
	await _cleanup()
	_place_player(Vector2(0, 400))
	enemy = _spawn()
	for x in [-20, 0, 20]:
		_shot(enemy, Vector2(x, 330))
	_observe(enemy)
	_expect(enemy._try_begin_tactical_maneuver() and enemy.state == BasicEnemy3D.State.SCISSORS, "Sustained fire selects a scissors escape over a routine roll")
	var first := enemy._tactics.sample_path(0.5)
	var last := enemy._tactics.sample_path(1.0)
	_expect(first.x * last.x < 0.0, "Scissors commits a real change of lateral direction")
	await _cleanup()

	enemy = _spawn("basic", 2)
	_observe(enemy)
	_expect(enemy._try_begin_tactical_maneuver() and enemy._tactics.last_action == Brain.Action.IMMELMANN, "An overshooting Generation II fighter chooses an Immelmann pursuit turn")
	_expect(enemy.state == BasicEnemy3D.State.TACTICAL_WINDUP and enemy._tactics._tell.visible, "Pursuit turn previews its committed path")
	var committed := enemy._tactics.sample_path(1.0)
	_place_player(Vector2(-350, 100))
	enemy._physics_process(0.3)
	_expect(enemy.state == BasicEnemy3D.State.IMMELMANN and enemy._tactics.sample_path(1.0) == committed, "Moving the player during the warning cannot retarget the committed endpoint")
	await _cleanup()

	_place_player(Vector2(0, 440), Vector2(160, 0))
	enemy = _spawn("fast")
	enemy._heading = Vector3.BACK
	enemy._tactics.role = 1
	_observe(enemy)
	_expect(enemy._try_begin_tactical_maneuver() and enemy._tactics.last_action == Brain.Action.CORKSCREW, "A flanker uses bounded player prediction to start a corkscrew approach")
	_expect(enemy.state == BasicEnemy3D.State.TACTICAL_WINDUP, "An offensive corkscrew has a warning before movement commits")
	await _cleanup()

	_place_player(Vector2(0, 400))
	var sniper := _spawn("sniper")
	sniper.state = BasicEnemy3D.State.HOLD
	var ally := _spawn()
	ally.global_position = flight_space.screen_motion_to_combat(Vector2(0, 170))
	_observe(sniper)
	_expect(sniper._try_begin_tactical_maneuver() and sniper.state == BasicEnemy3D.State.KNIFE_EDGE, "A sniper banks sideways to clear an ally from its firing lane")
	_expect(absf(flight_space.combat_motion_to_screen(sniper._tactics.sample_path(1)).x) > 150, "Knife-edge commits enough lateral travel to open a new firing angle")
	await _cleanup()

	enemy = _spawn("basic", 1)
	enemy.health = 20
	_observe(enemy)
	_expect(not enemy._try_begin_tactical_maneuver(), "Generation I keeps its introductory behavior")
	await _cleanup()


func _check_commitment_and_memory() -> void:
	_place_player(Vector2(0, 280), Vector2(0, -700), true)
	var enemy := _spawn()
	enemy.health = 20
	_observe(enemy)
	enemy._enter(BasicEnemy3D.State.CHARGE_WINDUP, 0.5)
	_expect(not enemy._try_begin_tactical_maneuver(), "Emergency decisions cannot overwrite a committed charge warning")
	enemy._enter(BasicEnemy3D.State.TRANSIT)
	_expect(enemy._try_begin_tactical_maneuver(), "Defense becomes available after the committed state ends")
	enemy._physics_process(enemy._tactics._duration + 0.001)
	enemy._tactics._cooldown = 0.0
	enemy._evade_cooldown = 0.0
	# Restore the close threat after the successful disengagement.
	player.global_position = enemy.global_position + flight_space.screen_motion_to_combat(Vector2(0, 280))
	_observe(enemy)
	_expect(not enemy._try_begin_tactical_maneuver(), "Repeat memory prevents spamming the same escape even when the general cooldown is cleared")
	await _cleanup()
	_place_player(Vector2(0, 280))
	enemy = _spawn()
	enemy._tactics.role = 2
	enemy.health = 50
	_observe(enemy)
	_expect(enemy._try_begin_tactical_maneuver() and enemy._tactics.last_action == Brain.Action.SPLIT_S, "Cautious pilots disengage earlier as their hull is damaged")
	await _cleanup()
	enemy = _spawn()
	enemy._tactics.role = 0
	enemy.health = 50
	_observe(enemy)
	_expect(enemy._try_begin_tactical_maneuver() and enemy._tactics.last_action == Brain.Action.IMMELMANN, "Pressure pilots keep pursuing under the same damage conditions")
	await _cleanup()


func _check_squad() -> void:
	_place_player(Vector2(0, 220))
	var first := _spawn()
	var second := _spawn("fast", 4)
	var third := _spawn()
	first._charge_used = false
	third._charge_used = false
	_expect(first._try_begin_charge() and second._try_begin_phase(), "Two nearby attackers can commit complementary approaches")
	_expect(not third._try_begin_charge(), "A third attacker leaves an opening instead of stacking another charge")
	first._enter(BasicEnemy3D.State.TRANSIT)
	_expect(third._try_begin_charge(), "An attack slot becomes available when another attacker resumes normal flight")
	await _cleanup()

	_place_player(Vector2(0, 400))
	first = _spawn()
	first._strafe_sign = 1.0
	second = _spawn()
	second.global_position = flight_space.screen_motion_to_combat(Vector2(180, 0))
	_observe(first)
	var lane := first._choose_maneuver_shift(Vector2.RIGHT, 180)
	_expect(lane.x < 0.0, "Maneuver choice favors the unoccupied lane")
	second.global_position = first.global_position
	_observe(first)
	_observe(second)
	_expect(first._tactics.separation.dot(second._tactics.separation) < 0, "Coincident allies choose opposing separation directions")
	await _cleanup()

	var tank := _spawn("tank")
	var wounded := _spawn()
	wounded.health = 25
	wounded.global_position = flight_space.screen_motion_to_combat(Vector2(120, 100))
	_observe(tank)
	var support := tank._tactics.support_position
	_expect(tank._tactics.has_support, "A tank recognizes a nearby wounded ally")
	_expect(support.distance_to(player.global_position) < wounded.global_position.distance_to(player.global_position), "The tank's screening waypoint lies in front of the wounded ally")
	var ordinary_target := Vector3.ZERO
	_expect(tank._tactics.adjust_target(tank, ordinary_target).distance_to(support) < ordinary_target.distance_to(support), "Screening changes the tank's actual steering target")
	await _cleanup()


func _check_gameplay_scale() -> void:
	# Project the real route through both gameplay views at their normal zoom.
	# A motion that passes in world units can still disappear at game scale.
	var previous_view := camera_rig.view_preset
	var was_processing := camera_rig.is_processing()
	camera_rig.set_process(false)
	_place_player(Vector2(0, 440))
	var height := get_viewport().get_visible_rect().size.y
	for view in [Native3DCameraRig.View.OVERHEAD, Native3DCameraRig.View.ANGLED]:
		camera_rig.set_view_preset(view, 0.0)
		for action: Brain.Action in Brain.Action.values():
			if action == Brain.Action.NONE:
				continue
			var role_name := "sniper" if action == Brain.Action.KNIFE_EDGE else ("bomber" if action == Brain.Action.BOMBING_RUN else "fast")
			for direction in [-1.0, 1.0]:
				var enemy := _spawn(role_name, 4)
				enemy._strafe_sign = direction
				if role_name == "sniper":
					enemy._enter(BasicEnemy3D.State.HOLD)
				_observe(enemy)
				var started := enemy._begin_tactical_maneuver(action, "normal camera readability")
				_expect(started, "Every supported maneuver has room at the center of the real arena")
				if started:
					var projected := Rect2(flight_space.combat_to_screen(enemy.global_position), Vector2.ZERO)
					for sample in 61:
						projected = projected.expand(flight_space.combat_to_screen(enemy._tactics.sample_path(float(sample) / 60.0)))
					_expect(projected.size.length() >= height * 0.07, Brain.Action.keys()[action] + " crosses a readable span at normal zoom in both views and directions")
				await _cleanup()
	camera_rig.set_view_preset(previous_view, 0.0)
	camera_rig.set_process(was_processing)


func _check_continuous_flight() -> void:
	for step in [1.0 / 30.0, 1.0 / 120.0]:
		for action: Brain.Action in Brain.Action.values():
			if action == Brain.Action.NONE:
				continue
			_place_player(Vector2(0, 440))
			var role_name := "sniper" if action == Brain.Action.KNIFE_EDGE else ("bomber" if action == Brain.Action.BOMBING_RUN else "fast")
			var enemy := _spawn(role_name, 4)
			enemy.velocity = enemy._cruise_velocity(enemy._heading)
			if role_name == "sniper":
				enemy._enter(BasicEnemy3D.State.HOLD)
				enemy._shoot_timer = 99.0
			_observe(enemy)
			var began := enemy._begin_tactical_maneuver(action, "continuous flight probe")
			_expect(began, "A moving craft can commit every supported route")
			if not began:
				await _cleanup()
				continue
			if enemy.state == BasicEnemy3D.State.TACTICAL_WINDUP:
				enemy._physics_process(enemy.state_remaining)
			var brain := enemy._tactics
			var epsilon := 0.0001 / brain._duration
			var starting_velocity := (brain.sample_path(epsilon) - brain.sample_path(0.0)) / 0.0001
			_expect(starting_velocity.distance_to(enemy.velocity) < 0.03 * enemy.velocity.length(), "Route entry preserves incoming velocity instead of stopping the craft")
			if action == Brain.Action.SCISSORS:
				var incoming := (brain.sample_path(0.5) - brain.sample_path(0.5 - epsilon)) / 0.0001
				var outgoing := (brain.sample_path(0.5 + epsilon) - brain.sample_path(0.5)) / 0.0001
				_expect(incoming.length() > enemy.velocity.length() * 0.5 and incoming.distance_to(outgoing) < incoming.length() * 0.03, "Scissors carries momentum through the change of direction")
			var final_velocity := (brain.sample_path(1.0) - brain.sample_path(1.0 - epsilon)) / 0.0001
			_expect(flight_space.combat_motion_to_screen(final_velocity).length() > enemy._speed_pixels * 0.8, "Route exit retains cruise momentum")
			for tick in 360:
				if not brain.has_plan():
					break
				enemy._physics_process(step)
			_expect(enemy.state == enemy._maneuver_entry_state(), "Every flight returns directly to its normal behavior")
			var exit_velocity := enemy.velocity
			var heading := enemy.rotation.y
			var position_before := enemy.global_position
			enemy._physics_process(step)
			_expect(enemy.global_position.distance_to(position_before) > 0.001, "Normal movement continues on the very next frame")
			_expect(enemy.velocity.distance_to(exit_velocity) < exit_velocity.length() * 0.3, "Flight-to-cruise does not snap velocity")
			_expect(absf(angle_difference(heading, enemy.rotation.y)) < 0.25, "Flight-to-cruise does not snap heading")
			await _cleanup()


func _check_paths_and_animation() -> void:
	_place_player(Vector2(0, 420))
	for scenario in 10:
		var action: Brain.Action = [Brain.Action.SPLIT_S, Brain.Action.IMMELMANN, Brain.Action.SCISSORS, Brain.Action.CORKSCREW, Brain.Action.KNIFE_EDGE][scenario % 5]
		var near_edge := scenario >= 5
		var enemy := _spawn("sniper" if action == Brain.Action.KNIFE_EDGE else "fast")
		_observe(enemy)
		var bounds := flight_space.get_combat_bounds()
		var size: Vector3 = (enemy.collision_shape.shape as BoxShape3D).size * enemy.collision_shape.global_basis.get_scale() * 0.5
		var radius := Vector2(size.x, size.z).length()
		if near_edge:
			enemy.global_position.x = bounds.end.x - radius - 2.0
		_observe(enemy)
		var origin := enemy.global_position
		if action == Brain.Action.KNIFE_EDGE:
			enemy._enter(BasicEnemy3D.State.HOLD)
		var started := enemy._begin_tactical_maneuver(action, "boundary probe")
		if not started:
			_expect(near_edge and not enemy._tactics.has_plan() and enemy.global_position == origin, "An edge that leaves too little travel safely rejects the maneuver")
			await _cleanup()
			continue
		_expect(enemy.global_position == origin, "Tactical maneuver entry never teleports")
		var max_step := 0.0
		for tick in 160:
			var previous := enemy.global_position
			enemy._physics_process(1.0 / 60.0)
			max_step = maxf(max_step, previous.distance_to(enemy.global_position))
			var half := enemy._maneuver_half_extents()
			var footprint := Rect2(Vector2(enemy.global_position.x - half.x, enemy.global_position.z - half.z), Vector2(half.x, half.z) * 2.0)
			_expect(bounds.encloses(footprint), Brain.Action.keys()[action] + " keeps the rotating collision envelope in bounds")
			_expect(not enemy.collision_shape.disabled and enemy.collision_layer != 0, "New maneuvers keep the real hull hittable")
			if not enemy._tactics.has_plan():
				var health := enemy.health
				_shot(enemy, Vector2(0, 300))._report_hit(enemy, enemy.global_position)
				_expect(enemy.health < health, "The completed maneuver remains vulnerable during normal flight")
				break
		_expect(max_step > 0.01 and max_step < 2.0, "%s travels continuously at bounded speed (largest step %.3f)" % [Brain.Action.keys()[action], max_step])
		_expect(not enemy._tactics.has_plan(), "Flight completion clears its plan without a recovery interval")
		_expect(not enemy._try_begin_tactical_maneuver(), "Cooldown prevents immediate maneuver chaining")
		await _cleanup()

	var enemy := _spawn("fast")
	for maneuver in [Flight.Maneuver.SPLIT_S, Flight.Maneuver.IMMELMANN, Flight.Maneuver.SCISSORS, Flight.Maneuver.CORKSCREW, Flight.Maneuver.KNIFE_EDGE]:
		for direction in [-1.0, 1.0]:
			enemy._flight_motion.reset(0.0, 31)
			enemy._flight_motion.play(maneuver, direction, 1.4)
			var previous := Quaternion.IDENTITY
			var travel := 0.0
			for tick in 170:
				enemy.advance_motion(1.0 / 120.0)
				var orientation := enemy._flight_motion.pose.basis.get_rotation_quaternion()
				var step := previous.angle_to(orientation)
				_expect(step < 0.5, "New aerobatic clips avoid angular snaps")
				travel += step
				previous = orientation
			_expect(travel > 1.0, "Each new maneuver has a distinct substantial hull animation")
			_expect(previous.angle_to(Quaternion.IDENTITY) < 0.04, "Both directions of every maneuver settle back to level flight")
			if maneuver == Flight.Maneuver.CORKSCREW:
				_expect(travel > 12.0, "Corkscrew completes two full axial turns")
	await _cleanup()


func _check_lifecycle() -> void:
	_place_player(Vector2(0, 400))
	var enemy := _spawn()
	_observe(enemy)
	SaveManager.settings["reduced_motion"] = true
	enemy.advance_motion(0.01)
	enemy._begin_tactical_maneuver(Brain.Action.CORKSCREW, "accessibility probe")
	_expect(enemy._tactics._tell.visible, "Reduced Motion preserves the committed-path warning")
	var timer := enemy.state_remaining
	var cooldown := enemy._tactics._cooldown
	get_tree().paused = true
	enemy.set_physics_process(true)
	await get_tree().create_timer(0.06, true).timeout
	enemy.set_physics_process(false)
	get_tree().paused = false
	_expect(enemy.state_remaining == timer and enemy._tactics._cooldown == cooldown, "Pause freezes both tactical timing and memory")
	enemy._physics_process(0.43)
	var origin := enemy.global_position
	enemy._physics_process(0.3)
	_expect(enemy.global_position != origin and enemy._flight_motion.pose == Transform3D.IDENTITY, "Reduced Motion preserves physical maneuver behavior without spinning the hull")
	GameManager.is_game_active = false
	timer = enemy.state_remaining
	enemy._physics_process(0.5)
	_expect(enemy.state_remaining == timer, "Inactive gameplay does not advance tactical paths")
	GameManager.is_game_active = true
	enemy.take_damage(1000)
	_expect(not enemy._tactics.has_plan() and not enemy._tactics._tell.visible, "Destroying a maneuvering enemy cancels its plan and warning")
	SaveManager.settings["reduced_motion"] = false
	await _cleanup()


func _cleanup() -> void:
	for enemy in _actors:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy.queue_free()
	_actors.clear()
	projectile_manager.clear_projectiles()
	player.is_boosting = false
	player.velocity = Vector3.ZERO
	await get_tree().process_frame
	await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
