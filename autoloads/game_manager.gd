extends Node
## Manages global game state: score, lives, waves, combos, difficulty scaling, and stat allocation.

# --- State ---
var score: int = 0
var high_score: int = 0
var combo: int = 0
var lives: int = 3
var current_wave: int = 1
var is_game_active: bool = false
var boss_active: bool = false
var try_again_stocks: int = 3

# --- Difficulty scaling ---
var base_spawn_interval: float = 1.5
var min_spawn_interval: float = 0.3
var enemy_speed_multiplier: float = 1.0
var enemies_per_wave: int = 8
var enemies_killed_this_wave: int = 0

# --- Point Allocation ---
var allocation_points_per_milestone: int = 3
var stat_fire_rate_level: int = 0
var stat_health_level: int = 0
var stat_speed_level: int = 0

# Computed bonuses (driven by stat levels)
var bonus_speed_pct: float = 0.0
var bonus_fire_rate_pct: float = 0.0
var bonus_damage: int = 0

# --- Orb Meter ---
var orbs_collected: int = 0
var orbs_per_heart: int = 10

func _ready() -> void:
	SignalBus.enemy_killed.connect(_on_enemy_killed)
	SignalBus.player_hit.connect(_on_player_hit)
	SignalBus.game_restarted.connect(_on_game_restarted)
	SignalBus.boss_died.connect(_on_boss_died)
	SignalBus.xp_orb_collected.connect(_on_orb_collected)

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
	if enemies_killed_this_wave >= enemies_per_wave and not boss_active:
		_advance_wave()

func _on_boss_died(_points: int) -> void:
	boss_active = false
	# Elite boss on wave 10 (and multiples of 10) triggers the ship-transformation upgrade
	if current_wave % 10 == 0:
		SignalBus.elite_upgrade_triggered.emit()
	_advance_wave()


# --- Orb Meter ---

func _on_orb_collected(_value: int) -> void:
	orbs_collected += 1
	if orbs_collected >= orbs_per_heart:
		orbs_collected = 0
		lives += 1
		SignalBus.lives_changed.emit(lives)
	SignalBus.orb_meter_changed.emit(orbs_collected, orbs_per_heart)

# --- Point Allocation ---

## Called by the allocation popup when the player invests a point.
func apply_stat_point(stat_name: String) -> void:
	match stat_name:
		"fire_rate":
			stat_fire_rate_level += 1
			bonus_fire_rate_pct += 0.05
		"health":
			stat_health_level += 1
			lives += 1
			SignalBus.lives_changed.emit(lives)
		"speed":
			stat_speed_level += 1
			bonus_speed_pct += 0.03

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
	var cleared_wave := current_wave
	SignalBus.wave_cleared.emit(cleared_wave)
	current_wave += 1
	enemies_killed_this_wave = 0
	enemies_per_wave = 8 + current_wave * 2
	enemy_speed_multiplier = 1.0 + (current_wave - 1) * 0.06
	boss_active = (current_wave % 5 == 0)
	SignalBus.wave_started.emit(current_wave)

	# Trigger point allocation every 5 waves (after clearing wave 5, 10, 15…)
	if cleared_wave % 5 == 0:
		SignalBus.allocation_triggered.emit(allocation_points_per_milestone)

func get_spawn_interval() -> float:
	var interval := base_spawn_interval - (current_wave - 1) * 0.05
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

	# Reset allocation state
	stat_fire_rate_level = 0
	stat_health_level = 0
	stat_speed_level = 0
	bonus_speed_pct = 0.0
	bonus_fire_rate_pct = 0.0
	bonus_damage = 0
	orbs_collected = 0
	try_again_stocks = 3

	is_game_active = true
	boss_active = false
	SignalBus.score_changed.emit(score)
	SignalBus.combo_changed.emit(combo)
	SignalBus.lives_changed.emit(lives)
	SignalBus.wave_started.emit(current_wave)

func start_game() -> void:
	_on_game_restarted()
