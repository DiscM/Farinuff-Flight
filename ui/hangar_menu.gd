extends Control
## Hangar — the meta-progression shop. Spends persistent salvage on
## permanent ship systems and elite-upgrade blueprints. Opened from the
## main menu; UI is built programmatically like the settings panel.

signal closed

var _salvage_label: Label
var _rows_by_id: Dictionary = {}
var _wallet_connected: bool = false

## Sets up the shop as a process-always full-rect control, builds the UI,
## and listens for wallet changes so the balance stays current.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	if not MetaProgression.salvage_changed.is_connected(_on_salvage_changed):
		MetaProgression.salvage_changed.connect(_on_salvage_changed)
		_wallet_connected = true

func _exit_tree() -> void:
	if _wallet_connected and MetaProgression.salvage_changed.is_connected(_on_salvage_changed):
		MetaProgression.salvage_changed.disconnect(_on_salvage_changed)

## Constructs the hangar UI: dark overlay, centered panel with title,
## salvage balance, a scrollable item list grouped by category, a note
## about salvage sources, and a close button.
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.06, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -240.0
	panel.offset_top = -330.0
	panel.offset_right = 240.0
	panel.offset_bottom = 330.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.15)
	style.border_color = Color(1.0, 0.75, 0.2, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	var title := Label.new()
	title.text = "⬡  HANGAR  ⬡"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.25))
	column.add_child(title)

	_salvage_label = Label.new()
	_salvage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_salvage_label.add_theme_font_size_override("font_size", 18)
	_salvage_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	column.add_child(_salvage_label)
	_refresh_salvage_label()

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 360)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	_add_category_header(list, "SHIP SYSTEMS")
	for item in MetaProgression.SHOP_ITEMS:
		if item["category"] == "system":
			_add_item_row(list, item)
	_add_category_header(list, "SHIP VARIANTS  ·  SELECT IN LAUNCH BAY")
	for ship in MetaProgression.SHIP_VARIANTS:
		if ship["id"] != MetaProgression.DEFAULT_SHIP:
			_add_item_row(list, ship)
	_add_category_header(list, "CHALLENGE MODIFIERS  ·  TOGGLE IN LAUNCH BAY")
	for modifier in MetaProgression.CHALLENGE_MODIFIERS:
		_add_item_row(list, modifier)
	_add_category_header(list, "ELITE BLUEPRINTS")
	for item in MetaProgression.SHOP_ITEMS:
		if item["category"] == "blueprint":
			_add_item_row(list, item)
	_add_category_header(list, "FIELD SUPPLY  ·  CONSUMED NEXT RUN")
	for item in MetaProgression.CONSUMABLE_ITEMS:
		_add_item_row(list, item)

	var note := Label.new()
	note.text = "Salvage is earned from boss kills, first-clear wave milestones, and the end-of-run bonus."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color(0.55, 0.65, 0.8))
	column.add_child(note)

	var stats := Label.new()
	stats.text = "LIFETIME — RUNS: %d · KILLS: %d · BEST WAVE: %d" % [
		MetaProgression.stat_total_runs,
		MetaProgression.stat_total_kills,
		MetaProgression.stat_best_wave,
	]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 12)
	stats.add_theme_color_override("font_color", Color(0.5, 0.55, 0.7))
	column.add_child(stats)

	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(180, 44)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.pressed.connect(_on_close_pressed)
	column.add_child(close_button)
	close_button.grab_focus()

func _add_category_header(parent: VBoxContainer, text: String) -> void:
	var header := Label.new()
	header.text = text
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.45, 0.75, 1.0))
	parent.add_child(header)

## Builds one shop row: icon, name, description, and a cost/BUY button.
## The row is re-styled on purchase state changes via _refresh_row.
func _add_item_row(parent: VBoxContainer, item: Dictionary) -> void:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	row.add_theme_stylebox_override("panel", style)
	parent.add_child(row)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)

	var icon := Label.new()
	icon.text = item["icon"]
	icon.add_theme_font_size_override("font_size", 26)
	icon.custom_minimum_size = Vector2(36, 0)
	hbox.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)
	hbox.add_child(text_box)

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", item["color"])
	text_box.add_child(name_label)

	var desc_label := Label.new()
	var desc_text := str(item["description"])
	if item.has("bonus_pct"):
		desc_text += "\n+%d%% salvage when active." % roundi(float(item["bonus_pct"]) * 100.0)
	desc_label.text = desc_text
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
	text_box.add_child(desc_label)

	var buy_button := Button.new()
	buy_button.custom_minimum_size = Vector2(96, 40)
	buy_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy_button.add_theme_font_size_override("font_size", 15)
	buy_button.pressed.connect(_on_buy_pressed.bind(str(item["id"])))
	hbox.add_child(buy_button)

	_rows_by_id[item["id"]] = {"row": row, "style": style, "button": buy_button, "item": item, "name_label": name_label}
	_refresh_row(str(item["id"]))

## Restyles a row for its current state: level pips and next-tier cost for
## tiered systems, OWNED for maxed items, cost for locked ones.
func _refresh_row(unlock_id: String) -> void:
	var entry: Dictionary = _rows_by_id.get(unlock_id, {})
	if entry.is_empty():
		return
	var item: Dictionary = entry["item"]
	var style: StyleBoxFlat = entry["style"]
	var button: Button = entry["button"]
	var name_label: Label = entry["name_label"]
	var level := MetaProgression.get_level(unlock_id)
	var max_level := MetaProgression.get_max_level(unlock_id)
	var next_cost := MetaProgression.get_next_cost(unlock_id)

	name_label.text = str(item["name"])
	if max_level > 1:
		var pips := ""
		for i in range(max_level):
			pips += "●" if i < level else "○"
		name_label.text += "  %s" % pips

	if next_cost < 0:
		# Maxed out (level 1 for single-tier items).
		style.bg_color = Color(item["color"].r * 0.12, item["color"].g * 0.12, item["color"].b * 0.12)
		style.border_color = item["color"]
		if item.get("category") == "consumable" and max_level == 1:
			button.text = "READY"
		else:
			button.text = "MAX" if max_level > 1 else "OWNED"
		button.disabled = true
		button.add_theme_color_override("font_color", item["color"])
	else:
		style.bg_color = Color(0.05, 0.07, 0.17) if level == 0 else Color(item["color"].r * 0.08, item["color"].g * 0.08, item["color"].b * 0.08)
		style.border_color = item["color"] if level > 0 else Color(0.3, 0.4, 0.6, 0.6)
		button.text = "⬡ %d" % next_cost
		button.disabled = not MetaProgression.can_purchase(unlock_id)
		button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))

func _refresh_salvage_label() -> void:
	_salvage_label.text = "SALVAGE: ⬡ %d" % MetaProgression.salvage

func _on_salvage_changed(_new_total: int) -> void:
	_refresh_salvage_label()
	# Affordability may have changed: refresh every row's BUY state.
	for unlock_id in _rows_by_id:
		_refresh_row(unlock_id)

func _on_buy_pressed(unlock_id: String) -> void:
	if MetaProgression.purchase(unlock_id):
		AudioManager.play_powerup()
	else:
		AudioManager.play_ui_click()

## Emits the closed signal and frees this shop panel.
func _on_close_pressed() -> void:
	AudioManager.play_ui_click()
	closed.emit()
	queue_free()

## Handles ESC key to close the shop panel.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		_on_close_pressed()
