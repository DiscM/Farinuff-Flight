extends RefCounted
## Optional GPU review helper, invoked against the production Flight Practice
## scene. No rewards or save progression: the normal boss AI drives each pose.

const BOSS := preload("res://entities/enemies/boss_enemy_3d.tscn")
const IDS := ["boss_assault", "boss_bulwark", "boss_tempest", "boss_void_harbinger", "boss_tempest_core"]
const WAVES := [5, 10, 15, 25, 20]
const OUTPUT := "res://design/voxel-bosses/godot"

static func capture(game: Native3DGameplay, index: int) -> Dictionary:
	if not game.get("_ready_for_practice"):
		return {"passed": false, "reason": "Flight Practice must finish warming first"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var focus_callback := Callable(game, "_pause_for_interruption")
	if game.get_window().focus_exited.is_connected(focus_callback):
		game.get_window().focus_exited.disconnect(focus_callback)
	game.call("_close_pause_menu")
	game.set_physics_process(false)
	game.get("_lesson").get_parent().get_parent().hide()
	game.player.set_dev_god_mode(true)
	game.player.set_physics_process(false)
	for previous in game.get_tree().get_nodes_in_group(&"native_3d_bosses"):
		previous.queue_free()
	await game.get_tree().process_frame
	game.projectile_manager.clear_projectiles()
	game.hazard_manager.clear_hazards()
	var size := game.get_viewport().get_visible_rect().size
	game.player.global_position = game.flight_space.screen_to_combat_plane(size * Vector2(.5, .78))
	GameManager.current_wave = WAVES[index]
	GameManager.boss_active = true
	var boss = BOSS.instantiate()
	game.actors_root.add_child(boss)
	game.register_enemy_feedback(boss)
	boss.activate_generation(game.flight_space, game.flight_space.screen_to_combat_plane(size * Vector2(.5, .30)), Vector3.BACK, 1)
	var initial_shots: int = game.projectile_manager._pools[1].shots_fired
	var report := {"asset": IDS[index], "wave": WAVES[index], "native_scale": boss.scale == Vector3.ONE, "practice": GameManager.practice_mode, "windup": false, "attack": false, "projectiles_fired": 0, "active_pods": boss._active_section_count()}
	for frame in 1200:
		await game.get_tree().physics_frame
		var executor = boss._boss_ai.executor
		if not report.windup and executor.winding_up and executor.elapsed > executor.plan.warning_seconds * .65:
			report.windup = boss._motions[index].current_clip == &"windup"
			report.windup_attack = String(executor.plan.definition.id)
			report.windup_pods = []
			for section in boss._sections:
				if section.is_active:
					report.windup_pods.append(String(section._motion.current_clip))
			await RenderingServer.frame_post_draw
			game.get_viewport().get_texture().get_image().save_png(OUTPUT + "/%s_windup.png" % IDS[index])
		var fired: int = game.projectile_manager._pools[1].shots_fired - initial_shots
		if report.windup and fired > 0 and boss._motions[index].current_clip == &"attack":
			report.attack = true
			report.projectiles_fired = fired
			report.attack_id = String(executor.plan.definition.id) if executor.plan != null else String(boss._boss_ai.selector.last_attack)
			# Let the real projectile pool move the released volley into view.
			for delay_frame in 6:
				await game.get_tree().physics_frame
			await RenderingServer.frame_post_draw
			game.get_viewport().get_texture().get_image().save_png(OUTPUT + "/%s_attack.png" % IDS[index])
			break
	boss.set_physics_process(false)
	if index == 4:
		boss._sections[0].take_damage(1)
		boss.advance_motion(.025)
		await RenderingServer.frame_post_draw
		game.get_viewport().get_texture().get_image().save_png(OUTPUT + "/pod_hit.png")
		boss._sections[0].take_damage(99999)
		await game.get_tree().process_frame
		await RenderingServer.frame_post_draw
		game.get_viewport().get_texture().get_image().save_png(OUTPUT + "/pod_destroyed.png")
		report.pod_destroyed = not boss._sections[0].visible and boss._active_section_count() == 1
	report.passed = report.native_scale and report.practice and report.windup and report.attack and report.projectiles_fired > 0
	var entries: Array = []
	var path := OUTPUT + "/gameplay_verification.json"
	if index > 0 and FileAccess.file_exists(path):
		entries = JSON.parse_string(FileAccess.get_file_as_string(path)).assets
	entries.append(report)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"method": "Production Flight Practice, frozen player with practice invulnerability, normal boss AI and projectile pool; one boss at a time, native wrapper scales", "assets": entries}, "\t"))
	return report

static func presentation(game: Native3DGameplay, index: int) -> String:
	# Separate, explicitly staged inspection frame: preserve the honest AI
	# captures above, but put this native-scale assembled hull below the HUD.
	for previous in game.get_tree().get_nodes_in_group(&"native_3d_bosses"):
		previous.queue_free()
	await game.get_tree().process_frame
	game.projectile_manager.clear_projectiles()
	GameManager.current_wave = WAVES[index]
	var boss = BOSS.instantiate()
	game.actors_root.add_child(boss)
	var camera_rig = game.flight_space.active_camera.get_parent().get_parent()
	camera_rig.set_process(false)
	var size := game.get_viewport().get_visible_rect().size
	boss.activate_generation(game.flight_space, game.flight_space.screen_to_combat_plane(size * Vector2(.5, .40)), Vector3.BACK, 1)
	boss.set_physics_process(false)
	boss.play_motion(&"windup", .6, true)
	boss.advance_motion(.6)
	await RenderingServer.frame_post_draw
	var path := OUTPUT + "/%s_presentation.png" % IDS[index]
	game.get_viewport().get_texture().get_image().save_png(path)
	camera_rig.set_process(true)
	return path
