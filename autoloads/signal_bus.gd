extends Node
## Central signal bus for decoupled communication between game systems.
## Signals are connected/emitted externally — @warning_ignore suppresses false positives.

# Enemy signals
@warning_ignore("unused_signal")
## Emitted when any enemy is killed. Carries the point value and world position of the kill.
signal enemy_killed(points: int, position: Vector2)
@warning_ignore("unused_signal")
## Emitted when all enemies on screen have been destroyed (currently unused but reserved).
signal all_enemies_cleared

# Player signals
@warning_ignore("unused_signal")
## Emitted when the player takes damage (before lives are decremented by GameManager).
signal player_hit
@warning_ignore("unused_signal")
## Emitted when the player loses all lives (reserved — game_over is the primary signal).
signal player_died

# Power-up signals
@warning_ignore("unused_signal")
## Emitted when the player collects a power-up. Carries the power-up type enum value and pickup position.
signal power_up_collected(type: int, position: Vector2)
@warning_ignore("unused_signal")
## Emitted when the player collects an XP orb. Carries the orb's XP value.
signal xp_orb_collected(xp_value: int)
@warning_ignore("unused_signal")
## Emitted when the orb meter changes. Carries the current count and the threshold needed for the next heart.
signal orb_meter_changed(current: int, max_orbs: int)

# Boss signals
@warning_ignore("unused_signal")
## Emitted when a boss enters the scene. Carries its initial HP, max HP, and display name.
signal boss_spawned(health: int, max_health: int, boss_name: String)
@warning_ignore("unused_signal")
## Emitted every frame during a boss fight with the boss's current HP for the health bar.
signal boss_health_changed(health: int)
@warning_ignore("unused_signal")
## Emitted when a boss is destroyed. Carries the point reward.
signal boss_died(points: int)

# Wave signals
@warning_ignore("unused_signal")
## Emitted when a new wave begins. Carries the wave number.
signal wave_started(wave_number: int)
@warning_ignore("unused_signal")
## Emitted when a wave's orb threshold is met or a boss is killed. Carries the cleared wave number.
signal wave_cleared(wave_number: int)
@warning_ignore("unused_signal")
## Announces that a newly started wave changes the regular-enemy generation.
signal evolution_transition_pending(generation: int, generation_name: String)
@warning_ignore("unused_signal")
## Emitted after the non-pausing evolution banner has completed.
signal evolution_transition_finished(generation: int)

# Score signals
@warning_ignore("unused_signal")
## Emitted whenever the total score changes.
signal score_changed(new_score: int)
@warning_ignore("unused_signal")
## Emitted whenever the combo counter changes.
signal combo_changed(new_combo: int)
@warning_ignore("unused_signal")
## Emitted whenever the player's life count changes.
signal lives_changed(new_lives: int)

# Point allocation signals
@warning_ignore("unused_signal")
## Emitted every 5 waves to trigger the stat point allocation popup. Carries the number of points to distribute.
signal allocation_triggered(points: int)
@warning_ignore("unused_signal")
## Emitted after defeating a Wave-10 elite boss to trigger the elite upgrade selection popup.
signal elite_upgrade_triggered


# Effects
@warning_ignore("unused_signal")
## Requests a camera screen shake. Carries the shake intensity and duration in seconds.
signal screen_shake(intensity: float, duration: float)

# Game state
@warning_ignore("unused_signal")
## Emitted when the player loses all lives and the game ends. Carries the final score.
signal game_over(final_score: int)
@warning_ignore("unused_signal")
## Emitted when the player restarts the game from the game over or pause menu.
signal game_restarted
