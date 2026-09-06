extends Node2D
## Display-only, fully assembled native 3D menu ship with no transform tweening.

signal launch_finished

const NativeUpgradeCatalog := preload("res://entities/player/native_player_upgrades.gd")
const BASE_ROTATION := deg_to_rad(20.0)
const RENDER_SIZE := Vector2i(256, 256)
const ALL_UPGRADES: Array[String] = [
	"twin_cannons",
	"auto_aim",
	"drone_escort",
	"hull_plating",
	"afterburner",
	"spread_shot_elite",
	"shield_burst",
	"magnet_field",
	"overclock",
	"rear_gunner",
	"orbitals",
	"piercing",
	"explosive_rounds",
]

var _rest_position := Vector2.ZERO
var _display_scale := 2.5
var _launch_requested := false
var _preview_viewport: SubViewport
var _preview_world: Node3D
var _assembly: PlayerShipAssembly3D
var _preview_hull_id := ""


func _ready() -> void:
	_build_3d_ship()
	set_process(true)


## The launch bay can change the selected hull while this menu remains alive
## underneath it. Refresh the display-only assembly so returning to the menu
## never leaves an outdated hull on screen.
func _process(_delta: float) -> void:
	if _launch_requested or not is_instance_valid(_assembly):
		return
	var selected_hull_id := str(MetaProgression.selected_ship)
	if selected_hull_id == _preview_hull_id:
		return
	_refresh_hull_preview(selected_hull_id)


func set_layout(viewport_size: Vector2, _animate_intro: bool) -> void:
	var layout_scale := clampf(
		minf(viewport_size.x / 1238.0, viewport_size.y / 720.0),
		0.72,
		1.35
	)
	_display_scale = 2.45 * layout_scale
	_rest_position = Vector2(viewport_size.x * 0.80, viewport_size.y * 0.57)
	if _launch_requested:
		return
	position = _rest_position
	scale = Vector2.ONE * _display_scale
	rotation = BASE_ROTATION
	modulate = Color.WHITE


func play_intro(_viewport_size: Vector2) -> void:
	position = _rest_position
	scale = Vector2.ONE * _display_scale
	rotation = BASE_ROTATION
	modulate = Color.WHITE


func fly_out(_viewport_size: Vector2) -> void:
	if _launch_requested:
		return
	_launch_requested = true
	launch_finished.emit()


func get_assembly() -> PlayerShipAssembly3D:
	return _assembly


func get_preview_viewport() -> SubViewport:
	return _preview_viewport


func get_preview_hull_id() -> String:
	return _preview_hull_id


func _build_3d_ship() -> void:
	_preview_viewport = SubViewport.new()
	_preview_viewport.name = "MenuShipViewport"
	_preview_viewport.size = RENDER_SIZE
	_preview_viewport.transparent_bg = true
	_preview_viewport.handle_input_locally = false
	_preview_viewport.own_world_3d = true
	_preview_viewport.msaa_3d = Viewport.MSAA_4X
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_preview_viewport)

	_preview_world = Node3D.new()
	_preview_world.name = "MenuShipWorld"
	_preview_viewport.add_child(_preview_world)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-52.0, -24.0, 0.0)
	key_light.light_color = Color(0.62, 0.82, 1.0)
	key_light.light_energy = 2.35
	key_light.shadow_enabled = false
	_preview_world.add_child(key_light)

	var rim_light := DirectionalLight3D.new()
	rim_light.rotation_degrees = Vector3(38.0, 148.0, 0.0)
	rim_light.light_color = Color(1.0, 0.08, 0.54)
	rim_light.light_energy = 1.35
	rim_light.shadow_enabled = false
	_preview_world.add_child(rim_light)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.0
	camera.position = Vector3(0.0, 8.0, 5.0)
	camera.current = true
	_preview_world.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)

	_preview_hull_id = str(MetaProgression.selected_ship)
	_build_assembly()

	var display := TextureRect.new()
	display.name = "MenuShipDisplay"
	display.position = Vector2(-64.0, -64.0)
	display.size = Vector2(128.0, 128.0)
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.texture = _preview_viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(display)


func _native_preview_upgrade_ids() -> Array[String]:
	var ids: Array[String] = []
	for upgrade_id in ALL_UPGRADES:
		if NativeUpgradeCatalog.SUPPORTED_IDS.has(upgrade_id) and not ids.has(upgrade_id):
			ids.append(upgrade_id)
	# Keep this display complete if the catalog gains a native module before the
	# presentation list is updated.
	for upgrade_id in NativeUpgradeCatalog.SUPPORTED_IDS:
		var normalized_id := str(upgrade_id)
		if not ids.has(normalized_id):
			ids.append(normalized_id)
	return ids


func _build_assembly() -> void:
	if not is_instance_valid(_preview_world):
		return
	_assembly = PlayerShipAssembly3D.new()
	_assembly.name = "MenuPlayerShipAssembly3D"
	_preview_world.add_child(_assembly)
	_assembly.build()
	_assembly.set_active_upgrades(_native_preview_upgrade_ids(), "", false, true)


func _refresh_hull_preview(selected_hull_id: String) -> void:
	_preview_hull_id = selected_hull_id
	var previous_assembly := _assembly
	_build_assembly()
	if is_instance_valid(previous_assembly):
		previous_assembly.queue_free()
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
