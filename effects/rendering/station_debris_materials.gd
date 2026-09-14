extends RefCounted
## The same PixelPlanets surface as the fleet, with quiet scenery exposure.

const SurfaceLibrary := preload("res://effects/rendering/enemy_surface_materials.gd")


static func apply_to(model: Node3D, brightness: float = 0.68) -> void:
	# Compensate for the authored instance scale so large station sections and
	# small fragments keep a similar visible pixel size in the combat camera.
	var pixel_density := 8.0 * model.scale.x
	SurfaceLibrary.apply_to(model, SurfaceLibrary.Style.PIXEL_PLANET, pixel_density)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		# Per-instance exposure never mutates the shared fleet material cache.
		# Authored station inlays are painted, not emissive reactor elements.
		mesh.set_instance_shader_parameter(&"instance_modulate", Color(brightness, brightness, brightness, 1.0))
