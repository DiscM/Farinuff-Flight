extends Control
## Hosts mature game menus inside the command deck without duplicating their rules.
signal expedition_requested
signal practice_requested(boss_wave: int)
signal back_requested
signal open_section(page_id: StringName)
@export_enum("launch_bay", "hangar", "flight_school", "settings") var menu_kind := "launch_bay"
const MENUS := {
	"launch_bay": preload("res://ui/launch_bay.tscn"),
	"hangar": preload("res://ui/hangar_menu.tscn"),
	"flight_school": preload("res://ui/flight_school.tscn"),
	"settings": preload("res://ui/settings_menu.tscn"),
}
var _menu: Control
var _payload: Dictionary = {}
var _leaving := false

func setup_payload(payload: Dictionary) -> void:
	_payload = payload.duplicate()

func _ready() -> void:
	_menu = MENUS[menu_kind].instantiate() as Control
	_menu.name = "MenuContent"
	if _menu.has_signal("closed"):
		_menu.connect("closed", _back)
	if _menu.has_signal("finished"):
		_menu.connect("finished", _lesson_finished)
	if _menu.has_signal("launch_confirmed"):
		_menu.connect("launch_confirmed", _launch)
	if _menu.has_signal("practice_requested"):
		_menu.connect("practice_requested", _practice)
	add_child(_menu)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_embed_panel()
	var primary := get_primary_safe_action()
	if primary != null:
		primary.grab_focus()

func _embed_panel() -> void:
	# Move the authored menu panel into a scrolling page. Its inner controls,
	# callbacks, selection state, and wallet subscriptions stay on the same root.
	var panels := _menu.find_children("*", "PanelContainer", true, false)
	if panels.is_empty():
		return
	var panel := panels[0] as PanelContainer
	for child in _menu.get_children():
		if child is Control:
			child.hide()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	_menu.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2.ZERO
	panel.reparent(scroll)
	panel.show()
	if menu_kind == "launch_bay":
		# Keep the launch and back decisions visible while loadout details scroll.
		var action := _menu.get_primary_safe_action() as Button
		if action != null:
			action.get_parent().reparent(layout)
	NeonUI.style_screen(_menu)

func _back() -> void:
	if _leaving:
		return
	_leaving = true
	back_requested.emit()

func _lesson_finished() -> void:
	if _leaving:
		return
	_leaving = true
	if bool(_payload.get("first_flight", false)):
		open_section.emit(&"expedition_map")
	else:
		back_requested.emit()

func _launch() -> void:
	if _leaving:
		return
	_leaving = true
	_menu.set_process_unhandled_input(false)
	expedition_requested.emit()

func _practice(wave: int) -> void:
	if _leaving:
		return
	_leaving = true
	_menu.set_process_unhandled_input(false)
	practice_requested.emit(wave)

func get_primary_safe_action() -> Control:
	if not is_instance_valid(_menu):
		return null
	if _menu.has_method("get_primary_safe_action"):
		return _menu.get_primary_safe_action()
	for control in _menu.find_children("*", "Control", true, false):
		if control is BaseButton and control.is_visible_in_tree() and not control.disabled:
			return control
	return null
