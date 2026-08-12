extends RefCounted
class_name ShipRenderMaterialLibrary3D
## Builds and caches the shared materials, outlines, and engine-trail geometry
## used by ship proxies. The cache belongs to one live render layer.

const Catalog := preload("res://effects/rendering/ship_render_catalog_3d.gd")
const VisualProxy := preload(
	"res://effects/rendering/ship_visual_proxy_3d.gd"
)

const PIXEL_SHIP_SHADER: Shader = preload("res://effects/shaders/models/pixel_toon_3d.gdshader")
const VOXEL_SHIP_SHADER: Shader = preload("res://effects/shaders/models/voxel_toon_3d.gdshader")
const CORRUPTED_ENEMY_SHIP_SHADER: Shader = preload("res://effects/shaders/models/corrupted_void_enemy_3d.gdshader")
const CORRUPTED_ENEMY_GEN2_SHADER: Shader = preload("res://effects/shaders/models/corrupted_void_enemy_gen2_3d.gdshader")
const CORRUPTED_ENEMY_GEN3_SHADER: Shader = preload("res://effects/shaders/models/corrupted_void_enemy_gen3_3d.gdshader")
const CORRUPTED_ENEMY_GEN4_SHADER: Shader = preload("res://effects/shaders/models/corrupted_void_enemy_gen4_3d.gdshader")
const CORRUPTED_ENEMY_RADIAL_SHADER: Shader = preload("res://effects/shaders/models/corrupted_void_enemy_radial_3d.gdshader")
const OUTLINE_SHADER: Shader = preload("res://effects/shaders/models/pixel_outline_3d.gdshader")
const CORRUPTED_ENEMY_OUTLINE_SHADER: Shader = preload("res://effects/shaders/models/corrupted_void_enemy_outline_3d.gdshader")
const ENGINE_TRAIL_SHADER: Shader = preload("res://effects/shaders/models/pixel_trail_3d.gdshader")

const CORRUPTED_ENEMY_ARCHETYPES := [
	&"basic",
	&"fast",
	&"bomber",
	&"tank",
	&"sniper",
]

const CORRUPTED_VOID_PROFILES := [
	{
		"evolution_level": 0.0,
		"circuit_amount": 0.05,
		"heat_amount": 0.0,
		"apex_amount": 0.0,
		"emission_strength": 0.74,
		"fracture_density": 0.10,
		"node_amount": 0.0,
		"reactor_focus": 0.12,
		"aura_strength": 0.08,
		"ring_strength": 0.0,
		"ring_count": 4.0,
	},
	{
		"evolution_level": 0.333333,
		"circuit_amount": 0.58,
		"heat_amount": 0.06,
		"apex_amount": 0.0,
		"emission_strength": 0.92,
		"fracture_density": 0.46,
		"node_amount": 0.38,
		"reactor_focus": 0.30,
		"aura_strength": 0.14,
		"ring_strength": 0.14,
		"ring_count": 4.0,
	},
	{
		"evolution_level": 0.666667,
		"circuit_amount": 0.76,
		"heat_amount": 0.72,
		"apex_amount": 0.18,
		"emission_strength": 1.18,
		"fracture_density": 0.82,
		"node_amount": 0.70,
		"reactor_focus": 0.62,
		"aura_strength": 0.22,
		"ring_strength": 0.46,
		"ring_count": 5.0,
	},
	{
		"evolution_level": 1.0,
		"circuit_amount": 0.88,
		"heat_amount": 0.38,
		"apex_amount": 1.0,
		"emission_strength": 1.45,
		"fracture_density": 0.96,
		"node_amount": 0.88,
		"reactor_focus": 0.95,
		"aura_strength": 0.65,
		"ring_strength": 0.98,
		"ring_count": 7.0,
	},
]

# Kept as a compatibility alias for diagnostics and older callers. Materials
# are selected per library instance through _ship_shader().
const SHIP_SHADER: Shader = PIXEL_SHIP_SHADER

var _surface_material_cache: Dictionary = {}
var _outline_material_cache: Dictionary = {}
var _trail_mesh_cache: Dictionary = {}
var _trail_material_cache: Dictionary = {}
var _evolution_aura_material_cache: Dictionary = {}
var _evolution_aura_mesh: QuadMesh
var _voxel_style_enabled := false


func _init() -> void:
	_voxel_style_enabled = Catalog.voxel_style_enabled()


func is_voxel_style_enabled() -> bool:
	return _voxel_style_enabled


func configure_proxy(proxy: VisualProxy) -> void:
	if proxy.player_assembly != null:
		proxy.player_assembly.build()
		proxy.meshes.assign(proxy.player_assembly.hull_meshes)
		proxy.outlines.assign(proxy.player_assembly.hull_outlines)
	else:
		proxy.collect_meshes(proxy.model)
		for mesh_instance in proxy.meshes:
			var materials: Array[Material] = []
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				materials.append(mesh_instance.get_active_material(surface_index))
			proxy.source_materials[mesh_instance.get_instance_id()] = materials
		apply_proxy_materials(proxy)
	ensure_engine_trail(proxy)


func apply_proxy_materials(proxy: VisualProxy) -> void:
	for outline in proxy.outlines:
		if is_instance_valid(outline):
			outline.queue_free()
	proxy.outlines.clear()

	for mesh_instance in proxy.meshes:
		if not is_instance_valid(mesh_instance) or mesh_instance.mesh == null:
			continue
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var original_materials: Array = proxy.source_materials.get(
			mesh_instance.get_instance_id(),
			[]
		)
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var source_material: Material = (
				original_materials[surface_index]
					if surface_index < original_materials.size()
					else null
			)
			var material := _get_surface_material(
				proxy.archetype,
				proxy.generation,
				surface_index,
				source_material
			)
			mesh_instance.set_surface_override_material(surface_index, material)

		# The current on-screen cap keeps the exact mockup outline affordable.
		# It is one shared material per class/generation, never per enemy.
		var outline := MeshInstance3D.new()
		outline.name = "%s_NeonOutline" % mesh_instance.name
		outline.mesh = mesh_instance.mesh
		outline.transform = mesh_instance.transform
		outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		outline.material_override = _get_outline_material(
			proxy.archetype,
			proxy.generation
		)
		mesh_instance.get_parent().add_child(outline)
		proxy.outlines.append(outline)

	ensure_evolution_aura(proxy)
	ensure_engine_trail(proxy)


func ensure_engine_trail(proxy: VisualProxy) -> void:
	if not Catalog.ENGINE_LAYOUTS.has(proxy.archetype):
		return
	if proxy.engine_trail == null:
		proxy.engine_trail = MeshInstance3D.new()
		proxy.engine_trail.name = "EngineTrails"
		proxy.engine_trail.mesh = _get_engine_trail_mesh(proxy.archetype)
		proxy.engine_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		proxy.root.add_child(proxy.engine_trail)
	proxy.engine_trail.material_override = _get_engine_trail_material(
		proxy.archetype,
		proxy.generation
	)


func _get_surface_material(
	archetype: StringName,
	generation: int,
	surface_index: int,
	source_material: Material
) -> ShaderMaterial:
	var cache_key := "%s:%d:%d" % [archetype, generation, surface_index]
	if _surface_material_cache.has(cache_key):
		return _surface_material_cache[cache_key] as ShaderMaterial

	var base_color := Color(0.18, 0.24, 0.34)
	var metallic := 0.55
	var roughness := 0.30
	var source_emission := 0.0
	var emissive_surface := 0.0
	var glow_color := Color(0.0, 0.0, 0.0, 0.0)
	if source_material is BaseMaterial3D:
		var base_material := source_material as BaseMaterial3D
		base_color = base_material.albedo_color
		metallic = base_material.metallic
		roughness = base_material.roughness
		if base_material.emission_enabled:
			source_emission = (
				0.75
				if Catalog.STATIC_STYLES.has(archetype)
				else 1.45
			)
			emissive_surface = 1.0
			glow_color = Color(base_material.emission, 1.0)

	var style := _get_style(archetype, generation)
	var material := ShaderMaterial.new()
	material.shader = _ship_shader(archetype, generation)
	material.set_shader_parameter("base_color", base_color)
	material.set_shader_parameter("energy_color", style["energy_color"])
	material.set_shader_parameter("accent_color", style["accent_color"])
	material.set_shader_parameter("metallic", metallic)
	material.set_shader_parameter("roughness", roughness)
	material.set_shader_parameter("emissive_surface", emissive_surface)
	material.set_shader_parameter("glow_color", glow_color)
	material.set_shader_parameter("evolution_level", style["evolution_level"])
	material.set_shader_parameter("circuit_amount", style["circuit_amount"])
	material.set_shader_parameter("heat_amount", style["heat_amount"])
	material.set_shader_parameter("apex_amount", style["apex_amount"])
	if CORRUPTED_ENEMY_ARCHETYPES.has(archetype) and not _voxel_style_enabled:
		material.set_shader_parameter("fracture_density", style["fracture_density"])
		material.set_shader_parameter("node_amount", style["node_amount"])
		material.set_shader_parameter("reactor_focus", style["reactor_focus"])
	material.set_shader_parameter(
		"pattern_scale",
		float(style.get("pattern_scale", 3.6))
	)
	material.set_shader_parameter(
		"emission_strength",
		float(style["emission_strength"]) + source_emission
	)
	material.set_shader_parameter(
		"animation_speed",
		0.0 if archetype == &"drone_escort" else 1.0
	)
	material.set_shader_parameter("phase_offset", 0.0)
	if _voxel_style_enabled:
		material.set_shader_parameter("voxel_normal_steps", 4.0)
		material.set_shader_parameter("voxel_palette_variation", 0.08)
		material.set_shader_parameter("voxel_edge_strength", 0.06)
	_surface_material_cache[cache_key] = material
	return material


func _ship_shader(archetype: StringName, generation: int) -> Shader:
	if _voxel_style_enabled:
		return VOXEL_SHIP_SHADER
	if CORRUPTED_ENEMY_ARCHETYPES.has(archetype):
		match clampi(generation, 1, 4):
			2:
				return CORRUPTED_ENEMY_GEN2_SHADER
			3:
				return CORRUPTED_ENEMY_GEN3_SHADER
			4:
				return CORRUPTED_ENEMY_GEN4_SHADER
			_:
				return CORRUPTED_ENEMY_SHIP_SHADER
	return PIXEL_SHIP_SHADER


func _get_outline_material(
	archetype: StringName,
	generation: int
) -> ShaderMaterial:
	var cache_key := "%s:%d" % [archetype, generation]
	if _outline_material_cache.has(cache_key):
		return _outline_material_cache[cache_key] as ShaderMaterial
	var material := ShaderMaterial.new()
	var corrupted_style := CORRUPTED_ENEMY_ARCHETYPES.has(archetype)
	material.shader = (
		CORRUPTED_ENEMY_OUTLINE_SHADER
		if corrupted_style and not _voxel_style_enabled
		else OUTLINE_SHADER
	)
	# The pixel style shares one void rim across every ship: the dark limb of
	# the planet shaders, exactly one low-res buffer pixel thick.
	material.set_shader_parameter(
		"outline_width",
		float(Catalog.PIXELATION) / Catalog.PIXELS_PER_MODEL_UNIT
	)
	if corrupted_style and not _voxel_style_enabled:
		var style := _get_style(archetype, generation)
		material.set_shader_parameter("energy_color", style["energy_color"])
		material.set_shader_parameter("accent_color", style["accent_color"])
		material.set_shader_parameter("violet_fringe", Color(0.90, 0.04, 1.0, 1.0))
		material.set_shader_parameter(
			"outline_energy",
			1.25 + float(style["evolution_level"]) * 0.55
		)
		material.set_shader_parameter("fringe_strength", 0.72)
	_outline_material_cache[cache_key] = material
	return material


func ensure_evolution_aura(proxy: VisualProxy) -> void:
	var corrupted_style := (
		CORRUPTED_ENEMY_ARCHETYPES.has(proxy.archetype)
		and not _voxel_style_enabled
	)
	if not corrupted_style:
		if is_instance_valid(proxy.evolution_aura):
			proxy.evolution_aura.visible = false
		return

	if proxy.evolution_aura == null:
		var aura := MeshInstance3D.new()
		aura.name = "EvolutionRadialAura"
		aura.mesh = _get_evolution_aura_mesh()
		aura.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		# Move the back-plate slightly away from the fixed camera so the opaque
		# hull depth-test clips the aura cleanly inside the silhouette.
		aura.position = Vector3(0.0, -0.14, -0.10)
		aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		proxy.root.add_child(aura)
		proxy.root.move_child(aura, 0)
		proxy.evolution_aura = aura

	proxy.evolution_aura.material_override = _get_evolution_aura_material(
		proxy.archetype,
		proxy.generation
	)
	proxy.evolution_aura.visible = true


func _get_evolution_aura_mesh() -> QuadMesh:
	if _evolution_aura_mesh != null:
		return _evolution_aura_mesh
	_evolution_aura_mesh = QuadMesh.new()
	_evolution_aura_mesh.size = Vector2(6.0, 6.0)
	return _evolution_aura_mesh


func _get_evolution_aura_material(
	archetype: StringName,
	generation: int
) -> ShaderMaterial:
	var cache_key := "%s:%d" % [archetype, generation]
	if _evolution_aura_material_cache.has(cache_key):
		return _evolution_aura_material_cache[cache_key] as ShaderMaterial
	var style := _get_style(archetype, generation)
	var material := ShaderMaterial.new()
	material.shader = CORRUPTED_ENEMY_RADIAL_SHADER
	material.set_shader_parameter("energy_color", style["energy_color"])
	material.set_shader_parameter("accent_color", style["accent_color"])
	material.set_shader_parameter("violet_fringe", Color(0.90, 0.04, 1.0, 1.0))
	material.set_shader_parameter("evolution_level", style["evolution_level"])
	material.set_shader_parameter("aura_strength", style["aura_strength"])
	material.set_shader_parameter("ring_strength", style["ring_strength"])
	material.set_shader_parameter("ring_count", style["ring_count"])
	material.set_shader_parameter("emission_strength", style["emission_strength"])
	material.set_shader_parameter("phase_offset", 0.0)
	material.set_shader_parameter("animation_speed", 1.0)
	_evolution_aura_material_cache[cache_key] = material
	return material


func _get_engine_trail_mesh(archetype: StringName) -> ArrayMesh:
	if _trail_mesh_cache.has(archetype):
		return _trail_mesh_cache[archetype] as ArrayMesh
	var layout: Dictionary = Catalog.ENGINE_LAYOUTS[archetype]
	var length := float(layout["length"])
	var half_width := float(layout.get("half_width", 0.075))
	var trail_y := float(layout.get("y", -0.035))
	var engine_points: Array = layout.get("points", [])
	if engine_points.is_empty():
		var engine_x := float(layout["x"])
		var nozzle_z := float(layout["z"])
		engine_points = [
			Vector2(-engine_x, nozzle_z),
			Vector2(engine_x, nozzle_z),
		]
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for point_variant in engine_points:
		var engine_point: Vector2 = point_variant
		var center_x := engine_point.x
		var nozzle_z := engine_point.y
		var base_index := vertices.size()
		vertices.append(Vector3(center_x - half_width, trail_y, nozzle_z))
		vertices.append(Vector3(center_x + half_width, trail_y, nozzle_z))
		vertices.append(Vector3(
			center_x + half_width * 0.24,
			trail_y,
			nozzle_z + length
		))
		vertices.append(Vector3(
			center_x - half_width * 0.24,
			trail_y,
			nozzle_z + length
		))
		uvs.append(Vector2(0.0, 0.0))
		uvs.append(Vector2(1.0, 0.0))
		uvs.append(Vector2(1.0, 1.0))
		uvs.append(Vector2(0.0, 1.0))
		indices.append_array(PackedInt32Array([
			base_index,
			base_index + 1,
			base_index + 2,
			base_index,
			base_index + 2,
			base_index + 3,
		]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_trail_mesh_cache[archetype] = mesh
	return mesh


func _get_engine_trail_material(
	archetype: StringName,
	generation: int
) -> ShaderMaterial:
	var cache_key := "%s:%d" % [archetype, generation]
	if _trail_material_cache.has(cache_key):
		return _trail_material_cache[cache_key] as ShaderMaterial
	var style := _get_style(archetype, generation)
	var material := ShaderMaterial.new()
	material.shader = ENGINE_TRAIL_SHADER
	material.set_shader_parameter("trail_color", style["energy_color"])
	material.set_shader_parameter(
		"trail_energy",
		2.25 + float(style["evolution_level"]) * 0.75
	)
	_trail_material_cache[cache_key] = material
	return material


func _get_style(archetype: StringName, generation: int) -> Dictionary:
	if archetype == &"player":
		return {
			"energy_color": Catalog.CLASS_ENERGY[&"player"],
			"accent_color": Catalog.CLASS_ACCENT[&"player"],
			"evolution_level": 0.25,
			"circuit_amount": 0.34,
			"heat_amount": 0.0,
			"apex_amount": 0.0,
			"emission_strength": 0.74,
		}
	if Catalog.STATIC_STYLES.has(archetype):
		var static_style: Dictionary = Catalog.STATIC_STYLES[archetype]
		return {
			"energy_color": Catalog.CLASS_ENERGY[archetype],
			"accent_color": Catalog.CLASS_ACCENT[archetype],
			"evolution_level": static_style["evolution_level"],
			"circuit_amount": static_style["circuit_amount"],
			"heat_amount": static_style["heat_amount"],
			"apex_amount": static_style["apex_amount"],
			"emission_strength": static_style["emission_strength"],
			"pattern_scale": static_style["pattern_scale"],
		}

	var clamped_generation := clampi(generation, 1, 4)
	var profile: Dictionary = CORRUPTED_VOID_PROFILES[clamped_generation - 1]
	return {
		# Keep each regular archetype's current palette intact. Violet is the
		# corruption treatment, not a replacement for class identity.
		"energy_color": Catalog.CLASS_ENERGY[archetype],
		"accent_color": Catalog.CLASS_ACCENT[archetype],
		"evolution_level": profile["evolution_level"],
		"circuit_amount": profile["circuit_amount"],
		"heat_amount": profile["heat_amount"],
		"apex_amount": profile["apex_amount"],
		"emission_strength": profile["emission_strength"],
		"fracture_density": profile["fracture_density"],
		"node_amount": profile["node_amount"],
		"reactor_focus": profile["reactor_focus"],
		"aura_strength": profile["aura_strength"],
		"ring_strength": profile["ring_strength"],
		"ring_count": profile["ring_count"],
	}
