extends Control
## Main Menu — title screen with Play button.

const SETTINGS_MENU_SCENE := preload("res://ui/settings_menu.tscn")
const NeonUI := preload("res://ui/neon_ui.gd")

var _settings_menu: Node = null

## Ensures the mouse cursor is visible and connects the Play and Settings
## buttons to their handlers.
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_apply_mockup_style()
	$LeftDock/MenuButtons/PlayWrap/PlayButton.pressed.connect(_on_play_pressed)
	$LeftDock/MenuButtons/SettingsWrap/SettingsButton.pressed.connect(_on_settings_pressed)

## Applies the approved neon-panel style while keeping all text inside
## explicit plaques so scaling changes do not create overlaps.
func _apply_mockup_style() -> void:
	$LeftDock/TitlePlaque.add_theme_stylebox_override("panel", NeonUI.plaque(NeonUI.CYAN, Color(0.02, 0.06, 0.14, 0.96), 10, 2))
	$LeftDock/SubtitlePlaque.add_theme_stylebox_override("panel", NeonUI.plaque(NeonUI.YELLOW, Color(0.03, 0.06, 0.12, 0.94), 8, 2))
	$LeftDock/ControlsPlaque.add_theme_stylebox_override("panel", NeonUI.plaque(NeonUI.GREEN, Color(0.01, 0.06, 0.08, 0.94), 8, 2))

	var play_button := $LeftDock/MenuButtons/PlayWrap/PlayButton as Button
	play_button.add_theme_stylebox_override("normal", NeonUI.button_style(NeonUI.YELLOW))
	play_button.add_theme_stylebox_override("hover", NeonUI.button_style(NeonUI.YELLOW, Color(0.05, 0.12, 0.18, 0.95)))
	play_button.add_theme_stylebox_override("pressed", NeonUI.button_style(NeonUI.YELLOW, Color(0.08, 0.12, 0.1, 1.0)))
	play_button.add_theme_color_override("font_color", NeonUI.WHITE)
	play_button.add_theme_color_override("font_hover_color", NeonUI.YELLOW)
	play_button.add_theme_font_size_override("font_size", 16)

	var settings_button := $LeftDock/MenuButtons/SettingsWrap/SettingsButton as Button
	settings_button.add_theme_stylebox_override("normal", NeonUI.button_style(NeonUI.CYAN))
	settings_button.add_theme_stylebox_override("hover", NeonUI.button_style(NeonUI.CYAN, Color(0.03, 0.1, 0.18, 0.95)))
	settings_button.add_theme_stylebox_override("pressed", NeonUI.button_style(NeonUI.CYAN, Color(0.04, 0.12, 0.2, 1.0)))
	settings_button.add_theme_color_override("font_color", NeonUI.WHITE)
	settings_button.add_theme_color_override("font_hover_color", NeonUI.CYAN)
	settings_button.add_theme_font_size_override("font_size", 16)

## Transitions to the game scene to start a new run.
func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")

## Opens the settings menu as a modal overlay. Prevents opening multiple
## instances by checking for an existing one.
func _on_settings_pressed() -> void:
	if is_instance_valid(_settings_menu):
		return
	_settings_menu = SETTINGS_MENU_SCENE.instantiate()
	_settings_menu.connect("closed", func(): _settings_menu = null)
	add_child(_settings_menu)
