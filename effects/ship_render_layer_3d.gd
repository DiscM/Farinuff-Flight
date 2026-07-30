extends Node2D
class_name ShipRenderLayer3D
## Shared 2.5D presentation layer.
##
## Area2D actors remain authoritative for movement, collision, weapons, and
## evolution. This node renders one synchronized 3D proxy per supported ship
## into a single transparent viewport composited between the 2D background and
## the existing projectiles/effects.

const SHIP_SHADER: Shader = preload("res://effects/shaders/models/neon_ship_3d.gdshader")
const OUTLINE_SHADER: Shader = preload("res://effects/shaders/models/neon_outline_3d.gdshader")
const ENGINE_TRAIL_SHADER: Shader = preload("res://effects/shaders/models/engine_trail_3d.gdshader")

const MODEL_SCENES := {
	&"player": preload("res://assets/models/mockups/player_ship_mockup.glb"),
	&"basic": preload("res://assets/models/mockups/basic_enemy_mockup.glb"),
	&"fast": preload("res://assets/models/mockups/fast_enemy_mockup.glb"),
	&"bomber": preload("res://assets/models/mockups/bomber_enemy_mockup.glb"),
	&"tank": preload("res://assets/models/mockups/tank_enemy_mockup.glb"),
	&"sniper": preload("res://assets/models/mockups/sniper_enemy_mockup.glb"),
	&"boss_assault": preload("res://assets/models/mockups/boss_assault_mockup.glb"),
	&"boss_bulwark": preload("res://assets/models/mockups/boss_bulwark_mockup.glb"),
	&"boss_tempest": preload("res://assets/models/mockups/boss_tempest_mockup.glb"),
	&"boss_void_harbinger": preload("res://assets/models/mockups/boss_void_harbinger_mockup.glb"),
	&"boss_tempest_core": preload("res://assets/models/mockups/boss_tempest_core_mockup.glb"),
	&"tempest_section": preload("res://assets/models/mockups/tempest_section_mockup.glb"),
	&"drone_escort": preload("res://assets/models/mockups/player_drone_escort.glb"),
}

const MODEL_PATHS := {
	&"player": "res://assets/models/mockups/player_ship_mockup.glb",
	&"basic": "res://assets/models/mockups/basic_enemy_mockup.glb",
	&"fast": "res://assets/models/mockups/fast_enemy_mockup.glb",
	&"bomber": "res://assets/models/mockups/bomber_enemy_mockup.glb",
	&"tank": "res://assets/models/mockups/tank_enemy_mockup.glb",
	&"sniper": "res://assets/models/mockups/sniper_enemy_mockup.glb",
	&"boss_assault": "res://assets/models/mockups/boss_assault_mockup.glb",
	&"boss_bulwark": "res://assets/models/mockups/boss_bulwark_mockup.glb",
	&"boss_tempest": "res://assets/models/mockups/boss_tempest_mockup.glb",
	&"boss_void_harbinger": "res://assets/models/mockups/boss_void_harbinger_mockup.glb",
	&"boss_tempest_core": "res://assets/models/mockups/boss_tempest_core_mockup.glb",
	&"tempest_section": "res://assets/models/mockups/tempest_section_mockup.glb",
	&"drone_escort": "res://assets/models/mockups/player_drone_escort.glb",
}

const CLASS_ENERGY := {
	&"player": Color(0.02, 0.72, 1.0),
	&"basic": Color(1.0, 0.035, 0.12),
	&"fast": Color(1.0, 0.28, 0.025),
	&"bomber": Color(0.38, 1.0, 0.12),
	&"tank": Color(0.65, 0.10, 1.0),
	&"sniper": Color(0.02, 0.72, 1.0),
	&"boss_assault": Color(1.0, 0.08, 0.035),
	&"boss_bulwark": Color(0.72, 0.12, 1.0),
	&"boss_tempest": Color(1.0, 0.025, 0.68),
	&"boss_void_harbinger": Color(1.0, 0.025, 0.58),
	&"boss_tempest_core": Color(0.18, 0.82, 1.0),
	&"tempest_section": Color(0.20, 0.92, 1.0),
	&"drone_escort": Color(0.40, 0.85, 1.0),
}

const CLASS_ACCENT := {
	&"player": Color(0.76, 0.95, 1.0),
	&"basic": Color(1.0, 0.58, 0.68),
	&"fast": Color(1.0, 0.86, 0.28),
	&"bomber": Color(0.78, 1.0, 0.44),
	&"tank": Color(0.92, 0.64, 1.0),
	&"sniper": Color(0.74, 0.98, 1.0),
	&"boss_assault": Color(1.0, 0.62, 0.05),
	&"boss_bulwark": Color(1.0, 0.72, 0.08),
	&"boss_tempest": Color(0.72, 0.92, 1.0),
	&"boss_void_harbinger": Color(1.0, 0.76, 0.12),
	&"boss_tempest_core": Color(1.0, 0.16, 0.72),
	&"tempest_section": Color(0.86, 0.98, 1.0),
	&"drone_escort": Color(0.78, 0.96, 1.0),
}

const STATIC_STYLES := {
	&"boss_assault": {
		"evolution_level": 0.72,
		"circuit_amount": 0.28,
		"heat_amount": 0.48,
		"apex_amount": 0.08,
		"emission_strength": 1.05,
		"pattern_scale": 1.35,
	},
	&"boss_bulwark": {
		"evolution_level": 0.76,
		"circuit_amount": 0.42,
		"heat_amount": 0.14,
		"apex_amount": 0.18,
		"emission_strength": 1.10,
		"pattern_scale": 1.25,
	},
	&"boss_tempest": {
		"evolution_level": 0.88,
		"circuit_amount": 0.52,
		"heat_amount": 0.08,
		"apex_amount": 0.42,
		"emission_strength": 1.15,
		"pattern_scale": 1.40,
	},
	&"boss_void_harbinger": {
		"evolution_level": 1.0,
		"circuit_amount": 0.55,
		"heat_amount": 0.24,
		"apex_amount": 0.65,
		"emission_strength": 1.25,
		"pattern_scale": 1.35,
	},
	&"boss_tempest_core": {
		"evolution_level": 1.0,
		"circuit_amount": 0.60,
		"heat_amount": 0.30,
		"apex_amount": 0.58,
		"emission_strength": 1.35,
		"pattern_scale": 1.20,
	},
	&"tempest_section": {
		"evolution_level": 0.84,
		"circuit_amount": 0.40,
		"heat_amount": 0.08,
		"apex_amount": 0.34,
		"emission_strength": 1.15,
		"pattern_scale": 2.20,
	},
	&"drone_escort": {
		"evolution_level": 0.46,
		"circuit_amount": 0.28,
		"heat_amount": 0.0,
		"apex_amount": 0.0,
		"emission_strength": 0.92,
		"pattern_scale": 4.80,
	},
}

const ENGINE_LAYOUTS := {
	&"player": {"x": 0.27, "z": 1.63, "length": 1.45},
	&"basic": {"x": 0.25, "z": 1.17, "length": 0.95},
	&"fast": {"x": 0.15, "z": 1.59, "length": 1.35},
	&"bomber": {"x": 0.33, "z": 1.48, "length": 1.10},
	&"tank": {"x": 0.50, "z": 1.69, "length": 0.95},
	&"sniper": {"x": 0.23, "z": 1.53, "length": 1.18},
	&"boss_assault": {
		"x": 0.817, "z": 3.705, "length": 1.75,
		"half_width": 0.15, "y": -0.09,
	},
	&"boss_bulwark": {
		"x": 1.147, "z": 3.090, "length": 1.45,
		"half_width": 0.17, "y": -0.20,
	},
	&"boss_tempest": {
		"x": 0.748, "z": 2.618, "length": 1.65,
		"half_width": 0.15, "y": -0.15,
	},
	&"boss_void_harbinger": {
		"x": 0.706, "z": 3.377, "length": 1.85,
		"half_width": 0.16, "y": -0.13,
	},
	&"boss_tempest_core": {
		"x": 1.10, "z": 3.982, "length": 1.70,
		"half_width": 0.18, "y": -0.21,
	},
}

const PIXELS_PER_MODEL_UNIT := 11.0
const CAMERA_HEIGHT := 45.0
const CAMERA_DEPTH := 28.125
const INVINCIBILITY_VISIBLE_ALPHA := 0.5
const RENDER_OVERSCAN_PIXELS := 32


class VisualProxy:
	var source_ref: WeakRef
	var source_id: int
	var root: Node3D
	var model: Node3D
	var meshes: Array[MeshInstance3D] = []
	var outlines: Array[MeshInstance3D] = []
	var source_materials: Dictionary = {}
	var engine_trail: MeshInstance3D
	var source_visual: CanvasItem
	var source_sprite: Sprite2D
	var player_assembly: PlayerShipAssembly3D
	var suppressed_visuals: Array[CanvasItem] = []
	var suppressed_self_modulates: Array[Color] = []
	var archetype: StringName
	var generation: int
	var phase_offset: float


@onready var ship_viewport: SubViewport = $ShipViewport
@onready var visual_world: Node3D = $ShipViewport/VisualWorld
@onready var camera_3d: Camera3D = $ShipViewport/VisualWorld/Camera3D
@onready var proxy_root: Node3D = $ShipViewport/VisualWorld/Proxies
@onready var viewport_display: TextureRect = $ViewportDisplay

var _proxies: Dictionary = {}
var _surface_material_cache: Dictionary = {}
var _outline_material_cache: Dictionary = {}
var _trail_mesh_cache: Dictionary = {}
var _trail_material_cache: Dictionary = {}
var _viewport_rect := Rect2(Vector2.ZERO, Vector2(360.0, 720.0))


func _ready() -> void:
	process_priority = 80
	add_to_group(&"ship_render_layer_3d")
	viewport_display.texture = ship_viewport.get_texture()
	viewport_display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	get_viewport().size_changed.connect(_resize_render_target)
	get_tree().node_added.connect(_on_tree_node_added)
	_resize_render_target()
	call_deferred("_scan_existing_sources")


func _exit_tree() -> void:
	if get_tree() != null and get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.disconnect(_on_tree_node_added)
	for proxy_variant in _proxies.values():
		var proxy := proxy_variant as VisualProxy
		_restore_suppressed_visuals(proxy)


func _process(_delta: float) -> void:
	sync_now()


func sync_now() -> void:
	var stale_ids: Array[int] = []
	for source_id_variant in _proxies:
		var source_id := int(source_id_variant)
		var proxy := _proxies[source_id] as VisualProxy
		var source := proxy.source_ref.get_ref() as Node2D
		if not is_instance_valid(source) or not source.is_inside_tree():
			stale_ids.append(source_id)
			continue
		_sync_proxy(proxy, source)
	for source_id in stale_ids:
		_unbind_source(source_id)


func _on_tree_node_added(node: Node) -> void:
	if node is Node2D:
		_try_bind_source.call_deferred(node)


func _scan_existing_sources() -> void:
	for player_node in get_tree().get_nodes_in_group("player"):
		_try_bind_source(player_node)
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		_try_bind_source(enemy_node)
	for section_node in get_tree().get_nodes_in_group("tempest_sections"):
		_try_bind_source(section_node)
	for drone_node in get_tree().get_nodes_in_group("drone_escort"):
		_try_bind_source(drone_node)


func _try_bind_source(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree() or not node is Node2D:
		return
	var source := node as Node2D
	var source_id := source.get_instance_id()
	if _proxies.has(source_id):
		return

	var archetype := _get_archetype(source)
	if not MODEL_SCENES.has(archetype):
		return
	var source_visual := _get_source_visual(source, archetype)
	if source_visual == null:
		return

	var model: Node3D
	var player_assembly: PlayerShipAssembly3D
	if archetype == &"player":
		player_assembly = PlayerShipAssembly3D.new()
		model = player_assembly
	else:
		var packed_scene := MODEL_SCENES[archetype] as PackedScene
		model = packed_scene.instantiate() as Node3D
	if model == null:
		return

	var proxy := VisualProxy.new()
	proxy.source_ref = weakref(source)
	proxy.source_id = source_id
	proxy.source_visual = source_visual
	proxy.source_sprite = source_visual as Sprite2D
	proxy.player_assembly = player_assembly
	proxy.archetype = archetype
	proxy.generation = _get_generation(source, archetype)
	proxy.phase_offset = float(source_id % 997) / 997.0 * TAU
	proxy.root = Node3D.new()
	proxy.root.name = "%s_3DProxy" % source.name
	proxy.model = model
	proxy.root.add_child(model)
	proxy_root.add_child(proxy.root)
	if player_assembly != null:
		player_assembly.build()
		proxy.meshes.assign(player_assembly.hull_meshes)
		proxy.outlines.assign(player_assembly.hull_outlines)
	else:
		_collect_meshes(model, proxy.meshes)
		for mesh_instance in proxy.meshes:
			var materials: Array[Material] = []
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				materials.append(mesh_instance.get_active_material(surface_index))
			proxy.source_materials[mesh_instance.get_instance_id()] = materials
		_apply_proxy_materials(proxy)
	_ensure_engine_trail(proxy)

	# Keep each 2D visual alive as its gameplay/state source, but make only its
	# own pixels transparent. Sibling cracks, smoke, tells, and collisions stay.
	_suppress_visual(proxy, source_visual)
	if archetype == &"player":
		_suppress_visual(
			proxy,
			source.get_node_or_null("UpgradeVisualsBack") as CanvasItem
		)
		_suppress_visual(
			proxy,
			source.get_node_or_null("UpgradeVisualsFront") as CanvasItem
		)

	_proxies[source_id] = proxy
	source.tree_exiting.connect(_unbind_source.bind(source_id), CONNECT_ONE_SHOT)
	_sync_proxy(proxy, source)


func _get_archetype(source: Node2D) -> StringName:
	if source.is_in_group("player"):
		return &"player"
	if source.is_in_group("drone_escort"):
		return &"drone_escort"
	if source is BossEnemy:
		var boss := source as BossEnemy
		if boss.is_tempest_core:
			return &"boss_tempest_core"
		if boss.is_elite:
			return &"boss_void_harbinger"
		match boss.boss_variant:
			BossEnemy.BossVariant.ASSAULT:
				return &"boss_assault"
			BossEnemy.BossVariant.BULWARK:
				return &"boss_bulwark"
			BossEnemy.BossVariant.TEMPEST:
				return &"boss_tempest"
	if source is TempestSection:
		return &"tempest_section"
	if source is BaseEnemy:
		var enemy := source as BaseEnemy
		if enemy.is_regular_enemy:
			return enemy.archetype_id
	return &""


func _get_source_visual(source: Node2D, archetype: StringName) -> CanvasItem:
	if archetype == &"player":
		return source.get_node_or_null("Sprite2D") as Sprite2D
	if archetype == &"drone_escort":
		return source.get_node_or_null("DroneVisual") as CanvasItem
	if archetype == &"tempest_section":
		return source
	return source.get_node_or_null("VisualRoot/Sprite2D") as Sprite2D


func _get_generation(source: Node2D, archetype: StringName) -> int:
	if archetype == &"player" or STATIC_STYLES.has(archetype):
		return 0
	if source is BaseEnemy:
		return clampi((source as BaseEnemy).generation, 1, 4)
	return 1


func _apply_proxy_materials(proxy: VisualProxy) -> void:
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
		outline.material_override = _get_outline_material(proxy.archetype, proxy.generation)
		mesh_instance.get_parent().add_child(outline)
		proxy.outlines.append(outline)

	_ensure_engine_trail(proxy)


func _ensure_engine_trail(proxy: VisualProxy) -> void:
	if not ENGINE_LAYOUTS.has(proxy.archetype):
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
	if source_material is BaseMaterial3D:
		var base_material := source_material as BaseMaterial3D
		base_color = base_material.albedo_color
		metallic = base_material.metallic
		roughness = base_material.roughness
		if base_material.emission_enabled:
			source_emission = 0.75 if STATIC_STYLES.has(archetype) else 1.45

	var style := _get_style(archetype, generation)
	var material := ShaderMaterial.new()
	material.shader = SHIP_SHADER
	material.set_shader_parameter("base_color", base_color)
	material.set_shader_parameter("energy_color", style["energy_color"])
	material.set_shader_parameter("accent_color", style["accent_color"])
	material.set_shader_parameter("metallic", metallic)
	material.set_shader_parameter("roughness", roughness)
	material.set_shader_parameter("evolution_level", style["evolution_level"])
	material.set_shader_parameter("circuit_amount", style["circuit_amount"])
	material.set_shader_parameter("heat_amount", style["heat_amount"])
	material.set_shader_parameter("apex_amount", style["apex_amount"])
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
	_surface_material_cache[cache_key] = material
	return material


func _get_outline_material(archetype: StringName, generation: int) -> ShaderMaterial:
	var cache_key := "%s:%d" % [archetype, generation]
	if _outline_material_cache.has(cache_key):
		return _outline_material_cache[cache_key] as ShaderMaterial
	var style := _get_style(archetype, generation)
	var material := ShaderMaterial.new()
	material.shader = OUTLINE_SHADER
	material.set_shader_parameter("outline_color", style["energy_color"])
	material.set_shader_parameter(
		"outline_width",
		0.028 + float(style["evolution_level"]) * 0.014
	)
	material.set_shader_parameter(
		"outline_energy",
		1.45 + float(style["evolution_level"]) * 0.85
	)
	_outline_material_cache[cache_key] = material
	return material


func _get_engine_trail_mesh(archetype: StringName) -> ArrayMesh:
	if _trail_mesh_cache.has(archetype):
		return _trail_mesh_cache[archetype] as ArrayMesh
	var layout: Dictionary = ENGINE_LAYOUTS[archetype]
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
		vertices.append(Vector3(center_x + half_width * 0.24, trail_y, nozzle_z + length))
		vertices.append(Vector3(center_x - half_width * 0.24, trail_y, nozzle_z + length))
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


func _get_engine_trail_material(archetype: StringName, generation: int) -> ShaderMaterial:
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
			"energy_color": CLASS_ENERGY[&"player"],
			"accent_color": CLASS_ACCENT[&"player"],
			"evolution_level": 0.25,
			"circuit_amount": 0.34,
			"heat_amount": 0.0,
			"apex_amount": 0.0,
			"emission_strength": 0.74,
		}
	if STATIC_STYLES.has(archetype):
		var static_style: Dictionary = STATIC_STYLES[archetype]
		return {
			"energy_color": CLASS_ENERGY[archetype],
			"accent_color": CLASS_ACCENT[archetype],
			"evolution_level": static_style["evolution_level"],
			"circuit_amount": static_style["circuit_amount"],
			"heat_amount": static_style["heat_amount"],
			"apex_amount": static_style["apex_amount"],
			"emission_strength": static_style["emission_strength"],
			"pattern_scale": static_style["pattern_scale"],
		}

	var clamped_generation := clampi(generation, 1, 4)
	var profile: Dictionary = EnemyEvolutionController.SHADER_PROFILES[clamped_generation - 1]
	var evolution_level := float(clamped_generation - 1) / 3.0
	var palette_blend := evolution_level * 0.46
	return {
		"energy_color": (CLASS_ENERGY[archetype] as Color).lerp(
			profile["energy_color"] as Color,
			palette_blend
		),
		"accent_color": (CLASS_ACCENT[archetype] as Color).lerp(
			profile["accent_color"] as Color,
			0.28 + evolution_level * 0.42
		),
		"evolution_level": evolution_level,
		"circuit_amount": profile["circuit_amount"],
		"heat_amount": profile["heat_amount"],
		"apex_amount": profile["apex_amount"],
		"emission_strength": 0.58 + float(profile["emission_strength"]) * 1.8,
	}


func _sync_proxy(proxy: VisualProxy, source: Node2D) -> void:
	var current_generation := _get_generation(source, proxy.archetype)
	if current_generation != proxy.generation:
		proxy.generation = current_generation
		_apply_proxy_materials(proxy)

	var center := screen_to_world(source.global_position)
	proxy.root.position = center
	var forward_2d := Vector2.UP.rotated(source.global_rotation)
	var forward_world_point := screen_to_world(source.global_position + forward_2d * 24.0)
	var forward_3d := forward_world_point - center
	forward_3d.y = 0.0
	if not forward_3d.is_zero_approx():
		proxy.root.look_at(center + forward_3d.normalized(), Vector3.UP)

	var source_scale := source.global_scale
	var visual_scale := Vector2.ONE
	var visual_root_2d := source.get_node_or_null("VisualRoot") as Node2D
	if visual_root_2d != null:
		visual_scale = visual_root_2d.scale
	if source is TempestSection:
		var section := source as TempestSection
		visual_scale = Vector2(
			section.section_size.x / 27.0,
			section.section_size.y / 48.0
		)
	var generation_scale := (
		1.0
		if proxy.archetype == &"player" or STATIC_STYLES.has(proxy.archetype)
		else 1.0 + float(proxy.generation - 1) * 0.055
	)
	var x_scale := absf(source_scale.x * visual_scale.x) * generation_scale
	var z_scale := absf(source_scale.y * visual_scale.y) * generation_scale
	proxy.root.scale = Vector3(x_scale, (x_scale + z_scale) * 0.5, z_scale)

	var source_feedback := source.modulate
	var flash := clampf(
		(minf(source_feedback.r, minf(source_feedback.g, source_feedback.b)) - 1.0) / 2.0,
		0.0,
		1.0
	)
	var combined_modulate := source_feedback
	if is_instance_valid(proxy.source_visual) and proxy.source_visual != source:
		var visual_feedback := proxy.source_visual.modulate
		combined_modulate *= visual_feedback
		flash = maxf(
			flash,
			clampf(
				(minf(
					visual_feedback.r,
					minf(visual_feedback.g, visual_feedback.b)
				) - 1.0) / 2.0,
				0.0,
				1.0
			)
		)
	var energy_override := Color(0.0, 0.0, 0.0, 0.0)
	var accent_override := Color(0.0, 0.0, 0.0, 0.0)
	var outline_override := Color(0.0, 0.0, 0.0, 0.0)
	if source is TempestSection:
		var section := source as TempestSection
		var health_ratio := maxf(float(section.health) / float(section.max_health), 0.0)
		var section_tint := section.section_color.darkened(
			0.06 + (1.0 - health_ratio) * 0.22
		)
		var body_tint := section_tint.lightened(0.30)
		combined_modulate *= Color(body_tint.r, body_tint.g, body_tint.b, 1.0)
		energy_override = Color(
			section.section_color.r,
			section.section_color.g,
			section.section_color.b,
			1.0
		)
		var bright_accent := section.section_color.lightened(0.48)
		accent_override = Color(
			bright_accent.r,
			bright_accent.g,
			bright_accent.b,
			1.0
		)
		outline_override = energy_override
	var instance_tint := Color(
		clampf(combined_modulate.r, 0.0, 1.5),
		clampf(combined_modulate.g, 0.0, 1.5),
		clampf(combined_modulate.b, 0.0, 1.5),
		1.0
	)
	var visible_alpha := combined_modulate.a
	proxy.root.visible = (
		source.is_visible_in_tree()
		and proxy.source_visual.visible
		and visible_alpha >= INVINCIBILITY_VISIBLE_ALPHA
	)
	if proxy.player_assembly != null:
		var upgrade_ids: Array[String] = source.call(&"get_active_elite_upgrade_ids")
		proxy.player_assembly.set_active_upgrades(upgrade_ids)
		proxy.player_assembly.set_feedback(instance_tint, flash, proxy.phase_offset)
	else:
		for mesh_instance in proxy.meshes:
			mesh_instance.set_instance_shader_parameter("instance_modulate", instance_tint)
			mesh_instance.set_instance_shader_parameter("instance_flash", flash)
			mesh_instance.set_instance_shader_parameter("instance_phase_offset", proxy.phase_offset)
			mesh_instance.set_instance_shader_parameter("instance_energy_override", energy_override)
			mesh_instance.set_instance_shader_parameter("instance_accent_override", accent_override)
		for outline in proxy.outlines:
			if not is_instance_valid(outline):
				continue
			outline.set_instance_shader_parameter("instance_modulate", instance_tint)
			outline.set_instance_shader_parameter("instance_flash", flash)
			outline.set_instance_shader_parameter("instance_outline_override", outline_override)
	if is_instance_valid(proxy.engine_trail):
		proxy.engine_trail.set_instance_shader_parameter(
			"instance_phase_offset",
			proxy.phase_offset
		)


func _unbind_source(source_id: int) -> void:
	if not _proxies.has(source_id):
		return
	var proxy := _proxies[source_id] as VisualProxy
	_proxies.erase(source_id)
	_restore_suppressed_visuals(proxy)
	if is_instance_valid(proxy.root):
		proxy.root.queue_free()


func _suppress_visual(proxy: VisualProxy, visual: CanvasItem) -> void:
	if not is_instance_valid(visual):
		return
	proxy.suppressed_visuals.append(visual)
	proxy.suppressed_self_modulates.append(visual.self_modulate)
	var hidden_modulate := visual.self_modulate
	hidden_modulate.a = 0.0
	visual.self_modulate = hidden_modulate


func _restore_suppressed_visuals(proxy: VisualProxy) -> void:
	for index in range(proxy.suppressed_visuals.size()):
		var visual := proxy.suppressed_visuals[index]
		if is_instance_valid(visual):
			visual.self_modulate = proxy.suppressed_self_modulates[index]
	proxy.suppressed_visuals.clear()
	proxy.suppressed_self_modulates.clear()


func _collect_meshes(root: Node, output: Array[MeshInstance3D]) -> void:
	if root is MeshInstance3D and not root.name.ends_with("_NeonOutline"):
		output.append(root as MeshInstance3D)
	for child in root.get_children():
		_collect_meshes(child, output)


func _resize_render_target() -> void:
	_viewport_rect = get_viewport().get_visible_rect()
	var overscan := Vector2i(RENDER_OVERSCAN_PIXELS, RENDER_OVERSCAN_PIXELS)
	var target_size := Vector2i(
		maxi(1, roundi(_viewport_rect.size.x)),
		maxi(1, roundi(_viewport_rect.size.y))
	) + overscan * 2
	ship_viewport.size = target_size
	# The oversized composite is positioned beyond the playfield. The main
	# viewport crops it only after Camera2D shake, so edge ships do not pop.
	viewport_display.position = _viewport_rect.position - Vector2(overscan)
	viewport_display.size = Vector2(target_size)
	camera_3d.size = float(target_size.y) / PIXELS_PER_MODEL_UNIT
	camera_3d.position = Vector3(0.0, CAMERA_HEIGHT, CAMERA_DEPTH)
	camera_3d.look_at(Vector3.ZERO, Vector3.UP)


func screen_to_world(screen_position: Vector2) -> Vector3:
	var local_position := (
		screen_position
		- _viewport_rect.position
		+ Vector2(RENDER_OVERSCAN_PIXELS, RENDER_OVERSCAN_PIXELS)
	)
	var ray_origin := camera_3d.project_ray_origin(local_position)
	var ray_direction := camera_3d.project_ray_normal(local_position)
	if absf(ray_direction.y) < 0.0001:
		return Vector3.ZERO
	var distance := -ray_origin.y / ray_direction.y
	return ray_origin + ray_direction * distance


## Narrow diagnostics API used by the smoke test and the developer menu.
func get_visual_for(source: Node2D) -> Node3D:
	if source == null or not _proxies.has(source.get_instance_id()):
		return null
	return (_proxies[source.get_instance_id()] as VisualProxy).root


func get_model_path_for(source: Node2D) -> String:
	var archetype := _get_archetype(source)
	return MODEL_PATHS.get(archetype, "")


func get_proxy_count() -> int:
	return _proxies.size()


func get_proxy_meshes(source: Node2D) -> Array[MeshInstance3D]:
	if source == null or not _proxies.has(source.get_instance_id()):
		return []
	return (_proxies[source.get_instance_id()] as VisualProxy).meshes.duplicate()


func get_proxy_outlines(source: Node2D) -> Array[MeshInstance3D]:
	if source == null or not _proxies.has(source.get_instance_id()):
		return []
	return (_proxies[source.get_instance_id()] as VisualProxy).outlines.duplicate()


func get_player_upgrade_visual(source: Node2D, upgrade_id: String) -> Node3D:
	if source == null or not _proxies.has(source.get_instance_id()):
		return null
	var proxy := _proxies[source.get_instance_id()] as VisualProxy
	if proxy.player_assembly == null:
		return null
	return proxy.player_assembly.get_module_root(upgrade_id)


func get_player_upgrade_model_path(upgrade_id: String) -> String:
	return PlayerShipAssembly3D.MODULE_PATHS.get(upgrade_id, "")


func get_player_upgrade_meshes(
	source: Node2D,
	upgrade_id: String
) -> Array[MeshInstance3D]:
	if source == null or not _proxies.has(source.get_instance_id()):
		return []
	var proxy := _proxies[source.get_instance_id()] as VisualProxy
	if proxy.player_assembly == null:
		return []
	return proxy.player_assembly.get_module_meshes(upgrade_id)


func get_player_upgrade_outlines(
	source: Node2D,
	upgrade_id: String
) -> Array[MeshInstance3D]:
	if source == null or not _proxies.has(source.get_instance_id()):
		return []
	var proxy := _proxies[source.get_instance_id()] as VisualProxy
	if proxy.player_assembly == null:
		return []
	return proxy.player_assembly.get_module_outlines(upgrade_id)


func set_render_paused(paused: bool) -> void:
	if paused:
		# A boss can hide itself and synchronously open an upgrade modal before
		# this node receives another process tick. Copy that final state now and
		# render it once so the paused texture cannot retain a dead ship.
		sync_now()
		ship_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	else:
		ship_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func request_render_refresh() -> void:
	var was_continuous := (
		ship_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS
	)
	sync_now()
	if not was_continuous:
		ship_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
