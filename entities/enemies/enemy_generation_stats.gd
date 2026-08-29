@tool
extends Resource
class_name EnemyGenerationStats
## Spatially independent generation balance, shared by the reference and native actors.

@export_range(1, 10000, 1) var max_health: int = 1
@export_range(0.0, 2000.0, 1.0) var move_speed: float = 150.0
@export_range(0, 100000, 1) var base_points: int = 100
@export_range(1, 99, 1) var orb_value: int = 1
@export_range(0.0, 1.0, 0.01) var orb_drop_chance: float = 0.6
@export var guaranteed_orb: bool = false
