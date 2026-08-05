extends Control
## First-run onboarding for the core Farinuff Flight loop.
##
## This is intentionally short and replayable from the main menu. It teaches
## the interactions that are easy to miss in a single-purchase arcade game:
## movement, boost reflection, orb/life economy, build choices, and the
## finite Wave-20 Expedition target.

signal finished

const PAGE_TITLES: Array[String] = [
	"MOVE / AIM",
	"BOOST / REFLECT",
	"ORB METER",
	"BUILD / TRANSFORM",
	"EXPEDITION",
]
const PAGE_TEXT: Array[String] = [
	"MOVE WITH WASD OR THE ARROW KEYS. ON A GAMEPAD, USE THE LEFT STICK. AIM WITH THE MOUSE OR RIGHT STICK. HOLD FIRE TO KEEP PRESSURE ON.",
	"BOOST THROUGH ENEMY FIRE TO EVADE AND REFLECT PROJECTILES. REFLECTED SHOTS RETURN AS YOUR GREEN FIRE.",
	"COLLECT XP ORBS TO CLEAR WAVES. EVERY 12 ORB VALUE RESTORES A LIFE. BOSSES ARRIVE EVERY FIFTH WAVE.",
	"TEMPORARY PICKUPS SHAPE THIS RUN. BOSS MILESTONES OFFER UPGRADES THAT TRANSFORM YOUR SHIP. SALVAGE UNLOCKS FUTURE OPTIONS IN THE HANGAR.",
	"REACH WAVE 20 AND BREAK THE TEMPEST CORE. AFTER THE CLEAR, CONTINUE INTO ENDLESS OR RETURN TO THE HANGAR.",
]
const PAGE_TIPS: Array[String] = [
	"TIP // KEEP MOVING; THE EDGES ARE DANGER ZONES.",
	"TIP // BOOST IS DEFENSE, NOT ONLY SPEED.",
	"TIP // A STRONG RUN CAN RECOVER FROM A BAD HIT.",
	"TIP // EVERY BUILD SHOULD ANSWER A THREAT.",
	"TIP // THE FIRST CLEAR IS A MILESTONE, NOT A HARD STOP.",
]

const CYAN := Color(0.14, 0.93, 1.0)
const GREEN := Color(0.32, 1.0, 0.55)
const YELLOW := Color(1.0, 0.84, 0.12)
const MAGENTA := Color(1.0, 0.16, 0.55)
const INK := Color(0.005, 0.012, 0.04, 0.98)

var _page_index := 0
var _finished := false
var _eyebrow: Label
var _title: Label
var _page_title: Label
var _body: Label
var _tip: Label
var _back_button: Button
var _next_button: Button
var _skip_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_render_page()
	_back_button.grab_focus()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.002, 0.004, 0.018, 0.96)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var scanline := ColorRect.new()
	scanline.set_anchors_preset(Control.PRESET_TOP_WIDE)
	scanline.offset_bottom = 2.0
	scanline.color = Color(MAGENTA, 0.55)
	scanline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scanline)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(318.0, 448.0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	_eyebrow = Label.new()
	_eyebrow.add_theme_color_override("font_color", GREEN)
	_eyebrow.add_theme_font_size_override("font_size", 12)
	content.add_child(_eyebrow)

	_title = Label.new()
	_title.text = "FLIGHT SCHOOL"
	_title.add_theme_color_override("font_color", CYAN)
	_title.add_theme_color_override("font_outline_color", Color(0.04, 0.18, 0.28, 1.0))
	_title.add_theme_constant_override("outline_size", 5)
	_title.add_theme_font_size_override("font_size", 28)
	content.add_child(_title)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0.0, 2.0)
	rule.color = Color(MAGENTA, 0.78)
	content.add_child(rule)

	_page_title = Label.new()
	_page_title.add_theme_color_override("font_color", YELLOW)
	_page_title.add_theme_font_size_override("font_size", 20)
	content.add_child(_page_title)

	_body = Label.new()
	_body.custom_minimum_size = Vector2(0.0, 146.0)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body.add_theme_color_override("font_color", Color(0.88, 0.93, 1.0))
	_body.add_theme_font_size_override("font_size", 16)
	content.add_child(_body)

	_tip = Label.new()
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.add_theme_color_override("font_color", Color(0.55, 0.70, 0.83))
	_tip.add_theme_font_size_override("font_size", 12)
	content.add_child(_tip)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 10.0)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)

	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 8)
	content.add_child(navigation)

	_back_button = _make_button("BACK", CYAN)
	_back_button.custom_minimum_size = Vector2(72.0, 48.0)
	_back_button.pressed.connect(_on_back_pressed)
	navigation.add_child(_back_button)

	_next_button = _make_button("NEXT", YELLOW)
	_next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_button.custom_minimum_size = Vector2(0.0, 48.0)
	_next_button.pressed.connect(advance)
	navigation.add_child(_next_button)

	_skip_button = _make_button("SKIP TRAINING", MAGENTA)
	_skip_button.custom_minimum_size = Vector2(0.0, 38.0)
	_skip_button.pressed.connect(finish)
	content.add_child(_skip_button)


func _make_button(label: String, color: Color) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_style(INK, color, 2, 1))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.04, 0.07, 0.12, 1.0), color, 2, 2))
	button.add_theme_stylebox_override("focus", _button_style(Color(0.04, 0.07, 0.12, 1.0), color, 2, 2))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.08, 0.10, 0.16, 1.0), color, 2, 2))
	return button


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.025, 0.07, 0.98)
	style.border_color = Color(CYAN, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0.0, 6.0)
	return style


func _button_style(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	return style


func _render_page() -> void:
	_eyebrow.text = "TRAINING // %02d OF %02d" % [_page_index + 1, get_page_count()]
	_page_title.text = PAGE_TITLES[_page_index]
	_body.text = PAGE_TEXT[_page_index]
	_tip.text = PAGE_TIPS[_page_index]
	_back_button.disabled = _page_index == 0
	_next_button.text = "BEGIN FLIGHT" if _page_index == get_page_count() - 1 else "NEXT"
	_skip_button.text = "CLOSE SCHOOL" if _page_index == get_page_count() - 1 else "SKIP TRAINING"


## Public seam used by smoke tests and by any future tutorial front end.
func get_page_count() -> int:
	return PAGE_TEXT.size()


## Returns the instructional copy for a page without exposing UI nodes.
func get_page_text(index: int) -> String:
	if index < 0 or index >= PAGE_TEXT.size():
		return ""
	return PAGE_TEXT[index]


## Advances the lesson or completes it on the final page.
func advance() -> void:
	if _finished:
		return
	if _page_index >= get_page_count() - 1:
		finish()
		return
	_page_index += 1
	_render_page()


## Completes the lesson, persists the first-run flag, and closes the modal.
func finish() -> void:
	if _finished:
		return
	_finished = true
	SaveManager.mark_flight_school_seen()
	finished.emit()
	queue_free()


func _on_back_pressed() -> void:
	if _page_index <= 0:
		return
	_page_index -= 1
	_render_page()


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_pressed("ui_cancel"):
		finish()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		advance()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		advance()
		get_viewport().set_input_as_handled()
