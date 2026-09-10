@tool
extends Resource
class_name CampaignDefinition
## Immutable authored campaign catalog consumed by CampaignCatalog.

@export var id: StringName = &""
@export var display_name: String = ""
@export var premise_key: StringName = &""
@export var sector_names: PackedStringArray = PackedStringArray()
@export var start_node_id: StringName = &""
@export var final_node_id: StringName = &""
## Untyped arrays keep external .tres authoring readable; the catalog checks
## every member's concrete Resource class before using it.
@export var nodes: Array[Resource] = []
@export var route_profiles: Array[Resource] = []
@export var boss_milestones: Array[Resource] = []
@export var story_beats: Array[Resource] = []
