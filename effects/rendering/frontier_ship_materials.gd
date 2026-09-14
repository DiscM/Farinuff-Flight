extends RefCounted
class_name FrontierShipMaterials
## One material bridge for native hulls, modules, escorts, and menu previews.

const SHADER := preload("res://effects/shaders/models/frontier_ship_3d.gdshader")
static var _materials: Dictionary[Material, ShaderMaterial] = {}


static func surface(source: Material) -> ShaderMaterial:
	if source is ShaderMaterial and source.shader == SHADER:
		return source
	if source != null and _materials.has(source):
		return _materials[source]
	var material := ShaderMaterial.new()
	material.shader = SHADER
	if source is BaseMaterial3D:
		material.set_shader_parameter(&"base_color", source.albedo_color)
		material.set_shader_parameter(&"emissive_surface", 1.0 if source.emission_enabled else 0.0)
		material.set_shader_parameter(&"metallic", minf(source.metallic, 0.55))
		material.set_shader_parameter(&"roughness", maxf(source.roughness, 0.38))
	if source != null:
		_materials[source] = material
	return material


static func apply(root: Node3D) -> void:
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for node in meshes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for index in mesh_instance.mesh.get_surface_count():
			mesh_instance.set_surface_override_material(index, surface(mesh_instance.get_active_material(index)))
