extends RefCounted
## Ordered run-local steps. Presentation owns the overlay; this module owns
## pending work and completion tokens so stale UI callbacks cannot advance it.
const PRIORITY := {"elite": 0, "allocation": 1, "story": 2, "route": 3, "victory": 4}
var _pending: Array[Dictionary] = []
var _active: Dictionary = {}
var _serial := 0

func enqueue(step: Dictionary) -> void:
	var entry := step.duplicate()
	_serial += 1
	entry["token"] = _serial
	_pending.append(entry)
	_pending.sort_custom(func(a: Dictionary, b: Dictionary):
		var left := int(PRIORITY.get(a.kind, 99))
		var right := int(PRIORITY.get(b.kind, 99))
		return int(a.token) < int(b.token) if left == right else left < right
	)

func take_next() -> Dictionary:
	if not _active.is_empty() or _pending.is_empty():
		return {}
	_active = _pending.pop_front()
	return _active.duplicate()

func complete(token: int) -> bool:
	if int(_active.get("token", -1)) != token:
		return false
	_active = {}
	return true

func has_work() -> bool:
	return not _pending.is_empty() or not _active.is_empty()

func suspend() -> void:
	if not _active.is_empty():
		var interrupted := _active.duplicate()
		_active = {}
		# A new token invalidates any callbacks still queued by the old overlay.
		enqueue(interrupted)

func clear() -> void:
	_pending.clear()
	_active = {}
