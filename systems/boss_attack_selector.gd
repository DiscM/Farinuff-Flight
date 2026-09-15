extends RefCounted
class_name BossAttackSelector
## Rule-based weighted selection with hard eligibility before any random draw.
const Definition := preload("res://systems/boss_attack_definition.gd")
const Profile := preload("res://systems/boss_combat_profile.gd")
var profile: Profile
var cooldowns: Dictionary[StringName, float] = {}
var last_family := -1
var last_attack: StringName
var consecutive := 0
var _rng := RandomNumberGenerator.new()

func configure(tuning: Profile) -> void:
	profile = tuning
	cooldowns.clear()
	last_family = -1
	last_attack = &""
	consecutive = 0
	if profile.selection_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = profile.selection_seed

func advance(delta: float) -> void:
	for id in cooldowns:
		cooldowns[id] = maxf(0.0, cooldowns[id] - maxf(delta, 0.0))

func score(attack: Definition, distance: float, radial_speed: float, phase: int) -> float:
	if attack == null or phase < attack.minimum_phase or distance < attack.minimum_range or distance > attack.maximum_range:
		return 0.0
	if cooldowns.get(attack.id, 0.0) > 0.0 or (last_family == attack.family and consecutive >= 2):
		return 0.0
	var span := maxf(attack.maximum_range - attack.minimum_range, 1.0)
	var proximity := 1.0 - clampf(absf(distance - attack.ideal_range) / span, 0.0, 1.0)
	var movement := 1.0 + attack.retreat_bias * clampf(radial_speed / 300.0, -1.0, 1.0) * 0.75
	var variety := 0.35 if last_family == attack.family else 1.0
	var aggression := 1.0 + phase * (0.25 if attack.family != Definition.Family.PROJECTILE else 0.1)
	return maxf(0.0, attack.weight) * (0.25 + proximity) * movement * variety * aggression

func choose(distance: float, radial_speed: float, phase: int) -> Definition:
	var candidates: Array[Definition] = []
	var weights: Array[float] = []
	var total := 0.0
	for attack in profile.attacks:
		var weight := score(attack, distance, radial_speed, phase)
		if weight > 0.0:
			candidates.append(attack)
			weights.append(weight)
			total += weight
	if candidates.is_empty():
		return null # Reposition/wait; never relax the repetition or cooldown rules.
	var roll := _rng.randf() * total
	for index in candidates.size():
		roll -= weights[index]
		if roll <= 0.0:
			return candidates[index]
	return candidates.back()

func commit(attack: Definition, phase: int) -> void:
	# Spend on windup, including interrupted attempts, to prevent cancel/retry spam.
	cooldowns[attack.id] = maxf(0.0, attack.cooldown * profile.cooldown_scale(phase))
	consecutive = consecutive + 1 if last_family == attack.family else 1
	last_family = attack.family
	last_attack = attack.id

func desired_distance(phase: int, fallback: float) -> float:
	# After two projectile attacks, close into another attack's range even while
	# it cools down. Otherwise orbiting at projectile range could deadlock forever.
	if consecutive < 2:
		return fallback
	var desired := INF
	for attack in profile.attacks:
		if attack != null and phase >= attack.minimum_phase and attack.family != last_family and attack.weight > 0.0:
			desired = minf(desired, attack.ideal_range)
	return fallback if is_inf(desired) else desired
