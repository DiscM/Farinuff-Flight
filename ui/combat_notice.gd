extends Label
var _remaining := 0.0
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	offset_left = -220
	offset_right = 220
	offset_top = 54
	offset_bottom = 94
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override("font_size", 16)
	SignalBus.combat_notice.connect(_show_notice)
	hide()
func _show_notice(message: String) -> void:
	text = message
	_remaining = 3.5
	show()
func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining <= 0:
		hide()
