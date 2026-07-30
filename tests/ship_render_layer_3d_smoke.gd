extends Node
## Runtime regression coverage for the shared Area2D -> 3D presentation layer.
##
## Run with:
## godot --headless --path . res://tests/ship_render_layer_3d_smoke.tscn

const GAME_SCENE := preload("res://scenes/game.tscn")
const ENEMY_SCENES: Array[PackedScene] = [
	preload("res://entities/enemies/basic_enemy.tscn"),
	preload("res://entities/enemies/fast_enemy.tscn"),
	preload("res://entities/enemies/bomber_enemy.tscn"),
	preload("res://entities/enemies/tank_enemy.tscn"),
	preload("res://entities/enemies/sniper_enemy.tscn"),
]
const ARCHETYPES: Array[StringName] = [&"basic", &"fast", &"bomber", &"tank", &"sniper"]
const EXPECTED_MODEL_PATHS := [
	"res://assets/models/mockups/basic_enemy_mockup.glb",
	"res://assets/models/mockups/fast_enemy_mockup.glb",
	"res://assets/models/mockups/bomber_enemy_mockup.glb",
	"res://assets/models/mockups/tank_enemy_mockup.glb",
	"res://assets/models/mockups/sniper_enemy_mockup.glb",
]
const EXPECTED_CIRCUITS := [0.05, 0.72, 0.18, 0.45]
const EXPECTED_HEAT := [0.0, 0.08, 0.90, 0.20]
const EXPECTED_APEX := [0.0, 0.0, 0.0, 1.0]

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := GAME_SCENE.instantiate()
	add_child(game)
	game.get_node("EnemySpawner").stop_spawning()
	game.get_node("PowerUpSpawner").stop_spawning()
	await get_tree().process_frame
	await get_tree().process_frame

	var layer := game.get_node_or_null("ShipRenderLayer3D") as ShipRenderLayer3D
	_expect(layer != null, "game.tscn must contain ShipRenderLayer3D")
	if layer == null:
		await _finish(game)
		return
	if OS.get_cmdline_user_args().has("--ship-3d-capture"):
		var planet_container := game.get_node_or_null("PlanetContainer") as Node2D
		if planet_container != null:
			planet_container.visible = false

	var viewport_rect := get_viewport().get_visible_rect()
	var positions := [
		Vector2(viewport_rect.size.x * 0.16, viewport_rect.size.y * 0.29),
		Vector2(viewport_rect.size.x * 0.39, viewport_rect.size.y * 0.26),
		Vector2(viewport_rect.size.x * 0.66, viewport_rect.size.y * 0.29),
		Vector2(viewport_rect.size.x * 0.28, viewport_rect.size.y * 0.47),
		Vector2(viewport_rect.size.x * 0.75, viewport_rect.size.y * 0.44),
	]
	var enemies: Array[BaseEnemy] = []
	for index in range(ENEMY_SCENES.size()):
		var enemy := ENEMY_SCENES[index].instantiate() as BaseEnemy
		enemy.generation = index % 4 + 1
		enemy.spawn_direction = Vector2.DOWN
		enemy.position = positions[index]
		enemy.set_physics_process(false)
		game.add_child(enemy)
		enemy.set_physics_process(false)
		enemies.append(enemy)

	var player := game.get_node("Player") as Node2D
	player.set_physics_process(false)
	player.position = Vector2(viewport_rect.size.x * 0.5, viewport_rect.size.y * 0.80)
	player.rotation = 0.0
	for index in range(enemies.size()):
		enemies[index].rotation = deg_to_rad(-22.0 + float(index) * 11.0)

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	layer.sync_now()

	_check_structure(game, layer, player, enemies)
	_check_transforms(layer, player, enemies)
	_check_shader_profiles(layer, enemies)
	_check_feedback(layer, player, enemies[3])
	_check_visibility(layer, enemies[4])
	_check_generation_refresh(layer, enemies[0])
	_check_legacy_afterimages_suppressed(game, layer, player, enemies[1])
	await _check_rebind_restoration(game, layer, enemies[2])

	if OS.get_cmdline_user_args().has("--ship-3d-capture"):
		await _capture_integration()

	for enemy in enemies:
		enemy.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(layer.get_proxy_count() == 1, "Freeing regular enemies must leave only the player proxy")

	await _finish(game)


func _check_structure(
	game: Node,
	layer: ShipRenderLayer3D,
	player: Node2D,
	enemies: Array[BaseEnemy]
) -> void:
	var viewport := layer.get_node("ShipViewport") as SubViewport
	var camera := layer.get_node("ShipViewport/VisualWorld/Camera3D") as Camera3D
	var display := layer.get_node("ViewportDisplay") as TextureRect
	var background := game.get_node("Background") as CanvasItem
	var planets := game.get_node("PlanetContainer") as CanvasItem
	var visible_rect := get_viewport().get_visible_rect()
	var visible_size := Vector2i(
		roundi(visible_rect.size.x),
		roundi(visible_rect.size.y)
	)
	var expected_render_size := (
		visible_size
		+ Vector2i.ONE * ShipRenderLayer3D.RENDER_OVERSCAN_PIXELS * 2
	)
	_expect(viewport.transparent_bg, "3D ship viewport must preserve the 2D background")
	_expect(
		viewport.size == expected_render_size,
		"3D viewport must include camera-shake overscan around the live playfield"
	)
	_expect(camera.projection == Camera3D.PROJECTION_ORTHOGONAL and camera.current, "Ship camera must be current and orthographic")
	_expect(display.texture == viewport.get_texture(), "ViewportDisplay must composite the ship viewport texture")
	_expect(display.is_visible_in_tree(), "ViewportDisplay must be visible in the game canvas")
	_expect(
		display.position.is_equal_approx(
			visible_rect.position - Vector2.ONE * ShipRenderLayer3D.RENDER_OVERSCAN_PIXELS
		)
		and display.size.is_equal_approx(Vector2(expected_render_size)),
		"ViewportDisplay must place the oversized render target around the live playfield"
	)
	_expect(
		layer.screen_to_world(visible_rect.get_center()).is_equal_approx(Vector3.ZERO),
		"Overscan must preserve the visible playfield's world-space center"
	)
	_expect(
		background.z_index < planets.z_index
		and planets.z_index < layer.z_index
		and layer.z_index < 0,
		"Render order must be background, planets, 3D ships, then 2D gameplay"
	)
	_expect(layer.get_proxy_count() == 6, "Player plus five regular enemies must create six proxies")
	game.set("pause_active", true)
	game.call("_update_pause_state")
	_expect(
		viewport.render_target_update_mode == SubViewport.UPDATE_ONCE,
		"Pausing must request one final synchronized 3D frame"
	)
	game.set("pause_active", false)
	game.call("_update_pause_state")
	_expect(viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "Resuming must reactivate the 3D viewport")

	var player_sprite := player.get_node("Sprite2D") as Sprite2D
	_expect(player_sprite.visible, "Player Sprite2D must remain available as a state driver")
	_expect(is_zero_approx(player_sprite.self_modulate.a), "Player Sprite2D pixels must be suppressed")
	_expect(layer.get_model_path_for(player) == "res://assets/models/mockups/player_ship_mockup.glb", "Player must map to the player GLB")
	var player_visual := layer.get_visual_for(player)
	_expect(player_visual != null, "Player must own a 3D proxy")

	var unique_visuals: Dictionary = {}
	if player_visual != null:
		unique_visuals[player_visual.get_instance_id()] = true
	for index in range(enemies.size()):
		var enemy := enemies[index]
		var sprite := enemy.get_node("VisualRoot/Sprite2D") as Sprite2D
		_expect(enemy.archetype_id == ARCHETYPES[index], "%s must retain its archetype id" % enemy.name)
		_expect(sprite.visible, "%s Sprite2D must remain a state driver" % enemy.name)
		_expect(is_zero_approx(sprite.self_modulate.a), "%s Sprite2D pixels must be suppressed" % enemy.name)
		_expect(enemy.get_node_or_null("CollisionShape2D") != null, "%s must retain Area2D collision" % enemy.name)
		_expect(enemy.get_node_or_null("VisualRoot/Evolution") != null, "%s must retain evolution gameplay" % enemy.name)
		_expect(layer.get_model_path_for(enemy) == EXPECTED_MODEL_PATHS[index], "%s maps to the wrong GLB" % enemy.name)
		var visual := layer.get_visual_for(enemy)
		_expect(visual != null, "%s must own a 3D proxy" % enemy.name)
		if visual != null:
			_expect(not unique_visuals.has(visual.get_instance_id()), "%s must not share a proxy node" % enemy.name)
			unique_visuals[visual.get_instance_id()] = true


func _check_transforms(
	layer: ShipRenderLayer3D,
	player: Node2D,
	enemies: Array[BaseEnemy]
) -> void:
	var sources: Array[Node2D] = [player]
	for enemy in enemies:
		sources.append(enemy)
	for source in sources:
		var visual := layer.get_visual_for(source)
		if visual == null:
			continue
		var expected_position := layer.screen_to_world(source.global_position)
		_expect(
			visual.position.is_equal_approx(expected_position),
			"%s proxy position must match the projected Area2D position" % source.name
		)
		var mapped_forward := (
			layer.screen_to_world(source.global_position + Vector2.UP.rotated(source.global_rotation) * 24.0)
			- expected_position
		).normalized()
		var visual_forward := -visual.global_basis.z.normalized()
		_expect(
			visual_forward.dot(mapped_forward) > 0.999,
			"%s proxy nose must follow Area2D rotation" % source.name
		)

	player.position += Vector2(31.0, -27.0)
	player.rotation = 0.47
	layer.sync_now()
	var moved_visual := layer.get_visual_for(player)
	_expect(moved_visual != null, "Player proxy must survive transform synchronization")
	if moved_visual == null:
		return
	_expect(
		moved_visual.position.is_equal_approx(layer.screen_to_world(player.global_position)),
		"Player proxy synchronization must continue after binding"
	)


func _check_shader_profiles(layer: ShipRenderLayer3D, enemies: Array[BaseEnemy]) -> void:
	for enemy in enemies:
		var meshes := layer.get_proxy_meshes(enemy)
		var outlines := layer.get_proxy_outlines(enemy)
		_expect(not meshes.is_empty(), "%s proxy must contain a hull mesh" % enemy.name)
		_expect(not outlines.is_empty(), "%s proxy must contain the mockup outline pass" % enemy.name)
		if meshes.is_empty():
			continue
		var generation_index := enemy.generation - 1
		for mesh in meshes:
			for surface_index in range(mesh.mesh.get_surface_count()):
				var material := mesh.get_surface_override_material(surface_index) as ShaderMaterial
				_expect(material != null, "%s hull surface %d must use a ShaderMaterial" % [enemy.name, surface_index])
				if material == null:
					continue
				_expect(
					material.shader.resource_path == "res://effects/shaders/models/neon_ship_3d.gdshader",
					"%s hull surface %d uses the wrong spatial shader" % [enemy.name, surface_index]
				)
				_expect(
					is_equal_approx(
						float(material.get_shader_parameter("evolution_level")),
						float(generation_index) / 3.0
					),
					"%s hull surface %d has the wrong evolution level" % [enemy.name, surface_index]
				)
				_expect(
					is_equal_approx(float(material.get_shader_parameter("circuit_amount")), EXPECTED_CIRCUITS[generation_index]),
					"%s hull surface %d has the wrong circuit profile" % [enemy.name, surface_index]
				)
				_expect(
					is_equal_approx(float(material.get_shader_parameter("heat_amount")), EXPECTED_HEAT[generation_index]),
					"%s hull surface %d has the wrong heat profile" % [enemy.name, surface_index]
				)
				_expect(
					is_equal_approx(float(material.get_shader_parameter("apex_amount")), EXPECTED_APEX[generation_index]),
					"%s hull surface %d has the wrong apex profile" % [enemy.name, surface_index]
				)
		for outline in outlines:
			var outline_material := outline.material_override as ShaderMaterial
			_expect(
				outline_material != null
				and outline_material.shader.resource_path == "res://effects/shaders/models/neon_outline_3d.gdshader",
				"%s outline uses the wrong spatial shader" % enemy.name
			)
		var visual := layer.get_visual_for(enemy)
		if visual != null:
			var trail := visual.get_node_or_null("EngineTrails") as MeshInstance3D
			var trail_material: ShaderMaterial = null
			if trail != null:
				trail_material = trail.material_override as ShaderMaterial
			_expect(
				trail_material != null
				and trail_material.shader.resource_path == "res://effects/shaders/models/engine_trail_3d.gdshader",
				"%s must use the integrated 3D engine-trail shader" % enemy.name
			)


func _check_feedback(
	layer: ShipRenderLayer3D,
	player: Node2D,
	tank: BaseEnemy
) -> void:
	tank.modulate = Color(3.0, 3.0, 3.0)
	layer.sync_now()
	var tank_meshes := layer.get_proxy_meshes(tank)
	if not tank_meshes.is_empty():
		_expect(
			float(tank_meshes[0].get_instance_shader_parameter("instance_flash")) > 0.9,
			"Enemy hit modulation must reach the 3D hull"
		)
	tank.modulate = Color.WHITE

	var player_sprite := player.get_node("Sprite2D") as Sprite2D
	player_sprite.modulate.a = 0.2
	layer.sync_now()
	var player_visual := layer.get_visual_for(player)
	_expect(player_visual != null, "Player feedback check requires a live proxy")
	if player_visual == null:
		return
	_expect(not player_visual.visible, "Player invincibility blink must hide the 3D proxy")
	player_sprite.modulate.a = 1.0
	layer.sync_now()
	_expect(player_visual.visible, "Player proxy must return after an invincibility blink")


func _check_visibility(layer: ShipRenderLayer3D, enemy: BaseEnemy) -> void:
	var visual := layer.get_visual_for(enemy)
	_expect(visual != null, "Enemy visibility check requires a live proxy")
	if visual == null:
		return
	enemy.hide()
	layer.sync_now()
	_expect(not visual.visible, "Hiding an enemy Area2D must hide its 3D proxy")
	enemy.show()
	layer.sync_now()
	_expect(visual.visible, "Showing an enemy Area2D must restore its 3D proxy")
	var sprite := enemy.get_node("VisualRoot/Sprite2D") as Sprite2D
	sprite.visible = false
	layer.sync_now()
	_expect(not visual.visible, "Hiding an enemy state sprite must hide its 3D proxy")
	sprite.visible = true
	layer.sync_now()
	_expect(visual.visible, "Showing an enemy state sprite must restore its 3D proxy")


func _check_generation_refresh(layer: ShipRenderLayer3D, enemy: BaseEnemy) -> void:
	var controller := enemy.get_node("VisualRoot/Evolution") as EnemyEvolutionController
	var visual := layer.get_visual_for(enemy)
	var trail := visual.get_node_or_null("EngineTrails") as MeshInstance3D
	var previous_trail_material: Material = null
	if trail != null:
		previous_trail_material = trail.material_override
	enemy.generation = 4
	controller.apply_generation(enemy, 4)
	layer.sync_now()
	var meshes := layer.get_proxy_meshes(enemy)
	_expect(not meshes.is_empty(), "Generation refresh requires a bound basic-enemy mesh")
	if meshes.is_empty():
		return
	var material := meshes[0].get_surface_override_material(0) as ShaderMaterial
	_expect(
		is_equal_approx(float(material.get_shader_parameter("apex_amount")), 1.0),
		"Changing a live enemy to Generation IV must refresh its 3D material"
	)
	_expect(
		trail != null
		and trail.material_override != previous_trail_material,
		"Changing generation must also refresh the integrated engine-trail material"
	)


func _check_legacy_afterimages_suppressed(
	game: Node,
	layer: ShipRenderLayer3D,
	player: Node2D,
	fast_enemy: BaseEnemy
) -> void:
	_expect(
		layer.is_in_group(&"ship_render_layer_3d"),
		"The active 3D render layer must advertise itself to gameplay effects"
	)
	var afterimage_container := game.get_node_or_null("AfterimageContainer")
	_expect(afterimage_container != null, "Player afterimage container must exist")
	if afterimage_container != null:
		var player_ghost_count := afterimage_container.get_child_count()
		player.call(&"_spawn_afterimage")
		_expect(
			afterimage_container.get_child_count() == player_ghost_count,
			"Player boost must not overlay a legacy 2D sprite on its 3D proxy"
		)

	var game_child_count := game.get_child_count()
	fast_enemy.call(&"_spawn_afterimages")
	_expect(
		game.get_child_count() == game_child_count,
		"Fast Apex phase must not overlay legacy 2D sprites on its 3D proxy"
	)


func _check_rebind_restoration(
	game: Node,
	layer: ShipRenderLayer3D,
	enemy: BaseEnemy
) -> void:
	var sprite := enemy.get_node("VisualRoot/Sprite2D") as Sprite2D
	game.remove_child(enemy)
	_expect(
		is_equal_approx(sprite.self_modulate.a, 1.0),
		"Unbinding a 3D proxy must restore the source Sprite2D opacity"
	)
	_expect(
		layer.get_visual_for(enemy) == null,
		"Removing a source from the tree must unbind its 3D proxy"
	)
	await get_tree().process_frame

	game.add_child(enemy)
	await get_tree().process_frame
	await get_tree().process_frame
	layer.sync_now()
	_expect(
		layer.get_visual_for(enemy) != null,
		"Re-adding a supported source must create a fresh 3D proxy"
	)
	_expect(
		is_zero_approx(sprite.self_modulate.a),
		"Rebinding a supported source must suppress only its Sprite2D pixels"
	)


func _capture_integration() -> void:
	for frame in range(5):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var output_path := ProjectSettings.globalize_path(
		"res://assets/models/mockups/shader_previews/in_game_3d_integration.png"
	)
	var error := image.save_png(output_path)
	_expect(error == OK, "In-game integration capture must save successfully")
	if error == OK:
		print("CODEX_SHIP_3D_CAPTURE_PASS: %s" % output_path)


func _finish(game: Node) -> void:
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	if _failures.is_empty():
		print("PASS: shared 3D ship render layer smoke tests")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
