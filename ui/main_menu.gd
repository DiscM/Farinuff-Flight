extends Control
## Main Menu — title screen with Play button.

const SETTINGS_MENU_SCENE := preload("res://ui/settings_menu.tscn")
var _settings_menu: Node = null

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$VBoxContainer/PlayButton.pressed.connect(_on_play_pressed)
	$VBoxContainer/SettingsButton.pressed.connect(_on_settings_pressed)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_settings_pressed() -> void:
	if is_instance_valid(_settings_menu):
		return
	_settings_menu = SETTINGS_MENU_SCENE.instantiate()
	_settings_menu.connect("closed", func(): _settings_menu = null)
	add_child(_settings_menu)
