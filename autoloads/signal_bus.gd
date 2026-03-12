extends Node
## Central signal bus for decoupled communication between game systems.
## Signals are connected/emitted externally — @warning_ignore suppresses false positives.

# Enemy signals
@warning_ignore("unused_signal")
signal enemy_killed(points: int, position: Vector2)
@warning_ignore("unused_signal")
signal all_enemies_cleared

# Player signals
@warning_ignore("unused_signal")
signal player_hit
@warning_ignore("unused_signal")
signal player_died

# Power-up signals
@warning_ignore("unused_signal")
signal power_up_collected(type: int, position: Vector2)
@warning_ignore("unused_signal")
signal xp_orb_collected(xp_value: int)
@warning_ignore("unused_signal")
signal orb_meter_changed(current: int, max_orbs: int)

# Boss signals
@warning_ignore("unused_signal")
signal boss_spawned(health: int, max_health: int)
@warning_ignore("unused_signal")
signal boss_health_changed(health: int)
@warning_ignore("unused_signal")
signal boss_died(points: int)

# Wave signals
@warning_ignore("unused_signal")
signal wave_started(wave_number: int)
@warning_ignore("unused_signal")
signal wave_cleared(wave_number: int)

# Score signals
@warning_ignore("unused_signal")
signal score_changed(new_score: int)
@warning_ignore("unused_signal")
signal combo_changed(new_combo: int)
@warning_ignore("unused_signal")
signal lives_changed(new_lives: int)

# Point allocation signals
@warning_ignore("unused_signal")
signal allocation_triggered(points: int)
@warning_ignore("unused_signal")
signal elite_upgrade_triggered


# Effects
@warning_ignore("unused_signal")
signal screen_shake(intensity: float, duration: float)

# Game state
@warning_ignore("unused_signal")
signal game_over(final_score: int)
@warning_ignore("unused_signal")
signal game_restarted
