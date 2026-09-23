extends Native3DGameplay
## Tests release events, articulated attachment alignment and pause/reset safety.
const Motion := preload("res://effects/ship_motion_3d.gd")
const ENEMIES := {
	"basic": preload("res://entities/enemies/basic_enemy_3d.tscn"),
	"fast": preload("res://entities/enemies/fast_enemy_3d.tscn"),
	"bomber": preload("res://entities/enemies/bomber_enemy_3d.tscn"),
	"tank": preload("res://entities/enemies/tank_enemy_3d.tscn"),
	"sniper": preload("res://entities/enemies/sniper_enemy_3d.tscn"),
}
var _failures: Array[String] = []


func _ready() -> void:
	await super._ready()
	_run.call_deferred()


func _run() -> void:
	player.set_physics_process(false)
	player.set_dev_god_mode(true)
	for role in ENEMIES:
		var enemy := (ENEMIES[role] as PackedScene).instantiate() as BasicEnemy3D
		actors_root.add_child(enemy)
		enemy.activate_generation(flight_space, Vector3(15,0,0), Vector3.FORWARD, 4)
		enemy.set_physics_process(false)
		var motion: Motion = enemy._motions[0]
		var collision := enemy.collision_shape.global_transform
		var contact_size: Vector3 = enemy.collision_shape.shape.size
		var wing_rest := motion.skeleton.get_bone_pose_rotation(1)
		enemy.play_motion(&"windup", .55, true)
		for step in 36:
			enemy.advance_motion(1.0/60.0)
		_expect(wing_rest.angle_to(motion.skeleton.get_bone_pose_rotation(1)) > .07, role + " visibly articulates during anticipation")
		_expect(motion.current_clip == &"windup", role + " holds anticipation until the actual release")
		enemy.play_motion(&"hit")
		_expect(motion.current_clip == &"windup", role + " damage does not hide its attack tell")
		for pair in enemy._animated_sockets:
			_expect(pair[0].global_transform.is_equal_approx(Motion.socket_transform(pair[1])), role + " socket follows the current bone pose")
		_expect(enemy.collision_shape.global_transform.is_equal_approx(collision) and enemy.collision_shape.shape.size == contact_size, role + " articulation keeps collision stable")
		match role:
			"basic":
				enemy._time_alive = 1.0
				enemy._try_begin_charge()
				enemy.state_remaining = .001
				enemy._advance_movement(.01)
			"fast":
				var bounds: Rect2 = enemy._flight_space.get_combat_bounds()
				enemy.global_position = Vector3(bounds.get_center().x, 0.0, bounds.get_center().y)
				enemy._enter(BasicEnemy3D.State.PHASE_WINDUP, .001)
				enemy._phase_displacement = Vector3(2, 0, 0)
				enemy._advance_movement(.01)
			"bomber":
				enemy._drop_bomb()
			"tank":
				enemy._fire_radial_burst()
			"sniper":
				enemy._locked_direction = Vector3.FORWARD
				enemy._fire_locked_shot(enemy.get_socket(&"MuzzleCenter"))
		_expect(motion.current_clip == &"attack", role + " actual attack releases its Blender clip")
		for step in 42:
			enemy.advance_motion(1.0/60.0)
		_expect(motion.current_clip == &"cruise", role + " settles after firing")
		var time_before := motion.animation_player.current_animation_position
		GameManager.is_game_active = false
		enemy._physics_process(.1)
		_expect(is_equal_approx(motion.animation_player.current_animation_position,time_before), role + " freezes outside gameplay")
		GameManager.is_game_active = true
		enemy.queue_free()
		await get_tree().process_frame
	await _check_player()
	# This short fixture can finish before the boot worker has parsed the run.
	# Draining that request avoids shutdown-only missing-preload diagnostics.
	await ResourceCache.wait_for_scene("res://scenes/native_3d_run.tscn")
	for failure in _failures:
		push_error(failure)
	print("COMBAT_MOTION_SMOKE_PASS" if _failures.is_empty() else "COMBAT_MOTION_SMOKE_FAIL")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check_player() -> void:
	var contact_transform := player.collision_shape.transform
	# Physics is disabled in this fixture; explicitly observe neutral input once
	# so the production held-button guard can accept the following fresh press.
	Input.action_release("shoot")
	player._update_shooting()
	player.set_elite_upgrade_enabled("twin_cannons", true)
	player.set_elite_upgrade_enabled("hull_plating", true)
	player.set_elite_upgrade_enabled("afterburner", true)
	_expect(player._upgrade_visuals._activation_time.size() == 3, "New upgrades play their Blender deployment")
	for step in 42:
		player.advance_ship_motion(1.0/60.0)
	for hull_name in ["PlayerHullGLB", "InterceptorHull", "BulwarkHull"]:
		for candidate in player._hull_motions:
			player.visuals.get_node(candidate).visible = candidate == hull_name
		var motion := player.get_ship_motion()
		player._begin_boost()
		for step in 12:
			player.advance_ship_motion(1.0/60.0)
		_expect(motion.current_clip == &"boost", hull_name + " folds for the actual boost event")
		Input.action_press("shoot")
		player.shoot_timer.stop()
		player._update_shooting()
		Input.action_release("shoot")
		_expect(motion.current_clip == &"boost_attack", hull_name + " fires without unfolding boost wings")
		for step in 8:
			player.advance_ship_motion(1.0/60.0)
		Input.action_press("shoot")
		player.shoot_timer.stop()
		player._update_shooting()
		Input.action_release("shoot")
		_expect(motion.animation_player.current_animation_position < .001, hull_name + " rapid volleys restart recoil immediately")
		player.advance_ship_motion(1.0/60.0)
		for id in ["twin_cannons", "hull_plating", "afterburner"]:
			var module: Motion = player._upgrade_visuals._motions[id]
			for index in 4:
				_expect(module.skeleton.get_bone_pose_rotation(index).is_equal_approx(motion.skeleton.get_bone_pose_rotation(index)), hull_name + " " + id + " stays attached through recoil and boost")
		for pair in player._motion_sockets[hull_name]:
			_expect(pair[0].global_transform.is_equal_approx(Motion.socket_transform(pair[1])), hull_name + " moving muzzles/engines remain aligned")
		player.boost_duration_timer = 0.0
		player._update_boost(.01)
		_expect(motion.rest_clip == &"cruise", hull_name + " unfolds when boost ends")
	player.set_elite_upgrade_enabled("overclock", true)
	player.set_elite_upgrade_enabled("shield_burst", true)
	player._elite_clock = 15.99
	player._shield_burst_clock = 9.99
	player._overclock_was_active = false
	player._upgrade_visuals._activation_time.clear()
	player._update_elite_abilities(.02)
	_expect(player._upgrade_visuals._activation_time.has("overclock"), "Overclock's active window triggers a module pulse")
	_expect(player._upgrade_visuals._activation_time.has("shield_burst"), "Actual shield burst triggers a module pulse")
	var motion := player.get_ship_motion()
	player.set_physics_process(true)
	get_tree().paused = true
	var held := motion.animation_player.current_animation_position
	await get_tree().create_timer(.08, true).timeout
	_expect(is_equal_approx(held,motion.animation_player.current_animation_position), "Scene pause freezes the Blender animation")
	get_tree().paused = false
	player.set_physics_process(false)
	player.reset_damage_state()
	player.reset_elite_upgrades()
	_expect(motion.current_clip == &"cruise" and player._upgrade_visuals._activation_time.is_empty(), "Reset clears motion and deployment state")
	_expect(player.collision_shape.transform.is_equal_approx(contact_transform), "Player animation preserves the gameplay hitbox")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
