extends Node
## Scene-owned native encounter loop. No 2D actors or scene-coordinate adapters.

const Enemy := preload("res://entities/enemies/basic_enemy_3d.gd")
const Threat := preload("res://systems/threat_director.gd")
const SCENES := {
	&"basic": preload("res://entities/enemies/basic_enemy_3d.tscn"),
	&"fast": preload("res://entities/enemies/fast_enemy_3d.tscn"),
	&"bomber": preload("res://entities/enemies/bomber_enemy_3d.tscn"),
	&"tank": preload("res://entities/enemies/tank_enemy_3d.tscn"),
	&"sniper": preload("res://entities/enemies/sniper_enemy_3d.tscn"),
	&"boss": preload("res://entities/enemies/boss_enemy_3d.tscn"),
}

var gameplay: Node
var threat: Threat
var _spawn_in := 0.5
var _pickup_in := 8.0
var _wave_epoch := 0
var started := false
var _pending_boss_wave := 0
var _pending_boss_points := 0
var _configured := false


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
	_spawn_in -= delta
	if _spawn_in <= 0.0:
		_spawn_in = GameManager.get_spawn_interval()
		spawn_enemy(_pick_kind())


func spawn_enemy(kind: StringName) -> Enemy:
	if not started or not GameManager.is_game_active or GameManager.boss_active or not SCENES.has(kind) or kind == &"boss" or not threat.can_spawn(kind):
		return null
	var bounds: Rect2 = gameplay.flight_space.get_combat_bounds(60.0)
	var origin := Vector3.ZERO
	var direction := Vector3.ZERO
	for attempt in range(6):
		match randi_range(0, 3):
			0:
				origin = Vector3(randf_range(bounds.position.x + 3, bounds.end.x - 3), 0, bounds.position.y)
				direction = Vector3.BACK
			1:
				origin = Vector3(randf_range(bounds.position.x + 3, bounds.end.x - 3), 0, bounds.end.y)
				direction = Vector3.FORWARD
			2:
				origin = Vector3(bounds.position.x, 0, randf_range(bounds.position.y + 3, bounds.end.y - 3))
				direction = Vector3.RIGHT
			3:
				origin = Vector3(bounds.end.x, 0, randf_range(bounds.position.y + 3, bounds.end.y - 3))
				direction = Vector3.LEFT
		if gameplay.flight_space.combat_motion_to_screen(origin - gameplay.player.global_position).length() >= 160.0:
			break
	var actor := SCENES[kind].instantiate() as Enemy
	gameplay.actors_root.add_child(actor)
	actor.archetype_id = kind
	gameplay.register_enemy_feedback(actor)
	if not actor.activate_generation(gameplay.flight_space, origin, direction, threat.generation):
		gameplay.unregister_enemy_feedback(actor)
		actor.queue_free()
		return null
	actor.add_to_group(&"native_3d_regular_enemies")
	threat.record_spawn(kind)
	return actor


func spawn_pickup() -> void:
	if not GameManager.is_game_active or GameManager.is_modifier_active("mod_no_powerups"):
		return
	var bounds: Rect2 = gameplay.flight_space.get_combat_bounds()
	gameplay.power_up_manager.spawn_power_up(
		Vector3(randf_range(bounds.position.x + 5, bounds.end.x - 5), 0, bounds.position.y),
		randi_range(0, 4 if GameManager.boss_active else 5)
	)


func _pick_kind() -> StringName:
	if threat.needs_light_enemy() or GameManager.current_wave <= 2:
		return &"basic" if randf() < 0.65 else &"fast"
	var choices: Array[StringName] = [&"basic", &"basic", &"fast", &"fast", &"bomber", &"tank", &"sniper"]
	return choices.pick_random()


func _on_wave_started(wave: int) -> void:
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
	gameplay.actors_root.add_child(boss)
	gameplay.register_enemy_feedback(boss)
	if boss.activate_generation(gameplay.flight_space, Vector3(bounds.get_center().x, 0, bounds.position.y + bounds.size.y * 0.22), Vector3.BACK, threat.generation):
		return
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
