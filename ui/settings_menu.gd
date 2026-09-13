extends Control
## Modal settings panel backed by SaveManager persistence.

signal closed

var volume_label: Label
var music_label: Label
var _controls_layer: CanvasLayer
var _controls_button: Button

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
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.06, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -minf(340.0, get_viewport_rect().size.x * 0.5 - 20.0)
	panel.offset_top = -minf(285.0, get_viewport_rect().size.y * 0.5 - 20.0)
	panel.offset_right = minf(340.0, get_viewport_rect().size.x * 0.5 - 20.0)
	panel.offset_bottom = minf(285.0, get_viewport_rect().size.y * 0.5 - 20.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.15)
	style.border_color = Color(0.2, 0.75, 1.0, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

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
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.custom_minimum_size.y = minf(340.0, maxf(160.0, get_viewport_rect().size.y - 260.0))
	tabs.use_hidden_tabs_for_min_size = false
	column.add_child(tabs)
	var audio := _make_category(tabs, "Audio")
	var display := _make_category(tabs, "Display")
	var access := _make_category(tabs, "Access")
	var controls := _make_category(tabs, "Controls")
	tabs.tab_changed.connect(func(_index: int): MenuAudio.play(&"UI.NAV.MOVE"))

	volume_label = Label.new()
	volume_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	audio.add_child(volume_label)

	var volume := HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = float(SaveManager.get_setting("master_volume", 0.8))
	volume.custom_minimum_size = Vector2(260, 34)
	volume.value_changed.connect(_on_volume_changed)
	audio.add_child(volume)
	_refresh_volume_label(volume.value)

	music_label = Label.new()
	music_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	audio.add_child(music_label)

	var music := HSlider.new()
	music.min_value = 0.0
	music.max_value = 1.0
	music.step = 0.05
	music.value = float(SaveManager.get_setting("music_volume", 0.8))
	music.custom_minimum_size = Vector2(260, 34)
	music.value_changed.connect(_on_music_changed)
	audio.add_child(music)
	_refresh_music_label(music.value)

	var ui_label := Label.new()
	ui_label.text = "Menu audio: %d%%" % roundi(float(SaveManager.get_setting("ui_volume", 0.8)) * 100)
	audio.add_child(ui_label)
	var ui_volume := HSlider.new()
	ui_volume.min_value = 0.0
	ui_volume.max_value = 1.0
	ui_volume.step = 0.05
	ui_volume.value = float(SaveManager.get_setting("ui_volume", 0.8))
	ui_volume.custom_minimum_size.y = 34
	ui_volume.value_changed.connect(func(value: float):
		SaveManager.update_setting("ui_volume", value)
		ui_label.text = "Menu audio: %d%%" % roundi(value * 100)
	)
	audio.add_child(ui_volume)
	var story := OptionButton.new()
	story.add_item("Story: full", 0)
	story.add_item("Story: brief", 1)
	story.add_item("Story: off", 2)
	story.select(clampi(int(SaveManager.get_setting("story_frequency", 0)), 0, 2))
	story.item_selected.connect(func(index: int): SaveManager.update_setting("story_frequency", index))
	access.add_child(story)
	display.add_child(_make_toggle("Screen shake", "screen_shake"))
	display.add_child(_make_toggle("CRT scanline effect", "crt_effect"))
	display.add_child(_make_toggle("Screen distortion", "screen_distortion"))
	display.add_child(_make_toggle("Fullscreen", "fullscreen", false))
	access.add_child(_make_toggle("Reduced flashing effects", "reduced_flashing", false))
	access.add_child(_make_toggle("Reduced menu motion", "reduced_motion", false))
	access.add_child(_make_toggle("Hold to confirm ending a run", "hold_to_confirm", false))
	var text_size := OptionButton.new()
	for percent: int in [100, 115, 130]:
		text_size.add_item("Menu text size: %d%%" % percent)
	text_size.select(clampi(roundi((float(SaveManager.get_setting("menu_text_scale", 1.0)) - 1.0) / 0.15), 0, 2))
	text_size.item_selected.connect(func(index: int): SaveManager.update_setting("menu_text_scale", 1.0 + index * 0.15))
	access.add_child(text_size)
	var deadzone_label := Label.new()
	deadzone_label.text = "Right stick aim deadzone: %d%%" % roundi(float(SaveManager.get_setting("aim_deadzone", 0.4)) * 100)
	controls.add_child(deadzone_label)
	var deadzone := HSlider.new()
	deadzone.min_value = 0.15
	deadzone.max_value = 0.6
	deadzone.step = 0.05
	deadzone.value = float(SaveManager.get_setting("aim_deadzone", 0.4))
	deadzone.custom_minimum_size.y = 34
	deadzone.value_changed.connect(func(value: float):
		SaveManager.update_setting("aim_deadzone", value)
		deadzone_label.text = "Right stick aim deadzone: %d%%" % roundi(value * 100)
	)
	controls.add_child(deadzone)
	_controls_button = Button.new()
	_controls_button.text = "CUSTOMIZE FLIGHT CONTROLS"
	_controls_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_controls_button.pressed.connect(_open_controls)
	controls.add_child(_controls_button)

	var note := Label.new()
	note.text = "Preferences and high score are saved automatically."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color(0.55, 0.65, 0.8))
	column.add_child(note)

	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(180, 46)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.pressed.connect(_on_close_pressed)
	column.add_child(close_button)
	tabs.get_tab_bar().grab_focus()

## Helper: creates a CheckButton toggle with a label, initialized from
## the persisted setting value (using the given fallback when the key has
## never been saved). Connects its toggled signal to persist changes via
## SaveManager.
func _make_toggle(label_text: String, setting_key: String, fallback: bool = true) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = label_text
	toggle.button_pressed = bool(SaveManager.get_setting(setting_key, fallback))
	toggle.add_theme_font_size_override("font_size", 17)
	toggle.toggled.connect(_on_toggle_changed.bind(setting_key))
	return toggle

## Called when the volume slider value changes. Persists the new value
## via SaveManager and refreshes the percentage label.
func _on_volume_changed(value: float) -> void:
	SaveManager.update_setting("master_volume", value)
	_refresh_volume_label(value)

## Updates the volume label to display the current percentage (0–100%).
func _refresh_volume_label(value: float) -> void:
	volume_label.text = "Master Volume: %d%%" % int(round(value * 100.0))

## Called when the music slider value changes. Persists the new value
## via SaveManager and refreshes the percentage label.
func _on_music_changed(value: float) -> void:
	SaveManager.update_setting("music_volume", value)
	_refresh_music_label(value)

## Updates the music label to display the current percentage (0–100%).
func _refresh_music_label(value: float) -> void:
	music_label.text = "Music Volume: %d%%" % int(round(value * 100.0))

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
	controls.closed.connect(func():
		_controls_layer.queue_free()
		_controls_layer = null
		_controls_button.grab_focus()
	)
	_controls_layer.add_child(controls)


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
