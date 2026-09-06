extends "res://scenes/native_3d_run.gd"
## Run with --max-fps 60 for comparable preparation-frame measurements.
## Does not consume supplies or award progression.


func _ready() -> void:
	var started_usec := Time.get_ticks_usec()
	var started_frame := Engine.get_process_frames()
	await super._ready()
	if not GameManager.is_game_active:
		push_error("RUN_WARMUP_BENCHMARK_FAIL: run failed to prepare")
		get_tree().quit(1)
		return
	encounters.started = false
	GameManager.is_game_active = false
	print("RUN_WARMUP_BENCHMARK_PASS elapsed_ms=%.2f frames=%d nodes=%d static_bytes=%d" % [
		(Time.get_ticks_usec() - started_usec) / 1000.0,
		Engine.get_process_frames() - started_frame,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		OS.get_static_memory_usage(),
	])
	get_tree().quit(0)
