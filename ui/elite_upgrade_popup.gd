extends Control
## Elite upgrade popup — shown after the Wave 10 (elite) boss is defeated.
## Presents 3 randomly selected ship transformation options; player picks one, then game resumes.

signal upgrade_chosen

# ── Upgrade Definitions ────────────────────────────────────────────────────────

const ALL_UPGRADES: Array[Dictionary] = [
	# ── Original 5 ─────────────────────────────────────────────────────────────
	{
		"id": "twin_cannons",
		"name": "Twin Cannons",
		"icon": "🔫",
		"description": "Fire two parallel bullets\nwith every shot.",
		"color": Color(1.0, 0.8, 0.2),
	},
	{
		"id": "auto_aim",
		"name": "Auto-Aim Core",
		"icon": "🎯",
		"description": "Bullets home in on\nthe nearest enemy.",
		"color": Color(0.3, 1.0, 0.5),
	},
	{
		"id": "drone_escort",
		"name": "Drone Escort",
		"icon": "🤖",
		"description": "A combat drone joins you,\nauto-firing at enemies.",
		"color": Color(0.4, 0.85, 1.0),
	},
	{
		"id": "hull_plating",
		"name": "Hull Plating",
		"icon": "🛡️",
		"description": "Reinforce the hull.\nGain +2 max lives.",
		"color": Color(0.8, 0.55, 1.0),
	},
	{
		"id": "afterburner",
		"name": "Afterburner",
		"icon": "🚀",
		"description": "+25% speed and snappier\nmaneuverability.",
		"color": Color(1.0, 0.45, 0.15),
	},
	# ── New Wave-10 Upgrades ────────────────────────────────────────────────────
	{
		"id": "spread_shot_elite",
		"name": "Spread Shot",
		"icon": "✦",
		"description": "Fire a permanent 3-way fan.\nStacks with Twin Cannons → 5 bullets.",
		"color": Color(1.0, 0.55, 0.9),
	},
	{
		"id": "shield_burst",
		"name": "Shield Burst",
		"icon": "💥",
		"description": "Every 8 s, emit a shockwave\nthat clears bullets & damages enemies.",
		"color": Color(0.3, 0.8, 1.0),
	},
	{
		"id": "magnet_field",
		"name": "Orb Magnet",
		"icon": "🧲",
		"description": "Permanently attract XP orbs\nand power-ups (faster pull).",
		"color": Color(1.0, 0.75, 0.1),
	},
	{
		"id": "overclock",
		"name": "Overclock",
		"icon": "⚡",
		"description": "Triple fire rate for 3 s\nevery 15 s. Stacks with Rapid Fire.",
		"color": Color(0.9, 1.0, 0.2),
	},
	{
		"id": "rear_gunner",
		"name": "Rear Gunner",
		"icon": "🔺",
		"description": "A rear cannon fires backward\neach shot. Inherits all bullet mods.",
		"color": Color(1.0, 0.35, 0.35),
	},
]

var chosen_upgrades: Array[Dictionary] = []

# ── Setup ──────────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pick_upgrades()
	_build_ui()
	_animate_in()

func _pick_upgrades() -> void:
	# Exclude upgrades that were chosen in previous Wave-10 events this run.
	var pool: Array[Dictionary] = []
	for upg in ALL_UPGRADES:
		if not GameManager.chosen_upgrade_ids.has(upg["id"]):
			pool.append(upg)
	pool.shuffle()
	chosen_upgrades = pool.slice(0, 3)

# ── UI ─────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Full-screen dark overlay
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.05, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Outer vertical container
	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.set_offsets_preset(Control.PRESET_FULL_RECT)
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_theme_constant_override("separation", 24)
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
	title.add_theme_font_size_override("font_size", 34)
	outer.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Choose one permanent upgrade for your ship"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.75, 1.0))
	subtitle.add_theme_font_size_override("font_size", 16)
	outer.add_child(subtitle)

	# Cards row
	var cards_row := HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cards_row.add_theme_constant_override("separation", 28)
	outer.add_child(cards_row)

	for upg in chosen_upgrades:
		cards_row.add_child(_make_card(upg))

func _make_card(upg: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(192, 260)

	# Stylebox for the card background
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.16)
	style.border_color = upg["color"]
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", style)

	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 10)
	card.add_child(inner)

	# Icon
	var icon_lbl := Label.new()
	icon_lbl.text = upg["icon"]
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 48)
	inner.add_child(icon_lbl)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = upg["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", upg["color"])
	name_lbl.add_theme_font_size_override("font_size", 20)
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
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(desc_lbl)

	# Spacer
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(sp)

	# Select button
	var btn := Button.new()
	btn.text = "SELECT"
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", upg["color"])
	btn.custom_minimum_size = Vector2(0, 42)
	btn.pressed.connect(_on_upgrade_selected.bind(upg["id"]))
	inner.add_child(btn)

	# Hover glow effect
	card.mouse_entered.connect(_on_card_hover.bind(card, style, upg["color"]))
	card.mouse_exited.connect(_on_card_unhover.bind(card, style))

	return card

func _on_card_hover(card: PanelContainer, style: StyleBoxFlat, color: Color) -> void:
	var tween := card.create_tween()
	tween.tween_method(func(c: Color): style.bg_color = c,
		style.bg_color, Color(color.r * 0.15, color.g * 0.15, color.b * 0.15), 0.12)
	tween.parallel().tween_property(card, "scale", Vector2(1.04, 1.04), 0.1).set_ease(Tween.EASE_OUT)

func _on_card_unhover(card: PanelContainer, style: StyleBoxFlat) -> void:
	var tween := card.create_tween()
	tween.tween_method(func(c: Color): style.bg_color = c,
		style.bg_color, Color(0.06, 0.06, 0.16), 0.12)
	tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.1).set_ease(Tween.EASE_OUT)

# ── Interaction ────────────────────────────────────────────────────────────────

func _on_upgrade_selected(upgrade_id: String) -> void:
	# Record as chosen so it won't appear in future Wave-10 upgrade pools.
	GameManager.chosen_upgrade_ids.append(upgrade_id)

	# Apply to player
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var player := players[0]
		match upgrade_id:
			"twin_cannons":      player.grant_twin_cannons()
			"auto_aim":          player.grant_auto_aim()
			"drone_escort":      player.grant_drone_escort()
			"hull_plating":      player.grant_hull_plating()
			"afterburner":       player.grant_afterburner()
			"spread_shot_elite": player.grant_spread_shot_elite()
			"shield_burst":      player.grant_shield_burst()
			"magnet_field":      player.grant_magnet_field()
			"overclock":         player.grant_overclock()
			"rear_gunner":       player.grant_rear_gunner()

	upgrade_chosen.emit()
	# game.gd owns the pause state — it unpauses when it receives upgrade_chosen.
	get_parent().queue_free()

# ── Animation ──────────────────────────────────────────────────────────────────

func _animate_in() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "position:y", 0.0, 0.4)\
		.from(30.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
