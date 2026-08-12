extends Node
## Headless coverage for the opt-in voxel material path.
##
## The test toggles the project setting in memory, so the shipped default stays
## on the existing pixel-toon path while CI can validate the voxel path without
## opening the editor.

const GAME_SCENE := preload("res://scenes/game.tscn")
const BASIC_ENEMY_SCENE := preload("res://entities/enemies/basic_enemy.tscn")
const BULLET_SCENE := preload("res://entities/bullets/bullet.tscn")
const ENEMY_BULLET_SCENE := preload("res://entities/bullets/enemy_bullet.tscn")
const SHIP_CATALOG := preload("res://effects/rendering/ship_render_catalog_3d.gd")
const VOXEL_SHADER_PATH := "res://effects/shaders/models/voxel_toon_3d.gdshader"
const OUTLINE_SHADER_PATH := "res://effects/shaders/models/pixel_outline_3d.gdshader"
const VOXEL_BACKGROUND_SHADER_PATH := "res://effects/shaders/voxel_galactic_starfield.gdshader"
const PLAYER_BOLT_SHADER_PATH := "res://effects/shaders/projectiles/voxel_player_bolt.gdshader"
const ENEMY_PLASMA_SHADER_PATH := "res://effects/shaders/projectiles/voxel_enemy_plasma_orb.gdshader"
const ORBITAL_SHADER_PATH := "res://effects/shaders/projectiles/voxel_player_orbital.gdshader"

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectSettings.set_setting(SHIP_CATALOG.VOXEL_STYLE_SETTING, true)
	var game := GAME_SCENE.instantiate()
	add_child(game)
	game.get_node("EnemySpawner").stop_spawning()
	game.get_node("PowerUpSpawner").stop_spawning()

	var player = game.get_node("Player")
	player.set_physics_process(false)
	player.position = get_viewport().get_visible_rect().size * Vector2(0.5, 0.72)

	var enemy = BASIC_ENEMY_SCENE.instantiate()
	enemy.generation = 3
	enemy.set_physics_process(false)
	enemy.position = get_viewport().get_visible_rect().size * Vector2(0.5, 0.30)
	game.add_child(enemy)

	var player_bullet = BULLET_SCENE.instantiate()
	add_child(player_bullet)
	player_bullet.call(
		"pool_activate",
		Vector2(180.0, 590.0),
		Vector2.UP,
		1.0,
		false,
		false,
		0
	)

	var enemy_bullet = ENEMY_BULLET_SCENE.instantiate()
	add_child(enemy_bullet)
	enemy_bullet.call(
		"pool_activate",
		Vector2(180.0, 110.0),
		Vector2.DOWN,
		400.0,
		Color(3.0, 0.8, 0.1, 1.0)
	)

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var layer := game.get_node_or_null("ShipRenderLayer3D") as ShipRenderLayer3D
	_expect(layer != null, "Game must expose the shared 3D ship layer")
	_expect(SHIP_CATALOG.voxel_style_enabled(), "Voxel style setting must be active in the smoke test")
	var background := game.get_node_or_null("Background") as ColorRect
	var background_material: ShaderMaterial = null
	if background != null:
		background_material = background.material as ShaderMaterial
	_expect(
		background_material != null
			and background_material.shader.resource_path == VOXEL_BACKGROUND_SHADER_PATH,
		"Background must use the voxel galaxy shader"
	)
	if layer == null:
		await _finish(game)
		return

	layer.sync_now()
	_check_hull_shader(layer, player, "player")
	_check_hull_shader(layer, enemy, "basic enemy")
	_check_canvas_shader(player_bullet, PLAYER_BOLT_SHADER_PATH, "player bolt")
	_check_canvas_shader(enemy_bullet, ENEMY_PLASMA_SHADER_PATH, "enemy plasma orb")

	player.call("grant_orbitals")
	await get_tree().process_frame
	var orbitals := get_tree().get_nodes_in_group("player_orbitals")
	_expect(orbitals.size() == 3, "Voxel smoke test must create three orbital projectiles")
	for orbital in orbitals:
		_check_canvas_shader(orbital, ORBITAL_SHADER_PATH, "orbital projectile")

	var player_visual := layer.get_visual_for(player)
	var trail: MeshInstance3D = null
	if player_visual != null:
		trail = player_visual.get_node_or_null("EngineTrails") as MeshInstance3D
	var trail_material: ShaderMaterial = null
	if trail != null:
		trail_material = trail.material_override as ShaderMaterial
	_expect(
		trail_material != null
			and trail_material.shader.resource_path == "res://effects/shaders/models/pixel_trail_3d.gdshader",
		"Voxel style must retain the existing pixel trail contract"
	)

	player.set_elite_upgrade_enabled("twin_cannons", true, false)
	layer.sync_now()
	var module_meshes := layer.get_player_upgrade_meshes(player, "twin_cannons")
	_check_shader_materials(module_meshes, "twin cannons")

	# Leave a short bridge-visible window for headless integration runners to
	# collect the PASS line and any shader compilation diagnostics.
	await get_tree().create_timer(3.0).timeout
	await _finish(game)


func _check_hull_shader(layer: ShipRenderLayer3D, source: Node2D, label: String) -> void:
	var meshes := layer.get_proxy_meshes(source)
	_expect(not meshes.is_empty(), "%s must expose at least one 3D mesh" % label)
	_check_shader_materials(meshes, label)
	var outlines := layer.get_proxy_outlines(source)
	_expect(not outlines.is_empty(), "%s must retain a silhouette outline" % label)
	for outline in outlines:
		var material := outline.material_override as ShaderMaterial
		_expect(
			material != null and material.shader.resource_path == OUTLINE_SHADER_PATH,
			"%s outline must retain the shared outline shader" % label
		)


func _check_shader_materials(meshes: Array[MeshInstance3D], label: String) -> void:
	for mesh_instance in meshes:
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var material := (
				mesh_instance.get_surface_override_material(surface_index)
				as ShaderMaterial
			)
			_expect(material != null, "%s surface must use a ShaderMaterial" % label)
			if material == null:
				continue
			_expect(
				material.shader.resource_path == VOXEL_SHADER_PATH,
				"%s surface must use the voxel toon shader" % label
			)
			_expect(
				is_equal_approx(float(material.get_shader_parameter("voxel_normal_steps")), 4.0),
				"%s surface must receive voxel normal quantization" % label
			)


func _check_canvas_shader(source: Node, shader_path: String, label: String) -> void:
	var sprite := source.get_node_or_null("Sprite2D") as Sprite2D
	var material: ShaderMaterial = null
	if sprite != null:
		material = sprite.material as ShaderMaterial
	_expect(material != null, "%s must expose a ShaderMaterial" % label)
	if material == null:
		return
	_expect(
		material.shader.resource_path == shader_path,
		"%s must use %s" % [label, shader_path]
	)
	_expect(
		is_equal_approx(float(material.get_shader_parameter("voxel_cell_scale")), 8.0),
		"%s must receive voxel cell quantization" % label
	)


func _finish(game: Node) -> void:
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	if _failures.is_empty():
		print("PASS: voxel shader smoke tests")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
