extends CanvasLayer
class_name CombatBackdrop2D
## Native-resolution retained 2D presentation behind the Combat Plane.

const GalaxyStyle := preload("res://effects/rendering/galaxy_visual_style.gd")

@onready var background: ColorRect = $Background
@onready var celestial: Node2D = $Celestial
var _void_depth := 0.0
var _target_depth := 0.0
var _previous_viewport_rect := Rect2()


func _ready() -> void:
	_configure_background_shader()
	get_viewport().size_changed.connect(_position_celestial)
	_position_celestial()
	SignalBus.wave_started.connect(_on_wave_started)


func _configure_background_shader() -> void:
	var shader_material := background.material.duplicate() as ShaderMaterial
	if shader_material == null:
		return
	background.material = shader_material
	GalaxyStyle.apply_to(shader_material)


func _on_wave_started(wave: int) -> void:
	_target_depth = clampf(float(wave - 1) / 24.0, 0.0, 1.0)


func _process(delta: float) -> void:
	if is_equal_approx(_void_depth, _target_depth):
		return
	_void_depth = move_toward(_void_depth, _target_depth, delta / 8.0)
	var material := background.material as ShaderMaterial
	material.set_shader_parameter(&"nebula_violet", Color("48365b").lerp(Color("643755"), _void_depth))
	material.set_shader_parameter(&"nebula_pink", Color("745074").lerp(Color("93617c"), _void_depth))


func _position_celestial() -> void:
	var viewport_rect := get_viewport().get_visible_rect()
	var screen_fraction := Vector2(0.82, 0.18)
	if _previous_viewport_rect.has_area():
		# Resizing preserves travel progress instead of resetting the starting anchor.
		screen_fraction = (celestial.position - _previous_viewport_rect.position) / _previous_viewport_rect.size
	celestial.position = viewport_rect.position + viewport_rect.size * screen_fraction
	_previous_viewport_rect = viewport_rect
