extends Node
## Compare current presentation across home port, Expedition and Flight School.

const HOME := preload("res://scenes/home_base.tscn")
const RUN := preload("res://scenes/harbor_combat.tscn")
const Layout := preload("res://systems/crescent_harbor_layout.gd")
const FlightTuning := preload("res://entities/player/player_flight_tuning.gd")
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var snapshot := preload("res://tests/save_file_snapshot.gd").new()
	SaveManager.settings["story_frequency"] = 2
	SaveManager.settings["reduced_motion"] = false
	SaveManager.settings["screen_shake"] = false
	var home := HOME.instantiate()
	add_child(home)
	home.set_physics_process(false)
	home._update_camera(0.0)
	var home_camera: Transform3D = home.camera.global_transform
	var home_zoom: float = home.camera.size
	var home_station_scale: Vector3 = home._harbor_visuals.scale
	var home_ship_scale: Vector3 = home.player.get_node("Hull").global_basis.get_scale()
	var home_cruise: float = home.CRUISE_SPEED
	var home_lighting := _lighting_snapshot(home.world)
	home.queue_free()
	await get_tree().process_frame
	var level := RUN.instantiate()
	add_child(level)
	for frame in 600:
		if level._gameplay_prepared and level.encounters.started:
			break
		await get_tree().process_frame
	if is_instance_valid(level._pause_overlay):
		level._close_pause_menu()
	_expect(level._gameplay_prepared and level.encounters.started, "Launch starts the production encounter director")
	level.encounters.set_physics_process(false)
	level.player.set_dev_god_mode(true)
	level.player.set_physics_process(false)
	level.camera_rig.set_process(false)
	level.camera_rig.set_physics_process(false)
	var camera: Camera3D = level.camera_rig.active_camera
	_expect(camera.projection == Camera3D.PROJECTION_ORTHOGONAL and is_equal_approx(camera.size, home_zoom), "Combat uses the exact home-port orthographic size")
	_expect(camera.global_basis.is_equal_approx(home_camera.basis), "Combat uses the actual home-port camera angle")
	_expect(camera.global_position.distance_to(home_camera.origin) < 0.01, "Combat starts from the same home-port framing")
	_expect(level.harbor.scale.is_equal_approx(home_station_scale), "Station scale matches the home port")
	_expect(level.player.visuals.get_node("PlayerHullGLB").global_basis.get_scale().is_equal_approx(home_ship_scale * 1.4), "Combat player model is enlarged 40% for visibility")
	_expect(level.player.global_position.is_equal_approx(Layout.INITIAL_POSITION), "Pilot starts at the same harbor arrival point")
	var enemies := get_tree().get_nodes_in_group(&"native_3d_regular_enemies")
	_expect(enemies.size() >= 3, "The harbor opens with three active enemies")
	for enemy in enemies:
		_expect(enemy.is_active and Layout.is_clear(enemy.global_position), "Patrols spawn clear of station machinery")
		_expect(get_viewport().get_visible_rect().has_point(camera.unproject_position(enemy.global_position)), "Opening patrols are visible in the home-port view")
		var previous: Vector3 = enemy.global_position
		enemy._physics_process(0.1)
		_expect(previous.distance_to(enemy.global_position) > 0.01, "Opening patrols use live enemy AI")
		enemy.set_physics_process(false)
	_check_orbit(level, home_cruise)
	_check_geometry(level)
	_check_shooting(level)
	# Follow also has to work in the tall/narrow window used on small displays.
	get_tree().root.size = Vector2i(900, 900)
	await get_tree().process_frame
	_check_orbit(level, home_cruise)
	level.queue_free()
	await get_tree().process_frame
	await _check_normal_combat(home_camera.basis, home_zoom, home_ship_scale, home_lighting)
	await _check_practice_presentation(home_camera.basis, home_zoom, home_ship_scale, home_lighting)
	await ResourceCache.wait_for_scene("res://scenes/home_base.tscn")
	await ResourceCache.wait_for_scene("res://scenes/native_3d_run.tscn")
	snapshot.restore()
	for failure in _failures:
		push_error(failure)
	print("HARBOR_COMBAT_SMOKE_PASS" if _failures.is_empty() else "HARBOR_COMBAT_SMOKE_FAIL")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _lighting_snapshot(world: Node) -> Dictionary:
	var key: DirectionalLight3D = world.find_child("WarmStarlight", true, false)
	var fill: DirectionalLight3D = world.find_child("BlueNebulaFill", true, false)
	var environments := world.find_children("*", "WorldEnvironment", true, false)
	if key == null or fill == null or environments.size() != 1:
		return {}
	var environment: Environment = environments[0].environment
	return {
		"key": [key.rotation, key.light_color, key.light_energy, key.shadow_enabled, key.directional_shadow_max_distance],
		"fill": [fill.rotation, fill.light_color, fill.light_energy],
		"ambient": [environment.ambient_light_color, environment.ambient_light_energy],
		"tone": [environment.tonemap_mode, environment.glow_intensity, environment.glow_strength, environment.glow_hdr_threshold],
	}


func _check_practice_presentation(home_basis: Basis, home_zoom: float, ship_scale: Vector3, home_lighting: Dictionary) -> void:
	var packed: PackedScene = await ResourceCache.wait_for_scene(ResourceCache.PRACTICE_PATH)
	var practice := packed.instantiate()
	add_child(practice)
	for frame in 600:
		if practice._ready_for_practice:
			break
		await get_tree().process_frame
	if is_instance_valid(practice._pause_overlay):
		practice._close_pause_menu()
	practice.set_physics_process(false)
	practice.player.set_physics_process(false)
	practice.camera_rig.set_process(false)
	var camera: Camera3D = practice.camera_rig.active_camera
	_expect(practice._ready_for_practice and GameManager.practice_mode, "Flight School starts an isolated practice session")
	_expect(camera.projection == Camera3D.PROJECTION_ORTHOGONAL and is_equal_approx(camera.size, home_zoom), "Flight School uses the same current zoom as Expedition")
	_expect(camera.global_basis.is_equal_approx(home_basis), "Flight School starts at the home-port camera angle")
	_expect(_lighting_snapshot(practice.get_node("World3D")) == home_lighting, "Flight School uses the current shared lighting")
	_expect(practice.player.visuals.get_node("PlayerHullGLB").global_basis.get_scale().is_equal_approx(ship_scale * 1.4), "Flight School retains the enlarged player model")
	_expect(is_equal_approx(practice.player._flight_speed_scale, 3.0) and is_equal_approx(practice.flight_space.configuration.enemy_scale_multiplier, 3.0), "Practice teaches the current combat movement and enemy scale")
	_expect(not practice.consume_field_supplies and not practice.rewards_enabled, "Sharing presentation does not enable practice supplies or rewards")
	practice.queue_free()
	await get_tree().process_frame


func _check_normal_combat(home_basis: Basis, home_zoom: float, ship_scale: Vector3, home_lighting: Dictionary) -> void:
	# Launch and retry both load this cached production scene, not the harbor demo.
	var packed: PackedScene = await ResourceCache.wait_for_scene(ResourceCache.NATIVE_RUN_PATH)
	var run := packed.instantiate()
	add_child(run)
	for frame in 600:
		if run._gameplay_prepared and run.encounters.started:
			break
		await get_tree().process_frame
	if is_instance_valid(run._pause_overlay):
		run._close_pause_menu()
	run.encounters.set_physics_process(false)
	run.player.set_physics_process(false)
	run.player.set_dev_god_mode(true)
	run.camera_rig.set_process(false)
	run.camera_rig.set_physics_process(false)
	_expect(run._gameplay_prepared and run.encounters.started, "Normal combat still starts its encounter director")
	_expect(run.get_node("Backdrop").visible and run.get_node_or_null("World3D/FrontierLandmarks") != null, "Normal launch retains the space battlefield and its scenery")
	_expect(run.get_node_or_null("World3D/CrescentHarbor") == null and not run.player.flight_constraint.is_valid(), "Normal combat has no harbor station or station collision boundary")
	var camera: Camera3D = run.camera_rig.active_camera
	_expect(camera.projection == Camera3D.PROJECTION_ORTHOGONAL and is_equal_approx(camera.size, 220.0) and is_equal_approx(camera.size, home_zoom), "Normal combat uses the base's 220-unit orthographic zoom")
	_expect(camera.global_basis.is_equal_approx(home_basis), "Normal combat starts at the base camera angle")
	_expect(run.player.global_position.is_equal_approx(Vector3.ZERO), "Normal combat starts at the center of its space arena")
	_expect(camera.unproject_position(run.player.global_position).distance_to(get_viewport().get_visible_rect().get_center()) < 0.25, "The normal combat camera centers on the arena instead of the station")
	_expect(not home_lighting.is_empty() and _lighting_snapshot(run.get_node("World3D")) == home_lighting, "Normal combat shares the base's key, fill, ambient light and tone mapping")
	for hull in ["PlayerHullGLB", "InterceptorHull", "BulwarkHull"]:
		_expect(run.player.visuals.get_node(hull).global_basis.get_scale().is_equal_approx(ship_scale * 1.4), "Normal combat enlarges the player model 40% for visibility: " + hull)
	var enemy: BasicEnemy3D = run.encounters.spawn_enemy(&"basic", 0, 0.5)
	_expect(enemy != null and enemy.is_active, "The normal wave director spawns live combat enemies")
	if enemy != null:
		enemy.set_physics_process(false)
	await _check_enlarged_enemy_targets(run)
	_check_shooting(run, Vector3.ZERO)
	run.player.set_combat_position(Vector3.ZERO)
	for turn in 4:
		run.camera_rig.flip_horizontal(0.5)
		run.camera_rig._advance_view_transition(0.5)
		_expect(is_equal_approx(camera.size, 220.0), "Normal combat keeps the base zoom at every quarter-turn")
		_expect(camera.global_basis.is_equal_approx(home_basis.rotated(Vector3.UP, PI * 0.5 * (turn + 1))), "Normal combat rotates in the selected 90-degree increments")
	var bounds: Rect2 = run.flight_space.get_combat_bounds()
	for point in [bounds.position, bounds.end]:
		run.player.set_combat_position(Vector3(point.x, 0.0, point.y))
		run.camera_rig._process(1.0 / 60.0)
		_expect(get_viewport().get_visible_rect().grow(-8.0).has_point(run.flight_space.combat_to_screen(run.player.global_position)), "The normal combat camera keeps edge travel visible")
	run.queue_free()
	await get_tree().process_frame


func _check_enlarged_enemy_targets(run: Node) -> void:
	# Probe the newly visible outer hull with real physics, including the sniper's
	# generation-specific envelope and attached armor/pods on larger enemies.
	for kind in ["basic", "fast", "bomber", "sniper", "tank", "boss"]:
		var packed := load("res://entities/enemies/%s_enemy_3d.tscn" % kind) as PackedScene
		var enemy := packed.instantiate() as BasicEnemy3D
		run.actors_root.add_child(enemy)
		var original_width: float = (enemy.collision_shape.shape as BoxShape3D).size.x
		_expect(enemy.activate_generation(run.flight_space, Vector3(40, 0, 40), Vector3.FORWARD, 4), kind + " activates in the enlarged combat profile")
		enemy.set_physics_process(false)
		enemy.play_motion(&"hit")
		enemy.advance_motion(0.1)
		# Imported BoneAttachment transforms settle after the physics pose updates.
		await get_tree().process_frame
		for pair in enemy._animated_sockets:
			if pair[1].is_visible_in_tree():
				_expect(pair[0].global_position.distance_to(pair[1].global_position) < 0.002, kind + " keeps animated weapon mounts aligned with the enlarged hull")
		await get_tree().physics_frame
		await get_tree().physics_frame
		for multiplier in [1.0, 2.0]:
			var point: Vector3 = enemy.global_position + Vector3.RIGHT * original_width * multiplier
			var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 50.0, point + Vector3.DOWN * 50.0)
			query.collision_mask = preload("res://systems/native_3d_physics_layers.gd").ENEMY_CRAFT
			query.collide_with_areas = true
			query.collide_with_bodies = false
			var hit := enemy.get_world_3d().direct_space_state.intersect_ray(query)
			_expect((hit.get("collider") == enemy) == (multiplier == 1.0), kind + " accepts hits on its enlarged hull and misses beyond it")
		enemy.queue_free()
		await get_tree().process_frame


func _check_orbit(level: Node, cruise: float) -> void:
	level.player.velocity = Vector3.ZERO
	level.camera_rig.set_view_preset(Native3DCameraRig.View.ANGLED, 0.0)
	var bounds: Rect2 = level.flight_space.get_combat_bounds()
	var before: Vector3 = level.camera_rig.view_pivot.basis.z
	for turn in 4:
		level.camera_rig.flip_horizontal(1.0)
		for step in 61:
			level.camera_rig._advance_view_transition(1.0 / 60.0)
			level.camera_rig._process(1.0 / 60.0)
			_expect(is_equal_approx(level.camera_rig.active_camera.size, 220.0), "A flip preserves home-port scale")
			_expect(level.flight_space.get_combat_bounds().is_equal_approx(bounds), "Orbit leaves the harbor boundary fixed")
			var point: Vector3 = level.player.global_position
			var screen: Vector2 = level.flight_space.combat_to_screen(point)
			_expect(get_viewport().get_visible_rect().grow(-8.0).has_point(screen), "The pilot stays visible throughout the orbit")
			_expect(level.flight_space.screen_to_combat_plane(screen).distance_to(point) < 0.02, "Mouse aiming still intersects the pilot's flight plane")
			for input: Vector2 in [Vector2.RIGHT, Vector2.UP, Vector2.ONE.normalized()]:
				var motion: Vector3 = level.flight_space.view_input_to_combat_motion(input * FlightTuning.SPEED)
				_expect(is_equal_approx(motion.length(), cruise), "The reference flight metric stays consistent at every angle")
		var expected := before.rotated(Vector3.UP, PI * 0.5 * (turn + 1))
		_expect(level.camera_rig.view_pivot.basis.z.is_equal_approx(expected), "Each press advances another 90 degrees around the harbor")
	_expect(level.camera_rig.view_pivot.basis.z.is_equal_approx(before), "Four presses return to the initial harbor angle")
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		level.player.set_combat_position(Layout.constrain(Layout.FLIGHT_CENTER + Vector3(cos(angle), 0.0, sin(angle)) * Layout.FLIGHT_RADIUS))
		level.camera_rig._process(1.0 / 60.0)
		_expect(get_viewport().get_visible_rect().grow(-8.0).has_point(level.flight_space.combat_to_screen(level.player.global_position)), "Harbor edge travel keeps the ship in frame")
	level.camera_rig.set_view_preset(Native3DCameraRig.View.OVERHEAD, 0.0)
	_expect(level.flight_space.view_input_to_combat_motion(Vector2.UP).is_finite(), "Overhead controls have a valid motion basis")


func _check_geometry(level: Node) -> void:
	var start := Layout.CORE_CENTER + Vector3.BACK * (Layout.CORE_RADIUS + 7.0)
	level.player.set_combat_position(start)
	level.player.velocity = Vector3.FORWARD * 50.0
	level.player._advance_flight(level.player.velocity)
	_expect(level.player.global_position.z >= Layout.CORE_CENTER.z + Layout.CORE_RADIUS - 0.01, "A long boost frame cannot tunnel through the harbor tower")
	_expect(Layout.is_clear(level.player.global_position), "Collision leaves the craft outside station geometry")
	level.player.set_combat_position(Layout.FLIGHT_CENTER + Vector3.RIGHT * 300.0)
	level.player._clamp_to_flight_bounds()
	_expect(is_equal_approx(level.player.global_position.distance_to(Layout.FLIGHT_CENTER), Layout.FLIGHT_RADIUS), "Movement respects the circular home-port perimeter")
	_expect(is_zero_approx(level.player.global_position.y), "Movement remains on the harbor flight plane")


func _check_shooting(level: Node, origin: Vector3 = Layout.INITIAL_POSITION) -> void:
	level.player.set_combat_position(origin)
	level.player.last_aim_direction = Vector3.FORWARD
	level.player._fire_waiting_for_release = false
	level.player.shoot_timer.stop()
	Input.action_press("shoot")
	level.player._update_shooting()
	Input.action_release("shoot")
	var projectiles := get_tree().get_nodes_in_group(&"player_projectiles")
	_expect(not projectiles.is_empty(), "The player's weapon fires a live pooled combat projectile")
	if not projectiles.is_empty():
		_expect(is_zero_approx(projectiles[0].velocity.y) and projectiles[0].velocity.length() > 0.0, "Projectiles fly on the shared harbor plane")


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
