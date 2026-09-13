extends Control
class_name FrontendShell
## Page/modal navigation shell for the Farinuff front end.
##
## Owns the page registry, the exclusive modal stack, page transitions,
## device-aware footer prompts, and deterministic focus restoration. The shell
## is usable standalone: boot scenes and smoke tests instantiate
## frontend_shell.tscn directly and navigate through show_page/show_modal/back.

signal practice_requested(boss_wave: int)
signal expedition_requested
signal open_section(page_id: StringName)

## Production pages share the shell; a missing resource gets a recoverable error page.
const PAGE_REGISTRY: Dictionary = {
	&"command_deck": "res://ui/frontend/command_deck.tscn",
	&"expedition_map": "res://ui/frontend/expedition_map_screen.tscn",
	&"launch_bay": "res://ui/frontend/launch_bay_screen.tscn",
	&"hangar": "res://ui/frontend/hangar_screen.tscn",
	&"flight_school": "res://ui/frontend/flight_school_screen.tscn",
	&"settings": "res://ui/frontend/settings_screen.tscn",
	&"archives": "res://ui/frontend/archives_screen.tscn",
}
const PAGE_NAV_ORDER: Array[StringName] = [
	&"command_deck",
	&"hangar",
	&"settings",
	&"archives",
]
const PAGE_DISPLAY_NAMES: Dictionary = {
	&"command_deck": "Play",
	&"expedition_map": "Expedition Chart",
	&"launch_bay": "Launch Bay",
	&"hangar": "Hangar",
	&"flight_school": "Flight School",
	&"settings": "Settings",
	&"archives": "Archives",
}

## Signals a modal may emit to request its own dismissal. The shell connects
## these so any style of hosted modal (confirmation dialogs, popups) restores
## invoking focus when it returns.
const MODAL_CLOSE_SIGNALS: Array[StringName] = [
	&"closed", &"finished", &"confirmed", &"cancelled", &"done",
	&"dismissed", &"accepted", &"acknowledged",
]

## Root styles are authored in ui/themes/farinuff_frontend_theme.tres; these
## fallbacks cover parsing before that resource has landed.
const FALLBACK_CYAN := Color(0.17, 0.95, 1.0)
const FALLBACK_YELLOW := Color(1.0, 0.86, 0.26)
const FALLBACK_MUTED := Color(0.55, 0.63, 0.78)

const DEFAULT_OBJECTIVE := "Return the signal to the last charted relay"
const DEFAULT_DETAILS := "Select a page to see its context here."
const NAV_RAIL_WIDTH := 240.0
const NAV_RAIL_WIDTH_NARROW := 204.0
const NARROW_BREAKPOINT := 1040.0

## Keyboard / mouse / gamepad labels for the footer prompt bar, indexed as
## accept, back, details, tab.
const PROMPT_LABELS: Dictionary = {
	&"keyboard": ["ENTER  ACCEPT", "ESC  BACK", "F1  CONTEXT", "[ / ]  SECTIONS"],
	&"mouse": ["CLICK  ACCEPT", "ESC  BACK", "F1  CONTEXT", "NAVIGATION"],
	&"gamepad": ["A  ACCEPT", "B  BACK", "Y  DETAIL", "LB/RB  TABS"],
}

const NAV_MARKER_ACTIVE := Color(1.0, 0.86, 0.26, 1.0)
const NAV_MARKER_IDLE := Color(1.0, 1.0, 1.0, 0.12)

@onready var status_rail: PanelContainer = %StatusRail
@onready var salvage_value: Label = %SalvageValue
@onready var hull_value: Label = %HullValue
@onready var wave_value: Label = %WaveValue
@onready var objective_value: Label = %ObjectiveValue
@onready var top_tabs: PanelContainer = %TopTabs
@onready var vertical_nav: VBoxContainer = %NavList
@onready var horizontal_nav: HBoxContainer = %TabList
@onready var left_nav: PanelContainer = %LeftNav
@onready var content_canvas: Control = %ContentCanvas
@onready var drawer: PanelContainer = %ContextDrawer
@onready var drawer_body: Label = %DrawerBody
@onready var details_overlay: PanelContainer = %DetailsOverlay
@onready var details_overlay_body: Label = %OverlayBody
@onready var accept_prompt: Label = %AcceptPrompt
@onready var back_prompt: Label = %BackPrompt
@onready var details_prompt: Label = %DetailsPrompt
@onready var tab_prompt: Label = %TabPrompt
@onready var build_label: Label = %BuildLabel
@onready var modal_layer: Control = %ModalLayer

@export var initial_page: StringName = &"command_deck"
var initial_payload: Dictionary = {}
var _history: Array[Dictionary] = []
var _restore_focus_index := -1
var _navigation_locked := false
var _status_refresh_in := 0.0
var _details_invoker: Control
var _details_close: Button
var _current_page_id: StringName = &""
var _current_page: Control
var _current_payload: Dictionary = {}
var _active_modal: Node
var _modal_invoker: Control
var _modal_payload: Dictionary = {}
var _suspended_focus: Dictionary = {}
var _page_tween: Tween
var _reduced_flashing := false
var _last_device: StringName = &"keyboard"
var _nav_buttons: Dictionary = {}
var _nav_markers: Dictionary = {}
var _nav_tab_buttons: Dictionary = {}
var _nav_tab_markers: Dictionary = {}


func _ready() -> void:
	add_to_group("scalable_ui")
	resized.connect(_on_viewport_resized)
	_build_nav()
	_wrap_horizontal_nav()
	_prepare_context_panel()
	SaveManager.settings_changed.connect(_on_settings_changed)
	_footer_build_label()
	_last_device = _initial_device()
	_update_prompts()
	_reduced_flashing = _load_reduced_flashing_setting()
	call_deferred("_start_shell")


func _start_shell() -> void:
	_on_viewport_resized()
	show_page(initial_page, initial_payload)


# --- Public navigation surface -------------------------------------------------

## Switches the content canvas to the registered page, passes the payload to
## the page, and focuses its primary safe action. Unknown ids fail fast: the
## current page is left untouched and an error is pushed. A page change while
## a modal is open is refused because modals are exclusive.
func show_page(page_id: StringName, payload: Dictionary = {}, remember: bool = true) -> void:
	if _navigation_locked:
		return
	if has_open_modal():
		push_warning("FrontendShell: refusing page change while a modal is open")
		return
	if not PAGE_REGISTRY.has(page_id):
		push_error("FrontendShell: unknown page id '%s'" % page_id)
		return
	if _current_page_id == page_id and is_instance_valid(_current_page):
		_current_payload = payload.duplicate()
		if _current_page.has_method("setup_payload"):
			_current_page.setup_payload(payload)
		_update_drawer(payload)
		_refresh_status_rail()
		return
	if remember and is_instance_valid(_current_page):
		var controls := _current_page.find_children("*", "Control", true, false)
		_history.append({"page": _current_page_id, "payload": _current_payload.duplicate(), "focus": controls.find(get_viewport().gui_get_focus_owner())})
		if _history.size() > 24:
			_history.pop_front()
	_close_details()
	_remove_current_page()
	_current_page_id = page_id
	_current_payload = payload.duplicate()
	var page := _instantiate_page(page_id, payload)
	content_canvas.add_child(page)
	_fit_full_rect(page)
	_current_page = page
	_bind_hover_focus(page)
	_on_page_active(page)
	_refresh_nav()
	_refresh_status_rail()
	_update_drawer(payload)
	call_deferred("_focus_page_primary")


## Opens a modal on top of the current page. Modals are exclusive: a second
## show_modal while one is open is refused. Focus is moved to the modal's safe
## action and the page below is made non-focusable until the modal closes,
## after which the exact invoking control regains focus.
func show_modal(scene: PackedScene, payload: Dictionary = {}) -> void:
	if scene == null:
		push_error("FrontendShell: show_modal requires a PackedScene")
		return
	if has_open_modal():
		push_error("FrontendShell: a modal is already open; modals are exclusive")
		return
	_modal_invoker = get_viewport().gui_get_focus_owner()
	_suspend_page_focus()
	var modal := scene.instantiate()
	modal_layer.visible = true
	modal_layer.add_child(modal)
	_fit_full_rect(modal)
	_modal_payload = payload.duplicate()
	if modal.has_method("setup_payload"):
		modal.setup_payload(payload)
	_connect_modal_close_signals(modal)
	_bind_hover_focus(modal)
	_active_modal = modal
	call_deferred("_focus_modal_primary")


## Cancels one navigation level: closes a modal (restoring invoking focus)
## first; otherwise returns from a non-command page to the Command Deck.
## Returns false when there is nothing to cancel.
func back() -> bool:
	if _navigation_locked:
		return false
	MenuAudio.play(&"UI.NAV.CANCEL")
	if details_overlay.visible:
		_close_details()
		return true
	if has_open_modal():
		_close_modal()
		return true
	if not _history.is_empty():
		var previous: Dictionary = _history.pop_back()
		_restore_focus_index = int(previous.focus)
		show_page(previous.page, previous.payload, false)
		return true
	if _current_page_id != &"command_deck":
		show_page(&"command_deck", {}, false)
		return true
	return false


## Removes residual pulsing/glitching visuals and skips page transitions.
func set_reduced_flashing(enabled: bool) -> void:
	_reduced_flashing = enabled
	if enabled and is_instance_valid(_page_tween):
		_page_tween.kill()
		if is_instance_valid(_current_page):
			_current_page.modulate.a = 1.0
			_current_page.position.x = 0.0


# --- Introspection helpers (used by smoke tests and composition roots) --------

func get_current_page_id() -> StringName:
	return _current_page_id


func get_current_page() -> Control:
	return _current_page


func has_open_modal() -> bool:
	return is_instance_valid(_active_modal)


func get_open_modal() -> Node:
	return _active_modal


func get_nav_button(page_id: StringName) -> Button:
	return _nav_tab_buttons.get(page_id) as Button


func set_objective(text: String) -> void:
	_current_payload["objective_text"] = text
	_refresh_status_rail()


# --- Page instantiation and lifecycle -----------------------------------------

func _instantiate_page(page_id: StringName, payload: Dictionary) -> Control:
	var path := str(PAGE_REGISTRY[page_id])
	var page: Control = null
	if ResourceLoader.exists(path):
		var scene := load(path) as PackedScene
		if scene != null:
			page = scene.instantiate() as Control
	if page == null:
		return _make_placeholder_page(page_id)
	page.set_meta(&"frontend_page_id", page_id)
	_bind_page(page, payload)
	return page


func _bind_page(page: Control, payload: Dictionary) -> void:
	if page.has_method("setup_payload"):
		page.setup_payload(payload)
	if page.has_signal("expedition_requested"):
		page.connect("expedition_requested", _on_page_expedition_requested)
	if page.has_signal("practice_requested"):
		page.connect("practice_requested", _on_page_practice_requested)
	if page.has_signal("back_requested"):
		page.connect("back_requested", back)
	if page.has_signal("open_section"):
		page.connect("open_section", _on_page_open_section)
	_bind_hover_focus(page)


## Themed placeholder for pages that arrive in later milestones. Renders the
## page's title so navigation is testable end-to-end and keeps a focusable
## primary so opening it has a deterministic focus target.
func _make_placeholder_page(page_id: StringName) -> Control:
	var page := Control.new()
	page.set_meta(&"frontend_page_id", page_id)
	page.mouse_filter = Control.MOUSE_FILTER_PASS
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var kicker := Label.new()
	kicker.text = "SECTION"
	kicker.add_theme_font_size_override("font_size", 14)
	kicker.add_theme_color_override("font_color", themed_color(&"CYAN", FALLBACK_CYAN))
	box.add_child(kicker)
	var title := Label.new()
	title.text = str(PAGE_DISPLAY_NAMES[page_id]).to_upper()
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", themed_color(&"YELLOW", FALLBACK_YELLOW))
	title.focus_mode = Control.FOCUS_ALL
	title.focus_neighbor_left = get_nav_button(page_id).get_path() if get_nav_button(page_id) else NodePath("")
	title.add_theme_stylebox_override("focus", themed_stylebox(&"focus_frame", _placeholder_focus_outline()))
	title.tooltip_text = "%s could not be opened" % PAGE_DISPLAY_NAMES[page_id]
	box.add_child(title)
	var body := Label.new()
	body.text = "This section could not be opened. Use Back or choose another section."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", FALLBACK_MUTED)
	box.add_child(body)
	return page


func _remove_current_page() -> void:
	if is_instance_valid(_current_page):
		if is_instance_valid(_page_tween):
			_page_tween.kill()
		get_viewport().gui_release_focus()
		# queue_free, never free(): a page may be navigating away from inside
		# one of its own signal emissions, where an immediate free is illegal.
		_current_page.hide()
		_current_page.queue_free()
	_current_page = null


func _on_page_active(page: Control) -> void:
	if _reduced_flashing:
		return
	if is_instance_valid(_page_tween):
		_page_tween.kill()
	page.modulate.a = 0.0
	page.position.x = 18.0
	_page_tween = create_tween()
	_page_tween.set_trans(Tween.TRANS_CUBIC)
	_page_tween.set_ease(Tween.EASE_OUT)
	_page_tween.set_parallel(true)
	_page_tween.tween_property(page, "modulate:a", 1.0, 0.18)
	_page_tween.tween_property(page, "position:x", 0.0, 0.18)


func _on_page_expedition_requested() -> void:
	expedition_requested.emit()


func _on_page_open_section(page_id: StringName) -> void:
	open_section.emit(page_id)
	if PAGE_REGISTRY.has(page_id):
		if _current_page_id == &"flight_school" and bool(_current_payload.get("first_flight", false)):
			_history.clear()
			show_page(page_id, {}, false)
		else:
			show_page(page_id)


# --- Modal stack --------------------------------------------------------------

func _connect_modal_close_signals(modal: Node) -> void:
	for signal_def in modal.get_signal_list():
		var signal_name: StringName = signal_def.get("name", "")
		if signal_name in MODAL_CLOSE_SIGNALS:
			modal.connect(signal_name, Callable(self, "_on_modal_close_signal"))
			return


func _on_modal_close_signal() -> void:
	call_deferred("_close_modal")


func _close_modal() -> void:
	if not modal_layer.visible:
		return
	# A hosted modal may queue_free itself after emitting its return signal;
	# never double-free it, only drop the shell's reference and restore state.
	if is_instance_valid(_active_modal) and not _active_modal.is_queued_for_deletion():
		_active_modal.queue_free()
	_active_modal = null
	modal_layer.visible = false
	_modal_payload = {}
	_restore_page_focus()
	var invoker := _modal_invoker
	_modal_invoker = null
	if is_instance_valid(invoker) and not invoker.is_queued_for_deletion():
		call_deferred("_restore_invoker_focus", invoker)


func _restore_invoker_focus(invoker: Control) -> void:
	if is_instance_valid(invoker) and not invoker.is_queued_for_deletion():
		invoker.grab_focus()


func _suspend_page_focus() -> void:
	_suspended_focus.clear()
	if not is_instance_valid(_current_page):
		return
	_suspend_control_focus(_current_page)
	for control in _current_page.find_children("*", "Control", true, false):
		_suspend_control_focus(control)


func _suspend_control_focus(control: Control) -> void:
	if control.focus_mode != Control.FOCUS_NONE:
		_suspended_focus[control] = control.focus_mode
		control.focus_mode = Control.FOCUS_NONE


func _restore_page_focus() -> void:
	for control: Control in _suspended_focus:
		if is_instance_valid(control):
			control.focus_mode = _suspended_focus[control]
	_suspended_focus.clear()


func _focus_modal_primary() -> void:
	if not has_open_modal():
		return
	var primary := _resolve_primary_action(_active_modal)
	if primary is Control and not primary.is_queued_for_deletion():
		primary.grab_focus()


# --- Focus routing ------------------------------------------------------------

func _focus_page_primary() -> void:
	if not is_instance_valid(_current_page):
		return
	if _restore_focus_index >= 0:
		var controls := _current_page.find_children("*", "Control", true, false)
		var index := _restore_focus_index
		_restore_focus_index = -1
		if index < controls.size():
			var restored := controls[index] as Control
			if restored.is_visible_in_tree() and restored.focus_mode != Control.FOCUS_NONE and not (restored is BaseButton and restored.disabled):
				restored.grab_focus()
				return
	var primary := _resolve_primary_action(_current_page)
	if primary is Control:
		_wire_primary_neighbor(primary)
		primary.grab_focus()


## Order of preference: a declared primary safe action, then the cancel-safe
## action of a hosted confirmation dialog, then the first focusable Control.
func _resolve_primary_action(root: Node) -> Control:
	if root.has_method("get_primary_safe_action"):
		var direct := root.call("get_primary_safe_action") as Node
		if direct is Control:
			return direct
	if root.has_method("get_cancel_button"):
		var cancel := root.call("get_cancel_button") as Node
		if cancel is Control:
			return cancel
	for control in root.find_children("*", "Control", true, false):
		if control is BaseButton or control.focus_mode == Control.FOCUS_ALL:
			return control
	return null


## Hover may move focus only when the latest input device is a mouse; a
## stationary cursor must not steal focus from the keyboard or gamepad.
func _bind_hover_focus(root: Node) -> void:
	for control in root.find_children("*", "Control", true, false):
		if control is Button:
			if not control.focus_entered.is_connected(_play_navigation_tick):
				control.focus_entered.connect(_play_navigation_tick)
			if not control.mouse_entered.is_connected(_on_gated_mouse_entered):
				control.mouse_entered.connect(_on_gated_mouse_entered.bind(control))


func _on_gated_mouse_entered(control: Control) -> void:
	if _last_device == &"mouse":
		control.grab_focus()


func _wire_primary_neighbor(primary: Control) -> void:
	var active_button := get_nav_button(_current_page_id)
	if active_button is Control:
		primary.focus_neighbor_left = active_button.get_path()


# --- Navigation rail ----------------------------------------------------------

func _build_nav() -> void:
	for page_id in PAGE_NAV_ORDER:
		vertical_nav.add_child(_make_nav_entry(page_id, _nav_buttons, _nav_markers))
	for page_id in PAGE_NAV_ORDER:
		horizontal_nav.add_child(_make_nav_entry(page_id, _nav_tab_buttons, _nav_tab_markers))
	_wire_nav_neighbors()


func _make_nav_entry(
	page_id: StringName,
	buttons_store: Dictionary,
	markers_store: Dictionary
) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size.y = 44
	var marker := ColorRect.new()
	marker.custom_minimum_size = Vector2(5, 30)
	marker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(marker)
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(0, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.set_meta(&"frontend_page_id", page_id)
	button.set_meta(&"is_nav_button", true)
	button.tooltip_text = "Open the %s page" % PAGE_DISPLAY_NAMES[page_id]
	button.pressed.connect(_on_nav_pressed.bind(page_id))
	button.mouse_entered.connect(_on_gated_mouse_entered.bind(button))
	row.add_child(button)
	buttons_store[page_id] = button
	markers_store[page_id] = marker
	return row


func _wire_nav_neighbors() -> void:
	var count := PAGE_NAV_ORDER.size()
	for i in range(count):
		var button := _nav_buttons[PAGE_NAV_ORDER[i]] as Button
		var previous := _nav_buttons[PAGE_NAV_ORDER[(i - 1 + count) % count]] as Button
		var next := _nav_buttons[PAGE_NAV_ORDER[(i + 1) % count]] as Button
		button.focus_neighbor_top = previous.get_path()
		button.focus_neighbor_bottom = next.get_path()
	var last := _nav_buttons[PAGE_NAV_ORDER[count - 1]] as Button
	last.focus_neighbor_bottom = _nav_buttons[PAGE_NAV_ORDER[0]].get_path()


func _on_nav_pressed(page_id: StringName) -> void:
	show_page(page_id)


func _refresh_nav() -> void:
	var active_colour := themed_color(&"YELLOW", FALLBACK_YELLOW)
	var button_sets: Array[Dictionary] = [_nav_buttons, _nav_tab_buttons]
	var marker_sets: Array[Dictionary] = [_nav_markers, _nav_tab_markers]
	for page_id in PAGE_NAV_ORDER:
		var is_active := page_id == _current_page_id
		for i in range(button_sets.size()):
			var marker := marker_sets[i][page_id] as ColorRect
			var button := button_sets[i][page_id] as Button
			button.disabled = page_id == &"archives" and ExpeditionManager.get_recovered_fragments().is_empty()
			marker.color = NAV_MARKER_ACTIVE if is_active else NAV_MARKER_IDLE
			button.text = ("▸ " if is_active else "  ") + str(PAGE_DISPLAY_NAMES[page_id]).to_upper()
			button.add_theme_color_override(
				"font_color",
				active_colour if is_active else themed_color(&"WHITE", Color(0.9, 0.98, 1.0))
			)


func _cycle_page(direction: int) -> void:
	if has_open_modal():
		return
	var index := PAGE_NAV_ORDER.find(_current_page_id)
	if index < 0:
		index = 0
	for step in range(1, PAGE_NAV_ORDER.size() + 1):
		var next_index := posmod(index + direction * step, PAGE_NAV_ORDER.size())
		var page_id: StringName = PAGE_NAV_ORDER[next_index]
		if page_id != &"archives" or not ExpeditionManager.get_recovered_fragments().is_empty():
			show_page(page_id)
			return


# --- Status rail and context drawer -------------------------------------------

func _refresh_status_rail() -> void:
	var save_manager := get_node_or_null("/root/SaveManager")
	var salvage := int(save_manager.salvage) if save_manager != null else 0
	var hull_id := str(save_manager.selected_ship) if save_manager != null else "ship_swallowtail"
	var best_wave := int(save_manager.stat_best_wave) if save_manager != null else 0
	var objective := str(_current_payload.get("objective_text", DEFAULT_OBJECTIVE))
	salvage_value.text = "SALVAGE  ⬡ %d" % salvage
	hull_value.text = "HULL  %s" % _format_hull_name(hull_id)
	wave_value.text = "BEST WAVE  %d" % best_wave
	objective_value.text = "OBJECTIVE  %s" % objective


func _format_hull_name(hull_id: String) -> String:
	var known := {
		"ship_swallowtail": "Swallowtail",
		"ship_interceptor": "Interceptor",
		"ship_bulwark": "Bulwark",
	}
	return str(known.get(hull_id, hull_id.trim_prefix("ship_").replace("_", " ").to_upper()))


func _update_drawer(payload: Dictionary) -> void:
	var details := str(payload.get("details", ""))
	if details.strip_edges().is_empty():
		details = _page_context(_current_page_id)
	drawer_body.text = details
	details_overlay_body.text = details


# --- Input, devices, and prompts ----------------------------------------------

func _input(event: InputEvent) -> void:
	_update_last_device(event)

func _unhandled_input(event: InputEvent) -> void:
	if _navigation_locked or event.is_echo() or not get_tree().get_nodes_in_group("input_binding_modal").is_empty():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back()
		return
	if has_open_modal():
		return
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
			get_viewport().set_input_as_handled()
			_cycle_page(-1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else 1)
		elif event.button_index == JOY_BUTTON_Y:
			get_viewport().set_input_as_handled()
			_toggle_details()
	elif event is InputEventKey and event.pressed:
		if event.keycode in [KEY_BRACKETLEFT, KEY_BRACKETRIGHT]:
			get_viewport().set_input_as_handled()
			_cycle_page(-1 if event.keycode == KEY_BRACKETLEFT else 1)
		elif event.keycode == KEY_F1:
			get_viewport().set_input_as_handled()
			_toggle_details()


func _update_last_device(event: InputEvent) -> void:
	var device: StringName = &"keyboard"
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		device = &"mouse"
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		device = &"gamepad"
	if device != _last_device:
		_last_device = device
		_update_prompts()


func _initial_device() -> StringName:
	if DisplayServer.get_name() == "headless":
		return &"keyboard"
	return &"mouse" if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE else &"keyboard"


func _update_prompts() -> void:
	var labels: Array = PROMPT_LABELS.get(_last_device, PROMPT_LABELS[&"keyboard"])
	accept_prompt.text = labels[0]
	back_prompt.text = labels[1]
	details_prompt.text = labels[2]
	tab_prompt.text = labels[3]


func _footer_build_label() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", "0.5.0"))
	build_label.text = "BUILD %s  ·  SIGNAL LOCKED" % version


# --- Responsive layout (scaffold) ---------------------------------------------

func _on_viewport_resized() -> void:
	if not is_node_ready():
		return
	_close_details()
	var viewport_size := size
	if viewport_size.x <= 1.0:
		viewport_size = get_viewport_rect().size
	var width := viewport_size.x
	objective_value.visible = width >= 1100.0
	wave_value.visible = width >= 800.0
	build_label.visible = width >= 900.0
	tab_prompt.visible = width >= 740.0
	left_nav.hide()
	top_tabs.show()
	drawer.hide()
	details_overlay.hide()


# --- Shared style conveniences --------------------------------------------------

func themed_color(color_name: StringName, fallback: Color) -> Color:
	if has_theme_color(color_name, &"Colors"):
		return get_theme_color(color_name, &"Colors")
	return fallback


func themed_stylebox(stylebox_name: StringName, fallback: StyleBox) -> StyleBox:
	if has_theme_stylebox(stylebox_name, &"focus_frame"):
		return get_theme_stylebox(stylebox_name, &"focus_frame")
	return fallback


## Fallback 2px high-contrast focus outline for when the shared theme has not
## loaded; the theme's own Button/focus stylebox is used whenever it is present.
func _placeholder_focus_outline() -> StyleBoxFlat:
	var outline := StyleBoxFlat.new()
	outline.bg_color = Color(0, 0, 0, 0)
	outline.border_color = FALLBACK_CYAN
	outline.set_border_width_all(2)
	outline.set_corner_radius_all(4)
	return outline


func _load_reduced_flashing_setting() -> bool:
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager != null and save_manager.has_method("get_setting"):
		return bool(save_manager.call("get_setting", "reduced_flashing", false)) or bool(save_manager.call("get_setting", "reduced_motion", false))
	return false


func _fit_full_rect(control: Control) -> void:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.set_meta(&"frontend_presented", true)

func set_navigation_locked(locked: bool) -> void:
	_navigation_locked = locked
	if locked:
		get_viewport().gui_release_focus()

func _on_page_practice_requested(wave: int) -> void:
	practice_requested.emit(wave)

func _wrap_horizontal_nav() -> void:
	top_tabs.remove_child(horizontal_nav)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	top_tabs.add_child(scroll)
	scroll.add_child(horizontal_nav)

func _toggle_details() -> void:
	if drawer.visible:
		return
	if details_overlay.visible:
		_close_details()
		return
	_details_invoker = get_viewport().gui_get_focus_owner()
	_suspend_page_focus()
	details_overlay.show()
	_details_close.grab_focus()

func _on_settings_changed() -> void:
	set_reduced_flashing(_load_reduced_flashing_setting())

func _process(delta: float) -> void:
	_status_refresh_in -= delta
	if _status_refresh_in <= 0.0:
		_status_refresh_in = 0.25
		_refresh_status_rail()

func _page_context(page_id: StringName) -> String:
	return str({
		&"command_deck": "Follow the Return Signal through four sectors. Defeat Tempest Core at Wave 20, then return home or continue into Endless.",
		&"expedition_map": "Inspect a relay for its enemy mix and boss. A new Expedition always begins at Wave 1. Route choices happen between cleared sectors.",
		&"launch_bay": "Choose an owned hull and optional challenge modifiers. Armed supplies are consumed only when the run starts. Each hull changes handling and starting lives.",
		&"hangar": "Spend banked salvage on systems, hulls, blueprints, and field supplies. Blueprints expand future transformation choices; they do not equip an ability immediately.",
		&"flight_school": "Practice uses the real flight and projectile systems. It cannot spend supplies or award salvage. Encounter a boss in an Expedition to unlock its practice session.",
		&"settings": "Settings apply immediately and persist. Story frequency changes presentation only; fragments are still recovered with Story Off.",
		&"archives": "Read fragments recovered from cleared routes. Explore the other branch on another Expedition to recover the rest of the signal.",
	}.get(page_id, DEFAULT_DETAILS))


func return_to_command_deck() -> void:
	_history.clear()
	_restore_focus_index = -1
	show_page(&"command_deck", {}, false)


func _prepare_context_panel() -> void:
	details_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_details_close = Button.new()
	_details_close.text = "CLOSE CONTEXT"
	_details_close.custom_minimum_size.y = 44
	_details_close.pressed.connect(_close_details)
	details_overlay.get_node("OverlayBox").add_child(_details_close)

func _close_details() -> void:
	if not is_instance_valid(details_overlay) or not details_overlay.visible:
		return
	details_overlay.hide()
	_restore_page_focus()
	if is_instance_valid(_details_invoker) and _details_invoker.is_visible_in_tree():
		_details_invoker.grab_focus()
	_details_invoker = null


func _play_navigation_tick() -> void:
	MenuAudio.play(&"UI.NAV.MOVE")
