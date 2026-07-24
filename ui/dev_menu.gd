extends PanelContainer
## Scrollable developer tools panel embedded inside the pause menu.

signal force_close

const ELITE_LABELS := {
	"twin_cannons": "Twin Cannons",
	"auto_aim": "Auto-Aim Core",
	"drone_escort": "Drone Escort",
	"hull_plating": "Hull Plating",
	"afterburner": "Afterburner",
	"spread_shot_elite": "Spread Shot",
	"shield_burst": "Shield Burst",
	"magnet_field": "Orb Magnet",
	"overclock": "Overclock",
	"rear_gunner": "Rear Gunner",
}

var _elite_checks: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = Vector2(350, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.10, 0.05, 0.97)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	style.border_color = Color(0.2, 0.8, 0.3, 0.6)
	style.set_border_width_all(2)
	add_theme_stylebox_override("panel", style)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var title := Label.new()
	title.text = "🛠  DEV TOOLS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	title.add_theme_font_size_override("font_size", 16)
	root.add_child(title)
	root.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)

	_build_run_actions(content)
	_build_player_state(content)
	_build_elite_upgrades(content)
	_build_visual_debug(content)


func _build_run_actions(parent: VBoxContainer) -> void:
	_add_section(parent, "RUN ACTIONS")
	_add_button(parent, "+ 50 Orbs", _on_add_orbs)
	_add_button(parent, "Clear Enemies", _on_clear_enemies)
	_add_button(parent, "Spawn Elite Boss", _on_spawn_elite_boss)
	_add_button(parent, "Spawn Tempest Core", _on_spawn_tempest_core)
	_add_button(parent, "Trigger Elite Upgrade", _on_elite_upgrade)
	_add_button(parent, "Trigger Point Alloc", _on_point_allocation)
	_add_button(parent, "+ 5 Lives", _on_add_lives)


func _build_player_state(parent: VBoxContainer) -> void:
	_add_section(parent, "PLAYER STATE")
	var player := _get_player()
	_add_check(
		parent,
		"God Mode",
		bool(player.dev_god_mode) if player != null else false,
		_on_god_mode_toggled
	)
	for definition in [
		["rapid_fire", "Rapid Fire"],
		["spread_shot", "Spread Shot"],
		["orbitals", "Orbitals"],
		["piercing", "Piercing"],
		["explosive_rounds", "Explosive Rounds"],
	]:
		var power_id: String = definition[0]
		var label: String = definition[1]
		var active := bool(player.get_dev_power_override(power_id)) if player != null else false
		_add_check(parent, label, active, _on_power_toggled.bind(power_id))


func _build_elite_upgrades(parent: VBoxContainer) -> void:
	_add_section(parent, "ELITE UPGRADES")
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	parent.add_child(buttons)
	_add_button(buttons, "Grant All", _on_grant_all_elites)
	_add_button(buttons, "Clear All", _on_clear_all_elites)

	var player := _get_player()
	for upgrade in GameManager.ALL_UPGRADES:
		var id := str(upgrade["id"])
		var active := bool(player.is_elite_upgrade_enabled(id)) if player != null else false
		var check := _add_check(parent, str(ELITE_LABELS.get(id, upgrade["name"])), active, _on_elite_toggled.bind(id))
		check.add_theme_color_override("font_color", upgrade["color"])
		_elite_checks[id] = check


func _build_visual_debug(parent: VBoxContainer) -> void:
	_add_section(parent, "VISUAL DEBUG")
	for definition in [
		["envelope", "104 × 96 Envelope"],
		["anchors", "Attachment Anchors"],
		["muzzles", "Muzzle Origins"],
		["collision", "Collision Capsule"],
	]:
		var flag: String = definition[0]
		_add_check(parent, definition[1], false, _on_debug_toggled.bind(flag))


func _add_section(parent: VBoxContainer, text: String) -> void:
	var separator := HSeparator.new()
	separator.custom_minimum_size.y = 8
	parent.add_child(separator)
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65))
	label.add_theme_font_size_override("font_size", 13)
	parent.add_child(label)


func _add_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85))
	button.custom_minimum_size = Vector2(0, 28)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _add_check(parent: Node, text: String, active: bool, callback: Callable) -> CheckButton:
	var check := CheckButton.new()
	check.text = text
	check.button_pressed = active
	check.add_theme_font_size_override("font_size", 13)
	check.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85))
	check.focus_mode = Control.FOCUS_NONE
	check.toggled.connect(callback)
	parent.add_child(check)
	return check


func _get_player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _on_power_toggled(enabled: bool, power_id: String) -> void:
	var player := _get_player()
	if player != null:
		player.set_dev_power_override(power_id, enabled)


func _on_god_mode_toggled(enabled: bool) -> void:
	var player := _get_player()
	if player != null:
		player.set_dev_god_mode(enabled)


func _on_elite_toggled(enabled: bool, upgrade_id: String) -> void:
	var player := _get_player()
	if player != null:
		player.set_elite_upgrade_enabled(upgrade_id, enabled, false)


func _on_grant_all_elites() -> void:
	var player := _get_player()
	if player == null:
		return
	for upgrade in GameManager.ALL_UPGRADES:
		var id := str(upgrade["id"])
		player.set_elite_upgrade_enabled(id, true, false)
		var check := _elite_checks.get(id) as CheckButton
		if check != null:
			check.set_pressed_no_signal(true)


func _on_clear_all_elites() -> void:
	var player := _get_player()
	if player == null:
		return
	player.clear_elite_upgrades()
	for check in _elite_checks.values():
		(check as CheckButton).set_pressed_no_signal(false)


func _on_debug_toggled(enabled: bool, flag: String) -> void:
	var player := _get_player()
	if player != null:
		player.set_visual_debug(flag, enabled)


func _on_add_orbs() -> void:
	SignalBus.xp_orb_collected.emit(50)


func _on_clear_enemies() -> void:
	get_tree().call_group("enemies", "take_damage", 9999)
	get_tree().call_group("tempest_sections", "take_damage", 9999)
	get_tree().call_group("enemy_bullets", "despawn")


func _on_spawn_elite_boss() -> void:
	force_close.emit()
	GameManager.current_wave = 10
	GameManager.boss_active = true
	SignalBus.wave_started.emit(10)


func _on_spawn_tempest_core() -> void:
	force_close.emit()
	GameManager.current_wave = 20
	GameManager.boss_active = true
	SignalBus.wave_started.emit(20)


func _on_elite_upgrade() -> void:
	force_close.emit()
	SignalBus.elite_upgrade_triggered.emit()


func _on_point_allocation() -> void:
	force_close.emit()
	SignalBus.allocation_triggered.emit(3)


func _on_add_lives() -> void:
	GameManager.lives += 5
	SignalBus.lives_changed.emit(GameManager.lives)
