extends Control
## Command Deck page: title treatment, current objective, the primary
## Expedition action, the latest discovery line, and build/version status.
##
## Emits expedition_requested on launch and open_section(page_id) so the host
## shell can route to other sections. The primary safe action is the Launch
## button; the shell focuses it when the page opens.

signal expedition_requested
signal open_section(page_id: StringName)

const DEFAULT_OBJECTIVE := "Return the signal to the last charted relay"
const DEFAULT_DISCOVERY := "No recovered fragments yet — signal source unknown."

var _payload: Dictionary = {}
var _launch_armed := false

@onready var objective_label: Label = %ObjectiveLabel
@onready var launch_button: Button = %LaunchButton
@onready var map_button: Button = %MapButton
@onready var hangar_button: Button = %HangarButton
@onready var settings_button: Button = %SettingsButton
@onready var discovery_label: Label = %DiscoveryLabel
@onready var version_label: Label = %VersionLabel


func _ready() -> void:
	set_meta(&"frontend_page_id", &"command_deck")
	launch_button.pressed.connect(_on_launch_pressed)
	map_button.pressed.connect(_on_map_pressed)
	hangar_button.pressed.connect(_on_hangar_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	launch_button.tooltip_text = "Launch with your selected hull and challenge modifiers."
	map_button.tooltip_text = "Open the Expedition Map to plan the return route."
	hangar_button.tooltip_text = "Choose your hull and challenge modifiers."
	settings_button.tooltip_text = "Learn the controls or practice your flight skills."
	version_label.text = "BUILD %s  ·  %s  ·  SIGNAL LOCKED" % [_build_version(), MetaProgression.selected_ship.trim_prefix("ship_").to_upper()]
	_apply_payload(_payload)
	_arrange_command_deck()


## Shell page protocol: hands the page its routing payload before first focus.
func setup_payload(payload: Dictionary) -> void:
	_payload = payload.duplicate()
	if is_node_ready():
		_apply_payload(payload)


## Shell page protocol: the control focused whenever the deck opens.
func get_primary_safe_action() -> Control:
	return launch_button


func _apply_payload(payload: Dictionary) -> void:
	var objective := str(payload.get("objective_text", DEFAULT_OBJECTIVE))
	var fragments := ExpeditionManager.get_recovered_fragments()
	var fallback_discovery := DEFAULT_DISCOVERY if fragments.is_empty() else "%d / 4 signal fragments recovered. Read them in Archives." % fragments.size()
	var discovery := str(payload.get("discovery_text", fallback_discovery))
	if _launch_armed:
		objective = "The Expedition is launching — stand by the map."
	objective_label.text = "%s" % objective
	discovery_label.text = "LATEST DISCOVERY  ·  %s" % discovery


func _on_launch_pressed() -> void:
	if _launch_armed:
		return
	if not MetaProgression.is_unlocked(MetaProgression.selected_ship):
		open_section.emit(&"launch_bay")
		return
	_launch_armed = true
	launch_button.disabled = true
	expedition_requested.emit()


func _on_map_pressed() -> void:
	open_section.emit(&"expedition_map")


func _on_hangar_pressed() -> void:
	open_section.emit(&"launch_bay")


func _on_settings_pressed() -> void:
	open_section.emit(&"flight_school")


func _build_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.5.0"))

func _arrange_command_deck() -> void:
	var margin := $Margin
	var column := $Margin/VBox
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	margin.add_child(scroll)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 32)
	scroll.add_child(row)
	column.reparent(row)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.2
	column.custom_minimum_size.x = 320
	var title := column.get_node("Title") as Label
	title.text = "FARINUFF\nFLIGHT ///"
	title.add_theme_font_override("font", NeonUI.HEADING_FONT)
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", NeonUI.WHITE)
	title.add_theme_constant_override("outline_size", 0)
	launch_button.text = "LAUNCH EXPEDITION  >>>"
	launch_button.accessibility_name = "Launch Expedition"
	launch_button.accessibility_description = "Start at Wave 1 with the displayed ship and saved challenge modifiers."
	NeonUI.style_primary(launch_button)
	map_button.text = "ROUTE DETAILS"
	map_button.accessibility_name = "Route details"
	hangar_button.text = "CHANGE LOADOUT"
	hangar_button.accessibility_name = "Change loadout"
	hangar_button.accessibility_description = "Choose your hull and challenge modifiers."
	settings_button.text = "FLIGHT SCHOOL"
	settings_button.accessibility_name = "Flight School"
	settings_button.accessibility_description = "Learn the controls or practice flight skills."
	var hero := VBoxContainer.new()
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(hero)
	var preview := preload("res://entities/player/ship_upgrade_preview.gd").new()
	var modules: Array[String] = []
	preview.render_size = Vector2i(768, 768)
	preview.camera_size = 4.5
	preview.configure(modules, "", MetaProgression.selected_ship)
	preview.custom_minimum_size = Vector2(260, 250)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero.add_child(preview)
	var hull := NeonUI.make_label(MetaProgression.selected_ship.trim_prefix("ship_").to_upper(), 26, NeonUI.CYAN)
	hull.custom_minimum_size.y = 34
	hero.add_child(hull)
	var bonus := MetaProgression.get_salvage_multiplier()
	var mission := NeonUI.make_label("REACH WAVE 20  /  SALVAGE ×%.2f" % bonus, 16)
	mission.custom_minimum_size.y = 28
	hero.add_child(mission)
	version_label.hide()
	row.resized.connect(func():
		hero.visible = row.size.x >= 680
		title.add_theme_font_size_override("font_size", 64 if row.size.x >= 680 else 44)
	)
