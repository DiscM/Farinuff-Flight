extends PanelContainer
## Debug-build command panel for exercising the native 3D run in place.

signal force_close

const NativeUpgrades := preload("res://entities/player/native_player_upgrades.gd")

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
	"orbitals": "Orbital Array",
	"piercing": "Piercing Rounds",
	"explosive_rounds": "Explosive Rounds",
}
const BOSS_VARIANTS: Array[StringName] = [
	&"assault", &"bulwark", &"tempest", &"harbinger", &"core",
]
const ENEMY_ARCHETYPES: Array[StringName] = [
	&"basic", &"fast", &"tank", &"bomber", &"sniper",
]

var _elite_checks: Dictionary[String, CheckButton] = {}
var _enemy_state_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = Vector2(390.0, 0.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.075, 0.055, 0.98)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	style.border_color = Color(0.2, 0.8, 0.3, 0.65)
	style.set_border_width_all(2)
	add_theme_stylebox_override("panel", style)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var title := Label.new()
	title.text = "DEV / DEBUG"
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
	_build_enemy_debug(content)
	_build_visual_debug(content)
	set_process(true)


func _process(_delta: float) -> void:
	if _enemy_state_label == null:
		return
	var gameplay := _get_gameplay()
	_enemy_state_label.text = gameplay.get_dev_debug_state() if gameplay != null else "Native run unavailable"


func _build_run_actions(parent: VBoxContainer) -> void:
	_add_section(parent, "RUN ACTIONS")
	_add_button(parent, "+ 50 Orbs", _on_add_orbs)
	_add_button(parent, "Clear Hostiles", _on_clear_hostiles)
	_add_button(parent, "Spawn Elite Boss", _on_spawn_boss.bind(&"bulwark"))
	_add_button(parent, "Spawn Tempest Core", _on_spawn_boss.bind(&"core"))
	_add_button(parent, "Trigger Elite Upgrade", _on_elite_upgrade)
	_add_button(parent, "Trigger Point Allocation", _on_point_allocation)
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
		["orbitals", "Orbitals Override"],
		["piercing", "Piercing Override"],
		["explosive_rounds", "Explosive Override"],
	]:
		var power_id: String = definition[0]
		var label: String = definition[1]
		var active := bool(player.get_dev_power_override(power_id)) if player != null else false
		_add_check(parent, label, active, _on_power_toggled.bind(power_id))


func _build_elite_upgrades(parent: VBoxContainer) -> void:
	_add_section(parent, "ELITE UPGRADES")
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	parent.add_child(actions)
	_add_button(actions, "Grant All", _on_grant_all_elites)
	_add_button(actions, "Clear All", _on_clear_all_elites)

	var player := _get_player()
	for upgrade_id in NativeUpgrades.SUPPORTED_IDS:
		var definition := _get_upgrade_definition(upgrade_id)
		var active := bool(player.is_elite_upgrade_enabled(upgrade_id)) if player != null else false
		var label := str(ELITE_LABELS.get(upgrade_id, upgrade_id.capitalize()))
		var check := _add_check(parent, label, active, _on_elite_toggled.bind(upgrade_id))
		check.add_theme_color_override("font_color", definition.get("color", Color.WHITE))
		_elite_checks[upgrade_id] = check


func _build_enemy_debug(parent: VBoxContainer) -> void:
	_add_section(parent, "ENEMY DEBUG")
	var generation_row := HBoxContainer.new()
	generation_row.add_theme_constant_override("separation", 4)
	parent.add_child(generation_row)
	for generation in range(1, 5):
		_add_button(generation_row, "GEN %d" % generation, _on_force_generation.bind(generation))

	var spawn_grid := GridContainer.new()
	spawn_grid.columns = 2
	spawn_grid.add_theme_constant_override("h_separation", 5)
	spawn_grid.add_theme_constant_override("v_separation", 5)
	parent.add_child(spawn_grid)
	for kind in ENEMY_ARCHETYPES:
		_add_button(spawn_grid, "Spawn " + String(kind).capitalize(), _on_spawn_archetype.bind(kind))
	_add_button(parent, "Trigger On-Screen Abilities", _on_trigger_enemy_abilities)

	var boss_grid := GridContainer.new()
	boss_grid.columns = 2
	boss_grid.add_theme_constant_override("h_separation", 5)
	boss_grid.add_theme_constant_override("v_separation", 5)
	parent.add_child(boss_grid)
	for variant in BOSS_VARIANTS:
		_add_button(boss_grid, "Boss " + String(variant).capitalize(), _on_spawn_boss.bind(variant))

	_enemy_state_label = Label.new()
	_enemy_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_enemy_state_label.add_theme_font_size_override("font_size", 11)
	_enemy_state_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.25))
	parent.add_child(_enemy_state_label)


func _build_visual_debug(parent: VBoxContainer) -> void:
	_add_section(parent, "VISUAL DEBUG")
	for definition in [
		["envelope", "104 × 96 Envelope"],
		["anchors", "Attachment Anchors"],
		["muzzles", "Muzzle Origins"],
		["collision", "Collision Capsule"],
	]:
		var flag: String = definition[0]
		var player := _get_player()
		var active := bool(player.get_visual_debug(flag)) if player != null else false
		_add_check(parent, definition[1], active, _on_debug_toggled.bind(flag))


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
	button.pressed.connect(AudioManager.play_ui_click)
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


func _get_gameplay() -> Node:
	var gameplay := get_tree().get_first_node_in_group(&"native_3d_gameplay")
	return gameplay if gameplay != null and gameplay.has_method(&"dev_spawn_archetype") else null


func _get_player() -> Node:
	return get_tree().get_first_node_in_group(&"player_craft")


func _get_upgrade_definition(upgrade_id: String) -> Dictionary:
	for definition in GameManager.ALL_UPGRADES + GameManager.META_ELITE_UPGRADES:
		if str(definition.get("id", "")) == upgrade_id:
			return definition
	return {}


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
	for upgrade_id in NativeUpgrades.SUPPORTED_IDS:
		player.set_elite_upgrade_enabled(upgrade_id, true, false)
		_elite_checks[upgrade_id].set_pressed_no_signal(true)


func _on_clear_all_elites() -> void:
	var player := _get_player()
	if player == null:
		return
	player.clear_elite_upgrades()
	for check in _elite_checks.values():
		check.set_pressed_no_signal(false)


func _on_debug_toggled(enabled: bool, flag: String) -> void:
	var player := _get_player()
	if player != null:
		player.set_visual_debug(flag, enabled)


func _on_add_orbs() -> void:
	var gameplay := _get_gameplay()
	if gameplay != null:
		gameplay.dev_add_orbs(50)


func _on_clear_hostiles() -> void:
	var gameplay := _get_gameplay()
	if gameplay != null:
		gameplay.dev_clear_hostiles()


func _on_spawn_boss(variant: StringName) -> void:
	var gameplay := _get_gameplay()
	if gameplay == null:
		return
	force_close.emit()
	gameplay.dev_spawn_boss_variant(variant)


func _on_elite_upgrade() -> void:
	var gameplay := _get_gameplay()
	if gameplay == null:
		return
	force_close.emit()
	gameplay.dev_trigger_elite_reward()


func _on_point_allocation() -> void:
	var gameplay := _get_gameplay()
	if gameplay == null:
		return
	force_close.emit()
	gameplay.dev_trigger_point_allocation(3)


func _on_add_lives() -> void:
	var gameplay := _get_gameplay()
	if gameplay != null:
		gameplay.dev_add_lives(5)


func _on_force_generation(generation: int) -> void:
	var gameplay := _get_gameplay()
	if gameplay != null:
		gameplay.dev_force_generation(generation)


func _on_spawn_archetype(kind: StringName) -> void:
	var gameplay := _get_gameplay()
	if gameplay != null:
		gameplay.dev_spawn_archetype(kind)


func _on_trigger_enemy_abilities() -> void:
	var gameplay := _get_gameplay()
	if gameplay != null:
		gameplay.dev_trigger_enemy_abilities()
