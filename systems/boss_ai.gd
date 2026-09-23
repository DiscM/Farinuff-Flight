extends Node
class_name BossAI
## Finite-state combat controller. All decisions are explicit rules; no ML.
## Health, locomotion, presentation, attack choice and hit detection own their
## data separately. The actor alone writes its world transform.
const Profile := preload("res://systems/boss_combat_profile.gd")
const Selector := preload("res://systems/boss_attack_selector.gd")
const Plan := preload("res://systems/boss_attack_plan.gd")
const Flight := preload("res://systems/boss_flight_orchestrator.gd")
enum State { IDLE, INTRO, REPOSITION, ATTACK, RECOVERY, STUNNED, PHASE_TRANSITION, DEAD }
signal attack_committed(attack_id: StringName)
signal combat_cancelled
const PROFILES: Array[Profile] = [
	preload("res://entities/enemies/ai_profiles/commander.tres"),
	preload("res://entities/enemies/ai_profiles/bulwark.tres"),
	preload("res://entities/enemies/ai_profiles/tempest.tres"),
	preload("res://entities/enemies/ai_profiles/harbinger.tres"),
	preload("res://entities/enemies/ai_profiles/core.tres"),
]
@export var profile_override: Profile
@onready var flight: Flight = $Flight
@onready var executor: BossAttackExecutor = $AttackExecutor
@onready var presentation: BossCombatPresentation = $Presentation
@onready var patterns: BossProjectilePatterns = $ProjectilePatterns
var profile: Profile
var selector := Selector.new()
var state: State = State.IDLE
var phase := 0
var state_remaining := 0.0
var target_position := Vector3.ZERO
var predicted_target := Vector3.ZERO
var distance := 0.0
var radial_speed := 0.0
var _space: FlightSpace3D
var _actor: BasicEnemy3D
var _enabled := false
var _lost_time := 0.0
var _stun_cooldown := 0.0
var _windup_damage := 0
var _sequence := 0

func configure(space: FlightSpace3D, variant: int) -> void:
	_space = space
	_actor = get_parent() as BasicEnemy3D
	profile = profile_override if profile_override != null else PROFILES[clampi(variant, 0, 4)]
	selector.configure(profile)
	flight.configure(space, variant)
	presentation.configure(_actor, space)
	patterns.configure(space, variant, _actor.get("_sections"))
	executor.configure(_actor, space, presentation, patterns)
	_enabled = true
	phase = 0
	_sequence = 0
	_lost_time = 0.0
	_stun_cooldown = 0.0
	state = State.IDLE
	state_remaining = 0.0
	flight.hold(&"idle")

func step(delta: float, target: Node3D) -> Vector3:
	if not _enabled or state == State.DEAD or delta <= 0.0:
		return Vector3.ZERO
	selector.advance(delta)
	_stun_cooldown = maxf(0.0, _stun_cooldown - delta)
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		_enter(State.IDLE)
		return Vector3.ZERO
	_observe(target)
	if state == State.IDLE:
		if distance <= profile.engagement_radius:
			_enter(State.INTRO, profile.intro_duration)
		return Vector3.ZERO
	var disengage := maxf(profile.engagement_radius, profile.disengagement_radius)
	_lost_time = _lost_time + delta if distance > disengage else 0.0
	if _lost_time >= maxf(0.01, profile.disengagement_grace):
		_enter(State.IDLE)
		return Vector3.ZERO
	var face_target := target_position
	if state == State.ATTACK and executor.plan != null:
		# Preserve a heading during charge, rather than facing a fixed point the
		# hull could pass and then turn back toward halfway through the lane.
		face_target = _actor.global_position + _space.screen_motion_to_combat(executor.plan.aim * 400.0)
	presentation.face(delta, face_target, profile.facing_response)
	match state:
		State.INTRO, State.RECOVERY, State.STUNNED, State.PHASE_TRANSITION:
			state_remaining = maxf(0.0, state_remaining - delta)
			if state_remaining <= 0.0:
				_enter(State.REPOSITION)
		State.REPOSITION:
			var attack := selector.choose(distance, radial_speed, phase)
			var bounds := _space.get_combat_bounds(-Flight.ARENA_INSET)
			if attack != null and bounds.has_point(Vector2(_actor.global_position.x, _actor.global_position.z)):
				var plan := Plan.new()
				plan.configure(attack, profile, phase)
				plan.target_position = predicted_target
				plan.aim = _space.combat_motion_to_screen(predicted_target - _actor.global_position).normalized()
				if plan.aim.is_zero_approx():
					plan.aim = Vector2.DOWN
				_sequence += 1
				plan.sequence = _sequence
				selector.commit(attack, phase)
				_enter(State.ATTACK)
				executor.begin(plan)
				attack_committed.emit(attack.id)
				return Vector3.ZERO
			var desired := selector.desired_distance(phase, flight.profile.preferred_distance)
			flight.set_combat_distance(desired)
			flight.set_intent(Flight.Maneuver.INTERCEPT if distance > desired + 40.0 else -1, 0.0, 1.0, &"combat_range")
			return flight.steer(delta, _actor.global_position, _actor.velocity, target_position, predicted_target, phase) * delta
		State.ATTACK:
			var displacement := executor.advance(delta, target)
			if not executor.active:
				var recovery := executor.plan.recovery_seconds
				_enter(State.RECOVERY, recovery)
			return displacement
	return Vector3.ZERO

func _observe(target: Node3D) -> void:
	target_position = target.global_position
	var offset := _space.combat_motion_to_screen(target_position - _actor.global_position)
	distance = offset.length()
	var speed := Vector3.ZERO
	if target is Player3D:
		speed = target.velocity
	var screen_speed := _space.combat_motion_to_screen(speed)
	radial_speed = screen_speed.dot(offset.normalized())
	# Read visible motion, never button state. Cap lead so boosting/changing
	# direction can defeat prediction. Once a tell begins this point is frozen.
	var lead := (screen_speed * profile.prediction_seconds).limit_length(profile.maximum_prediction)
	predicted_target = target_position + _space.screen_motion_to_combat(lead)
	var bounds := _space.get_combat_bounds(-40.0)
	predicted_target.x = clampf(predicted_target.x, bounds.position.x, bounds.end.x)
	predicted_target.z = clampf(predicted_target.z, bounds.position.y, bounds.end.y)

func _enter(next: State, duration: float = 0.0) -> void:
	if state == State.DEAD or state == next:
		return
	if state == State.ATTACK:
		# A one-tick slam still needs its release animation to finish during
		# Recovery. Interruptions, in contrast, cancel the pose immediately.
		executor.cancel(next != State.RECOVERY)
	state = next
	state_remaining = maxf(0.0, duration)
	_windup_damage = 0
	if next != State.REPOSITION:
		flight.hold(StringName(State.keys()[next].to_lower()))
	if next in [State.IDLE, State.STUNNED, State.PHASE_TRANSITION, State.DEAD]:
		executor.cancel()
		combat_cancelled.emit()

func begin_phase(next: int) -> void:
	if not _enabled or state == State.DEAD or next <= phase:
		return
	phase = clampi(next, 0, 2)
	flight.begin_phase(phase)
	# Keep cooldowns and repetition history across phases. An interruption is
	# never a shortcut to a third attack from the same family.
	if state == State.PHASE_TRANSITION:
		state_remaining = profile.phase_transition_duration
		combat_cancelled.emit()
	else:
		_enter(State.PHASE_TRANSITION, profile.phase_transition_duration)

func record_damage(amount: int, maximum_health: int) -> void:
	if state != State.ATTACK or not executor.winding_up or profile.stagger_health_fraction <= 0.0:
		return
	_windup_damage += amount
	if _windup_damage >= maxi(1, ceili(maximum_health * profile.stagger_health_fraction)):
		try_stun()

func try_stun(duration: float = -1.0) -> bool:
	if not _enabled or _stun_cooldown > 0.0 or state in [State.IDLE, State.INTRO, State.STUNNED, State.PHASE_TRANSITION, State.DEAD]:
		return false
	_stun_cooldown = profile.stun_cooldown
	_enter(State.STUNNED, profile.stun_duration if duration < 0.0 else maxf(0.1, duration))
	return true

func can_start_arena_pressure() -> bool:
	return _enabled and profile.enable_arena_pressure and state == State.REPOSITION

func shutdown() -> void:
	if _enabled:
		_enter(State.DEAD)
	_enabled = false
	flight.shutdown()

func get_debug_state() -> Dictionary:
	return {"state": State.keys()[state], "phase": phase, "remaining": state_remaining,
		"distance": distance, "radial_speed": radial_speed, "predicted_target": predicted_target,
		"attack": selector.last_attack, "consecutive": selector.consecutive,
		"cooldowns": selector.cooldowns.duplicate(), "windup": executor.winding_up}
