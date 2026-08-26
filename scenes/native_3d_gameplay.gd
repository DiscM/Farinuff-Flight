extends Node
class_name Native3DGameplay
## Isolated native 3D world shell. Gameplay actors arrive in later slices.

@onready var hud: CanvasLayer = $HUD

var _previous_hdr_2d: bool = false


func _enter_tree() -> void:
	_previous_hdr_2d = get_viewport().use_hdr_2d
	get_viewport().use_hdr_2d = true


func _ready() -> void:
	add_to_group(&"native_3d_gameplay")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	GameManager.start_game()
	if hud.has_method("update_all"):
		hud.update_all()


func _exit_tree() -> void:
	if get_viewport() != null:
		get_viewport().use_hdr_2d = _previous_hdr_2d
