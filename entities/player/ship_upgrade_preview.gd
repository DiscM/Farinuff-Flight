extends Control
class_name ShipUpgradePreview
## Static native 3D preview of a hull plus its current/candidate modules.

const NativeUpgradeCatalog := preload("res://entities/player/native_player_upgrades.gd")
const SUPPORTED_HULL_IDS: Array[String] = [
	"ship_swallowtail",
	"ship_interceptor",
	"ship_bulwark",
]

const PREVIEW_SIZE := Vector2i(256, 128)

var _current_upgrades: Array[String] = []
var _candidate_id := ""
var _requested_hull_id := ""
var _built_hull_id := ""
var _preview_viewport: SubViewport
var _preview_world: Node3D
var _assembly: PlayerShipAssembly3D


func _ready() -> void:
	_build_3d_preview()


## Configures the native preview. `hull_id` is optional for existing callers;
## when supplied, the preview renders that hull without changing the run's
## selected loadout.
func configure(
	current_upgrades: Array[String],
	candidate_id: String,
	hull_id: String = ""
) -> void:
	_current_upgrades.clear()
	for id in current_upgrades:
		var upgrade_id := str(id)
		if NativeUpgradeCatalog.SUPPORTED_IDS.has(upgrade_id) and not _current_upgrades.has(upgrade_id):
			_current_upgrades.append(upgrade_id)
	_candidate_id = str(candidate_id)
	_requested_hull_id = _normalize_hull_id(hull_id)
	custom_minimum_size = Vector2(0, 76)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_node_ready():
		if _requested_hull_id != _built_hull_id:
			_rebuild_assembly()
		_refresh_preview()


func get_assembly() -> PlayerShipAssembly3D:
	return _assembly


func get_preview_viewport() -> SubViewport:
	return _preview_viewport


func get_hull_id() -> String:
	return _built_hull_id


func _build_3d_preview() -> void:
	_preview_viewport = SubViewport.new()
	_preview_viewport.name = "UpgradePreviewViewport"
	_preview_viewport.size = PREVIEW_SIZE
	_preview_viewport.transparent_bg = true
	_preview_viewport.handle_input_locally = false
	_preview_viewport.own_world_3d = true
	_preview_viewport.msaa_3d = Viewport.MSAA_4X
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_preview_viewport)

	_preview_world = Node3D.new()
	_preview_world.name = "PreviewWorld"
	_preview_viewport.add_child(_preview_world)

	var key_light := DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.rotation_degrees = Vector3(-52.0, -24.0, 0.0)
	key_light.light_color = Color(0.62, 0.82, 1.0)
	key_light.light_energy = 2.35
	key_light.shadow_enabled = false
	_preview_world.add_child(key_light)

	var rim_light := DirectionalLight3D.new()
	rim_light.name = "RimLight"
	rim_light.rotation_degrees = Vector3(38.0, 148.0, 0.0)
	rim_light.light_color = Color(1.0, 0.08, 0.54)
	rim_light.light_energy = 1.35
	rim_light.shadow_enabled = false
	_preview_world.add_child(rim_light)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.0
	camera.position = Vector3(0.0, 8.0, 5.0)
	camera.current = true
	_preview_world.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)

	_create_assembly()

	var display := TextureRect.new()
	display.name = "PreviewDisplay"
	display.set_anchors_preset(Control.PRESET_FULL_RECT)
	display.set_offsets_preset(Control.PRESET_FULL_RECT)
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.texture = _preview_viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(display)
	_refresh_preview()


func _normalize_hull_id(hull_id: String) -> String:
	return hull_id if SUPPORTED_HULL_IDS.has(hull_id) else ""


## PlayerShipAssembly3D reads the selected hull from MetaProgression while it
## builds. Swap that value only for the synchronous build, then restore it so
## launch-bay previews never mutate the actual run loadout.
func _create_assembly() -> void:
	if not is_instance_valid(_preview_world):
		return
	var previous_hull_id := MetaProgression.selected_ship
	if _requested_hull_id != "":
		MetaProgression.selected_ship = _requested_hull_id
	_assembly = PlayerShipAssembly3D.new()
	_assembly.name = "PlayerShipAssembly3D"
	_preview_world.add_child(_assembly)
	_assembly.build()
	MetaProgression.selected_ship = previous_hull_id
	_built_hull_id = _requested_hull_id


func _rebuild_assembly() -> void:
	if is_instance_valid(_assembly):
		_assembly.queue_free()
	_create_assembly()


func _refresh_preview() -> void:
	if not is_instance_valid(_assembly):
		return
	var upgrades := _current_upgrades.duplicate()
	if (
		_candidate_id != ""
		and NativeUpgradeCatalog.SUPPORTED_IDS.has(_candidate_id)
		and not upgrades.has(_candidate_id)
	):
		upgrades.append(_candidate_id)
	_assembly.set_active_upgrades(
		upgrades,
		_candidate_id,
		true,
		true
	)
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
