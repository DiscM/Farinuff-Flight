extends Control
## Pause menu — shown when ESC is pressed during gameplay.
## Allows the player to resume, retry, or return to the main menu.

signal resumed

const SETTINGS_MENU_SCENE := preload("res://ui/settings_menu.tscn")
const DOCK_TEXTURE := preload("res://assets/Game UI collection FREE version/PNG/Borders/Yellow/New folder/Group 4 copy.png")
const BUTTON_BLUE_TEXTURE := preload("res://assets/Game UI collection FREE version/PNG/Button with border/Blue/1x/Asset 8.png")
const BUTTON_YELLOW_TEXTURE := preload("res://assets/Game UI collection FREE version/PNG/Button with border/Yellow/1x/Asset 8.png")
const NATIVE_RUN_PATH := "res://scenes/native_3d_run.tscn"
const MAIN_MENU_PATH := "res://ui/main_menu.tscn"

var _settings_menu: Node = null
var _transitioning := false

## Builds the UI layout and plays the fade-in animation. The scene's full-rect
## anchors fill the viewport. Runs in PROCESS_MODE_ALWAYS so it functions while
## the tree is paused.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_animate_in()

## Handles the ESC key to resume gameplay and close the pause menu.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		if _transitioning:
			return
		get_viewport().set_input_as_handled()
		resumed.emit()

## Constructs the full pause menu UI as a left-aligned dock matching the
## approved mockup, with every text run contained by a plaque or button.
func _build_ui() -> void:
	var vp_size := get_viewport_rect().size

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.02, 0.82)
	bg.position = Vector2.ZERO
	bg.size = vp_size
	add_child(bg)

	var dock := Control.new()
	dock.name = "LeftDock"
	dock.position = Vector2(18.0, maxf((vp_size.y - 660.0) * 0.5, 12.0))
	dock.size = Vector2(236.0, minf(660.0, vp_size.y - 24.0))
	add_child(dock)

	var frame := TextureRect.new()
	frame.name = "DockFrame"
	frame.texture = DOCK_TEXTURE
	frame.position = Vector2(-6.0, -18.0)
	frame.size = Vector2(250.0, dock.size.y + 36.0)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.modulate = Color(1, 1, 1, 0.9)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_child(frame)

	var button_column := VBoxContainer.new()
	button_column.name = "MenuButtons"
	button_column.position = Vector2(22, 178)
	button_column.size = Vector2(194, 328)
	button_column.add_theme_constant_override("separation", 18)
	dock.add_child(button_column)

	button_column.add_child(_make_btn("ResumeWrap", "RESUME", NeonUI.YELLOW, _on_resume, true))
	button_column.add_child(_make_btn("RetryWrap", "RESTART RUN", NeonUI.CYAN, _on_retry))
	button_column.add_child(_make_btn("SettingsWrap", "OPTIONS", NeonUI.CYAN, _on_settings))
	button_column.add_child(_make_btn("MenuWrap", "MAIN MENU", NeonUI.CYAN, _on_menu))
## Helper: creates a centered, styled button with the given label text,
## color, callback, and width.
func _make_btn(control_name: String, label: String, accent: Color, callback: Callable, hot: bool = false) -> Control:
	var button_wrapper := Control.new()
	button_wrapper.name = control_name
	button_wrapper.custom_minimum_size = Vector2(194, 48)

	var texture := TextureRect.new()
	texture.texture = BUTTON_YELLOW_TEXTURE if hot else BUTTON_BLUE_TEXTURE
	texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_SCALE
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button_wrapper.add_child(texture)

	var btn := NeonUI.make_button("Button", label, accent, Vector2(0, 0))
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.offset_left = 16
	btn.offset_top = 6
	btn.offset_right = -14
	btn.offset_bottom = -6
	btn.pressed.connect(callback)
	btn.pressed.connect(AudioManager.play_ui_click)
	button_wrapper.add_child(btn)
	return button_wrapper

# ── Actions ────────────────────────────────────────────────────────────────────

## Emits the resumed signal and frees the pause overlay.
func _on_resume() -> void:
	if _transitioning:
		return
	resumed.emit()
	get_parent().queue_free()

## Unpauses the game and reuses the resident game scene for a fresh retry.
func _on_retry() -> void:
	if _transitioning:
		return
	_transitioning = true
	var current_scene := get_tree().current_scene
	if current_scene == null or current_scene.scene_file_path != NATIVE_RUN_PATH:
		# Review scenes use this same pause menu. Preserve their reload contract
		# instead of redirecting every retry into the production run.
		get_tree().paused = false
		get_tree().reload_current_scene()
		return
	var run_scene := await ResourceCache.wait_for_scene(NATIVE_RUN_PATH)
	get_tree().paused = false
	if run_scene != null and get_tree().change_scene_to_packed(run_scene) == OK:
		return
	_transitioning = false
	get_tree().reload_current_scene()

## Unpauses the game and reuses the resident title scene.
func _on_menu() -> void:
	if _transitioning:
		return
	_transitioning = true
	var menu_scene := await ResourceCache.wait_for_scene(MAIN_MENU_PATH)
	get_tree().paused = false
	if menu_scene != null and get_tree().change_scene_to_packed(menu_scene) == OK:
		return
	_transitioning = false
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")

## Opens the settings menu as a modal child. Prevents duplicate instances.
func _on_settings() -> void:
	if is_instance_valid(_settings_menu):
		return
	_settings_menu = SETTINGS_MENU_SCENE.instantiate()
	_settings_menu.connect("closed", func(): _settings_menu = null)
	add_child(_settings_menu)

# ── Animation ──────────────────────────────────────────────────────────────────

## Plays a quick fade-in and scale-up entrance animation for the pause menu.
func _animate_in() -> void:
	modulate.a = 0.0
	scale = Vector2(0.95, 0.95)
	pivot_offset = size / 2.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
