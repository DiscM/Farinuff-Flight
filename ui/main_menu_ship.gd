extends Node2D
## Display-only, fully upgraded 3D menu ship with no transform tweening.

signal launch_finished

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
]

var _rest_position := Vector2.ZERO
var _display_scale := 2.5
var _launch_requested := false
var _preview_viewport: SubViewport
var _assembly: PlayerShipAssembly3D


func _ready() -> void:
	_build_3d_ship()


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

	var world := Node3D.new()
	world.name = "MenuShipWorld"
	_preview_viewport.add_child(world)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-52.0, -24.0, 0.0)
	key_light.light_color = Color(0.62, 0.82, 1.0)
	key_light.light_energy = 2.35
	key_light.shadow_enabled = false
	world.add_child(key_light)

	var rim_light := DirectionalLight3D.new()
	rim_light.rotation_degrees = Vector3(38.0, 148.0, 0.0)
	rim_light.light_color = Color(1.0, 0.08, 0.54)
	rim_light.light_energy = 1.35
	rim_light.shadow_enabled = false
	world.add_child(rim_light)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.0
	camera.position = Vector3(0.0, 8.0, 5.0)
	camera.current = true
	world.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)

	_assembly = PlayerShipAssembly3D.new()
	world.add_child(_assembly)
	_assembly.build()
	_assembly.set_active_upgrades(ALL_UPGRADES, "", false, true)

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
