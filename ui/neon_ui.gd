extends RefCounted
class_name NeonUI

const HEADING_FONT := preload("res://ui/themes/cabinet_heading.tres")

const CYAN := Color(0.17, 0.95, 1.0)
const YELLOW := Color(1.0, 0.9, 0.08)
const GREEN := Color(0.36, 1.0, 0.59)
const PINK := Color(1.0, 0.25, 0.56)
const INK := Color(0.008, 0.018, 0.035, 0.94)
const INK_DARK := Color(0.004, 0.01, 0.022, 0.96)
const WHITE := Color(0.9, 0.98, 1.0)

static func plaque(accent: Color = CYAN, fill: Color = INK, radius: int = 10, border_width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(mini(radius, 2))
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 0
	style.shadow_offset = Vector2(4, 5)
	style.content_margin_left = 12
	style.content_margin_top = 8
	style.content_margin_right = 12
	style.content_margin_bottom = 8
	return style

static func button_style(accent: Color, fill: Color = INK_DARK) -> StyleBoxFlat:
	var style := plaque(accent, fill, 2, 1)
	style.skew = Vector2(-0.12, 0.0)
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
	if size >= 22:
		label.add_theme_font_override("font", HEADING_FONT)
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
	button.add_theme_font_override("font", HEADING_FONT)
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_color_override("font_hover_color", accent)
	button.add_theme_stylebox_override("normal", button_style(accent))
	button.add_theme_stylebox_override("hover", button_style(accent, Color(0.03, 0.1, 0.2, 0.96)))
	button.add_theme_stylebox_override("pressed", button_style(accent, Color(0.05, 0.13, 0.2, 1.0)))
	button.add_theme_stylebox_override("focus", button_style(accent, Color(0.02, 0.08, 0.16, 1.0)))
	if accent == YELLOW:
		style_primary(button)
	return button


## Yellow is reserved for the screen's commit / continue action.
static func style_primary(button: Button) -> void:
	button.add_theme_font_override("font", HEADING_FONT)
	for state in ["normal", "hover", "pressed"]:
		var fill := YELLOW.lightened(0.18) if state == "hover" else YELLOW
		if state == "pressed":
			fill = YELLOW.darkened(0.12)
		button.add_theme_stylebox_override(state, button_style(YELLOW, fill))
	button.add_theme_stylebox_override("disabled", button_style(Color(0.35, 0.4, 0.48), INK_DARK))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK_DARK)
	var focus := button_style(WHITE, Color.TRANSPARENT)
	focus.draw_center = false
	focus.set_border_width_all(3)
	button.add_theme_stylebox_override("focus", focus)


## Apply shared typography to authored screens without changing state colors.
static func style_screen(root: Node) -> void:
	for control in root.find_children("*", "Control", true, false):
		if control is Label and control.get_theme_font_size("font_size") >= 24:
			control.add_theme_font_override("font", HEADING_FONT)
		if control is PanelContainer:
			var panel_style := control.get_theme_stylebox("panel") as StyleBoxFlat
			if panel_style != null:
				panel_style.set_corner_radius_all(2)
