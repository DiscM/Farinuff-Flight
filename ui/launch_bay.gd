extends Control
## Launch Bay — the pre-run loadout screen. The player picks an owned ship
## variant, toggles owned challenge modifiers for bonus salvage, and sees
## the resulting salvage multiplier before launching. Opened from the main
## menu; UI is built programmatically like the settings/hangar panels.

## Emitted when the player confirms the launch. The main menu owns the
## fly-out transition and scene change.
signal launch_confirmed
## Emitted when the player backs out without launching.
signal closed

var _ship_cards_by_id: Dictionary = {}
var _multiplier_label: Label

## Sets up the launch bay as a process-always full-rect control and builds
## the UI from the MetaProgression catalogs.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.06, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -250.0
	panel.offset_top = -320.0
	panel.offset_right = 250.0
	panel.offset_bottom = 320.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.15)
	style.border_color = Color(0.2, 0.75, 1.0, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var title := Label.new()
	title.text = "▲  LAUNCH BAY  ▲"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	column.add_child(title)

	column.add_child(_make_section_label("SHIP"))
	var ships_row := HBoxContainer.new()
	ships_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ships_row.add_theme_constant_override("separation", 10)
	column.add_child(ships_row)
	for ship in MetaProgression.SHIP_VARIANTS:
		ships_row.add_child(_make_ship_card(ship))

	column.add_child(_make_section_label("CHALLENGE MODIFIERS"))
	var modifiers_box := VBoxContainer.new()
	modifiers_box.add_theme_constant_override("separation", 4)
	column.add_child(modifiers_box)
	for modifier in MetaProgression.CHALLENGE_MODIFIERS:
		modifiers_box.add_child(_make_modifier_toggle(modifier))

	_multiplier_label = Label.new()
	_multiplier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_multiplier_label.add_theme_font_size_override("font_size", 16)
	_multiplier_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	column.add_child(_multiplier_label)
	_refresh_multiplier_label()

	var buttons_row := HBoxContainer.new()
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_row.add_theme_constant_override("separation", 16)
	column.add_child(buttons_row)

	var back_button := Button.new()
	back_button.text = "BACK"
	back_button.custom_minimum_size = Vector2(130, 44)
	back_button.add_theme_font_size_override("font_size", 18)
	back_button.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	back_button.pressed.connect(_on_back_pressed)
	buttons_row.add_child(back_button)

	var launch_button := Button.new()
	launch_button.text = "▲  LAUNCH"
	launch_button.custom_minimum_size = Vector2(190, 44)
	launch_button.add_theme_font_size_override("font_size", 20)
	launch_button.add_theme_color_override("font_color", Color(0.3, 1.0, 0.55))
	launch_button.pressed.connect(_on_launch_pressed)
	buttons_row.add_child(launch_button)
	launch_button.grab_focus()

func _make_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.45, 0.75, 1.0))
	return label

# --- Ship cards ---

## Builds a ship card: icon, name, stat profile, and select state. Locked
## ships are dimmed and show their Hangar cost; owned ships highlight when
## selected and re-select on press.
func _make_ship_card(ship: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(148, 128)
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	var icon := Label.new()
	icon.text = ship["icon"]
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 24)
	box.add_child(icon)

	var name_label := Label.new()
	name_label.text = ship["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", ship["color"])
	box.add_child(name_label)

	var desc := Label.new()
	desc.text = ship["description"]
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
	box.add_child(desc)

	var select_button := Button.new()
	select_button.custom_minimum_size = Vector2(0, 30)
	select_button.add_theme_font_size_override("font_size", 13)
	select_button.pressed.connect(_on_ship_selected.bind(str(ship["id"])))
	box.add_child(select_button)

	_ship_cards_by_id[ship["id"]] = {"card": card, "style": style, "button": select_button, "ship": ship}
	_refresh_ship_card(str(ship["id"]))
	return card

func _refresh_ship_card(ship_id: String) -> void:
	var entry: Dictionary = _ship_cards_by_id.get(ship_id, {})
	if entry.is_empty():
		return
	var ship: Dictionary = entry["ship"]
	var style: StyleBoxFlat = entry["style"]
	var button: Button = entry["button"]
	if not MetaProgression.is_unlocked(ship_id):
		style.bg_color = Color(0.03, 0.04, 0.10)
		style.border_color = Color(0.25, 0.3, 0.45, 0.5)
		button.text = "🔒 ⬡%d" % int(ship["cost"])
		button.disabled = true
		button.add_theme_color_override("font_color", Color(0.45, 0.5, 0.65))
	elif MetaProgression.selected_ship == ship_id:
		style.bg_color = Color(ship["color"].r * 0.15, ship["color"].g * 0.15, ship["color"].b * 0.15)
		style.border_color = ship["color"]
		button.text = "SELECTED"
		button.disabled = true
		button.add_theme_color_override("font_color", ship["color"])
	else:
		style.bg_color = Color(0.05, 0.07, 0.17)
		style.border_color = Color(0.3, 0.4, 0.6, 0.6)
		button.text = "SELECT"
		button.disabled = false
		button.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))

func _on_ship_selected(ship_id: String) -> void:
	AudioManager.play_ui_click()
	MetaProgression.select_ship(ship_id)
	for id in _ship_cards_by_id:
		_refresh_ship_card(id)

# --- Modifier toggles ---

## Builds a modifier row: a CheckButton for owned modifiers, or a disabled
## locked row showing the Hangar cost.
func _make_modifier_toggle(modifier: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var toggle := CheckButton.new()
	toggle.text = "%s  %s" % [modifier["icon"], modifier["name"]]
	toggle.tooltip_text = str(modifier["description"])
	toggle.add_theme_font_size_override("font_size", 14)
	row.add_child(toggle)

	var bonus := Label.new()
	bonus.text = "+%d%%" % roundi(float(modifier["bonus_pct"]) * 100.0)
	bonus.add_theme_font_size_override("font_size", 14)
	bonus.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	row.add_child(bonus)

	if MetaProgression.is_unlocked(str(modifier["id"])):
		toggle.button_pressed = MetaProgression.is_modifier_active(str(modifier["id"]))
		toggle.toggled.connect(_on_modifier_toggled.bind(str(modifier["id"])))
	else:
		toggle.disabled = true
		toggle.text += "  🔒 ⬡%d" % int(modifier["cost"])
		bonus.modulate.a = 0.45
	return row

func _on_modifier_toggled(enabled: bool, modifier_id: String) -> void:
	AudioManager.play_ui_click()
	MetaProgression.set_modifier_active(modifier_id, enabled)
	_refresh_multiplier_label()

# --- Readout & buttons ---

func _refresh_multiplier_label() -> void:
	var multiplier := MetaProgression.get_salvage_multiplier()
	if multiplier > 1.0:
		_multiplier_label.text = "SALVAGE MULTIPLIER: ×%.2f" % multiplier
	else:
		_multiplier_label.text = "SALVAGE MULTIPLIER: ×1.00  ·  NO MODIFIERS"

func _on_launch_pressed() -> void:
	AudioManager.play_ui_click()
	launch_confirmed.emit()

func _on_back_pressed() -> void:
	AudioManager.play_ui_click()
	closed.emit()
	queue_free()

## Handles ESC key to back out of the launch bay.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		_on_back_pressed()
