extends RefCounted
class_name NeonUI

const CYAN := Color(0.17, 0.95, 1.0)
const YELLOW := Color(1.0, 0.86, 0.26)
const GREEN := Color(0.36, 1.0, 0.59)
const PINK := Color(1.0, 0.25, 0.56)
const INK := Color(0.02, 0.06, 0.14, 0.9)
const INK_DARK := Color(0.01, 0.03, 0.08, 0.94)
const WHITE := Color(0.9, 0.98, 1.0)

static func plaque(accent: Color = CYAN, fill: Color = INK, radius: int = 10, border_width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 5
	style.shadow_offset = Vector2(4, 5)
	style.content_margin_left = 12
	style.content_margin_top = 8
	style.content_margin_right = 12
	style.content_margin_bottom = 8
	return style

static func button_style(accent: Color, fill: Color = INK_DARK) -> StyleBoxFlat:
	var style := plaque(accent, fill, 8, 2)
	style.content_margin_left = 18
	style.content_margin_right = 18
	return style

static func make_label(text: String, size: int, color: Color = WHITE, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	return label

static func make_plaque(name: String, rect: Rect2, accent: Color, fill: Color = INK, radius: int = 10) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = name
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", plaque(accent, fill, radius))
	return panel

static func make_button(name: String, text: String, accent: Color, min_size: Vector2) -> Button:
	var button := Button.new()
	button.name = name
	button.text = text
	button.custom_minimum_size = min_size
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_color_override("font_hover_color", accent)
	button.add_theme_stylebox_override("normal", button_style(accent))
	button.add_theme_stylebox_override("hover", button_style(accent, Color(0.03, 0.1, 0.2, 0.96)))
	button.add_theme_stylebox_override("pressed", button_style(accent, Color(0.05, 0.13, 0.2, 1.0)))
	button.add_theme_stylebox_override("focus", button_style(accent, Color(0.02, 0.08, 0.16, 1.0)))
	return button
