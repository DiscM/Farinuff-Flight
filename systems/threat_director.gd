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

var generation: int = 1
var spawn_history: Array[StringName] = []


func set_generation(value: int) -> void:
	generation = clampi(value, 1, 4)


func can_spawn(archetype: StringName) -> bool:
	var active := get_tree().get_nodes_in_group("regular_enemies")
	if active.size() >= ACTIVE_CAPS[generation - 1]:
		return false
	var used := 0.0
	for enemy in active:
		if is_instance_valid(enemy):
			used += float(COSTS.get(enemy.archetype_id, 1.0))
	return used + float(COSTS.get(archetype, 1.0)) <= THREAT_BUDGETS[generation - 1]


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
