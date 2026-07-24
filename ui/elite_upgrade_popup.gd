extends Control
## Elite upgrade popup — shown after the Wave 10 (elite) boss is defeated.
## Presents 3 randomly selected ship transformation options; player picks one, then game resumes.

signal upgrade_chosen

const SHIP_PREVIEW_SCRIPT := preload("res://entities/player/ship_upgrade_preview.gd")

# ── Upgrade Definitions ────────────────────────────────────────────────────────

# (Upgrades moved to GameManager to allow for global completion checks)

var chosen_upgrades: Array[Dictionary] = []
var cards_by_id: Dictionary = {}
var selection_locked: bool = false
var confirmation_label: Label = null

# When true, no fullscreen overlay bg is drawn — used for side-by-side layout
var panel_only: bool = false

# ── Setup ──────────────────────────────────────────────────────────────────────

## Picks 3 random upgrades from the available pool, builds the card-based
## UI, and plays the entrance animation.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pick_upgrades()
	_build_ui()
	_animate_in()

## Selects up to 3 upgrades from ALL_UPGRADES, excluding any that have
## already been chosen in this run. Shuffles the pool for random selection.
func _pick_upgrades() -> void:
	# Exclude upgrades that were chosen in previous Wave-10 events this run.
	var pool: Array[Dictionary] = []
	for upg in GameManager.ALL_UPGRADES:
		if not GameManager.chosen_upgrade_ids.has(upg["id"]):
			pool.append(upg)
	pool.shuffle()
	chosen_upgrades = pool.slice(0, 3)

# ── UI ─────────────────────────────────────────────────────────────────────────

## Constructs the elite upgrade UI: optional dark overlay, title/subtitle
## labels, and a horizontal row of upgrade cards — each showing an icon,
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
	title.text = "✦  SHIP TRANSFORMATION  ✦"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3))
	title.add_theme_font_size_override("font_size", 26 if compact_layout else 34)
	outer.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Choose one permanent upgrade for your ship"
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

	for upg in chosen_upgrades:
		cards_row.add_child(_make_card(upg))

## Creates a single upgrade card panel: styled border in the upgrade's color,
## icon, name, description, and a SELECT button. Registers hover effects for
## the glow animation.
func _make_card(upg: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(168, 214) if panel_only else Vector2(192, 260)

	# Stylebox for the card background
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.16)
	style.border_color = upg["color"]
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(12 if panel_only else 18)
	card.add_theme_stylebox_override("panel", style)

	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 6 if panel_only else 10)
	card.add_child(inner)

	# Current-build preview with the candidate module highlighted.
	var preview := SHIP_PREVIEW_SCRIPT.new() as ShipUpgradePreview
	var player := get_tree().get_first_node_in_group("player")
	var current_upgrades: Array[String] = []
	if player != null and player.has_method("get_active_elite_upgrade_ids"):
		current_upgrades = player.get_active_elite_upgrade_ids()
	preview.configure(current_upgrades, str(upg["id"]))
	inner.add_child(preview)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = upg["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", upg["color"])
	name_lbl.add_theme_font_size_override("font_size", 16 if panel_only else 20)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(name_lbl)

	# Divider
	var div := HSeparator.new()
	div.add_theme_color_override("color", Color(upg["color"], 0.35))
	inner.add_child(div)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = upg["description"]
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
	btn.add_theme_color_override("font_color", upg["color"])
	btn.custom_minimum_size = Vector2(0, 34 if panel_only else 42)
	btn.pressed.connect(_on_upgrade_selected.bind(upg["id"]))
	inner.add_child(btn)
	card.set_meta("select_button", btn)
	cards_by_id[upg["id"]] = card

	# Hover glow effect
	card.mouse_entered.connect(_on_card_hover.bind(card, style, upg["color"]))
	card.mouse_exited.connect(_on_card_unhover.bind(card, style))

	return card

## Animates a subtle background glow and slight scale-up when the mouse
## hovers over an upgrade card.
func _on_card_hover(card: PanelContainer, style: StyleBoxFlat, color: Color) -> void:
	var tween := card.create_tween()
	tween.tween_method(func(c: Color): style.bg_color = c,
		style.bg_color, Color(color.r * 0.15, color.g * 0.15, color.b * 0.15), 0.12)
	tween.parallel().tween_property(card, "scale", Vector2(1.04, 1.04), 0.1).set_ease(Tween.EASE_OUT)

## Reverts the card's background and scale when the mouse leaves.
func _on_card_unhover(card: PanelContainer, style: StyleBoxFlat) -> void:
	var tween := card.create_tween()
	tween.tween_method(func(c: Color): style.bg_color = c,
		style.bg_color, Color(0.06, 0.06, 0.16), 0.12)
	tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.1).set_ease(Tween.EASE_OUT)

# ── Interaction ────────────────────────────────────────────────────────────────

## Called when a card's SELECT button is pressed. Locks selection to prevent
## double-picks, shows visual feedback on the chosen/unchosen cards, waits
## briefly, records the upgrade as chosen in GameManager, applies it to the
## player, emits upgrade_chosen, and cleans up the popup.
func _on_upgrade_selected(upgrade_id: String) -> void:
	if selection_locked:
		return
	selection_locked = true
	var selected_upgrade: Dictionary = {}
	for upgrade in chosen_upgrades:
		if upgrade["id"] == upgrade_id:
			selected_upgrade = upgrade
			break
	_show_selection_feedback(upgrade_id, selected_upgrade)
	await get_tree().create_timer(0.30, true, false, true).timeout

	# Record as chosen so it won't appear in future Wave-10 upgrade pools.
	if not GameManager.chosen_upgrade_ids.has(upgrade_id):
		GameManager.chosen_upgrade_ids.append(upgrade_id)

	# Fade the selection UI away, then install the module on the actual
	# paused gameplay ship before resuming.
	var player = get_tree().get_first_node_in_group("player")
	var installation_cover := _get_installation_cover()
	var fade := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(installation_cover, "modulate:a", 0.0, 0.18).set_ease(Tween.EASE_IN)
	await fade.finished
	if player != null and player.has_method("install_elite_upgrade"):
		await player.install_elite_upgrade(upgrade_id, true)
	if panel_only:
		var restore := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		restore.tween_property(installation_cover, "modulate:a", 1.0, 0.15).set_ease(Tween.EASE_OUT)
		await restore.finished

	upgrade_chosen.emit()
	# game.gd owns the pause state — it unpauses when it receives upgrade_chosen.
	# In panel_only mode the parent is a shared HBoxContainer; game.gd cleans up the overlay.
	if not panel_only:
		get_parent().queue_free()


func _get_installation_cover() -> CanvasItem:
	if not panel_only:
		return self
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.get_parent() is CanvasLayer:
			return ancestor as CanvasItem
		ancestor = ancestor.get_parent()
	return self

## Provides visual feedback after selection: highlights the chosen card
## (white border, scale pulse, tinted background), fades out unchosen cards,
## disables all SELECT buttons, and updates the subtitle to show the
## installed upgrade name.
func _show_selection_feedback(upgrade_id: String, upgrade: Dictionary) -> void:
	var selected_color: Color = upgrade.get("color", Color(0.3, 1.0, 0.6))
	if confirmation_label:
		confirmation_label.text = "INSTALLED: " + str(upgrade.get("name", "UPGRADE")).to_upper()
		confirmation_label.add_theme_color_override("font_color", selected_color)
	for id in cards_by_id:
		var card := cards_by_id[id] as PanelContainer
		var button := card.get_meta("select_button") as Button
		button.disabled = true
		if id == upgrade_id:
			var style := card.get_theme_stylebox("panel") as StyleBoxFlat
			if style:
				style.bg_color = Color(selected_color.r * 0.18, selected_color.g * 0.18, selected_color.b * 0.18)
				style.border_color = Color.WHITE
				style.set_border_width_all(4)
			var tween := card.create_tween()
			tween.tween_property(card, "scale", Vector2(1.08, 1.08), 0.12).set_ease(Tween.EASE_OUT)
			tween.tween_property(card, "scale", Vector2(1.03, 1.03), 0.16).set_ease(Tween.EASE_IN_OUT)
		else:
			var tween := card.create_tween()
			tween.tween_property(card, "modulate:a", 0.25, 0.16)

# ── Animation ──────────────────────────────────────────────────────────────────

## Plays a fade-in and slide-up entrance animation for the popup.
func _animate_in() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "position:y", 0.0, 0.4)\
		.from(30.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
