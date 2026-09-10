extends Native3DGameplay
## Deterministic native completion coverage. CI runs this scene headlessly; the
## local verification pass for this change remains file-only.
const BossScene := preload("res://entities/enemies/boss_enemy_3d.tscn")
const BossScript := preload("res://entities/enemies/boss_enemy_3d.gd")
const EnemyScene := preload("res://entities/enemies/basic_enemy_3d.tscn")
const EnemyScenes := {
	&"basic": preload("res://entities/enemies/basic_enemy_3d.tscn"),
	&"fast": preload("res://entities/enemies/fast_enemy_3d.tscn"),
	&"bomber": preload("res://entities/enemies/bomber_enemy_3d.tscn"),
	&"tank": preload("res://entities/enemies/tank_enemy_3d.tscn"),
	&"sniper": preload("res://entities/enemies/sniper_enemy_3d.tscn"),
}
const EnemyModelScales := {
	&"basic": 0.45,
	&"fast": 0.22,
	&"bomber": 0.37,
	&"tank": 0.68,
	&"sniper": 0.33,
}
const EnemySocketBindings := {
	&"basic": {
		&"Socket_Muzzle": [&"MuzzleCenter"],
		&"Socket_EngineLeft": [&"EngineLeft"],
		&"Socket_EngineRight": [&"EngineRight"],
	},
	&"fast": {
		&"Socket_Muzzle": [&"MuzzleCenter"],
		&"Socket_EngineLeft": [&"EngineLeft"],
		&"Socket_EngineRight": [&"EngineRight"],
	},
	&"bomber": {
		&"Socket_Muzzle": [&"MuzzleCenter"],
		&"Socket_EngineLeft": [&"EngineLeft"],
		&"Socket_EngineRight": [&"EngineRight"],
		&"Socket_PayloadLeft": [&"BombBayLeft"],
		&"Socket_PayloadRight": [&"BombBayRight"],
	},
	&"tank": {
		&"Socket_Muzzle": [&"MuzzleCenter"],
		&"Socket_EngineLeft": [&"EngineLeft"],
		&"Socket_EngineRight": [&"EngineRight"],
	},
	&"sniper": {
		&"Socket_Muzzle": [&"MuzzleCenter", &"LaserOrigin"],
		&"Socket_EngineLeft": [&"EngineLeft"],
		&"Socket_EngineRight": [&"EngineRight"],
	},
}
const EnemyModelShader: Shader = preload(
	"res://effects/shaders/models/imported_enemy_surface_3d.gdshader"
)
const UpgradeCatalog := preload("res://entities/player/native_player_upgrades.gd")
const PhysicsLayers := preload("res://systems/native_3d_physics_layers.gd")
var _failures: Array[String] = []

class DamageTarget extends Area3D:
	var damage_received := 0
	func take_damage(amount: int) -> void:
		damage_received += amount

func _ready() -> void:
	await super._ready()
	_run_checks.call_deferred()

func _run_checks() -> void:
	_expect(GameManager.is_game_active, "Native scene must initialize")
	_check_native_actor_graph()
	_check_generation_resources()
	await _check_enemy_model_integrations()
	_check_pool_contract()
	await _check_native_registries_and_checkout_reuse()
	_check_upgrade_contract()
	await _check_projectile_contract()
	await _check_boss_variants()
	_check_continue_transition()
	GameManager.current_wave = 1
	GameManager.is_game_active = false
	if _failures.is_empty():
		print("NATIVE_COMPLETION_SMOKE_PASS")
		print("PASS: native graph, upgrades, projectile reuse, pools, transitions, and five boss variants")
		await get_tree().process_frame
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("NATIVE_COMPLETION_SMOKE_FAIL: %d assertion(s)" % _failures.size())
		await get_tree().process_frame
		get_tree().quit(1)


func _check_native_actor_graph() -> void:
	_expect(player is Player3D, "Native gameplay must mount Player3D")
	_expect(player.get_parent() == actors_root, "Player3D must be under the native actor root")
	_expect(actors_root.get_child_count() == 1, "Native smoke starts with only the Player3D actor")
	for actor in actors_root.get_children():
		_expect(actor is Node3D, "Native combat actors must stay in the 3D scene graph")
		_expect(not actor is Node2D, "Native combat actors must not use a 2D node")
	for path in ["Projectiles3D", "Pickups3D", "PowerUps3D", "Effects3D", "Hazards3D", "PoolRoot3D"]:
		_expect($World3D.get_node_or_null(path) is Node3D, "Native world container exists: " + path)
	_expect($World3D/PoolRoot3D.process_mode == Node.PROCESS_MODE_DISABLED, "Native pool root is inert")
	_expect(projectile_manager.is_ready, "Native projectile pool is warmed")
	_expect(xp_orb_manager.is_ready, "Native XP orb pool is warmed")
	_expect(power_up_manager.is_ready, "Native power-up pool is warmed")
	_expect(effect_manager.is_ready, "Native effect pool is warmed")
	_expect(hazard_manager.is_ready, "Native hazard pool is warmed")
	var effect_metrics: Dictionary = effect_manager.get_metrics()
	_expect(int(effect_metrics["pool_size"]) == 64, "Native presentation effect budget is 64")
	_expect(int(effect_metrics["local_lights_capacity"]) == 4, "Native presentation light budget is 4")
	_expect(
		Performance.has_custom_monitor(&"native_3d/frame_process_ms"),
		"Native presentation timing monitor is registered"
	)


func _check_generation_resources() -> void:
	var generations: Array = BasicEnemy.GENERATION_STATS
	_expect(generations.size() == 4, "Basic enemy exposes four native generation resources")
	for index in generations.size():
		var stats := generations[index] as EnemyGenerationStats
		_expect(stats != null, "Generation %d resource loads as EnemyGenerationStats" % (index + 1))
		if stats == null:
			continue
		_expect(stats.max_health > 0, "Generation %d has health" % (index + 1))
		_expect(stats.move_speed > 0.0, "Generation %d has movement speed" % (index + 1))
		_expect(stats.base_points > 0, "Generation %d has reward points" % (index + 1))


func _check_enemy_model_integrations() -> void:
	for archetype in EnemyScenes:
		var enemy := (EnemyScenes[archetype] as PackedScene).instantiate() as BasicEnemy
		actors_root.add_child(enemy)
		var model_root := enemy.get_node("Visuals").get_child(0) as Node3D
		var expected_scale := Vector3.ONE * float(EnemyModelScales[archetype])
		_expect(
			model_root.scale.is_equal_approx(expected_scale),
			"%s enemy uses its authored runtime fit scale" % archetype
		)
		var meshes := model_root.find_children("*", "MeshInstance3D", true, false)
		_expect(
			meshes.size() >= 4 and meshes.size() <= 8,
			"%s enemy uses a bounded material-mesh budget" % archetype
		)
		var visual_bounds := AABB()
		var has_visual_bounds := false
		var surface_count := 0
		var shader_surface_count := 0
		var emissive_surface_count := 0
		var authored_colors: Array[Color] = []
		for node in meshes:
			var mesh_instance := node as MeshInstance3D
			var to_enemy := enemy.global_transform.affine_inverse() * mesh_instance.global_transform
			var mesh_bounds := to_enemy * mesh_instance.get_aabb()
			visual_bounds = visual_bounds.merge(mesh_bounds) if has_visual_bounds else mesh_bounds
			has_visual_bounds = true
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				surface_count += 1
				var material := mesh_instance.get_active_material(surface_index)
				if (
					material is ShaderMaterial
					and (material as ShaderMaterial).shader == EnemyModelShader
				):
					shader_surface_count += 1
					var shader_material := material as ShaderMaterial
					authored_colors.append(shader_material.get_shader_parameter(&"base_color"))
					if float(shader_material.get_shader_parameter(&"emission_strength")) > 0.0:
						emissive_surface_count += 1
		_expect(
			shader_surface_count == surface_count and surface_count > 0,
			"%s enemy adapts every Blender surface to the runtime enemy shader" % archetype
		)
		_expect(
			_has_authored_role_color(archetype, authored_colors),
			"%s enemy preserves its authored role palette: %s" % [archetype, authored_colors]
		)
		_expect(
			emissive_surface_count > 0,
			"%s enemy preserves authored emissive surfaces" % archetype
		)
		var hitbox := enemy.get_node("CollisionShape3D").shape as BoxShape3D
		_expect(
			has_visual_bounds and hitbox.size.x <= visual_bounds.size.x * 1.25,
			"%s enemy hitbox does not extend far beyond its visible hull" % archetype
		)
		for imported_name in EnemySocketBindings[archetype]:
			var imported_socket := model_root.find_child(imported_name, true, false) as Node3D
			_expect(imported_socket != null, "%s imports %s" % [archetype, imported_name])
			if imported_socket == null:
				continue
			for wrapper_name in EnemySocketBindings[archetype][imported_name]:
				var wrapper := enemy.get_node("Attachments/Sockets/%s" % wrapper_name) as Node3D
				_expect(
					wrapper.global_position.distance_to(imported_socket.global_position) < 0.002,
					"%s %s matches authored %s" % [archetype, wrapper_name, imported_name]
				)
		enemy.queue_free()
		await get_tree().process_frame


func _has_authored_role_color(archetype: StringName, colors: Array[Color]) -> bool:
	for color in colors:
		match archetype:
			&"basic":
				if color.r > 0.75 and color.r > color.g * 3.0 and color.r > color.b * 3.5:
					return true
			&"fast":
				if color.r > 0.90 and color.g > 0.25 and color.g < 0.40 and color.b < 0.15:
					return true
			&"bomber":
				if color.g > 0.35 and color.g > color.r * 1.50 and color.g > color.b * 2.0:
					return true
			&"tank":
				if color.b > 0.70 and color.b > color.r * 1.40 and color.b > color.g * 2.5:
					return true
			&"sniper":
				if color.b > 0.75 and color.b > color.g * 1.35 and color.b > color.r * 4.0:
					return true
	return false


func _check_pool_contract() -> void:
	var projectile_metrics: Dictionary = projectile_manager.get_metrics()
	_check_pool_metrics(projectile_metrics["player"], "active", "pool_size", "player projectile pool")
	_check_pool_metrics(projectile_metrics["enemy"], "active", "pool_size", "enemy projectile pool")
	_check_pool_metrics(effect_manager.get_metrics(), "active", "pool_size", "native effect pool")
	_check_pool_metrics(xp_orb_manager.get_metrics(), "active", "pool_size", "XP orb pool")
	_check_pool_metrics(power_up_manager.get_metrics(), "active", "pool_size", "power-up pool")

	var hazard_metrics: Dictionary = hazard_manager.get_metrics()
	_check_pool_metrics(hazard_metrics, "active", "pool_size", "seeker fragment pool")
	_check_pool_metrics(hazard_metrics, "mine_active", "mine_pool_size", "mine pool")
	_check_pool_metrics(hazard_metrics, "field_active", "field_pool_size", "plasma field pool")
	_expect(
		int(hazard_metrics["total_active"])
			<= int(hazard_metrics["pool_size"])
			+ int(hazard_metrics["mine_pool_size"])
			+ int(hazard_metrics["field_pool_size"])
			+ int(hazard_metrics["rail_pool_size"]),
		"Native hazard active count stays within all warmed capacities"
	)


func _check_pool_metrics(metrics: Dictionary, active_key: String, size_key: String, label: String) -> void:
	_expect(metrics.has("pool_growth_after_warmup"), label + " reports pool growth")
	_expect(
		int(metrics.get("pool_growth_after_warmup", -1)) == 0,
		label + " must not grow after warmup"
	)
	_expect(metrics.has(active_key) and metrics.has(size_key), label + " reports active/capacity metrics")
	if metrics.has(active_key) and metrics.has(size_key):
		_expect(
			int(metrics[active_key]) <= int(metrics[size_key]),
			label + " active count stays within capacity"
		)


func _check_native_registries_and_checkout_reuse() -> void:
	# Scene-owned registries must discover review-spawned actors and remove them
	# on tree exit so Auto-Aim and radius damage can reuse the same array safely.
	var enemy := EnemyScene.instantiate() as BasicEnemy
	actors_root.add_child(enemy)
	var enemy_id := enemy.get_instance_id()
	_expect(_get_homing_targets().has(enemy), "Native enemy registry tracks child actors")
	_expect(
		enemy.activate_generation(
			flight_space,
			player.global_position + Vector3(0.0, 0.0, -180.0),
			Vector3.BACK,
			1
		),
		"Registry test enemy activates"
	)
	enemy.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	var cached_after_exit := false
	for candidate in _get_homing_targets():
		if is_instance_valid(candidate) and candidate.get_instance_id() == enemy_id:
			cached_after_exit = true
	_expect(not cached_after_exit, "Native enemy registry removes exiting actors")

	projectile_manager.fire_player_projectile(player.global_position, Vector3.FORWARD)
	projectile_manager.fire_player_projectile(player.global_position, Vector3.FORWARD)
	var checkout: Array = projectile_manager._pools[Projectile.Kind.PLAYER].checked_out
	_expect(checkout.size() >= 2, "Projectile checkout tracks two simultaneous shots")
	if checkout.size() >= 2:
		var first := checkout[0] as Projectile3D
		var second := checkout[1] as Projectile3D
		first.despawn()
		await _wait_for_pool_returns()
		_expect(second.is_active, "Swap removal keeps the remaining projectile active")
		_expect(
			int(projectile_manager.get_metrics()["player"]["active"]) >= 1,
			"Projectile metrics retain the remaining checkout after return"
		)
		second.despawn()
		await _wait_for_pool_returns()


func _check_upgrade_contract() -> void:
	var supported: Array[String] = UpgradeCatalog.SUPPORTED_IDS.duplicate()
	_expect(supported.size() == 13, "Native upgrade catalog contains 13 IDs")
	var seen: Dictionary = {}
	for id in supported:
		_expect(not seen.has(id), "Native upgrade catalog IDs are unique: " + id)
		seen[id] = true

	var lives_before := GameManager.lives
	_expect(not player.apply_elite_upgrade("not_a_native_upgrade"), "Unsupported upgrade is rejected")
	for id in supported:
		_expect(player.apply_elite_upgrade(id), "Upgrade applies: " + id)
		_expect(not player.apply_elite_upgrade(id), "Duplicate rejected: " + id)
	_expect(player.get_active_elite_upgrade_ids().size() == 13, "All native capabilities are active")
	for id in supported:
		_expect(player.has_elite_upgrade(id), "Active upgrade is queryable: " + id)
	_expect(GameManager.lives == lives_before + 1, "Hull Plating applies its life bonus once")
	_expect(player.has_elite_upgrade("spread_shot_elite"), "Elite spread upgrade is active")
	_expect(player.has_elite_upgrade("auto_aim"), "Auto-Aim upgrade is active")
	_expect(player.has_elite_upgrade("piercing"), "Piercing upgrade is active")
	_expect(player.has_elite_upgrade("explosive_rounds"), "Explosive upgrade is active")


func _check_projectile_contract() -> void:
	player.last_aim_direction = Vector3.FORWARD
	player.has_spread_shot = false
	_expect(player._get_fire_directions().size() == 3, "Elite spread produces a three-way fan")
	player.has_spread_shot = true
	_expect(player._get_fire_directions().size() == 5, "Temporary and elite spread stack to five directions")

	var first := DamageTarget.new()
	var second := DamageTarget.new()
	$World3D.add_child(first)
	$World3D.add_child(second)
	first.collision_layer = PhysicsLayers.ENEMY_CRAFT
	second.collision_layer = PhysicsLayers.ENEMY_CRAFT
	projectile_manager.fire_player_projectile(player.global_position, Vector3.FORWARD)
	var shots := get_tree().get_nodes_in_group(&"player_projectiles")
	_expect(not shots.is_empty(), "Player projectile acquired")
	var configured_projectile_id := -1
	if not shots.is_empty():
		var shot := shots.back() as Projectile3D
		configured_projectile_id = shot.get_instance_id()
		_expect(shot.homing and shot.piercing and shot.explosive, "Projectile snapshots homing/piercing/explosive modifiers")
		shot._report_hit(first, player.global_position)
		shot._report_hit(first, player.global_position)
		shot._report_hit(second, player.global_position)
		_expect(first.damage_received == WeaponTuning.BASE_DAMAGE + GameManager.bonus_damage, "Piercing target hit exactly once")
		_expect(second.damage_received == first.damage_received, "Piercing continues to another target")
		_expect(shot.is_active, "Piercing retains projectile")

	projectile_manager.clear_projectiles()
	first.queue_free()
	second.queue_free()
	player.reset_elite_upgrades()
	player.reset_power_up_state()
	await _wait_for_pool_returns()
	_expect(player.get_active_elite_upgrade_ids().is_empty(), "Reset clears permanent local state")
	_expect(not player.is_drone_escort_enabled(), "Reset disables drone")

	projectile_manager.fire_player_projectile(player.global_position, Vector3.FORWARD)
	shots = get_tree().get_nodes_in_group(&"player_projectiles")
	_expect(not shots.is_empty(), "Projectile pool remains usable after reset")
	if not shots.is_empty():
		var recycled := shots.back() as Projectile3D
		_expect(recycled.get_instance_id() == configured_projectile_id, "Projectile pool reuses the same instance")
		_expect(not recycled.homing and not recycled.piercing and not recycled.explosive, "Pool reuse clears projectile modifiers")
		_expect(not recycled.is_deflected, "Pool reuse clears deflection state")
	projectile_manager.clear_projectiles()
	await _wait_for_pool_returns()
	_check_pool_contract()


func _wait_for_pool_returns() -> void:
	# The wrappers return on a deferred call after physics-query flushing. Two
	# idle frames make this deterministic without a wall-clock sleep.
	await get_tree().process_frame
	await get_tree().process_frame


func _check_boss_variants() -> void:
	_expect(BossScript.TITLES.size() == 5, "Boss catalog contains five hull variants")
	var expected_titles := [
		"ASSAULT COMMANDER", "IRON BULWARK", "TEMPEST", "VOID HARBINGER", "TEMPEST CORE"
	]
	_expect(BossScript.TITLES == expected_titles, "Boss hull titles remain ordered")
	var original_wave := GameManager.current_wave
	var expected_milestones := [
		{"wave": 5, "variant": 0},
		{"wave": 10, "variant": 1},
		{"wave": 15, "variant": 2},
		{"wave": 20, "variant": 4},
		{"wave": 25, "variant": 3},
	]
	for milestone: Dictionary in expected_milestones:
		var wave := int(milestone["wave"])
		var index := int(milestone["variant"])
		GameManager.current_wave = wave
		_expect(
			BossScript.resolve_variant_for_wave(wave) == index,
			"Public boss selection resolves Wave %d to variant %d" % [wave, index]
		)
		var boss := BossScene.instantiate()
		actors_root.add_child(boss)
		_expect(boss.activate_generation(flight_space, Vector3.ZERO, Vector3.BACK, 1), "Boss activates")
		_expect(boss.variant == index, "Wave %d selects the stable boss hull variant %d" % [wave, index])
		var visible_hulls := 0
		for hull in boss.get_node("Visuals").get_children():
			if hull is Node3D and hull.visible:
				visible_hulls += 1
		_expect(visible_hulls == 1, "Exactly one boss hull is visible for variant %d" % index)
		var expected_sections := 0 if index == 0 else 2
		_expect(boss._active_section_count() == expected_sections, "Boss section count matches variant")
		if index > 0:
			_expect(boss._sections.size() == 2, "Boss variant has two destructible sections")
			boss._sections[0].take_damage(99999)
			_expect(boss._active_section_count() == 1, "Destroyed pod stops contributing")
			_expect(not boss._sections[0].is_active and boss._sections[1].is_active, "Only the damaged pod deactivates")
			boss._sections[1].take_damage(99999)
			_expect(boss._active_section_count() == 0, "Both destroyed pods stop contributing")
		boss.queue_free()
		await get_tree().process_frame
	GameManager.current_wave = original_wave


func _check_continue_transition() -> void:
	var original_active := GameManager.is_game_active
	var original_boss_active := GameManager.boss_active
	var original_completed := GameManager.expedition_completed
	var original_wave := GameManager.current_wave
	GameManager.expedition_completed = false
	GameManager.is_game_active = false
	_expect(not GameManager.continue_into_endless(), "Endless continuation is gated before victory")
	GameManager.expedition_completed = true
	GameManager.current_wave = GameManager.FINAL_EXPEDITION_WAVE + 1
	_expect(GameManager.continue_into_endless(), "Victory can continue into Endless")
	_expect(GameManager.is_game_active, "Endless continuation reactivates gameplay")
	_expect(not GameManager.expedition_completed, "Endless continuation consumes victory state")
	_expect(GameManager.current_wave >= GameManager.FINAL_EXPEDITION_WAVE + 1, "Endless resumes after final wave")
	GameManager.is_game_active = original_active
	GameManager.boss_active = original_boss_active
	GameManager.expedition_completed = original_completed
	GameManager.current_wave = original_wave

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
