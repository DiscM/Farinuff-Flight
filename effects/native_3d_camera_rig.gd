extends Node3D
class_name Native3DCameraRig
## Fixed movement projection with loose boss-camera follow and additive shake.

const FlightConfig := preload("res://systems/flight_space_3d_config.gd")

const CAMERA_NEAR_CLIP := 0.1
const CAMERA_FAR_CLIP := 180.0
const COMBAT_RENDER_LAYER := 1

@export var configuration: FlightConfig

@onready var projection_camera: Camera3D = $ProjectionCamera3D
@onready var shake_offset: Node3D = $ShakeOffset
@onready var active_camera: Camera3D = $ShakeOffset/Camera3D

var _follow_offset := Vector3.ZERO

var _shake_intensity_world: float = 0.0
var _shake_rotation_radians: float = 0.0
var _shake_time_remaining: float = 0.0


func _ready() -> void:
	configure(configuration)
	SignalBus.screen_shake.connect(_on_screen_shake)
	SaveManager.settings_changed.connect(_on_settings_changed)


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
	_update_follow(delta)
	_shake_time_remaining = maxf(0.0, _shake_time_remaining - delta)
	if _shake_time_remaining <= 0.0:
		_reset_shake()
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


func _reset_shake() -> void:
	shake_offset.position = Vector3.ZERO
	shake_offset.rotation = Vector3.ZERO
	_shake_intensity_world = 0.0
	_shake_rotation_radians = 0.0
	_shake_time_remaining = 0.0


func _update_follow(delta: float) -> void:
	var target := Vector3.ZERO
	var gameplay := get_tree().get_first_node_in_group(&"native_3d_gameplay") as Native3DGameplay
	if GameManager.boss_active and gameplay != null and is_instance_valid(gameplay.player):
		var space: FlightSpace3D = gameplay.flight_space
		var view := space.get_view_bounds()
		var arena := space.get_combat_bounds()
		var center := Vector3(view.get_center().x, 0.0, view.get_center().y)
		var displacement := space.combat_motion_to_screen(gameplay.player.global_position - center - _follow_offset)
		# Leave a soft 90-pixel pocket around the player; boost can lead the camera.
		var excess := Vector2(signf(displacement.x) * maxf(absf(displacement.x) - 90.0, 0.0), signf(displacement.y) * maxf(absf(displacement.y) - 70.0, 0.0))
		target = _follow_offset + space.screen_motion_to_combat(excess)
		target.x = clampf(target.x, arena.position.x + view.size.x * 0.5 - center.x, arena.end.x - view.size.x * 0.5 - center.x)
		target.z = clampf(target.z, arena.position.y + view.size.y * 0.5 - center.z, arena.end.y - view.size.y * 0.5 - center.z)
	_follow_offset = _follow_offset.lerp(target, 1.0 - exp(-3.0 * delta))
	# Only the rendered camera follows. Stable projection still owns movement
	# scale and fixed arena bounds, and ShakeOffset continues to add feedback.
	active_camera.position = global_basis.inverse() * _follow_offset
