extends Node
## Spawns enemies at timed intervals based on current wave difficulty.
## On every 5th wave, halts normal spawning and drops a boss instead.

const ENEMY_SCENES: Array[PackedScene] = []

var basic_enemy_scene: PackedScene = preload("res://entities/enemies/basic_enemy.tscn")
var fast_enemy_scene: PackedScene = preload("res://entities/enemies/fast_enemy.tscn")
var tank_enemy_scene: PackedScene = preload("res://entities/enemies/tank_enemy.tscn")
var bomber_enemy_scene: PackedScene = preload("res://entities/enemies/bomber_enemy.tscn")
var boss_enemy_scene: PackedScene = preload("res://entities/enemies/boss_enemy.tscn")
var sniper_enemy_scene: PackedScene = preload("res://entities/enemies/sniper_enemy.tscn")

@onready var spawn_timer: Timer = $SpawnTimer

var viewport_width: float = 720.0
var viewport_height: float = 1024.0
var margin: float = 40.0

func _ready() -> void:
	viewport_width = get_viewport().get_visible_rect().size.x
	viewport_height = get_viewport().get_visible_rect().size.y
	spawn_timer.wait_time = GameManager.get_spawn_interval()
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)

	SignalBus.wave_started.connect(_on_wave_started)
	SignalBus.game_over.connect(_on_game_over)
	SignalBus.boss_died.connect(_on_boss_died)

func start_spawning() -> void:
	spawn_timer.start()

func stop_spawning() -> void:
	spawn_timer.stop()

func _on_spawn_timer_timeout() -> void:
	if not GameManager.is_game_active:
		return
	if GameManager.boss_active:
		return  # Don't spawn regulars during boss fight
	_spawn_enemy()
	spawn_timer.wait_time = GameManager.get_spawn_interval()

func _spawn_enemy() -> void:
	var scene: PackedScene = _pick_enemy_scene()
	var enemy: BaseEnemy = scene.instantiate() as BaseEnemy

	# Pick a random side: 0=top, 1=bottom, 2=left, 3=right
	var side := randi() % 4
	match side:
		0: # Top
			enemy.position = Vector2(randf_range(margin, viewport_width - margin), -40.0)
			enemy.spawn_direction = Vector2.DOWN
		1: # Bottom
			enemy.position = Vector2(randf_range(margin, viewport_width - margin), viewport_height + 40.0)
			enemy.spawn_direction = Vector2.UP
		2: # Left
			enemy.position = Vector2(-40.0, randf_range(margin, viewport_height - margin))
			enemy.spawn_direction = Vector2.RIGHT
		3: # Right
			enemy.position = Vector2(viewport_width + 40.0, randf_range(margin, viewport_height - margin))
			enemy.spawn_direction = Vector2.LEFT
	get_tree().current_scene.add_child(enemy)

func _pick_enemy_scene() -> PackedScene:
	var wave := GameManager.current_wave
	var roll := randf()

	if wave <= 2:
		if roll < 0.75:
			return basic_enemy_scene
		else:
			return fast_enemy_scene
	elif wave <= 5:
		if roll < 0.34:
			return basic_enemy_scene
		elif roll < 0.58:
			return fast_enemy_scene
		elif roll < 0.76:
			return bomber_enemy_scene
		elif roll < 0.90:
			return tank_enemy_scene
		else:
			return sniper_enemy_scene
	else:
		if roll < 0.18:
			return basic_enemy_scene
		elif roll < 0.36:
			return fast_enemy_scene
		elif roll < 0.57:
			return bomber_enemy_scene
		elif roll < 0.80:
			return tank_enemy_scene
		else:
			return sniper_enemy_scene

func _on_wave_started(wave_number: int) -> void:
	spawn_timer.wait_time = GameManager.get_spawn_interval()
	if wave_number % 5 == 0:
		call_deferred("_spawn_boss", wave_number)

func _spawn_boss(wave_number: int) -> void:
	stop_spawning()
	# Clear remaining regular enemies
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not (enemy is BossEnemy):
			enemy.call_deferred("queue_free")

	var boss: BossEnemy = boss_enemy_scene.instantiate() as BossEnemy
	boss.position = Vector2(viewport_width / 2.0, -80.0)
	boss.is_elite = (wave_number % 10 == 0)
	boss.is_tempest_core = (wave_number == 20)
	get_tree().current_scene.add_child(boss)

func _on_boss_died(_points: int) -> void:
	# Resume normal spawning for next wave
	if GameManager.is_game_active:
		start_spawning()

func _on_game_over(_score: int) -> void:
	stop_spawning()

func _on_try_again_accepted() -> void:
	if not GameManager.boss_active:
		start_spawning()
