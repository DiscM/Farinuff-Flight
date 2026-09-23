extends RefCounted
class_name BossAttackPlan
## A committed attack snapshot. Aim and damage never change after its tell
## except for TRACK targeting, which refreshes its aim through the predictor
## at a capped rate until release. Targeting and style are chosen by the
## combat FSM at commitment.
const Definition := preload("res://systems/boss_attack_definition.gd")

enum Targeting { LEAD, SNAP, TRACK, BRACKET, PREDICT }
enum Style { COMMIT, SURGE, FEINT }

const TRACK_TURN_RADIANS := 1.4
const BRACKET_WIDTH_SCALE := 1.45

var definition: Definition
var origin := Vector3.ZERO
var target_position := Vector3.ZERO
var charge_endpoint := Vector3.ZERO
var aim := Vector2.DOWN
var phase := 0
var warning_seconds := 1.0
var recovery_seconds := 1.0
var burst_interval_seconds := 0.4
var sequence := 0
var targeting: Targeting = Targeting.LEAD
var style: Style = Style.COMMIT
var feint_cancelled := false
var feint_cancel_fraction := 0.55
var track_refresh_seconds := 0.15
var intercept_seconds := 0.55
var maximum_intercept_pixels := 160.0


func configure(attack: Definition, tuning: BossCombatProfile, health_phase: int) -> void:
	definition = attack.duplicate(true) as Definition
	phase = health_phase
	warning_seconds = maxf(tuning.minimum_reaction_time, definition.telegraph_duration)
	recovery_seconds = maxf(0.1, definition.recovery_duration * tuning.recovery_scale(phase))
	burst_interval_seconds = maxf(0.05, definition.burst_interval * tuning.burst_scale(phase))
	feint_cancel_fraction = tuning.feint_cancel_fraction
	track_refresh_seconds = tuning.track_refresh_seconds
	intercept_seconds = tuning.intercept_seconds
	maximum_intercept_pixels = tuning.maximum_intercept_pixels


func apply_style(next: Style, tuning: BossCombatProfile) -> void:
	style = next
	match style:
		Style.SURGE:
			warning_seconds = maxf(tuning.minimum_reaction_time, warning_seconds * 0.85)
			recovery_seconds = maxf(0.1, recovery_seconds * 0.55)
			burst_interval_seconds = maxf(0.05, burst_interval_seconds * 0.85)
		Style.FEINT:
			warning_seconds = maxf(tuning.minimum_reaction_time, warning_seconds * 1.1)
		_:
			pass


func apply_targeting(next: Targeting) -> void:
	targeting = next
	match targeting:
		Targeting.SNAP:
			warning_seconds *= 0.85
		Targeting.BRACKET:
			definition.charge_half_width = minf(
				definition.charge_half_width * BRACKET_WIDTH_SCALE,
				200.0
			)
			definition.slam_radius = minf(definition.slam_radius * BRACKET_WIDTH_SCALE, 600.0)
			definition.burst_count = mini(definition.burst_count + 1, 6)
		Targeting.PREDICT:
			burst_interval_seconds = maxf(0.05, burst_interval_seconds * 0.9)
		_:
			pass


## TRACK refreshes aim at a capped angular rate so a reversing player can still
## defeat it, while a steady approach cannot simply ignore the tell.
func track_aim_toward(desired: Vector2) -> void:
	if targeting != Targeting.TRACK or desired.is_zero_approx() or aim.is_zero_approx():
		return
	var turn := clampf(aim.angle_to(desired), -TRACK_TURN_RADIANS, TRACK_TURN_RADIANS)
	aim = aim.rotated(turn)
