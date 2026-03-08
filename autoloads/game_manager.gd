extends Node
## Manages global game state: score, lives, waves, combos, difficulty scaling, and RPG leveling.

# --- State ---
var score: int = 0
var high_score: int = 0
var combo: int = 0
var lives: int = 3
var current_wave: int = 1
var is_game_active: bool = false

# --- Difficulty scaling ---
var base_spawn_interval: float = 1.5
var min_spawn_interval: float = 0.3
var enemy_speed_multiplier: float = 1.0
var enemies_per_wave: int = 8
var enemies_killed_this_wave: int = 0

# --- RPG Level-Up ---
var xp: int = 0
var level: int = 1
var xp_to_next_level: int = 250  # first threshold uses logarithmic curve

# Passive per-level bonuses (cumulative)
var bonus_speed_pct: float = 0.0
var bonus_fire_rate_pct: float = 0.0
var bonus_damage: int = 0
var speed_stacks: int = 0

func _ready() -> void:
	SignalBus.enemy_killed.connect(_on_enemy_killed)
	SignalBus.player_hit.connect(_on_player_hit)
	SignalBus.game_restarted.connect(_on_game_restarted)
	SignalBus.xp_orb_collected.connect(_on_xp_orb_collected)

# --- Score & Combo ---

func _on_enemy_killed(points: int, _position: Vector2) -> void:
	combo += 1
	var multiplied_points := points * combo
	score += multiplied_points
	SignalBus.score_changed.emit(score)
	SignalBus.combo_changed.emit(combo)

	# Award XP equal to base point value
	#_award_xp(points)  # XP now comes from collectible orbs

	enemies_killed_this_wave += 1
	if enemies_killed_this_wave >= enemies_per_wave:
		_advance_wave()

# --- RPG XP / Level System ---

func _on_xp_orb_collected(value: int) -> void:
	_award_xp(value)

## Logarithmic XP curve: early levels need more XP, later levels scale gently.
## level 1→2 = 250, 2→3 ≈ 396, 3→4 = 500, 5→6 ≈ 646, 10→11 ≈ 866
func _calc_xp_for_level(lvl: int) -> int:
	return int(250.0 * log(float(lvl + 1)) / log(2.0))

func _award_xp(amount: int) -> void:
	xp += amount
	SignalBus.xp_changed.emit(xp, xp_to_next_level)
	if xp >= xp_to_next_level:
		_level_up()

func _level_up() -> void:
	xp -= xp_to_next_level
	level += 1
	xp_to_next_level = _calc_xp_for_level(level)

	# Passive per-level bonuses
	bonus_speed_pct += 0.05
	bonus_fire_rate_pct += 0.05
	if level % 3 == 0:
		bonus_damage += 1

	SignalBus.xp_changed.emit(xp, xp_to_next_level)
	SignalBus.level_up.emit(level)

## Called by the level-up popup when the player picks an upgrade.
func apply_upgrade(type: String) -> void:
	match type:
		"speed":
			if speed_stacks < 5:
				speed_stacks += 1
				bonus_speed_pct += 0.01
		"fire_rate":
			bonus_fire_rate_pct += 0.25
		"damage":
			bonus_damage += 1
		"shield":
			pass  # Handled by player
		"life":
			lives += 1
			SignalBus.lives_changed.emit(lives)
		"magnet":
			pass  # Handled by player
		"rear_gun":
			pass  # Handled by player
		"piercing":
			pass  # Handled by player
		"orbitals":
			pass  # Handled by player
		"explosive_rounds":
			pass  # Handled by player
		"zigzag":
			pass  # Handled by player

# --- Player hit ---

func _on_player_hit() -> void:
	combo = 0
	SignalBus.combo_changed.emit(combo)
	lives -= 1
	SignalBus.lives_changed.emit(lives)
	SignalBus.screen_shake.emit(8.0, 0.3)

	if lives <= 0:
		is_game_active = false
		if score > high_score:
			high_score = score
		SignalBus.game_over.emit(score)

# --- Waves ---

func _advance_wave() -> void:
	SignalBus.wave_cleared.emit(current_wave)
	current_wave += 1
	enemies_killed_this_wave = 0
	enemies_per_wave = 8 + current_wave * 2
	enemy_speed_multiplier = 1.0 + (current_wave - 1) * 0.12
	SignalBus.wave_started.emit(current_wave)

func get_spawn_interval() -> float:
	var interval := base_spawn_interval - (current_wave - 1) * 0.1
	return maxf(interval, min_spawn_interval)

# --- Restart ---

func _on_game_restarted() -> void:
	score = 0
	combo = 0
	lives = 3
	current_wave = 1
	enemies_killed_this_wave = 0
	enemies_per_wave = 8
	enemy_speed_multiplier = 1.0

	# Reset RPG state
	xp = 0
	level = 1
	xp_to_next_level = _calc_xp_for_level(1)
	bonus_speed_pct = 0.0
	bonus_fire_rate_pct = 0.0
	bonus_damage = 0
	speed_stacks = 0

	is_game_active = true
	SignalBus.score_changed.emit(score)
	SignalBus.combo_changed.emit(combo)
	SignalBus.lives_changed.emit(lives)
	SignalBus.wave_started.emit(current_wave)
	SignalBus.xp_changed.emit(xp, xp_to_next_level)

func start_game() -> void:
	_on_game_restarted()
