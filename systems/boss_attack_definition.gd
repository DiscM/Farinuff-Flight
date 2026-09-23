extends Resource
class_name BossAttackDefinition
## Immutable tuning. Cooldowns and repetition history belong to each selector.
enum Family { SLAM, CHARGE, PROJECTILE }

@export var id: StringName = &"projectile"
@export var family: Family = Family.PROJECTILE
@export_range(0, 2) var minimum_phase := 0
@export var alternate_pattern := false
@export_group("Selection (baseline screen pixels)")
@export_range(0.0, 2600.0) var minimum_range := 0.0
@export_range(1.0, 2600.0) var maximum_range := 1500.0
@export_range(0.0, 2600.0) var ideal_range := 450.0
@export_range(0.0, 10.0) var weight := 1.0
## Positive values favor a retreating player; negative values favor an approach.
@export_range(-1.0, 1.0) var retreat_bias := 0.0
@export_group("Timing (seconds)")
@export_range(0.0, 60.0) var cooldown := 5.0
@export_range(0.1, 5.0) var telegraph_duration := 1.2
@export_range(0.1, 5.0) var recovery_duration := 1.5
@export_range(0.05, 3.0) var burst_interval := 0.4
@export_range(1, 6) var burst_count := 3
@export_group("Damage and motion")
## This game uses lives, so one damage removes one life (or the shield).
@export_range(1, 10) var damage := 1
@export_range(10.0, 600.0) var slam_radius := 240.0
@export_range(100.0, 1800.0) var charge_speed := 750.0
@export_range(100.0, 1600.0) var charge_distance := 700.0
@export_range(10.0, 200.0) var charge_half_width := 65.0
@export_range(0.1, 2.0) var projectile_speed_scale := 1.0
