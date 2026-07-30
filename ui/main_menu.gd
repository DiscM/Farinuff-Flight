extends Control
## Animated Neon Vector Cabinet title screen.

const SETTINGS_MENU_SCENE := preload("res://ui/settings_menu.tscn")
const PIXEL_PLANET_SCENE_PATH := "res://effects/shaders/PixelPlanets/Planets/GasPlanetLayers/GasPlanetLayers.tscn"

const CYAN := Color(0.14, 0.93, 1.0)
const YELLOW := Color(1.0, 0.84, 0.12)
const GREEN := Color(0.32, 1.0, 0.55)
const MAGENTA := Color(1.0, 0.16, 0.55)
const INK := Color(0.005, 0.012, 0.04, 0.96)
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
@onready var cabinet_layout: Control = $CabinetLayout
@onready var ship_rig: Node2D = $ShipStage/ShipRig
@onready var play_button: Button = $CabinetLayout/PlayButton
@onready var settings_button: Button = $CabinetLayout/SettingsButton
@onready var play_reticle: Label = $CabinetLayout/PlayReticle
@onready var tagline: PanelContainer = $CabinetLayout/Tagline
@onready var crt_overlay: ColorRect = $CRTOverlay

var _planet: Control
var _settings_menu: Node
var _launching := false
var _pulse_time := 0.0
var _intro_played := false
var _layout_tween: Tween
var _button_focus_tweens: Dictionary[Button, Tween] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_apply_arcade_styles()
	_build_pixel_planet()

	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	play_button.pressed.connect(AudioManager.play_ui_click)
	settings_button.pressed.connect(AudioManager.play_ui_click)
	play_button.mouse_entered.connect(play_button.grab_focus)
	settings_button.mouse_entered.connect(settings_button.grab_focus)
	play_button.focus_entered.connect(_on_button_focus_entered.bind(play_button))
	settings_button.focus_entered.connect(_on_button_focus_entered.bind(settings_button))
	ship_rig.connect("launch_finished", _on_ship_launch_finished)
	resized.connect(_on_resized)
	if not SaveManager.settings_changed.is_connected(_apply_visual_settings):
		SaveManager.settings_changed.connect(_apply_visual_settings)

	call_deferred("_finish_setup")
	set_process(true)


func _process(delta: float) -> void:
	_pulse_time += delta
	play_reticle.modulate.a = 0.70 + sin(_pulse_time * 3.6) * 0.25
	play_reticle.rotation = sin(_pulse_time * 1.7) * 0.055


func _finish_setup() -> void:
	_layout_scene(true)
	_apply_visual_settings()
	play_button.grab_focus()
	_play_title_intro()


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


func _layout_scene(animate_ship: bool) -> void:
	var viewport_size := size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = get_viewport_rect().size

	var cabinet_scale := minf(viewport_size.y / 720.0, viewport_size.x / 760.0)
	cabinet_scale = clampf(cabinet_scale, 0.44, 1.35)
	cabinet_layout.scale = Vector2.ONE * cabinet_scale
	cabinet_layout.position = Vector2(
		maxf(14.0, viewport_size.x * 0.035),
		maxf(12.0, viewport_size.y * 0.025)
	)

	_layout_planet(viewport_size)
	if ship_rig.has_method("set_layout"):
		ship_rig.call("set_layout", viewport_size, animate_ship and not _intro_played)
	_intro_played = true


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


func _play_title_intro() -> void:
	var target_position := cabinet_layout.position
	cabinet_layout.position = target_position - Vector2(38.0, 0.0)
	cabinet_layout.modulate.a = 0.0

	if is_instance_valid(_planet):
		_planet.modulate.a = 0.0
	if is_instance_valid(_layout_tween):
		_layout_tween.kill()
	_layout_tween = create_tween()
	_layout_tween.set_parallel(true)
	_layout_tween.set_trans(Tween.TRANS_QUART)
	_layout_tween.set_ease(Tween.EASE_OUT)
	_layout_tween.tween_property(cabinet_layout, "position", target_position, 0.58)
	_layout_tween.tween_property(cabinet_layout, "modulate:a", 1.0, 0.42)
	if is_instance_valid(_planet):
		_layout_tween.tween_property(_planet, "modulate:a", 1.0, 0.72)


func _apply_arcade_styles() -> void:
	tagline.add_theme_stylebox_override(
		"panel",
		_make_style(YELLOW, Color(0.03, 0.03, 0.02, 1.0), 0, 0)
	)

	var play_normal := _make_style(YELLOW, Color(0.03, 0.03, 0.02, 1.0), 4, 3)
	var play_hover := _make_style(Color(1.0, 0.92, 0.34), Color(0.06, 0.04, 0.01, 1.0), 4, 4)
	var play_pressed := _make_style(Color(1.0, 0.72, 0.05), Color(0.09, 0.05, 0.0, 1.0), 4, 3)
	play_button.add_theme_stylebox_override("normal", play_normal)
	play_button.add_theme_stylebox_override("hover", play_hover)
	play_button.add_theme_stylebox_override("focus", play_hover)
	play_button.add_theme_stylebox_override("pressed", play_pressed)
	play_button.add_theme_color_override("font_color", Color(0.025, 0.025, 0.025))
	play_button.add_theme_color_override("font_hover_color", Color(0.01, 0.01, 0.01))
	play_button.add_theme_color_override("font_focus_color", Color(0.01, 0.01, 0.01))

	var settings_normal := _make_style(INK, CYAN, 2, 2)
	var settings_hover := _make_style(Color(0.02, 0.10, 0.18, 0.98), Color(0.48, 0.98, 1.0), 2, 3)
	var settings_pressed := _make_style(Color(0.03, 0.14, 0.22, 1.0), CYAN, 2, 2)
	settings_button.add_theme_stylebox_override("normal", settings_normal)
	settings_button.add_theme_stylebox_override("hover", settings_hover)
	settings_button.add_theme_stylebox_override("focus", settings_hover)
	settings_button.add_theme_stylebox_override("pressed", settings_pressed)
	settings_button.add_theme_color_override("font_color", CYAN)
	settings_button.add_theme_color_override("font_hover_color", Color(0.82, 1.0, 1.0))
	settings_button.add_theme_color_override("font_focus_color", Color(0.82, 1.0, 1.0))


func _make_style(
	fill: Color,
	border: Color,
	corner_radius: int,
	border_width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	style.shadow_size = 5
	style.shadow_offset = Vector2(7.0, 8.0)
	return style


func _on_button_focus_entered(button: Button) -> void:
	if _launching:
		return
	var previous_tween: Tween = _button_focus_tweens.get(button)
	if is_instance_valid(previous_tween):
		previous_tween.kill()
	var tween := create_tween()
	_button_focus_tweens[button] = tween
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	button.scale = Vector2.ONE * 0.985
	tween.tween_property(button, "scale", Vector2.ONE, 0.18)


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


func _on_play_pressed() -> void:
	if _launching or is_instance_valid(_settings_menu):
		return
	_launching = true
	play_button.disabled = true
	settings_button.disabled = true

	var viewport_size := size if size.x > 1.0 else get_viewport_rect().size
	if is_instance_valid(_planet) and _planet.has_method("set_rotates"):
		_planet.call("set_rotates", 0.055)
	if ship_rig.has_method("fly_out"):
		ship_rig.call("fly_out", viewport_size)
	else:
		_on_ship_launch_finished()


func _on_ship_launch_finished() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_settings_pressed() -> void:
	if _launching or is_instance_valid(_settings_menu):
		return
	_settings_menu = SETTINGS_MENU_SCENE.instantiate()
	_settings_menu.connect("closed", _on_settings_closed)
	add_child(_settings_menu)


func _on_settings_closed() -> void:
	_settings_menu = null
	settings_button.grab_focus()


func _on_resized() -> void:
	if not is_node_ready():
		return
	_layout_scene(false)
