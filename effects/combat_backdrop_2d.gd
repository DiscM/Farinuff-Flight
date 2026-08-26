extends CanvasLayer
class_name CombatBackdrop2D
## Native-resolution retained 2D presentation behind the Combat Plane.

const GalaxyStyle := preload("res://effects/rendering/galaxy_visual_style.gd")

@onready var background: ColorRect = $Background
@onready var celestial: Node2D = $Celestial


func _ready() -> void:
	_configure_background_shader()
	get_viewport().size_changed.connect(_position_celestial)
	_position_celestial()


func _configure_background_shader() -> void:
	var shader_material := background.material as ShaderMaterial
	if shader_material == null:
		return
	GalaxyStyle.apply_to(shader_material)


func _position_celestial() -> void:
	var viewport_rect := get_viewport().get_visible_rect()
	celestial.position = viewport_rect.position + viewport_rect.size * Vector2(0.82, 0.18)
