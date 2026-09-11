extends VBoxContainer
## Shared preview and live route chart with an explicit threat dossier.
signal selection_changed(node_id: StringName)
var preview_mode := true
var selectable_ids: Array[StringName] = []
var selected_id: StringName = &""
var _graph: Control
var _dossier: Label

func _ready() -> void:
	add_theme_constant_override("separation", 14)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dossier = Label.new()
	_dossier.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dossier.custom_minimum_size.y = 90
	_dossier.add_theme_font_size_override("font_size", 17)
	_graph = preload("res://ui/route_graph.gd").new()
	_graph.preview_mode = preview_mode
	_graph.selectable_ids = selectable_ids.duplicate()
	_graph.node_selected.connect(_show_dossier)
	# The dossier is initialized before graph readiness emits its initial selection.
	add_child(_graph)
	add_child(_dossier)

func _show_dossier(node_id: StringName) -> void:
	selected_id = node_id
	var dossier := ExpeditionManager.get_node_dossier(node_id)
	_dossier.text = "%s · %s\nTHREATS · %s\nSECTOR BOSS · %s" % [dossier.get("title", ""), dossier.get("waves", ""), dossier.get("threats", ""), dossier.get("boss", "")]
	selection_changed.emit(node_id)

func get_primary_safe_action() -> Control:
	return _graph.get_primary_safe_action() if _graph != null else null
