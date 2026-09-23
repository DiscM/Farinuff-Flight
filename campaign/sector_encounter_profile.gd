@tool
extends Resource
class_name SectorEncounterProfile
## Immutable authored encounter weighting for one named route.

const MIN_ARCHETYPE_WEIGHT := 0.0
const MAX_ARCHETYPE_WEIGHT := 10.0

@export var id: StringName = &""
@export var route_name: String = ""
@export_range(MIN_ARCHETYPE_WEIGHT, MAX_ARCHETYPE_WEIGHT, 0.01) var basic_weight: float = 1.0
@export_range(MIN_ARCHETYPE_WEIGHT, MAX_ARCHETYPE_WEIGHT, 0.01) var fast_weight: float = 1.0
@export_range(MIN_ARCHETYPE_WEIGHT, MAX_ARCHETYPE_WEIGHT, 0.01) var bomber_weight: float = 1.0
@export_range(MIN_ARCHETYPE_WEIGHT, MAX_ARCHETYPE_WEIGHT, 0.01) var tank_weight: float = 1.0
@export_range(MIN_ARCHETYPE_WEIGHT, MAX_ARCHETYPE_WEIGHT, 0.01) var sniper_weight: float = 1.0
