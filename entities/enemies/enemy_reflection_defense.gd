extends RefCounted
## Reflection charge and cooldown policy, reset on each pooled activation.
## The enemy state machine owns windup/roll transitions and visual tells.

var cooldown := 0.0
var charges := 0
var prefer_reflect := true


func reset(prefer: bool) -> void:
	cooldown = 0.0
	charges = 0
	prefer_reflect = prefer


func advance(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)


func begin(offset: Vector2, relative_velocity: Vector2, radius: float, warning: float, recovery: float, capacity: int) -> bool:
	var closing := relative_velocity.dot(offset.normalized())
	# Shots arriving during the warning must still hit; never arm a late parry.
	if closing <= 0.0 or (offset.length() - radius) / closing < warning + 0.08:
		return false
	cooldown = recovery
	charges = capacity
	prefer_reflect = false
	return true


## Returns true when the roll's last charge has been spent.
func consume() -> bool:
	charges = maxi(0, charges - 1)
	return charges == 0


func after_dodge(recovery: float) -> void:
	cooldown = maxf(cooldown, recovery)
	prefer_reflect = true
