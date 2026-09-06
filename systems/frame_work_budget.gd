extends RefCounted
## Bounds synchronous preparation work without forcing a frame per tiny batch.
## Reset after yielding so time spent waiting/rendering is not charged to work.

var _budget_usec: int
var _started_usec: int


func _init(budget_usec: int = 4000) -> void:
	_budget_usec = maxi(1, budget_usec)
	reset()


func reset() -> void:
	_started_usec = Time.get_ticks_usec()


func should_yield() -> bool:
	if Time.get_ticks_usec() - _started_usec < _budget_usec:
		return false
	reset()
	return true
