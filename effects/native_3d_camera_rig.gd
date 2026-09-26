extends Node3D
class_name Native3DCameraRig
## Orthographic view transitions around a fixed combat plane and arena.

signal view_transition_started
signal view_transition_finished

enum View { OVERHEAD, ANGLED }

const FlightConfig := preload("res://systems/flight_space_3d_config.gd")
const PortPresentation := preload("res://systems/home_port_presentation.gd")

const COMBAT_RENDER_LAYER := 1
## Matches the home port's Vector3(150, 180, 200) viewing direction.
const ANGLED_ELEVATION := 35.753887
const ANGLED_AZIMUTH := 36.869898
const VIEW_TRANSITION_SECONDS := 1.6
const ORBIT_STEP_DEGREES := 90.0
const FLIP_TRANSITION_SECONDS := 1.2

@export var configuration: FlightConfig

@onready var projection_camera: Camera3D = $ProjectionCamera3D
@onready var view_pivot: Node3D = $ViewPivot3D
@onready var shake_offset: Node3D = $ViewPivot3D/ShakeOffset
@onready var active_camera: Camera3D = $ViewPivot3D/ShakeOffset/Camera3D

var _follow_offset := Vector3.ZERO
var view_preset: View = View.ANGLED
var orbit_step := 0
var _view_angles := Vector2(ANGLED_ELEVATION, ANGLED_AZIMUTH)
var _transition_from := Vector2.ZERO
var _transition_target := Vector2.ZERO
var _transition_elapsed := 0.0
var _transition_duration := 0.0
var harbor_overview := false

var _shake_intensity_world: float = 0.0
var _shake_rotation_radians: float = 0.0
var _shake_time_remaining: float = 0.0


func _ready() -> void:
	process_physics_priority = -200
	configure(configuration)
	SignalBus.screen_shake.connect(_on_screen_shake)
	SaveManager.settings_changed.connect(_on_settings_changed)


func configure(value: FlightConfig) -> void:
	if value == null:
		push_error("Native3DCameraRig requires a FlightSpace3DConfig resource")
		return
	configuration = value
	# This camera remains independent of view transitions: AI, projectile speeds,
	# pickup ranges and arena bounds keep their existing world-space tuning.
	projection_camera.position = configuration.get_camera_position()
	projection_camera.rotation_degrees = Vector3(-configuration.camera_elevation_degrees, 0.0, 0.0)
	_configure_camera(projection_camera)
	_configure_camera(active_camera)
	if projection_camera != null:
		projection_camera.current = false
	if active_camera != null:
		active_camera.current = true
	_follow_offset = Vector3.ZERO
	orbit_step = 0
	set_view_preset(View.ANGLED, 0.0)
	_reset_shake()


func set_view_preset(preset: View, duration: float = VIEW_TRANSITION_SECONDS) -> void:
	view_preset = preset
	var elevation := ANGLED_ELEVATION if preset == View.ANGLED else configuration.camera_elevation_degrees
	var azimuth := ANGLED_AZIMUTH if preset == View.ANGLED else 0.0
	transition_to_view(elevation, azimuth + ORBIT_STEP_DEGREES * orbit_step, duration)


func toggle_view() -> void:
	set_view_preset(View.ANGLED if view_preset == View.OVERHEAD else View.OVERHEAD)


## Each press advances one quarter-turn, including presses during an orbit.
func flip_horizontal(duration: float = FLIP_TRANSITION_SECONDS) -> void:
	orbit_step = (orbit_step + 1) % 4
	var next_yaw := (_transition_target.y if is_transitioning() else _view_angles.y) + ORBIT_STEP_DEGREES
	var elevation := ANGLED_ELEVATION if view_preset == View.ANGLED else configuration.camera_elevation_degrees
	# Keep advancing in the same direction when several presses are in flight.
	_start_view_transition(elevation, next_yaw, duration)


## Retarget from the current pose, including during an unfinished transition.
func transition_to_view(elevation: float, azimuth: float, duration: float = VIEW_TRANSITION_SECONDS) -> void:
	var yaw_delta := wrapf(azimuth - _view_angles.y, -180.0, 180.0)
	if is_equal_approx(yaw_delta, -180.0):
		yaw_delta = 180.0
	_start_view_transition(elevation, _view_angles.y + yaw_delta, duration)


func _start_view_transition(elevation: float, azimuth: float, duration: float) -> void:
	_transition_from = _view_angles
	_transition_target = Vector2(clampf(elevation, 25.0, 90.0), azimuth)
	_transition_elapsed = 0.0
	_transition_duration = maxf(duration, 0.0)
	view_transition_started.emit()
	if bool(SaveManager.get_setting("reduced_motion", false)) or is_zero_approx(_transition_duration):
		_finish_view_transition()


func is_transitioning() -> bool:
	return _transition_duration > 0.0


func _physics_process(delta: float) -> void:
	_advance_view_transition(delta)


func _advance_view_transition(delta: float) -> void:
	if not is_transitioning():
		return
	_transition_elapsed = minf(_transition_elapsed + delta, _transition_duration)
	var progress := _transition_elapsed / _transition_duration
	# Smooth start and stop without tween callbacks surviving a scene reset.
	_view_angles = _transition_from.lerp(_transition_target, smoothstep(0.0, 1.0, progress))
	_apply_view()
	if _transition_elapsed >= _transition_duration:
		_finish_view_transition()


func _finish_view_transition() -> void:
	_view_angles = Vector2(_transition_target.x, wrapf(_transition_target.y, -180.0, 180.0))
	_transition_duration = 0.0
	_apply_view()
	view_transition_finished.emit()


func _apply_view() -> void:
	var elevation := deg_to_rad(_view_angles.x)
	var azimuth := deg_to_rad(_view_angles.y)
	var aspect := maxf(get_viewport().get_visible_rect().size.aspect(), 0.1)
	view_pivot.rotation = Vector3(-elevation, azimuth, 0.0)
	var target := PortPresentation.overview_target(aspect) if harbor_overview else Vector3.ZERO
	view_pivot.position = target + _follow_offset + view_pivot.basis.z * PortPresentation.CAMERA_OFFSET.length()
	active_camera.size = PortPresentation.INITIAL_ZOOM
	active_camera.near = PortPresentation.NEAR_CLIP
	active_camera.far = PortPresentation.FAR_CLIP


func _configure_camera(camera_node: Camera3D) -> void:
	if camera_node == null:
		return
	# KEEP_HEIGHT preserves the configured combat span vertically.
	# Wider aspect ratios reveal extra horizontal space; resolution adds detail.
	camera_node.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera_node.keep_aspect = Camera3D.KEEP_HEIGHT
	camera_node.size = maxf(configuration.get_orthogonal_size(), 1.0)
	camera_node.near = PortPresentation.NEAR_CLIP
	camera_node.far = PortPresentation.FAR_CLIP
	# Native combat nodes use the default 3D layer; keeping the mask explicit
	# prevents future presentation-only layers from entering the flight view.
	camera_node.cull_mask = COMBAT_RENDER_LAYER


func _process(delta: float) -> void:
	_update_follow(delta)
	_apply_view()
	var gameplay := get_tree().get_first_node_in_group(&"native_3d_gameplay") as Native3DGameplay
	if gameplay != null and is_instance_valid(gameplay.player):
		var correction := PortPresentation.pilot_frame_correction(active_camera, gameplay.player.global_position)
		_follow_offset += correction
		view_pivot.position += correction
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
	if bool(SaveManager.get_setting("reduced_motion", false)) and is_transitioning():
		_finish_view_transition()


func _reset_shake() -> void:
	shake_offset.position = Vector3.ZERO
	shake_offset.rotation = Vector3.ZERO
	_shake_intensity_world = 0.0
	_shake_rotation_radians = 0.0
	_shake_time_remaining = 0.0


func _update_follow(delta: float) -> void:
	var target := Vector3.ZERO
	var gameplay := get_tree().get_first_node_in_group(&"native_3d_gameplay") as Native3DGameplay
	if gameplay != null and is_instance_valid(gameplay.player) and not bool(SaveManager.get_setting("reduced_motion", false)):
		target = gameplay.player.velocity * 0.12
	_follow_offset = _follow_offset.lerp(target, 1.0 - exp(-delta * 2.7))
	# Follow is applied to the view pivot; the projection camera stays fixed.
