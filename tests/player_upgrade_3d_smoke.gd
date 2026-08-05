extends Node
## Runtime regression coverage for GLB-backed player upgrades and escort drone.
##
## Run with:
## godot --headless --path . res://tests/player_upgrade_3d_smoke.tscn

const GAME_SCENE := preload("res://scenes/game.tscn")
const MOUNTED_IDS: Array[String] = [
	"twin_cannons",
	"auto_aim",
	"hull_plating",
	"afterburner",
	"spread_shot_elite",
	"shield_burst",
	"magnet_field",
	"overclock",
	"rear_gunner",
]
const EXPECTED_PATHS := {
	"twin_cannons": "res://assets/models/redesign/butterfly_elites/bf_elite_twin_cannons.glb",
	"auto_aim": "res://assets/models/redesign/butterfly_elites/bf_elite_auto_aim.glb",
	"hull_plating": "res://assets/models/redesign/butterfly_elites/bf_elite_hull_plating.glb",
	"afterburner": "res://assets/models/redesign/butterfly_elites/bf_elite_afterburner.glb",
	"spread_shot_elite": "res://assets/models/redesign/butterfly_elites/bf_elite_spread_shot.glb",
	"shield_burst": "res://assets/models/redesign/butterfly_elites/bf_elite_shield_burst.glb",
	"magnet_field": "res://assets/models/redesign/butterfly_elites/bf_elite_magnet_field.glb",
	"overclock": "res://assets/models/redesign/butterfly_elites/bf_elite_overclock.glb",
	"rear_gunner": "res://assets/models/redesign/butterfly_elites/bf_elite_rear_gunner.glb",
}
const SHIP_SHADER_PATH := "res://effects/shaders/models/pixel_toon_3d.gdshader"
const OUTLINE_SHADER_PATH := "res://effects/shaders/models/pixel_outline_3d.gdshader"
const EXPECTED_FULLY_UPGRADED_TRIANGLES := 2152

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := GAME_SCENE.instantiate()
	add_child(game)
	game.get_node("EnemySpawner").stop_spawning()
	game.get_node("PowerUpSpawner").stop_spawning()
	var player := game.get_node("Player") as Node2D
	player.set_physics_process(false)
	player.position = get_viewport().get_visible_rect().size * Vector2(0.5, 0.69)

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var layer := game.get_node("ShipRenderLayer3D") as ShipRenderLayer3D
	_expect(layer != null, "Game must expose the shared 3D ship layer")
	if layer == null:
		await _finish(game)
		return
	layer.sync_now()

	_check_legacy_layers_suppressed(player)
	_check_player_engine_trail(layer, player)
	_check_mounted_upgrade_models(layer, player)
	_check_paused_upgrade_refresh(layer, player)
	await _check_fully_upgraded_static_assembly(layer, player)
	await _check_drone_proxy(layer, player)
	await _check_unbind_restoration(game, layer, player)

	if OS.get_cmdline_user_args().has("--player-upgrade-3d-capture"):
		var planet_container := game.get_node_or_null("PlanetContainer") as CanvasItem
		if planet_container != null:
			planet_container.visible = false
		player.position = get_viewport().get_visible_rect().size * Vector2(0.5, 0.64)
		player.scale = Vector2.ONE * 1.65
		player.set_elite_upgrade_enabled("drone_escort", true, false)
		await get_tree().process_frame
		var capture_drones := get_tree().get_nodes_in_group("drone_escort")
		if not capture_drones.is_empty():
			var capture_drone := capture_drones[0] as ShipDrone
			capture_drone.set_physics_process(false)
			capture_drone.global_position = (
				player.global_position + ShipDrone.HOVER_OFFSET
			)
		for projectile in get_tree().get_nodes_in_group("player_bullets"):
			projectile.queue_free()
		await get_tree().process_frame
		layer.sync_now()
		await _capture_integration()

	player.clear_elite_upgrades()
	await get_tree().process_frame
	await _finish(game)


func _check_legacy_layers_suppressed(player: Node2D) -> void:
	var back := player.get_node("UpgradeVisualsBack") as CanvasItem
	var front := player.get_node("UpgradeVisualsFront") as CanvasItem
	_expect(
		back.visible and front.visible,
		"Legacy upgrade layers must remain alive as fallback/state drivers"
	)
	_expect(
		is_zero_approx(back.self_modulate.a)
		and is_zero_approx(front.self_modulate.a),
		"Legacy 2D upgrade pixels must be suppressed while 3D rendering is active"
	)


func _check_player_engine_trail(
	layer: ShipRenderLayer3D,
	player: Node2D
) -> void:
	var visual := layer.get_visual_for(player)
	_expect(visual != null, "Player engine-trail check requires a 3D assembly")
	if visual == null:
		return
	var trail := visual.get_node_or_null("EngineTrails") as MeshInstance3D
	var material: ShaderMaterial = null
	if trail != null:
		material = trail.material_override as ShaderMaterial
	_expect(
		material != null
		and material.shader.resource_path
		== "res://effects/shaders/models/pixel_trail_3d.gdshader",
		"Player assembly must retain the integrated 3D engine trail"
	)


func _check_mounted_upgrade_models(
	layer: ShipRenderLayer3D,
	player: Node2D
) -> void:
	for id in MOUNTED_IDS:
		var module := layer.get_player_upgrade_visual(player, id)
		_expect(module != null, "%s must have one prebuilt 3D attachment" % id)
		if module == null:
			continue
		_expect(not module.visible, "%s must begin disabled" % id)
		_expect(
			module.scene_file_path == EXPECTED_PATHS[id],
			"%s must instantiate its real GLB" % id
		)
		_expect(
			layer.get_player_upgrade_model_path(id) == EXPECTED_PATHS[id],
			"%s diagnostics must report its real GLB path" % id
		)
		_expect(
			module.transform.is_equal_approx(Transform3D.IDENTITY),
			"%s must attach at the authored identity transform" % id
		)

		var original_instance_id := module.get_instance_id()
		player.set_elite_upgrade_enabled(id, true, false)
		layer.sync_now()
		_expect(module.visible, "%s must appear immediately when enabled" % id)
		player.set_elite_upgrade_enabled(id, true, false)
		layer.sync_now()
		_expect(
			layer.get_player_upgrade_visual(player, id).get_instance_id() == original_instance_id,
			"%s must not duplicate when enabled twice" % id
		)

		var meshes := layer.get_player_upgrade_meshes(player, id)
		var outlines := layer.get_player_upgrade_outlines(player, id)
		_expect(not meshes.is_empty(), "%s must contain a hull mesh" % id)
		_expect(not outlines.is_empty(), "%s must contain a 3D outline pass" % id)
		_check_module_shaders(id, meshes, outlines)

		player.set_elite_upgrade_enabled(id, false, false)
		layer.sync_now()
		_expect(not module.visible, "%s must disappear immediately when disabled" % id)


func _check_module_shaders(
	id: String,
	meshes: Array[MeshInstance3D],
	outlines: Array[MeshInstance3D]
) -> void:
	for mesh_instance in meshes:
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var material := (
				mesh_instance.get_surface_override_material(surface_index)
				as ShaderMaterial
			)
			_expect(material != null, "%s surface must use a ShaderMaterial" % id)
			if material == null:
				continue
			_expect(
				material.shader.resource_path == SHIP_SHADER_PATH,
				"%s surface must use the shared neon ship shader" % id
			)
			_expect(
				material.get_shader_parameter("animation_speed") != null
				and is_zero_approx(
					material.get_shader_parameter("animation_speed") as float
				),
				"%s shader motion must be disabled" % id
			)
	for outline in outlines:
		var material := outline.material_override as ShaderMaterial
		_expect(
			material != null and material.shader.resource_path == OUTLINE_SHADER_PATH,
			"%s outline must use the shared 3D outline shader" % id
		)


func _check_paused_upgrade_refresh(
	layer: ShipRenderLayer3D,
	player: Node2D
) -> void:
	var viewport := layer.get_node("ShipViewport") as SubViewport
	var module := layer.get_player_upgrade_visual(player, "twin_cannons")
	layer.set_render_paused(true)
	player.set_elite_upgrade_enabled("twin_cannons", true, false)
	_expect(
		module != null and module.visible,
		"Selecting an upgrade while paused must refresh its 3D module immediately"
	)
	_expect(
		viewport.render_target_update_mode == SubViewport.UPDATE_ONCE,
		"Paused upgrade selection must request one refreshed 3D frame"
	)
	player.set_elite_upgrade_enabled("twin_cannons", false, false)
	layer.set_render_paused(false)
	_expect(
		viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS,
		"Resuming after upgrade selection must restore continuous rendering"
	)


func _check_fully_upgraded_static_assembly(
	layer: ShipRenderLayer3D,
	player: Node2D
) -> void:
	for id in MOUNTED_IDS:
		player.set_elite_upgrade_enabled(id, true, false)
	layer.sync_now()

	var transforms: Dictionary = {}
	var all_meshes := layer.get_proxy_meshes(player)
	for id in MOUNTED_IDS:
		var module := layer.get_player_upgrade_visual(player, id)
		_expect(module != null and module.visible, "%s must be visible in the full build" % id)
		if module != null:
			transforms[id] = module.transform
		for mesh in layer.get_player_upgrade_meshes(player, id):
			all_meshes.append(mesh)

	var triangle_count := _count_triangles(all_meshes)
	_expect(
		triangle_count == EXPECTED_FULLY_UPGRADED_TRIANGLES,
		"Fully upgraded player must remain %d triangles, got %d"
		% [EXPECTED_FULLY_UPGRADED_TRIANGLES, triangle_count]
	)

	var sprite := player.get_node("Sprite2D") as Sprite2D
	for frame in range(4):
		sprite.frame = frame
		await get_tree().process_frame
		layer.sync_now()
		for id in MOUNTED_IDS:
			var module := layer.get_player_upgrade_visual(player, id)
			_expect(
				module != null
				and module.transform.is_equal_approx(transforms[id] as Transform3D),
				"%s must not bob, roll, or tween with sprite frames" % id
			)

	var front := player.get_node("UpgradeVisualsFront") as ShipUpgradeVisuals
	_expect(
		front.position.is_zero_approx() and is_zero_approx(front.rotation),
		"Legacy anchor driver must also remain at a static identity transform"
	)
	_check_socket_anchor_alignment(layer, player, front)


func _check_socket_anchor_alignment(
	layer: ShipRenderLayer3D,
	player: Node2D,
	anchor_driver: ShipUpgradeVisuals
) -> void:
	var socket_checks := [
		["twin_cannons", "Socket_MuzzleLeft", "twin_left"],
		["twin_cannons", "Socket_MuzzleRight", "twin_right"],
		["spread_shot_elite", "Socket_MuzzleLeft", "spread_left"],
		["spread_shot_elite", "Socket_MuzzleRight", "spread_right"],
		["rear_gunner", "Socket_MuzzleRear", "rear"],
	]
	for check in socket_checks:
		var module := layer.get_player_upgrade_visual(player, check[0])
		var socket := _find_descendant_named(module, check[1]) as Node3D
		_expect(socket != null, "%s must expose %s" % [check[0], check[1]])
		if socket == null:
			continue
		var module_local := module.global_transform.affine_inverse() * socket.global_position
		var socket_anchor := Vector2(module_local.x, module_local.z) * ShipRenderLayer3D.PIXELS_PER_MODEL_UNIT
		var gameplay_anchor := anchor_driver.get_player_local_muzzle(check[2])
		_expect(
			socket_anchor.distance_to(gameplay_anchor) <= 0.01,
			"%s socket %s must align with gameplay anchor %s, got %s vs %s"
			% [check[0], check[1], check[2], socket_anchor, gameplay_anchor]
		)


func _check_drone_proxy(
	layer: ShipRenderLayer3D,
	player: Node2D
) -> void:
	player.set_elite_upgrade_enabled("drone_escort", true, false)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	layer.sync_now()

	var drones := get_tree().get_nodes_in_group("drone_escort")
	_expect(drones.size() == 1, "Drone Escort must create exactly one gameplay node")
	if drones.size() != 1:
		return
	var drone := drones[0] as ShipDrone
	var collision := drone.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var legacy_visual := drone.get_node_or_null("DroneVisual") as CanvasItem
	_expect(collision != null, "3D Drone Escort must retain its Area2D collision")
	_expect(
		legacy_visual != null and is_zero_approx(legacy_visual.self_modulate.a),
		"Drone Escort's procedural pixels must be suppressed"
	)
	_expect(
		drone.global_position.is_equal_approx(
			player.global_position + ShipDrone.HOVER_OFFSET
		),
		"Stationary Drone Escort must hold its authored gameplay offset"
	)
	_expect(
		is_zero_approx(drone.rotation),
		"Drone Escort must not retain the cosmetic sine-roll animation"
	)
	_expect(
		layer.get_model_path_for(drone)
		== "res://assets/models/redesign/butterfly_elites/bf_elite_drone_escort.glb",
		"Drone Escort must map to its GLB"
	)
	var visual := layer.get_visual_for(drone)
	_expect(visual != null, "Drone Escort must own a 3D proxy")
	if visual != null:
		_expect(
			visual.position.is_equal_approx(layer.screen_to_world(drone.global_position)),
			"Drone Escort proxy must match its exact Area2D position"
		)
	_check_module_shaders(
		"drone_escort",
		layer.get_proxy_meshes(drone),
		layer.get_proxy_outlines(drone)
	)

	player.set_elite_upgrade_enabled("drone_escort", false, false)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(
		get_tree().get_nodes_in_group("drone_escort").is_empty(),
		"Disabling Drone Escort must remove its gameplay node and proxy source"
	)


func _check_unbind_restoration(
	game: Node,
	layer: ShipRenderLayer3D,
	player: Node2D
) -> void:
	var sprite := player.get_node("Sprite2D") as CanvasItem
	var back := player.get_node("UpgradeVisualsBack") as CanvasItem
	var front := player.get_node("UpgradeVisualsFront") as CanvasItem
	game.remove_child(player)
	_expect(
		is_equal_approx(sprite.self_modulate.a, 1.0)
		and is_equal_approx(back.self_modulate.a, 1.0)
		and is_equal_approx(front.self_modulate.a, 1.0),
		"Unbinding must restore every suppressed player visual"
	)
	_expect(
		layer.get_visual_for(player) == null,
		"Removing the player must unbind its 3D assembly"
	)
	game.add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	layer.sync_now()
	_expect(
		layer.get_visual_for(player) != null,
		"Re-adding the player must rebuild its 3D assembly"
	)
	_expect(
		is_zero_approx(sprite.self_modulate.a)
		and is_zero_approx(back.self_modulate.a)
		and is_zero_approx(front.self_modulate.a),
		"Rebinding must suppress base and upgrade pixels again"
	)


func _count_triangles(meshes: Array[MeshInstance3D]) -> int:
	var triangles := 0
	for mesh_instance in meshes:
		if mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var index_count: int = mesh_instance.mesh.surface_get_array_index_len(
				surface_index
			)
			if index_count > 0:
			triangles += floori(float(index_count) / 3.0)
			else:
				var vertex_count: int = mesh_instance.mesh.surface_get_array_len(
					surface_index
				)
			triangles += floori(float(vertex_count) / 3.0)
	return triangles


func _find_descendant_named(root: Node, target_name: String) -> Node:
	if root == null:
		return null
	if root.name == target_name:
		return root
	for child in root.get_children():
		var found := _find_descendant_named(child, target_name)
		if found != null:
			return found
	return null


func _capture_integration() -> void:
	for frame in range(5):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var output_path := ProjectSettings.globalize_path(
		"res://assets/models/mockups/shader_previews/in_game_player_upgrades_3d.png"
	)
	var error := image.save_png(output_path)
	_expect(error == OK, "Player-upgrade integration capture must save successfully")
	if error == OK:
		print("CODEX_PLAYER_UPGRADE_3D_CAPTURE_PASS: %s" % output_path)


func _finish(game: Node) -> void:
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	if _failures.is_empty():
		print("PASS: player upgrade 3D smoke tests")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
