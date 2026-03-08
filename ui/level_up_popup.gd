extends Control
## Level-up popup — pauses game, shows 3 random upgrade choices.
## Offers a mix of stat boosts and unique permanent weapons/effects.

signal upgrade_chosen

# Stat boost upgrades (always available, stackable)
const STAT_UPGRADES: Array[Dictionary] = [
	{"id": "speed", "label": "🚀  +1% SPEED", "color": Color(0.3, 0.85, 1.0), "desc": "Move faster (max 5 stacks)", "unique": false},
	{"id": "fire_rate", "label": "🔥  +5% FIRE RATE", "color": Color(1.0, 0.75, 0.15), "desc": "Shoot faster (max 20 stacks)", "unique": false},
	{"id": "damage", "label": "💥  +1 DAMAGE", "color": Color(1.0, 0.35, 0.25), "desc": "Bullets hit harder", "unique": false},
	{"id": "shield", "label": "🛡️  SHIELD", "color": Color(0.3, 0.95, 0.55), "desc": "Block one hit", "unique": false},
	{"id": "life", "label": "❤️  +1 LIFE", "color": Color(1.0, 0.4, 0.55), "desc": "Extra life", "unique": false},
]

# Unique permanent upgrades (removed from pool once picked)
const UNIQUE_UPGRADES: Array[Dictionary] = [
	{"id": "rear_gun", "label": "🔙  REAR GUN", "color": Color(0.9, 0.5, 0.2), "desc": "Fire bullets backward too", "unique": true},
	{"id": "piercing", "label": "⚡  PIERCING SHOTS", "color": Color(0.4, 0.9, 1.0), "desc": "Bullets pass through enemies", "unique": true},
	{"id": "orbitals", "label": "🌀  ORBITALS", "color": Color(0.4, 1.0, 0.85), "desc": "Orbiting shields that damage enemies", "unique": true},
	{"id": "zigzag", "label": "〰️  ZIG-ZAG SHOTS", "color": Color(0.85, 0.7, 1.0), "desc": "Bullets weave side to side (stackable!)", "unique": false},
	{"id": "explosive_rounds", "label": "💣  EXPLOSIVE ROUNDS", "color": Color(1.0, 0.45, 0.15), "desc": "Bullets explode on impact for area damage", "unique": true},
]

var offered_upgrades: Array[Dictionary] = []

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var level_label: Label = $VBoxContainer/LevelLabel
@onready var button_container: VBoxContainer = $VBoxContainer/ButtonContainer

func _ready() -> void:
	# Ensure this UI processes even when tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pick_upgrades()
	_build_buttons()
	_animate_in()

func _pick_upgrades() -> void:
	# Get player reference to check which unique upgrades are already owned
	var player: Area2D = null
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

	# Build available pool: all stat upgrades + unowned unique upgrades
	var pool: Array[Dictionary] = []
	for u in STAT_UPGRADES:
		pool.append(u)

	for u in UNIQUE_UPGRADES:
		if player and _player_has_upgrade(player, u["id"]):
			continue  # Already owned, skip
		pool.append(u)

	pool.shuffle()

	# Pick 3, ensuring at least 1 unique if available
	offered_upgrades = []
	var unique_offered := false

	for u in pool:
		if offered_upgrades.size() >= 3:
			break
		if u["unique"] and not unique_offered:
			offered_upgrades.insert(0, u)
			unique_offered = true
		else:
			offered_upgrades.append(u)

	# If we still have fewer than 3, fill from remaining
	if offered_upgrades.size() < 3:
		for u in pool:
			if offered_upgrades.size() >= 3:
				break
			if u not in offered_upgrades:
				offered_upgrades.append(u)

func _player_has_upgrade(player: Area2D, upgrade_id: String) -> bool:
	match upgrade_id:
		"speed":
			return GameManager.speed_stacks >= 5
		"fire_rate":
			return GameManager.fire_rate_stacks >= 20
		"rear_gun":
			return player.has_rear_gun
		"piercing":
			return player.has_piercing
		"orbitals":
			return player.has_orbitals
		"explosive_rounds":
			return player.has_explosive_rounds
		"zigzag":
			return player.zigzag_stacks >= 10  # Capped at 10 stacks
	return false

func _build_buttons() -> void:
	level_label.text = "LEVEL " + str(GameManager.level)

	for i in range(offered_upgrades.size()):
		var data: Dictionary = offered_upgrades[i]
		var btn := Button.new()
		btn.text = data["label"]
		btn.custom_minimum_size = Vector2(340, 55)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_color_override("font_color", data["color"])
		btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
		btn.tooltip_text = data["desc"]

		# Unique upgrades get a ★ prefix to stand out
		if data["unique"]:
			btn.text = "★ " + btn.text

		var upgrade_id: String = data["id"]
		btn.pressed.connect(_on_upgrade_picked.bind(upgrade_id))
		button_container.add_child(btn)

func _on_upgrade_picked(upgrade_id: String) -> void:
	GameManager.apply_upgrade(upgrade_id)

	# Handle player-specific upgrades
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player: Area2D = players[0]
		match upgrade_id:
			"shield":
				player.grant_shield()
			"magnet":
				player.grant_magnet_extended()
			"rear_gun":
				player.grant_rear_gun()
			"piercing":
				player.grant_piercing()
			"orbitals":
				player.grant_orbitals()
			"explosive_rounds":
				player.grant_explosive_rounds()
			"zigzag":
				player.grant_zigzag()

	upgrade_chosen.emit()

	# Unpause and remove
	get_tree().paused = false
	# Remove the parent CanvasLayer
	get_parent().queue_free()

func _animate_in() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
