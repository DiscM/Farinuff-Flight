@tool
extends Resource
class_name RouteNodeDefinition
## Immutable authored map-node data for one Expedition sector or route.

@export var id: StringName = &""
@export var display_name: String = ""
@export var description_key: StringName = &""
@export_range(1, 4, 1) var sector_index: int = 1
@export_range(1, 20, 1) var first_wave: int = 1
@export_range(1, 20, 1) var last_wave: int = 5
@export var map_position := Vector2.ZERO
@export var outgoing_node_ids: Array[StringName] = []
@export var boss_variant_id: StringName = &""
## Fixed sectors intentionally leave this empty; route sectors resolve one of
## the four authored SectorEncounterProfile resources.
@export var encounter_profile_id: StringName = &""
@export var briefing_beat_id: StringName = &""
@export var debrief_beat_id: StringName = &""
@export var fragment_beat_id: StringName = &""
@export var threat_tags: PackedStringArray = PackedStringArray()
@export var accent_id: StringName = &""
@export var discovery_glyph_id: StringName = &""
@export var completion_glyph_id: StringName = &""
