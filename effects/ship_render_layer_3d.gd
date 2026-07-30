extends Node2D
class_name ShipRenderLayer3D
## Shared 2.5D presentation layer.
##
## Area2D actors remain authoritative for movement, collision, weapons, and
## evolution. This node renders one synchronized 3D proxy per supported ship
## into a single transparent viewport composited between the 2D background and
## the existing projectiles/effects.

const Catalog := preload("res://effects/rendering/ship_render_catalog_3d.gd")
const MaterialLibrary := preload(
	"res://effects/rendering/ship_render_material_library_3d.gd"
)
const VisualSynchronizer := preload(
	"res://effects/rendering/ship_visual_synchronizer_3d.gd"
)
const VisualProxy := preload(
	"res://effects/rendering/ship_visual_proxy_3d.gd"
)

# Compatibility constants retained on the public render-layer type.
const SHIP_SHADER := MaterialLibrary.SHIP_SHADER
const OUTLINE_SHADER := MaterialLibrary.OUTLINE_SHADER
const ENGINE_TRAIL_SHADER := MaterialLibrary.ENGINE_TRAIL_SHADER
const MODEL_SCENES := Catalog.MODEL_SCENES
const MODEL_PATHS := Catalog.MODEL_PATHS
const CLASS_ENERGY := Catalog.CLASS_ENERGY
const CLASS_ACCENT := Catalog.CLASS_ACCENT
const STATIC_STYLES := Catalog.STATIC_STYLES
const ENGINE_LAYOUTS := Catalog.ENGINE_LAYOUTS
const PIXELS_PER_MODEL_UNIT := Catalog.PIXELS_PER_MODEL_UNIT
const PIXELATION := Catalog.PIXELATION
const CAMERA_HEIGHT := Catalog.CAMERA_HEIGHT
const CAMERA_DEPTH := Catalog.CAMERA_DEPTH
const INVINCIBILITY_VISIBLE_ALPHA := Catalog.INVINCIBILITY_VISIBLE_ALPHA
const RENDER_OVERSCAN_PIXELS := Catalog.RENDER_OVERSCAN_PIXELS


@onready var ship_viewport: SubViewport = $ShipViewport
@onready var visual_world: Node3D = $ShipViewport/VisualWorld
@onready var camera_3d: Camera3D = $ShipViewport/VisualWorld/Camera3D
@onready var proxy_root: Node3D = $ShipViewport/VisualWorld/Proxies
@onready var viewport_display: TextureRect = $ViewportDisplay

var _proxies: Dictionary = {}
var _materials := MaterialLibrary.new()
var _synchronizer := VisualSynchronizer.new()
var _viewport_rect := Rect2(Vector2.ZERO, Vector2(360.0, 720.0))


func _ready() -> void:
	process_priority = 80
	add_to_group(&"ship_render_layer_3d")
	viewport_display.texture = ship_viewport.get_texture()
	# NEAREST upscale keeps the low-res ship pixels chunky, matching the
	# PixelPlanets backgrounds instead of smoothing them away.
	viewport_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	get_viewport().size_changed.connect(_resize_render_target)
	get_tree().node_added.connect(_on_tree_node_added)
	_resize_render_target()
	call_deferred("_scan_existing_sources")


func _exit_tree() -> void:
	if get_tree() != null and get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.disconnect(_on_tree_node_added)
	for proxy_variant in _proxies.values():
		var proxy := proxy_variant as VisualProxy
		proxy.restore_suppressed_visuals()


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

	var archetype := Catalog.get_archetype(source)
	if not Catalog.MODEL_SCENES.has(archetype):
		return
	var source_visual := Catalog.get_source_visual(source, archetype)
	if source_visual == null:
		return

	var model := Catalog.instantiate_model(archetype)
	if model == null:
		return
	var player_assembly := model as PlayerShipAssembly3D

	var proxy := VisualProxy.new()
	proxy.source_ref = weakref(source)
	proxy.source_visual = source_visual
	proxy.player_assembly = player_assembly
	proxy.archetype = archetype
	proxy.generation = Catalog.get_generation(source, archetype)
	proxy.phase_offset = float(source_id % 997) / 997.0 * TAU
	proxy.root = Node3D.new()
	proxy.root.name = "%s_3DProxy" % source.name
	proxy.model = model
	proxy.root.add_child(model)
	proxy_root.add_child(proxy.root)
	_materials.configure_proxy(proxy)

	# Keep each 2D visual alive as its gameplay/state source, but make only its
	# own pixels transparent. Sibling cracks, smoke, tells, and collisions stay.
	proxy.suppress_visual(source_visual)
	if archetype == &"player":
		proxy.suppress_visual(
			source.get_node_or_null("UpgradeVisualsBack") as CanvasItem
		)
		proxy.suppress_visual(
			source.get_node_or_null("UpgradeVisualsFront") as CanvasItem
		)

	_proxies[source_id] = proxy
	source.tree_exiting.connect(_unbind_source.bind(source_id), CONNECT_ONE_SHOT)
	_sync_proxy(proxy, source)


func _sync_proxy(proxy: VisualProxy, source: Node2D) -> void:
	_synchronizer.sync_proxy(
		proxy,
		source,
		screen_to_world,
		_materials
	)


func _unbind_source(source_id: int) -> void:
	if not _proxies.has(source_id):
		return
	var proxy := _proxies[source_id] as VisualProxy
	_proxies.erase(source_id)
	proxy.restore_suppressed_visuals()
	if is_instance_valid(proxy.root):
		proxy.root.queue_free()


func _resize_render_target() -> void:
	_viewport_rect = get_viewport().get_visible_rect()
	var overscan := Vector2i(RENDER_OVERSCAN_PIXELS, RENDER_OVERSCAN_PIXELS)
	var target_size := Vector2i(
		maxi(1, roundi(_viewport_rect.size.x)),
		maxi(1, roundi(_viewport_rect.size.y))
	) + overscan * 2
	# Render into a 1/PIXELATION buffer; the TextureRect stretches it back to
	# the full composite size with NEAREST filtering (the chunky pixel grid).
	var buffer_size := Vector2i(
		maxi(1, target_size.x / PIXELATION),
		maxi(1, target_size.y / PIXELATION)
	)
	ship_viewport.size = buffer_size
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
	# Ray projection works in the SubViewport's pixel space, which is the
	# 1/PIXELATION buffer, so scale the full-res composite position down.
	var buffer_position := local_position / float(PIXELATION)
	var ray_origin := camera_3d.project_ray_origin(buffer_position)
	var ray_direction := camera_3d.project_ray_normal(buffer_position)
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
	var archetype := Catalog.get_archetype(source)
	return Catalog.MODEL_PATHS.get(archetype, "")


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
