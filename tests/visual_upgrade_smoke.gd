extends Node
## Headless regression coverage for static fallback and 3D upgrade previews.
##
## Run with:
## godot --headless --path . res://tests/visual_upgrade_smoke.tscn
## (Run the .tscn wrapper, not --script: --script mode skips the autoloads
## these tests depend on and never exits.)

const PLAYER_SCENE := preload("res://entities/player/player.tscn")
const PREVIEW_SCRIPT := preload("res://entities/player/ship_upgrade_preview.gd")
const MENU_SHIP_SCRIPT := preload("res://ui/main_menu_ship.gd")

const ELITE_IDS: Array[String] = [
	"twin_cannons",
	"auto_aim",
	"drone_escort",
	"hull_plating",
	"afterburner",
	"spread_shot_elite",
	"shield_burst",
	"magnet_field",
	"overclock",
	"rear_gunner",
]

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_upgrade_pool_parity()
	_check_no_upgrade_presentation_tweens()
	_check_every_combination_fits()

	var world := Node2D.new()
	add_child(world)
	var player := PLAYER_SCENE.instantiate()
	world.add_child(player)
	await get_tree().process_frame

	_check_player_structure(player)
	await _check_static_muzzles_and_visibility(player)
	_check_reversible_state(player)
	await get_tree().process_frame
	await _check_no_node_accumulation(player)
	await _exercise_preview_3d(world, player)
	await _exercise_menu_ship_3d(world)
	for id in ELITE_IDS:
		player.set_elite_upgrade_enabled(id, true, false)
	await get_tree().process_frame
	await _check_afterimage_cache(player)

	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	if _failures.is_empty():
		print("PASS: visual upgrade smoke tests")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


func _check_upgrade_pool_parity() -> void:
	var canonical_ids: Array[String] = []
	for upgrade in GameManager.ALL_UPGRADES:
		canonical_ids.append(str(upgrade["id"]))
	var modeled_ids := PlayerShipAssembly3D.ATTACHED_IDS.duplicate()
	modeled_ids.append("drone_escort")
	canonical_ids.sort()
	modeled_ids.sort()
	_expect(
		canonical_ids == modeled_ids,
		"Every canonical elite upgrade must have a 3D player model"
	)


func _check_no_upgrade_presentation_tweens() -> void:
	var static_sources := [
		"res://effects/player_ship_assembly_3d.gd",
		"res://entities/player/ship_upgrade_preview.gd",
		"res://ui/elite_upgrade_popup.gd",
		"res://ui/main_menu_ship.gd",
	]
	for source_path in static_sources:
		var source := FileAccess.get_file_as_string(source_path)
		_expect(
			not source.contains("create_tween("),
			"%s must not create presentation Tweens" % source_path
		)


func _check_every_combination_fits() -> void:
	for mask in range(1 << ELITE_IDS.size()):
		var installed: Array[String] = []
		for index in range(ELITE_IDS.size()):
			if mask & (1 << index):
				installed.append(ELITE_IDS[index])
		_expect(
			ShipUpgradeVisuals.bounds_fit_envelope(installed),
			"Upgrade combination %d exceeds the 104×96 envelope: %s" % [mask, installed]
		)


func _check_player_structure(player: Node) -> void:
	var collision := player.get_node("CollisionShape2D") as CollisionShape2D
	_expect(collision.shape is CapsuleShape2D, "Player collision shape must remain a capsule")
	_expect(
		collision.position == Vector2.ZERO and collision.scale == Vector2.ONE,
		"Visual upgrades must not alter the collision transform"
	)
	var visual_count := 0
	for child in player.get_children():
		if child is ShipUpgradeVisuals:
			visual_count += 1
	_expect(visual_count == 2, "Player must have exactly two persistent upgrade visual layers")


func _check_reversible_state(player: Node) -> void:
	for id in ELITE_IDS:
		player.set_elite_upgrade_enabled(id, true, false)
		player.set_elite_upgrade_enabled(id, true, false)
		var active: Array[String] = player.get_active_elite_upgrade_ids()
		_expect(active.count(id) == 1, "%s must be idempotent when enabled twice" % id)
		player.set_elite_upgrade_enabled(id, false, false)
		player.set_elite_upgrade_enabled(id, false, false)
		_expect(
			not player.get_active_elite_upgrade_ids().has(id),
			"%s must be removable and idempotent when disabled twice" % id
		)


func _check_static_muzzles_and_visibility(player: Node) -> void:
	var sprite := player.get_node("Sprite2D") as Sprite2D
	var visuals := player.get_node("UpgradeVisualsFront") as ShipUpgradeVisuals
	sprite.set_process(false)
	sprite.frame = 0
	await get_tree().process_frame
	var frame_zero_anchor := visuals.get_player_local_muzzle("twin_left")
	sprite.frame = 1
	await get_tree().process_frame
	var frame_one_anchor := visuals.get_player_local_muzzle("twin_left")
	_expect(
		frame_zero_anchor.is_equal_approx(frame_one_anchor),
		"Muzzle anchors must not inherit animation-frame interpolation"
	)
	_expect(
		visuals.position.is_zero_approx() and is_zero_approx(visuals.rotation),
		"Fallback upgrade hardware must use a static identity transform"
	)
	sprite.visible = false
	await get_tree().process_frame
	_expect(not visuals.visible, "Upgrade layers must inherit base sprite visibility")
	sprite.visible = true


func _check_no_node_accumulation(player: Node) -> void:
	var stable_child_count := player.get_child_count()
	for pass_index in range(4):
		for id in ELITE_IDS:
			player.set_elite_upgrade_enabled(id, true, false)
		_expect(
			player.get_child_count() == stable_child_count,
			"Pass %d accumulated permanent ship children while enabling upgrades" % pass_index
		)
		_expect(
			get_tree().get_nodes_in_group("drone_escort").size() == 1,
			"Pass %d must create exactly one Drone Escort node" % pass_index
		)
		player.clear_elite_upgrades()
		await get_tree().process_frame
		_expect(
			player.get_child_count() == stable_child_count,
			"Pass %d left upgrade nodes behind after Clear All" % pass_index
		)
		_expect(
			get_tree().get_nodes_in_group("drone_escort").is_empty(),
			"Pass %d left the Drone Escort behind after Clear All" % pass_index
		)


func _exercise_preview_3d(world: Node2D, player: Node) -> void:
	var preview := PREVIEW_SCRIPT.new() as ShipUpgradePreview
	preview.size = Vector2(250, 66)
	world.add_child(preview)
	preview.configure(player.get_active_elite_upgrade_ids(), "twin_cannons")
	await get_tree().process_frame
	var assembly := preview.get_assembly()
	_expect(assembly != null, "Upgrade cards must build a PlayerShipAssembly3D")
	_expect(
		_is_static_viewport(preview.get_preview_viewport()),
		"Upgrade-card 3D previews must render a static frame"
	)
	if assembly == null:
		return
	var module := assembly.get_module_root("twin_cannons")
	_expect(module != null and module.visible, "Candidate 3D module must be visible in its card")
	_expect(
		module != null
		and module.scene_file_path == PlayerShipAssembly3D.MODULE_PATHS["twin_cannons"],
		"Upgrade-card candidate must instantiate the real Twin Cannons GLB"
	)
	var meshes := assembly.get_module_meshes("twin_cannons")
	_expect(not meshes.is_empty(), "Upgrade-card candidate must contain a 3D mesh")
	if not meshes.is_empty():
		var material := meshes[0].get_surface_override_material(0) as ShaderMaterial
		_expect(
			material != null
			and material.shader.resource_path == "res://effects/shaders/models/neon_ship_3d.gdshader",
			"Upgrade-card candidate must use the shared neon 3D shader"
		)
		_expect(
			is_zero_approx(float(material.get_shader_parameter("animation_speed"))),
			"Upgrade-card module shader must be static"
		)


func _exercise_menu_ship_3d(world: Node2D) -> void:
	var menu_ship := MENU_SHIP_SCRIPT.new() as Node2D
	world.add_child(menu_ship)
	await get_tree().process_frame
	var tween_count := get_tree().get_processed_tweens().size()
	menu_ship.call(&"set_layout", Vector2(1280.0, 720.0), true)
	_expect(
		get_tree().get_processed_tweens().size() == tween_count,
		"Fully upgraded menu ship must not create an intro tween"
	)
	var assembly := menu_ship.call(&"get_assembly") as PlayerShipAssembly3D
	_expect(assembly != null, "Main menu must render a fully upgraded 3D assembly")
	if assembly != null:
		for id in PlayerShipAssembly3D.ATTACHED_IDS:
			var module := assembly.get_module_root(id)
			_expect(
				module != null and module.visible,
				"Main-menu assembly must include %s" % id
			)
		_expect(
			assembly.drone_preview_root.visible,
			"Main-menu assembly must include the 3D Drone Escort"
		)
	var menu_viewport := menu_ship.call(&"get_preview_viewport") as SubViewport
	_expect(
		menu_viewport != null and _is_static_viewport(menu_viewport),
		"Main-menu 3D ship must render a static frame"
	)
	menu_ship.call(&"fly_out", Vector2(1280.0, 720.0))
	_expect(
		get_tree().get_processed_tweens().size() == tween_count,
		"Fully upgraded menu ship must not create an exit tween"
	)


func _is_static_viewport(viewport: SubViewport) -> bool:
	return (
		viewport != null
		and viewport.render_target_update_mode
		in [SubViewport.UPDATE_ONCE, SubViewport.UPDATE_DISABLED]
	)


func _check_afterimage_cache(player: Node) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var cache := player.get_node("AfterimageCache") as ShipAfterimageCache
	if DisplayServer.get_name() == "headless":
		_expect(
			cache.get_node_or_null("TemporaryAfterimageBaker") == null,
			"Headless cache builds must release their temporary viewport"
		)
		return
	_expect(cache.texture != null, "Afterimage atlas must finish baking")
	if cache.texture != null:
		_expect(
			cache.texture.get_size() == Vector2(512, 128),
			"Afterimage atlas must contain four 128×128 frames"
		)
		var image := cache.texture.get_image()
		_expect(
			image != null and image.get_used_rect().has_area(),
			"Afterimage atlas must contain rendered ship pixels"
		)
		var capture_path := OS.get_environment("VISUAL_UPGRADE_CAPTURE")
		if capture_path != "" and image != null:
			image.save_png(capture_path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
