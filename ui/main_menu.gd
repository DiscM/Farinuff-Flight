extends Node
## Compatibility entry for old bookmarks and saved launch configurations.
## The flyable home port owns all production menu and service navigation.

const HOME_BASE_PATH := "res://scenes/home_base.tscn"

func _ready() -> void:
	_enter_home_port.call_deferred()

func _enter_home_port() -> void:
	get_tree().paused = false
	var result := get_tree().change_scene_to_file(HOME_BASE_PATH)
	if result != OK:
		push_error("Unable to enter Wayfarer Home Port: %s" % error_string(result))
