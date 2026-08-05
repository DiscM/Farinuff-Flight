extends Node
class_name ThreatDirector
## Maintains active-enemy and weighted-threat limits without burst queuing.

const ACTIVE_CAPS := [12, 10, 9, 8]
const THREAT_BUDGETS := [12.0, 11.0, 10.0, 9.0]
const COSTS := {
	&"basic": 1.0,
	&"fast": 1.25,
	&"bomber": 2.0,
	&"sniper": 2.25,
	&"tank": 3.0,
}

## Late-game pressure growth: past wave 15 the active cap and threat budget
## gain +1 per 5 waves (max +3), so Gen IV pressure keeps rising alongside
## the enemy stat drift instead of plateauing.
const LATE_PRESSURE_START_WAVE := 15
const LATE_PRESSURE_WAVES_PER_STEP := 5
const LATE_PRESSURE_MAX_BONUS := 3

var generation: int = 1
var spawn_history: Array[StringName] = []


func set_generation(value: int) -> void:
	generation = clampi(value, 1, 4)


## Bonus added to the active cap and threat budget in the late game
## (0 at/below wave 15, +1 per 5 waves after, max +3).
func get_late_pressure_bonus(wave_number: int = GameManager.current_wave) -> int:
	var past := maxi(0, wave_number - LATE_PRESSURE_START_WAVE)
	return clampi(
		floori(float(past) / float(LATE_PRESSURE_WAVES_PER_STEP)),
		0,
		LATE_PRESSURE_MAX_BONUS
	)


func can_spawn(archetype: StringName) -> bool:
	var active := get_tree().get_nodes_in_group("regular_enemies")
	var bonus := get_late_pressure_bonus()
	if active.size() >= ACTIVE_CAPS[generation - 1] + bonus:
		return false
	var used := 0.0
	for enemy in active:
		if is_instance_valid(enemy):
			used += float(COSTS.get(enemy.archetype_id, 1.0))
	return used + float(COSTS.get(archetype, 1.0)) <= THREAT_BUDGETS[generation - 1] + float(bonus)


func record_spawn(archetype: StringName) -> void:
	spawn_history.append(archetype)
	if spawn_history.size() > 10:
		spawn_history.pop_front()


func needs_light_enemy() -> bool:
	# Evaluate the nine spawns that would remain after the next insertion.
	# Forcing a light ship when they contain fewer than five guarantees every
	# completed rolling window of ten is at least 50% Basic/Fast.
	if spawn_history.size() < 9:
		return false
	var light_count := 0
	var start_index := maxi(0, spawn_history.size() - 9)
	for index in range(start_index, spawn_history.size()):
		var kind := spawn_history[index]
		if kind == &"basic" or kind == &"fast":
			light_count += 1
	return light_count < 5


func get_debug_state() -> String:
	var active := get_tree().get_nodes_in_group("regular_enemies")
	var used := 0.0
	for enemy in active:
		if is_instance_valid(enemy):
			used += float(COSTS.get(enemy.archetype_id, 1.0))
	return "Gen %d | active %d/%d | threat %.2f/%.2f" % [
		generation, active.size(), ACTIVE_CAPS[generation - 1],
		used, THREAT_BUDGETS[generation - 1],
	]
