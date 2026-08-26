extends Node3D
class_name Native3DCameraRig
## Owns stable projection and presentation-only shake cameras.

const FlightConfig := preload("res://systems/flight_space_3d_config.gd")

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
	var cameras: Array[Camera3D] = [projection_camera, active_camera]
	for camera_node in cameras:
		if camera_node == null:
			continue
		camera_node.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera_node.keep_aspect = Camera3D.KEEP_HEIGHT
		camera_node.size = configuration.get_orthogonal_size()
		camera_node.near = 0.1
		camera_node.far = 200.0


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
