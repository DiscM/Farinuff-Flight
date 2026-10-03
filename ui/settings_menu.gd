extends Control

## Modal settings panel backed by SaveManager persistence.

signal closed

const Briefing := preload("res://ui/shared/menu_briefing.gd")
const HostedLayout := preload("res://ui/shared/hosted_menu_layout.gd")
const WindowLayout := preload("res://systems/game_window_layout.gd")
var _hosted_layout: HostedLayout
var _controls_layer: CanvasLayer
var _controls_button: Button
var _controls_host: Node

## Sets up the settings panel as a process-always full-rect control and
## builds the UI contents.
func _ready() -> void:
	add_to_group("scalable_ui")
	theme = preload("res://ui/themes/farinuff_frontend_theme.tres")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

## Constructs the settings panel UI: dark overlay background, centered
## panel with volume slider, toggle switches for screen shake/CRT/distortion,
## a save-note label, and a close button.
func _build_ui() -> void:
	var panel := Briefing.make_surface(self, Color(0.2, 0.75, 1.0, 0.8), 12, 24, 0.9)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	column.add_child(title)
	Briefing.wrap_heading(title)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.custom_minimum_size.y = 160
	tabs.use_hidden_tabs_for_min_size = false
	column.add_child(tabs)
	var audio := _make_category(tabs, "Audio")
	var display := _make_category(tabs, "Display")
	var access := _make_category(tabs, "Access")
	var controls := _make_category(tabs, "Controls")
	tabs.tab_changed.connect(func(_index: int): MenuAudio.play(&"UI.NAV.MOVE"))

	_add_percentage_slider(audio, "Master Volume", "master_volume", 0.8, Vector2(260, 34), "", "", Vector2(0, 1), Color(0.8, 0.9, 1.0))
	_add_percentage_slider(audio, "Music Volume", "music_volume", 0.8, Vector2(260, 34), "", "", Vector2(0, 1), Color(0.8, 0.9, 1.0))
	_add_percentage_slider(audio, "Sound effects", "sfx_volume", 1.0, Vector2(0, 34), "SFXVolume", "Combat sounds, including boost, reflection, damage, and pickups.")
	_add_percentage_slider(audio, "Menu audio", "ui_volume", 0.8)
	var story := OptionButton.new()
	story.add_item("Story: Full", 0)
	story.add_item("Story: Short", 1)
	story.add_item("Story: Off", 2)
	story.select(clampi(int(SaveManager.get_setting("story_frequency", 0)), 0, 2))
	story.item_selected.connect(func(index: int): SaveManager.update_setting("story_frequency", index))
	access.add_child(story)
	display.add_child(_make_toggle("Screen shake", "screen_shake"))
	display.add_child(_make_toggle("Retro TV scanlines", "crt_effect"))
	display.add_child(_make_toggle("Screen distortion", "screen_distortion"))
	display.add_child(_make_toggle("Fullscreen", "fullscreen", false))
	display.add_child(_choice("GraphicsQuality", "Graphics quality", "graphics_quality", ["low", "medium", "high"], ["Low", "Medium", "High"]))
	display.add_child(_choice("FrameCap", "Frame limit", "frame_cap", [0, 30, 60, 120, 144, 240], ["Unlimited", "30 FPS", "60 FPS", "120 FPS", "144 FPS", "240 FPS"]))
	display.add_child(_make_toggle("VSync", "vsync"))
	var window_size := OptionButton.new()
	window_size.name = "WindowSize"
	window_size.accessibility_name = "Window size"
	for label: String in WindowLayout.PRESET_LABELS:
		window_size.add_item("Window size: " + label)
	window_size.select(WindowLayout.PRESET_IDS.find(WindowLayout.normalize_preset(SaveManager.get_setting("window_size"))))
	window_size.item_selected.connect(func(index: int): SaveManager.update_setting("window_size", WindowLayout.PRESET_IDS[index]))
	display.add_child(window_size)
	var window_note := Label.new()
	window_note.text = "Windowed mode only."
	window_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	window_note.add_theme_font_size_override("font_size", 14)
	display.add_child(window_note)
	access.add_child(_make_toggle("Reduce flashes", "reduced_flashing", false))
	access.add_child(_make_toggle("Reduce menu motion", "reduced_motion", false))
	access.add_child(_make_toggle("Hold to confirm ending a run", "hold_to_confirm", false))
	var text_size := OptionButton.new()
	for percent: int in [100, 115, 130]:
		text_size.add_item("Menu text size: %d%%" % percent)
	text_size.select(clampi(roundi((float(SaveManager.get_setting("menu_text_scale", 1.0)) - 1.0) / 0.15), 0, 2))
	text_size.item_selected.connect(func(index: int): SaveManager.update_setting("menu_text_scale", 1.0 + index * 0.15))
	access.add_child(text_size)
	access.add_child(_choice("HUDScale", "Combat HUD size", "hud_scale", [1.0, 1.15, 1.3], ["100%", "115%", "130%"]))
	controls.add_child(_make_toggle("Toggle fire on / off with each press", "toggle_fire", false))
	var fire_note := Label.new()
	fire_note.text = "After pausing, release Fire to re-arm."
	fire_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fire_note.add_theme_font_size_override("font_size", 14)
	controls.add_child(fire_note)
	_add_percentage_slider(controls, "Right stick aim deadzone", "aim_deadzone", 0.4, Vector2(0, 34), "", "Aim stick threshold. Increase to reduce drift.", Vector2(0.15, 0.6))
	_controls_button = Button.new()
	_controls_button.text = "CHANGE CONTROLS"
	_controls_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_controls_button.pressed.connect(_open_controls)
	controls.add_child(_controls_button)

	var note := Label.new()
	note.text = "Autosaved"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color(0.55, 0.65, 0.8))
	column.add_child(note)

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(180, 46)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.pressed.connect(_on_close_pressed)
	column.add_child(close_button)
	_hosted_layout = HostedLayout.new(panel, [close_button], tabs.get_tab_bar(), [tabs])
	tabs.get_tab_bar().grab_focus()

## Helper: creates a CheckButton toggle with a label, initialized from
## the persisted setting value (using the given fallback when the key has
## never been saved). Connects its toggled signal to persist changes via
## SaveManager.
func _make_toggle(label_text: String, setting_key: String, fallback: bool = true) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.name = setting_key
	toggle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toggle.text = label_text
	toggle.button_pressed = bool(SaveManager.get_setting(setting_key, fallback))
	toggle.add_theme_font_size_override("font_size", 17)
	toggle.toggled.connect(_on_toggle_changed.bind(setting_key))
	return toggle

## All percentage sliders persist and refresh their own label through one path.
func _add_percentage_slider(parent: Control, title: String, key: String, fallback: float, minimum_size: Vector2 = Vector2(0, 34), node_name: String = "", tooltip: String = "", limits: Vector2 = Vector2(0, 1), color: Color = Color.TRANSPARENT) -> void:
	var label := Label.new()
	if color != Color.TRANSPARENT:
		label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	var slider := HSlider.new()
	slider.name = key if node_name.is_empty() else node_name
	slider.accessibility_name = title
	slider.tooltip_text = tooltip
	slider.min_value = limits.x
	slider.max_value = limits.y
	slider.step = 0.05
	slider.value = float(SaveManager.get_setting(key, fallback))
	slider.custom_minimum_size = minimum_size
	label.text = "%s: %d%%" % [title, roundi(slider.value * 100)]
	slider.value_changed.connect(func(value: float):
		SaveManager.update_setting(key, value)
		label.text = "%s: %d%%" % [title, roundi(value * 100)]
	)
	parent.add_child(slider)

## Called when any toggle switch changes. Persists the new boolean value
## under the given setting key via SaveManager.
func _on_toggle_changed(enabled: bool, setting_key: String) -> void:
	AudioManager.play_ui_click()
	SaveManager.update_setting(setting_key, enabled)

## Emits the closed signal and frees this settings panel.
func _on_close_pressed() -> void:
	AudioManager.play_ui_click()
	closed.emit()
	queue_free()

## Handles ESC key to close the settings panel.
func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_controls_layer):
		return
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_on_close_pressed()


func _open_controls() -> void:
	if is_instance_valid(_controls_layer):
		return
	_controls_layer = CanvasLayer.new()
	_controls_layer.layer = 90
	_controls_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_controls_layer)
	var controls := preload("res://ui/controls_menu.gd").new()
	_controls_host = preload("res://ui/shared/modal_host.gd").new()
	_controls_layer.add_child(_controls_host)
	_controls_host.dismissed.connect(func(_modal: Control):
		_controls_layer.queue_free()
		_controls_layer = null
	)
	_controls_host.present(controls, _controls_button)


func _make_category(tabs: TabContainer, category_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = category_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	tabs.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 14)
	scroll.add_child(contents)
	return contents


func _choice(node_name: String, title: String, key: String, values: Array, labels: Array) -> OptionButton:
	var choice := OptionButton.new()
	choice.name = node_name
	choice.accessibility_name = title
	for label: String in labels:
		choice.add_item(title + ": " + label)
	choice.select(maxi(values.find(SaveManager.get_setting(key)), 0))
	choice.item_selected.connect(func(index: int): SaveManager.update_setting(key, values[index]))
	return choice


func get_hosted_layout() -> HostedLayout:
	return _hosted_layout
