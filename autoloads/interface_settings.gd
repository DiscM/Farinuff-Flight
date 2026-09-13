extends Node
## Scales menu typography in layout containers, leaving the flight camera untouched.
var _queued := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	SaveManager.settings_changed.connect(_queue_refresh)
	_queue_refresh()

func _on_node_added(node: Node) -> void:
	if node is Control:
		_queue_refresh()

func _queue_refresh() -> void:
	if _queued:
		return
	_queued = true
	call_deferred("_refresh")

func _refresh() -> void:
	_queued = false
	var factor := clampf(float(SaveManager.get_setting("menu_text_scale", 1.0)), 1.0, 1.3)
	for root: Node in get_tree().get_nodes_in_group("scalable_ui"):
		_scale_branch(root, factor)

func _scale_branch(node: Node, factor: float) -> void:
	if node is Label or node is BaseButton or node is LineEdit or node is TabBar:
		if not node.has_meta("base_menu_font"):
			node.set_meta("base_menu_font", node.get_theme_font_size("font_size"))
		node.add_theme_font_size_override("font_size", roundi(float(node.get_meta("base_menu_font")) * factor))
	elif node is RichTextLabel:
		for key: String in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
			if not node.has_meta("base_menu_" + key):
				node.set_meta("base_menu_" + key, node.get_theme_font_size(key))
			node.add_theme_font_size_override(key, roundi(float(node.get_meta("base_menu_" + key)) * factor))
	if node is BaseButton:
		if not node.has_meta("base_menu_height"):
			node.set_meta("base_menu_height", node.custom_minimum_size.y)
		node.custom_minimum_size.y = maxf(40, float(node.get_meta("base_menu_height"))) * factor
	for child: Node in node.get_children():
		_scale_branch(child, factor)
