extends Node
## Wall-clock process intervals, not the delayed Performance FPS monitor.
## Samples stay in memory during combat; serialization happens between stages.
var game: Node
var active := false
var intervals_ms := PackedFloat64Array()
var counters: Array[Dictionary] = []
var _last_usec := 0
var _next_counter_usec := 0
var _unfocused_frames := 0

func begin() -> void:
	intervals_ms.clear()
	counters.clear()
	_unfocused_frames = 0
	# The first callback establishes a boundary; a partial frame is not a sample.
	_last_usec = 0
	_next_counter_usec = 0
	active = true

func _process(_delta: float) -> void:
	if not active:
		return
	var now := Time.get_ticks_usec()
	if _last_usec != 0:
		intervals_ms.append(float(now - _last_usec) / 1000.0)
		if not get_window().has_focus():
			_unfocused_frames += 1
	_last_usec = now
	if now >= _next_counter_usec:
		counters.append(snapshot())
		_next_counter_usec = now + 500000

func finish() -> Dictionary:
	active = false
	counters.append(snapshot())
	var result := {"frame_intervals_ms": Array(intervals_ms), "counters": counters.duplicate(true), "unfocused_frames": _unfocused_frames}
	intervals_ms.clear()
	counters.clear()
	return result

func snapshot() -> Dictionary:
	var rendered := DisplayServer.get_name() != "headless"
	var result := {
		"elapsed_ms": Time.get_ticks_msec(),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"orphan_nodes": null, "static_bytes": null, "renderer_bytes": null,
		"draw_calls": null, "draw_pipeline_compilations": null,
		"pool": ObjectPool.get_metrics(),
	}
	if OS.is_debug_build():
		result.orphan_nodes = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		result.static_bytes = OS.get_static_memory_usage()
	if rendered:
		result.renderer_bytes = int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
		result.draw_calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		result.draw_pipeline_compilations = int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW))
	if is_instance_valid(game):
		result["projectiles"] = game.projectile_manager.get_metrics()
		result["hazards"] = game.hazard_manager.get_metrics()
		result["effects"] = game.effect_manager.get_metrics()
		result["enemies"] = get_tree().get_nodes_in_group(&"native_3d_enemies").size()
	return result
