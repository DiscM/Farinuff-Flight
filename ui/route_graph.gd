extends Control
## A responsive, navigable relay diagram. Selecting a node never advances a run.
signal node_selected(node_id: StringName)
var preview_mode := true
var selectable_ids: Array[StringName] = []
var selected_id: StringName = &""
var _nodes: Array[Resource] = []
var _buttons: Dictionary = {}
var _states: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_nodes = ExpeditionManager.get_chart_nodes()
	var snapshot := ExpeditionManager.get_snapshot()
	for node in _nodes:
		var button := Button.new()
		var reachable: bool = node.id == &"far_reach" if preview_mode else selectable_ids.has(node.id)
		var known: bool = reachable or snapshot.discovered_node_ids.has(node.id)
		var cleared := snapshot.cleared_node_ids.has(node.id) and not preview_mode
		var marker := "✓ CLEARED" if cleared else "◇ REACHABLE" if reachable else "◈ DISCOVERED" if known else "▣ LOCKED"
		_states[node.id] = "cleared" if cleared else "reachable" if reachable else "discovered" if known else "locked"
		button.text = "%s\n%d–%d · %s" % [node.display_name if known else "UNKNOWN RELAY", node.first_wave, node.last_wave, marker]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 13)
		button.disabled = not known
		button.tooltip_text = ExpeditionManager.get_route_description(node) if known else "Clear the preceding sector to recover this coordinate."
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color(0, 0, 0, 0)
		focus.border_color = Color.WHITE
		focus.set_border_width_all(3)
		button.add_theme_stylebox_override("focus", focus)
		if snapshot.recovered_fragment_ids.has(node.fragment_beat_id) and not snapshot.seen_story_beat_ids.has(node.fragment_beat_id):
			button.text += " · NEW SIGNAL"
		button.pressed.connect(_select.bind(StringName(node.id)))
		button.pressed.connect(func(): MenuAudio.play(&"MAP.ROUTE.SELECT"))
		button.focus_entered.connect(func(): MenuAudio.play(&"UI.NAV.MOVE"))
		add_child(button)
		_buttons[node.id] = button
	resized.connect(_layout_nodes)
	SaveManager.settings_changed.connect(_layout_nodes)
	_layout_nodes()
	var primary := get_primary_safe_action()
	if primary != null:
		for node_id: StringName in _buttons:
			if _buttons[node_id] == primary:
				_select(node_id)
				break

func _layout_nodes() -> void:
	var text_scale := clampf(float(SaveManager.get_setting("menu_text_scale", 1.0)), 1.0, 1.3)
	var columns := 4 if size.x >= 720.0 * text_scale else 2
	var row_height := 250.0 * text_scale
	var cell_width := size.x / float(columns)
	custom_minimum_size.y = row_height if columns == 4 else row_height * 2.0
	for node in _nodes:
		var sector := int(node.sector_index) - 1
		var column := sector % columns
		var row := floori(float(sector) / float(columns))
		var branch := (-55.0 if node.map_position.y < 0.45 else 55.0 if node.map_position.y > 0.55 else 0.0) * text_scale
		var button: Button = _buttons[node.id]
		button.position = Vector2(column * cell_width + 8.0, row * row_height + 75.0 * text_scale + branch)
		button.size = Vector2(maxf(cell_width - 16.0, 90.0), 94.0 * text_scale)
	_wire_directional_focus()
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
			if _states.get(node.id) == "cleared" and _states.get(next_id) == "cleared":
				color = Color(0.35, 1.0, 0.55)
			elif _states.get(next_id) == "reachable":
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
		if button != null and not button.disabled and _states.get(node.id) == "reachable":
			return button
	return null


func _wire_directional_focus() -> void:
	var directions := {"focus_neighbor_left": Vector2.LEFT, "focus_neighbor_right": Vector2.RIGHT, "focus_neighbor_top": Vector2.UP, "focus_neighbor_bottom": Vector2.DOWN}
	for source: Button in _buttons.values():
		if source.disabled:
			continue
		for property: String in directions:
			var best: Button = null
			var best_cost := INF
			var direction: Vector2 = directions[property]
			for candidate: Button in _buttons.values():
				if candidate == source or candidate.disabled:
					continue
				var displacement := candidate.position + candidate.size * 0.5 - source.position - source.size * 0.5
				var forward := displacement.dot(direction)
				if forward <= 1.0:
					continue
				var cost := forward + absf(displacement.dot(direction.orthogonal())) * 3.0
				if cost < best_cost:
					best = candidate
					best_cost = cost
			source.set(property, source.get_path_to(best) if best != null else NodePath())
