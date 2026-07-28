extends Node
## Periodically spawns a random power-up from the top of the screen.

const POWER_UP_SCENE: PackedScene = preload("res://entities/powerups/power_up.tscn")

@onready var spawn_timer: Timer = $SpawnTimer

var viewport_width: float = 720.0
var margin: float = 60.0
var min_interval: float = 8.0
var max_interval: float = 15.0

## Reads the viewport width and configures the spawn timer as a one-shot
## timer that triggers power-up spawns at randomized intervals.
func _ready() -> void:
	viewport_width = get_viewport().get_visible_rect().size.x
	spawn_timer.one_shot = true
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	SignalBus.game_over.connect(_on_game_over)

## Starts power-up spawning by scheduling the first timer.
func start_spawning() -> void:
	_restart_timer()

## Stops power-up spawning by halting the timer.
func stop_spawning() -> void:
	spawn_timer.stop()

## Restarts the spawn timer with a random wait time between min_interval
## and max_interval seconds.
func _restart_timer() -> void:
	spawn_timer.wait_time = randf_range(min_interval, max_interval)
	spawn_timer.start()

## Called on each timer tick. Spawns a power-up if the game is active,
## then restarts the timer for the next spawn.
func _on_spawn_timer_timeout() -> void:
	if not GameManager.is_game_active:
		return
	_spawn_powerup()
	_restart_timer()

## Acquires a pooled power-up at a random X position along the top of the
## screen with a random PowerUp.Type (excluding Nuke during boss fights).
func _spawn_powerup() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var pu := ObjectPool.acquire(POWER_UP_SCENE, scene_root)
	if pu == null or not pu.has_method("pool_activate"):
		return
	# Nukes are disabled during boss fights so they cannot erase the boss.
	var max_type_index := PowerUp.Type.MAGNET if GameManager.boss_active else PowerUp.Type.NUKE
	var type_index := randi_range(PowerUp.Type.SCALE_UP, max_type_index)
	pu.pool_activate(
		Vector2(randf_range(margin, viewport_width - margin), -20.0),
		type_index
	)

## Called on game over. Stops all power-up spawning.
func _on_game_over(_score: int) -> void:
	stop_spawning()
