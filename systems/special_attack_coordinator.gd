extends Node
class_name SpecialAttackCoordinator
## Scene-local concurrency and hazard caps for evolved enemy attacks.

const HAZARD_CAPS := {
	&"mine": 6,
	&"cluster_mine": 2,
	&"plasma_field": 2,
	&"seeker_fragment": 6,
}

var _major_owner: Node = null
var _hazard_counts: Dictionary = {}
var major_attacks_enabled: bool = true


func request_major(requester: Node) -> bool:
	if not major_attacks_enabled:
		return false
	_prune_major()
	if _major_owner != null and _major_owner != requester:
		return false
	_major_owner = requester
	return true


func release_major(requester: Node) -> void:
	if _major_owner == requester:
		_major_owner = null


func request_hazard(kind: StringName) -> bool:
	var cap := int(HAZARD_CAPS.get(kind, 0))
	if cap <= 0:
		return true
	var count := int(_hazard_counts.get(kind, 0))
	if count >= cap:
		return false
	_hazard_counts[kind] = count + 1
	return true


func release_hazard(kind: StringName) -> void:
	_hazard_counts[kind] = maxi(0, int(_hazard_counts.get(kind, 0)) - 1)


func reset_pressure() -> void:
	_major_owner = null
	_hazard_counts.clear()


func get_debug_state() -> String:
	_prune_major()
	return "major=%s | mines=%d/%d cluster=%d/%d plasma=%d/%d fragments=%d/%d" % [
		"grace" if not major_attacks_enabled else "busy" if _major_owner != null else "free",
		int(_hazard_counts.get(&"mine", 0)), int(HAZARD_CAPS[&"mine"]),
		int(_hazard_counts.get(&"cluster_mine", 0)), int(HAZARD_CAPS[&"cluster_mine"]),
		int(_hazard_counts.get(&"plasma_field", 0)), int(HAZARD_CAPS[&"plasma_field"]),
		int(_hazard_counts.get(&"seeker_fragment", 0)), int(HAZARD_CAPS[&"seeker_fragment"]),
	]


func _prune_major() -> void:
	if _major_owner != null and not is_instance_valid(_major_owner):
		_major_owner = null
