extends Node
## Spawns enemies at timed intervals based on current wave difficulty.

const ENEMY_SCENES: Array[PackedScene] = []

var basic_enemy_scene: PackedScene = preload("res://entities/enemies/basic_enemy.tscn")
var fast_enemy_scene: PackedScene = preload("res://entities/enemies/fast_enemy.tscn")
var tank_enemy_scene: PackedScene = preload("res://entities/enemies/tank_enemy.tscn")
var bomber_enemy_scene: PackedScene = preload("res://entities/enemies/bomber_enemy.tscn")

@onready var spawn_timer: Timer = $SpawnTimer

var viewport_width: float = 720.0
var margin: float = 40.0

func _ready() -> void:
	viewport_width = get_viewport().get_visible_rect().size.x
	spawn_timer.wait_time = GameManager.get_spawn_interval()
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)

	SignalBus.wave_started.connect(_on_wave_started)
	SignalBus.game_over.connect(_on_game_over)

func start_spawning() -> void:
	spawn_timer.start()

func stop_spawning() -> void:
	spawn_timer.stop()

func _on_spawn_timer_timeout() -> void:
	if not GameManager.is_game_active:
		return
	_spawn_enemy()
	spawn_timer.wait_time = GameManager.get_spawn_interval()

func _spawn_enemy() -> void:
	var scene: PackedScene = _pick_enemy_scene()
	var enemy: Area2D = scene.instantiate()
	enemy.position = Vector2(
		randf_range(margin, viewport_width - margin),
		-40.0
	)
	get_tree().current_scene.add_child(enemy)

func _pick_enemy_scene() -> PackedScene:
	var wave := GameManager.current_wave
	# Weighted random based on wave
	var roll := randf()

	if wave <= 2:
		# Early waves: mostly basic
		if roll < 0.75:
			return basic_enemy_scene
		else:
			return fast_enemy_scene
	elif wave <= 5:
		if roll < 0.40:
			return basic_enemy_scene
		elif roll < 0.65:
			return fast_enemy_scene
		elif roll < 0.85:
			return bomber_enemy_scene
		else:
			return tank_enemy_scene
	else:
		# Later waves: everything
		if roll < 0.25:
			return basic_enemy_scene
		elif roll < 0.45:
			return fast_enemy_scene
		elif roll < 0.70:
			return bomber_enemy_scene
		else:
			return tank_enemy_scene

func _on_wave_started(_wave_number: int) -> void:
	spawn_timer.wait_time = GameManager.get_spawn_interval()

func _on_game_over(_score: int) -> void:
	stop_spawning()
