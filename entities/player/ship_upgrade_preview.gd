extends Control
class_name ShipUpgradePreview
## Static 3D popup preview of the current hull plus one candidate module.

const PREVIEW_SIZE := Vector2i(256, 128)

var _current_upgrades: Array[String] = []
var _candidate_id := ""
var _preview_viewport: SubViewport
var _assembly: PlayerShipAssembly3D


func _ready() -> void:
	_build_3d_preview()


func configure(current_upgrades: Array[String], candidate_id: String) -> void:
	_current_upgrades.clear()
	for id in current_upgrades:
		if not _current_upgrades.has(id):
			_current_upgrades.append(id)
	_candidate_id = candidate_id
	custom_minimum_size = Vector2(0, 66)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_node_ready():
		_refresh_preview()


func get_assembly() -> PlayerShipAssembly3D:
	return _assembly


func get_preview_viewport() -> SubViewport:
	return _preview_viewport


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

	var world := Node3D.new()
	world.name = "PreviewWorld"
	_preview_viewport.add_child(world)

	var key_light := DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.rotation_degrees = Vector3(-52.0, -24.0, 0.0)
	key_light.light_color = Color(0.62, 0.82, 1.0)
	key_light.light_energy = 2.35
	key_light.shadow_enabled = false
	world.add_child(key_light)

	var rim_light := DirectionalLight3D.new()
	rim_light.name = "RimLight"
	rim_light.rotation_degrees = Vector3(38.0, 148.0, 0.0)
	rim_light.light_color = Color(1.0, 0.08, 0.54)
	rim_light.light_energy = 1.35
	rim_light.shadow_enabled = false
	world.add_child(rim_light)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.0
	camera.position = Vector3(0.0, 8.0, 5.0)
	camera.current = true
	world.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)

	_assembly = PlayerShipAssembly3D.new()
	_assembly.name = "PlayerShipAssembly3D"
	world.add_child(_assembly)
	_assembly.build()

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


func _refresh_preview() -> void:
	if not is_instance_valid(_assembly):
		return
	var upgrades := _current_upgrades.duplicate()
	if not upgrades.has(_candidate_id):
		upgrades.append(_candidate_id)
	_assembly.set_active_upgrades(
		upgrades,
		_candidate_id,
		true,
		true
	)
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
