extends Control
## Main Menu — title screen with Play button.

func _ready() -> void:
	$VBoxContainer/PlayButton.pressed.connect(_on_play_pressed)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")
