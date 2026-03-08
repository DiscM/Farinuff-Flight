extends Node
## Central signal bus for decoupled communication between game systems.

# Enemy signals
signal enemy_killed(points: int, position: Vector2)
signal all_enemies_cleared

# Player signals
signal player_hit
signal player_died

# Power-up signals
signal power_up_collected(type: int, position: Vector2)
signal xp_orb_collected(xp_value: int)

# Wave signals
signal wave_started(wave_number: int)
signal wave_cleared(wave_number: int)

# Score signals
signal score_changed(new_score: int)
signal combo_changed(new_combo: int)
signal lives_changed(new_lives: int)

# RPG / Level-up signals
signal xp_changed(current_xp: int, xp_to_next: int)
signal level_up(new_level: int)

# Effects
signal screen_shake(intensity: float, duration: float)

# Game state
signal game_over(final_score: int)
signal game_restarted
