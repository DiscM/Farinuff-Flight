extends RefCounted
## Explicit embedding contract authored by each menu. Content scrolls while
## decision controls remain reachable; menu callbacks and state keep their owner.

var _panel: PanelContainer
var _actions: Array[Control]
var _primary: Control
var _compact: Array[Control]


func _init(panel: PanelContainer, actions: Array[Control], primary: Control, compact: Array[Control] = []) -> void:
	_panel = panel
	_actions = actions
	_primary = primary
	_compact = compact


func get_primary_safe_action() -> Control:
	return _primary


func mount(menu: Control) -> void:
	for child in menu.get_children():
		if child is Control:
			child.hide()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	menu.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.custom_minimum_size = Vector2.ZERO
	_panel.reparent(scroll)
	_panel.show()
	for action in _actions:
		action.reparent(column)
	for control in _compact:
		control.custom_minimum_size.y = 160
	NeonUI.style_screen(menu)
