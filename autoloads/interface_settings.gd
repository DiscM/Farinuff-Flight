extends Node
## Scales menu typography in layout containers, leaving the flight camera untouched.
var _queued := false
var _storage_panel: PanelContainer
var _storage_notice: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	SaveManager.settings_changed.connect(_queue_refresh)
	_build_storage_notice()
	SaveManager.storage_status_changed.connect(_refresh_storage_notice)
	_refresh_storage_notice()
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


func _build_storage_notice() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 90
	add_child(overlay)
	_storage_panel = PanelContainer.new()
	_storage_panel.name = "StorageNotice"
	_storage_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_storage_panel.offset_left = 20
	_storage_panel.offset_right = -20
	_storage_panel.offset_top = -100
	_storage_panel.offset_bottom = -20
	_storage_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.02, 0.01, 0.98)
	style.border_color = Color(1, 0.7, 0.15)
	style.set_border_width_all(2)
	style.set_content_margin_all(12)
	_storage_panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(_storage_panel)
	_storage_notice = Label.new()
	_storage_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_storage_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_storage_panel.add_child(_storage_notice)


func _refresh_storage_notice() -> void:
	_storage_notice.text = SaveManager.get_storage_notice()
	_storage_panel.visible = not _storage_notice.text.is_empty()
