extends Node
## Periodically spawns a random power-up from the top of the screen.

const POWER_UP_SCENE: PackedScene = preload("res://entities/powerups/power_up.tscn")

@onready var spawn_timer: Timer = $SpawnTimer

var viewport_width: float = 720.0
var margin: float = 60.0
var min_interval: float = 8.0
var max_interval: float = 15.0

func _ready() -> void:
	viewport_width = get_viewport().get_visible_rect().size.x
	spawn_timer.one_shot = true
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	SignalBus.game_over.connect(_on_game_over)

func start_spawning() -> void:
	_restart_timer()

func stop_spawning() -> void:
	spawn_timer.stop()

func _restart_timer() -> void:
	spawn_timer.wait_time = randf_range(min_interval, max_interval)
	spawn_timer.start()

func _on_spawn_timer_timeout() -> void:
	if not GameManager.is_game_active:
		return
	_spawn_powerup()
	_restart_timer()

func _spawn_powerup() -> void:
	var pu: Area2D = POWER_UP_SCENE.instantiate()
	pu.position = Vector2(
		randf_range(margin, viewport_width - margin),
		-20.0
	)
	# Random type
	var type_index := randi_range(0, 5)
	pu.type = type_index
	get_tree().current_scene.add_child(pu)

func _on_game_over(_score: int) -> void:
	stop_spawning()
