extends Node
class_name CombatScreenOverlays2D
## Reusable screen-space CRT and distortion passes for 2D and native 3D play.

@onready var crt_layer: CanvasLayer = $CRTScanlines
@onready var distortion_layer: CanvasLayer = $ScreenDistortion


func _ready() -> void:
	SaveManager.settings_changed.connect(_apply_visual_settings)
	_apply_visual_settings()


func _apply_visual_settings() -> void:
	crt_layer.visible = bool(SaveManager.get_setting("crt_effect", true))
	distortion_layer.visible = bool(SaveManager.get_setting("screen_distortion", true))
