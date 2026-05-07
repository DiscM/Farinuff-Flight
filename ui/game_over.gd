extends Control
## Game Over screen — shows final score with retry and menu buttons.

@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var high_score_label: Label = $VBoxContainer/HighScoreLabel
@onready var level_label: Label = $VBoxContainer/LevelLabel

func _ready() -> void:
	$VBoxContainer/RetryButton.pressed.connect(_on_retry_pressed)
	$VBoxContainer/MenuButton.pressed.connect(_on_menu_pressed)

func show_score(final_score: int) -> void:
	score_label.text = "SCORE: " + str(final_score)
	high_score_label.text = "HIGH SCORE: " + str(GameManager.high_score)
	level_label.text = "WAVE REACHED: " + str(GameManager.current_wave)

func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
