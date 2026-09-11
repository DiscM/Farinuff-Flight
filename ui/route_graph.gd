extends Control
## A responsive, navigable relay diagram. Selecting a node never advances a run.
signal node_selected(node_id: StringName)
var preview_mode := true
var selectable_ids: Array[StringName] = []
var selected_id: StringName = &""
var _nodes: Array[Resource] = []
var _buttons: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_nodes = ExpeditionManager.get_chart_nodes()
	var snapshot := ExpeditionManager.get_snapshot()
	for node in _nodes:
		var button := Button.new()
		var marker := "CLEARED" if snapshot.cleared_node_ids.has(node.id) and not preview_mode else "CHARTED" if snapshot.discovered_node_ids.has(node.id) else "UNCHARTED"
		button.text = "%s\n%d–%d · %s" % [node.display_name, node.first_wave, node.last_wave, marker]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 13)
		button.disabled = not preview_mode and not selectable_ids.has(node.id)
		button.tooltip_text = ExpeditionManager.get_route_description(node)
		button.pressed.connect(_select.bind(StringName(node.id)))
		button.pressed.connect(AudioManager.play_ui_click)
		button.focus_entered.connect(_select.bind(StringName(node.id)))
		add_child(button)
		_buttons[node.id] = button
	resized.connect(_layout_nodes)
	_layout_nodes()
	var primary := get_primary_safe_action()
	if primary != null:
		for node_id: StringName in _buttons:
			if _buttons[node_id] == primary:
				_select(node_id)
				break

func _layout_nodes() -> void:
	var columns := 4 if size.x >= 620.0 else 2
	var cell_width := size.x / float(columns)
	custom_minimum_size.y = 230.0 if columns == 4 else 450.0
	for node in _nodes:
		var sector := int(node.sector_index) - 1
		var column := sector % columns
		var row := floori(float(sector) / float(columns))
		var branch := -46.0 if node.map_position.y < 0.45 else 46.0 if node.map_position.y > 0.55 else 0.0
		var button: Button = _buttons[node.id]
		button.position = Vector2(column * cell_width + 8.0, row * 220.0 + 68.0 + branch)
		button.size = Vector2(maxf(cell_width - 16.0, 90.0), 78.0)
	queue_redraw()

func _draw() -> void:
	for node in _nodes:
		if not _buttons.has(node.id):
			continue
		var origin: Button = _buttons[node.id]
		for next_id in node.outgoing_node_ids:
			if not _buttons.has(next_id):
				continue
			var destination: Button = _buttons[next_id]
			var color := Color(0.20, 0.42, 0.52, 0.65)
			if node.id == selected_id or next_id == selected_id:
				color = Color(0.2, 0.95, 1.0, 0.95)
			draw_line(origin.position + origin.size * 0.5, destination.position + destination.size * 0.5, color, 2.0, true)
	if _buttons.has(selected_id):
		var selected: Button = _buttons[selected_id]
		draw_rect(Rect2(selected.position - Vector2(3, 3), selected.size + Vector2(6, 6)), Color(1.0, 0.85, 0.25), false, 2.0)

func _select(node_id: StringName) -> void:
	if not _buttons.has(node_id) or _buttons[node_id].disabled:
		return
	selected_id = node_id
	queue_redraw()
	node_selected.emit(node_id)

func get_primary_safe_action() -> Button:
	for node in _nodes:
		var button: Button = _buttons.get(node.id)
		if button != null and not button.disabled:
			return button
	return null
