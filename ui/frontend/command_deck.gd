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
	launch_button.tooltip_text = "Review the Expedition chart, then choose your hull and modifiers in the Launch Bay."
	map_button.tooltip_text = "Open the Expedition Map to plan the return route."
	hangar_button.tooltip_text = "Open the Hangar to spend salvage and adjust the loadout."
	settings_button.tooltip_text = "Open Settings to adjust audio, display, and accessibility."
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
	var fallback_discovery := DEFAULT_DISCOVERY if fragments.is_empty() else "%d / 4 signal fragments recovered. Open the chart to read the Archives." % fragments.size()
	var discovery := str(payload.get("discovery_text", fallback_discovery))
	if _launch_armed:
		objective = "The Expedition is launching — stand by the map."
	objective_label.text = "%s" % objective
	discovery_label.text = "LATEST DISCOVERY  ·  %s" % discovery


func _on_launch_pressed() -> void:
	open_section.emit(&"expedition_map")


func _on_map_pressed() -> void:
	open_section.emit(&"expedition_map")


func _on_hangar_pressed() -> void:
	open_section.emit(&"hangar")


func _on_settings_pressed() -> void:
	open_section.emit(&"settings")


func _build_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.5.0"))

func _arrange_command_deck() -> void:
	var margin := $Margin
	var column := $Margin/VBox
	margin.remove_child(column)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	margin.add_child(scroll)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var preview := preload("res://entities/player/ship_upgrade_preview.gd").new()
	var modules: Array[String] = []
	preview.configure(modules, "", MetaProgression.selected_ship)
	preview.custom_minimum_size = Vector2(280, 140)
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(preview)
	column.move_child(preview, 2)
