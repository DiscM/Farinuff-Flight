extends Control
## Neon Cabinet entry: backdrop plus the shared frontend, with no legacy menu.

const PIXEL_PLANET_SCENE_PATH := "res://effects/shaders/PixelPlanets/Planets/GasPlanetLayers/GasPlanetLayers.tscn"
const NATIVE_RUN_PATH := "res://scenes/native_3d_run.tscn"
const CRT_ENABLED_PROFILE := {
	"scanline_intensity": 0.13,
	"aberration_strength": 0.0015,
	"vignette_strength": 0.34,
	"contrast": 1.08,
	"brightness": 1.02,
}
const CRT_DISABLED_PROFILE := {
	"scanline_intensity": 0.0,
	"aberration_strength": 0.0,
	"vignette_strength": 0.0,
	"contrast": 1.0,
	"brightness": 1.0,
}

@onready var planet_stage: Control = $PlanetStage
@onready var crt_overlay: ColorRect = $CRTOverlay

var _planet: Control
var _frontend: FrontendShell
var _frontend_launch_layer: CanvasLayer
var _return_to_school := false
var _launching := false


func _ready() -> void:
	_return_to_school = GameManager.return_to_flight_school
	GameManager.return_to_flight_school = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_pixel_planet()
	_layout_planet(size)
	_apply_visual_settings()
	resized.connect(_on_resized)
	SaveManager.settings_changed.connect(_apply_visual_settings)
	# Mount before the first draw; there is no intermediate title screen.
	_mount_command_deck()


func _on_resized() -> void:
	if is_node_ready():
		_layout_planet(size)


func _build_pixel_planet() -> void:
	var packed_scene := load(PIXEL_PLANET_SCENE_PATH) as PackedScene
	if packed_scene == null:
		push_warning("Unable to load the main-menu PixelPlanet.")
		return

	_planet = packed_scene.instantiate() as Control
	if _planet == null:
		push_warning("Main-menu PixelPlanet root must be a Control.")
		return

	_planet.name = "RingedPixelPlanet"
	_planet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_planet.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_planet.position = Vector2.ZERO
	_planet.size = Vector2(100.0, 100.0)
	_planet.pivot_offset = Vector2.ZERO
	planet_stage.add_child(_planet)

	if _planet.has_method("set_seed"):
		_planet.call("set_seed", 734)
	if _planet.has_method("set_light"):
		_planet.call("set_light", Vector2(-0.12, 0.26))
	if _planet.has_method("set_rotates"):
		_planet.call("set_rotates", 0.018)
	if _planet.has_method("set_colors"):
		_planet.call("set_colors", PackedColorArray([
			Color(1.0, 0.42, 0.82),
			Color(0.60, 0.22, 0.88),
			Color(0.22, 0.15, 0.52),
			Color(0.18, 0.08, 0.31),
			Color(0.08, 0.05, 0.20),
			Color(0.015, 0.025, 0.09),
		]))


func _layout_planet(viewport_size: Vector2) -> void:
	if not is_instance_valid(_planet):
		return

	var ring_diameter := minf(viewport_size.x * 0.37, viewport_size.y * 0.68)
	ring_diameter = clampf(ring_diameter, 145.0, 760.0)
	var planet_scale := ring_diameter / 300.0
	var margin := maxf(24.0, viewport_size.x * 0.055)
	var center := Vector2(
		viewport_size.x - ring_diameter * 0.5 - margin,
		clampf(
			viewport_size.y * 0.41,
			ring_diameter * 0.5 + margin,
			viewport_size.y - ring_diameter * 0.5 - margin
		)
	)

	_planet.scale = Vector2.ONE * planet_scale
	_planet.position = center - Vector2(50.0, 50.0) * planet_scale


func _apply_visual_settings() -> void:
	var crt_enabled := bool(SaveManager.get_setting("crt_effect", true))
	var distortion_enabled := bool(SaveManager.get_setting("screen_distortion", true))
	crt_overlay.visible = crt_enabled or distortion_enabled

	var crt_material := crt_overlay.material as ShaderMaterial
	if crt_material == null:
		return
	crt_material.set_shader_parameter("apply_distortion", distortion_enabled)
	var profile: Dictionary = CRT_ENABLED_PROFILE if crt_enabled else CRT_DISABLED_PROFILE
	for parameter: String in profile:
		crt_material.set_shader_parameter(parameter, profile[parameter])


func _mount_command_deck() -> void:
	_frontend = preload("res://ui/frontend/frontend_shell.tscn").instantiate() as FrontendShell
	_frontend.name = "CommandDeckShell"
	var first_flight := not SaveManager.has_seen_flight_school
	_frontend.initial_page = &"flight_school" if _return_to_school or first_flight else &"command_deck"
	_frontend.initial_payload = {"first_flight": first_flight and not _return_to_school}
	_frontend.expedition_requested.connect(_launch_from_frontend)
	_frontend.practice_requested.connect(_practice_from_frontend)
	add_child(_frontend)
	# Keep CRT effects behind readable menu text and controls.
	move_child(_frontend, get_child_count() - 1)
	_frontend.get_node("Backdrop").color = Color(0.004, 0.008, 0.025, 0.38)

func _launch_from_frontend() -> void:
	_prepare_frontend_flight(NATIVE_RUN_PATH)

func _practice_from_frontend(wave: int) -> void:
	if _launching:
		return
	GameManager.practice_boss_wave = wave
	_prepare_frontend_flight("res://scenes/flight_practice.tscn")

func _prepare_frontend_flight(path: String) -> void:
	if _launching:
		return
	_launching = true
	_frontend.set_navigation_locked(true)
	_frontend_launch_layer = CanvasLayer.new()
	_frontend_launch_layer.layer = 70
	add_child(_frontend_launch_layer)
	var transition := preload("res://ui/frontend/launch_transition.gd").new()
	transition.scene_path = path
	transition.returned.connect(_recover_frontend_launch)
	_frontend_launch_layer.add_child(transition)
	var scene := await ResourceCache.wait_for_scene(path)
	if scene != null and get_tree().change_scene_to_packed(scene) == OK:
		return
	transition.show_failure()

func _recover_frontend_launch() -> void:
	_frontend_launch_layer.queue_free()
	_frontend_launch_layer = null
	_launching = false
	_frontend.set_navigation_locked(false)
	_frontend.return_to_command_deck()
