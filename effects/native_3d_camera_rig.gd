extends Node3D
class_name Native3DCameraRig
## Owns stable projection and presentation-only shake cameras.

const FlightConfig := preload("res://systems/flight_space_3d_config.gd")

const CAMERA_NEAR_CLIP := 0.1
const CAMERA_FAR_CLIP := 180.0
const COMBAT_RENDER_LAYER := 1

@export var configuration: FlightConfig

@onready var projection_camera: Camera3D = $ProjectionCamera3D
@onready var shake_offset: Node3D = $ShakeOffset
@onready var active_camera: Camera3D = $ShakeOffset/Camera3D

var _shake_intensity_world: float = 0.0
var _shake_rotation_radians: float = 0.0
var _shake_time_remaining: float = 0.0


func _ready() -> void:
	configure(configuration)
	SignalBus.screen_shake.connect(_on_screen_shake)
	SaveManager.settings_changed.connect(_on_settings_changed)
	set_process(false)


func configure(value: FlightConfig) -> void:
	if value == null:
		push_error("Native3DCameraRig requires a FlightSpace3DConfig resource")
		return
	configuration = value
	position = configuration.get_camera_position()
	rotation_degrees = Vector3(-configuration.camera_elevation_degrees, 0.0, 0.0)
	_configure_camera(projection_camera)
	_configure_camera(active_camera)
	if projection_camera != null:
		projection_camera.current = false
	if active_camera != null:
		active_camera.current = true


func _configure_camera(camera_node: Camera3D) -> void:
	if camera_node == null:
		return
	# KEEP_HEIGHT preserves the 1280x720 combat span vertically and reveals
	# additional horizontal space at wider or higher-resolution viewports.
	camera_node.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera_node.keep_aspect = Camera3D.KEEP_HEIGHT
	camera_node.size = maxf(configuration.get_orthogonal_size(), 1.0)
	camera_node.near = CAMERA_NEAR_CLIP
	camera_node.far = CAMERA_FAR_CLIP
	# Native combat nodes use the default 3D layer; keeping the mask explicit
	# prevents future presentation-only layers from entering the flight view.
	camera_node.cull_mask = COMBAT_RENDER_LAYER


func _process(delta: float) -> void:
	_shake_time_remaining = maxf(0.0, _shake_time_remaining - delta)
	if _shake_time_remaining <= 0.0:
		_reset_shake()
		set_process(false)
		return
	shake_offset.position = Vector3(
		randf_range(-_shake_intensity_world, _shake_intensity_world),
		randf_range(-_shake_intensity_world, _shake_intensity_world),
		0.0
	)
	shake_offset.rotation = Vector3(
		0.0,
		0.0,
		randf_range(-_shake_rotation_radians, _shake_rotation_radians)
	)
	_shake_intensity_world = lerpf(_shake_intensity_world, 0.0, delta * 5.0)
	_shake_rotation_radians = lerpf(_shake_rotation_radians, 0.0, delta * 5.0)


func _on_screen_shake(intensity: float, duration: float) -> void:
	if not bool(SaveManager.get_setting("screen_shake", true)) or configuration == null:
		_reset_shake()
		return
	_shake_intensity_world = configuration.pixels_to_world(intensity)
	_shake_rotation_radians = deg_to_rad(intensity * 0.08)
	_shake_time_remaining = duration
	set_process(true)


func _on_settings_changed() -> void:
	if not bool(SaveManager.get_setting("screen_shake", true)):
		_reset_shake()
		set_process(false)


func _reset_shake() -> void:
	shake_offset.position = Vector3.ZERO
	shake_offset.rotation = Vector3.ZERO
	_shake_intensity_world = 0.0
	_shake_rotation_radians = 0.0
	_shake_time_remaining = 0.0
