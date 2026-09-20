extends RefCounted
## Immutable authored-material conversions, shared across enemy instances.
## Scene selection controls which hulls receive the PixelPlanets treatment.

enum Style { AUTHORED_ALLOY, PIXEL_PLANET }

const ALLOY_SHADER := preload("res://effects/shaders/models/imported_enemy_surface_3d.gdshader")
const PIXEL_SHADER := preload("res://effects/shaders/models/pixel_planet_enemy_3d.gdshader")
static var _materials_by_shader: Dictionary = {}
static var _authored_sources: Dictionary = {}


static func apply_to(visuals: Node3D, style: Style, pixel_density: float = 8.0) -> void:
	var shader: Shader = PIXEL_SHADER if style == Style.PIXEL_PLANET else ALLOY_SHADER
	var meshes := visuals.find_children("*", "MeshInstance3D", true, false)
	if visuals is MeshInstance3D:
		meshes.append(visuals)
	for node in meshes:
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var source: Material = mesh.get_active_material(surface)
			source = _authored_sources.get(source, source)
			mesh.set_surface_override_material(surface, _convert(source, shader))
		if style == Style.PIXEL_PLANET:
			_set_hull_coordinates(mesh, visuals, pixel_density)


static func _convert(source: Material, shader: Shader) -> ShaderMaterial:
	if not _materials_by_shader.has(shader):
		_materials_by_shader[shader] = {}
	var materials: Dictionary = _materials_by_shader[shader]
	if materials.has(source):
		return materials[source] as ShaderMaterial
	var material := ShaderMaterial.new()
	material.shader = shader
	var base_color := Color(0.18, 0.24, 0.34, 1.0)
	var emission_color := Color(0.0, 0.0, 0.0, 0.0)
	var emission_strength := 0.0
	var metallic := 0.55
	var roughness := 0.30
	if source is BaseMaterial3D:
		var authored := source as BaseMaterial3D
		base_color = authored.albedo_color
		metallic = authored.metallic
		roughness = authored.roughness
		# GLB color factors alone discard painted panels, vents and hazard marks.
		# Preserve the UV atlas through either art style; textureless legacy hulls
		# keep exactly the same color-only conversion.
		material.set_shader_parameter(&"has_albedo_texture", authored.albedo_texture != null)
		material.set_shader_parameter(&"albedo_texture", authored.albedo_texture)
		material.set_shader_parameter(&"uv_scale", Vector2(authored.uv1_scale.x, authored.uv1_scale.y))
		material.set_shader_parameter(&"uv_offset", Vector2(authored.uv1_offset.x, authored.uv1_offset.y))
		if authored.emission_enabled:
			emission_color = Color(authored.emission.r, authored.emission.g, authored.emission.b, 1.0)
			emission_strength = authored.emission_energy_multiplier
			material.set_shader_parameter(&"has_emission_texture", authored.emission_texture != null)
			material.set_shader_parameter(&"emission_texture", authored.emission_texture)
	material.set_shader_parameter(&"base_color", base_color)
	material.set_shader_parameter(&"emission_color", emission_color)
	material.set_shader_parameter(&"emission_strength", emission_strength)
	if shader == ALLOY_SHADER:
		material.set_shader_parameter(&"metallic", metallic)
		material.set_shader_parameter(&"roughness", roughness)
	materials[source] = material
	_authored_sources[material] = source
	return material


static func _set_hull_coordinates(mesh: MeshInstance3D, visuals: Node3D, pixel_density: float) -> void:
	# GLB material groups can have distinct transforms. Resolve them once into
	# the Visuals frame so the grid neither swims with movement nor restarts at
	# every material boundary. Actor yaw and rigid bone animation remain free.
	var frame := visuals.global_transform.affine_inverse() * mesh.global_transform
	mesh.set_instance_shader_parameter(&"instance_hull_row_x", Vector4(frame.basis.x.x, frame.basis.y.x, frame.basis.z.x, frame.origin.x))
	mesh.set_instance_shader_parameter(&"instance_hull_row_y", Vector4(frame.basis.x.y, frame.basis.y.y, frame.basis.z.y, frame.origin.y))
	mesh.set_instance_shader_parameter(&"instance_hull_row_z", Vector4(frame.basis.x.z, frame.basis.y.z, frame.basis.z.z, frame.origin.z))
	mesh.set_instance_shader_parameter(&"instance_pixel_density", pixel_density)
