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

const SHIP_PREVIEW_SCRIPT := preload("res://entities/player/ship_upgrade_preview.gd")
const NATIVE_HULL_IDS: Array[String] = [
	"ship_swallowtail",
	"ship_interceptor",
	"ship_bulwark",
]
const FALLBACK_ICON := "◇"
const FALLBACK_NAME := "UNKNOWN HULL"
const FALLBACK_DESCRIPTION := "Hull data unavailable."
const FALLBACK_COLOR := Color(0.55, 0.65, 0.82)

var _ship_cards_by_id: Dictionary = {}
var _multiplier_label: Label
var _supply_label: Label
var _selected_ship_label: Label
var _launch_button: Button

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
	panel.offset_left = -285.0
	panel.offset_top = -350.0
	panel.offset_right = 285.0
	panel.offset_bottom = 350.0
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
	if _ship_cards_by_id.is_empty():
		ships_row.add_child(_make_catalog_placeholder("No native hull catalog is available."))

	_selected_ship_label = Label.new()
	_selected_ship_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selected_ship_label.add_theme_font_size_override("font_size", 12)
	_selected_ship_label.add_theme_color_override("font_color", Color(0.7, 0.84, 1.0))
	column.add_child(_selected_ship_label)
	_refresh_selected_ship_label()

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

	_supply_label = Label.new()
	_supply_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_supply_label.add_theme_font_size_override("font_size", 13)
	_supply_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.9))
	column.add_child(_supply_label)
	_refresh_supply_label()

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

	_launch_button = Button.new()
	var launch_button := _launch_button
	launch_button.text = "▲  LAUNCH"
	launch_button.custom_minimum_size = Vector2(190, 44)
	launch_button.add_theme_font_size_override("font_size", 20)
	launch_button.add_theme_color_override("font_color", Color(0.3, 1.0, 0.55))
	launch_button.pressed.connect(_on_launch_pressed)
	buttons_row.add_child(launch_button)
	_refresh_launch_button()
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
	var ship_id := str(ship.get("id", "")).strip_edges()
	var ship_name := _safe_text(ship, "name", FALLBACK_NAME)
	var ship_icon := _safe_text(ship, "icon", FALLBACK_ICON)
	var ship_description := _safe_text(ship, "description", FALLBACK_DESCRIPTION)
	var ship_color := _safe_color(ship, "color", FALLBACK_COLOR)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(148, 212)
	card.tooltip_text = ship_description
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	var preview := _make_ship_preview(ship_id)
	box.add_child(preview)

	var icon := Label.new()
	icon.text = ship_icon
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 20)
	box.add_child(icon)

	var name_label := Label.new()
	name_label.text = ship_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", ship_color)
	box.add_child(name_label)

	var desc := Label.new()
	desc.text = ship_description
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)

	var select_button := Button.new()
	select_button.custom_minimum_size = Vector2(0, 30)
	select_button.add_theme_font_size_override("font_size", 13)
	select_button.pressed.connect(_on_ship_selected.bind(ship_id))
	box.add_child(select_button)

	if ship_id != "":
		_ship_cards_by_id[ship_id] = {"card": card, "style": style, "button": select_button, "ship": ship}
		_refresh_ship_card(ship_id)
	return card


func _make_ship_preview(hull_id: String) -> Control:
	if not NATIVE_HULL_IDS.has(hull_id):
		return _make_catalog_placeholder("NATIVE PREVIEW UNAVAILABLE")
	var preview := SHIP_PREVIEW_SCRIPT.new() as ShipUpgradePreview
	if preview == null:
		return _make_catalog_placeholder("NATIVE PREVIEW UNAVAILABLE")
	preview.configure([], "", hull_id)
	preview.custom_minimum_size = Vector2(0, 76)
	return preview


func _make_catalog_placeholder(message: String) -> Label:
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.55, 0.65, 0.82))
	label.custom_minimum_size = Vector2(140, 56)
	return label


func _safe_text(data: Dictionary, key: String, fallback: String) -> String:
	var value: Variant = data.get(key, "")
	var text := str(value).strip_edges()
	return text if text != "" else fallback


func _safe_color(data: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = data.get(key, fallback)
	return value if value is Color else fallback

func _refresh_ship_card(ship_id: String) -> void:
	var entry: Dictionary = _ship_cards_by_id.get(ship_id, {})
	if entry.is_empty():
		return
	var ship: Dictionary = entry["ship"]
	var style: StyleBoxFlat = entry["style"]
	var button: Button = entry["button"]
	var card: PanelContainer = entry["card"]
	var ship_color := _safe_color(ship, "color", FALLBACK_COLOR)
	var is_unlocked := MetaProgression.is_unlocked(ship_id)
	if not is_unlocked:
		style.bg_color = Color(0.03, 0.04, 0.10)
		style.border_color = Color(0.25, 0.3, 0.45, 0.5)
		button.text = "🔒 ⬡%d" % int(ship.get("cost", 0))
		button.disabled = true
		button.add_theme_color_override("font_color", Color(0.45, 0.5, 0.65))
		card.modulate = Color(0.62, 0.66, 0.76, 1.0)
	elif MetaProgression.selected_ship == ship_id:
		style.bg_color = Color(ship_color.r * 0.15, ship_color.g * 0.15, ship_color.b * 0.15)
		style.border_color = ship_color
		button.text = "SELECTED"
		button.disabled = true
		button.add_theme_color_override("font_color", ship_color)
		card.modulate = Color.WHITE
	else:
		style.bg_color = Color(0.05, 0.07, 0.17)
		style.border_color = Color(0.3, 0.4, 0.6, 0.6)
		button.text = "SELECT"
		button.disabled = false
		button.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
		card.modulate = Color.WHITE

func _on_ship_selected(ship_id: String) -> void:
	if not _ship_cards_by_id.has(ship_id) or not MetaProgression.is_unlocked(ship_id):
		return
	AudioManager.play_ui_click()
	MetaProgression.select_ship(ship_id)
	for id in _ship_cards_by_id:
		_refresh_ship_card(id)
	_refresh_selected_ship_label()
	_refresh_launch_button()


func _refresh_selected_ship_label() -> void:
	if not is_instance_valid(_selected_ship_label):
		return
	var selected_id := str(MetaProgression.selected_ship)
	var entry: Dictionary = _ship_cards_by_id.get(selected_id, {})
	if entry.is_empty():
		_selected_ship_label.text = "SELECTED HULL: UNAVAILABLE — CHOOSE AN UNLOCKED NATIVE HULL"
		return
	var ship: Dictionary = entry["ship"]
	_selected_ship_label.text = "SELECTED HULL: %s  ·  NATIVE 3D" % _safe_text(ship, "name", FALLBACK_NAME).to_upper()


func _refresh_launch_button() -> void:
	if not is_instance_valid(_launch_button):
		return
	var selected_id := str(MetaProgression.selected_ship)
	var entry: Dictionary = _ship_cards_by_id.get(selected_id, {})
	var can_launch := not entry.is_empty() and MetaProgression.is_unlocked(selected_id)
	_launch_button.disabled = not can_launch
	_launch_button.text = "▲  LAUNCH" if can_launch else "SELECT AN UNLOCKED HULL"

# --- Modifier toggles ---

## Builds a modifier row: a CheckButton for owned modifiers, or a disabled
## locked row showing the Hangar cost.
func _make_modifier_toggle(modifier: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var toggle := CheckButton.new()
	var modifier_id := str(modifier.get("id", ""))
	toggle.text = "%s  %s" % [
		_safe_text(modifier, "icon", FALLBACK_ICON),
		_safe_text(modifier, "name", "UNKNOWN MODIFIER"),
	]
	toggle.tooltip_text = _safe_text(modifier, "description", FALLBACK_DESCRIPTION)
	toggle.add_theme_font_size_override("font_size", 14)
	row.add_child(toggle)

	var bonus := Label.new()
	bonus.text = "+%d%%" % roundi(float(modifier.get("bonus_pct", 0.0)) * 100.0)
	bonus.add_theme_font_size_override("font_size", 14)
	bonus.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	row.add_child(bonus)

	if modifier_id != "" and MetaProgression.is_unlocked(modifier_id):
		toggle.button_pressed = MetaProgression.is_modifier_active(modifier_id)
		toggle.toggled.connect(_on_modifier_toggled.bind(modifier_id))
	else:
		toggle.disabled = true
		toggle.text += "  🔒 ⬡%d" % int(modifier.get("cost", 0))
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

## Shows the Hangar field supply that will be consumed by this run
## (stockpiled try-again stocks and the drop-pod state), including capacity.
func _refresh_supply_label() -> void:
	var stock_capacity := int(MetaProgression.MAX_STOCKPILED_STOCKS)
	var stock_count := clampi(int(MetaProgression.consumable_stocks), 0, stock_capacity)
	var pod_state := "ARMED" if MetaProgression.consumable_powerup_armed else "EMPTY"
	_supply_label.visible = true
	_supply_label.text = "FIELD SUPPLY  ·  TRY-AGAIN STOCK %d/%d  ·  DROP POD %s" % [
		stock_count,
		stock_capacity,
		pod_state,
	]

func _on_launch_pressed() -> void:
	if not is_instance_valid(_launch_button) or _launch_button.disabled:
		return
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
