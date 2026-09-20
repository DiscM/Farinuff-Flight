extends RefCounted
## Optional visual check in Flight Practice: production actors, AI, shaders,
## and projectile pools with an invulnerable stationary player. No rewards.

const OUTPUT := "res://design/combat-scale"

static func prepare(game: Native3DGameplay, boss_wave: int = 0) -> Dictionary:
	if not game.get("_ready_for_practice"):
		return {"ready": false}
	var focus_callback := Callable(game, "_pause_for_interruption")
	if game.get_window().focus_exited.is_connected(focus_callback):
		game.get_window().focus_exited.disconnect(focus_callback)
	game.call("_close_pause_menu")
	game.set_physics_process(false)
	game.get("_lesson").get_parent().get_parent().hide()
	game.player.set_dev_god_mode(true)
	game.player.set_physics_process(false)
	for enemy in game.get_tree().get_nodes_in_group(&"scale_review"):
		enemy.queue_free()
	await game.get_tree().process_frame
	game.projectile_manager.clear_projectiles()
	game.hazard_manager.clear_hazards()
	GameManager.boss_active = boss_wave > 0
	GameManager.current_wave = boss_wave if boss_wave > 0 else 1
	game.hud.update_all()
	var rig := game.flight_space.active_camera.get_parent().get_parent()
	rig._follow_offset = Vector3.ZERO
	game.flight_space.active_camera.position = Vector3.ZERO
	var view := game.get_viewport().get_visible_rect().size
	game.player.global_position = game.flight_space.screen_to_combat_plane(view * Vector2(.5, .72))
	var kinds := ["basic", "tank", "bomber", "fast", "sniper"]
	var positions := [Vector2(.25, .27), Vector2(.5, .23), Vector2(.75, .26), Vector2(.33, .5), Vector2(.72, .49)]
	if boss_wave > 0:
		kinds = ["boss"]
		positions = [Vector2(.5, .30)]
	for index in kinds.size():
		var enemy = load("res://entities/enemies/%s_enemy_3d.tscn" % kinds[index]).instantiate()
		enemy.archetype_id = StringName(kinds[index])
		game.actors_root.add_child(enemy)
		game.register_enemy_feedback(enemy)
		enemy.add_to_group(&"scale_review")
		enemy.activate_generation(game.flight_space, game.flight_space.screen_to_combat_plane(view * positions[index]), Vector3.BACK, 1)
	return {"ready": true, "practice": GameManager.practice_mode, "boss_wave": boss_wave}

static func capture(game: Native3DGameplay, label: String) -> Dictionary:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var path := OUTPUT.path_join(label + ".png")
	var image := game.get_viewport().get_texture().get_image()
	image.save_png(path)
	var view := game.get_viewport().get_visible_rect().size
	var report := {
		"capture": path, "render_size": str(image.get_size()),
		"window_size": str(game.get_window().size), "ui_size": str(view),
		"view_bounds": str(game.flight_space.get_view_bounds()),
		"combat_bounds": str(game.flight_space.get_combat_bounds()),
		"practice": GameManager.practice_mode, "enemies": [],
		"enemy_projectiles_fired": game.projectile_manager._pools[1].shots_fired,
		"boss_hud_alpha": game.hud.get_node("BossDock").modulate.a,
	}
	for enemy in game.get_tree().get_nodes_in_group(&"scale_review"):
		var screen_min := Vector2(INF, INF)
		var screen_max := Vector2(-INF, -INF)
		var surfaces := 0
		var textured := 0
		for node in enemy.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			if not mesh.is_visible_in_tree() or mesh.mesh == null:
				continue
			for corner in 8:
				var world := mesh.global_transform * mesh.get_aabb().get_endpoint(corner)
				var point := game.flight_space.active_camera.unproject_position(world)
				screen_min = screen_min.min(point)
				screen_max = screen_max.max(point)
			for surface in mesh.mesh.get_surface_count():
				surfaces += 1
				var material := mesh.get_active_material(surface) as ShaderMaterial
				if material != null and material.get_shader_parameter("albedo_texture") is Texture2D:
					textured += 1
		var size := (screen_max - screen_min) * Vector2(image.get_size()) / view
		report.enemies.append({"kind": String(enemy.archetype_id), "visible_pixel_envelope": str(size), "surfaces": surfaces, "textured_surfaces": textured, "root_scale": str(enemy.scale), "active": enemy.is_active})
	var file := FileAccess.open(OUTPUT.path_join(label + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	return report
