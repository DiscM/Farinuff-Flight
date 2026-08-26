extends RefCounted
class_name GalaxyVisualStyle
## Owns the renderer-wide selection of the retained galaxy backdrop shader.

const VisualStyle := preload("res://effects/rendering/visual_style_settings.gd")
const PIXEL_BACKGROUND_SHADER: Shader = preload("res://effects/shaders/galactic_starfield.gdshader")
const VOXEL_BACKGROUND_SHADER: Shader = preload("res://effects/shaders/voxel_galactic_starfield.gdshader")


static func apply_to(shader_material: ShaderMaterial) -> void:
	shader_material.shader = (
		VOXEL_BACKGROUND_SHADER
		if VisualStyle.voxel_style_enabled()
		else PIXEL_BACKGROUND_SHADER
	)
