extends Node
class_name BossAttackExecutor
## Runs one committed attack. It cannot choose, retarget, or skip its warning.
const Definition := preload("res://systems/boss_attack_definition.gd")
const Flight := preload("res://systems/boss_flight_orchestrator.gd")
signal released(attack_id: StringName)
var plan: BossAttackPlan
var winding_up := false
var active := false
var elapsed := 0.0
var _charge_elapsed := 0.0
var _burst_timer := 0.0
var _burst_step := 0
var _space: FlightSpace3D
var _actor: BasicEnemy3D
var _presentation: BossCombatPresentation
var _patterns: BossProjectilePatterns
var _hit_victims: Dictionary[int, bool] = {}

func configure(actor: BasicEnemy3D, space: FlightSpace3D, presentation: BossCombatPresentation, patterns: BossProjectilePatterns) -> void:
	_actor = actor
	_space = space
	_presentation = presentation
	_patterns = patterns
	cancel()

func begin(snapshot: BossAttackPlan) -> void:
	cancel()
	plan = snapshot
	plan.origin = _actor.global_position
	plan.charge_endpoint = _charge_endpoint(plan)
	elapsed = 0.0
	_charge_elapsed = 0.0
	_burst_timer = 0.0
	_burst_step = 0
	_hit_victims.clear()
	winding_up = true
	active = true
	_presentation.telegraph(plan)
	_actor.charge_started.emit(plan.origin, _space.input_to_combat_direction(plan.aim))

func _charge_endpoint(snapshot: BossAttackPlan) -> Vector3:
	var direction := _space.screen_motion_to_combat(snapshot.aim)
	var distance := snapshot.definition.charge_distance
	var bounds := _space.get_combat_bounds(-Flight.ARENA_INSET)
	# Intersect a ray with the arena. Clamping X/Z independently would bend the
	# advertised lane and let the boss turn after the player had read the tell.
	if not is_zero_approx(direction.x):
		var edge: float = bounds.end.x if direction.x > 0.0 else bounds.position.x
		distance = minf(distance, maxf(0.0, (edge - snapshot.origin.x) / direction.x))
	if not is_zero_approx(direction.z):
		var edge: float = bounds.end.y if direction.z > 0.0 else bounds.position.y
		distance = minf(distance, maxf(0.0, (edge - snapshot.origin.z) / direction.z))
	return snapshot.origin + direction * distance

## Returns displacement for the actor to apply; there is one transform writer.
func advance(delta: float, target: Node3D) -> Vector3:
	if not active or delta <= 0.0:
		return Vector3.ZERO
	if winding_up:
		elapsed += delta
		_presentation.progress(clampf(elapsed / plan.warning_seconds, 0.0, 1.0))
		if elapsed >= plan.warning_seconds:
			winding_up = false
			_presentation.release()
			released.emit(plan.definition.id)
			_actor.charge_released.emit(plan.origin, _space.input_to_combat_direction(plan.aim))
		# Do not spend a long frame twice across a state boundary. Damage starts
		# on the next tick, after at least the entire promised reaction window.
		return Vector3.ZERO
	match plan.definition.family:
		Definition.Family.SLAM:
			_circle_hit(target, plan.origin, plan.definition.slam_radius, plan.definition.damage)
			active = false
		Definition.Family.CHARGE:
			var length := _space.combat_motion_to_screen(plan.charge_endpoint - plan.origin).length()
			var duration := length / maxf(1.0, plan.definition.charge_speed)
			_charge_elapsed += delta
			var progress := clampf(_charge_elapsed / maxf(0.001, duration), 0.0, 1.0)
			var next := plan.origin.lerp(plan.charge_endpoint, progress)
			_sweep_hit(target, _actor.global_position, next, plan.definition.charge_half_width, plan.definition.damage)
			active = progress < 1.0
			return next - _actor.global_position
		Definition.Family.PROJECTILE:
			_patterns.advance(delta)
			_burst_timer -= delta
			var count := maxi(1, plan.definition.burst_count + plan.phase)
			if _burst_step < count and _burst_timer <= 0.0:
				_presentation.attack_pulse()
				_patterns.fire(plan, _burst_step)
				_burst_step += 1
				_burst_timer = plan.definition.burst_interval
			active = _burst_step < count or _patterns.has_pending()
	return Vector3.ZERO

func cancel(reset_motion: bool = true) -> void:
	active = false
	winding_up = false
	plan = null
	if _patterns != null:
		_patterns.cancel()
	if _presentation != null:
		_presentation.clear(reset_motion)

## One hit per target per attack, including across many frames of a charge.
func _circle_hit(target: Node3D, center: Vector3, radius: float, damage: int) -> bool:
	return _sweep_hit(target, center, center, radius, damage)


func _sweep_hit(target: Node3D, start: Vector3, finish: Vector3, half_width: float, damage: int) -> bool:
	if not is_instance_valid(target) or not target.has_method("receive_damage"):
		return false
	var id := target.get_instance_id()
	if _hit_victims.has(id):
		return false
	var offset := _space.combat_motion_to_screen(target.global_position - start)
	var segment := _space.combat_motion_to_screen(finish - start)
	var progress := clampf(offset.dot(segment) / segment.length_squared(), 0.0, 1.0) if segment.length_squared() > 0.001 else 0.0
	if offset.distance_to(segment * progress) > half_width:
		return false
	_hit_victims[id] = true # A shield/boost also consumes this attack's single hit.
	return target.receive_damage(finish, Player3D.DamageSource.ENEMY_CONTACT, damage)
