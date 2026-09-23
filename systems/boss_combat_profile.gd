extends Resource
class_name BossCombatProfile
## Shared designer data; never store encounter state in a cached Resource.
const Definition := preload("res://systems/boss_attack_definition.gd")

@export var display_name := "Boss"
@export_group("Engagement (baseline screen pixels)")
@export_range(100.0, 2500.0) var engagement_radius := 1400.0
@export_range(100.0, 3000.0) var disengagement_radius := 1700.0
@export_range(0.0, 5.0) var disengagement_grace := 2.0
@export_range(0.0, 2.0) var prediction_seconds := 0.25
@export_range(0.0, 300.0) var maximum_prediction := 100.0
@export_range(0.1, 20.0) var facing_response := 8.0
@export_group("State timing (seconds)")
@export_range(0.1, 5.0) var intro_duration := 1.5
@export_range(0.1, 5.0) var phase_transition_duration := 1.6
@export_range(0.1, 5.0) var stun_duration := 1.4
@export_range(0.1, 20.0) var stun_cooldown := 8.0
## Damage during one windup can stagger the boss. Zero disables this trigger.
@export_range(0.0, 0.5) var stagger_health_fraction := 0.04
@export_range(0.5, 3.0) var minimum_reaction_time := 0.8
@export_group("Phases (remaining HP fraction)")
@export_range(0.31, 0.99) var phase_two_threshold := 0.6
@export_range(0.01, 0.59) var phase_three_threshold := 0.3
@export_range(0.1, 1.0) var phase_two_cooldown_scale := 0.82
@export_range(0.1, 1.0) var phase_three_cooldown_scale := 0.65
@export_range(0.1, 1.0) var phase_two_recovery_scale := 0.9
@export_range(0.1, 1.0) var phase_three_recovery_scale := 0.65
@export_group("Attacks")
@export var attacks: Array[Definition] = []
## Nonzero makes weighted choices reproducible. No learned model or input reads.
@export var selection_seed := 0
@export var enable_arena_pressure := false
@export_group("Targeting and attack style")
## A FEINT breaks into DODGE once its tell has passed this fraction and the
## player is already outside the committed hit solution.
@export_range(0.2, 0.9, 0.05) var feint_cancel_fraction := 0.55
## TRACK retargets its aim at this interval during the tell.
@export_range(0.05, 0.5, 0.01) var track_refresh_seconds := 0.15
@export_group("Targeting predictor")
## Travel speed used to solve where a shot meets the target.
@export_range(50.0, 1200.0, 10.0) var projectile_speed_estimate := 320.0
## Lead horizon for PREDICT and TRACK intercept solutions.
@export_range(0.0, 1.5, 0.05) var intercept_seconds := 0.55
## Hard cap on intercept lead so a boost cannot create an unbounded intercept.
@export_range(0.0, 400.0, 5.0) var maximum_intercept_pixels := 160.0
@export_group("Continuous fire")
## Suppressing shots fired between committed volleys while maneuvering.
@export var support_fire := true
@export_range(0.1, 2.0, 0.01) var support_fire_interval := 0.38
@export_range(50.0, 1200.0, 10.0) var support_fire_speed := 380.0
@export_group("Projectile fire rate")
## Burst spacing tightens with each health phase.
@export_range(0.4, 1.0, 0.05) var phase_two_burst_scale := 0.85
@export_range(0.4, 1.0, 0.05) var phase_three_burst_scale := 0.7

func cooldown_scale(phase: int) -> float:
	return [1.0, phase_two_cooldown_scale, phase_three_cooldown_scale][clampi(phase, 0, 2)]

func recovery_scale(phase: int) -> float:
	return [1.0, phase_two_recovery_scale, phase_three_recovery_scale][clampi(phase, 0, 2)]

func burst_scale(phase: int) -> float:
	return [1.0, phase_two_burst_scale, phase_three_burst_scale][clampi(phase, 0, 2)]
