extends Node
class_name CombatScreenOverlays2D
## Reusable screen-space CRT and distortion passes for 2D and native 3D play.

@onready var crt_layer: CanvasLayer = $CRTScanlines
@onready var distortion_layer: CanvasLayer = $ScreenDistortion


func _ready() -> void:
	preload("res://effects/rendering/frontier_palette.gd").apply_crt($CRTScanlines/FullscreenPass.material)
	$CRTScanlines/FullscreenPass.material.set_shader_parameter(&"barrel_distortion", 0.012)
	$ScreenDistortion/FullscreenPass.material.set_shader_parameter(&"barrel_distortion", 0.012)
	SaveManager.settings_changed.connect(_apply_visual_settings)
	_apply_visual_settings()


func _apply_visual_settings() -> void:
	var crt_enabled := bool(SaveManager.get_setting("crt_effect", true))
	var distortion_enabled := bool(SaveManager.get_setting("screen_distortion", true))
	crt_layer.visible = crt_enabled
	# CRT already supports barrel distortion. Compose both in one screen read;
	# retain the standalone pass for players who enable distortion without CRT.
	$CRTScanlines/FullscreenPass.material.set_shader_parameter(&"apply_distortion", distortion_enabled)
	distortion_layer.visible = distortion_enabled and not crt_enabled
