extends Node
## Generation-aware edge spawner governed by scene-local threat systems.

var basic_enemy_scene: PackedScene = preload("res://entities/enemies/basic_enemy.tscn")
var fast_enemy_scene: PackedScene = preload("res://entities/enemies/fast_enemy.tscn")
var tank_enemy_scene: PackedScene = preload("res://entities/enemies/tank_enemy.tscn")
var bomber_enemy_scene: PackedScene = preload("res://entities/enemies/bomber_enemy.tscn")
var sniper_enemy_scene: PackedScene = preload("res://entities/enemies/sniper_enemy.tscn")
var boss_enemy_scene: PackedScene = preload("res://entities/enemies/boss_enemy.tscn")

@onready var spawn_timer: Timer = $SpawnTimer
@onready var threat_director: ThreatDirector = $ThreatDirector
@onready var special_attack_coordinator: SpecialAttackCoordinator = $SpecialAttackCoordinator

var viewport_width := 360.0
var viewport_height := 720.0
var edge_padding := 34.0
var spawn_distance := 80.0
## Minimum distance between a fresh spawn point and the player. Spawn rolls
## closer than this are re-rolled (up to MAX_SPAWN_ROLLS attempts) so an
## enemy can't materialize right on top of the ship with no reaction time.
var player_safe_distance := 160.0
const MAX_SPAWN_ROLLS := 6
var evolution_hold := false
var grace_time := 0.0


func _ready() -> void:
	_refresh_viewport_size()
	get_viewport().size_changed.connect(_refresh_viewport_size)
	spawn_timer.wait_time = GameManager.get_spawn_interval()
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	SignalBus.wave_started.connect(_on_wave_started)
	SignalBus.game_over.connect(_on_game_over)
	SignalBus.boss_died.connect(_on_boss_died)
	SignalBus.evolution_transition_finished.connect(_on_evolution_transition_finished)


func _refresh_viewport_size() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	viewport_width = viewport_size.x
	viewport_height = viewport_size.y


func start_spawning() -> void:
	if not evolution_hold:
		spawn_timer.start()


func stop_spawning() -> void:
	spawn_timer.stop()


func set_evolution_hold(enabled: bool) -> void:
	evolution_hold = enabled
	if enabled:
		stop_spawning()
	elif GameManager.is_game_active and not GameManager.boss_active:
		start_spawning()


func _on_spawn_timer_timeout() -> void:
	if not GameManager.is_game_active or GameManager.boss_active or evolution_hold:
		return
	var kind := _pick_archetype()
	if threat_director.can_spawn(kind):
		_spawn_enemy(kind)
	var interval := GameManager.get_spawn_interval()
	if grace_time > 0.0:
		grace_time = maxf(0.0, grace_time - interval * 2.0)
		interval *= 2.0
		if grace_time <= 0.0:
			special_attack_coordinator.major_attacks_enabled = true
	spawn_timer.wait_time = interval


func _spawn_enemy(kind: StringName) -> void:
	var scene := _scene_for(kind)
	var enemy := scene.instantiate() as BaseEnemy
	if enemy == null:
		return
	enemy.generation = threat_director.generation
	enemy.special_attack_coordinator = special_attack_coordinator
	var spawn := _roll_fair_spawn()
	enemy.position = spawn["position"]
	enemy.spawn_direction = spawn["direction"]
	get_tree().current_scene.add_child(enemy)
	threat_director.record_spawn(kind)

## Rolls a random edge spawn, re-rolling rolls that land too close to the
## player. After MAX_SPAWN_ROLLS attempts the last roll is accepted so the
## spawn cadence is never stalled.
func _roll_fair_spawn() -> Dictionary:
	var player := get_tree().get_first_node_in_group("player")
	var spawn := _roll_spawn()
	for attempt in MAX_SPAWN_ROLLS:
		if not is_instance_valid(player):
			break
		if spawn["position"].distance_to(player.global_position) >= player_safe_distance:
			break
		spawn = _roll_spawn()
	return spawn

## Picks a random point just off one of the four screen edges, travelling
## inward.
func _roll_spawn() -> Dictionary:
	match randi() % 4:
		0:
			return {"position": Vector2(randf_range(edge_padding, viewport_width - edge_padding), -spawn_distance),
				"direction": Vector2.DOWN}
		1:
			return {"position": Vector2(randf_range(edge_padding, viewport_width - edge_padding), viewport_height + spawn_distance),
				"direction": Vector2.UP}
		2:
			return {"position": Vector2(-spawn_distance, randf_range(edge_padding, viewport_height - edge_padding)),
				"direction": Vector2.RIGHT}
		_:
			return {"position": Vector2(viewport_width + spawn_distance, randf_range(edge_padding, viewport_height - edge_padding)),
				"direction": Vector2.LEFT}


func spawn_archetype(kind: StringName, generation_override: int = 0) -> void:
	var previous := threat_director.generation
	if generation_override > 0:
		threat_director.set_generation(generation_override)
	_spawn_enemy(kind)
	threat_director.set_generation(previous)


func spawn_boss_variant(variant: StringName) -> void:
	stop_spawning()
	_clear_regular_pressure()
	var boss := boss_enemy_scene.instantiate() as BossEnemy
	boss.position = Vector2(viewport_width / 2.0, -80.0)
	match variant:
		&"bulwark":
			boss.forced_variant = BossEnemy.BossVariant.BULWARK
		&"tempest":
			boss.forced_variant = BossEnemy.BossVariant.TEMPEST
		&"harbinger":
			boss.is_elite = true
		&"core":
			boss.is_tempest_core = true
		_:
			boss.forced_variant = BossEnemy.BossVariant.ASSAULT
	GameManager.boss_active = true
	get_tree().current_scene.add_child(boss)


func _pick_archetype() -> StringName:
	if threat_director.needs_light_enemy():
		return &"basic" if randf() < 0.56 else &"fast"
	var roll := randf()
	if GameManager.current_wave <= 2:
		return &"basic" if roll < 0.75 else &"fast"
	if GameManager.current_wave <= 5:
		if roll < 0.34:
			return &"basic"
		if roll < 0.58:
			return &"fast"
		if roll < 0.76:
			return &"bomber"
		if roll < 0.90:
			return &"tank"
		return &"sniper"
	# Stable evolved mix: 28/22/18/14/18.
	if roll < 0.28:
		return &"basic"
	if roll < 0.50:
		return &"fast"
	if roll < 0.68:
		return &"bomber"
	if roll < 0.82:
		return &"tank"
	return &"sniper"


func _scene_for(kind: StringName) -> PackedScene:
	match kind:
		&"fast":
			return fast_enemy_scene
		&"tank":
			return tank_enemy_scene
		&"bomber":
			return bomber_enemy_scene
		&"sniper":
			return sniper_enemy_scene
		_:
			return basic_enemy_scene


func _on_wave_started(wave_number: int) -> void:
	threat_director.set_generation(GameManager.get_enemy_generation(wave_number))
	spawn_timer.wait_time = GameManager.get_spawn_interval()
	if wave_number == 6 or wave_number == 11 or wave_number == 16:
		set_evolution_hold(true)
		grace_time = 8.0
		special_attack_coordinator.major_attacks_enabled = false
	else:
		special_attack_coordinator.major_attacks_enabled = true
	if wave_number % 5 == 0:
		call_deferred("_spawn_boss", wave_number)


func _spawn_boss(wave_number: int) -> void:
	# Deferred from _on_wave_started — the run may have ended in the meantime.
	if not GameManager.is_game_active:
		return
	stop_spawning()
	_clear_regular_pressure()
	var boss := boss_enemy_scene.instantiate() as BossEnemy
	boss.position = Vector2(viewport_width / 2.0, -80.0)
	boss.is_elite = wave_number % 10 == 0
	boss.is_tempest_core = wave_number == 20
	get_tree().current_scene.add_child(boss)


func _on_boss_died(_points: int) -> void:
	if GameManager.is_game_active and not evolution_hold:
		start_spawning()


func _on_evolution_transition_finished(_generation: int) -> void:
	set_evolution_hold(false)


func _on_game_over(_score: int) -> void:
	stop_spawning()


func _on_try_again_accepted() -> void:
	_clear_evolved_pressure()
	if not GameManager.boss_active and not evolution_hold:
		start_spawning()


func clear_for_transition() -> void:
	_clear_evolved_pressure()


func _clear_regular_pressure() -> void:
	for enemy in get_tree().get_nodes_in_group("regular_enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()
	_clear_evolved_pressure()


func _clear_evolved_pressure() -> void:
	for enemy in get_tree().get_nodes_in_group("regular_enemies"):
		if is_instance_valid(enemy):
			enemy.suppress_death_effects = true
	for pressure in get_tree().get_nodes_in_group("evolved_pressure"):
		if not is_instance_valid(pressure):
			continue
		if pressure.has_method("despawn"):
			pressure.despawn()
		elif pressure.has_method("clear_ordnance"):
			pressure.clear_ordnance()
		else:
			pressure.queue_free()
	special_attack_coordinator.reset_pressure()


func get_debug_state() -> String:
	return threat_director.get_debug_state() + "\n" + special_attack_coordinator.get_debug_state()
