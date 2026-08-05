extends Node
## Runtime regression coverage for all boss identities in the shared 3D layer.
##
## Run with:
## godot --headless --path . res://tests/boss_render_layer_3d_smoke.tscn

const GAME_SCENE := preload("res://scenes/game.tscn")
const BOSS_SCENE := preload("res://entities/enemies/boss_enemy.tscn")
const BOSS_CONFIGS := [
	{
		"name": "Assault",
		"forced_variant": BossEnemy.BossVariant.ASSAULT,
		"expected_variant": BossEnemy.BossVariant.ASSAULT,
		"visual": "Assault",
		"path": "res://assets/models/mockups/boss_assault_mockup.glb",
		"collision": Vector2(76.0, 88.0),
		"health": 23,
	},
	{
		"name": "Bulwark",
		"forced_variant": BossEnemy.BossVariant.BULWARK,
		"expected_variant": BossEnemy.BossVariant.BULWARK,
		"visual": "Bulwark",
		"path": "res://assets/models/mockups/boss_bulwark_mockup.glb",
		"collision": Vector2(96.0, 70.0),
		"health": 31,
	},
	{
		"name": "Tempest",
		"forced_variant": BossEnemy.BossVariant.TEMPEST,
		"expected_variant": BossEnemy.BossVariant.TEMPEST,
		"visual": "Tempest",
		"path": "res://assets/models/mockups/boss_tempest_mockup.glb",
		"collision": Vector2(82.0, 82.0),
		"health": 26,
	},
	{
		"name": "VoidHarbinger",
		"forced_variant": -1,
		"expected_variant": BossEnemy.BossVariant.TEMPEST,
		"visual": "VoidHarbinger",
		"path": "res://assets/models/mockups/boss_void_harbinger_mockup.glb",
		"collision": Vector2(88.0, 76.0),
		"health": 63,
		"elite": true,
	},
	{
		"name": "TempestCore",
		"forced_variant": -1,
		"expected_variant": BossEnemy.BossVariant.TEMPEST,
		"visual": "TempestCore",
		"path": "res://assets/models/mockups/boss_tempest_core_mockup.glb",
		"collision": Vector2(84.0, 80.0),
		"health": 150,
		"core": true,
	},
]
const SECTION_MODEL_PATH := "res://assets/models/mockups/tempest_section_mockup.glb"

var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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

	var viewport_rect := get_viewport().get_visible_rect()
	var positions := [
		Vector2(viewport_rect.size.x * 0.24, viewport_rect.size.y * 0.33),
		Vector2(viewport_rect.size.x * 0.76, viewport_rect.size.y * 0.33),
		Vector2(viewport_rect.size.x * 0.24, viewport_rect.size.y * 0.48),
		Vector2(viewport_rect.size.x * 0.76, viewport_rect.size.y * 0.48),
		Vector2(viewport_rect.size.x * 0.50, viewport_rect.size.y * 0.66),
	]
	var bosses: Array[BossEnemy] = []
	for index in range(BOSS_CONFIGS.size()):
		var config: Dictionary = BOSS_CONFIGS[index]
		var boss := BOSS_SCENE.instantiate() as BossEnemy
		boss.forced_variant = int(config["forced_variant"])
		boss.is_elite = bool(config.get("elite", false))
		boss.is_tempest_core = bool(config.get("core", false))
		boss.position = positions[index]
		boss.set_physics_process(false)
		game.add_child(boss)
		boss.set_physics_process(false)
		bosses.append(boss)

	var player := game.get_node("Player") as Node2D
	player.set_physics_process(false)
	player.position = Vector2(viewport_rect.size.x * 0.5, viewport_rect.size.y * 0.88)

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	layer.sync_now()

	_check_boss_identities(layer, bosses)
	var core := bosses[4]
	_check_initial_tempest_sections(layer, core)

	if OS.get_cmdline_user_args().has("--boss-3d-capture"):
		var planet_container := game.get_node_or_null("PlanetContainer") as Node2D
		if planet_container != null:
			planet_container.visible = false
		await _capture_integration()

	_check_core_immunity(core)
	_check_retained_boss_effects(layer, bosses[1])
	await _check_tempest_phase_lifecycle(layer, core)
	_check_visibility(layer, bosses[0])
	await _check_death_pause_flush(game, layer, bosses[3])

	for boss in bosses:
		if not is_instance_valid(boss):
			continue
		if is_instance_valid(boss.telegraph_marker):
			boss.telegraph_marker.queue_free()
		boss.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(
		layer.get_proxy_count() == 1,
		"Freeing all bosses and sections must leave only the player proxy"
	)

	await _finish(game)


func _check_boss_identities(
	layer: ShipRenderLayer3D,
	bosses: Array[BossEnemy]
) -> void:
	var unique_visuals: Dictionary = {}
	for index in range(bosses.size()):
		var boss := bosses[index]
		var config: Dictionary = BOSS_CONFIGS[index]
		var label := String(config["name"])
		_expect(boss is Area2D, "%s must retain its Area2D gameplay body" % label)
		_expect(
			boss.is_in_group("enemies") and not boss.is_in_group("regular_enemies"),
			"%s must remain a boss-only enemy" % label
		)
		_expect(
			boss.boss_variant == int(config["expected_variant"]),
			"%s resolved the wrong BossVariant" % label
		)
		_expect(
			boss.max_health == int(config["health"]) and not boss.attack_sequence.is_empty(),
			"%s must retain its health and attack sequence" % label
		)

		var collision := boss.get_node("CollisionShape2D") as CollisionShape2D
		var rectangle := collision.shape as RectangleShape2D
		var expected_collision: Vector2 = config["collision"]
		_expect(
			not collision.disabled
			and rectangle != null
			and rectangle.size.is_equal_approx(expected_collision),
			"%s must retain its authoritative collision dimensions" % label
		)

		var variants := boss.get_node("VisualRoot/VariantVisuals")
		var active_variants: Array[CanvasItem] = []
		for child in variants.get_children():
			if child is CanvasItem and (child as CanvasItem).visible:
				active_variants.append(child as CanvasItem)
		_expect(
			active_variants.size() == 1
			and active_variants[0].name == StringName(config["visual"]),
			"%s must retain the correct muzzle-marker variant" % label
		)
		if active_variants.size() == 1:
			var muzzle := active_variants[0].get_node("Muzzle") as Marker2D
			var boss_muzzle: Vector2 = boss.call("_get_boss_muzzle")
			_expect(
				boss_muzzle.is_equal_approx(muzzle.global_position),
				"%s must keep firing from its authoritative 2D muzzle" % label
			)

		var sprite := boss.get_node("VisualRoot/Sprite2D") as Sprite2D
		_expect(sprite.visible, "%s Sprite2D must remain an animation/state driver" % label)
		_expect(
			is_zero_approx(sprite.self_modulate.a),
			"%s legacy sprite pixels must be suppressed" % label
		)
		_expect(
			layer.get_model_path_for(boss) == String(config["path"]),
			"%s maps to the wrong boss GLB" % label
		)
		var visual := layer.get_visual_for(boss)
		_expect(visual != null, "%s must own a live 3D proxy" % label)
		if visual == null:
			continue
		_expect(
			not unique_visuals.has(visual.get_instance_id()),
			"%s must not share a proxy node" % label
		)
		unique_visuals[visual.get_instance_id()] = true
		_expect(
			_find_instanced_scene_path(visual) == String(config["path"]),
			"%s proxy instantiated the wrong PackedScene" % label
		)
		var visual_root := boss.get_node("VisualRoot") as Node2D
		_check_source_transform(layer, boss, visual, visual_root.scale, label)
		_check_proxy_shaders(layer, boss, label, true)

		var damage_effects := boss.get_node("VisualRoot/DamageEffects") as CanvasItem
		_expect(
			damage_effects.visible,
			"%s 2D damage overlays must remain available above the 3D hull" % label
		)


func _check_initial_tempest_sections(
	layer: ShipRenderLayer3D,
	core: BossEnemy
) -> void:
	_expect(
		core.tempest_phase == BossEnemy.TempestPhase.BARRIER
		and core.tempest_sections.size() == 3,
		"Tempest Core must begin with three shield pylons"
	)
	for section_variant in core.tempest_sections:
		var section := section_variant as TempestSection
		_expect(section != null, "Every Tempest Core module must remain a TempestSection")
		if section == null:
			continue
		_expect(
			section.is_in_group("tempest_sections")
			and _has_collision_shape(section),
			"%s must retain its destructible Area2D collision" % section.name
		)
		_expect(
			is_zero_approx(section.self_modulate.a),
			"%s procedural 2D pixels must be suppressed" % section.name
		)
		_expect(
			layer.get_model_path_for(section) == SECTION_MODEL_PATH,
			"%s maps to the wrong reusable section GLB" % section.name
		)
		var visual := layer.get_visual_for(section)
		_expect(visual != null, "%s must own a 3D proxy" % section.name)
		if visual != null:
			_expect(
				_find_instanced_scene_path(visual) == SECTION_MODEL_PATH,
				"%s instantiated the wrong section PackedScene" % section.name
			)
			_check_proxy_shaders(layer, section, String(section.name), false)
			_check_section_instance_color(layer, section)
			_check_source_transform(
				layer,
				section,
				visual,
				Vector2(
					section.section_size.x / 27.0,
					section.section_size.y / 48.0
				),
				String(section.name)
			)

	if not core.tempest_sections.is_empty():
		var orbit_section := core.tempest_sections[0] as TempestSection
		var previous_position := orbit_section.global_position
		core.call("_update_tempest_systems", 0.25)
		layer.sync_now()
		var orbit_visual := layer.get_visual_for(orbit_section)
		_expect(
			not orbit_section.global_position.is_equal_approx(previous_position),
			"Tempest shield pylons must retain their gameplay orbit"
		)
		if orbit_visual != null:
			_check_source_transform(
				layer,
				orbit_section,
				orbit_visual,
				Vector2(
					orbit_section.section_size.x / 27.0,
					orbit_section.section_size.y / 48.0
				),
				String(orbit_section.name)
			)

func _check_retained_boss_effects(
	layer: ShipRenderLayer3D,
	boss: BossEnemy
) -> void:
	boss.health = maxi(1, floori(float(boss.max_boss_health) * 0.30))
	boss.call("_update_damage_effects")
	var crack_one := boss.get_node("VisualRoot/DamageEffects/CrackOne") as Line2D
	var crack_two := boss.get_node("VisualRoot/DamageEffects/CrackTwo") as Line2D
	var smoke := boss.get_node("VisualRoot/DamageEffects/Smoke") as CPUParticles2D
	_expect(
		crack_one.visible and crack_two.visible and smoke.emitting,
		"Critical boss damage must retain cracks and smoke above the 3D hull"
	)
	_expect(
		layer.get_visual_for(boss) != null and layer.get_visual_for(boss).visible,
		"Critical damage overlays must not replace or hide the boss proxy"
	)

	boss.call("_pick_next_move_phase")
	_expect(
		boss.is_telegraphing
		and is_instance_valid(boss.telegraph_marker)
		and boss.telegraph_marker.visible,
		"Boss movement telegraphs must remain functional with the 3D hull"
	)


func _check_core_immunity(core: BossEnemy) -> void:
	var initial_health := core.health
	core.take_damage(10)
	_expect(
		core.health == initial_health,
		"Barrier-phase Tempest Core must remain immune to direct damage"
	)


func _check_tempest_phase_lifecycle(
	layer: ShipRenderLayer3D,
	core: BossEnemy
) -> void:
	var shield_sections: Array = core.tempest_sections.duplicate()
	var shield_visuals: Array[Node3D] = []
	for section_variant in shield_sections:
		var section := section_variant as TempestSection
		if section != null:
			var section_visual := layer.get_visual_for(section)
			if section_visual != null:
				shield_visuals.append(section_visual)
			section.take_damage(section.health)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	layer.sync_now()
	_expect(
		core.tempest_phase == BossEnemy.TempestPhase.ARMAMENTS
		and core.tempest_sections.size() == 3,
		"Destroying all shield pylons must advance to three Armaments modules"
	)
	for old_visual in shield_visuals:
		_expect(
			not is_instance_valid(old_visual) or not old_visual.is_inside_tree(),
			"Destroyed Tempest sections must remove their 3D proxies"
		)
	for section_variant in core.tempest_sections:
		var section := section_variant as TempestSection
		if section != null:
			_expect(
				layer.get_visual_for(section) != null,
				"Replacement Armaments sections must create 3D proxies"
			)
			_check_section_instance_color(layer, section)
	if not core.tempest_sections.is_empty():
		var flash_section := core.tempest_sections[0] as TempestSection
		flash_section.modulate = Color(3.0, 3.0, 3.0)
		layer.sync_now()
		var flash_meshes := layer.get_proxy_meshes(flash_section)
		if not flash_meshes.is_empty():
			_expect(
				float(
					flash_meshes[0].get_instance_shader_parameter("instance_flash")
				) > 0.9,
				"Tinted Tempest sections must retain a full white hit flash"
			)
		flash_section.modulate = Color.WHITE

	core.call("_start_tempest_phase", BossEnemy.TempestPhase.OVERLOAD, false)
	layer.sync_now()
	var meshes := layer.get_proxy_meshes(core)
	_expect(not meshes.is_empty(), "Tempest Core Overload check requires a hull mesh")
	if not meshes.is_empty():
		var instance_tint: Color = meshes[0].get_instance_shader_parameter(
			"instance_modulate"
		)
		_expect(
			instance_tint.is_equal_approx(Color(1.5, 0.45, 0.8, 1.0)),
			"Tempest Core phase tint must reach its 3D hull"
		)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(
		core.tempest_sections.is_empty(),
		"Overload must clear detachable Tempest sections"
	)


func _check_visibility(layer: ShipRenderLayer3D, boss: BossEnemy) -> void:
	var visual := layer.get_visual_for(boss)
	_expect(visual != null, "Boss visibility check requires a live proxy")
	if visual == null:
		return
	boss.hide()
	layer.sync_now()
	_expect(not visual.visible, "Hiding a BossEnemy must hide its 3D proxy")
	boss.show()
	layer.sync_now()
	_expect(visual.visible, "Showing a BossEnemy must restore its 3D proxy")


func _check_death_pause_flush(
	game: Node,
	layer: ShipRenderLayer3D,
	elite_boss: BossEnemy
) -> void:
	var visual := layer.get_visual_for(elite_boss)
	_expect(visual != null, "Elite boss death check requires a live proxy")
	if visual == null:
		return
	# Wave 10 exercises the real elite-upgrade + allocation pause path. Wave 20
	# is now reserved for the Expedition finale and shows a victory modal.
	GameManager.current_wave = 10
	GameManager.boss_active = true
	elite_boss.rewards_enabled = false
	elite_boss.suppress_death_effects = true
	elite_boss.call("_die")
	_expect(
		not elite_boss.visible and not visual.visible,
		"An elite boss must disappear from its 3D proxy before modal pause"
	)
	var viewport := layer.get_node("ShipViewport") as SubViewport
	_expect(
		bool(game.get("elite_upgrade_active"))
		and viewport.render_target_update_mode == SubViewport.UPDATE_ONCE,
		"Elite boss death must request one clean 3D frame before freezing"
	)

	# Restore the fixture without selecting a real upgrade. The game scene is
	# freed immediately after this check, including any deferred popup overlay.
	game.set("elite_upgrade_active", false)
	game.set("allocation_active", false)
	game.set("_pending_allocation_points", -1)
	game.call("_update_pause_state")
	game.get_node("EnemySpawner").stop_spawning()
	await get_tree().create_timer(0.52).timeout


func _check_source_transform(
	layer: ShipRenderLayer3D,
	source: Node2D,
	visual: Node3D,
	local_visual_scale: Vector2,
	label: String
) -> void:
	var expected_position := layer.screen_to_world(source.global_position)
	_expect(
		visual.position.is_equal_approx(expected_position),
		"%s proxy position must follow its Area2D source" % label
	)
	var mapped_forward := (
		layer.screen_to_world(
			source.global_position
			+ Vector2.UP.rotated(source.global_rotation) * 24.0
		)
		- expected_position
	).normalized()
	var visual_forward := -visual.global_basis.z.normalized()
	_expect(
		visual_forward.dot(mapped_forward) > 0.999,
		"%s proxy rotation must follow its Area2D source" % label
	)
	var source_scale := source.global_scale
	var expected_x := absf(source_scale.x * local_visual_scale.x)
	var expected_z := absf(source_scale.y * local_visual_scale.y)
	var expected_scale := Vector3(
		expected_x,
		(expected_x + expected_z) * 0.5,
		expected_z
	)
	_expect(
		visual.scale.is_equal_approx(expected_scale),
		"%s proxy scale must follow its 2D visual/collision size" % label
	)


func _check_proxy_shaders(
	layer: ShipRenderLayer3D,
	source: Node2D,
	label: String,
	expect_trail: bool
) -> void:
	var meshes := layer.get_proxy_meshes(source)
	var outlines := layer.get_proxy_outlines(source)
	_expect(not meshes.is_empty(), "%s proxy must contain a hull mesh" % label)
	_expect(not outlines.is_empty(), "%s proxy must contain an outline pass" % label)
	for mesh in meshes:
		for surface_index in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_surface_override_material(surface_index) as ShaderMaterial
			_expect(
				material != null
				and material.shader.resource_path
				== "res://effects/shaders/models/pixel_toon_3d.gdshader",
				"%s hull surface %d must use the production 3D shader"
				% [label, surface_index]
			)
	for outline in outlines:
		var material := outline.material_override as ShaderMaterial
		_expect(
			material != null
			and material.shader.resource_path
			== "res://effects/shaders/models/pixel_outline_3d.gdshader",
			"%s outline must use the production outline shader" % label
		)
	if not expect_trail:
		return
	var visual := layer.get_visual_for(source)
	var trail := visual.get_node_or_null("EngineTrails") as MeshInstance3D
	var trail_material: ShaderMaterial = null
	if trail != null:
		trail_material = trail.material_override as ShaderMaterial
	_expect(
		trail_material != null
		and trail_material.shader.resource_path
		== "res://effects/shaders/models/pixel_trail_3d.gdshader",
		"%s must use the production 3D engine-trail shader" % label
	)


func _check_section_instance_color(
	layer: ShipRenderLayer3D,
	section: TempestSection
) -> void:
	var meshes := layer.get_proxy_meshes(section)
	var outlines := layer.get_proxy_outlines(section)
	if not meshes.is_empty():
		var energy_override: Color = meshes[0].get_instance_shader_parameter(
			"instance_energy_override"
		)
		_expect(
			energy_override.is_equal_approx(
				Color(
					section.section_color.r,
					section.section_color.g,
					section.section_color.b,
					1.0
				)
			),
			"%s must pass its phase color to the shared 3D hull material"
			% section.name
		)
	if not outlines.is_empty():
		var outline_override: Color = outlines[0].get_instance_shader_parameter(
			"instance_outline_override"
		)
		_expect(
			outline_override.is_equal_approx(
				Color(
					section.section_color.r,
					section.section_color.g,
					section.section_color.b,
					1.0
				)
			),
			"%s must pass its phase color to the shared 3D outline material"
			% section.name
		)


func _find_instanced_scene_path(root: Node) -> String:
	if not root.scene_file_path.is_empty():
		return root.scene_file_path
	for child in root.get_children():
		var found := _find_instanced_scene_path(child)
		if not found.is_empty():
			return found
	return ""


func _has_collision_shape(root: Node) -> bool:
	for child in root.get_children():
		if child is CollisionShape2D:
			return true
	return false


func _capture_integration() -> void:
	for frame in range(5):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var output_path := ProjectSettings.globalize_path(
		"res://assets/models/mockups/shader_previews/in_game_boss_3d_integration.png"
	)
	var error := image.save_png(output_path)
	_expect(error == OK, "In-game boss integration capture must save successfully")
	if error == OK:
		print("CODEX_BOSS_3D_CAPTURE_PASS: %s" % output_path)


func _finish(game: Node) -> void:
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	if _failures.is_empty():
		print("PASS: boss 3D render layer smoke tests")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
