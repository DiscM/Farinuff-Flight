extends TankEnemy3D
## First native boss encounter. Reuses the Tank hull and attacks while authored
## boss models, sections, and distinct variants are developed independently.

var max_health := 60
var _boss_time := 0.0
var _anchor := Vector3.ZERO


func _configure_movement() -> void:
	super._configure_movement()
	_anchor = global_position
	_boss_time = 0.0
	burst_interval = 1.8


func activate_generation(space: FlightSpace, origin: Vector3, direction: Vector3, stage: int) -> bool:
	if not super.activate_generation(space, origin, direction, stage):
		return false
	max_health = roundi((45.0 + GameManager.current_wave * 3.0) * GameManager.get_enemy_health_multiplier())
	health = max_health
	add_to_group(&"native_3d_bosses")
	SignalBus.boss_spawned.emit(health, max_health, "SIEGE COMMANDER")
	return true


func _advance_movement(delta: float) -> void:
	# Tank attack timers remain authoritative; the boss holds a firing lane.
	velocity = Vector3.ZERO
	super._advance_movement(delta)
	_boss_time += delta
	global_position = _anchor + _flight_space.screen_motion_to_combat(Vector2(sin(_boss_time * 0.65) * 110.0, 0.0))


func _on_area_entered(_area: Area3D) -> void:
	# Player owns contact damage. Contact must not remove the boss and strand
	# GameManager in a boss wave.
	pass


func take_damage(amount: int) -> void:
	super.take_damage(amount)
	SignalBus.boss_health_changed.emit(maxi(health, 0))


func get_reward_points() -> int:
	return 1500 + GameManager.current_wave * 100


func should_drop_xp_orb() -> bool:
	return false


func _before_finish(reason: FinishReason, _position: Vector3) -> void:
	if reason == FinishReason.DESTROYED:
		# Advance the run after the current projectile/physics callback ends.
		SignalBus.boss_died.emit.call_deferred(get_reward_points())
