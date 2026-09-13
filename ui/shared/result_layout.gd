extends RefCounted
## Keeps run decisions visible while a long build/economy summary scrolls.
static func mount(host: Control, body: VBoxContainer, actions: Array[Control]) -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(minf(700.0, host.get_viewport_rect().size.x - 40.0), maxf(320.0, host.get_viewport_rect().size.y - 40.0))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	layout.add_child(scroll)
	body.reparent(scroll)
	body.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	body.custom_minimum_size = Vector2.ZERO
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for action: Control in actions:
		action.reparent(layout)
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if action is Button:
			action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for child: Node in body.get_children():
		if child is Label:
			child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not actions.is_empty():
		actions[0].grab_focus()
