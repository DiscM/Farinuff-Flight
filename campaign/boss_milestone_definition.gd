@tool
extends Resource
class_name BossMilestoneDefinition
## Immutable mapping from an authored wave milestone to a production boss.

@export var id: StringName = &""
@export var display_name: String = ""
@export_range(1, 1000, 1) var wave: int = 1
@export_range(0, 4, 1) var production_variant_index: int = 0
