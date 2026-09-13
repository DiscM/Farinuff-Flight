extends Node
## Scene-owned native encounter loop. No 2D actors or scene-coordinate adapters.

const Enemy := preload("res://entities/enemies/basic_enemy_3d.gd")
const Threat := preload("res://systems/threat_director.gd")
const SCENES := {
	&"basic": preload("res://entities/enemies/basic_enemy_3d.tscn"),
	&"courier": preload("res://entities/enemies/courier_enemy_3d.tscn"),
	&"fast": preload("res://entities/enemies/fast_enemy_3d.tscn"),
	&"bomber": preload("res://entities/enemies/bomber_enemy_3d.tscn"),
	&"tank": preload("res://entities/enemies/tank_enemy_3d.tscn"),
	&"sniper": preload("res://entities/enemies/sniper_enemy_3d.tscn"),
	&"boss": preload("res://entities/enemies/boss_enemy_3d.tscn"),
}
const DEV_BOSS_VARIANTS := {
	&"assault": {"index": 0, "wave": 5},
	&"bulwark": {"index": 1, "wave": 10},
	&"tempest": {"index": 2, "wave": 15},
	&"harbinger": {"index": 3, "wave": 25},
	&"core": {"index": 4, "wave": GameManager.FINAL_EXPEDITION_WAVE},
}

const INTERCEPTION := preload("res://campaign/data/encounters/interception.tres")
const ARMORED_ADVANCE := preload("res://campaign/data/encounters/armored_advance.tres")
const SNIPER_CROSSFIRE := preload("res://campaign/data/encounters/sniper_crossfire.tres")
const MINE_SWEEP := preload("res://campaign/data/encounters/mine_sweep.tres")
const PREDICTION_NET := preload("res://campaign/data/encounters/prediction_net.tres")
const ROUTE_PATTERNS := {
	&"profile_iron_wake": [ARMORED_ADVANCE, INTERCEPTION],
	&"profile_ghost_lanes": [SNIPER_CROSSFIRE, INTERCEPTION],
	&"profile_tempest_veil": [MINE_SWEEP, INTERCEPTION],
	&"profile_echo_field": [PREDICTION_NET, SNIPER_CROSSFIRE],
}
var _last_pattern_title := ""
var _pattern: Resource
var _pattern_index := 0
var _pattern_age := 0.0
var _pattern_edge := 0
var _encounter_in := 9.0
var objectives: Node
var gameplay: Node
var threat: Threat
var _spawn_in := 0.5
var _pickup_in := 8.0
var _wave_epoch := 0
var started := false
var _pending_boss_wave := 0
var _pending_boss_points := 0
var _configured := false
var _dev_boss_variant_override := -1


func configure(game: Node) -> void:
	if _configured:
		return
	add_to_group(&"native_encounter_director")
	gameplay = game
	threat = Threat.new()
	threat.enemy_group = &"native_3d_regular_enemies"
	add_child(threat)
	if not SignalBus.wave_started.is_connected(_on_wave_started):
		SignalBus.wave_started.connect(_on_wave_started)
	objectives = preload("res://systems/field_objective_controller.gd").new()
	add_child(objectives)
	objectives.configure(self)
	_configured = true


func warm_actors() -> void:
	for scene: PackedScene in SCENES.values():
		var actor := scene.instantiate() as Enemy
		gameplay.actors_root.add_child(actor)
		await get_tree().process_frame
		if DisplayServer.get_name() != "headless":
			RenderingServer.force_draw(false)
		actor.queue_free()
		await get_tree().process_frame


func start() -> void:
	started = true
	_on_wave_started(GameManager.current_wave)


func _physics_process(delta: float) -> void:
	if not started or not GameManager.is_game_active:
		return
	if _pending_boss_wave > 0:
		finish_boss(_pending_boss_wave, _pending_boss_points)
		return
	_pickup_in -= delta
	if _pickup_in <= 0.0:
		_pickup_in = randf_range(8.0, 15.0)
		spawn_pickup()
	if GameManager.boss_active:
		return
	_encounter_in -= delta
	if _pattern != null:
		_pattern_age += delta
		if _pattern_age > float(_pattern.maximum_seconds):
			_pattern = null
	elif _encounter_in <= 0.0 and GameManager.current_wave >= 3:
		_begin_pattern()
	_spawn_in -= delta
	if _spawn_in <= 0.0:
		_spawn_in = GameManager.get_spawn_interval()
		if _pattern != null:
			_spawn_pattern_member()
		elif not objectives.try_start():
			spawn_enemy(_pick_kind())


func spawn_enemy(kind: StringName, entry_edge: int = -1, lane: float = 0.5) -> Enemy:
	if not started or not GameManager.is_game_active or GameManager.boss_active or not SCENES.has(kind) or kind == &"boss" or not threat.can_spawn(kind):
		return null
	var bounds: Rect2 = gameplay.flight_space.get_combat_bounds(60.0)
	var origin := Vector3.ZERO
	var direction := Vector3.ZERO
	for attempt in range(6):
		match entry_edge if entry_edge >= 0 else randi_range(0, 3):
			0:
				origin = Vector3(lerpf(bounds.position.x + 3, bounds.end.x - 3, lane) if entry_edge >= 0 else randf_range(bounds.position.x + 3, bounds.end.x - 3), 0, bounds.position.y)
				direction = Vector3.BACK
			1:
				origin = Vector3(lerpf(bounds.position.x + 3, bounds.end.x - 3, lane) if entry_edge >= 0 else randf_range(bounds.position.x + 3, bounds.end.x - 3), 0, bounds.end.y)
				direction = Vector3.FORWARD
			2:
				origin = Vector3(bounds.position.x, 0, lerpf(bounds.position.y + 3, bounds.end.y - 3, lane) if entry_edge >= 0 else randf_range(bounds.position.y + 3, bounds.end.y - 3))
				direction = Vector3.RIGHT
			3:
				origin = Vector3(bounds.end.x, 0, lerpf(bounds.position.y + 3, bounds.end.y - 3, lane) if entry_edge >= 0 else randf_range(bounds.position.y + 3, bounds.end.y - 3))
				direction = Vector3.LEFT
		if gameplay.flight_space.combat_motion_to_screen(origin - gameplay.player.global_position).length() >= 160.0:
			break
	if gameplay.flight_space.combat_motion_to_screen(origin - gameplay.player.global_position).length() < 160.0:
		return null
	var actor := SCENES[kind].instantiate() as Enemy
	if actor is BomberEnemy3D:
		actor.configure_hazard_manager(gameplay.hazard_manager)
	gameplay.actors_root.add_child(actor)
	actor.archetype_id = kind
	gameplay.register_enemy_feedback(actor)
	if not actor.activate_generation(gameplay.flight_space, origin, direction, threat.generation):
		gameplay.unregister_enemy_feedback(actor)
		actor.queue_free()
		return null
	actor.add_to_group(&"native_3d_regular_enemies")
	threat.record_spawn(&"fast" if kind == &"courier" else kind)
	return actor


func dev_spawn_archetype(kind: StringName) -> Enemy:
	if not started or not GameManager.is_game_active or GameManager.boss_active or not SCENES.has(kind) or kind == &"boss":
		return null
	# A developer-requested actor should bypass the normal threat admission test,
	# but it still uses the production scene, generation, registration, and spawn bounds.
	var generation := threat.generation
	var bounds: Rect2 = gameplay.flight_space.get_combat_bounds(60.0)
	var origin := Vector3(bounds.get_center().x, 0.0, bounds.position.y)
	if gameplay.flight_space.combat_motion_to_screen(origin - gameplay.player.global_position).length() < 160.0:
		return null
	var actor := SCENES[kind].instantiate() as Enemy
	if actor is BomberEnemy3D:
		actor.configure_hazard_manager(gameplay.hazard_manager)
	gameplay.actors_root.add_child(actor)
	actor.archetype_id = kind
	gameplay.register_enemy_feedback(actor)
	if not actor.activate_generation(gameplay.flight_space, origin, Vector3.BACK, generation):
		gameplay.unregister_enemy_feedback(actor)
		actor.queue_free()
		return null
	actor.add_to_group(&"native_3d_regular_enemies")
	threat.record_spawn(&"fast" if kind == &"courier" else kind)
	return actor


func dev_spawn_boss_variant(variant: StringName) -> bool:
	if not DEV_BOSS_VARIANTS.has(variant) or not started or not GameManager.is_game_active:
		return false
	var definition: Dictionary = DEV_BOSS_VARIANTS[variant]
	_wave_epoch += 1
	_pending_boss_wave = 0
	_pending_boss_points = 0
	_dev_boss_variant_override = int(definition["index"])
	for enemy in get_tree().get_nodes_in_group(&"native_3d_enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()
	gameplay.projectile_manager.clear_projectiles()
	gameplay.hazard_manager.clear_hazards()
	GameManager.current_wave = int(definition["wave"])
	GameManager.orbs_collected_this_wave = 0
	GameManager.orbs_needed_this_wave = GameManager.get_orb_threshold_for_wave(GameManager.current_wave)
	GameManager.boss_active = true
	SignalBus.wave_started.emit(GameManager.current_wave)
	return true


func spawn_pickup() -> void:
	if not GameManager.is_game_active or GameManager.is_modifier_active("mod_no_powerups"):
		return
	var bounds: Rect2 = gameplay.flight_space.get_combat_bounds()
	gameplay.power_up_manager.spawn_power_up(
		Vector3(randf_range(bounds.position.x + 5, bounds.end.x - 5), 0, bounds.position.y),
		randi_range(0, 4 if GameManager.boss_active else 5)
	)


func _pick_kind() -> StringName:
	var light_only := threat.needs_light_enemy() or GameManager.current_wave <= 2
	var weights := {&"basic": 2.0, &"fast": 2.0, &"bomber": 1.0, &"tank": 1.0, &"sniper": 1.0}
	if GameManager.current_wave <= 2:
		weights[&"basic"] = 0.65
		weights[&"fast"] = 0.35
	var profile := ExpeditionManager.get_current_route_profile()
	var total := 0.0
	for kind: StringName in weights:
		if light_only and kind not in [&"basic", &"fast"]:
			weights[kind] = 0.0
		elif profile != null:
			weights[kind] = float(weights[kind]) * float(profile.get(String(kind) + "_weight"))
		total += float(weights[kind])
	var roll := randf() * total
	for kind: StringName in weights:
		roll -= float(weights[kind])
		if roll < 0.0:
			return kind
	return &"basic"


func _on_wave_started(wave: int) -> void:
	_pattern = null
	_encounter_in = 7.0
	_wave_epoch += 1
	threat.set_generation(GameManager.get_enemy_generation(wave))
	_spawn_in = 0.5
	if started and wave % 5 == 0:
		_begin_boss.call_deferred(_wave_epoch)


func _begin_boss(epoch: int) -> void:
	if epoch != _wave_epoch or not GameManager.is_game_active or not GameManager.boss_active:
		return
	for enemy in get_tree().get_nodes_in_group(&"native_3d_regular_enemies"):
		enemy.queue_free()
	gameplay.projectile_manager.clear_projectiles()
	gameplay.hazard_manager.clear_hazards()
	var bounds: Rect2 = gameplay.flight_space.get_combat_bounds()
	var boss := SCENES[&"boss"].instantiate() as Enemy
	if _dev_boss_variant_override >= 0:
		boss.set("dev_variant_override", _dev_boss_variant_override)
	gameplay.actors_root.add_child(boss)
	gameplay.register_enemy_feedback(boss)
	if boss.activate_generation(gameplay.flight_space, Vector3(bounds.get_center().x, 0, bounds.position.y + bounds.size.y * 0.22), Vector3.BACK, threat.generation):
		_dev_boss_variant_override = -1
		return
	_dev_boss_variant_override = -1
	gameplay.unregister_enemy_feedback(boss)
	boss.queue_free()


func _exit_tree() -> void:
	if SignalBus.wave_started.is_connected(_on_wave_started):
		SignalBus.wave_started.disconnect(_on_wave_started)


func finish_boss(wave: int, points: int) -> void:
	if not GameManager.boss_active or GameManager.current_wave != wave:
		_pending_boss_wave = 0
		return
	# A simultaneous player death can pause before this deferred completion.
	# Keep it scene-owned and finish after a continue instead of stranding a boss wave.
	if not started or not GameManager.is_game_active:
		_pending_boss_wave = wave
		_pending_boss_points = points
		return
	_pending_boss_wave = 0
	gameplay.projectile_manager.clear_enemy_projectiles()
	gameplay.hazard_manager.clear_hazards()
	SignalBus.boss_died.emit(points)


func _begin_pattern() -> void:
	_encounter_in = randf_range(15.0, 22.0)
	var profile := ExpeditionManager.get_current_route_profile()
	var candidates: Array = ROUTE_PATTERNS.get(profile.id, [INTERCEPTION]) if profile != null else [INTERCEPTION, ARMORED_ADVANCE]
	var eligible: Array[Resource] = []
	for candidate: Resource in candidates:
		if GameManager.current_wave >= int(candidate.minimum_wave) and str(candidate.title) != _last_pattern_title:
			eligible.append(candidate)
	_pattern = eligible.pick_random() if not eligible.is_empty() else INTERCEPTION
	_last_pattern_title = str(_pattern.title)
	_pattern_edge = int(_pattern.entry_edges[randi_range(0, _pattern.entry_edges.size() - 1)])
	_pattern_index = 0
	_pattern_age = 0.0
	_spawn_in = float(_pattern.warning_seconds)
	var edge_names := ["TOP", "BOTTOM", "LEFT", "RIGHT"]
	var entry_text: String = edge_names[_pattern_edge]
	if _pattern.opposite_edges.has(1):
		entry_text = "TOP + BOTTOM" if _pattern_edge < 2 else "LEFT + RIGHT"
	SignalBus.encounter_warning.emit("%s · %s · %s" % [_pattern.title, entry_text, "ENTERS LEFT HALF" if _pattern_edge < 2 else "ENTERS UPPER HALF"], float(_pattern.warning_seconds))


func _spawn_pattern_member() -> void:
	if _pattern == null:
		return
	var kind: StringName = _pattern.archetypes[_pattern_index]
	# A required light ship takes the slot before the next heavy member.
	if threat.needs_light_enemy() and kind not in [&"basic", &"fast"]:
		spawn_enemy(_pick_kind())
		return
	var edge := _pattern_edge
	if _pattern_index < _pattern.opposite_edges.size() and _pattern.opposite_edges[_pattern_index] == 1:
		edge = [1, 0, 3, 2][_pattern_edge]
	var actor := spawn_enemy(kind, edge, float(_pattern.lanes[_pattern_index]))
	_spawn_in = maxf(GameManager.get_spawn_interval(), float(_pattern.interval_seconds))
	if actor == null:
		return
	_pattern_index += 1
	if _pattern_index >= _pattern.archetypes.size():
		_pattern = null
