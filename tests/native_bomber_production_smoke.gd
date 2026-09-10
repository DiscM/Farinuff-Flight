extends "res://scenes/native_3d_run.gd"
## Focused production-path coverage for bomber mine hazards. Each actor is
## created by NativeEncounterDirector.spawn_enemy(), then its normal
## Generation II-IV timer path is accelerated only to keep this smoke test
## short; the mine request and bounded checkout remain real.

const BomberEnemy := preload("res://entities/enemies/bomber_enemy_3d.gd")

var _failures: Array[String] = []
var _mine_drops := 0


func _ready() -> void:
	await super._ready()
	_run_checks.call_deferred()


func _run_checks() -> void:
	_expect(GameManager.is_game_active, "Native production run initializes")
	_expect(encounters != null and encounters.started, "Encounter director starts the production run")
	for generation in [2, 3, 4]:
		await _check_generation(generation)
	GameManager.is_game_active = false
	if _failures.is_empty():
		print("NATIVE_BOMBER_PRODUCTION_SMOKE_PASS")
		await get_tree().process_frame
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("NATIVE_BOMBER_PRODUCTION_SMOKE_FAIL: %d assertion(s)" % _failures.size())
	await get_tree().process_frame
	get_tree().quit(1)


func _check_generation(generation: int) -> void:
	dev_clear_hostiles()
	await get_tree().process_frame
	hazard_manager.clear_hazards()
	_mine_drops = 0
	dev_force_generation(generation)
	var bomber := encounters.spawn_enemy(&"bomber") as BomberEnemy
	_expect(bomber != null, "Production spawn creates a Generation %d bomber" % generation)
	if bomber == null:
		return
	_expect(bomber.generation == generation, "Production bomber activates at Generation %d" % generation)
	bomber.mine_dropped.connect(_on_mine_dropped)
	# Keep the actor in the combat view while preserving its production
	# activation. Only the timer is shortened; _advance_movement() still gates
	# the request on lifetime and visibility.
	var center := flight_space.get_combat_bounds().get_center()
	bomber.global_position = Vector3(center.x + 8.0, 0.0, center.y)
	bomber.set("_mine_timer", 0.0)
	var spawned_before := int(hazard_manager.get_metrics()["spawned_mines"])
	for _frame in range(30):
		await get_tree().physics_frame
	var metrics: Dictionary = hazard_manager.get_metrics()
	_expect(_mine_drops >= 1, "Generation %d bomber emits its mine drop signal" % generation)
	_expect(
		int(metrics["spawned_mines"]) == spawned_before + 1,
		"Generation %d bomber requests one pooled mine" % generation,
	)
	_expect(
		int(metrics["mine_active"]) <= int(metrics["mine_pool_size"]),
		"Generation %d mine checkout remains bounded" % generation,
	)
	bomber.queue_free()
	await get_tree().process_frame
	hazard_manager.clear_hazards()


func _on_mine_dropped(_is_cluster: bool, _leaves_plasma: bool) -> void:
	_mine_drops += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
