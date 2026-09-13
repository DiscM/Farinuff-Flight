extends Control
## Pause menu — shown when ESC is pressed during gameplay.
## Allows the player to resume, retry, or return to the main menu.

signal resumed

const DEV_MENU_SCENE := preload("res://ui/dev_menu.tscn")
const SETTINGS_MENU_SCENE := preload("res://ui/settings_menu.tscn")
const DOCK_TEXTURE := preload("res://assets/Game UI collection FREE version/PNG/Borders/Yellow/New folder/Group 4 copy.png")
const BUTTON_BLUE_TEXTURE := preload("res://assets/Game UI collection FREE version/PNG/Button with border/Blue/1x/Asset 8.png")
const BUTTON_YELLOW_TEXTURE := preload("res://assets/Game UI collection FREE version/PNG/Button with border/Yellow/1x/Asset 8.png")
const NATIVE_RUN_PATH := "res://scenes/native_3d_run.tscn"
const MAIN_MENU_PATH := "res://ui/main_menu.tscn"

var _settings_menu: Node = null
var _dev_panel: PanelContainer = null
var _dev_slot: VBoxContainer = null
var _transitioning := false
var _build_panel: Control
var _confirmation: Control

## Builds the UI layout and plays the fade-in animation. The scene's full-rect
## anchors fill the viewport. Runs in PROCESS_MODE_ALWAYS so it functions while
## the tree is paused.
func _ready() -> void:
	theme = preload("res://ui/themes/farinuff_frontend_theme.tres")
	add_to_group("scalable_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_animate_in()

## Handles the ESC key to resume gameplay and close the pause menu.
func _unhandled_input(event: InputEvent) -> void:
	if (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")) and not event.is_echo():
		if _transitioning or is_instance_valid(_settings_menu) or is_instance_valid(_build_panel) or is_instance_valid(_confirmation):
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

	var heading := NeonUI.make_label("PAUSED ///", 36, NeonUI.WHITE)
	heading.position = Vector2(22, 110)
	heading.size = Vector2(280, 54)
	dock.add_child(heading)

	var button_column := VBoxContainer.new()
	button_column.name = "MenuButtons"
	button_column.position = Vector2(22, 178)
	button_column.size = Vector2(260, 328)
	button_column.add_theme_constant_override("separation", 18)
	dock.add_child(button_column)

	button_column.add_child(_make_btn("ResumeWrap", "RESUME", NeonUI.YELLOW, _on_resume, true))
	button_column.add_child(_make_btn("RetryWrap", "RESTART RUN", NeonUI.CYAN, _on_retry))
	button_column.add_child(_make_btn("BuildWrap", "SHIP BUILD", NeonUI.CYAN, _on_build))
	button_column.add_child(_make_btn("SettingsWrap", "SETTINGS", NeonUI.CYAN, _on_settings))
	button_column.add_child(_make_btn("MenuWrap", "QUIT TO MENU", NeonUI.CYAN, _on_menu))
	var gameplay := get_tree().get_first_node_in_group(&"native_3d_gameplay")
	if OS.is_debug_build() and gameplay != null and gameplay.has_method(&"dev_spawn_archetype"):
		button_column.add_child(_make_btn("DevWrap", "DEV TOOLS", NeonUI.GREEN, _on_dev_tools))

	_dev_slot = VBoxContainer.new()
	_dev_slot.name = "DevSlot"
	_dev_slot.position = Vector2(270.0, 36.0)
	_dev_slot.size = Vector2(minf(vp_size.x - 300.0, 430.0), vp_size.y - 72.0)
	_dev_slot.visible = false
	_dev_slot.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_dev_slot)


## Helper: creates a centered, styled button with the given label text,
## color, callback, and width.
func _make_btn(control_name: String, label: String, accent: Color, callback: Callable, _hot: bool = false) -> Control:
	var button_wrapper := Control.new()
	button_wrapper.name = control_name
	button_wrapper.custom_minimum_size = Vector2(260, 48)


	var btn := NeonUI.make_button("Button", label, accent, Vector2(0, 0))
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.offset_left = 16
	btn.offset_top = 0
	btn.offset_right = -14
	btn.offset_bottom = 0
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


## Lazily mounts the debug-only command panel beside the pause dock.
func _on_dev_tools() -> void:
	if _transitioning or _dev_slot == null:
		return
	_dev_slot.visible = not _dev_slot.visible
	if not _dev_slot.visible or is_instance_valid(_dev_panel):
		return
	_dev_panel = DEV_MENU_SCENE.instantiate() as PanelContainer
	_dev_panel.force_close.connect(_on_resume)
	_dev_slot.add_child(_dev_panel)

## Unpauses the game and reuses the resident game scene for a fresh retry.
func _restart_confirmed() -> void:
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
	if current_scene.has_method("abandon_run"):
		current_scene.abandon_run()
	var run_scene := await ResourceCache.wait_for_scene(NATIVE_RUN_PATH)
	get_tree().paused = false
	if run_scene != null and get_tree().change_scene_to_packed(run_scene) == OK:
		return
	_transitioning = false
	get_tree().reload_current_scene()

## Unpauses the game and reuses the resident title scene.
func _menu_confirmed() -> void:
	if _transitioning:
		return
	_transitioning = true
	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.has_method("abandon_run"):
		current_scene.abandon_run()
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
	if bool(SaveManager.get_setting("reduced_motion", false)):
		return
	modulate.a = 0.0
	scale = Vector2(0.95, 0.95)
	pivot_offset = size / 2.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_build() -> void:
	if is_instance_valid(_build_panel):
		return
	var panel := preload("res://ui/sector_interlude.gd").new()
	_build_panel = panel
	panel.heading = "SHIP BUILD"
	panel.show_route_map = false
	var lines := PackedStringArray()
	for upgrade in GameManager.ALL_UPGRADES + GameManager.META_ELITE_UPGRADES:
		if GameManager.chosen_upgrade_ids.has(str(upgrade.id)):
			lines.append("%s · %s\n%s" % [upgrade.name, upgrade.get("role", "Utility"), upgrade.description])
	if lines.is_empty():
		lines.append("Your first transformation arrives after Wave 5.")
	lines.append("Allocated systems · Fire rate %d · Hull %d · Speed %d" % [GameManager.stat_fire_rate_level, GameManager.stat_health_level, GameManager.stat_speed_level])
	panel.body = "\n\n".join(lines)
	panel.resolved.connect(func(_route: StringName):
		panel.queue_free()
		get_node("LeftDock/MenuButtons/BuildWrap/Button").grab_focus()
	)
	add_child(panel)


func _on_retry() -> void:
	if GameManager.practice_mode:
		_restart_confirmed()
	else:
		_confirm_transition("Restart Expedition?", "Bank earned salvage and start again. Your current ship build will be lost.", _restart_confirmed)


func _on_menu() -> void:
	if GameManager.practice_mode:
		GameManager.return_to_flight_school = true
		_menu_confirmed()
	else:
		_confirm_transition("End Expedition?", "Bank earned salvage and return to the Hangar. This run cannot be resumed.", _menu_confirmed)


func _confirm_transition(heading: String, message: String, action: Callable) -> void:
	if _transitioning or is_instance_valid(_confirmation):
		return
	_confirmation = preload("res://ui/shared/run_confirmation.gd").new()
	_confirmation.title = heading
	_confirmation.dialog_text = message
	_confirmation.confirmed.connect(func():
		_confirmation.queue_free()
		action.call()
	)
	_confirmation.canceled.connect(func(): _confirmation.queue_free())
	add_child(_confirmation)
