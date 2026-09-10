@tool
extends Resource
class_name SectorEncounterProfile
## Immutable authored encounter weighting for one named route.
##
## Route profiles only change archetype weights in the MVP. The remaining
## multipliers are explicit neutral extension points and must stay bounded.

const MIN_MULTIPLIER := 0.5
const MAX_MULTIPLIER := 2.0
const MIN_ARCHETYPE_WEIGHT := 0.0
const MAX_ARCHETYPE_WEIGHT := 10.0

@export var id: StringName = &""
@export var route_name: String = ""
@export var threat_tags: PackedStringArray = PackedStringArray()
@export_range(MIN_ARCHETYPE_WEIGHT, MAX_ARCHETYPE_WEIGHT, 0.01) var basic_weight: float = 1.0
@export_range(MIN_ARCHETYPE_WEIGHT, MAX_ARCHETYPE_WEIGHT, 0.01) var fast_weight: float = 1.0
@export_range(MIN_ARCHETYPE_WEIGHT, MAX_ARCHETYPE_WEIGHT, 0.01) var bomber_weight: float = 1.0
@export_range(MIN_ARCHETYPE_WEIGHT, MAX_ARCHETYPE_WEIGHT, 0.01) var tank_weight: float = 1.0
@export_range(MIN_ARCHETYPE_WEIGHT, MAX_ARCHETYPE_WEIGHT, 0.01) var sniper_weight: float = 1.0
@export_range(MIN_MULTIPLIER, MAX_MULTIPLIER, 0.01) var spawn_multiplier: float = 1.0
@export_range(MIN_MULTIPLIER, MAX_MULTIPLIER, 0.01) var orb_multiplier: float = 1.0
@export_range(MIN_MULTIPLIER, MAX_MULTIPLIER, 0.01) var pickup_multiplier: float = 1.0
@export_range(MIN_MULTIPLIER, MAX_MULTIPLIER, 0.01) var threat_budget_multiplier: float = 1.0


func multipliers_are_neutral() -> bool:
	return (
		is_equal_approx(spawn_multiplier, 1.0)
		and is_equal_approx(orb_multiplier, 1.0)
		and is_equal_approx(pickup_multiplier, 1.0)
		and is_equal_approx(threat_budget_multiplier, 1.0)
	)
