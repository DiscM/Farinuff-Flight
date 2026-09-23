extends Node
class_name BossAI
## Finite-state combat controller. All decisions are explicit rules; no ML.
## Mobility states CHASE, STRAFE and DODGE keep the hull moving around the
## player; ATTACK carries a targeting mode and delivery style chosen at
## commitment. Health, locomotion, presentation, attack choice and hit
## detection own their data separately. The actor alone writes its transform.
const Profile := preload("res://systems/boss_combat_profile.gd")
const Selector := preload("res://systems/boss_attack_selector.gd")
const Plan := preload("res://systems/boss_attack_plan.gd")
const Movement := preload("res://systems/boss_movement_brain.gd")
const Predictor := preload("res://systems/boss_targeting_predictor.gd")
const Projectile := preload("res://entities/projectiles/projectile_3d.gd")
enum State { IDLE, INTRO, CHASE, STRAFE, DODGE, ATTACK, RECOVERY, STUNNED, PHASE_TRANSITION, DEAD }
signal attack_committed(attack_id: StringName)
signal combat_cancelled
const PROFILES: Array[Profile] = [
	preload("res://entities/enemies/ai_profiles/commander.tres"),
	preload("res://entities/enemies/ai_profiles/bulwark.tres"),
	preload("res://entities/enemies/ai_profiles/tempest.tres"),
	preload("res://entities/enemies/ai_profiles/harbinger.tres"),
	preload("res://entities/enemies/ai_profiles/core.tres"),
]
const PROJECTILE_ALERT_PIXELS := 150.0
const CHASE_BAND_PIXELS := 180.0
const RECOVERY_SPEED_SCALE := 0.5
const ATTACK_WINDUP_SPEED_SCALE := 0.55
const PRESENTATION_SPEED_SCALE := 0.35

@export var profile_override: Profile
@onready var movement: Movement = $Movement
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
var lateral_speed := 0.0
var _space: FlightSpace3D
var _actor: BasicEnemy3D
var _enabled := false
var _lost_time := 0.0
var _stun_cooldown := 0.0
var _windup_damage := 0
var _sequence := 0
var _last_targeting: Plan.Targeting = Plan.Targeting.LEAD
var _last_style: Plan.Style = Plan.Style.COMMIT
var _predictor := Predictor.new()
var _support_timer := 0.0

func configure(space: FlightSpace3D, variant: int) -> void:
	_space = space
	_actor = get_parent() as BasicEnemy3D
	profile = profile_override if profile_override != null else PROFILES[clampi(variant, 0, 4)]
	selector.configure(profile)
	movement.configure(space, variant)
	_predictor.configure(space, profile.projectile_speed_estimate)
	presentation.configure(_actor, space)
	patterns.configure(space, variant, _actor.get("_sections"))
	executor.configure(_actor, space, presentation, patterns, _predictor)
	if not executor.feint_broken.is_connected(_on_feint_broken):
		executor.feint_broken.connect(_on_feint_broken)
	_enabled = true
	phase = 0
	_sequence = 0
	_lost_time = 0.0
	_stun_cooldown = 0.0
	_support_timer = profile.support_fire_interval
	state = State.IDLE
	state_remaining = 0.0
	movement.hold(&"idle")

func step(delta: float, target: Node3D) -> Vector3:
	if not _enabled or state == State.DEAD or delta <= 0.0:
		return Vector3.ZERO
	selector.advance(delta)
	_stun_cooldown = maxf(0.0, _stun_cooldown - delta)
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		_enter(State.IDLE)
		return Vector3.ZERO
	_observe(target, delta)
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
		face_target = _actor.global_position + _space.screen_motion_to_combat(executor.plan.aim * 400.0)
	presentation.face(delta, face_target, profile.facing_response)
	match state:
		State.INTRO, State.STUNNED, State.PHASE_TRANSITION:
			state_remaining = maxf(0.0, state_remaining - delta)
			if state_remaining <= 0.0:
				_enter_mobility()
				return Vector3.ZERO
			if state == State.STUNNED:
				return Vector3.ZERO
			return movement.steer(
				delta, _actor.global_position, _actor.velocity,
				target_position, predicted_target, phase
			) * delta
		State.RECOVERY:
			state_remaining = maxf(0.0, state_remaining - delta)
			if state_remaining <= 0.0:
				_enter_mobility()
				return Vector3.ZERO
			return movement.steer(
				delta, _actor.global_position, _actor.velocity,
				target_position, predicted_target, phase
			) * delta
		State.DODGE:
			state_remaining = maxf(0.0, state_remaining - delta)
			if state_remaining <= 0.0:
				_enter_mobility()
				return Vector3.ZERO
			return movement.steer(
				delta, _actor.global_position, _actor.velocity,
				target_position, predicted_target, phase
			) * delta
		State.CHASE, State.STRAFE:
			if _try_begin_dodge():
				return Vector3.ZERO
			_apply_mobility_intent()
			if _try_commit_attack():
				return Vector3.ZERO
			_advance_support_fire(delta)
			return movement.steer(
				delta, _actor.global_position, _actor.velocity,
				target_position, predicted_target, phase
			) * delta
		State.ATTACK:
			var displacement := Vector3.ZERO
			if executor.winding_up:
				movement.set_speed_scale(ATTACK_WINDUP_SPEED_SCALE)
				displacement = movement.steer(
					delta, _actor.global_position, _actor.velocity,
					target_position, predicted_target, phase
				) * delta
			displacement += executor.advance(delta, target)
			if not executor.active and state == State.ATTACK:
				var recovery := 0.1
				if executor.plan != null:
					recovery = executor.plan.recovery_seconds
				_enter(State.RECOVERY, recovery)
			return displacement
	return Vector3.ZERO

func _observe(target: Node3D, delta: float = 0.0) -> void:
	target_position = target.global_position
	var offset := _space.combat_motion_to_screen(target_position - _actor.global_position)
	distance = offset.length()
	var speed := Vector3.ZERO
	if target is Player3D:
		speed = target.velocity
	if delta > 0.0:
		_predictor.advance(delta, target_position, speed)
	var screen_speed := _space.combat_motion_to_screen(speed)
	radial_speed = 0.0 if offset.is_zero_approx() else screen_speed.dot(offset.normalized())
	lateral_speed = 0.0 if offset.is_zero_approx() else screen_speed.dot(offset.normalized().orthogonal())
	var lead := (screen_speed * profile.prediction_seconds).limit_length(profile.maximum_prediction)
	predicted_target = target_position + _space.screen_motion_to_combat(lead)
	var bounds := _space.get_combat_bounds(-40.0)
	predicted_target.x = clampf(predicted_target.x, bounds.position.x, bounds.end.x)
	predicted_target.z = clampf(predicted_target.z, bounds.position.y, bounds.end.y)

func _enter_mobility() -> void:
	if distance > movement.profile.preferred_distance + CHASE_BAND_PIXELS:
		_enter(State.CHASE)
	else:
		_enter(State.STRAFE)

func _apply_mobility_intent() -> void:
	if state == State.CHASE:
		movement.mode = Movement.Mode.CHASE
		movement.reason = &"close_gap"
	elif state == State.STRAFE:
		movement.mode = Movement.Mode.STRAFE
		movement.reason = &"strafe_ring"
	movement.set_combat_distance(selector.desired_distance(phase, movement.profile.preferred_distance))
	movement.set_speed_scale(RECOVERY_SPEED_SCALE if state == State.RECOVERY else 1.0)

func _try_begin_dodge() -> bool:
	if state not in [State.CHASE, State.STRAFE]:
		return false
	var threat := _find_incoming_projectile()
	if threat == null:
		return false
	var shot_direction := _space.combat_motion_to_screen(threat.velocity).normalized()
	var offset := _space.combat_motion_to_screen(_actor.global_position - threat.global_position)
	var side := signf(shot_direction.cross(offset)) if not is_zero_approx(shot_direction.cross(offset)) else 1.0
	if movement.request_dodge(shot_direction, side):
		_enter(State.DODGE, movement.dodge_remaining)
		return true
	return false

func _find_incoming_projectile() -> Projectile:
	var alert_squared := PROJECTILE_ALERT_PIXELS * PROJECTILE_ALERT_PIXELS
	for node in get_tree().get_nodes_in_group(&"player_projectiles"):
		var projectile := node as Projectile
		if projectile == null or not projectile.is_active:
			continue
		var offset := _space.combat_motion_to_screen(
			_actor.global_position - projectile.global_position
		)
		if offset.is_zero_approx() or offset.length_squared() > alert_squared:
			continue
		var shot_direction := _space.combat_motion_to_screen(projectile.velocity).normalized()
		if shot_direction.dot(offset.normalized()) <= 0.72:
			continue
		return projectile
	return null

func _try_commit_attack() -> bool:
	var attack := selector.choose(distance, radial_speed, phase)
	var bounds := _space.get_combat_bounds(-Movement.ARENA_INSET)
	if attack == null or not bounds.has_point(Vector2(_actor.global_position.x, _actor.global_position.z)):
		return false
	var plan := Plan.new()
	plan.configure(attack, profile, phase)
	plan.apply_style(_choose_style(), profile)
	plan.targeting = _choose_targeting(attack)
	plan.apply_targeting(plan.targeting)
	plan.target_position = predicted_target
	plan.aim = _compute_aim(plan.targeting)
	_sequence += 1
	plan.sequence = _sequence
	selector.commit(attack, phase)
	_last_targeting = plan.targeting
	_last_style = plan.style
	_enter(State.ATTACK)
	executor.begin(plan)
	attack_committed.emit(attack.id)
	return true

func _advance_support_fire(delta: float) -> void:
	if not profile.support_fire:
		return
	_support_timer = maxf(0.0, _support_timer - delta)
	if _support_timer > 0.0:
		return
	_support_timer = maxf(0.1, profile.support_fire_interval * profile.burst_scale(phase))
	var muzzle := _actor.get_socket(&"MuzzleCenter") as Marker3D
	var origin := muzzle.global_position if muzzle != null else _actor.global_position
	patterns.fire_support(_compute_aim(Plan.Targeting.PREDICT), origin, profile.support_fire_speed)


func _compute_aim(targeting: Plan.Targeting) -> Vector2:
	var from := _actor.global_position
	var toward := target_position
	match targeting:
		Plan.Targeting.LEAD:
			toward = _predictor.solve_intercept(
				from, profile.prediction_seconds, profile.maximum_prediction
			)
		Plan.Targeting.PREDICT, Plan.Targeting.TRACK:
			toward = _predictor.solve_intercept(
				from, profile.intercept_seconds, profile.maximum_intercept_pixels
			)
		_:
			toward = target_position
	var aim := _space.combat_motion_to_screen(toward - from).normalized()
	return aim if not aim.is_zero_approx() else Vector2.DOWN

func _choose_targeting(attack: BossAttackDefinition) -> Plan.Targeting:
	if attack.family == BossAttackDefinition.Family.CHARGE:
		return Plan.Targeting.LEAD
	if attack.family == BossAttackDefinition.Family.PROJECTILE:
		if phase >= 1 and _sequence % 3 == 2:
			return Plan.Targeting.TRACK
		return Plan.Targeting.PREDICT
	if radial_speed < -150.0:
		return Plan.Targeting.SNAP
	if absf(lateral_speed) > 220.0:
		return Plan.Targeting.BRACKET
	if attack.family == BossAttackDefinition.Family.SLAM:
		return Plan.Targeting.SNAP
	return Plan.Targeting.PREDICT

func _choose_style() -> Plan.Style:
	if phase >= 2:
		return Plan.Style.SURGE if _sequence % 2 == 0 else Plan.Style.COMMIT
	if phase >= 1 and _sequence % 3 == 2:
		return Plan.Style.SURGE
	return Plan.Style.FEINT if _sequence % 4 == 3 else Plan.Style.COMMIT

func _on_feint_broken() -> void:
	if state != State.ATTACK or not _enabled:
		return
	combat_cancelled.emit()
	var threat := _find_incoming_projectile()
	var side := 1.0
	if threat != null:
		var shot_direction := _space.combat_motion_to_screen(threat.velocity).normalized()
		var offset := _space.combat_motion_to_screen(_actor.global_position - threat.global_position)
		var cross := shot_direction.cross(offset)
		side = signf(cross) if not is_zero_approx(cross) else 1.0
	if movement.request_dodge(Vector2.DOWN, side):
		_enter(State.DODGE, movement.dodge_remaining)
	else:
		_enter_mobility()

func _enter(next: State, duration: float = 0.0) -> void:
	if state == State.DEAD or state == next:
		return
	if state == State.ATTACK:
		executor.cancel(next != State.RECOVERY)
	state = next
	state_remaining = maxf(0.0, duration)
	_windup_damage = 0
	match next:
		State.CHASE, State.STRAFE, State.RECOVERY, State.ATTACK, State.INTRO, State.PHASE_TRANSITION:
			movement.release_hold(StringName(State.keys()[next].to_lower()))
			var scale := 1.0
			if next == State.RECOVERY:
				scale = RECOVERY_SPEED_SCALE
			elif next == State.ATTACK:
				scale = ATTACK_WINDUP_SPEED_SCALE
			elif next in [State.INTRO, State.PHASE_TRANSITION]:
				scale = PRESENTATION_SPEED_SCALE
			movement.set_speed_scale(scale)
		State.DODGE:
			movement.release_hold(&"dodge")
		_:
			movement.hold(StringName(State.keys()[next].to_lower()))
	if next in [State.IDLE, State.STUNNED, State.PHASE_TRANSITION, State.DEAD]:
		executor.cancel()
		combat_cancelled.emit()
	if next == State.CHASE:
		movement.mode = Movement.Mode.CHASE
	elif next == State.STRAFE:
		movement.mode = Movement.Mode.STRAFE

func begin_phase(next: int) -> void:
	if not _enabled or state == State.DEAD or next <= phase:
		return
	phase = clampi(next, 0, 2)
	movement.begin_phase(phase)
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
	return _enabled and profile.enable_arena_pressure and state in [State.CHASE, State.STRAFE]

func shutdown() -> void:
	if _enabled:
		_enter(State.DEAD)
	_enabled = false
	movement.shutdown()

func get_debug_state() -> Dictionary:
	return {
		"state": State.keys()[state],
		"phase": phase,
		"remaining": state_remaining,
		"distance": distance,
		"radial_speed": radial_speed,
		"lateral_speed": lateral_speed,
		"predicted_target": predicted_target,
		"attack": selector.last_attack,
		"consecutive": selector.consecutive,
		"cooldowns": selector.cooldowns.duplicate(),
		"windup": executor.winding_up,
		"targeting": Plan.Targeting.keys()[_last_targeting],
		"support_remaining": _support_timer,
		"style": Plan.Style.keys()[_last_style],
		"movement": movement.get_debug_state(),
	}
