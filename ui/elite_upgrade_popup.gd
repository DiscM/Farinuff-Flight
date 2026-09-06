extends Control
## Elite upgrade popup — shown after the Wave 10 (elite) boss is defeated.
## Presents up to 3 randomly selected native ship modules. Solo selection
## resumes play; combined milestones wait for point allocation to finish.

signal upgrade_chosen

const NativeUpgradeCatalog := preload("res://entities/player/native_player_upgrades.gd")
const SHIP_PREVIEW_SCRIPT := preload("res://entities/player/ship_upgrade_preview.gd")
const MAX_CHOICES := 3
const FALLBACK_ICON := "✦"
const FALLBACK_NAME := "NATIVE UPGRADE"
const FALLBACK_DESCRIPTION := "Native module data unavailable."
const FALLBACK_COLOR := Color(0.3, 1.0, 0.6)

var use_custom_upgrade_pool := false
var custom_upgrade_pool: Array[Dictionary] = []
var upgrade_target: Node
var show_ship_previews := true

# ── Upgrade Definitions ────────────────────────────────────────────────────────

# (Upgrades moved to GameManager to allow for global completion checks)

var chosen_upgrades: Array[Dictionary] = []
var cards_by_id: Dictionary = {}
var selection_locked: bool = false
var confirmation_label: Label = null
var _available_upgrade_count := 0

# When true, no fullscreen overlay bg is drawn — used for side-by-side layout
var panel_only: bool = false

# ── Setup ──────────────────────────────────────────────────────────────────────

## Picks 3 random upgrades from the available pool, builds the card-based
## UI, already at its final transform with no entrance interpolation.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pick_upgrades()
	_build_ui()
	modulate.a = 1.0
	position.y = 0.0

## Selects up to three implemented native upgrades from the current run's
## pool (base catalog plus meta-unlocked blueprints), excluding any already
## chosen this run. Custom pools are filtered by the same native catalog so a
## stale or incomplete reward can never reach the card builder.
func _pick_upgrades() -> void:
	var pool: Array[Dictionary] = []
	var source_pool: Array = custom_upgrade_pool if use_custom_upgrade_pool else NativeUpgradeCatalog.available()
	var seen_ids: Dictionary = {}
	for raw_upgrade: Variant in source_pool:
		if not raw_upgrade is Dictionary:
			continue
		var raw: Dictionary = raw_upgrade
		var upgrade_id := str(raw.get("id", "")).strip_edges()
		if (
			upgrade_id == ""
			or not NativeUpgradeCatalog.SUPPORTED_IDS.has(upgrade_id)
			or seen_ids.has(upgrade_id)
			or GameManager.chosen_upgrade_ids.has(upgrade_id)
		):
			continue
		seen_ids[upgrade_id] = true
		pool.append(_normalize_upgrade(raw, upgrade_id))
	_available_upgrade_count = pool.size()
	pool.shuffle()
	chosen_upgrades.clear()
	for index in range(mini(pool.size(), MAX_CHOICES)):
		chosen_upgrades.append(pool[index])


func _normalize_upgrade(raw: Dictionary, upgrade_id: String) -> Dictionary:
	var normalized: Dictionary = raw.duplicate()
	normalized["id"] = upgrade_id
	normalized["name"] = _safe_text(raw, "name", FALLBACK_NAME)
	normalized["icon"] = _safe_text(raw, "icon", FALLBACK_ICON)
	normalized["description"] = _safe_text(raw, "description", FALLBACK_DESCRIPTION)
	normalized["color"] = _safe_color(raw, "color", FALLBACK_COLOR)
	return normalized


func _safe_text(data: Dictionary, key: String, fallback: String) -> String:
	var value: Variant = data.get(key, "")
	var text := str(value).strip_edges()
	return text if text != "" else fallback


func _safe_color(data: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = data.get(key, fallback)
	return value if value is Color else fallback

# ── UI ─────────────────────────────────────────────────────────────────────────

## Constructs the elite upgrade UI: optional dark overlay, title/subtitle
## labels, and a horizontal row of upgrade cards — each showing a ship preview,
## name, description, and a SELECT button.
func _build_ui() -> void:
	var compact_layout := panel_only

	if not panel_only:
		# Full-screen dark overlay
		var bg := ColorRect.new()
		bg.color = Color(0.0, 0.0, 0.05, 0.92)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)

	# Outer vertical container
	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.set_offsets_preset(Control.PRESET_FULL_RECT)
	outer.alignment = BoxContainer.ALIGNMENT_BEGIN if compact_layout else BoxContainer.ALIGNMENT_CENTER
	outer.add_theme_constant_override("separation", 12 if compact_layout else 24)
	add_child(outer)

	# Title banner
	var title_bg := ColorRect.new()
	title_bg.color = Color(0.05, 0.05, 0.18, 0.0)
	title_bg.custom_minimum_size = Vector2(0, 1)
	outer.add_child(title_bg)

	var title := Label.new()
	title.text = "✦  NATIVE ELITE REWARD  ✦"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3))
	title.add_theme_font_size_override("font_size", 26 if compact_layout else 34)
	outer.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Choose one native module  ·  %d available  ·  showing %d/%d" % [
		_available_upgrade_count,
		chosen_upgrades.size(),
		MAX_CHOICES,
	]
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.75, 1.0))
	subtitle.add_theme_font_size_override("font_size", 13 if compact_layout else 16)
	outer.add_child(subtitle)
	confirmation_label = subtitle

	# Cards row
	var cards_row := HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cards_row.add_theme_constant_override("separation", 14 if compact_layout else 28)
	outer.add_child(cards_row)

	if chosen_upgrades.is_empty():
		cards_row.add_child(_make_empty_state())
	else:
		for upg in chosen_upgrades:
			cards_row.add_child(_make_card(upg))


func _make_empty_state() -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(260, 150) if panel_only else Vector2(340, 180)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.15)
	style.border_color = Color(0.35, 0.48, 0.68, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 10)
	card.add_child(content)

	var message := Label.new()
	message.text = "NO NATIVE UPGRADES AVAILABLE\nAll remaining reward slots are installed or unavailable."
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_color_override("font_color", Color(0.75, 0.84, 0.98))
	message.add_theme_font_size_override("font_size", 13 if panel_only else 15)
	content.add_child(message)

	var continue_button := Button.new()
	continue_button.text = "CONTINUE"
	continue_button.custom_minimum_size = Vector2(0, 36)
	continue_button.pressed.connect(_on_empty_state_continue)
	content.add_child(continue_button)
	return card

## Creates a single upgrade card panel: styled border in the upgrade's color,
## preview, name, description, and a SELECT button. Registers immediate hover
## state changes.
func _make_card(upg: Dictionary) -> PanelContainer:
	var upgrade_id := str(upg.get("id", ""))
	var upgrade_color := _safe_color(upg, "color", FALLBACK_COLOR)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(168, 214) if panel_only else Vector2(192, 260)

	# Stylebox for the card background
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.16)
	style.border_color = upgrade_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(12 if panel_only else 18)
	card.add_theme_stylebox_override("panel", style)

	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 6 if panel_only else 10)
	card.add_child(inner)

	var icon := Label.new()
	icon.text = _safe_text(upg, "icon", FALLBACK_ICON)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 22 if panel_only else 28)
	inner.add_child(icon)

	if show_ship_previews:
		var preview := SHIP_PREVIEW_SCRIPT.new() as ShipUpgradePreview
		var player := get_tree().get_first_node_in_group("player_craft")
		var current_upgrades: Array[String] = []
		if player != null and player.has_method("get_active_elite_upgrade_ids"):
			current_upgrades = player.get_active_elite_upgrade_ids()
		preview.configure(current_upgrades, upgrade_id)
		inner.add_child(preview)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = _safe_text(upg, "name", FALLBACK_NAME)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", upgrade_color)
	name_lbl.add_theme_font_size_override("font_size", 16 if panel_only else 20)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(name_lbl)

	# Divider
	var div := HSeparator.new()
	div.add_theme_color_override("color", Color(upgrade_color, 0.35))
	inner.add_child(div)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = _safe_text(upg, "description", FALLBACK_DESCRIPTION)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.88, 1.0))
	desc_lbl.add_theme_font_size_override("font_size", 11 if panel_only else 14)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL if panel_only else Control.SIZE_FILL
	inner.add_child(desc_lbl)

	# Spacer
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 2 if panel_only else 0)
	sp.size_flags_vertical = Control.SIZE_FILL if panel_only else Control.SIZE_EXPAND_FILL
	inner.add_child(sp)

	# Select button
	var btn := Button.new()
	btn.text = "SELECT"
	btn.add_theme_font_size_override("font_size", 14 if panel_only else 17)
	btn.add_theme_color_override("font_color", upgrade_color)
	btn.custom_minimum_size = Vector2(0, 34 if panel_only else 42)
	btn.tooltip_text = _safe_text(upg, "description", FALLBACK_DESCRIPTION)
	btn.pressed.connect(_on_upgrade_selected.bind(upgrade_id))
	inner.add_child(btn)
	card.set_meta("select_button", btn)
	cards_by_id[upgrade_id] = card

	# Hover state changes immediately; upgrade presentation does not tween.
	card.mouse_entered.connect(_on_card_hover.bind(card, style, upgrade_color))
	card.mouse_exited.connect(_on_card_unhover.bind(card, style))

	return card

## Applies the hover state immediately.
func _on_card_hover(card: PanelContainer, style: StyleBoxFlat, color: Color) -> void:
	if selection_locked:
		return
	style.bg_color = Color(color.r * 0.15, color.g * 0.15, color.b * 0.15)
	card.scale = Vector2(1.04, 1.04)

## Restores the idle state immediately.
func _on_card_unhover(card: PanelContainer, style: StyleBoxFlat) -> void:
	if selection_locked:
		return
	style.bg_color = Color(0.06, 0.06, 0.16)
	card.scale = Vector2.ONE


# ── Interaction ────────────────────────────────────────────────────────────────

## Called when a card's SELECT button is pressed. Locks selection to prevent
## double-picks, immediately applies the upgrade, shows static card feedback
## for 0.15 seconds, then signals completion without fading the panel.
func _on_upgrade_selected(upgrade_id: String) -> void:
	if selection_locked:
		return
	var selected_upgrade: Dictionary = {}
	for upgrade in chosen_upgrades:
		if upgrade["id"] == upgrade_id:
			selected_upgrade = upgrade
			break
	if selected_upgrade.is_empty():
		return
	if not is_instance_valid(upgrade_target):
		upgrade_target = get_tree().get_first_node_in_group("player_craft")
	if not is_instance_valid(upgrade_target) or not upgrade_target.has_method("apply_elite_upgrade"):
		if confirmation_label:
			confirmation_label.text = "NATIVE SHIP UNAVAILABLE"
		return
	if not upgrade_target.apply_elite_upgrade(upgrade_id):
		return
	selection_locked = true

	# Record as chosen so it won't appear in future Wave-10 upgrade pools.
	if not GameManager.chosen_upgrade_ids.has(upgrade_id):
		GameManager.chosen_upgrade_ids.append(upgrade_id)

	_show_selection_feedback(upgrade_id, selected_upgrade)
	await get_tree().create_timer(0.15, true, false, true).timeout

	upgrade_chosen.emit()
	# native_3d_run.gd owns the pause state — it unpauses when it receives upgrade_chosen.
	# In panel_only mode the parent is a shared HBoxContainer; native_3d_run.gd cleans up the overlay.
	if not panel_only:
		_close_popup()


func _on_empty_state_continue() -> void:
	if selection_locked:
		return
	selection_locked = true
	upgrade_chosen.emit()
	if not panel_only:
		_close_popup()


func _close_popup() -> void:
	var parent := get_parent()
	if is_instance_valid(parent):
		parent.queue_free()
	else:
		queue_free()


## Locks the completed elite panel in a static selected state while a combined
## milestone screen waits for point allocation to finish.
func _show_selection_feedback(upgrade_id: String, upgrade: Dictionary) -> void:
	var selected_color := _safe_color(upgrade, "color", FALLBACK_COLOR)
	if confirmation_label:
		confirmation_label.text = "SELECTED: " + str(upgrade.get("name", "UPGRADE")).to_upper()
		confirmation_label.add_theme_color_override("font_color", selected_color)
	for id in cards_by_id:
		var card := cards_by_id[id] as PanelContainer
		card.scale = Vector2.ONE
		var button := card.get_meta("select_button") as Button
		button.disabled = true
		if id == upgrade_id:
			button.text = "SELECTED"
			var style := card.get_theme_stylebox("panel") as StyleBoxFlat
			if style:
				style.bg_color = Color(selected_color.r * 0.18, selected_color.g * 0.18, selected_color.b * 0.18)
				style.border_color = Color.WHITE
				style.set_border_width_all(4)
		else:
			card.modulate.a = 0.25
