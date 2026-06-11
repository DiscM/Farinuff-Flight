extends Control
## Game Over screen — shows final score with retry and menu buttons.

@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var high_score_label: Label = $VBoxContainer/HighScoreLabel
@onready var level_label: Label = $VBoxContainer/LevelLabel

## Connects the retry and menu buttons to their respective handlers.
func _ready() -> void:
	$VBoxContainer/RetryButton.pressed.connect(_on_retry_pressed)
	$VBoxContainer/MenuButton.pressed.connect(_on_menu_pressed)

## Displays the final score, the all-time high score, and the wave
## the player reached on the game over screen.
func show_score(final_score: int) -> void:
	score_label.text = "SCORE: " + str(final_score)
	high_score_label.text = "HIGH SCORE: " + str(GameManager.high_score)
	level_label.text = "WAVE REACHED: " + str(GameManager.current_wave)

## Unpauses the game and reloads the game scene for a fresh run.
func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/game.tscn")

## Unpauses the game and returns to the main menu.
func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
