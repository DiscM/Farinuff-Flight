extends Native3DGameplay
## Exercises production executors, all shipped rigs, cancellation and sockets.
const Boss := preload("res://entities/enemies/boss_enemy_3d.tscn")
const Motion := preload("res://effects/ship_motion_3d.gd")
const Families := [&"slam", &"charge", &"volley", &"alternate"]
var _failures: Array[String] = []
var _capture := false
var _sheets: Dictionary = {}

func _ready() -> void:
	await super._ready()
	_run.call_deferred()

func _run() -> void:
	_capture = DisplayServer.get_name() != "headless" or OS.get_cmdline_user_args().has("--capture-attack-motion")
	player.set_physics_process(false)
	player.set_dev_god_mode(true)
	player.global_position = flight_space.screen_motion_to_combat(Vector2(0, 600))
	if _capture:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://design/attack-motion"))
		for family in Families + [&"phase", &"regular"]:
			_sheets[family] = Image.create(960, 1200, false, Image.FORMAT_RGBA8)
			_sheets[family].fill(Color(0.025, 0.035, 0.07))
	for index in 5:
		var boss = Boss.instantiate()
		actors_root.add_child(boss)
		boss.dev_variant_override = index
		GameManager.current_wave = [5, 10, 15, 25, 20][index]
		boss.activate_generation(flight_space, Vector3.ZERO, Vector3.BACK, 4)
		boss.set_physics_process(false)
		boss._arena_patterns.set_physics_process(false)
		var motion: Motion = boss._motions[index]
		var collider: Transform3D = boss.collision_shape.global_transform
		for family_index in Families.size():
			var family: StringName = Families[family_index]
			var plan := BossAttackPlan.new()
			plan.configure(boss._boss_ai.profile.attacks[family_index], boss._boss_ai.profile, 2)
			plan.aim = Vector2.DOWN
			plan.target_position = player.global_position
			boss._boss_ai.executor.cancel()
			boss.play_motion(&"cruise")
			await _snapshot(boss, family, index, 0)
			boss._boss_ai.executor.begin(plan)
			_expect(motion.current_clip == StringName(String(family) + "_windup"), "%s %s selects the attack-specific anticipation" % [index, family])
			boss.advance_motion(plan.warning_seconds + .1)
			var end_pose := motion.skeleton.get_bone_pose_rotation(1)
			_expect(end_pose.angle_to(Quaternion.IDENTITY) > .06, "Windup has visible articulated armor")
			boss.play_motion(&"hit")
			_expect(motion.is_windup(), "Damage does not mask a family-specific warning")
			await _snapshot(boss, family, index, 1)
			boss._boss_ai.executor.advance(plan.warning_seconds + .01, player)
			_expect(motion.current_clip == StringName(String(family) + "_attack"), "Executor releases the matching family animation")
			var attack_pose := motion.skeleton.get_bone_pose_rotation(1)
			_expect(end_pose.angle_to(attack_pose) < .02, "Release starts at the held brace pose")
			if plan.definition.family == BossAttackDefinition.Family.PROJECTILE:
				boss._boss_ai.executor.advance(.01, player)
			for frame in 12:
				boss.advance_motion(.01)
			_expect(end_pose.angle_to(motion.skeleton.get_bone_pose_rotation(1)) > .04, "Release produces a distinct armor impulse")
			for section in boss._sections:
				if section.is_active:
					_expect(section._motion.current_clip == motion.current_clip, "Active weapon pods synchronize with the attack family")
			for pair in boss._animated_sockets:
				if boss.visuals.get_child(index).is_ancestor_of(pair[1]):
					_expect(pair[0].global_transform.is_equal_approx(Motion.socket_transform(pair[1])), "Animated firing sockets track the current pose")
			_expect(collider.is_equal_approx(boss.collision_shape.global_transform), "Articulation leaves the hitbox unchanged")
			await _snapshot(boss, family, index, 2)
			boss._boss_ai.executor.cancel()
			_expect(motion.current_clip == &"cruise", "Cancelled attacks release their held pose")
			projectile_manager.clear_projectiles()
		await _snapshot(boss, &"phase", index, 0)
		boss._boss_ai.begin_phase(1)
		_expect(motion.current_clip == &"phase_shift", "Actual phase transition plays the reactor/opening animation")
		boss.play_motion(&"hit")
		_expect(motion.current_clip == &"phase_shift", "Hit recoil does not mask a phase transition")
		for frame in 12:
			boss.advance_motion(boss._boss_ai.profile.phase_transition_duration * .35 / 12.0)
		await _snapshot(boss, &"phase", index, 1)
		for frame in 12:
			boss.advance_motion(boss._boss_ai.profile.phase_transition_duration * .25 / 12.0)
		await _snapshot(boss, &"phase", index, 2)
		var before := motion.animation_player.current_animation_position
		GameManager.is_game_active = false
		boss._physics_process(.1)
		_expect(is_equal_approx(before, motion.animation_player.current_animation_position), "Inactive combat freezes attack animations")
		GameManager.is_game_active = true
		boss.set_physics_process(true)
		get_tree().paused = true
		await get_tree().create_timer(.04, true).timeout
		_expect(is_equal_approx(before, motion.animation_player.current_animation_position), "Scene pause freezes a live custom boss animation")
		get_tree().paused = false
		boss.set_physics_process(false)
		boss._boss_ai.executor.cancel()
		boss.queue_free()
		await get_tree().process_frame
	await _check_regular_art()
	if _capture:
		for family in Families + [&"phase", &"regular"]:
			_sheets[family].save_png("res://design/attack-motion/%s.png" % family)
	await ResourceCache.wait_for_scene(ResourceCache.NATIVE_RUN_PATH)
	for failure in _failures:
		push_error(failure)
	print("ENEMY_ATTACK_ANIMATION_SMOKE_PASS" if _failures.is_empty() else "ENEMY_ATTACK_ANIMATION_SMOKE_FAIL")
	get_tree().quit(0 if _failures.is_empty() else 1)

func _check_regular_art() -> void:
	var roles := ["basic", "fast", "bomber", "tank", "sniper"]
	var prefixes := ["charge", "phase", "deploy", "radial", "rail"]
	var states := [BasicEnemy3D.State.CHARGE_WINDUP, BasicEnemy3D.State.PHASE_WINDUP, BasicEnemy3D.State.MINE_DEPLOY, BasicEnemy3D.State.BARRAGE, BasicEnemy3D.State.RAIL_AIM]
	for index in roles.size():
		var scene := load("res://entities/enemies/%s_enemy_3d.tscn" % roles[index]) as PackedScene
		var enemy := scene.instantiate() as BasicEnemy3D
		actors_root.add_child(enemy)
		enemy.activate_generation(flight_space, Vector3.ZERO, Vector3.BACK, 4)
		enemy.set_physics_process(false)
		var motion: Motion = enemy._motions[0]
		await _snapshot(enemy, &"regular", index, 0)
		enemy.state = states[index]
		enemy.play_motion(&"windup", .5, true)
		for frame in 30:
			enemy.advance_motion(1.0/60.0)
		_expect(motion.current_clip == StringName(prefixes[index] + "_windup"), roles[index] + " state selects its specialized warning")
		await _snapshot(enemy, &"regular", index, 1)
		enemy.play_motion(StringName(prefixes[index] + "_attack"))
		for frame in 12:
			enemy.advance_motion(.01)
		_expect(motion.current_clip == StringName(prefixes[index] + "_attack"), roles[index] + " plays specialized release")
		await _snapshot(enemy, &"regular", index, 2)
		enemy.queue_free()
		await get_tree().process_frame

func _snapshot(boss: Node3D, family: StringName, row: int, column: int) -> void:
	if not _capture:
		return
	await RenderingServer.frame_post_draw
	var frame := get_viewport().get_texture().get_image()
	var center := flight_space.active_camera.unproject_position(boss.global_position)
	# Metal's viewport texture can be Retina-sized while projection uses logical pixels.
	var density := Vector2(frame.get_size()) / get_viewport().get_visible_rect().size
	var half_size := Vector2(180, 135) if family != &"regular" else Vector2(65, 48.75)
	var rect := Rect2i(Vector2i((center - half_size) * density), Vector2i(half_size * 2.0 * density))
	var crop := frame.get_region(rect)
	crop.resize(320, 240, Image.INTERPOLATE_LANCZOS)
	crop.convert(Image.FORMAT_RGBA8)
	_sheets[family].blit_rect(crop, Rect2i(0, 0, 320, 240), Vector2i(column * 320, row * 240))

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
