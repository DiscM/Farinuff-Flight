extends Native3DGameplay
## Behavioral contracts through real boss/player/pooled-projectile components.
const BossScene := preload("res://entities/enemies/boss_enemy_3d.tscn")
const Boss := preload("res://entities/enemies/boss_enemy_3d.gd")
const AI := preload("res://systems/boss_ai.gd")
const Definition := preload("res://systems/boss_attack_definition.gd")
const Selector := preload("res://systems/boss_attack_selector.gd")
const Health := preload("res://systems/boss_health.gd")
const Tuning := preload("res://entities/enemies/ai_profiles/commander.tres")
var _failures: Array[String] = []
var _fired := 0

func _ready() -> void:
	await super._ready()
	_run.call_deferred()

func _run() -> void:
	player.set_physics_process(false)
	player.set_dev_god_mode(true)
	GameManager.boss_active = true
	flight_space._physics_process(0.0)
	projectile_manager.projectile_fired.connect(_record_shot)
	_check_selection()
	_check_health()
	await _check_states()
	await _check_interruptions()
	await _check_damage()
	await _check_mobility_variety()
	await _check_repertoire()
	GameManager.is_game_active = false
	for failure in _failures:
		push_error(failure)
	print("BOSS_AI_SMOKE_PASS" if _failures.is_empty() else "BOSS_AI_SMOKE_FAIL")
	get_tree().quit(0 if _failures.is_empty() else 1)

func _check_selection() -> void:
	var tuning := Tuning.duplicate(true) as BossCombatProfile
	tuning.selection_seed = 73
	var selector := Selector.new()
	selector.configure(tuning)
	var slam := tuning.attacks[0]
	var charge := tuning.attacks[1]
	var projectile := tuning.attacks[2]
	var alternate := tuning.attacks[3]
	_expect(selector.choose(120, -100, 0) == slam, "Close range chooses slam")
	_expect(selector.score(charge, 600, 0, 0) == 0 and selector.score(charge, 600, 0, 1) > 0, "Charge unlocks in phase two")
	_expect(selector.score(alternate, 600, 0, 1) == 0 and selector.score(alternate, 600, 0, 2) > 0, "Alternate projectile unlocks only in phase three")
	_expect(selector.score(slam, 600, 0, 2) == 0 and selector.choose(2000, 0, 2) == null, "Attack ranges are hard constraints")
	_expect(selector.score(charge, 600, 300, 1) > selector.score(charge, 600, -300, 1), "Charge weight favors a retreating player")
	_expect(selector.score(slam, 180, -300, 0) > selector.score(slam, 180, 300, 0), "Slam weight favors an approaching player")
	selector.commit(projectile, 0)
	_expect(selector.choose(600, 0, 0) == null, "Unavailable attacks produce a wait rather than ignore cooldowns")
	selector.advance(projectile.cooldown)
	_expect(selector.score(projectile, 600, 0, 0) > 0, "Cooldown becomes available on expiry")
	selector.commit(projectile, 0)
	selector.advance(60.0)
	_expect(selector.score(projectile, 600, 0, 2) == 0 and selector.score(alternate, 600, 0, 2) == 0, "Both projectile patterns share the strict two-repeat limit")
	_expect(selector.choose(120, 0, 0) == slam and selector.desired_distance(0, 400) <= slam.maximum_range, "Reposition closes into a legal alternative instead of deadlocking")
	var second := Selector.new()
	second.configure(tuning)
	selector.configure(tuning)
	var last := -1
	var streak := 0
	for index in 200:
		var attack := selector.choose(600, 120, 2)
		var replay := second.choose(600, 120, 2)
		_expect(attack != null and replay != null and attack.id == replay.id, "Seeded weighted selection is reproducible")
		if attack == null:
			break
		streak = streak + 1 if last == attack.family else 1
		last = attack.family
		_expect(streak <= 2, "No three consecutive attacks of one family")
		selector.commit(attack, 2)
		second.commit(replay, 2)
		selector.advance(60)
		second.advance(60)
	_expect(is_equal_approx(tuning.attacks[2].cooldown, 5.0), "Encounter state never mutates shared tuning")

func _check_health() -> void:
	var health_component := Health.new()
	add_child(health_component)
	health_component.configure(100, .6, .3)
	health_component.apply_damage(39)
	_expect(health_component.phase == 0, "61 percent is phase one")
	health_component.apply_damage(1)
	_expect(health_component.phase == 1, "60 percent starts phase two")
	health_component.apply_damage(30)
	_expect(health_component.phase == 1, "Exactly 30 percent remains phase two")
	health_component.apply_damage(1)
	_expect(health_component.phase == 2, "Below 30 percent starts phase three")
	health_component.apply_damage(-10)
	_expect(health_component.current == 29, "Negative damage cannot heal or resurrect")
	health_component.apply_damage(999)
	_expect(health_component.current == 0 and health_component.apply_damage(1) == 0, "Death clamps health and is idempotent")
	health_component.configure(100, .6, .3)
	health_component.apply_damage(71)
	_expect(health_component.phase == 2, "One large hit skips directly to the correct phase")
	health_component.configure(100, .7, .2)
	health_component.apply_damage(30)
	_expect(health_component.phase == 1, "Custom phase boundaries are respected")
	health_component.queue_free()

func _spawn(variant: int = 0) -> Boss:
	var boss := BossScene.instantiate() as Boss
	actors_root.add_child(boss)
	boss.dev_variant_override = variant
	boss._boss_ai.profile_override = AI.PROFILES[variant].duplicate(true) as BossCombatProfile
	boss._boss_ai.profile_override.selection_seed = 27
	_expect(boss.activate_generation(flight_space, Vector3.ZERO, Vector3.BACK, 1), "Boss activates with component wiring")
	boss.set_physics_process(false)
	boss._arena_patterns.set_physics_process(false)
	player.velocity = Vector3.ZERO
	return boss

func _check_states() -> void:
	var boss := _spawn()
	var ai := boss._boss_ai
	player.global_position = flight_space.screen_motion_to_combat(Vector2(0, 2000))
	boss._advance_movement(5.0)
	_expect(ai.state == AI.State.IDLE and _fired == 0, "Idle ignores players outside engagement radius")
	player.global_position = flight_space.screen_motion_to_combat(Vector2(0, 420))
	boss._advance_movement(.01)
	_expect(ai.state == AI.State.INTRO, "Entering radius starts Intro")
	boss._advance_movement(20.0)
	_expect(
		ai.state in [AI.State.CHASE, AI.State.STRAFE] and _fired == 0,
		"A long frame cannot skip Intro into an untelegraphed attack"
	)
	boss._advance_movement(.01)
	_expect(ai.state == AI.State.ATTACK and ai.executor.winding_up, "Mobility states choose an eligible attack")
	var plan := ai.executor.plan
	var origin := boss.global_position
	player.global_position += flight_space.screen_motion_to_combat(Vector2(300, 0))
	player.velocity = flight_space.screen_motion_to_combat(Vector2(500, 0))
	boss._advance_movement(.1)
	_expect(plan.aim == Vector2.DOWN and boss.global_position == origin, "Windup locks aim and holds the hull while the player changes direction")
	var elapsed := ai.executor.elapsed
	var cooldowns := ai.selector.cooldowns.duplicate()
	GameManager.is_game_active = false
	boss._physics_process(20.0)
	GameManager.is_game_active = true
	_expect(ai.executor.elapsed == elapsed and ai.selector.cooldowns == cooldowns, "Pause freezes warnings and cooldowns")
	boss._advance_movement(plan.warning_seconds - elapsed - .01)
	_expect(_fired == 0 and ai.executor.winding_up, "No projectile damage before the full telegraph")
	boss._advance_movement(.02)
	_expect(not ai.executor.winding_up and _fired == 0, "Release boundary does not compress the next execution tick")
	for beat in 8:
		boss._advance_movement(.91)
		if ai.state == AI.State.RECOVERY:
			break
	_expect(ai.state == AI.State.RECOVERY and _fired > 0, "A completed volley enters Recovery")
	_expect(boss._motions[0].current_clip == &"attack", "Entering Recovery preserves the final release animation")
	var count := _fired
	boss._advance_movement(plan.recovery_seconds - .01)
	_expect(ai.state == AI.State.RECOVERY and _fired == count, "Recovery leaves a full attack-free punish window")
	boss._advance_movement(.02)
	_expect(ai.state in [AI.State.CHASE, AI.State.STRAFE], "Recovery returns to mobility")
	_expect(boss.stun(), "Stun is a reachable state")
	_expect(ai.state == AI.State.STUNNED and not boss.stun(), "Stun cooldown prevents repeated stun-lock")
	boss._advance_movement(ai.profile.stun_duration + .01)
	_expect(ai.state in [AI.State.CHASE, AI.State.STRAFE], "Stun expires into mobility")
	# Start another tell, then cross the HP boundary while it is winding up.
	for attack in ai.profile.attacks:
		ai.selector.cooldowns[attack.id] = 0.0
	boss._advance_movement(.01)
	_expect(ai.state == AI.State.ATTACK, "Second committed attack starts")
	cooldowns = ai.selector.cooldowns.duplicate()
	var consecutive := ai.selector.consecutive
	boss.take_damage(ceili(boss.max_health * .4))
	_expect(boss.phase == 1 and ai.state == AI.State.PHASE_TRANSITION and not ai.executor.active, "Health phase cancels the old attack")
	_expect(ai.selector.cooldowns == cooldowns and ai.selector.consecutive == consecutive, "Phase changes preserve spent cooldowns and repetition history")
	count = _fired
	boss._advance_movement(ai.profile.phase_transition_duration - .01)
	_expect(_fired == count and ai.state == AI.State.PHASE_TRANSITION, "Phase transition grants its full breathing window")
	boss._advance_movement(.02)
	player.remove_from_group(&"player_craft")
	boss._advance_movement(.01)
	_expect(ai.state == AI.State.IDLE and not ai.executor.active, "Missing player cancels offense and returns Idle")
	player.add_to_group(&"player_craft")
	boss._advance_movement(.01)
	_expect(ai.state == AI.State.INTRO, "Reacquisition repeats Intro instead of immediately attacking")
	boss._advance_movement(ai.profile.intro_duration + .01)
	boss._advance_movement(.01)
	player.global_position = flight_space.screen_motion_to_combat(Vector2(0, 2300))
	boss._advance_movement(ai.profile.disengagement_grace + .01)
	_expect(ai.state == AI.State.IDLE, "Disengagement radius and grace suspend combat")
	boss._before_finish(BasicEnemy.FinishReason.ESCAPED, boss.global_position)
	count = _fired
	boss._advance_movement(100.0)
	_expect(ai.state == AI.State.DEAD and _fired == count and not boss.stun(), "Dead is absorbing and cannot attack or stun")
	boss.queue_free()
	await _clear_field()

func _check_interruptions() -> void:
	var boss := _spawn()
	var ai := boss._boss_ai
	player.global_position = flight_space.screen_motion_to_combat(Vector2(0, 420))
	boss._advance_movement(.01)
	boss._advance_movement(ai.profile.intro_duration + .01)
	boss._advance_movement(.01)
	var cooldowns := ai.selector.cooldowns.duplicate()
	var count := _fired
	boss.take_damage(ceili(boss.max_health * ai.profile.stagger_health_fraction))
	_expect(ai.state == AI.State.STUNNED and not ai.executor.active, "Sustained windup damage triggers Stunned through real health routing")
	_expect(ai.selector.cooldowns == cooldowns, "Stagger never refunds the interrupted attack")
	boss._advance_movement(ai.profile.stun_duration + .01)
	_expect(_fired == count, "An interrupted telegraph cannot release delayed damage")
	# Retain the stun cooldown while making the projectile eligible for this check.
	ai.selector.cooldowns[&"projectile"] = 0.0
	boss._advance_movement(.01)
	boss.take_damage(ceili(boss.max_health * ai.profile.stagger_health_fraction))
	_expect(ai.state == AI.State.ATTACK, "The next windup cannot immediately be stun-locked")
	var plan := ai.executor.plan
	var attack := ai.profile.attacks[2]
	var original_damage := plan.definition.damage
	attack.damage = 3
	_expect(plan.definition.damage == original_damage, "Committed damage is independent of later tuning edits")
	attack.telegraph_duration = .1
	var quick_plan := BossAttackPlan.new()
	quick_plan.configure(attack, ai.profile, 2)
	_expect(quick_plan.warning_seconds == ai.profile.minimum_reaction_time, "Phase three and tuning edits cannot bypass the reaction-time floor")
	# Kill during a warning. Death must cancel, without emitting another phase.
	boss.take_damage(99999)
	_expect(ai.state == AI.State.DEAD and not ai.executor.active and boss.health == 0, "Lethal damage during a tell reaches Dead and cancels execution")
	await _clear_field()

func _check_damage() -> void:
	var boss := _spawn()
	var ai := boss._boss_ai
	player.set_dev_god_mode(false)
	GameManager.lives = 6
	player.reset_damage_state()
	player.global_position = flight_space.screen_motion_to_combat(Vector2(0, 100))
	player._on_area_entered(boss)
	_expect(GameManager.lives == 6, "Boss body contact cannot bypass a telegraph")
	var plan := BossAttackPlan.new()
	var slam := ai.profile.attacks[0].duplicate(true) as Definition
	slam.damage = 2
	plan.configure(slam, ai.profile, 0)
	plan.target_position = player.global_position
	ai.executor.begin(plan)
	ai.executor.advance(plan.warning_seconds - .01, player)
	_expect(GameManager.lives == 6, "Slam has no windup damage")
	ai.executor.advance(.02, player)
	ai.executor.advance(.01, player)
	_expect(GameManager.lives == 4, "Configurable slam damage removes the configured number of lives")
	player.reset_damage_state()
	ai.executor.advance(1.0, player)
	_expect(GameManager.lives == 4, "Slam hits each target only once")
	# A full charge in one tick must sweep across a target between its endpoints.
	player.reset_damage_state()
	player.global_position = flight_space.screen_motion_to_combat(Vector2(0, 350))
	plan = BossAttackPlan.new()
	plan.configure(ai.profile.attacks[1], ai.profile, 1)
	plan.aim = Vector2.DOWN
	plan.target_position = player.global_position
	ai.executor.begin(plan)
	var endpoint := plan.charge_endpoint
	ai.executor.advance(plan.warning_seconds + .01, player)
	var displacement := ai.executor.advance(2.0, player)
	boss.global_position += displacement
	_expect(GameManager.lives == 3 and boss.global_position.is_equal_approx(endpoint), "Charge sweeps its locked lane and stops at the advertised endpoint")
	player.reset_damage_state()
	ai.executor.advance(2.0, player)
	_expect(GameManager.lives == 3, "Charge cannot repeatedly damage during one pass")
	# A sidestep outside the telegraphed lane defeats the same attack.
	boss.global_position = Vector3.ZERO
	player.global_position = flight_space.screen_motion_to_combat(Vector2(200, 350))
	ai.executor.begin(plan)
	ai.executor.advance(plan.warning_seconds + .01, player)
	ai.executor.advance(2.0, player)
	_expect(GameManager.lives == 3, "Sidestepping the charge lane avoids damage")
	player.has_shield = true
	player.receive_damage(player.global_position, Player3D.DamageSource.ENEMY_CONTACT, 3)
	_expect(GameManager.lives == 3 and not player.has_shield, "A shield absorbs one whole attack regardless of damage tuning")
	player.reset_damage_state()
	projectile_manager.fire_enemy_projectile(Vector3.ZERO, Vector3.BACK, 400, Projectile.Motion.STRAIGHT, Color.WHITE, 0, 2)
	var shot := get_tree().get_first_node_in_group(&"enemy_projectiles") as Projectile
	_expect(shot != null and shot.damage == 2, "Projectile stores the committed damage payload")
	if shot != null:
		projectile_manager._on_projectile_hit(player, player.global_position, shot)
	_expect(GameManager.lives == 1, "Projectile damage passes through the normal damage authority")
	await _clear_field()
	projectile_manager.fire_enemy_projectile(Vector3.ZERO, Vector3.BACK)
	shot = get_tree().get_first_node_in_group(&"enemy_projectiles") as Projectile
	_expect(shot != null and shot.damage == 1, "Reused projectiles reset the prior attack's damage")
	player.set_dev_god_mode(true)
	boss._before_finish(BasicEnemy.FinishReason.ESCAPED, boss.global_position)
	boss.queue_free()
	await _clear_field()

func _check_mobility_variety() -> void:
	var boss := _spawn()
	var ai := boss._boss_ai
	for attack in ai.profile.attacks:
		ai.selector.cooldowns[attack.id] = 999.0
	player.global_position = flight_space.screen_motion_to_combat(Vector2(0, 900))
	boss.global_position = Vector3.ZERO
	boss._advance_movement(.01)
	boss._advance_movement(ai.profile.intro_duration + .01)
	_expect(ai.state == AI.State.CHASE, "A distant player is chased down")
	var before := flight_space.combat_motion_to_screen(player.global_position - boss.global_position).length()
	for tick in 120:
		boss._advance_movement(1.0 / 60.0)
	var after := flight_space.combat_motion_to_screen(player.global_position - boss.global_position).length()
	_expect(after < before - 100.0, "Chase closes on a distant player")
	player.global_position = flight_space.screen_motion_to_combat(Vector2(0, 360))
	for attack in ai.profile.attacks:
		ai.selector.cooldowns[attack.id] = 0.0
	for tick in 30:
		boss._advance_movement(1.0 / 60.0)
		if ai.state != AI.State.ATTACK:
			_expect(ai.state == AI.State.STRAFE, "Close range strafes around the player")
			break
	# A committed FEINT that has been walked out of breaks into a dodge.
	for attack in ai.profile.attacks:
		ai.selector.cooldowns[attack.id] = 0.0
	ai._sequence = 3
	ai._last_style = AI.Plan.Style.COMMIT
	player.global_position = flight_space.screen_motion_to_combat(Vector2(0, 360))
	boss.global_position = Vector3.ZERO
	for tick in 12:
		boss._advance_movement(1.0 / 60.0)
		if ai.state == AI.State.ATTACK and ai.executor.plan != null and ai.executor.plan.style == AI.Plan.Style.FEINT:
			break
	if ai.state == AI.State.ATTACK and ai.executor.plan != null and ai.executor.plan.style == AI.Plan.Style.FEINT:
		player.global_position = flight_space.screen_motion_to_combat(Vector2(700, 700))
		for tick in 60:
			boss._advance_movement(1.0 / 60.0)
			if ai.state != AI.State.ATTACK:
				break
		_expect(
			ai.state in [AI.State.DODGE, AI.State.CHASE, AI.State.STRAFE],
			"A feint the player has already left is abandoned for mobility"
		)
	# An incoming Player Projectile forces an explicit dodge state.
	projectile_manager.fire_player_projectile(
		boss.global_position + flight_space.screen_motion_to_combat(Vector2(0, -80)),
		flight_space.input_to_combat_direction(Vector2(0.0, 1.0))
	)
	for attack in ai.profile.attacks:
		ai.selector.cooldowns[attack.id] = 0.0
	ai._stun_cooldown = 0.0
	ai.state = AI.State.STRAFE
	ai.movement.release_hold(&"test")
	ai.movement.dodge_remaining = 0.0
	ai.movement._dodge_cooldown = 0.0
	ai._try_begin_dodge()
	_expect(ai.state == AI.State.DODGE, "Incoming fire forces a dodge")
	boss._advance_movement(1.0 / 60.0)
	var moved := boss.global_position
	boss._advance_movement(0.2)
	_expect(boss.global_position != moved, "Dodge keeps the hull flying")
	_expect(
		ai.state in [AI.State.DODGE, AI.State.CHASE, AI.State.STRAFE],
		"Dodge resolves back into mobility"
	)
	projectile_manager.clear_player_projectiles()
	boss._before_finish(BasicEnemy.FinishReason.ESCAPED, boss.global_position)
	boss.queue_free()
	await _clear_field()

func _check_repertoire() -> void:
	var targetings: Array[String] = []
	var styles: Array[String] = []
	for variant in 5:
		var boss := _spawn(variant)
		var ai := boss._boss_ai
		var families: Array[int] = []
		var alternate_seen := false
		for phase in 3:
			if phase > 0:
				ai.begin_phase(phase)
			var last_family := -1
			var streak := 0
			var previous_sequence := ai._sequence
			var starting_sequence := ai._sequence
			for tick in 4500:
				player.global_position = Vector3.ZERO
				if tick == 0:
					boss.global_position = flight_space.screen_motion_to_combat(Vector2(0, -600))
				boss._advance_movement(1.0 / 60.0)
				if ai.state == AI.State.ATTACK and not ai.executor.winding_up and ai.executor.plan.definition.family == Definition.Family.CHARGE:
					var direction := flight_space.input_to_combat_direction(ai.executor.plan.aim)
					var heading := atan2(-direction.x, -direction.z)
					_expect(absf(angle_difference(boss.global_rotation.y + boss.visuals.rotation.y, heading)) < 0.02, "Charge keeps facing its committed heading throughout the lane")
				if ai._sequence != previous_sequence:
					previous_sequence = ai._sequence
					if ai.executor.plan == null:
						continue
					var attack := ai.executor.plan.definition
					alternate_seen = alternate_seen or attack.alternate_pattern
					_expect(attack.minimum_phase <= phase, "Live encounter respects phase unlocks")
					streak = streak + 1 if last_family == attack.family else 1
					last_family = attack.family
					_expect(streak <= 2, "Live encounter never exceeds two repeats")
					if not families.has(attack.family):
						families.append(attack.family)
					var targeting := String(AI.Plan.Targeting.keys()[ai.executor.plan.targeting])
					var style := String(AI.Plan.Style.keys()[ai.executor.plan.style])
					if not targetings.has(targeting):
						targetings.append(targeting)
					if not styles.has(style):
						styles.append(style)
				if tick % 180 == 0:
					await _clear_field()
			_expect(ai._sequence >= starting_sequence + 3, "Encounter continues selecting attacks in every phase")
		_expect(families.has(Definition.Family.SLAM) and families.has(Definition.Family.CHARGE) and families.has(Definition.Family.PROJECTILE), Boss.TITLES[variant] + " uses all three attack families")
		_expect(alternate_seen, Boss.TITLES[variant] + " uses its additional projectile pattern in phase three")
		boss._before_finish(BasicEnemy.FinishReason.ESCAPED, boss.global_position)
		boss.queue_free()
		await _clear_field()
	_expect(targetings.size() >= 3, "Encounter uses several targeting behaviors")
	_expect(styles.size() >= 2, "Encounter uses several attack styles")

func _record_shot(kind: Projectile.Kind, _origin: Vector3, _direction: Vector3, _speed: float) -> void:
	if kind != Projectile.Kind.ENEMY:
		return
	_fired += 1
	var shot := get_tree().get_nodes_in_group(&"enemy_projectiles").back() as Projectile
	shot.set_physics_process(false)

func _clear_field() -> void:
	projectile_manager.clear_projectiles()
	hazard_manager.clear_hazards()
	await get_tree().process_frame
	await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
