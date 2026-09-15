extends RefCounted
class_name BossAttackPlan
## A committed attack snapshot. Aim and damage never change after its tell.
const Definition := preload("res://systems/boss_attack_definition.gd")
var definition: Definition
var origin := Vector3.ZERO
var target_position := Vector3.ZERO
var charge_endpoint := Vector3.ZERO
var aim := Vector2.DOWN
var phase := 0
var warning_seconds := 1.0
var recovery_seconds := 1.0
var sequence := 0

func configure(attack: Definition, tuning: BossCombatProfile, health_phase: int) -> void:
	definition = attack.duplicate(true) as Definition
	phase = health_phase
	warning_seconds = maxf(tuning.minimum_reaction_time, definition.telegraph_duration)
	recovery_seconds = maxf(0.1, definition.recovery_duration * tuning.recovery_scale(phase))
