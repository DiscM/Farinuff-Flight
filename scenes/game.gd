extends Node2D
## Main game scene — contains the player, spawners, HUD, camera, and background.

const GAME_OVER_SCENE := preload("res://ui/game_over.tscn")
const LEVEL_UP_POPUP_SCENE := preload("res://ui/level_up_popup.tscn")

@onready var player: Area2D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var camera: Camera2D = $Camera2D
@onready var enemy_spawner: Node = $EnemySpawner
@onready var powerup_spawner: Node = $PowerUpSpawner

var game_over_shown: bool = false
var level_up_active: bool = false

# Screen shake state
var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0

func _ready() -> void:
	GameManager.start_game()
	hud.update_all()

	enemy_spawner.start_spawning()
	powerup_spawner.start_spawning()

	SignalBus.game_over.connect(_on_game_over)
	SignalBus.screen_shake.connect(_on_screen_shake)
	SignalBus.level_up.connect(_on_level_up)

	# Position player at bottom center
	var viewport_size := get_viewport().get_visible_rect().size
	player.position = Vector2(viewport_size.x / 2.0, viewport_size.y - 80.0)

func _process(delta: float) -> void:
	# Camera shake
	if shake_timer > 0:
		shake_timer -= delta
		var offset := Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		camera.offset = offset
		shake_intensity = lerpf(shake_intensity, 0.0, delta * 5.0)
	else:
		camera.offset = Vector2.ZERO

func _on_screen_shake(intensity: float, duration: float) -> void:
	shake_intensity = intensity
	shake_duration = duration
	shake_timer = duration

func _on_game_over(final_score: int) -> void:
	if game_over_shown:
		return
	game_over_shown = true

	# Brief pause
	await get_tree().create_timer(0.8).timeout

	# Use a CanvasLayer so the Control renders in screen space, not world space
	var overlay := CanvasLayer.new()
	add_child(overlay)
	var game_over_screen := GAME_OVER_SCENE.instantiate()
	overlay.add_child(game_over_screen)
	game_over_screen.show_score(final_score)

func _on_level_up(_new_level: int) -> void:
	if level_up_active:
		return  # Prevent stacking popups
	level_up_active = true

	# Pause the game immediately
	get_tree().paused = true

	# Show the popup on a CanvasLayer that processes while paused
	var overlay := CanvasLayer.new()
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)
	var popup := LEVEL_UP_POPUP_SCENE.instantiate()
	popup.upgrade_chosen.connect(_on_level_up_closed)
	overlay.add_child(popup)

func _on_level_up_closed() -> void:
	level_up_active = false
