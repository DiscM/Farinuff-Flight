extends Native3DGameplay
## Lifecycle checks for the pooled presentation and world-space propulsion.

var _failures: Array[String] = []


func _ready() -> void:
	await super._ready()
	player.set_physics_process(false)
	await _check_effect_reuse()
	await _check_pause_and_trails()
	await _check_death_routes()
	effect_manager.clear_effects()
	await get_tree().process_frame
	await get_tree().process_frame
	var metrics := effect_manager.get_metrics()
	_expect(int(metrics.active) == 0 and int(metrics.local_lights_active) == 0, "Cleanup returns effects and light claims")
	_expect(int(metrics.pool_growth_after_warmup) == 0, "New effects never grow the warmed pool")
	for failure in _failures:
		push_error(failure)
	print("FRONTIER_VISUAL_SMOKE_PASS" if _failures.is_empty() else "FRONTIER_VISUAL_SMOKE_FAIL")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check_effect_reuse() -> void:
	# Recycle every kind through the same pool so fragment visibility, mesh choice,
	# duration, shader uniforms, and local-light claims cannot leak into later shots.
	for kind in NativeEffect.EffectKind.values():
		_expect(effect_manager.play_effect(kind, Vector3.ZERO), "Effect can play after warm-up: %s" % kind)
		await get_tree().create_timer(0.9).timeout
		await get_tree().process_frame
		var metrics := effect_manager.get_metrics()
		_expect(int(metrics.active) == 0, "Effect expires: %s" % kind)
		_expect(int(metrics.local_lights_active) == 0, "Light claim expires: %s" % kind)
	for index in effect_manager.pool_size:
		_expect(effect_manager.play_effect(NativeEffect.EffectKind.ARMOR_BREAK, Vector3.ZERO), "Warmed capacity is available")
	_expect(not effect_manager.play_effect(NativeEffect.EffectKind.REFLECT, Vector3.ZERO), "Saturation rejects extra effects")
	_expect(int(effect_manager.get_metrics().local_lights_active) <= 4, "Saturation respects light budget")
	effect_manager.clear_effects()
	await get_tree().process_frame
	await get_tree().process_frame


func _check_pause_and_trails() -> void:
	var ribbons := player.get_node("EngineRibbons")
	for index in 90:
		player.position.x += 0.12
		ribbons.advance(1.0 / 60.0, 1.0, true, true)
	_expect(ribbons._left.size() == ribbons.MAX_SAMPLES, "Ribbon history remains bounded")
	effect_manager.play_effect(NativeEffect.EffectKind.VOID_COLLAPSE, Vector3.ZERO)
	await get_tree().process_frame
	var effect := effect_manager._checked_out.back() as NativeEffect
	get_tree().paused = true
	var elapsed := effect._elapsed
	var sky_time: float = $Backdrop/BackgroundShaderClock._elapsed_seconds
	var landmark_transform: Transform3D = $World3D/FrontierLandmarks._relay.transform
	await get_tree().create_timer(0.12, true).timeout
	_expect(is_equal_approx(effect._elapsed, elapsed), "Paused effects stop advancing")
	_expect(is_equal_approx($Backdrop/BackgroundShaderClock._elapsed_seconds, sky_time), "Paused sky stops advancing")
	_expect($World3D/FrontierLandmarks._relay.transform.is_equal_approx(landmark_transform), "Paused landmark stops rotating")
	get_tree().paused = false
	player.position.x += 40.0
	ribbons.advance(1.0 / 60.0, 1.0, false, true)
	_expect(ribbons._left.size() == 1, "Teleports clear ribbon history")
	ribbons.advance(1.0 / 60.0, 0.0, false, false)
	_expect(ribbons._left.is_empty() and ribbons.mesh.get_surface_count() == 0, "Inactive propulsion clears geometry")
	player.position = Vector3.ZERO


func _check_death_routes() -> void:
	var scenes := [preload("res://entities/enemies/basic_enemy_3d.tscn"), preload("res://entities/enemies/tank_enemy_3d.tscn"), preload("res://entities/enemies/basic_enemy_3d.tscn")]
	var expected := [NativeEffect.EffectKind.DEATH, NativeEffect.EffectKind.ARMOR_BREAK, NativeEffect.EffectKind.VOID_COLLAPSE]
	for index in scenes.size():
		var enemy := scenes[index].instantiate() as BasicEnemy
		# EncounterDirector assigns the class identity before actor activation.
		enemy.archetype_id = &"tank" if index == 1 else &"basic"
		actors_root.add_child(enemy)
		enemy.activate_generation(flight_space, Vector3(20, 0, 0), Vector3.FORWARD, 3 if index == 2 else 1)
		enemy.take_damage(99999)
		var last_effect := effect_manager._checked_out.back() as NativeEffect
		_expect(last_effect._kind == expected[index], "Enemy destruction route %d (%s): expected %d, got %d" % [index, enemy.archetype_id, expected[index], last_effect._kind])
		await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
