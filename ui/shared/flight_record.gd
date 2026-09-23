extends PanelContainer
## The same factual flight record on defeat, victory, and pause screens.
var show_advice := false

func _ready() -> void:
	name = "FlightRecord"
	var style := NeonUI.plaque(Color(NeonUI.CYAN, 0.35), Color(0.015, 0.035, 0.05), 2, 1)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	_add_label(column, "FLIGHT RECORD", 12, NeonUI.CYAN)
	_add_label(column, GameManager.run_insights.summary(), 14, NeonUI.WHITE)
	if show_advice:
		column.add_child(HSeparator.new())
		_add_label(column, GameManager.run_insights.next_attempt_tip(), 13, Color(0.74, 0.84, 0.91))

func _add_label(parent: Node, copy: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = copy
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
