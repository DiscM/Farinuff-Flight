extends Control
## One ordered, safe-boundary story or route decision. The run owns pause state.
signal resolved(node_id: StringName)
signal abandon_requested
var allow_abandon := false
var show_route_map := true
var heading := "THE RETURN SIGNAL"
var body := ""
var routes: Array[Resource] = []
var _resolved := false

func _ready() -> void:
	add_to_group("scalable_ui")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = preload("res://ui/themes/farinuff_frontend_theme.tres")
	var shade := ColorRect.new()
	shade.color = Color(0.005, 0.015, 0.04, 0.97)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 20)
	scroll.add_child(column)
	var title := Label.new()
	title.text = heading
	title.add_theme_font_size_override("font_size", 26)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	var map_line := Label.new()
	map_line.visible = show_route_map
	map_line.text = "FAR REACH  →  BROKEN PERIMETER  →  TEMPEST REACH  →  QUIET CORE"
	map_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(map_line)
	var copy := Label.new()
	copy.text = body
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_theme_font_size_override("font_size", 20)
	column.add_child(copy)
	var first: Button
	if not routes.is_empty():
		map_line.hide()
		var chart := preload("res://ui/expedition_chart.gd").new()
		chart.preview_mode = false
		for route in routes:
			chart.selectable_ids.append(StringName(route.id))
		first = Button.new()
		first.text = "CONFIRM ROUTE"
		first.custom_minimum_size.y = 48
		first.disabled = true
		var confirm := first
		chart.selection_changed.connect(func(node_id: StringName):
			confirm.disabled = not chart.selectable_ids.has(node_id)
			var dossier := ExpeditionManager.get_node_dossier(node_id)
			confirm.text = "FLY TO " + str(dossier.get("title", "NEXT SECTOR")).to_upper()
		)
		column.add_child(chart)
		first.pressed.connect(func(): _choose(chart.selected_id))
		column.add_child(first)
	if routes.is_empty():
		first = Button.new()
		first.text = "CONTINUE"
		first.custom_minimum_size.y = 48
		first.pressed.connect(_choose.bind(&""))
		column.add_child(first)
	if allow_abandon:
		var leave := Button.new()
		leave.text = "END RUN AND RETURN TO HANGAR"
		leave.custom_minimum_size.y = 44
		leave.pressed.connect(_confirm_abandon)
		column.add_child(leave)
	if first != null:
		first.grab_focus()

func _choose(node_id: StringName) -> void:
	if _resolved:
		return
	_resolved = true
	AudioManager.play_ui_click()
	resolved.emit(node_id)

func _unhandled_input(event: InputEvent) -> void:
	if routes.is_empty() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_choose(&"")


func _confirm_abandon() -> void:
	if _resolved:
		return
	var confirmation := ConfirmationDialog.new()
	confirmation.title = "End this Expedition?"
	confirmation.dialog_text = "Bank earned salvage and return to the Hangar. This run's ship build will end."
	confirmation.confirmed.connect(func():
		if _resolved:
			return
		_resolved = true
		abandon_requested.emit()
		confirmation.queue_free()
	)
	confirmation.canceled.connect(confirmation.queue_free)
	add_child(confirmation)
	confirmation.popup_centered()
