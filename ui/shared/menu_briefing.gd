extends RefCounted
## Shared briefing treatment; screens retain ownership of their data and actions.

static func frame() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.035, 0.075, 0.96)
	style.border_color = Color(0.17, 0.95, 1.0, 0.45)
	style.set_border_width_all(1)
	style.border_width_top = 3
	style.set_content_margin_all(20)
	return style

static func wrap_heading(title: Label) -> PanelContainer:
	var parent := title.get_parent()
	var index := title.get_index()
	var panel := PanelContainer.new()
	panel.name = "BriefingHeader"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", frame())
	parent.add_child(panel)
	parent.move_child(panel, index)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	title.reparent(column)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.clip_text = false
	title.add_theme_font_override("font", NeonUI.DATA_FONT)
	title.add_theme_color_override("font_color", NeonUI.WHITE)
	title.add_theme_constant_override("outline_size", 0)
	return panel

static func enable_scroll(scroll: ScrollContainer, description: String) -> void:
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_ALL
	scroll.get_v_scroll_bar().accessibility_name = description

static func fit_panel(panel: PanelContainer, body: VBoxContainer, actions: Array[Control]) -> void:
	var viewport := panel.get_viewport_rect().size
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = maxf(24, (viewport.x - 920) * 0.5)
	panel.offset_right = -panel.offset_left
	panel.offset_top = 24
	panel.offset_bottom = -24
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	panel.add_child(layout)
	var scroll := ScrollContainer.new()
	enable_scroll(scroll, "Scroll menu briefing")
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	body.reparent(scroll)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for action in actions:
		action.reparent(layout)
